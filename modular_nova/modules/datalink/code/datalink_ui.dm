// MODULE ID: DATALINK
// Shared console plumbing for the Datalink TGUI window: a custom ui_state that
// knows about both carrier types, plus the data/act procs each carrier calls.
// Holding the UI on the carrier items (not the node datum) keeps tgui's
// src-object checks trivial.

/// Wearer (or suit AI assistant) of a suit module / occupant of a mech.
GLOBAL_DATUM_INIT(datalink_state, /datum/ui_state/datalink, new)

/datum/ui_state/datalink/can_use_topic(datum/src_object, mob/user)
	if(!user?.client || user.stat == DEAD)
		return UI_CLOSE
	if(istype(src_object, /obj/item/mod/module/datalink))
		var/obj/item/mod/module/datalink/module = src_object
		if(!module.mod)
			return UI_CLOSE
		if(user == module.mod.wearer || user == module.mod.ai_assistant)
			return UI_INTERACTIVE
		return UI_CLOSE
	if(istype(src_object, /obj/item/mecha_parts/mecha_equipment/datalink))
		var/obj/item/mecha_parts/mecha_equipment/datalink/transceiver = src_object
		if(!transceiver.chassis)
			return UI_CLOSE
		if(user in transceiver.chassis.occupants)
			return UI_INTERACTIVE
		return UI_CLOSE
	return UI_CLOSE

/// Assemble the console payload for a node (design doc §7: contact list).
/proc/datalink_ui_data(datum/datalink_node/node)
	. = list()
	if(!node)
		.["active"] = FALSE
		.["state"] = DATALINK_STATE_SILENT
		.["contacts"] = list()
		.["commands"] = list()
		.["lpi"] = FALSE
		return
	.["active"] = node.state == DATALINK_STATE_ACTIVE
	.["state"] = node.state
	.["net_id"] = node.net_id
	.["callsign"] = node.get_callsign()
	.["power_class"] = node.power_class
	.["range"] = node.range
	.["relay_depth"] = node.relay_depth
	.["neighbors"] = length(node.neighbors)
	.["foreign"] = node.get_foreign_strength()
	.["lpi"] = node.lpi_mode
	.["selected"] = node.selected_contact
	var/list/contacts = list()
	for(var/datum/datalink_contact/contact as anything in node.get_contacts())
		contacts += list(list(
			"id" = contact.node_id,
			"name" = contact.callsign,
			"hops" = contact.hops,
			"dist" = round(contact.dist, 0.1),
			"power" = contact.power_class,
		))
	.["contacts"] = contacts
	var/list/commands = list()
	for(var/key in node.active_commands)
		var/datum/datalink_command/command = node.active_commands[key]
		commands += list(list(
			"origin" = command.origin_callsign,
			"text" = command.get_text(),
			"expires" = max(0, round((command.expires_at - world.time) / 10)),
			"priority" = command.priority,
		))
	.["commands"] = commands

/// Handle console button presses for a node. Returns TRUE on a state change.
/proc/datalink_ui_act(datum/datalink_node/node, action, params, mob/user)
	if(!node)
		return FALSE
	switch(action)
		if("select")
			var/selected = params["ref"]
			if(selected in node.neighbors)
				node.selected_contact = selected
				return TRUE
		if("toggle")
			if(!user)
				return FALSE
			if(node.suit_carrier)
				var/obj/item/mod/module/datalink/module = node.suit_carrier
				if(module.active)
					module.deactivate(user)
				else
					module.activate(user)
				return TRUE
			if(node.mech_carrier)
				node.mech_carrier.set_active(!node.mech_carrier.active)
				return TRUE
			return FALSE
		if("lpi")
			node.set_lpi(!node.lpi_mode)
			return TRUE
		if(DATALINK_CMD_PING, DATALINK_CMD_REGROUP, DATALINK_CMD_HOLD, DATALINK_CMD_MOVE_TO, DATALINK_CMD_FOCUS)
			return node.issue_command(action)
		if(DATALINK_CMD_CUSTOM)
			if(!user)
				return FALSE
			var/custom_text = tgui_input_text(user, "Custom datalink message:", "Datalink Transceiver", max_length = 120)
			if(!length(custom_text))
				return FALSE
			return node.issue_command(DATALINK_CMD_CUSTOM, custom_text)
	return FALSE
