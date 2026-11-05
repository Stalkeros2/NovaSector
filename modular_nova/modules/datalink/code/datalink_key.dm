// MODULE ID: DATALINK
// Crypto fill key (design doc §8): rewrites a datalink module's NetID.
// Possession of the module (or this key) is the net key — a deliberate hook.

/obj/item/datalink_key
	name = "\improper datalink crypto key"
	desc = "A wafer-style crypto filler for tactical datalink transceivers. \
		Swapping the key rewrites the target module's net id — for better or worse, \
		whoever holds the key holds the net."
	// TODO art: placeholder sprite (guaranteed-valid state from the module sheet)
	icon = 'icons/obj/clothing/modsuit/mod_modules.dmi'
	icon_state = "module"
	w_class = WEIGHT_CLASS_TINY
	/// Net id this key will write into a transceiver
	var/net_id = DATALINK_NET_NANOTRASEN

/obj/item/datalink_key/examine(mob/user)
	. = ..()
	. += span_notice("Currently programmed net id: [span_bold("[net_id]")].")
	. += span_notice("Use it in-hand to pick a different net id, or apply it to a \
		loose datalink module or transceiver to rewrite it.")

/obj/item/datalink_key/attack_self(mob/user)
	var/chosen_net = tgui_input_list(user, "Select net id", "Crypto Fill", GLOB.datalink_net_ids, src)
	if(!chosen_net || !user.Adjacent(src))
		return
	net_id = chosen_net
	balloon_alert(user, "net id: [net_id]")

/obj/item/datalink_key/Initialize(mapload)
	. = ..()
	// Unnamed keys start on a random net; preset subtypes keep theirs.
	if(type == /obj/item/datalink_key)
		net_id = pick(GLOB.datalink_net_ids)

/// Subtype presets for mapping/spawning.
/obj/item/datalink_key/nanotrasen
	net_id = DATALINK_NET_NANOTRASEN

/obj/item/datalink_key/sol
	net_id = DATALINK_NET_SOL

/obj/item/datalink_key/freelance
	net_id = DATALINK_NET_FREELANCE

/obj/item/datalink_key/unaffiliated
	net_id = DATALINK_NET_UNAFFILIATED
