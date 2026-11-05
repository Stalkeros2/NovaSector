// MODULE ID: DATALINK
// Suit-side endpoint node carrier (design doc §2: suit module, endpoint only).
// Registers a node when worn, exposes the Datalink console, and treats the
// console as the module's "selected" interaction (design doc §10).

/obj/item/mod/module/datalink
	name = "\improper MOD tactical datalink module"
	desc = "A suit-integrated transceiver suite that grafted onto the MOD's own bus. \
		It beacons the wearer's position and command traffic to every other transceiver \
		on the same net, and paints the ones it hears right on the wearer's screen. \
		Net keys are stored on the module itself — lose it, and you lose the net."
	icon_state = "module"
	complexity = 1
	module_type = MODULE_TOGGLE
	idle_power_cost = DEFAULT_CHARGE_DRAIN * 0.5
	active_power_cost = DEFAULT_CHARGE_DRAIN * 0.5
	incompatible_modules = list(/obj/item/mod/module/datalink)
	tgui_id = "Datalink"
	/// Faction/net key — the security boundary (design doc §8)
	var/net_id = DATALINK_NET_NANOTRASEN
	/// Our network node; created when the suit is worn
	var/datum/datalink_node/node

/obj/item/mod/module/datalink/Destroy()
	QDEL_NULL(node)
	return ..()

/// Open the console instead of the default toggle behaviour (design doc §10).
/obj/item/mod/module/datalink/on_select(mob/activator)
	ensure_node()
	ui_interact(activator)

/obj/item/mod/module/datalink/on_equip()
	. = ..()
	ensure_node()
	node?.set_active(active)

/obj/item/mod/module/datalink/on_unequip()
	. = ..()
	node?.unregister()

/obj/item/mod/module/datalink/on_uninstall(deleting = FALSE)
	. = ..()
	QDEL_NULL(node)

/obj/item/mod/module/datalink/on_activation(mob/activator)
	. = ..()
	ensure_node()
	node?.set_active(TRUE)

/obj/item/mod/module/datalink/on_deactivation(mob/activator, display_message = TRUE, deleting = FALSE)
	. = ..()
	node?.set_active(FALSE)

/// Create our node if we're actually being worn. Returns the node or null.
/obj/item/mod/module/datalink/proc/ensure_node()
	if(node)
		return node
	if(!mod?.wearer)
		return null
	node = new(src, mod.wearer)
	if(!node.register())
		to_chat(mod.wearer, span_warning("[src] fails to join the net — no datalink slots remaining!"))
		qdel(node)
		node = null
	return node

/// Rewrites our net key, e.g. from a crypto fill key (design doc §8).
/obj/item/mod/module/datalink/proc/set_net_id(new_net_id)
	net_id = new_net_id
	if(node)
		node.net_id = new_net_id
		node.neighbors.Cut()
		node.selected_contact = null

/obj/item/mod/module/datalink/attackby(obj/item/attacking_item, mob/user, params)
	if(istype(attacking_item, /obj/item/datalink_key))
		var/obj/item/datalink_key/crypto_key = attacking_item
		set_net_id(crypto_key.net_id)
		balloon_alert(user, "net set to [net_id]")
		playsound(src, 'sound/machines/ping.ogg', 40, TRUE)
		return
	return ..()

/// Summary line for the main MODsuit window.
/obj/item/mod/module/datalink/add_ui_data()
	. = ..()
	.["datalink_net"] = net_id
	.["datalink_state"] = node?.state || DATALINK_STATE_SILENT
	.["datalink_contacts"] = length(node?.neighbors)

// --- Console (tgui) ---------------------------------------------------------

/obj/item/mod/module/datalink/ui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "Datalink", name)
		ui.open()

/obj/item/mod/module/datalink/ui_state(mob/user)
	return GLOB.datalink_state

/obj/item/mod/module/datalink/ui_data(mob/user)
	return datalink_ui_data(node)

/obj/item/mod/module/datalink/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return
	return datalink_ui_act(node, action, params, ui.user)
