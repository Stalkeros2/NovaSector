// MODULE ID: DATALINK
// One network node per installed datalink module (design doc §4). Owned by the
// carrier item; holds a bounded neighbor table, dedupe ring, active commands
// and the client-side HUD controller. No persistent links, no graph — aging
// replaces link-down events.

/datum/datalink_contact
	/// node_id of the remote contact
	var/node_id
	/// Last callsign we heard from it
	var/callsign
	var/x
	var/y
	var/z
	/// 1 for direct contacts, 2 for relayed ones
	var/hops
	/// DATALINK_CLASS_* of the remote node
	var/power_class
	/// world.time of the beacon that last refreshed this entry
	var/last_heard
	/// Distance from our position source, recomputed by get_contacts()
	var/dist = 0

/datum/datalink_contact/New(id, list/packet)
	node_id = id
	update(packet, world.time)

/// Refresh this entry from a beacon packet; lower hop counts always win.
/datum/datalink_contact/proc/update(list/packet, now)
	callsign = packet["call"]
	x = packet["x"]
	y = packet["y"]
	z = packet["z"]
	power_class = packet["class"]
	hops = isnull(hops) ? packet["hop"] : min(hops, packet["hop"])
	last_heard = now

/datum/datalink_node
	/// Stable random id for this node
	var/node_id
	/// Faction/net key — the security boundary (design doc §8)
	var/net_id
	/// Display name, refreshed on each beacon
	var/callsign
	/// Atom that gives us our position (the wearer's mob, or the mecha)
	var/atom/movable/position_source
	/// The MOD module that owns us, if any
	var/obj/item/mod/module/datalink/suit_carrier
	/// The mech transceiver that owns us, if any
	var/obj/item/mecha_parts/mecha_equipment/datalink/mech_carrier
	/// DATALINK_CLASS_SUIT or DATALINK_CLASS_VEHICLE
	var/power_class
	/// TX/RX range in tiles
	var/range
	/// How many hops from origin we will rebroadcast (0 for endpoint suits)
	var/relay_depth
	/// LPI (low-probability-of-intercept): direct-LOS contacts only,
	/// no relaying in either direction, quiet emissions.
	var/lpi_mode = FALSE
	/// DATALINK_STATE_* — ACTIVE transmits, SILENT only listens
	var/state = DATALINK_STATE_SILENT
	/// Whether we are part of GLOB.datalink_nodes
	var/registered = FALSE
	/// Sequence number for beacons and commands we originate
	var/seq = 0
	/// Flood tokens, refilled once per network tick, spent on command relays
	var/flood_tokens = DATALINK_FLOOD_RATE
	/// NodeID -> /datum/datalink_contact, bounded and aged out by the subsystem
	var/list/neighbors = list()
	/// Dedupe keys -> world.time, bounded ring (design doc §4)
	var/list/dedupe = list()
	/// "origin:seq" -> /datum/datalink_command
	var/list/active_commands = list()
	/// Contact selected in the console UI
	var/selected_contact
	/// Jittered beacon timer id
	var/beacon_timer
	/// Last foreign packet we sensed (design doc §8)
	var/foreign_last_seen = 0
	var/foreign_dist = 0
	var/foreign_range = 1
	/// world.time of the last foreign-detection warning
	var/foreign_warned_at = 0
	/// Client-side marker controller (design doc §7 option B)
	var/datum/datalink_hud/hud

/datum/datalink_node/New(obj/item/carrier, atom/movable/source)
	position_source = source
	if(istype(carrier, /obj/item/mod/module/datalink))
		var/obj/item/mod/module/datalink/module = carrier
		suit_carrier = module
		power_class = DATALINK_CLASS_SUIT
		range = DATALINK_RANGE_SUIT
		relay_depth = DATALINK_RELAY_DEPTH_NONE
		net_id = module.net_id
	else if(istype(carrier, /obj/item/mecha_parts/mecha_equipment/datalink))
		var/obj/item/mecha_parts/mecha_equipment/datalink/transceiver = carrier
		mech_carrier = transceiver
		power_class = DATALINK_CLASS_VEHICLE
		range = DATALINK_RANGE_VEHICLE
		relay_depth = DATALINK_RELAY_DEPTH_VEHICLE
		net_id = transceiver.net_id
	callsign = get_callsign()
	node_id = generate_node_id()
	hud = new(src)

