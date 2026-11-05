// MODULE ID: DATALINK
// Exosuit utility-slot transceiver (design doc §2: vehicle module, range 60,
// relay depth 2). Becomes a node while installed; occupants get an action
// button that opens the console (design doc §10).

/obj/item/mecha_parts/mecha_equipment/datalink
	name = "datalink transceiver array"
	desc = "A utility-slot radio transceiver that beacons the exosuit's position and \
		command traffic to every other transceiver on the same net. Its amplified uplink \
		lets it rebroadcast for other nodes, extending the net by up to two hops. \
		Net keys are stored on the unit — lose it, and you lose the net."
	icon_state = "mecha_radio"
	equipment_slot = MECHA_UTILITY
	can_be_toggled = TRUE
	active_label = "Datalink"
	unstackable = TRUE
	/// Action button opens the console instead of toggling (see Trigger below)
	action_type = /datum/action/vehicle/sealed/mecha/equipment/datalink
	/// Faction/net key — the security boundary (design doc §8)
	var/net_id = DATALINK_NET_NANOTRASEN
	/// Our network node; created while installed on a chassis
	var/datum/datalink_node/node

/obj/item/mecha_parts/mecha_equipment/datalink/attach(obj/vehicle/sealed/mecha/new_mecha, attach_right = FALSE)
	..()
	ensure_node(new_mecha)

/obj/item/mecha_parts/mecha_equipment/datalink/detach(atom/moveto)
	QDEL_NULL(node)
	..()

/obj/item/mecha_parts/mecha_equipment/datalink/Destroy()
	QDEL_NULL(node)
	return ..()

/obj/item/mecha_parts/mecha_equipment/datalink/set_active(new_active)
	. = ..()
	if(node)
		node.set_active(active)

/// Create our node while installed. Returns the node or null.
/obj/item/mecha_parts/mecha_equipment/datalink/proc/ensure_node(obj/vehicle/sealed/mecha/chassis_to_use)
	if(node)
		node.position_source = chassis_to_use || chassis
		node.set_active(active)
		return node
	var/obj/vehicle/sealed/mecha/position = chassis_to_use || chassis
	if(!position)
		return null
	node = new(src, position)
	if(!node.register())
		for(var/mob/occupant as anything in position.occupants)
			to_chat(occupant, span_warning("[src] fails to join the net — no datalink slots remaining!"))
		qdel(node)
		node = null
		return null
	node.set_active(active)
	return node

/// Rewrites our net key, e.g. from a crypto fill key (design doc §8).
/obj/item/mecha_parts/mecha_equipment/datalink/proc/set_net_id(new_net_id)
	net_id = new_net_id
	if(node)
		node.net_id = new_net_id
		node.neighbors.Cut()
		node.selected_contact = null

/obj/item/mecha_parts/mecha_equipment/datalink/attackby(obj/item/attacking_item, mob/user, params)
	if(istype(attacking_item, /obj/item/datalink_key))
		var/obj/item/datalink_key/crypto_key = attacking_item
		set_net_id(crypto_key.net_id)
		balloon_alert(user, "net set to [net_id]")
		playsound(src, 'sound/machines/ping.ogg', 40, TRUE)
		return
	return ..()

// --- Console (tgui) ---------------------------------------------------------

/obj/item/mecha_parts/mecha_equipment/datalink/ui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "Datalink", name)
		ui.open()

/obj/item/mecha_parts/mecha_equipment/datalink/ui_state(mob/user)
	return GLOB.datalink_state

/obj/item/mecha_parts/mecha_equipment/datalink/ui_data(mob/user)
	return datalink_ui_data(node)

/obj/item/mecha_parts/mecha_equipment/datalink/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return
	return datalink_ui_act(node, action, params, ui.user)

/**
 * Occupant action button: opens the console.
 *
 * Deliberately does NOT call ..(): the parent equipment action toggles the
 * equipment on press, while this button opens the transceiver console — the
 * console carries its own ON/OFF toggle (mirroring the MODsuit module UX).
 * Availability and signal checks are replicated from /datum/action/Trigger.
 */
/datum/action/vehicle/sealed/mecha/equipment/datalink/Trigger(mob/clicker, trigger_flags)
	SHOULD_CALL_PARENT(FALSE) //We are snowflaked from parent
	if(!(trigger_flags & TRIGGER_FORCE_AVAILABLE) && !IsAvailable(feedback = TRUE))
		return FALSE
	if(SEND_SIGNAL(src, COMSIG_ACTION_TRIGGER, src) & COMPONENT_ACTION_BLOCK_TRIGGER)
		return FALSE
	if(!chassis || !(owner in chassis.occupants) || !equipment)
		return FALSE
	var/obj/item/mecha_parts/mecha_equipment/datalink/transceiver = equipment
	transceiver.ui_interact(owner)
	return TRUE
