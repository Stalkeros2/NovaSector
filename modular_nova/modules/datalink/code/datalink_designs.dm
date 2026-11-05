// MODULE ID: DATALINK
// Fabrication entries for both carriers plus their research node.

/datum/design/module/datalink
	name = "Tactical Datalink Module"
	materials = list(
		/datum/material/iron = SHEET_MATERIAL_AMOUNT * 2,
		/datum/material/glass = SHEET_MATERIAL_AMOUNT,
		/datum/material/silver = SMALL_MATERIAL_AMOUNT * 5,
	)
	build_path = /obj/item/mod/module/datalink

/datum/design/mech_datalink
	name = "Datalink Transceiver Array"
	desc = "A utility-slot transceiver that networks the exosuit into a tactical datalink mesh."
	build_type = MECHFAB
	build_path = /obj/item/mecha_parts/mecha_equipment/datalink
	materials = list(
		/datum/material/iron = SHEET_MATERIAL_AMOUNT * 2.5,
		/datum/material/glass = SHEET_MATERIAL_AMOUNT,
		/datum/material/silver = SMALL_MATERIAL_AMOUNT * 5,
	)
	construction_time = 10 SECONDS
	category = list(
		RND_CATEGORY_MECHFAB_EQUIPMENT + RND_SUBCATEGORY_MECHFAB_EQUIPMENT_MISC,
		RND_CATEGORY_MECHFAB_RIPLEY + RND_SUBCATEGORY_MECHFAB_SUPPORTED_EQUIPMENT,
		RND_CATEGORY_MECHFAB_GYGAX + RND_SUBCATEGORY_MECHFAB_SUPPORTED_EQUIPMENT,
		RND_CATEGORY_MECHFAB_DURAND + RND_SUBCATEGORY_MECHFAB_SUPPORTED_EQUIPMENT,
		RND_CATEGORY_MECHFAB_HONK + RND_SUBCATEGORY_MECHFAB_SUPPORTED_EQUIPMENT,
		RND_CATEGORY_MECHFAB_PHAZON + RND_SUBCATEGORY_MECHFAB_SUPPORTED_EQUIPMENT,
		RND_CATEGORY_MECHFAB_CLARKE + RND_SUBCATEGORY_MECHFAB_SUPPORTED_EQUIPMENT,
		RND_CATEGORY_MECHFAB_SAVANNAH_IVANOV + RND_SUBCATEGORY_MECHFAB_SUPPORTED_EQUIPMENT,
	)
	departmental_flags = DEPARTMENT_BITFLAG_SCIENCE

/datum/design/datalink_key
	name = "Datalink Crypto Key"
	desc = "A wafer-style crypto filler used to rewrite a datalink transceiver's net id."
	build_type = PROTOLATHE
	build_path = /obj/item/datalink_key
	materials = list(
		/datum/material/iron = SMALL_MATERIAL_AMOUNT * 2,
		/datum/material/silver = SMALL_MATERIAL_AMOUNT * 2,
	)
	construction_time = 5 SECONDS
	category = list(RND_CATEGORY_INITIAL, RND_CATEGORY_TOOLS)
	departmental_flags = DEPARTMENT_BITFLAG_SCIENCE

/datum/techweb_node/datalink_network
	display_name = "Tactical Datalink Mesh"
	description = "Ad-hoc wireless datalink transceivers for suits and exosuits that share position telemetry, contact awareness and command traffic across a keyed net."
	prerequisite_nodes = list(/datum/techweb_node/mod_equip)
	unlocked_designs = list(
		/datum/design/module/datalink,
		/datum/design/mech_datalink,
		/datum/design/datalink_key,
	)
	research_costs = list(TECHWEB_POINT_TYPE_GENERIC = TECHWEB_TIER_1_POINTS)
	announce_channels = list(RADIO_CHANNEL_SCIENCE)
