/////////////////////////////
///// Mecha ATGM System /////
/////////////////////////////

/obj/item/mecha_parts/mecha_equipment/weapon/ballistic/launcher/atgm
	name = "\improper ATGM-9 'Striker' Missile System"
	desc = "An advanced anti-tank guided missile system for combat exosuits. Projects a laser designator that guides the missile to its target."
	icon_state = "lmg"
	projectile = /obj/projectile/bullet/rocket/atgm
	fire_sound = 'sound/items/weapons/gun/general/rocket_launch.ogg'
	projectiles = 4
	projectiles_cache = 4
	projectiles_cache_max = 4
	disabledreload = TRUE
	equip_cooldown = 60
	missile_speed = 2
	missile_range = 30
	harmful = TRUE

	// User management
	var/mob/current_user = null

	// Aiming system
	var/aiming = FALSE
	var/aiming_time = 9 SECONDS
	var/aiming_time_left = 0
	var/aiming_time_fire_threshold = 0.5 SECONDS
	var/aiming_timer = null // Timer ID for aiming countdown
	var/movement_penalty = 0.5 SECONDS // Penalty for movement, added to remaining time

	// Targeting
	var/lastangle = 0
	var/atom/current_target = null
	var/obj/effect/projectile/tracer/laser/atgm/current_tracer = null

	// Missile tracking
	var/obj/projectile/bullet/rocket/atgm/current_missile = null

/obj/item/mecha_parts/mecha_equipment/weapon/ballistic/launcher/atgm/Destroy()
	cleanup_aiming_system()
	cleanup_missile()
	return ..()

/obj/item/mecha_parts/mecha_equipment/weapon/ballistic/launcher/atgm/attach(obj/vehicle/sealed/mecha/new_mecha, attach_right = FALSE)
	. = ..()
	// Add zoom feature when ATGM is attached
	if(chassis)
		chassis.initialize_passenger_action_type(/datum/action/vehicle/sealed/mecha/mech_zoom)

/obj/item/mecha_parts/mecha_equipment/weapon/ballistic/launcher/atgm/detach()
	cleanup_aiming_system()
	cleanup_missile()
	// Remove zoom feature when ATGM is detached (if not inherent to mech)
	if(chassis)
		chassis.destroy_passenger_action_type(/datum/action/vehicle/sealed/mecha/mech_zoom)
	return ..()

// ===== USER MANAGEMENT =====

/obj/item/mecha_parts/mecha_equipment/weapon/ballistic/launcher/atgm/proc/check_user()
	if(!current_user?.client)
		return FALSE
	if(current_user.incapacitated)
		return FALSE
	return TRUE

/obj/item/mecha_parts/mecha_equipment/weapon/ballistic/launcher/atgm/proc/set_user(mob/user)
	if(user == current_user)
		return

	// Clean up signals from previous user
	if(current_user?.client)
		unregister_client_signals(current_user)

	cleanup_aiming_system()

	current_user = user

// ===== CLIENT SIGNAL MANAGEMENT =====

/obj/item/mecha_parts/mecha_equipment/weapon/ballistic/launcher/atgm/proc/register_client_signals(mob/source)
	if(!source?.client)
		return
	RegisterSignal(source.client, COMSIG_CLIENT_MOUSEDRAG, PROC_REF(on_mouse_drag))

/obj/item/mecha_parts/mecha_equipment/weapon/ballistic/launcher/atgm/proc/unregister_client_signals(mob/source)
	if(!source?.client)
		return
	UnregisterSignal(source.client, list(COMSIG_CLIENT_MOUSEDRAG, COMSIG_CLIENT_MOUSEUP, COMSIG_CLIENT_MOUSEDOWN))

/obj/item/mecha_parts/mecha_equipment/weapon/ballistic/launcher/atgm/proc/on_mouse_drag(client/source, src_object, over_object, src_location, over_location, src_control, over_control, params)
	SIGNAL_HANDLER
	if(aiming && check_user())
		process_aim(params)

