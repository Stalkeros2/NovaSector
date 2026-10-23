/// Full-screen green tint for the thermal CRT sight. Stronger than the stock color_vision green.
/atom/movable/screen/fullscreen/thermal_vision_green
	icon = 'icons/hud/screen_gen.dmi'
	screen_loc = "WEST,SOUTH to EAST,NORTH"
	icon_state = "noise"
	color = "#25a325"
	alpha = 65

/// Full-screen horizontal scanline overlay for the thermal CRT sight.
/// Same states the gateway uses for its camera feeds - knob: swap scanline4/scanline2 after eyeballing in-game.
/atom/movable/screen/fullscreen/thermal_vision_scanlines
	icon = 'icons/hud/map_backgrounds.dmi'
	screen_loc = "WEST,SOUTH to EAST,NORTH"
	icon_state = "scanline2"
	alpha = 120

/// Thermal CRT sight suite - utility module granting occupants wall-penetrating
/// mob/object vision plus a green scanline display overlay.
/obj/item/mecha_parts/mecha_equipment/thermal_sight
	name = "\improper M/TS-29 thermal sight suite"
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
