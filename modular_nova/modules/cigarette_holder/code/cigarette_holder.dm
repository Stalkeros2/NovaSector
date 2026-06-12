/obj/item/clothing/mask/cigarette_holder
	name = "cigarette holder"
	desc = "A fancy cigarette holder. Can store a single cigarette inside it. Clicking yourself with it lets you take a drag."
	icon = 'modular_nova/modules/cigarette_holder/icons/cigarette_holder.dmi'
	icon_state = "cig_holder"
	worn_icon = 'modular_nova/modules/cigarette_holder/icons/cigarette_holder.dmi'
	worn_icon_state = "cig_holder_w"
	lefthand_file = 'modular_nova/modules/cigarette_holder/icons/cigarette_holder_l.dmi'
	righthand_file = 'modular_nova/modules/cigarette_holder/icons/cigarette_holder_r.dmi'
	inhand_icon_state = "cig_holder_h"
	w_class = WEIGHT_CLASS_SMALL
	slot_flags = ITEM_SLOT_MASK

	var/obj/item/cigarette/stored_cig = null

// Update the icon to show if a cigarette is inserted and lit
/obj/item/clothing/mask/cigarette_holder/update_overlays()
	. = ..()
	if(stored_cig)
		var/mutable_appearance/cigarette = mutable_appearance(stored_cig.icon, stored_cig.icon_state, FLOAT_LAYER-0.1)
		. += cigarette
		cigarette.pixel_y += 4

/obj/item/clothing/mask/cigarette_holder/worn_overlays(mutable_appearance/standing, isinhands)
	. = ..()
	if(ishuman(loc))
		var/mob/living/carbon/human/user = loc
		if(isinhands)
			if(stored_cig)
				var/is_right = IS_RIGHT_INDEX(user.get_held_index_of_item(src))
				var/icon_file = is_right ? stored_cig.righthand_file : stored_cig.lefthand_file
				var/mutable_appearance/cigarette = mutable_appearance(icon_file, stored_cig.inhand_icon_state)
				. += cigarette
				switch(user.dir)
					if(WEST || EAST)
						cigarette.pixel_x -= 1
					if(NORTH)
						cigarette.pixel_y -= 1
		else
			if(stored_cig)
				var/mutable_appearance/cigarette = mutable_appearance(stored_cig.worn_icon, stored_cig.worn_icon_state)
				. += cigarette
				cigarette.pixel_y += 5

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
