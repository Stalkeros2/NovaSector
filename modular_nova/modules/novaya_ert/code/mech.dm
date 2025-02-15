/obj/vehicle/sealed/mecha/varangian
	name = "\improper Varangian"
	desc = "Heavy-duty, combat exosuit, developed after the Durand model. Rarely found among civilian populations. \
	Its bleeding edge armour ensures maximum usability and protection at the cost of some modularity."
	icon_state = "varangian"
	base_icon_state = "varangian"
	movedelay = 5
	max_integrity = 500
	armor_type = /datum/armor/mecha_varangian
	max_temperature = 30000
	destruction_sleep_duration = 40
	exit_delay = 40
	resistance_flags = FIRE_PROOF | ACID_PROOF
	wreckage = /obj/structure/mecha_wreckage/varangian
	mecha_flags = CAN_STRAFE | IS_ENCLOSED | HAS_LIGHTS | MMI_COMPATIBLE
	mech_type = EXOSUIT_MODULE_DURAND
	force = 20 //Use the pilebunker instead.
	max_equip_by_category = list(
		MECHA_L_ARM = 1,
		MECHA_R_ARM = 1,
		MECHA_UTILITY = 3,
		MECHA_POWER = 1,
		MECHA_ARMOR = 1,
	)

/datum/armor/mecha_varangian
	melee = 20
	bullet = 40
	laser = 20
	energy = 10
	bomb = 30
	fire = 100
	acid = 100

/obj/vehicle/sealed/mecha/varangian/generate_actions()
	. = ..()
	initialize_passenger_action_type(/datum/action/vehicle/sealed/mecha/mech_smoke)
	initialize_passenger_action_type(/datum/action/vehicle/sealed/mecha/mech_zoom)

/obj/vehicle/sealed/mecha/varangian/loaded
	equip_by_category = list(
		MECHA_L_ARM = /obj/item/mecha_parts/mecha_equipment/weapon/energy/pulse,
		MECHA_R_ARM = /obj/item/mecha_parts/mecha_equipment/weapon/ballistic/missile_rack,
		MECHA_UTILITY = list(/obj/item/mecha_parts/mecha_equipment/radio, /obj/item/mecha_parts/mecha_equipment/air_tank/full, /obj/item/mecha_parts/mecha_equipment/thrusters/ion),
		MECHA_POWER = list(),
		MECHA_ARMOR = list(),
	)

/obj/vehicle/sealed/mecha/varangian/loaded/populate_parts()
	cell = new /obj/item/stock_parts/power_store/cell/bluespace(src)
	scanmod = new /obj/item/stock_parts/scanning_module/triphasic(src)
	capacitor = new /obj/item/stock_parts/capacitor/quadratic(src)
	servo = new /obj/item/stock_parts/servo/femto(src)
	update_part_values()

/obj/item/mecha_parts/mecha_equipment/weapon/ballistic/cannon
	name = "\improper GP-120 \"Whitethorn\" Cannon"
	desc = "A weapon for combat exosuits. Shoots high calibre overpenetrating sabots."
	icon_state = "mecha_carbine"
	equip_cooldown = 60
	projectile = /obj/projectile/bullet/apfsds
	projectiles = 1
	projectiles_cache = 4
	projectiles_cache_max = 12
	disabledreload = TRUE
	harmful = TRUE
	ammo_type = "120mm APFSDS"

/obj/projectile/bullet/apfsds
	name = "120mm sabot"
	icon = 'modular_nova/modules/novaya_ert/icons/projectile.dmi'
	icon_state = "cannon"
	damage = 80
	armour_penetration = 35
	range = 25
	projectile_piercing = PASSMOB | PASSVEHICLE | PASSGLASS | PASSGRILLE | PASSCLOSEDTURF | PASSMACHINE | PASSSTRUCTURE | PASSDOORS
	max_pierces = 3
	phasing_ignore_direct_target = TRUE
	dismemberment = 10
	catastropic_dismemberment = FALSE

/obj/item/mecha_ammo/apfsds
	name = "120mm sabot cluster"
	desc = "A quad-stack of tank sabots, for use with main mech weapons."
	icon = 'modular_nova/modules/novaya_ert/icons/mecha_ammo.dmi'
	icon_state = "cannon"
	custom_materials = list(/datum/material/titanium=SHEET_MATERIAL_AMOUNT*3,/datum/material/uranium=HALF_SHEET_MATERIAL_AMOUNT * 1.5)
	rounds = 4
	ammo_type = "120mm APFSDS"