/datum/datalink_node/Destroy()
	unregister()
	if(beacon_timer)
		deltimer(beacon_timer)
		beacon_timer = null
	QDEL_NULL(hud)
	neighbors.Cut()
	dedupe.Cut()
	active_commands.Cut()
	position_source = null
	suit_carrier = null
	mech_carrier = null
	return ..()

/// Random, collision-free node id (design doc §4).
/datum/datalink_node/proc/generate_node_id()
	var/new_id
	do
		new_id = "[num2hex(rand(0, 65535), 4)][num2hex(rand(0, 65535), 4)]"
		for(var/datum/datalink_node/other as anything in GLOB.datalink_nodes)
			if(other.node_id == new_id)
				new_id = null
				break
	while(!new_id)
	return new_id

/// The mob a client-side UI/HUD should attach to.
/datum/datalink_node/proc/get_user()
	if(suit_carrier?.mod?.wearer)
		return suit_carrier.mod.wearer
	if(mech_carrier?.chassis && length(mech_carrier.chassis.occupants))
		return mech_carrier.chassis.occupants[1]
	return null

/// Best available display name for our holder.
/datum/datalink_node/proc/get_callsign()
	if(suit_carrier?.mod?.wearer)
		return suit_carrier.mod.wearer.get_authentification_name("Unknown")
	if(mech_carrier?.chassis)
		return mech_carrier.chassis.name
	return callsign || "unknown"

/// Suit nodes only transmit while the suit is sealed and charged.
/datum/datalink_node/proc/has_power()
	if(suit_carrier)
		if(!suit_carrier.mod || !suit_carrier.mod.active)
			return FALSE
		return suit_carrier.check_power(1)
	return TRUE

// ---------------------------------------------------------------------------
// Registration and beaconing (design doc §5.1)
// ---------------------------------------------------------------------------

/datum/datalink_node/proc/register()
	if(registered)
		return TRUE
	if(length(GLOB.datalink_nodes) >= DATALINK_MAX_NODES)
		return FALSE
	GLOB.datalink_nodes += src
	registered = TRUE
	if(state != DATALINK_STATE_DESTROYED)
		state = DATALINK_STATE_ACTIVE
	start_beaconing()
	return TRUE

/datum/datalink_node/proc/unregister()
	stop_beaconing()
	registered = FALSE
	state = DATALINK_STATE_SILENT
	GLOB.datalink_nodes -= src
	hud?.clear()

/**
 * Enable/disable transmission. Called by the carrier item (module toggle, mech
 * equipment toggle); registration is retried here so a node that failed the
 * 128-node cap can come online when a slot frees up.
 */
/datum/datalink_node/proc/set_active(new_active)
	if(!new_active)
		state = DATALINK_STATE_SILENT
		stop_beaconing()
		// Drop our HUD markers immediately, don't wait for the next tick.
		hud?.clear()
		return
	if(state == DATALINK_STATE_DESTROYED)
		return
	register()
	if(registered)
		state = DATALINK_STATE_ACTIVE
		start_beaconing()

/datum/datalink_node/proc/start_beaconing()
	if(beacon_timer)
		return
	beacon_tick()

/datum/datalink_node/proc/stop_beaconing()
	if(beacon_timer)
		deltimer(beacon_timer)
		beacon_timer = null

/// Toggle LPI (low-probability-of-intercept) mode: direct-LOS contacts only,
/// no relaying in either direction, and foreign nets need LOS to spot us.
/datum/datalink_node/proc/set_lpi(new_lpi)
	if(lpi_mode == new_lpi)
		return
	lpi_mode = new_lpi
	if(lpi_mode)
		// Drop relayed (2-hop) contacts immediately; direct ones stay.
		for(var/id in neighbors.Copy())
			var/datum/datalink_contact/contact = neighbors[id]
			if(contact.hops > 1)
				neighbors -= id
		if(selected_contact && !(selected_contact in neighbors))
			selected_contact = null
	hud?.mark_dirty()

