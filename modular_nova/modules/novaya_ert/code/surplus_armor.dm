// THE STANDARD COLORS FOR USE WILL BE BELOW

#define CIN_WINTER_COLORS "#bbbbc9"
#define CIN_MOUNTAIN_DESERT_COLORS "#aa6d4c"
#define CIN_FOREST_COLORS "#6D6D51"
#define CIN_MARINE_COLORS "#51517b"
#define CIN_EVIL_COLORS "#5d5d66"

#define CIN_WINTER_COLORS_COMPLIMENT "#838392"
#define CIN_MOUNTAIN_DESERT_COLORS_COMPLIMENT "#a37e45"
#define CIN_FOREST_COLORS_COMPLIMENT "#474734"
#define CIN_MARINE_COLORS_COMPLIMENT "#39394d"
#define CIN_EVIL_COLORS_COMPLIMENT "#3d3d46"

// Shared Armor Datum
// CIN armor is decently tough against bullets and wounding, but flounders when lasers enter the play, because it wasn't designed to protect against those much

/datum/armor/cin_surplus_armor
	melee = 30
	bullet = 40
	laser = 10
	energy = 10
	bomb = 40
	fire = 50
	acid = 50
	wound = 20

/datum/client_colour/glass_colour/predator_vision
	color = list(1,0,0,0, 0,0.5,0.5,0, 0,0.5,0.5,0, 0,0,0,1, 0,0,0,0)

// Hats

/obj/item/clothing/head/helmet/cin_surplus_helmet
	name = "\improper GZ-03 combat helmet"
	desc = "An outdated service helmet previously used by CIN military forces. The design dates back to the years leading up to CIN - SolFed border war, and was in service until the advent of VOSKHOD powered armor becoming standard issue."
	worn_icon = 'modular_nova/modules/novaya_ert/icons/surplus_armor/surplus_armor.dmi'
	icon = 'modular_nova/modules/novaya_ert/icons/surplus_armor/surplus_armor_object.dmi'
	icon_state = "helmet"
	armor_type = /datum/armor/cin_surplus_armor
	supports_variations_flags = CLOTHING_SNOUTED_VARIATION_NO_NEW_ICON
	var/predator_vision = FALSE
	var/thermal_overlay = "helmet_predator"
	var/mob/living/carbon/current_user
	actions_types = list(/datum/action/item_action/toggle_predator_helmet)

/datum/action/item_action/toggle_predator_helmet
	name = "Toggle Thermal Imaging"

/datum/action/item_action/toggle_predator_helmet/Trigger(trigger_flags)
	var/obj/item/clothing/head/helmet/cin_surplus_helmet/my_helmet = target
	if(!my_helmet.current_user)
		return
	my_helmet.predator_vision = !my_helmet.predator_vision
	if(my_helmet.predator_vision)
		to_chat(owner, span_notice("You turn thermals on."))
		my_helmet.enable_predator()
	else
		to_chat(owner, span_notice("You turn thermals off."))
		my_helmet.disable_predator()
	my_helmet.update_appearance()

/obj/item/clothing/head/helmet/cin_surplus_helmet/equipped(mob/user, slot)
	. = ..()
	current_user = user

/obj/item/clothing/head/helmet/cin_surplus_helmet/proc/enable_predator(mob/user)
	if(current_user)
		var/obj/item/organ/eyes/my_eyes = current_user.get_organ_by_type(/obj/item/organ/eyes)
		if(my_eyes)
			my_eyes.color_cutoffs = list(255, 0, 0)
			my_eyes.sight_flags |= SEE_MOBS
			my_eyes.flash_protect = FLASH_PROTECTION_SENSITIVE
		current_user.add_client_colour(/datum/client_colour/glass_colour/predator_vision, REF(src))
		current_user.update_sight()

/obj/item/clothing/head/helmet/cin_surplus_helmet/proc/disable_predator()
	if(current_user)
		var/obj/item/organ/eyes/my_eyes = current_user.get_organ_by_type(/obj/item/organ/eyes)
		if(my_eyes)
			my_eyes.color_cutoffs = initial(my_eyes.color_cutoffs)
			my_eyes.sight_flags = initial(my_eyes.sight_flags)
			my_eyes.flash_protect = initial(my_eyes.flash_protect)
		current_user.remove_client_colour(REF(src))
		current_user.update_sight()

/obj/item/clothing/head/helmet/cin_surplus_helmet/click_alt(mob/user)
	if(!current_user)
		return

	predator_vision = !predator_vision
	if(predator_vision)
		to_chat(user, span_notice("You turn thermals on."))
		enable_predator()
	else
		to_chat(user, span_notice("You turn thermals off."))
		disable_predator()
	update_appearance()
	return CLICK_ACTION_SUCCESS

/obj/item/clothing/head/helmet/cin_surplus_helmet/dropped(mob/user)
	. = ..()
	disable_predator()
	current_user = null

