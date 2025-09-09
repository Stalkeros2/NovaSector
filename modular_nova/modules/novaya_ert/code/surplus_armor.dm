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
