// Full-screen green tint for the thermal CRT sight. Stronger than the stock color_vision green.
/atom/movable/screen/fullscreen/thermal_vision_green
	icon = 'icons/hud/screen_gen.dmi'
	screen_loc = "WEST,SOUTH to EAST,NORTH"
	icon_state = "noise"
	color = "#25a325"
	alpha = 65

// Full-screen horizontal scanline overlay for the thermal CRT sight.
/atom/movable/screen/fullscreen/thermal_vision_scanlines
	icon = 'icons/hud/map_backgrounds.dmi'
	screen_loc = "WEST,SOUTH to EAST,NORTH"
	icon_state = "scanline2"
	alpha = 120

// Thermal CRT sight suite - utility module granting occupants wall-penetrating
// mob/object vision plus a green scanline display overlay.
/obj/item/mecha_parts/mecha_equipment/thermal_sight
	name = "\improper M/TS-29 \" \" thermal sight suite"
	desc = "A wall-penetrating optical suite for exosuits, produced by KMIF. Renders living targets and \
		structural objects through solid cover directly onto the pilot's display, in the classic green \
		CRT style of older frontier sensor systems. Toggle to enable."
	icon_state = "mecha_abooster_emp"
	equipment_slot = MECHA_UTILITY
	can_be_toggled = TRUE
	active = FALSE //the pilot opts into the green
	unstackable = TRUE

/obj/item/mecha_parts/mecha_equipment/thermal_sight/attach(obj/vehicle/sealed/mecha/new_mecha, attach_right = FALSE)
	. = ..()
	RegisterSignal(chassis, COMSIG_ATOM_ENTERED, PROC_REF(on_chassis_entered))
	RegisterSignal(chassis, COMSIG_ATOM_EXITED, PROC_REF(on_chassis_exited))
	if(active)
		for(var/mob/living/occupant in chassis.occupants)
			apply_effects(occupant)

/obj/item/mecha_parts/mecha_equipment/thermal_sight/detach(atom/moveto)
	if(chassis)
		UnregisterSignal(chassis, list(COMSIG_ATOM_ENTERED, COMSIG_ATOM_EXITED))
		for(var/mob/living/occupant in chassis.occupants)
			remove_effects(occupant)
	return ..()

/obj/item/mecha_parts/mecha_equipment/thermal_sight/set_active(new_active)
	. = ..()
	if(!chassis)
		return
	for(var/mob/living/occupant in chassis.occupants)
		if(active)
			apply_effects(occupant)
		else
			remove_effects(occupant)

/// A mob entered the chassis - if we're live, give them the sight.
/obj/item/mecha_parts/mecha_equipment/thermal_sight/proc/on_chassis_entered(obj/vehicle/sealed/mecha/source, atom/movable/arrived, atom/old_loc, list/old_locs)
	SIGNAL_HANDLER
	if(!active)
		return
	if(isliving(arrived))
		apply_effects(arrived)
	else if(istype(arrived, /obj/item/mmi))
		// The MMI enters contents before its brain mob becomes an occupant, so don't gate on the occupants list.
		var/obj/item/mmi/inserted = arrived
		if(inserted.brainmob)
			apply_effects(inserted.brainmob)

/// A mob left the chassis - strip our effects (idempotent, guarded by our trait source).
/obj/item/mecha_parts/mecha_equipment/thermal_sight/proc/on_chassis_exited(obj/vehicle/sealed/mecha/source, atom/movable/gone, direction)
	SIGNAL_HANDLER
	if(isliving(gone))
		remove_effects(gone)
	else if(istype(gone, /obj/item/mmi))
		var/obj/item/mmi/removed = gone
		if(removed.brainmob)
			remove_effects(removed.brainmob)

