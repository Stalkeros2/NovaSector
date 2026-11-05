// MODULE ID: DATALINK
// Unit tests (design doc §11): registration/cap, beacon reach + LOS blocking,
// NetID filtering + foreign detection, aging, dedupe caps, command dedupe and
// expiry, and vehicle relay queueing.
// Wrapped so the file compiles cleanly from tgstation.dme outside test builds.

#if defined(UNIT_TESTS) || defined(SPACEMAN_DMM)

/datum/unit_test/datalink_registration/Run()
	var/mob/living/carbon/human/holder = allocate(/mob/living/carbon/human, run_loc_floor_bottom_left)
	var/obj/item/mod/module/datalink/module = allocate(/obj/item/mod/module/datalink)
	var/datum/datalink_node/node = new(module, holder)

	TEST_ASSERT(node.register(), "First node failed to register")
	TEST_ASSERT(node.registered, "Node not marked as registered")
	TEST_ASSERT((node in GLOB.datalink_nodes), "Registered node missing from GLOB.datalink_nodes")
	TEST_ASSERT_EQUAL(node.relay_depth, DATALINK_RELAY_DEPTH_NONE, "Suit node must never relay (endpoint only)")
	TEST_ASSERT_EQUAL(node.range, DATALINK_RANGE_SUIT, "Suit node has the wrong range")
	node.unregister()
	TEST_ASSERT(!(node in GLOB.datalink_nodes), "Unregistered node still in GLOB.datalink_nodes")
	qdel(node)

	// Node cap (design doc §2): fill the registry, then expect rejection.
	var/list/fillers = list()
	var/list/failures = list()
	while(length(GLOB.datalink_nodes) < DATALINK_MAX_NODES)
		var/obj/item/mod/module/datalink/filler_module = allocate(/obj/item/mod/module/datalink)
		var/datum/datalink_node/filler = new(filler_module, holder)
		if(!filler.register())
			failures += "Filler node failed to register below the cap"
			break
		fillers += filler
	var/obj/item/mod/module/datalink/overflow_module = allocate(/obj/item/mod/module/datalink)
	var/datum/datalink_node/overflow = new(overflow_module, holder)
	if(overflow.register())
		failures += "Node registered past the DATALINK_MAX_NODES cap"
	qdel(overflow)
	for(var/datum/datalink_node/filler as anything in fillers)
		qdel(filler)
	for(var/reason in failures)
		TEST_FAIL(reason)

/datum/unit_test/datalink_beacons_and_los/Run()
	var/turf/base = run_loc_floor_bottom_left
	var/turf/peer_turf = locate(base.x + 3, base.y, base.z)
	var/mob/living/carbon/human/alpha = allocate(/mob/living/carbon/human, base)
	var/mob/living/carbon/human/beta = allocate(/mob/living/carbon/human, peer_turf)
	var/obj/item/mod/module/datalink/module_a = allocate(/obj/item/mod/module/datalink)
	var/obj/item/mod/module/datalink/module_b = allocate(/obj/item/mod/module/datalink)
	var/datum/datalink_node/node_a = new(module_a, alpha)
	var/datum/datalink_node/node_b = new(module_b, beta)
	var/list/failures = list()

	if(!node_a.register() || !node_b.register())
		TEST_FAIL("Nodes failed to register for the beacon test")
		qdel(node_a)
		qdel(node_b)
		return

	// 1. A wall between the two nodes blocks the beacon (design doc §6).
	var/turf/wall_turf = locate(base.x + 1, base.y, base.z)
	var/original_wall_type = wall_turf.type
	wall_turf.ChangeTurf(/turf/closed/wall)
	SSdatalink.los_cache.Cut()
	node_a.send_beacon()
	var/blocked = !(node_a.node_id in node_b.neighbors)
	// Restore before asserting so a failure can't leave the test room walled.
	wall_turf = locate(base.x + 1, base.y, base.z)
	wall_turf.ChangeTurf(original_wall_type)
	SSdatalink.los_cache.Cut()
	if(!blocked)
		failures += "Beacon passed through an opaque wall"

	// 2. With LOS clear, the beacon is delivered.
	node_a.send_beacon()
	if(!(node_a.node_id in node_b.neighbors))
		failures += "Beacon did not reach an in-range node with clear LOS"

	// 3. Mismatched NetID is dropped but detectable (design doc §8).
	node_b.net_id = "OTHER-NET"
	node_a.send_beacon()
	if(!node_b.get_foreign_strength())
		failures += "Foreign packet was not detected on a mismatched net"

	qdel(node_a)
	qdel(node_b)
	for(var/reason in failures)
		TEST_FAIL(reason)