/obj/item/clothing/head/helmet/cin_surplus_helmet/Destroy()
	disable_predator()
	current_user = null
	return ..()

/obj/item/clothing/head/helmet/cin_surplus_helmet/update_icon_state()
	. = ..()
	icon_state = predator_vision ? "helmet_active" :"helmet"

/obj/item/clothing/head/helmet/cin_surplus_helmet/update_overlays()
	. = ..()
	if(predator_vision)
		. += thermal_overlay
		. += emissive_appearance(icon, thermal_overlay, src)

/obj/item/clothing/head/helmet/cin_surplus_helmet/examine_more(mob/user)
	. = ..()

	. += "The GZ-03 series of coalition armor was a collaborative project between the NRI and TransOrbital \
		to develop a frontline soldier's armor set that could withstand attacks from the Solar Federation's \
		then relatively new pulse ballistics. The design itself is based upon a far older pattern \
		of armor originally developed by SolFed themselves, which was the standard pattern of armor design \
		granted to the first colony ships leaving Sol. Armor older than any of the CIN member states, \
		upgraded with modern technology. This helmet in particular encloses the entire head save for \
		the face, and should come with a glass visor and relatively comfortable internal padding. Should, \
		anyways, surplus units such as this are infamous for arriving with several missing accessories."

	return .

// Undersuits

/obj/item/clothing/under/syndicate/rus_army/cin_surplus
	name = "\improper CIN combat uniform"
	desc = "A CIN designed combat uniform that can come in any number of camouflauge variations. Despite this particular design being developed in the years leading up to the CIN-SolFed border war, the uniform is still in use by many member states to this day."
	worn_icon = 'modular_nova/modules/novaya_ert/icons/surplus_armor/surplus_armor_object.dmi'
	icon = 'icons/map_icons/clothing/under/_under.dmi'
	icon_state = "/obj/item/clothing/under/syndicate/rus_army/cin_surplus"
	post_init_icon_state = "undersuit_greyscale"
	greyscale_config = /datum/greyscale_config/cin_surplus_undersuit/object
	greyscale_config_worn = /datum/greyscale_config/cin_surplus_undersuit
	greyscale_config_worn_digi = /datum/greyscale_config/cin_surplus_undersuit/digi
	greyscale_colors = "#bbbbc9#bbbbc9#34343a"
	has_sensor = HAS_SENSORS
	flags_1 = IS_PLAYER_COLORABLE_1

/obj/item/clothing/under/syndicate/rus_army/cin_surplus/desert
	greyscale_colors = "#aa6d4c#aa6d4c#34343a"

/obj/item/clothing/under/syndicate/rus_army/cin_surplus/forest
	greyscale_colors = "#6D6D51#6D6D51#34343a"

/obj/item/clothing/under/syndicate/rus_army/cin_surplus/marine
	greyscale_colors = "#51517b#51517b#34343a"

/obj/item/clothing/under/syndicate/rus_army/cin_surplus/random_color
	/// What colors the jumpsuit can spawn with (only does the arms and legs of it)
	var/static/list/possible_limb_colors = list(
		CIN_WINTER_COLORS,
		CIN_MOUNTAIN_DESERT_COLORS,
		CIN_FOREST_COLORS,
		CIN_MARINE_COLORS,
	)

/obj/item/clothing/under/syndicate/rus_army/cin_surplus/random_color/Initialize(mapload)
	greyscale_colors = "[pick(possible_limb_colors)][pick(possible_limb_colors)][CIN_EVIL_COLORS]"

	. = ..()

// Vests

/obj/item/clothing/suit/armor/vest/cin_surplus_vest
	name = "\improper GZ-03 armor vest"
	desc = "An outdated armor vest previously used by CIN military forces. The design dates back to the years leading up to CIN - SolFed border war, and was in service until the advent of VOSKHOD powered armor becoming standard issue."
	worn_icon = 'modular_nova/modules/novaya_ert/icons/surplus_armor/surplus_armor.dmi'
	icon = 'modular_nova/modules/novaya_ert/icons/surplus_armor/surplus_armor_object.dmi'
	icon_state = "vest"
	armor_type = /datum/armor/cin_surplus_armor
	supports_variations_flags = CLOTHING_NO_VARIATION

/obj/item/clothing/suit/armor/vest/cin_surplus_vest/examine_more(mob/user)
	. = ..()

	. += "The GZ-03 series of coalition armor was a collaborative project between the NRI and TransOrbital \
		to develop a frontline soldier's armor set that could withstand attacks from the Solar Federation's \
		then relatively new pulse ballistics. The design itself is based upon a far older pattern \
		of armor originally developed by SolFed themselves, which was the standard pattern of armor design \
		granted to the first colony ships leaving Sol. Armor older than any of the CIN member states, \
		upgraded with modern technology. This vest in particular is made up of several large, dense plates \
		front and back. While vests like this were also produced with extra plating to protect the groin, many \
		surplus vests are missing them due to the popularity of removing the plates and using them as seating \
		during wartime."

	return .

