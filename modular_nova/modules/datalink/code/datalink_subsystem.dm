// MODULE ID: DATALINK
// The network tick (design doc §9): 0.25 s — drains relay/flood queues under
// budget, ages neighbor tables, expires commands, refreshes HUD markers.
// Beacons are NOT batched here; they are individually scheduled with jitter.
SUBSYSTEM_DEF(datalink)
	name = "Datalink"
	wait = 0.25 SECONDS
	ss_flags = SS_NO_INIT
	runlevels = RUNLEVEL_GAME | RUNLEVEL_POSTGAME

	/// Remaining uncached LOS checks for this tick
	var/los_budget = DATALINK_LOS_BUDGET_GLOBAL
	/// Pending relay jobs: list of list(datum/datalink_node, packet)
	var/list/relay_queue = list()
	/// Commands deferred by the LOS budget: list of list(node, packet, receiver)
	var/list/deferred_queue = list()
	/// LOS results: "x,y|x,y" -> list(expires_at, result)
	var/list/los_cache = list()
	/// Metrics (design doc §9)
	var/metric_beacons_sent = 0
	var/metric_commands_sent = 0
	var/metric_relays = 0
	var/metric_deferred = 0
	var/metric_dropped = 0
	var/metric_aged = 0
	var/metric_los_checks = 0
	var/metric_los_hits = 0

// NOTE: the fire body is written to be idempotent (budgets reset at the top,
// every pass is a bounded scan), so `resumed` is deliberately unused; a
// suspended tick re-running costs one bounded pass, never corrupts state.
/datum/controller/subsystem/datalink/fire(resumed)
	los_budget = DATALINK_LOS_BUDGET_GLOBAL
	prune_los_cache()
	drain_deferred()
	drain_relays()
	var/now = world.time
	for(var/datum/datalink_node/node as anything in GLOB.datalink_nodes)
		if(QDELETED(node))
			continue
		node.age(now)
		node.hud?.refresh()

/// Bounds the LOS cache; called every tick, only does work once we're over cap.
/datum/controller/subsystem/datalink/proc/prune_los_cache()
	if(length(los_cache) <= DATALINK_LOS_CACHE_SIZE)
		return
	for(var/key in los_cache)
		var/list/entry = los_cache[key]
		if(entry[1] < world.time)
			los_cache -= key

/// Retry commands that were deferred when the LOS budget ran out.
/datum/controller/subsystem/datalink/proc/drain_deferred()
	while(length(deferred_queue) && los_budget > 0)
		var/list/entry = deferred_queue[1]
		deferred_queue.Cut(1, 2)
		var/datum/datalink_node/transmitter = entry[1]
		var/list/packet = entry[2]
		var/datum/datalink_node/receiver = entry[3]
		if(QDELETED(transmitter) || QDELETED(receiver) || !transmitter.registered || !receiver.registered || transmitter.state != DATALINK_STATE_ACTIVE || receiver.state != DATALINK_STATE_ACTIVE)
			continue
		metric_deferred--
		var/turf/source_turf = get_turf(transmitter.position_source)
		var/turf/receiver_turf = get_turf(receiver.position_source)
		if(!source_turf || !receiver_turf)
			continue
		if(!datalink_can_see(source_turf, receiver_turf, force = TRUE))
			metric_dropped++
			continue
		dispatch(transmitter, packet, receiver)

/// Bounded per-tick drain of the relay/flood queue (design doc §9).
/datum/controller/subsystem/datalink/proc/drain_relays()
	var/drain = min(length(relay_queue), DATALINK_FLOOD_DRAIN_PER_TICK)
	for(var/index in 1 to drain)
		var/list/entry = relay_queue[1]
		relay_queue.Cut(1, 2)
		var/datum/datalink_node/relay_node = entry[1]
		var/list/packet = entry[2]
		if(QDELETED(relay_node) || !relay_node.registered || relay_node.state != DATALINK_STATE_ACTIVE)
			continue
		metric_relays++
		fanout(relay_node, packet)

/// Enqueue a rebroadcast. The packet is already hop/ttl-adjusted by the receiver.
/datum/controller/subsystem/datalink/proc/queue_relay(datum/datalink_node/node, list/packet)
	relay_queue += list(list(node, packet))

/**
 * Fan a packet out from `transmitter` to every listening node in range with LOS.
 * This is the whole "network": bounded iteration over GLOB.datalink_nodes with
 * range and LOS gating — no per-tile processing, no message objects.
 */
/datum/controller/subsystem/datalink/proc/fanout(datum/datalink_node/transmitter, list/packet)
	var/turf/source_turf = get_turf(transmitter.position_source)
	if(!source_turf)
		return
	if(packet["kind"] == DATALINK_PACKET_BEACON)
		metric_beacons_sent++
	else
		metric_commands_sent++
	for(var/datum/datalink_node/receiver as anything in GLOB.datalink_nodes)
		// Disabled (SILENT) nodes are deaf — no packets delivered at all.
		if(receiver == transmitter || QDELETED(receiver) || !receiver.registered || receiver.state != DATALINK_STATE_ACTIVE)
			continue
		var/turf/receiver_turf = get_turf(receiver.position_source)
		if(!receiver_turf || receiver_turf.z != source_turf.z)
			continue
		var/dist = get_dist_euclidean(source_turf, receiver_turf)
		if(packet["net"] != receiver.net_id)
			// Design doc §8: foreign traffic is detectable but not decodable.
			// Normal emissions leak across walls within range. LPI emissions
			// are only interceptable with immediate line of sight.
			if(dist > transmitter.range)
				continue
			if(packet["lpi"] && datalink_can_see(source_turf, receiver_turf) != TRUE)
				continue
			receiver.note_foreign(dist, transmitter.range)
			continue
		if(dist > transmitter.range)
			continue
		var/visible = datalink_can_see(source_turf, receiver_turf)
		if(visible == DATALINK_LOS_DEFERRED)
			if(packet["kind"] == DATALINK_PACKET_COMMAND)
				deferred_queue += list(list(transmitter, packet, receiver))
				metric_deferred++
			else
				// Beacons recur every second; skipping one is free (design doc §9).
				metric_dropped++
			continue
		if(!visible)
			continue
		dispatch(transmitter, packet, receiver)

/// Deliver a packet that already passed range/LOS to its receiver.
/datum/controller/subsystem/datalink/proc/dispatch(datum/datalink_node/transmitter, list/packet, datum/datalink_node/receiver)
	switch(packet["kind"])
		if(DATALINK_PACKET_BEACON)
			receiver.receive_beacon(packet, transmitter)
		if(DATALINK_PACKET_COMMAND)
			receiver.receive_command(packet, transmitter)