/datum/unit_test/datalink_aging_dedupe_commands/Run()
	var/mob/living/carbon/human/holder = allocate(/mob/living/carbon/human, run_loc_floor_bottom_left)
	var/obj/item/mod/module/datalink/module = allocate(/obj/item/mod/module/datalink)
	var/datum/datalink_node/node = new(module, holder)
	var/list/failures = list()
	// receive_command() requires a registered, ACTIVE node.
	if(!node.register())
		failures += "Node failed to register for the command tests"
	var/list/beacon_packet = list(
		"kind" = DATALINK_PACKET_BEACON,
		"net" = node.net_id,
		"origin" = "FEEDFACE",
		"call" = "TESTER",
		"seq" = 1,
		"hop" = 1,
		"x" = run_loc_floor_bottom_left.x,
		"y" = run_loc_floor_bottom_left.y,
		"z" = run_loc_floor_bottom_left.z,
		"class" = DATALINK_CLASS_SUIT,
	)

	// Aging: a neighbor silent past the window is dropped; a fresh one stays.
	node.upsert_contact(beacon_packet)
	node.neighbors["FEEDFACE"].last_heard = world.time - (DATALINK_BEACON_INTERVAL * DATALINK_AGING_INTERVALS) - 1
	node.age()
	if("FEEDFACE" in node.neighbors)
		failures += "Stale neighbor was not aged out"
	beacon_packet["seq"] = 2
	node.upsert_contact(beacon_packet)
	node.age()
	if(!("FEEDFACE" in node.neighbors))
		failures += "Fresh neighbor was aged out incorrectly"

	// Dedupe ring stays bounded (design doc §4).
	for(var/index in 1 to DATALINK_MAX_DEDUPE + 10)
		node.remember_dedupe("ring[index]")
	if(length(node.dedupe) > DATALINK_MAX_DEDUPE)
		failures += "Dedupe ring exceeded its cap ([length(node.dedupe)] > [DATALINK_MAX_DEDUPE])"

	// Command dedupe: the same (origin, seq) is only accepted once.
	var/list/command_packet = list(
		"kind" = DATALINK_PACKET_COMMAND,
		"net" = node.net_id,
		"origin" = "FEEDFACE",
		"call" = "TESTER",
		"seq" = 42,
		"hop" = 1,
		"cmd" = DATALINK_CMD_PING,
		"tx" = run_loc_floor_bottom_left.x,
		"ty" = run_loc_floor_bottom_left.y,
		"tz" = run_loc_floor_bottom_left.z,
		"payload" = null,
		"priority" = DATALINK_PRIORITY_HIGH,
		"ttl" = DATALINK_COMMAND_TTL_SUIT,
		"time" = world.time,
	)
	node.receive_command(command_packet, null)
	node.receive_command(command_packet, null)
	if(length(node.active_commands) != 1)
		failures += "Command dedupe failed ([length(node.active_commands)] commands stored for one packet)"

	// Command expiry: stale commands are dropped by the aging pass.
	for(var/key in node.active_commands)
		var/datum/datalink_command/command = node.active_commands[key]
		command.expires_at = world.time - 1
	node.age()
	if(length(node.active_commands))
		failures += "Expired command was not cleared"

	qdel(node)
	for(var/reason in failures)
		TEST_FAIL(reason)

