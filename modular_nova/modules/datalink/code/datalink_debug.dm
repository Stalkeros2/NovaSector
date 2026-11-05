// MODULE ID: DATALINK
// Admin/debug tooling (design doc §10): dumps nodes, partitions, contacts and
// subsystem metrics on demand.

ADMIN_VERB(dump_datalink_network, R_DEBUG, "Datalink Network Dump", "Dump every datalink node, its contacts, and subsystem metrics.", ADMIN_CATEGORY_DEBUG)
	var/list/output = list(
		"=== TACTICAL DATALINK MESH ===",
		"Nodes: [length(GLOB.datalink_nodes)] / [DATALINK_MAX_NODES] | Relay queue: [length(SSdatalink.relay_queue)] | Deferred: [length(SSdatalink.deferred_queue)] | LOS cache: [length(SSdatalink.los_cache)]",
		"Metrics: beacons [SSdatalink.metric_beacons_sent], commands [SSdatalink.metric_commands_sent], relays [SSdatalink.metric_relays], aged-out [SSdatalink.metric_aged], deferred [SSdatalink.metric_deferred], dropped [SSdatalink.metric_dropped], LOS checks [SSdatalink.metric_los_checks] ([SSdatalink.metric_los_hits] cache hits)",
	)
	if(!length(GLOB.datalink_nodes))
		output += "(no registered nodes)"
	for(var/datum/datalink_node/node as anything in GLOB.datalink_nodes)
		if(QDELETED(node))
			continue
		var/turf/node_turf = get_turf(node.position_source)
		output += "  [node.node_id] '[node.callsign]' net=[node.net_id] state=[node.state][node.lpi_mode ? " LPI" : ""] class=[node.power_class] range=[node.range] depth=[node.relay_depth] pos=([node_turf ? "[node_turf.x],[node_turf.y],[node_turf.z]" : "null"]) neighbors=[length(node.neighbors)] commands=[length(node.active_commands)] foreign=[node.get_foreign_strength()]%"
		for(var/datum/datalink_contact/contact as anything in node.get_contacts())
			output += "     - '[contact.callsign]' hops=[contact.hops] dist=[round(contact.dist, 0.1)] at ([contact.x],[contact.y],[contact.z]) last_heard=[round((world.time - contact.last_heard) / 10, 0.1)]s ago"
	to_chat(user, span_notice(jointext(output, "\n")))
	log_admin("[key_name(user)] dumped the datalink network: [length(GLOB.datalink_nodes)] nodes.")