/// Grants the sight flags and screen overlays to one mob. Idempotent via our trait source.
/obj/item/mecha_parts/mecha_equipment/thermal_sight/proc/apply_effects(mob/living/occupant)
	if(isAI(occupant)) //AIs pilot remotely and never enter chassis contents
		return
	if(HAS_TRAIT_FROM(occupant, TRAIT_THERMAL_VISION, REF(src)))
		return
	// Signal adds SEE_OBJS (mechs/fuel tanks through walls); the trait covers SEE_MOBS + thermal light cutoff.
	RegisterSignal(occupant, COMSIG_CARBON_UPDATE_SIGHT_CUTOFFS, PROC_REF(on_sight_update))
	ADD_TRAIT(occupant, TRAIT_THERMAL_VISION, REF(src))
	occupant.overlay_fullscreen("thermal_green", /atom/movable/screen/fullscreen/thermal_vision_green)
	occupant.overlay_fullscreen("thermal_scanlines", /atom/movable/screen/fullscreen/thermal_vision_scanlines)
	occupant.update_sight()

/// Strips the sight from one mob. Only removes OUR trait source - other sources (e.g. WUNK's VEHICLE_TRAIT) persist.
/obj/item/mecha_parts/mecha_equipment/thermal_sight/proc/remove_effects(mob/living/occupant)
	if(!HAS_TRAIT_FROM(occupant, TRAIT_THERMAL_VISION, REF(src)))
		return
	UnregisterSignal(occupant, COMSIG_CARBON_UPDATE_SIGHT_CUTOFFS)
	REMOVE_TRAIT(occupant, TRAIT_THERMAL_VISION, REF(src))
	occupant.clear_fullscreen("thermal_green")
	occupant.clear_fullscreen("thermal_scanlines")
	occupant.update_sight()

/// Composes the exact SEE_MOBS|SEE_OBJS pair - no SEE_TURFS, unlike TRAIT_XRAY_VISION.
/obj/item/mecha_parts/mecha_equipment/thermal_sight/proc/on_sight_update(mob/living/carbon/source, list/return_list)
	SIGNAL_HANDLER
	return_list[1] |= SEE_MOBS | SEE_OBJS

// Active Protection System - utility slot module projecting an invisible 3x3 interception bubble.
/obj/item/mecha_parts/mecha_equipment/active_protection
	name = "\improper M/APS-3 \"Snakeskin\" active protection system"
	desc = "An automated ordnance interception system for exosuits, produced by KMIF. Projects an invisible \
		interception field around the chassis that detonates incoming missiles, rockets and slow shells mid-flight. \
		Power-hungry: every interception draws heavily from the exosuit's power cell, and fast penetrators slip right through."
	icon_state = "mecha_abooster_proj"
	equipment_slot = MECHA_UTILITY
	can_be_toggled = TRUE
	active = TRUE
	unstackable = TRUE
	/// Energy the chassis cell pays per intercepted projectile.
	var/intercept_cost = 100
	/// Projectiles faster than this slip through the field entirely.
	var/max_intercept_speed = 1.5
	/// The interception field we project while active.
	var/datum/proximity_monitor/advanced/mech_aps/interception_field

/obj/item/mecha_parts/mecha_equipment/active_protection/Destroy()
	disable_field()
	return ..()

/obj/item/mecha_parts/mecha_equipment/active_protection/attach(obj/vehicle/sealed/mecha/new_mecha, attach_right = FALSE)
	. = ..()
	if(active)
		enable_field()

/obj/item/mecha_parts/mecha_equipment/active_protection/detach(atom/moveto)
	disable_field()
	return ..()

/obj/item/mecha_parts/mecha_equipment/active_protection/set_active(new_active)
	. = ..()
	if(active)
		enable_field()
	else
		disable_field()

/// Projects the interception field around the chassis.
/obj/item/mecha_parts/mecha_equipment/active_protection/proc/enable_field()
	if(interception_field || !chassis)
		return
	interception_field = new(chassis, 1) //3x3 field centred on the chassis
	interception_field.aps_module = src
	interception_field.recalculate_field(full_recalc = TRUE) //base never populates field_turfs on its own; kicks off setup_field_turf for pre-existing projectiles
	log_message("Interception field enabled.", LOG_MECHA)