/obj/item/mecha_parts/mecha_equipment/weapon/ballistic/launcher/atgm/proc/on_mouse_down(client/source, atom/movable/object, location, control, params)
	SIGNAL_HANDLER
	if(!aiming)
		return
	RegisterSignal(source, COMSIG_CLIENT_MOUSEUP, PROC_REF(on_mouse_up))

/obj/item/mecha_parts/mecha_equipment/weapon/ballistic/launcher/atgm/proc/on_mouse_up(client/source, atom/movable/object, location, control, params)
	SIGNAL_HANDLER
	UnregisterSignal(source, COMSIG_CLIENT_MOUSEUP)
	if(aiming && aiming_time_left <= aiming_time_fire_threshold && check_user())
		to_chat(chassis.occupants, "[icon2html(src, chassis.occupants)][span_warning("Target locked! Firing missile!")]")
		fire_missile()
	stop_aiming()

// ===== AIMING SYSTEM =====

/obj/item/mecha_parts/mecha_equipment/weapon/ballistic/launcher/atgm/proc/start_aiming(params, atom/initial_target = null)
	if(aiming || current_missile)
		return FALSE

	if(!check_user())
		return FALSE

	aiming = TRUE
	aiming_time_left = aiming_time
	lastangle = 0 // Initialize last angle

	// For mech equipment, use the initial target atom directly if provided
	if(initial_target)
		var/turf/target_turf = get_turf(initial_target)
		if(target_turf)
			var/turf/source_turf = get_turf(chassis)
			if(source_turf)
				lastangle = get_angle(source_turf, target_turf)
				current_target = target_turf
			create_laser_tracer_at_turf(target_turf)
	else
		create_laser_tracer(params)

	// Set up timer for aiming lock
	if(aiming_timer)
		deltimer(aiming_timer)
	aiming_timer = addtimer(CALLBACK(src, PROC_REF(complete_aiming)), aiming_time, TIMER_STOPPABLE)

	// Register client signals for mouse tracking
	if(current_user?.client)
		register_client_signals(current_user)

	// Let the user know aiming has started
	to_chat(chassis.occupants, "[icon2html(src, chassis.occupants)][span_notice("ATGM targeting system activated. Click again to fire or cancel.")]")
	return TRUE

/obj/item/mecha_parts/mecha_equipment/weapon/ballistic/launcher/atgm/proc/complete_aiming()
	if(aiming && check_user())
		aiming_time_left = aiming_time_fire_threshold - 0.1 // Just below threshold to allow firing
		to_chat(chassis.occupants, "[icon2html(src, chassis.occupants)][span_notice("Target lock acquired! Click again to fire.")]")
	aiming_timer = null

/obj/item/mecha_parts/mecha_equipment/weapon/ballistic/launcher/atgm/proc/stop_aiming()
	aiming = FALSE
	aiming_time_left = 0
	if(aiming_timer)
		deltimer(aiming_timer)
		aiming_timer = null
	cleanup_tracer()

	// Unregister client signals when stopping aiming
	if(current_user?.client)
		unregister_client_signals(current_user)

/obj/item/mecha_parts/mecha_equipment/weapon/ballistic/launcher/atgm/proc/stop_aiming_preserve_missile()
	aiming = FALSE
	aiming_time_left = 0
	if(aiming_timer)
		deltimer(aiming_timer)
		aiming_timer = null
	cleanup_tracer() // This will cause missile to enter free flight mode

	// Unregister client signals when stopping aiming
	if(current_user?.client)
		unregister_client_signals(current_user)

	// Notify that missile is now in free flight
	if(current_missile && chassis?.occupants)
		to_chat(chassis.occupants, "[icon2html(src, chassis.occupants)][span_notice("ATGM guidance disabled. Missile entering free flight mode.")]")

