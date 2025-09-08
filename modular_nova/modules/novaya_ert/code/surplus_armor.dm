// THESE WILL (MOSTLY) SPAWN WITH A RANDOM 'CAMO' COLOR WHEN ORDERED THROUGH CARGO
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

// Martyr armor absorbs damage incredibly effectively, but the wearer pays the price for it later.
/datum/armor/armor_cin_martyr
	melee = ARMOR_LEVEL_WEAK
	bullet = ARMOR_LEVEL_INSANE // The armor itself barely takes a scratch...
	laser = ARMOR_LEVEL_TINY
	energy = ARMOR_LEVEL_TINY
	bomb = ARMOR_LEVEL_WEAK
	fire = ARMOR_LEVEL_MID
	acid = ARMOR_LEVEL_WEAK
	wound = WOUND_ARMOR_HIGH

// Hats

/obj/item/clothing/head/helmet/cin_martyr
	name = "\improper GZ-04 'Muchenik' kinetic redistribution helmet"
	desc = "A heavy, full-face helmet that complements the 'Muchenik' vest. It features the same ominous piezoelectric dampening technology.\
	 The visor is a thick, slightly hazy polycarbonate, designed to withstand impacts that would turn a standard helmet to shrapnel."
	icon = 'modular_nova/modules/novaya_ert/icons/armor.dmi'
	worn_icon = 'modular_nova/modules/novaya_ert/icons/wornarmor.dmi'
	icon_state = "police_helmet"
	inhand_icon_state = "helmet"
	armor_type = /datum/armor/armor_cin_martyr
	flags_inv = HIDEMASK|HIDEEARS|HIDEEYES|HIDEFACE|HIDEHAIR|HIDEFACIALHAIR|HIDESNOUT
	flags_cover = HEADCOVERSEYES | HEADCOVERSMOUTH | PEPPERPROOF
	dog_fashion = null
	supports_variations_flags = CLOTHING_SNOUTED_VARIATION_NO_NEW_ICON
	resistance_flags = FIRE_PROOF
	/// Kinetic absorption component handles damage storage.
	var/datum/component/kinetic_absorption/kinetic_component

/obj/item/clothing/head/helmet/cin_martyr/Initialize(mapload)
	. = ..()
	kinetic_component = AddComponent(/datum/component/kinetic_absorption)

/obj/item/clothing/head/helmet/cin_martyr/dropped(mob/user)
	. = ..()
	// If removed while still holding damage, apply it all at once in a final, brutal reckoning.
	if(kinetic_component && kinetic_component.stored_damage > 0)
		kinetic_component.release_all_damage(user)

/obj/item/clothing/head/helmet/cin_martyr/examine_more(mob/user)
	. = ..()

	. += "The helmet of the 'Muchenik' system operates on the same brutal principle as the vest. \
		A shot to the head that should have been fatal instead results in a concussive force distributed \
		as a debilitating migraine and internal trauma, stored within the helmet's systems. \
		The recommended procedure is to keep it sealed until the vest's dispersal cycle is complete, \
		allowing the energy to be safely bled off through the neural interface in the collar. \
		Removing it early is known to cause catastrophic cerebral hemorrhaging in test subjects. \
		It is the ultimate act of faith in Imperial engineering: betting your mind and body that the battle \
		will be over before the armor's price claims you."

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

/obj/item/clothing/suit/armor/vest/cin_martyr
	name = "\improper GZ-04 'Muchenik' kinetic redistribution vest"
	desc = "A heavy, boxy plate carrier of NRI design, covered in thick, angled plasteel plates and a network of piezoelectric dampeners. 	A small, red warning stencil on the shoulder reads: 'WARNING: KINETIC DEFLECTION SYSTEM - DO NOT REMOVE UNDER LOAD'. 	It is exceptionally effective at stopping ballistic impacts, seemingly too good to be true."
	icon = 'modular_nova/modules/novaya_ert/icons/armor.dmi' // Assuming a standard path
	worn_icon = 'modular_nova/modules/novaya_ert/icons/wornarmor.dmi'
	icon_state = "police_vest"
	inhand_icon_state = "armor"
	blood_overlay_type = "armor"
	armor_type = /datum/armor/armor_cin_martyr
	supports_variations_flags = CLOTHING_DIGITIGRADE_VARIATION_NO_NEW_ICON
	resistance_flags = FIRE_PROOF
	/// Kinetic absorption component handles damage storage and processing.
	var/datum/component/kinetic_absorption/kinetic_component

/obj/item/clothing/suit/armor/vest/cin_martyr/Initialize(mapload)
	. = ..()
	// Add kinetic absorption component to handle damage absorption/storage.
	kinetic_component = AddComponent(/datum/component/kinetic_absorption)

/obj/item/clothing/suit/armor/vest/cin_martyr/dropped(mob/user)
	. = ..()
	// If removed while still holding damage, apply it all at once in a final, brutal reckoning.
	if(kinetic_component && kinetic_component.stored_damage > 0)
		kinetic_component.release_all_damage(user)

/obj/item/clothing/suit/armor/vest/cin_martyr/examine_more(mob/user)
	. = ..()

	. += "The GZ-04 'Muchenik' (Martyr) system is a terrifyingly pragmatic piece of Imperial technology. \
		Rather than simply stopping a projectile, its piezoelectric lattice captures and redistributes the kinetic energy \
		throughout the entire vest, preventing penetration and catastrophic failure of the plates. \
		The catch is that this energy isn't dissipated safely; it's stored in capacitor-like systems and slowly released \
		as vibrational energy into the wearer's body, transmuting what would have been a lethal wound into a deep, \
		agonizing ache that cripples the user over time. <br>\
		The official doctrine is to wear it only for short, critical engagements, and to never, under any circumstances, \
		remove the vest until its systems show a full discharge. To do so is to risk every ounce of pain it has absorbed \
		being unleashed upon the wearer all at once. It is the choice between a certain, immediate death and a probable, \
		protracted one; a true soldier's sacrifice for the preservation of the Motherland."

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