/// Drops the interception field.
/obj/item/mecha_parts/mecha_equipment/active_protection/proc/disable_field()
	QDEL_NULL(interception_field)

// Invisible 3x3 interception field. Purely event-driven - crossing signals only, no ticking.
/datum/proximity_monitor/advanced/mech_aps
	//The outer ring counts as field too, so crossing the edge already counts as an intercept opportunity.
	edge_is_a_field = TRUE
	/// The APS module projecting us, for cost and knob access.
	var/obj/item/mecha_parts/mecha_equipment/active_protection/aps_module

/datum/proximity_monitor/advanced/mech_aps/field_turf_crossed(atom/movable/movable, turf/old_location, turf/new_location)
	var/obj/projectile/incoming = movable
	if(istype(incoming))
		try_intercept(incoming)

// Also catches projectiles parked inside the field the moment it's established (e.g. mech moved under one).
/datum/proximity_monitor/advanced/mech_aps/setup_field_turf(turf/target)
	for(var/obj/projectile/preexisting in range(1, target))
		try_intercept(preexisting)

/// Decides whether this projectile qualifies for interception, and pays for it.
/datum/proximity_monitor/advanced/mech_aps/proc/try_intercept(obj/projectile/incoming)
	if(QDELETED(incoming) || QDELETED(aps_module))
		return
	if(!istype(incoming, /obj/projectile/bullet/rocket) && !istype(incoming, /obj/projectile/bullet/tank_cannon))
		return
	if(incoming.speed > aps_module.max_intercept_speed) //fast penetrators (sabots) are not our problem
		return
	if(isnull(incoming.angle)) //not fired yet
		return
	// Only intercept shots actually travelling towards us - our own outgoing fire flies right out.
	if(abs(closer_angle_difference(incoming.angle, get_angle(incoming, host))) > 90)
		return
	if(!aps_module.chassis?.use_energy(aps_module.intercept_cost))
		return
	intercept(incoming)

/// Kills the projectile: the warhead cooks off on the spot.
/datum/proximity_monitor/advanced/mech_aps/proc/intercept(obj/projectile/incoming)
	var/turf/impact_turf = get_turf(incoming)
	var/projectile_name = incoming.name
	qdel(incoming)
	explosion(impact_turf, devastation_range = -1, heavy_impact_range = -1, light_impact_range = 1, flash_range = 1, adminlog = FALSE)
	do_sparks(5, FALSE, impact_turf)
	playsound(impact_turf, 'modular_nova/modules/modular_weapons/sounds/grenade_burst.ogg', 75, FALSE, 3)
	var/intercept_notice = span_danger("APS INTERCEPT: [uppertext(projectile_name)] neutralized!")
	to_chat(aps_module.chassis?.occupants, "[icon2html(aps_module, aps_module.chassis?.occupants)][intercept_notice]")

//Smoke launcher that shoots smoke grenades around on activation. Self-explanatory.
/obj/item/mecha_parts/mecha_equipment/smoke_launcher
	name = "M/PCD-1 \"Funky Name\" passive concealment dispenser"
	desc = "An exosuit-mounted smoke grenade launcher, produced by KMIF. Fires a timed barrage: two grenades to the front, then one to each side, then two to the rear."
	icon = 'icons/obj/devices/mecha_equipment.dmi'
	icon_state = "mecha_smoke"
	equipment_slot = MECHA_UTILITY
	can_be_triggered = TRUE
	equip_cooldown = 150
	energy_drain = 25
	harmful = FALSE
	active_label = "Status"
	action_type = /datum/action/vehicle/sealed/mecha/equipment/smoke_launcher_action

