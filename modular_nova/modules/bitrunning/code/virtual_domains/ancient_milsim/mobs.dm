/mob/living/basic/trooper/cin_soldier
	name = "Coalition Operative"
	desc = "Death to SolFed."
	melee_damage_lower = 15
	melee_damage_upper = 20
	ai_controller = /datum/ai_controller/basic_controller/trooper/calls_reinforcements/ancient_milsim
	attack_verb_continuous = "slashes"
	attack_verb_simple = "slash"
	attack_sound = 'sound/items/weapons/blade1.ogg'
	attack_vis_effect = ATTACK_EFFECT_SLASH
	faction = list(ROLE_SYNDICATE)
	corpse = /obj/effect/mob_spawn/corpse/human/cin_soldier
	mob_spawner = /obj/effect/mob_spawn/corpse/human/cin_soldier

	/// Reference to the squad leader, if any
	var/mob/living/basic/trooper/cin_soldier/squad_leader
	/// List of squad members following this operative (if they're a leader)
	var/list/mob/living/basic/trooper/cin_soldier/squad_members = list()
	/// Maximum squad size
	var/max_squad_size = 4
	/// Distance to maintain from squad leader
	var/leader_follow_distance = 3
	/// Whether this operative is a squad leader
	var/is_squad_leader = FALSE

/// Called when the mob is initialized to set up squad behavior
/mob/living/basic/trooper/cin_soldier/Initialize(mapload)
	. = ..()
	// Try to find a squad leader to join
	find_squad_leader()
	// If no leader found, become one
	if(!squad_leader)
		become_squad_leader()

/// Makes this operative a squad leader
/mob/living/basic/trooper/cin_soldier/proc/become_squad_leader()
	is_squad_leader = TRUE
	squad_leader = null
	visible_message(span_notice("[src] takes command of the squad."))

/// Makes this operative follow a squad leader
/mob/living/basic/trooper/cin_soldier/proc/follow_squad_leader(mob/living/basic/trooper/cin_soldier/leader)
	if(!leader || leader == src)
		return
	squad_leader = leader
	is_squad_leader = FALSE
	leader.squad_members += src
	visible_message(span_notice("[src] falls in with [leader]."))

/// Finds a nearby squad leader to follow
/mob/living/basic/trooper/cin_soldier/proc/find_squad_leader()
	for(var/mob/living/basic/trooper/cin_soldier/possible_leader in view(7, src))
		if(possible_leader != src && possible_leader.is_squad_leader && possible_leader.squad_members.len < possible_leader.max_squad_size)
			follow_squad_leader(possible_leader)
			return TRUE
	return FALSE

/// Handles squad leader reassignment when the current leader dies
/mob/living/basic/trooper/cin_soldier/proc/reassign_squad_leader()
	if(!is_squad_leader || squad_members.len == 0)
		return

	// Pick a new squad leader from the members
	var/mob/living/basic/trooper/cin_soldier/new_leader = pick(squad_members)

	// Remove everyone from the old squad
	for(var/mob/living/basic/trooper/cin_soldier/member in squad_members)
		member.squad_leader = null
		member.is_squad_leader = FALSE

	// Clear the old squad list
	squad_members.Cut()

	// Make the new leader
	new_leader.become_squad_leader()

	// Have everyone join the new leader's squad
	for(var/mob/living/basic/trooper/cin_soldier/member in view(7, new_leader))
		if(member != new_leader && istype(member, /mob/living/basic/trooper/cin_soldier) && !member.is_squad_leader)
			member.follow_squad_leader(new_leader)

/// Called when the mob dies
/mob/living/basic/trooper/cin_soldier/death(gibbed)
	. = ..()
	// If this was a squad leader, reassign
	if(is_squad_leader)
		reassign_squad_leader()
	// If this was following a leader, remove from the squad
	else if(squad_leader)
		squad_leader.squad_members -= src

/datum/ai_controller/basic_controller/trooper/calls_reinforcements/ancient_milsim
	planning_subtrees = list(
		/datum/ai_planning_subtree/simple_find_target,
		/datum/ai_planning_subtree/call_reinforcements,
		/datum/ai_planning_subtree/follow_squad_leader,
		/datum/ai_planning_subtree/attack_obstacle_in_path/trooper,
		/datum/ai_planning_subtree/basic_melee_attack_subtree,
		/datum/ai_planning_subtree/travel_to_point/and_clear_target/reinforce,
	)
	blackboard = list(
		BB_TARGETING_STRATEGY = /datum/targeting_strategy/basic,
		BB_TARGET_MINIMUM_STAT = SOFT_CRIT,
		BB_REINFORCEMENTS_SAY = "Call contact at nine dash two.",
		BB_SQUAD_FOLLOW_DISTANCE = 3
	)

/datum/ai_controller/basic_controller/trooper/calls_reinforcements/ancient_milsim/ranged
	planning_subtrees = list(
		/datum/ai_planning_subtree/simple_find_target,
		/datum/ai_planning_subtree/call_reinforcements,
		/datum/ai_planning_subtree/follow_squad_leader,
		/datum/ai_planning_subtree/basic_ranged_attack_subtree/trooper,
		/datum/ai_planning_subtree/travel_to_point/and_clear_target/reinforce,
	)

/mob/living/basic/trooper/cin_soldier/melee
	r_hand = /obj/item/melee/energy/sword/saber/purple
	l_hand = /obj/item/shield/energy
	loot = list(/obj/effect/spawner/random/ancient_milsim/melee)
	var/projectile_deflect_chance = 20

/mob/living/basic/trooper/cin_soldier/melee/bullet_act(obj/projectile/projectile)
	if(prob(projectile_deflect_chance))
		visible_message(span_danger("[src] blocks [projectile] with their shield!"))
		return BULLET_ACT_BLOCK
	return ..()