/obj/item/mecha_parts/mecha_equipment/weapon/ballistic/launcher/atgm/proc/cleanup_aiming_system()
	stop_aiming()
	current_target = null
	lastangle = 0

/obj/item/mecha_parts/mecha_equipment/weapon/ballistic/launcher/atgm/proc/create_laser_tracer(params)
	cleanup_tracer()

	var/turf/laser_turf = calculate_target_turf(params)
	if(!laser_turf)
		return

	create_laser_tracer_at_turf(laser_turf)

/obj/item/mecha_parts/mecha_equipment/weapon/ballistic/launcher/atgm/proc/create_laser_tracer_at_turf(turf/laser_turf)
	cleanup_tracer()

	if(!laser_turf)
		return

	current_tracer = new(laser_turf)
	current_tracer.set_light_color(COLOR_RED)
	current_tracer.set_light_range(3)
	current_tracer.update_beam(chassis)

/obj/item/mecha_parts/mecha_equipment/weapon/ballistic/launcher/atgm/proc/cleanup_tracer()
	QDEL_NULL(current_tracer)

// ===== TARGETING =====

/obj/item/mecha_parts/mecha_equipment/weapon/ballistic/launcher/atgm/proc/get_turf_in_angle(angle, turf/starting_turf, distance)
	if(!starting_turf || !angle || !distance)
		return null

	// Convert angle to radians for calculations
	var/rad_angle = angle * (PI / 180)

	// Calculate target x,y using trigonometry
	// In BYOND: X increases eastward, Y increases northward (upward)
	// BYOND angles: 0° = North, 90° = East, 180° = South, 270° = West

	// Convert BYOND angle to radians for sin/cos calculations
	// Need to rotate the angle since 0° in BYOND is North, not East as in standard trig
	var/target_x = starting_turf.x + round(sin(rad_angle) * distance) // Use sin for X with BYOND angles
	var/target_y = starting_turf.y + round(cos(rad_angle) * distance) // Add because 0° is North (upward)

	// Ensure coordinates are within map bounds
	target_x = clamp(target_x, 1, world.maxx)
	target_y = clamp(target_y, 1, world.maxy)

	// Return the turf at the calculated position
	return locate(target_x, target_y, starting_turf.z)

/obj/item/mecha_parts/mecha_equipment/weapon/ballistic/launcher/atgm/proc/process_aim(params)
	if(!current_user?.client)
		return

	var/turf/target_turf = null

	// Try to get turf from params if available (from client signals)
	if(params)
		target_turf = calculate_target_turf(params)

	// If no turf from params, use the mouse object reference from client
	if(!target_turf && current_user.client?.mouse_object_ref)
		var/atom/mouse_target = current_user.client.mouse_object_ref.resolve()
		if(mouse_target)
			target_turf = get_turf(mouse_target)

	if(!target_turf)
		return

	// Calculate the angle between the mecha and the target turf
	var/turf/source_turf = get_turf(chassis)
	if(!source_turf)
		return

	var/new_angle = get_angle(source_turf, target_turf)

	// Check if there's significant movement and apply penalty
	if(lastangle > 0 && abs(new_angle - lastangle) > 5) // 5 degree threshold
		// Add small penalty for movement, but don't exceed the original aiming time
		aiming_time_left = min(aiming_time, aiming_time_left + movement_penalty)

		// Reset timer if needed
		if(aiming_timer)
			deltimer(aiming_timer)
		aiming_timer = addtimer(CALLBACK(src, PROC_REF(complete_aiming)), aiming_time_left, TIMER_STOPPABLE)

	lastangle = new_angle

	// Update the current target
	current_target = target_turf
	update_laser_position()

/obj/item/mecha_parts/mecha_equipment/weapon/ballistic/launcher/atgm/proc/calculate_target_turf(params)
	if(!current_user?.client || !params)
		return null

	var/list/mouse_params = params2list(params)
	var/icon_x = text2num(mouse_params["icon-x"])
	var/icon_y = text2num(mouse_params["icon-y"])

	if(isnull(icon_x) || isnull(icon_y))
		return null

	return get_turf_at_screen_coords(current_user.client, icon_x, icon_y)