// The mech UI funnels module buttons through ui_act -> handle_ui_act, so cover both trigger-style actions here.
/obj/item/mecha_parts/mecha_equipment/smoke_launcher/handle_ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	switch(action)
		if("trigger", "toggle")
			return activate(usr)

/**
 * Validates the activation and starts the barrage asynchronously.
 * Returns TRUE if the barrage was started.
 * Arguments:
 * * user - the pilot that pulled the trigger
 */
/obj/item/mecha_parts/mecha_equipment/smoke_launcher/proc/activate(mob/user)
	if(!user || !chassis)
		return FALSE
	if(!action_checks(chassis)) // cooldown, energy, integrity, ejection, etc.
		return FALSE
	INVOKE_ASYNC(src, PROC_REF(fire_barrage), user)
	return TRUE

/**
 * Fires the timed smoke barrage:
 * 1. Two grenades in the front arc, wait 0.75 seconds;
 * 2. One grenade to each side (left and right), wait 0.75 seconds;
 * 3. Two grenades in the rear arc.
 */
/obj/item/mecha_parts/mecha_equipment/smoke_launcher/proc/fire_barrage(mob/user)
	if(!chassis || QDELETED(chassis))
		return

	// Start the equipment cooldown on the mech (prevents spamming)
	TIMER_COOLDOWN_START(chassis, COOLDOWN_MECHA_EQUIPMENT(type), get_equip_cooldown(null))
	SEND_SIGNAL(user, COMSIG_MOB_USED_MECH_EQUIPMENT, chassis)
	chassis.use_energy(energy_drain)

	// Volley 1: two grenades in the front arc
	var/front_angle = dir2angle(chassis.dir)
	fire_smoke_grenade(front_angle - 15)
	fire_smoke_grenade(front_angle + 15)
	sleep(0.75 SECONDS)

	if(!chassis || QDELETED(chassis))
		return

	// Volley 2: one grenade to each side
	var/right_angle = dir2angle(turn(chassis.dir, 90))
	var/left_angle = dir2angle(turn(chassis.dir, -90))
	fire_smoke_grenade(right_angle)
	fire_smoke_grenade(left_angle)
	sleep(0.75 SECONDS)

	if(!chassis || QDELETED(chassis))
		return

	// Volley 3: two grenades in the rear arc
	var/rear_angle = dir2angle(REVERSE_DIR(chassis.dir))
	fire_smoke_grenade(rear_angle - 15)
	fire_smoke_grenade(rear_angle + 15)

/// Spawns and fires a single smoke grenade projectile at the given angle.
/obj/item/mecha_parts/mecha_equipment/smoke_launcher/proc/fire_smoke_grenade(angle)
	if(!chassis || QDELETED(chassis))
		return
	var/turf/spawn_turf = get_turf(chassis)
	if(!spawn_turf)
		return
	var/obj/projectile/bullet/c980grenade/smoke/projectile = new(spawn_turf)
	projectile.firer = chassis
	projectile.fired_from = src
	projectile.fire(angle)

/// Action button for the smoke launcher - clicking it (or pressing its bound hotkey) fires the barrage.
/datum/action/vehicle/sealed/mecha/equipment/smoke_launcher_action
	name = "Smoke Launcher"

/datum/action/vehicle/sealed/mecha/equipment/smoke_launcher_action/set_equipment(passed_equipment)
	. = ..()
	name = "[equipment.name]"

/datum/action/vehicle/sealed/mecha/equipment/smoke_launcher_action/Trigger(mob/clicker, trigger_flags)
	SHOULD_CALL_PARENT(FALSE) //We are snowflaked from parent, like the extinguisher and cargo module
	if(!chassis || !(owner in chassis.occupants) || !equipment)
		return
	if(!istype(equipment, /obj/item/mecha_parts/mecha_equipment/smoke_launcher))
		return
	var/obj/item/mecha_parts/mecha_equipment/smoke_launcher/launcher = equipment
	launcher.activate(owner)