// Chest Rig

/obj/item/storage/belt/military/cin_surplus
	desc = "A tactical webbing often used by the CIN's military forces."
	worn_icon = 'modular_nova/modules/novaya_ert/icons/surplus_armor/surplus_armor_object.dmi'
	worn_icon_state = "chestrig"
	icon = 'icons/map_icons/items/_item.dmi'
	icon_state = "/obj/item/storage/belt/military/cin_surplus"
	post_init_icon_state = "chestrig"
	greyscale_config = /datum/greyscale_config/cin_surplus_chestrig/object
	greyscale_config_worn = /datum/greyscale_config/cin_surplus_chestrig
	greyscale_colors = CIN_WINTER_COLORS_COMPLIMENT
	flags_1 = IS_PLAYER_COLORABLE_1
	storage_type = /datum/storage/loadout_belt

/obj/item/storage/belt/military/cin_surplus/desert
	icon_state = "/obj/item/storage/belt/military/cin_surplus/desert"
	greyscale_colors = CIN_MOUNTAIN_DESERT_COLORS_COMPLIMENT

/obj/item/storage/belt/military/cin_surplus/forest
	icon_state = "/obj/item/storage/belt/military/cin_surplus/forest"
	greyscale_colors = CIN_FOREST_COLORS_COMPLIMENT

/obj/item/storage/belt/military/cin_surplus/marine
	icon_state = "/obj/item/storage/belt/military/cin_surplus/marine"
	greyscale_colors = CIN_MARINE_COLORS_COMPLIMENT

/obj/item/storage/belt/military/cin_surplus/random_color
	/// The different colors this can choose from when initializing
	var/static/list/possible_spawning_colors = list(
		CIN_WINTER_COLORS_COMPLIMENT,
		CIN_MOUNTAIN_DESERT_COLORS_COMPLIMENT,
		CIN_FOREST_COLORS_COMPLIMENT,
		CIN_MARINE_COLORS_COMPLIMENT,
		CIN_EVIL_COLORS_COMPLIMENT,
	)

/obj/item/storage/belt/military/cin_surplus/random_color/Initialize(mapload)
	greyscale_colors = pick(possible_spawning_colors)

	. = ..()

// Backpack

/obj/item/storage/backpack/industrial/cin_surplus
	name = "\improper CIN military backpack"
	desc = "A rugged backpack often used by the CIN's military forces."
	worn_icon = 'modular_nova/modules/novaya_ert/icons/surplus_armor/surplus_armor_object.dmi'
	icon = 'icons/map_icons/items/_item.dmi'
	icon_state = "/obj/item/storage/backpack/industrial/cin_surplus"
	post_init_icon_state = "backpack"
	greyscale_config = /datum/greyscale_config/cin_surplus_backpack/object
	greyscale_config_worn = /datum/greyscale_config/cin_surplus_backpack
	greyscale_colors = CIN_WINTER_COLORS_COMPLIMENT

/obj/item/storage/backpack/industrial/cin_surplus/desert
	icon_state = "/obj/item/storage/backpack/industrial/cin_surplus/desert"
	greyscale_colors = CIN_MOUNTAIN_DESERT_COLORS_COMPLIMENT

/obj/item/storage/backpack/industrial/cin_surplus/forest
	icon_state = "/obj/item/storage/backpack/industrial/cin_surplus/forest"
	greyscale_colors = CIN_FOREST_COLORS_COMPLIMENT

/obj/item/storage/backpack/industrial/cin_surplus/marine
	icon_state = "/obj/item/storage/backpack/industrial/cin_surplus/marine"
	greyscale_colors = CIN_MARINE_COLORS_COMPLIMENT

/obj/item/storage/backpack/industrial/cin_surplus/random_color
	/// The different colors this can choose from when initializing
	var/static/list/possible_spawning_colors = list(
		CIN_WINTER_COLORS_COMPLIMENT,
		CIN_MOUNTAIN_DESERT_COLORS_COMPLIMENT,
		CIN_FOREST_COLORS_COMPLIMENT,
		CIN_MARINE_COLORS_COMPLIMENT,
		CIN_EVIL_COLORS_COMPLIMENT,
	)

/obj/item/storage/backpack/industrial/cin_surplus/random_color/Initialize(mapload)
	greyscale_colors = pick(possible_spawning_colors)

	return ..()

#undef CIN_WINTER_COLORS
#undef CIN_MOUNTAIN_DESERT_COLORS
#undef CIN_FOREST_COLORS
#undef CIN_MARINE_COLORS
#undef CIN_EVIL_COLORS

#undef CIN_WINTER_COLORS_COMPLIMENT
#undef CIN_MOUNTAIN_DESERT_COLORS_COMPLIMENT
#undef CIN_FOREST_COLORS_COMPLIMENT
#undef CIN_MARINE_COLORS_COMPLIMENT
#undef CIN_EVIL_COLORS_COMPLIMENT