/obj/item/mecha_parts/mecha_equipment/weapon/ballistic/launcher/atgm/proc/update_laser_position()
	if(!current_tracer || !chassis)
		return

	var/turf/origin_turf = get_turf(chassis)
	var/turf/target_turf = current_target ? get_turf(current_target) : get_turf_in_angle(lastangle, origin_turf, missile_range)

	if(!target_turf)
		return

	// Check for dense obstacles in the path
	var/turf/actual_target = target_turf
	var/list/line = get_line(origin_turf, target_turf)
	for(var/turf/T in line)
		if(T == origin_turf) // Skip the starting turf
			continue
		if(T.density)
			actual_target = T
			break
		// Check for windows, doors, and other dense objects
		for(var/obj/structure/S in T)
			if(S.density)
				actual_target = T
				break

	current_tracer.forceMove(actual_target)
	current_tracer.update_beam(chassis)

// Convert screen coordinates to world coordinates
/obj/item/mecha_parts/mecha_equipment/weapon/ballistic/launcher/atgm/proc/get_turf_at_screen_loc(client/client, x_pos, y_pos)
	if(!client?.view || !client?.eye)
		return null

	var/turf/center_turf = get_turf(client.eye)
	if(!center_turf)
		return null

	// Calculate offsets from center based on client's view size
	var/list/view_size = getviewsize(client.view)
	var/x_offset = round(x_pos - (view_size[1] / 2))
	var/y_offset = round(y_pos - (view_size[2] / 2))

	// Get the turf at those coordinates
	return locate(center_turf.x + x_offset, center_turf.y + y_offset, center_turf.z)

// Legacy method - keep for backward compatibility
/obj/item/mecha_parts/mecha_equipment/weapon/ballistic/launcher/atgm/proc/get_turf_at_screen_coords(client/client, icon_x, icon_y)
	if(!client?.eye)
		return null

	var/list/offsets = get_client_pixel_offset(client)
	if(!offsets)
		return null

	var/turf/source = get_turf(client.eye)
	if(!source)
		return null

	var/target_x = clamp(
		source.x + round((icon_x - offsets["x"] - (world.icon_size/2)) / world.icon_size),
		1, world.maxx
	)
	var/target_y = clamp(
		source.y + round((icon_y - offsets["y"] - (world.icon_size/2)) / world.icon_size),
		1, world.maxy
	)

	return locate(target_x, target_y, source.z)

/obj/item/mecha_parts/mecha_equipment/weapon/ballistic/launcher/atgm/proc/get_client_pixel_offset(client/client)
	if(!client)
		return null

	var/list/view_size = getviewsize(client.view)
	return list(
		"x" = round((view_size[1] * world.icon_size) / 2),
		"y" = round((view_size[2] * world.icon_size) / 2)
	)

// ===== WEAPON ACTION =====

/obj/item/mecha_parts/mecha_equipment/weapon/ballistic/launcher/atgm/action(mob/source, atom/target, list/modifiers)
	if(!action_checks(target))
		return FALSE

	set_user(source)

	if(aiming)
		to_chat(chassis.occupants, "[icon2html(src, chassis.occupants)][span_notice("ATGM targeting system deactivated.")]")
		if(aiming_time_left <= aiming_time_fire_threshold && check_user())
			to_chat(chassis.occupants, "[icon2html(src, chassis.occupants)][span_warning("Target locked! Firing missile!")]")
			fire_missile()
			stop_aiming() // Normal stop when firing
		else
			// User manually cancelled - preserve missile in free flight
			stop_aiming_preserve_missile()
		return TRUE

	if(current_missile)
		return FALSE

	// Get current mouse position for initial targeting
	var/client/C = source.client
	if(!C)
		return FALSE

	// Start the aiming process - pass the target atom for mech equipment
	var/success = start_aiming(C.mouseParams || list(), target)

	// If we successfully started aiming, register mouse down signal for firing
	if(success && aiming && C)
		RegisterSignal(C, COMSIG_CLIENT_MOUSEDOWN, PROC_REF(on_mouse_down))

	return success