/// Jittered ~1 Hz heartbeat (design doc §3.2, §9).
/datum/datalink_node/proc/beacon_tick()
	beacon_timer = null
	if(registered && state == DATALINK_STATE_ACTIVE && has_power())
		send_beacon()
	if(!registered || state != DATALINK_STATE_ACTIVE)
		return
	var/next_interval = DATALINK_BEACON_INTERVAL + rand(-DATALINK_BEACON_JITTER, DATALINK_BEACON_JITTER)
	beacon_timer = addtimer(CALLBACK(src, PROC_REF(beacon_tick)), max(DATALINK_BEACON_MIN_INTERVAL, next_interval), TIMER_STOPPABLE | TIMER_UNIQUE | TIMER_OVERRIDE)

/// Build and transmit our own beacon (identity + position piggybacked, §5.2).
/datum/datalink_node/proc/send_beacon()
	var/turf/position = get_turf(position_source)
	if(!position)
		return
	callsign = get_callsign()
	seq++
	var/list/packet = list(
		"kind" = DATALINK_PACKET_BEACON,
		"net" = net_id,
		"origin" = node_id,
		"call" = callsign,
		"seq" = seq,
		"hop" = 1,
		"x" = position.x,
		"y" = position.y,
		"z" = position.z,
		"class" = power_class,
		"lpi" = lpi_mode,
	)
	SSdatalink.fanout(src, packet)

// ---------------------------------------------------------------------------
// Receiving (design doc §5.1, §5.3)
// ---------------------------------------------------------------------------

/datum/datalink_node/proc/receive_beacon(list/packet, datum/datalink_node/transmitter)
	// A disabled (SILENT) node neither transmits nor receives (design §4).
	if(!registered || state != DATALINK_STATE_ACTIVE)
		return
	// LPI only connects to direct LOS peers: reject anything relayed (hop > 1).
	if(lpi_mode && packet["hop"] > 1)
		return
	// Beacons dedupe per (origin, seq, hop): two paths for the same hop are
	// redundant, but a direct hop-1 still counts after a hop-2 sighting.
	var/key = "B:[packet["origin"]]:[packet["seq"]]:[packet["hop"]]"
	if(dedupe_seen(key))
		return
	remember_dedupe(key)
	upsert_contact(packet)
	// Relay once per beacon, gated by depth (suit = never). LPI nodes stay
	// quiet, and LPI-flagged packets are never rebroadcast by anyone.
	if(relay_depth > packet["hop"] && !lpi_mode && !packet["lpi"] && !dedupe_seen("RB:[packet["origin"]]:[packet["seq"]]"))
		remember_dedupe("RB:[packet["origin"]]:[packet["seq"]]")
		var/list/relay_packet = packet.Copy()
		relay_packet["hop"] = packet["hop"] + 1
		SSdatalink.queue_relay(src, relay_packet)
	hud?.mark_dirty()

/datum/datalink_node/proc/receive_command(list/packet, datum/datalink_node/transmitter)
	// Disabled nodes process nothing: no command markers, no chat spam.
	if(!registered || state != DATALINK_STATE_ACTIVE)
		return
	// LPI only hears direct LOS traffic - ignore relayed commands too.
	if(lpi_mode && packet["hop"] > 1)
		return

	var/key = "C:[packet["origin"]]:[packet["seq"]]"
	if(!dedupe_seen(key))
		remember_dedupe(key)
		var/datum/datalink_command/command = new(packet)
		active_commands[key] = command
		notify_holder(command)
		hud?.mark_dirty()
	// Independent relay gate: flood once per packet per node, TTL-bounded.
	// LPI: we never rebroadcast, and LPI-flagged traffic is never rebroadcast.
	if(relay_depth > packet["hop"] && packet["ttl"] > 1 && !lpi_mode && !packet["lpi"] && !dedupe_seen("RC:[packet["origin"]]:[packet["seq"]]"))
		if(flood_tokens < 1)
			return
		flood_tokens -= 1
		remember_dedupe("RC:[packet["origin"]]:[packet["seq"]]")
		var/list/relay_packet = packet.Copy()
		relay_packet["hop"] = packet["hop"] + 1
		relay_packet["ttl"] = packet["ttl"] - 1
		SSdatalink.queue_relay(src, relay_packet)

