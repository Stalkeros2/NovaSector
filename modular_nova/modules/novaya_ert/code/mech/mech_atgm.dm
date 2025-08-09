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

	// Targeting
	var/lastangle = 0
	var/atom/current_target = null
	var/obj/effect/projectile/tracer/laser/atgm/current_tracer = null

	// Missile tracking
	var/obj/projectile/bullet/rocket/atgm/current_missile = null
	var/datum/component/tether/missile_tether = null

/obj/item/mecha_parts/mecha_equipment/weapon/ballistic/launcher/atgm/Destroy()
	cleanup_aiming_system()
	cleanup_missile()
	return ..()

/obj/item/mecha_parts/mecha_equipment/weapon/ballistic/launcher/atgm/detach()
	cleanup_aiming_system()
	cleanup_missile()
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

	cleanup_aiming_system()
	unregister_client_signals()

	current_user = user
	if(user?.client)
		register_client_signals()

/obj/item/mecha_parts/mecha_equipment/weapon/ballistic/launcher/atgm/proc/register_client_signals()
	if(!current_user?.client)
		return

	RegisterSignal(current_user.client, COMSIG_CLIENT_MOUSEDOWN, PROC_REF(on_mouse_down))
	RegisterSignal(current_user.client, COMSIG_CLIENT_MOUSEDRAG, PROC_REF(on_mouse_drag))
	RegisterSignal(current_user.client, COMSIG_CLIENT_MOUSEUP, PROC_REF(on_mouse_up))

/obj/item/mecha_parts/mecha_equipment/weapon/ballistic/launcher/atgm/proc/unregister_client_signals()
	if(!current_user?.client || QDELETED(current_user.client))
		return

	UnregisterSignal(current_user.client, list(
		COMSIG_CLIENT_MOUSEDOWN,
		COMSIG_CLIENT_MOUSEDRAG,
		COMSIG_CLIENT_MOUSEUP
	))

// ===== MOUSE INPUT HANDLING =====

/obj/item/mecha_parts/mecha_equipment/weapon/ballistic/launcher/atgm/proc/on_mouse_down(client/source, atom/movable/object, location, control, params)
	SIGNAL_HANDLER

	if(!validate_mouse_input(source, object))
		return

	INVOKE_ASYNC(src, PROC_REF(start_aiming), params)

/obj/item/mecha_parts/mecha_equipment/weapon/ballistic/launcher/atgm/proc/on_mouse_drag(client/source, src_object, over_object, src_location, over_location, src_control, over_control, params)
	SIGNAL_HANDLER

	if(!aiming || !check_user())
		return

	process_aim(params)

/obj/item/mecha_parts/mecha_equipment/weapon/ballistic/launcher/atgm/proc/on_mouse_up(client/source, atom/movable/object, location, control, params)
	SIGNAL_HANDLER

	if(!object?.IsAutoclickable())
		return

	process_aim(params)

	if(aiming_time_left <= aiming_time_fire_threshold && check_user())
		fire_missile()

	stop_aiming()

/obj/item/mecha_parts/mecha_equipment/weapon/ballistic/launcher/atgm/proc/validate_mouse_input(client/source, atom/movable/object)
	if(source.mob != current_user)
		return FALSE
	if(!object?.IsAutoclickable())
		return FALSE
	if(object in source.mob.contents || object == source.mob)
		return FALSE
	return TRUE

// ===== AIMING SYSTEM =====

/obj/item/mecha_parts/mecha_equipment/weapon/ballistic/launcher/atgm/proc/start_aiming(params)
	if(aiming || current_missile)
		return FALSE

	if(!check_user())
		return FALSE

	aiming = TRUE
	aiming_time_left = aiming_time

	create_laser_tracer(params)
	START_PROCESSING(SSfastprocess, src)
	return TRUE

/obj/item/mecha_parts/mecha_equipment/weapon/ballistic/launcher/atgm/proc/stop_aiming()
	aiming = FALSE
	aiming_time_left = 0
	STOP_PROCESSING(SSfastprocess, src)
	cleanup_tracer()

/obj/item/mecha_parts/mecha_equipment/weapon/ballistic/launcher/atgm/proc/cleanup_aiming_system()
	stop_aiming()
	current_target = null
	lastangle = 0

/obj/item/mecha_parts/mecha_equipment/weapon/ballistic/launcher/atgm/proc/create_laser_tracer(params)
	cleanup_tracer()

	var/turf/laser_turf = calculate_target_turf(params)
	if(!laser_turf)
		return

	current_tracer = new(laser_turf)
	current_tracer.set_light_color(COLOR_RED)
	current_tracer.set_light_range(3)
	current_tracer.update_beam(chassis)

/obj/item/mecha_parts/mecha_equipment/weapon/ballistic/launcher/atgm/proc/cleanup_tracer()
	QDEL_NULL(current_tracer)

// ===== TARGETING =====

/obj/item/mecha_parts/mecha_equipment/weapon/ballistic/launcher/atgm/proc/process_aim(params)
	if(!params || !current_user?.client)
		return

	var/angle = mouse_angle_from_client(current_user.client, params)
	if(isnull(angle))
		return

	lastangle = angle

	var/turf/target_turf = calculate_target_turf(params)
	if(target_turf)
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

	var/turf/target_turf = current_target ? get_turf(current_target) : get_turf_in_angle(lastangle, get_turf(chassis), missile_range)

	if(target_turf)
		current_tracer.forceMove(target_turf)
		current_tracer.update_beam(chassis)

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

