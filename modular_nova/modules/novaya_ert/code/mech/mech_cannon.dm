#define MECHA_AMMO_TANK_CANNON "76mm shell"

/obj/item/mecha_ammo/tank_cannon
	name = "76mm ammo rack"
	desc = "A rack of 76mm shells for tank cannons."
	w_class = WEIGHT_CLASS_BULKY
	icon_state = "lmg"
	custom_materials = list(/datum/material/iron = SHEET_MATERIAL_AMOUNT*5)
	rounds = 10
	direct_load = TRUE
	load_audio = 'sound/items/weapons/gun/general/mag_bullet_insert.ogg'
	ammo_type = MECHA_AMMO_TANK_CANNON
	qdel_on_empty = FALSE

/obj/item/mecha_ammo/tank_cannon/update_name()
	. = ..()
	name = "[rounds ? null : "empty "][initial(name)] ([ammo_type])"

/obj/item/mecha_ammo/tank_cannon/update_desc()
	. = ..()
	desc = rounds ? initial(desc) : "An empty 76mm ammo rack. It can be safely folded for recycling."

/obj/item/mecha_ammo/tank_cannon/update_icon_state()
	icon_state = rounds ? initial(icon_state) : "[initial(icon_state)]_e"
	return ..()

/obj/item/mecha_parts/mecha_equipment/weapon/ballistic/tank_cannon
	name = "\improper 76mm Tank Cannon"
	desc = "A powerful 76mm tank cannon capable of firing both APFSDS and HEAT-MP rounds. Use the mech UI to switch ammo types."
	icon_state = "mecha_scatter"
	equip_cooldown = 60 // 6 seconds cooldown
	projectile = /obj/projectile/bullet/tank_cannon_apfsds
	projectiles = 1
	projectiles_cache = 10
	projectiles_cache_max = 10
	disabledreload = FALSE
	harmful = TRUE
	ammo_type = MECHA_AMMO_TANK_CANNON
	/// Current ammo type (0 = APFSDS, 1 = HEAT-MP)
	var/current_ammo = 0
	/// List of projectile types for each ammo type
	var/list/projectile_types = list(
		/obj/projectile/bullet/tank_cannon_apfsds,
		/obj/projectile/bullet/tank_cannon_heat,
	)
	/// List of ammo type names for UI
	var/list/ammo_names = list("APFSDS", "HEAT-MP")
	/// Cooldown timer for reload messages
	var/reload_message_cooldown = 0

/obj/item/mecha_parts/mecha_equipment/weapon/ballistic/tank_cannon/Initialize()
	. = ..()
	current_ammo = clamp(current_ammo, 0, length(projectile_types) - 1)
	projectile = projectile_types[current_ammo + 1]

/obj/item/mecha_parts/mecha_equipment/weapon/ballistic/tank_cannon/get_snowflake_data()
	. = ..()
	.["current_ammo"] = current_ammo
	.["ammo_names"] = ammo_names

/obj/item/mecha_parts/mecha_equipment/weapon/ballistic/tank_cannon/handle_ui_act(action, list/params)
	if(action == "switch_ammo")
		current_ammo = !current_ammo // Toggle between 0 and 1
		projectile = projectile_types[current_ammo + 1] // DM lists are 1-indexed
		var/mob/user = usr
		if(user)
			to_chat(user, span_notice("[src] ammo type switched to [ammo_names[current_ammo + 1]]."))
			return TRUE
	return ..()

/obj/item/mecha_parts/mecha_equipment/weapon/ballistic/tank_cannon/action(mob/source, atom/target, list/modifiers)
	. = ..()
	if(!.)
		return

	// Show loading message if not on cooldown
	if(world.time > reload_message_cooldown)
		var/message = "[ammo_names[current_ammo]] loaded."
		to_chat(source, span_notice("[icon2html(src, source)][message]"))
		reload_message_cooldown = world.time + 1 SECONDS

		// Start cooldown callback for additional messages
		addtimer(CALLBACK(src, PROC_REF(show_index_message), 2 SECONDS))
		addtimer(CALLBACK(src, PROC_REF(show_ready_message), equip_cooldown))

/obj/item/mecha_parts/mecha_equipment/weapon/ballistic/tank_cannon/proc/show_index_message()
	if(!chassis || !LAZYLEN(chassis.occupants))
		return
	var/message = "[ammo_names[current_ammo]] indexed."
	for(var/mob/occupant in chassis.occupants)
		to_chat(occupant, span_notice("[icon2html(src, occupant)][message]"))

/obj/item/mecha_parts/mecha_equipment/weapon/ballistic/tank_cannon/proc/show_ready_message()
	if(!chassis || !LAZYLEN(chassis.occupants))
		return
	var/message = "UP!"
	for(var/mob/occupant in chassis.occupants)
		to_chat(occupant, span_notice("[icon2html(src, occupant)][message]"))

/obj/projectile/bullet/tank_cannon_apfsds
	name = "APFSDS round"
	icon_state = "greyscale_bolt"
	damage = 60
	armour_penetration = 70
	speed = 0.4
	range = 30
	impact_effect_type = /obj/effect/temp_visual/impact_effect
	hitsound = 'sound/effects/explosion/explosion1.ogg'
	hitsound_wall = 'sound/effects/explosion/explosion1.ogg'

/obj/projectile/bullet/tank_cannon_heat
	name = "HEAT-MP round"
	icon_state = "greyscale_bolt"
	damage = 40
	armour_penetration = 30
	speed = 0.4
	range = 30
	sharpness = NONE
	impact_effect_type = /obj/effect/temp_visual/impact_effect
	hitsound = 'sound/effects/explosion/explosion2.ogg'
	hitsound_wall = 'sound/effects/explosion/explosion2.ogg'

/obj/projectile/bullet/tank_cannon_heat/on_hit(atom/target, blocked = FALSE)
	..()
	explosion(target, -1, 1, 2, 3)
	return BULLET_ACT_HIT