/datum/datalink_node/proc/notify_holder(datum/datalink_command/command)
	var/mob/living/user = get_user()
	if(!user)
		return
	to_chat(user, span_notice("<b>[span_info("DATALINK")] [command.origin_callsign]:</b> [command.get_text()]"))
	if(command.priority >= DATALINK_PRIORITY_HIGH)
		user.balloon_alert(user, "new datalink command!")

/// Insert or refresh a neighbor from a beacon (design doc §4).
/datum/datalink_node/proc/upsert_contact(list/packet)
	var/id = packet["origin"]
	var/datum/datalink_contact/existing = neighbors[id]
	if(existing)
		existing.update(packet, world.time)
		return
	if(length(neighbors) >= DATALINK_MAX_NEIGHBORS)
		// Bounded table: evict the stalest entry rather than dropping fresh data.
		var/stalest_id
		var/stalest_time = INFINITY
		for(var/other_id in neighbors)
			var/datum/datalink_contact/other = neighbors[other_id]
			if(other.last_heard < stalest_time)
				stalest_time = other.last_heard
				stalest_id = other_id
		neighbors -= stalest_id
	neighbors[id] = new /datum/datalink_contact(id, packet)

// ---------------------------------------------------------------------------
// Originating commands (design doc §5.3)
// ---------------------------------------------------------------------------

/datum/datalink_node/proc/send_command(cmd_type, target_x, target_y, target_z, payload = null, priority = DATALINK_PRIORITY_NORMAL)
	if(!registered || state != DATALINK_STATE_ACTIVE)
		return FALSE
	seq++
	var/list/packet = list(
		"kind" = DATALINK_PACKET_COMMAND,
		"net" = net_id,
		"origin" = node_id,
		"call" = get_callsign(),
		"seq" = seq,
		"hop" = 1,
		"cmd" = cmd_type,
		"tx" = target_x,
		"ty" = target_y,
		"tz" = target_z,
		"payload" = payload,
		"priority" = priority,
		"ttl" = (power_class == DATALINK_CLASS_VEHICLE ? DATALINK_COMMAND_TTL_VEHICLE : DATALINK_COMMAND_TTL_SUIT),
		"time" = world.time,
		"lpi" = lpi_mode,
	)
	SSdatalink.fanout(src, packet)
	if(priority >= DATALINK_PRIORITY_HIGH)
		// Redundant second pass: catches nodes that moved into range mid-window.
		addtimer(CALLBACK(src, PROC_REF(retransmit), packet), DATALINK_COMMAND_RETRANSMIT, TIMER_STOPPABLE)
	return TRUE

/datum/datalink_node/proc/retransmit(list/packet)
	if(!registered || state != DATALINK_STATE_ACTIVE)
		return
	SSdatalink.fanout(src, packet)

/// Translate a console button press into a command packet.
/datum/datalink_node/proc/issue_command(cmd_type, payload = null)
	switch(cmd_type)
		if(DATALINK_CMD_PING, DATALINK_CMD_REGROUP, DATALINK_CMD_HOLD)
			var/turf/position = get_turf(position_source)
			if(!position)
				return FALSE
			return send_command(cmd_type, position.x, position.y, position.z, null, DATALINK_PRIORITY_HIGH)
		if(DATALINK_CMD_MOVE_TO, DATALINK_CMD_FOCUS)
			var/datum/datalink_contact/target = neighbors[selected_contact]
			if(!target)
				return FALSE
			return send_command(cmd_type, target.x, target.y, target.z, null, DATALINK_PRIORITY_NORMAL)
		if(DATALINK_CMD_CUSTOM)
			if(!length(payload))
				return FALSE
			return send_command(cmd_type, null, null, null, payload, DATALINK_PRIORITY_HIGH)
	return FALSE