// ===== MISSILE MANAGEMENT =====

/obj/item/mecha_parts/mecha_equipment/weapon/ballistic/launcher/atgm/proc/fire_missile()
	if(projectiles <= 0 || !current_tracer || !chassis)
		stop_aiming()
		return FALSE

	projectiles--

	var/turf/start_turf = get_turf(chassis)
	current_missile = new projectile(start_turf)
	current_missile.guiding_laser = current_tracer
	current_missile.launcher = src
	// Set the firer to the current user to prevent null reference errors
	current_missile.firer = current_user

	// Calculate the angle to the target
	var/target_angle = lastangle
	if(current_target)
		target_angle = get_angle(start_turf, current_target)

	current_missile.aim_projectile(current_tracer, current_user)
	current_missile.fire(target_angle)

	playsound(chassis, fire_sound, 50, TRUE)
	log_message("Fired [current_missile.name] from [name].", LOG_MECHA)

	// Transfer tracer ownership to missile
	current_tracer = null
	stop_aiming()
	return TRUE

// create_missile_tether removed - missile now uses distance-based free flight

/obj/item/mecha_parts/mecha_equipment/weapon/ballistic/launcher/atgm/proc/missile_released()
	current_missile = null

/obj/item/mecha_parts/mecha_equipment/weapon/ballistic/launcher/atgm/proc/cleanup_missile()
	if(current_missile)
		qdel(current_missile)
		current_missile = null

// ===== MISSILE PROJECTILE =====

/obj/projectile/bullet/rocket/atgm
	name = "guided missile"
	desc = "An advanced anti-tank missile guided by laser designator."
	icon_state = "missile"
	range = 30
	speed = 1

	var/obj/effect/projectile/tracer/laser/atgm/guiding_laser = null
	var/obj/item/mecha_parts/mecha_equipment/weapon/ballistic/launcher/atgm/launcher = null
	var/distance_traveled = 0
	var/max_tether_distance = 8  // Distance at which missile enters free flight
	var/free_flight = FALSE
	var/turn_rate = 5

/obj/projectile/bullet/rocket/atgm/Initialize(mapload)
	. = ..()

/obj/projectile/bullet/rocket/atgm/Destroy()

	if(launcher)
		launcher.missile_released()
		launcher = null

	QDEL_NULL(guiding_laser)
	QDEL_NULL(movement_vector)
	return ..()

/obj/projectile/bullet/rocket/atgm/proc/update_guidance()
	if(!guiding_laser || QDELETED(guiding_laser))
		if(!free_flight && launcher?.chassis)
			to_chat(launcher.chassis.occupants, "[icon2html(launcher, launcher.chassis.occupants)][span_warning("Missile has lost laser tracking! Entering free flight mode.")]")
		free_flight = TRUE
		return


	if(!launcher || distance_traveled > max_tether_distance)
		if(!free_flight && launcher?.chassis)
			to_chat(launcher.chassis.occupants, "[icon2html(launcher, launcher.chassis.occupants)][span_warning("Missile has exceeded guidance range! Entering free flight mode.")]")
		free_flight = TRUE
		return


	var/turf/laser_pos = get_turf(guiding_laser)
	var/turf/current_pos = get_turf(src)

	if(!laser_pos || !current_pos)
		return

	var/target_angle = get_angle(current_pos, laser_pos)
	var/angle_diff = angle_difference(angle, target_angle)

	// Dynamic turn rate based on distance to target for more realistic behavior
	// Missiles turn more sharply when close to target
	var/distance = get_dist(current_pos, laser_pos)
	var/dynamic_turn_rate = turn_rate
	if(distance < 5)
		dynamic_turn_rate = turn_rate * 1.5
	else if(distance > 15)
		dynamic_turn_rate = turn_rate * 0.7

	// Limit turn rate for realistic missile physics
	if(abs(angle_diff) > dynamic_turn_rate)
		angle += dynamic_turn_rate * sign(angle_diff)
	else
		angle = target_angle

	// Update movement vector with new angle
	if(movement_vector)
		movement_vector.set_angle(angle)
		movement_vector.set_speed(speed)
	else
		// Fallback: create movement vector if it doesn't exist
		movement_vector = new(speed, angle)