/mob/living/basic/trooper/cin_soldier/ranged
	melee_damage_lower = 5
	melee_damage_upper = 10
	ai_controller = /datum/ai_controller/basic_controller/trooper/calls_reinforcements/ancient_milsim/ranged
	r_hand = /obj/item/gun/ballistic/automatic/miecz
	loot = list(/obj/effect/spawner/random/ancient_milsim/ranged)
	/// Type of bullet we use
	var/casingtype = /obj/item/ammo_casing/c27_54cesarzowa/ancient // We buffed this round, so these guys got unintentionally buffed too.
	/// Sound to play when firing weapon
	var/projectilesound = 'modular_nova/modules/modular_weapons/sounds/smg_light.ogg'
	/// number of burst shots
	var/burst_shots = 2
	/// Time between taking shots
	var/ranged_cooldown = 0.45 SECONDS

/obj/item/ammo_casing/c27_54cesarzowa/ancient
	projectile_type = /obj/projectile/bullet/c27_54cesarzowa/ancient

/obj/projectile/bullet/c27_54cesarzowa/ancient
	name = ".27-54 Cesarzowa piercing bullet casing"
	damage = 18 // original was 15 but we ran this the longest and it worked fine
	armour_penetration = 30
	wound_bonus = -30
	exposed_wound_bonus = -10

/mob/living/basic/trooper/cin_soldier/ranged/Initialize(mapload)
	. = ..()
	AddComponent(\
		/datum/component/ranged_attacks,\
		casing_type = casingtype,\
		projectile_sound = projectilesound,\
		cooldown_time = ranged_cooldown,\
		burst_shots = burst_shots,\
	)

/mob/living/basic/trooper/cin_soldier/ranged/shotgun_revolver
	r_hand = /obj/item/gun/ballistic/revolver/shotgun_revolver
	l_hand = /obj/item/shield/ballistic
	ai_controller = /datum/ai_controller/basic_controller/trooper/ranged/shotgunner
	casingtype = /obj/item/ammo_casing/shotgun/buckshot
	projectilesound = 'modular_nova/modules/sec_haul/sound/revolver_fire.ogg'
	burst_shots = 1
	ranged_cooldown = 1.25 SECONDS
	var/projectile_deflect_chance = 10

/mob/living/basic/trooper/cin_soldier/ranged/shotgun_revolver/bullet_act(obj/projectile/projectile)
	if(prob(projectile_deflect_chance))
		visible_message(span_danger("[src] blocks [projectile] with their shield!"))
		return BULLET_ACT_BLOCK
	return ..()

/datum/modular_mob_segment/cin_mobs
	max = 3
	mobs = list(
		/mob/living/basic/trooper/cin_soldier/ranged,
		/mob/living/basic/trooper/cin_soldier/ranged/shotgun_revolver,
		/mob/living/basic/trooper/cin_soldier/melee,
	)

/obj/effect/mob_spawn/corpse/human/cin_soldier
	name = "Coalition Operative"
	hairstyle = "Bald"
	facial_hairstyle = "Shaved"
	outfit = /datum/outfit/cin_soldier_corpse
	mob_name = "Echo One"

/// Squad leader following behavior for Coalition operatives
/datum/ai_planning_subtree/follow_squad_leader

/// Execute the squad leader following behavior
/datum/ai_planning_subtree/follow_squad_leader/SelectBehaviors(datum/ai_controller/controller, seconds_per_tick)
	var/mob/living/basic/trooper/cin_soldier/soldier = controller.pawn

	// Only follow if we have a squad leader and we're not a leader ourselves
	if(!soldier.squad_leader || soldier.is_squad_leader)
		return

	// Get the follow distance from blackboard or use default
	var/follow_distance = controller.blackboard[BB_SQUAD_FOLLOW_DISTANCE] || 3

	// If we're too far from our leader, move closer
	if(get_dist(soldier, soldier.squad_leader) > follow_distance)
		controller.queue_behavior(/datum/ai_behavior/travel_to_and_from/turf/squad_leader_follow, soldier.squad_leader, follow_distance)
		return SUBTREE_RETURN_BEHAVIOR_PERFORMED

	return SUBTREE_RETURN_CONTINUE

/// Behavior for following a squad leader
/datum/ai_behavior/travel_to_and_from/turf/squad_leader_follow
	action_cooldown = 0.5 SECONDS
	behavior_flags = AI_BEHAVIOR_REQUIRE_MOVEMENT | AI_BEHAVIOR_CAN_PLAN_DURING_EXECUTION

/datum/ai_behavior/travel_to_and_from/turf/squad_leader_follow/setup(datum/ai_controller/controller, target, distance)
	. = ..()
	controller.set_blackboard_key(BB_TRAVEL_TO_AND_FROM_TARGET, target)
	controller.set_blackboard_key(BB_TRAVEL_TO_AND_FROM_DISTANCE, distance)

/datum/ai_behavior/travel_to_and_from/turf/squad_leader_follow/perform(seconds_per_tick, datum/ai_controller/controller, target, distance)
	var/mob/living/basic/trooper/cin_soldier/soldier = controller.pawn
	var/mob/living/basic/trooper/cin_soldier/leader = target

	// If leader is dead or gone, find a new one
	if(!leader || leader.stat == DEAD)
		soldier.squad_leader = null
		soldier.find_squad_leader()
		return AI_BEHAVIOR_DELAY | AI_BEHAVIOR_FAILED

	// If we're close enough, we're done
	if(get_dist(soldier, leader) <= distance)
		return AI_BEHAVIOR_DELAY | AI_BEHAVIOR_SUCCEEDED

	// Otherwise, continue following
	return ..()