// ---------------------------------------------------------------------------
// Foreign detection (design doc §8)
// ---------------------------------------------------------------------------

/datum/datalink_node/proc/note_foreign(dist, max_range)
	foreign_last_seen = world.time
	foreign_dist = dist
	foreign_range = max(1, max_range)
	if(world.time - foreign_warned_at < DATALINK_FOREIGN_WARNING_COOLDOWN)
		return
	foreign_warned_at = world.time
	var/mob/living/user = get_user()
	if(!user)
		return
	to_chat(user, span_warning("Foreign datalink emissions detected nearby (signal strength ~[get_foreign_strength()]%)."))
	user.balloon_alert(user, "foreign datalink in range!")

/// 0 when nothing foreign is sensed, otherwise 1–100 scaled by distance.
/datum/datalink_node/proc/get_foreign_strength()
	if(!foreign_last_seen || world.time - foreign_last_seen > DATALINK_FOREIGN_DECAY)
		return 0
	return max(1, round(100 * (1 - (foreign_dist / foreign_range))))

// ---------------------------------------------------------------------------
// Aging (design doc §5.1, §9)
// ---------------------------------------------------------------------------

/// Called once per network tick by SSdatalink. Idempotent and bounded.
/datum/datalink_node/proc/age(now = world.time)
	for(var/id in neighbors.Copy())
		var/datum/datalink_contact/contact = neighbors[id]
		var/window = DATALINK_BEACON_INTERVAL * DATALINK_AGING_INTERVALS
		if(contact.hops > 1)
			window *= DATALINK_RELAYED_AGING_MULTIPLIER
		if(now - contact.last_heard > window)
			neighbors -= id
			SSdatalink.metric_aged++
			if(selected_contact == id)
				selected_contact = null
	for(var/key in dedupe.Copy())
		if(now - dedupe[key] > DATALINK_DEDUPE_WINDOW)
			dedupe -= key
	for(var/key in active_commands.Copy())
		var/datum/datalink_command/command = active_commands[key]
		if(now > command.expires_at)
			active_commands -= key
			hud?.mark_dirty()
	flood_tokens = min(DATALINK_FLOOD_RATE, flood_tokens + 1)
	if(foreign_last_seen && now - foreign_last_seen > DATALINK_FOREIGN_DECAY)
		foreign_last_seen = 0
		foreign_dist = 0
		hud?.mark_dirty()

/// TRUE if we already handled this dedupe key.
/datum/datalink_node/proc/dedupe_seen(key)
	return key in dedupe

/// Record a dedupe key, evicting the oldest entry past the ring cap.
/datum/datalink_node/proc/remember_dedupe(key)
	if(key in dedupe)
		return
	if(length(dedupe) >= DATALINK_MAX_DEDUPE)
		dedupe -= dedupe[1]
	dedupe[key] = world.time

// ---------------------------------------------------------------------------
// Contacts for HUD/console (design doc §4, §7)
// ---------------------------------------------------------------------------

/// All neighbors sorted nearest-first, capped at DATALINK_MAX_CONTACTS.
/datum/datalink_node/proc/get_contacts()
	var/list/result = list()
	for(var/id in neighbors)
		result += neighbors[id]
	var/turf/origin = get_turf(position_source)
	for(var/datum/datalink_contact/contact as anything in result)
		var/turf/contact_turf = locate(contact.x, contact.y, contact.z)
		if(origin && contact_turf)
			contact.dist = get_dist_euclidean(origin, contact_turf)
		else
			contact.dist = INFINITY
	// Insertion sort — the list is at most DATALINK_MAX_NEIGHBORS long.
	for(var/index in 2 to length(result))
		var/datum/datalink_contact/current = result[index]
		var/sort_index = index - 1
		while(sort_index >= 1 && result[sort_index].dist > current.dist)
			result[sort_index + 1] = result[sort_index]
			sort_index--
		result[sort_index + 1] = current
	if(length(result) > DATALINK_MAX_CONTACTS)
		result.Cut(DATALINK_MAX_CONTACTS + 1)
	return result
