/obj/item/clothing/mask/cigarette_holder
	name = "cigarette holder"
	desc = "A fancy cigarette holder. Can store a single cigarette inside it. If a cigarette is inside, it will intercept attacks aimed at you. Clicking yourself with it lets you take a drag."
	icon_state = "cig_holder"
	w_class = WEIGHT_CLASS_SMALL
	slot_flags = ITEM_SLOT_MASK

	var/obj/item/cigarette/stored_cig = null

// Update the icon to show if a cigarette is inserted and lit
/obj/item/clothing/mask/cigarette_holder/update_overlays()
	. = ..()
	if(stored_cig)
		. += mutable_appearance(stored_cig.icon, stored_cig.icon_state, FLOAT_LAYER-0.1)

// Interaction when clicking the holder itself (or clicking yourself while holding it)
/obj/item/clothing/mask/cigarette_holder/attack_self(mob/user)
	if(!stored_cig)
		balloon_alert(user, "no cigarette!")
		return

	if(!stored_cig.lit)
		balloon_alert(user, "cigarette unlit!")
		return

	balloon_alert(user, "smonking...")
	if(do_after(user, 3 SECONDS, src))
		stored_cig.long_exhale(user)
		return

/obj/item/clothing/mask/cigarette_holder/attack_self_secondary(mob/user, list/modifiers)
	if(stored_cig)
		if(stored_cig.lit)
			stored_cig.put_out()
			stored_cig = null
			balloon_alert(user, "cigarette snuffed out!")
			update_appearance(UPDATE_OVERLAYS)
			return SECONDARY_ATTACK_CANCEL_ATTACK_CHAIN
		user.put_in_hands(stored_cig)
		stored_cig = null
		balloon_alert(user, "cigarette poked out!")
		update_appearance(UPDATE_OVERLAYS)
		return SECONDARY_ATTACK_CANCEL_ATTACK_CHAIN
	return ..()

// Interaction when clicking the holder with another item (e.g., inserting a cigarette or lighting it)
/obj/item/clothing/mask/cigarette_holder/attackby(obj/item/I, mob/user, params)
	if(istype(I, /obj/item/cigarette))
		if(stored_cig)
			balloon_alert(user, "already full!")
			return
		if(!user.transferItemToLoc(I, src))
			return
		stored_cig = I
		balloon_alert(user, "[I] inserted!")
		update_appearance(UPDATE_OVERLAYS)
		return

	// Light the cigarette inside with any heat source
	if(stored_cig && !stored_cig.lit && I.get_temperature())
		stored_cig.light(span_notice("[user] lights the cigarette in the holder with [I]."))
		to_chat(user, span_notice("You light the cigarette in the holder with [I]."))
		update_appearance(UPDATE_OVERLAYS)
		return

	return ..()

// Clean up the stored cigarette when the holder is destroyed
/obj/item/clothing/mask/cigarette_holder/Destroy()
	QDEL_NULL(stored_cig)
	return ..()