/datum/unit_test/datalink_vehicle_relay/Run()
	var/obj/item/mecha_parts/mecha_equipment/datalink/array = allocate(/obj/item/mecha_parts/mecha_equipment/datalink)
	var/datum/datalink_node/node = new(array, null)
	var/list/failures = list()

	TEST_ASSERT_EQUAL(node.relay_depth, DATALINK_RELAY_DEPTH_VEHICLE, "Vehicle node has the wrong relay depth")
	TEST_ASSERT_EQUAL(node.range, DATALINK_RANGE_VEHICLE, "Vehicle node has the wrong range")
	if(!node.register())
		TEST_FAIL("Vehicle node failed to register")
		qdel(node)
		return

	var/queued_before = length(SSdatalink.relay_queue)
	var/list/beacon_packet = list(
		"kind" = DATALINK_PACKET_BEACON,
		"net" = node.net_id,
		"origin" = "CAFEBABE",
		"call" = "RELAY",
		"seq" = 1,
		"hop" = 1,
		"x" = run_loc_floor_bottom_left.x,
		"y" = run_loc_floor_bottom_left.y,
		"z" = run_loc_floor_bottom_left.z,
		"class" = DATALINK_CLASS_SUIT,
	)
	node.receive_beacon(beacon_packet, null)
	if(length(SSdatalink.relay_queue) != queued_before + 1)
		failures += "Vehicle did not queue a relay for a hop-1 beacon"
	// A hop-2 beacon must not be relayed again (hop limit).
	var/list/deep_packet = beacon_packet.Copy()
	deep_packet["hop"] = 2
	deep_packet["seq"] = 2
	node.receive_beacon(deep_packet, null)
	if(length(SSdatalink.relay_queue) != queued_before + 1)
		failures += "Vehicle relayed past its relay depth"
	// Suit nodes must never relay.
	var/mob/living/carbon/human/suit_holder = allocate(/mob/living/carbon/human, run_loc_floor_bottom_left)
	var/obj/item/mod/module/datalink/module = allocate(/obj/item/mod/module/datalink)
	var/datum/datalink_node/suit_node = new(module, suit_holder)
	suit_node.register()
	suit_node.receive_beacon(beacon_packet, null)
	if(length(SSdatalink.relay_queue) != queued_before + 1)
		failures += "Suit node relayed a packet (must be endpoint-only)"

	qdel(suit_node)
	qdel(node)
	for(var/reason in failures)
		TEST_FAIL(reason)

/datum/unit_test/datalink_lpi/Run()
	var/mob/living/carbon/human/holder = allocate(/mob/living/carbon/human, run_loc_floor_bottom_left)
	var/obj/item/mod/module/datalink/module = allocate(/obj/item/mod/module/datalink)
	var/datum/datalink_node/node = new(module, holder)
	var/obj/item/mecha_parts/mecha_equipment/datalink/array = allocate(/obj/item/mecha_parts/mecha_equipment/datalink)
	var/datum/datalink_node/vehicle = new(array, null)
	var/list/failures = list()
	if(!node.register())
		failures += "Suit node failed to register"
	if(!vehicle.register())
		failures += "Vehicle node failed to register"
	var/turf/base = run_loc_floor_bottom_left
	var/list/relayed = list(
		"kind" = DATALINK_PACKET_BEACON,
		"net" = node.net_id,
		"origin" = "RELAYED1",
		"call" = "FARAWAY",
		"seq" = 1,
		"hop" = 2,
		"x" = base.x,
		"y" = base.y,
		"z" = base.z,
		"class" = DATALINK_CLASS_VEHICLE,
		"lpi" = FALSE,
	)
	// A pre-existing relayed contact gets purged the moment LPI engages.
	node.upsert_contact(relayed)
	node.set_lpi(TRUE)
	if("RELAYED1" in node.neighbors)
		failures += "Enabling LPI did not purge relayed contacts"
	// Direct (hop 1) beacons still connect...
	var/list/direct = relayed.Copy()
	direct["origin"] = "DIRECT01"
	direct["seq"] = 2
	direct["hop"] = 1
	node.receive_beacon(direct, null)
	if(!("DIRECT01" in node.neighbors))
		failures += "LPI node rejected a direct LOS (hop 1) beacon"
	// ...relayed (hop 2) beacons do not.
	var/list/again_relayed = relayed.Copy()
	again_relayed["origin"] = "RELAYED2"
	again_relayed["seq"] = 3
	node.receive_beacon(again_relayed, null)
	if("RELAYED2" in node.neighbors)
		failures += "LPI node accepted a relayed (hop 2) beacon"
	// An LPI-capable mech stays quiet: allies' packets are not rebroadcast.
	var/queued_before = length(SSdatalink.relay_queue)
	vehicle.set_lpi(TRUE)
	var/list/ally_packet = direct.Copy()
	ally_packet["origin"] = "ALLY0001"
	ally_packet["seq"] = 4
	vehicle.receive_beacon(ally_packet, null)
	if(length(SSdatalink.relay_queue) != queued_before)
		failures += "LPI vehicle relayed an ally packet"
	// Normal allies refuse to rebroadcast LPI-flagged packets either.
	vehicle.set_lpi(FALSE)
	var/list/lpi_packet = direct.Copy()
	lpi_packet["origin"] = "QUIET001"
	lpi_packet["seq"] = 5
	lpi_packet["lpi"] = TRUE
	vehicle.receive_beacon(lpi_packet, null)
	if(length(SSdatalink.relay_queue) != queued_before)
		failures += "A normal vehicle rebroadcast an LPI-flagged packet"
	qdel(vehicle)
	qdel(node)
	for(var/reason in failures)
		TEST_FAIL(reason)

#endif

