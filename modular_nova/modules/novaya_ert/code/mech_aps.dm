/// Active Protection System - utility slot module projecting an invisible 3x3 interception bubble.
/// Fully event-driven (proximity monitor crossing signals), no processing loop.
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

/// Invisible 3x3 interception field. Purely event-driven - crossing signals only, no ticking.
/datum/proximity_monitor/advanced/mech_aps
	//The outer ring counts as field too, so crossing the edge already counts as an intercept opportunity.
	edge_is_a_field = TRUE
	/// The APS module projecting us, for cost and knob access.
	var/obj/item/mecha_parts/mecha_equipment/active_protection/aps_module

/datum/proximity_monitor/advanced/mech_aps/field_turf_crossed(atom/movable/movable, turf/old_location, turf/new_location)
	var/obj/projectile/incoming = movable
	if(istype(incoming))
		try_intercept(incoming)

/// Also catches projectiles parked inside the field the moment it's established (e.g. mech moved under one).
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
