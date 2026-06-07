/obj/item/clothing/mask/cigarette_holder
	name = "cigarette holder"
	desc = "A fancy cigarette holder. Can store a single cigarette inside it. If a cigarette is inside, it will intercept attacks aimed at you. Clicking yourself with it lets you take a drag."
	icon_state = "cig_holder"
	w_class = WEIGHT_CLASS_SMALL
	slot_flags = ITEM_SLOT_MASK

	var/obj/item/cigarette/stored_cig = null

// Update the icon to show if a cigarette is inserted and lit
/obj/item/clothing/mask/cigarette_holder/update_icon()
	if(stored_cig)
		if(stored_cig.lit)
			icon_state = "cig_holder_lit"
		else
			icon_state = "cig_holder_unlit"
	else
		icon_state = "cig_holder"

// Interaction when clicking the holder itself (or clicking yourself while holding it)
/obj/item/clothing/mask/cigarette_holder/attack_self(mob/user)
	if(!stored_cig)
		to_chat(user, span_notice("There is no cigarette in the holder to smoke."))
		return

	if(!stored_cig.lit)
		to_chat(user, span_notice("The cigarette in the holder isn't lit!"))
		return

	stored_cig.long_exhale(user)
	return

/obj/item/clothing/mask/cigarette_holder/attack_self_secondary(mob/user, list/modifiers)
	if(stored_cig)
		if(stored_cig.lit)
			stored_cig.put_out()
			stored_cig = null
			to_chat(user, span_notice("You snuff out the cigarette in the holder."))
			update_appearance()
			return SECONDARY_ATTACK_CANCEL_ATTACK_CHAIN
		user.put_in_hands(stored_cig)
		stored_cig = null
		to_chat(user, span_notice("You poke the cigarette out of the holder."))
		update_appearance()
		return SECONDARY_ATTACK_CANCEL_ATTACK_CHAIN
	return ..()

// Interaction when clicking the holder with another item (e.g., inserting a cigarette or lighting it)
/obj/item/clothing/mask/cigarette_holder/attackby(obj/item/I, mob/user, params)
	if(istype(I, /obj/item/cigarette))
		if(stored_cig)
			to_chat(user, span_warning("There is already a cigarette in the holder!"))
			return
		if(!user.transferItemToLoc(I, src))
			return
		stored_cig = I
		to_chat(user, span_notice("You insert [I] into the holder."))
		update_appearance()
		return

	// Light the cigarette inside with any heat source
	if(stored_cig && !stored_cig.lit && I.get_temperature())
		stored_cig.light(span_notice("[user] lights the cigarette in the holder with [I]."))
		to_chat(user, span_notice("You light the cigarette in the holder with [I]."))
		update_appearance()
		return

	// Remove cigarette with screwdriver or pen
	if(I.tool_behaviour == TOOL_SCREWDRIVER || istype(I, /obj/item/pen))
		if(stored_cig)
			stored_cig.forceMove(get_turf(src))
			to_chat(user, span_notice("You poke the cigarette out of the holder."))
			user.put_in_hands(stored_cig)
			stored_cig = null
			update_appearance()
			return

	return ..()

// Clean up the stored cigarette when the holder is destroyed
/obj/item/clothing/mask/cigarette_holder/Destroy()
	QDEL_NULL(stored_cig)
	return ..()