// ===== PROCESSING =====

/obj/item/mecha_parts/mecha_equipment/weapon/ballistic/launcher/atgm/process(delta_time)
	if(!aiming || !check_user())
		stop_aiming()
		return

	aiming_time_left = max(0, aiming_time_left - delta_time)

	if(aiming_time_left <= 0)
		fire_missile()
		return

	// Update laser position based on current mouse position
	var/client/user_client = current_user.client
	if(!user_client?.mouseParams)
		return

	var/target_angle = mouse_angle_from_client(user_client, user_client.mouseParams)
	if(!isnull(target_angle))
		lastangle = target_angle
		update_laser_position()

// ===== WEAPON ACTION =====

/obj/item/mecha_parts/mecha_equipment/weapon/ballistic/launcher/atgm/action(mob/source, atom/target, list/modifiers)
	if(!action_checks(target))
		return FALSE

	set_user(source)

	if(aiming)
		stop_aiming()
		return FALSE

	if(current_missile)
		return FALSE

	return start_aiming()

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

	current_missile.aim_projectile(current_tracer, current_user)
	current_missile.fire(lastangle)

	create_missile_tether()

	playsound(chassis, fire_sound, 50, TRUE)
	log_message("Fired [current_missile.name] from [name].", LOG_MECHA)

	// Transfer tracer ownership to missile
	current_tracer = null
	stop_aiming()
	return TRUE

/obj/item/mecha_parts/mecha_equipment/weapon/ballistic/launcher/atgm/proc/create_missile_tether()
	if(!current_missile || !chassis)
		return

	missile_tether = chassis.AddComponent(/datum/component/tether, current_missile, 8, "ATGM guidance tether", src)

/obj/item/mecha_parts/mecha_equipment/weapon/ballistic/launcher/atgm/proc/missile_released()
	current_missile = null
	QDEL_NULL(missile_tether)

/obj/item/mecha_parts/mecha_equipment/weapon/ballistic/launcher/atgm/proc/cleanup_missile()
	if(current_missile)
		qdel(current_missile)
		current_missile = null
	QDEL_NULL(missile_tether)

// ===== MISSILE PROJECTILE =====

/obj/projectile/bullet/rocket/atgm
	name = "guided missile"
	desc = "An advanced anti-tank missile guided by laser designator."
	icon_state = "missile"
	range = 30
	speed = 2

	var/obj/effect/projectile/tracer/laser/atgm/guiding_laser = null
	var/obj/item/mecha_parts/mecha_equipment/weapon/ballistic/launcher/atgm/launcher = null
	var/distance_traveled = 0
	var/max_tether_distance = 15
	var/free_flight = FALSE
	var/turn_rate = 5

/obj/projectile/bullet/rocket/atgm/Initialize(mapload)
	. = ..()
	START_PROCESSING(SSfastprocess, src)

/obj/projectile/bullet/rocket/atgm/Destroy()
	STOP_PROCESSING(SSfastprocess, src)

	if(launcher)
		launcher.missile_released()
		launcher = null

	QDEL_NULL(guiding_laser)
	QDEL_NULL(movement_vector)
	return ..()

/obj/projectile/bullet/rocket/atgm/proc/update_guidance()
	if(!guiding_laser || QDELETED(guiding_laser))
		free_flight = TRUE
		return

	if(!launcher || distance_traveled > max_tether_distance)
		free_flight = TRUE
		return

	var/turf/laser_pos = get_turf(guiding_laser)
	var/turf/current_pos = get_turf(src)

	if(!laser_pos || !current_pos)
		return

	var/target_angle = get_angle(current_pos, laser_pos)
	var/angle_diff = angle_difference(angle, target_angle)

	// Limit turn rate for realistic missile physics
	if(abs(angle_diff) > turn_rate)
		angle += turn_rate * sign(angle_diff)
	else
		angle = target_angle

	// Update movement vector with new angle
	if(movement_vector)
		movement_vector.set_angle(angle)
		movement_vector.set_speed(speed)

/obj/projectile/bullet/rocket/atgm/proc/angle_difference(current_angle, target_angle)
	var/diff = target_angle - current_angle

	// Normalize to -180 to 180 range
	while(diff > 180)
		diff -= 360
	while(diff < -180)
		diff += 360

	return diff

/obj/projectile/bullet/rocket/atgm/process(delta_time)
	if(!free_flight && !QDELETED(src))
		update_guidance()

	distance_traveled += speed * delta_time

	// Check if missile has exceeded range
	if(distance_traveled > range)
		qdel(src)
		return

	// Update sprite rotation to match flight direction
	if(!QDELETED(src))
		transform = transform.Turn(angle - dir2angle(dir))

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

	return ..(set_angle, direct_target)

/obj/projectile/bullet/rocket/atgm/on_hit(atom/target, blocked, piercing_hit)
	// Create explosion on impact
	explosion(
		get_turf(src),
		devastation_range = 1,
		heavy_impact_range = 2,
		light_impact_range = 3,
		flash_range = 4
	)

	return ..()

// ===== LASER TRACER =====

/obj/effect/projectile/tracer/laser/atgm
	name = "laser designator"
	desc = "A targeting laser for guided munitions."
	icon = 'icons/obj/weapons/guns/projectiles.dmi'
	icon_state = "laser"
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
    // Use the Beam() proc to create a beam from source to this object
    guidance_beam = source.Beam(src, icon_state = "line", time = INFINITY, maxdistance = INFINITY)

