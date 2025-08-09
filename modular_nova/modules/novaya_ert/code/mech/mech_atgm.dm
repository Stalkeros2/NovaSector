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
	/// Current user of the ATGM system
	var/mob/current_user = null
	/// Whether we're currently aiming
	var/aiming = FALSE
	/// Time needed to fully aim
	var/aiming_time = 3 SECONDS
	/// Time left to aim
	var/aiming_time_left = 0
	/// Last angle of the laser
	var/lastangle = 0
	/// Current laser tracer
	var/obj/effect/projectile/tracer/laser/atgm/current_tracer = null
	/// Current missile in flight (if any)
	var/obj/projectile/bullet/rocket/atgm/current_missile = null
	/// Tether datum for the missile
	var/datum/component/tether/missile_tether = null

/obj/item/mecha_parts/mecha_equipment/weapon/ballistic/launcher/atgm/action(mob/source, atom/target, list/modifiers)
	if(!action_checks(target))
		return FALSE

	if(aiming)
		stop_aiming()
		return FALSE

	if(current_missile) // Already guiding a missile
		return FALSE

	// Start aiming process
	start_aiming(source, target, modifiers)
	return TRUE

/obj/item/mecha_parts/mecha_equipment/weapon/ballistic/launcher/atgm/proc/start_aiming(mob/user, atom/target, list/modifiers)
	current_user = user
	aiming = TRUE
	aiming_time_left = aiming_time

	// Get initial angle from user's mouse position
	var/angle = mouse_angle_from_client(user.client, modifiers)
	lastangle = angle

	// Create laser tracer at a distance from the mech
	var/turf/start_turf = get_turf(chassis)
	var/turf/laser_turf = get_turf_in_angle(angle, start_turf, 5) // Project laser 5 tiles away initially
	current_tracer = new(laser_turf)
	current_tracer.set_light_color(rgb(255, 0, 0))
	current_tracer.set_light_range(3)

	START_PROCESSING(SSfastprocess, src)

/obj/item/mecha_parts/mecha_equipment/weapon/ballistic/launcher/atgm/proc/stop_aiming()
	aiming = FALSE
	current_user = null
	STOP_PROCESSING(SSfastprocess, src)
	QDEL_NULL(current_tracer)

/obj/item/mecha_parts/mecha_equipment/weapon/ballistic/launcher/atgm/process()
	if(!aiming || !current_user || !chassis)
		stop_aiming()
		return

	// Convert mouse params string to list
	var/list/modifiers = params2list(current_user.client.mouseParams)

	// Update angle based on mouse position
	var/angle = mouse_angle_from_client(current_user.client, modifiers)
	var/difference = abs(closer_angle_difference(lastangle, angle))

	// If angle changed significantly, reset aiming time
	if(difference > 5)
		aiming_time_left = aiming_time
		lastangle = angle
	else
		aiming_time_left -= SSfastprocess.wait

	// Update laser position and color
	if(current_tracer)
		var/percent = (aiming_time_left / aiming_time) * 100
		current_tracer.set_light_color(rgb(255 * (percent / 100), 255 * ((100 - percent) / 100), 0))

		// Move laser to new position based on angle
		var/turf/start_turf = get_turf(chassis)
		var/turf/laser_turf = get_turf_in_angle(lastangle, start_turf, 10) // Project laser 10 tiles away
		if(laser_turf)
			current_tracer.forceMove(laser_turf)

	// If aiming time is up and we don't have a missile in flight, fire one
	if(aiming_time_left <= 0 && !current_missile)
		fire_missile()

/obj/item/mecha_parts/mecha_equipment/weapon/ballistic/launcher/atgm/proc/fire_missile()
	if(projectiles <= 0)
		stop_aiming()
		return

	projectiles--
	var/turf/start_turf = get_turf(chassis)
	current_missile = new projectile(start_turf)
	current_missile.guiding_laser = current_tracer
	current_missile.launcher = src

	// Fire the missile at the laser's position
	current_missile.aim_projectile(current_tracer, current_user)
	current_missile.fire(lastangle)

	// Create tether between mech and missile
	missile_tether = chassis.AddComponent(/datum/component/tether, current_missile, 10, "ATGM guidance tether", src)

	playsound(chassis, fire_sound, 50, TRUE)
	log_message("Fired [current_missile.name] from [name].", LOG_MECHA)

/obj/item/mecha_parts/mecha_equipment/weapon/ballistic/launcher/atgm/proc/missile_released()
	current_missile = null
	QDEL_NULL(missile_tether)
	stop_aiming()

/obj/item/mecha_parts/mecha_equipment/weapon/ballistic/launcher/atgm/detach()
	stop_aiming()
	if(current_missile)
		qdel(current_missile)
		current_missile = null
	return ..()

/obj/projectile/bullet/rocket/atgm
	name = "guided missile"
	desc = "An advanced anti-tank missile guided by laser designator."
	icon_state = "missile"
	range = 30
	speed = 2
	/// Reference to the guiding laser
	var/obj/effect/projectile/tracer/laser/atgm/guiding_laser = null
	/// Reference to the launcher
	var/obj/item/mecha_parts/mecha_equipment/weapon/ballistic/launcher/atgm/launcher = null
	/// Distance traveled
	var/distance_traveled = 0
	/// Maximum tether distance before release
	var/max_tether_distance = 15
	/// Whether missile is in free flight
	var/free_flight = FALSE
	/// Turn rate in degrees per process
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
	return ..()

/obj/projectile/bullet/rocket/atgm/set_angle(new_angle)
	angle = new_angle
	if(!nondirectional_sprite)
		transform = transform.Turn(angle - new_angle)

/obj/projectile/bullet/rocket/atgm/process()
	if(free_flight || !guiding_laser || !launcher)
		return

	distance_traveled++

	// If beyond tether distance, release
	if(distance_traveled >= max_tether_distance)
		free_flight = TRUE
		if(launcher)
			launcher.missile_released()
		return

	// Follow laser if still tethered
	if(guiding_laser)
		var/target_angle = get_angle(src, get_turf(guiding_laser))
		var/angle_diff = closer_angle_difference(angle, target_angle)
		var/turn_amount = clamp(angle_diff, -turn_rate, turn_rate)
		set_angle(angle + turn_amount)

/obj/projectile/bullet/rocket/atgm/on_hit(atom/target, blocked = 0, pierce_hit)
	. = ..()
	QDEL_NULL(guiding_laser)
	if(launcher)
		launcher.missile_released()

/obj/effect/projectile/tracer/laser/atgm
	icon_state = "beam_omni"
	light_color = COLOR_RED
	light_range = 3