/obj/projectile/bullet/rocket/atgm/proc/angle_difference(current_angle, target_angle)
	var/diff = target_angle - current_angle

	// Normalize to -180 to 180 range
	while(diff > 180)
		diff -= 360
	while(diff < -180)
		diff += 360

	return diff

/obj/projectile/bullet/rocket/atgm/process(delta_time)
	// Call parent process first for normal projectile movement
	. = ..()

	// Only do guidance updates if still alive and not in free flight
	if(QDELETED(src) || free_flight)
		return .

	update_guidance()
	distance_traveled += speed * delta_time

	// Check if missile has exceeded range, but don't delete if in free flight
	if(distance_traveled > range && !free_flight)
		qdel(src)
		return .

	// Update sprite rotation to match flight direction
	transform = transform.Turn(angle - dir2angle(dir))
	return .

/obj/projectile/bullet/rocket/atgm/aim_projectile(atom/target, mob/user)
	if(!target)
		return FALSE

	var/turf/start_pos = get_turf(src)
	var/turf/target_pos = get_turf(target)

	if(!start_pos || !target_pos)
		return FALSE

	angle = get_angle(start_pos, target_pos)
	if(movement_vector)
		movement_vector.set_angle(angle)
	return TRUE

/obj/projectile/bullet/rocket/atgm/fire(set_angle, atom/direct_target)
	if(!isnull(set_angle))
		angle = set_angle

	// Call parent fire() to properly initialize movement_vector
	. = ..(set_angle, direct_target)

	// Ensure movement_vector exists after parent initialization
	if(!movement_vector)
		movement_vector = new(speed, angle)

/obj/projectile/bullet/rocket/atgm/on_hit(atom/target, blocked, pierce_hit)
	// Call parent first for proper rocket handling
	..()
	do_boom(target)
	return BULLET_ACT_HIT

/obj/projectile/bullet/rocket/atgm/do_boom(atom/target, random_crit_gib = FALSE)
	// More powerful explosion for ATGM
	explosion(
		target,
		devastation_range = 1,
		heavy_impact_range = 2,
		light_impact_range = 3,
		flash_range = 4,
		explosion_cause = src
	)

// ===== LASER TRACER =====

/obj/effect/projectile/tracer/laser/atgm
	name = "laser designator"
	desc = "A targeting laser for guided munitions."
	icon = 'icons/obj/weapons/guns/projectiles.dmi'
	icon_state = "ibeam"
	light_color = COLOR_RED
	light_range = 3
	alpha = 200

	var/obj/effect/beam/guidance_beam = null

/obj/effect/projectile/tracer/laser/atgm/Initialize(mapload)
	. = ..()
	set_light_on(TRUE)

/obj/effect/projectile/tracer/laser/atgm/Destroy()
	QDEL_NULL(guidance_beam)
	return ..()

/obj/effect/projectile/tracer/laser/atgm/proc/update_beam(atom/source)
	if(!source)
		return

	QDEL_NULL(guidance_beam)
	// Create a visible beam from source to this object
	guidance_beam = source.Beam(src, icon_state = "laser", icon = 'icons/obj/weapons/guns/projectiles.dmi', time = INFINITY, maxdistance = 30)
	set_light_color(COLOR_RED)
	set_light_range(4)
	set_light_on(TRUE)
