// Blackboard keys
#define BB_CURRENT_TARGET "current_target"

// Chatter types
#define CHATTER_TYPE_IDLE "idle"
#define CHATTER_TYPE_COMBAT "combat"

/// Squad chatter idle behavior for Coalition operatives
/datum/idle_behavior/idle_squad_chatter
	/// Time between possible chatter messages
	var/chatter_cooldown_time = 10 SECONDS
	/// Current dialogue chain being spoken by the squad
	var/list/current_dialogue = null
	/// Map of mob refs to their dialogue chains
	var/static/list/mob_dialogue_map = list()
	/// Timer reference for cooldown
	var/timerid

/datum/idle_behavior/idle_squad_chatter/perform_idle_behavior(seconds_per_tick, datum/ai_controller/controller)
	. = ..()
	var/mob/living/basic/trooper/cin_soldier/soldier = controller.pawn

	// Check if chatter is on cooldown
	if(timerid)
		return

	// Get cooldown time from blackboard or use default
	var/cooldown_time = 30 SECONDS

	// Determine if we should do idle or combat chatter
	var/chatter_type = CHATTER_TYPE_IDLE
	var/datum/weakref/current_target_ref = controller.blackboard[BB_CURRENT_TARGET]
	if(current_target_ref)
		var/atom/current_target = current_target_ref.resolve()
		if(current_target && get_dist(soldier, current_target) <= 7)
			chatter_type = CHATTER_TYPE_COMBAT

	// Determine squad size
	var/squad_size = 1
	if(soldier.is_squad_leader)
		squad_size += soldier.squad_members.len
	else if(soldier.squad_leader)
		squad_size += soldier.squad_leader.squad_members.len

	// Select appropriate chatter based on squad size and type
	var/chatter_message = get_squad_chatter(soldier, squad_size, chatter_type, src)

	// Queue the chatter behavior
	if(chatter_message)
		controller.queue_behavior(/datum/ai_behavior/perform_speech, chatter_message)

	// Set cooldown using timer
	timerid = addtimer(CALLBACK(src, TYPE_PROC_REF(/datum/idle_behavior/idle_squad_chatter, reset_cooldown)), cooldown_time, TIMER_DELETE_ME | TIMER_UNIQUE)

/// Resets the cooldown timer
/datum/idle_behavior/idle_squad_chatter/proc/reset_cooldown()
	timerid = null

/// Helper function to get appropriate squad chatter
/proc/get_squad_chatter(mob/living/basic/trooper/cin_soldier/soldier, squad_size, chatter_type, datum/idle_behavior/idle_squad_chatter/idle_behavior)
	if(!istype(soldier))
		return null

	// Define chatter lists for single operatives
	var/list/idle_chatter_single = list(
		"Checking comms... nothing but static.",
		"Any squads in the area? This is Echo One.",
		"Command, do you read? Over.",
		"Area secure. Moving to next position.",
		"Maintaining vigilance.",
		"Scanning for hostiles."
	)

	var/list/combat_chatter_single = list(
		"Engaging hostiles!",
		"Taking fire! Need backup!",
		"Contact! I'm hit!",
		"Suppressing fire!",
		"Fallback! I need support!",
		"Enemy spotted, engaging!"
	)

	// Define dialogue pairs for two operatives
	var/list/idle_dialogue_pairs = list(
		list("Eyes open, team.", "Roger, watching my sector."),
		list("Status check.", "All green here."),
		list("Moving to next position.", "Covering you."),
		list("Stay frosty.", "Always am."),
		list("See anything?", "Negative, area's clear."),
		list("How's ammo?", "Good to go.")
	)

	var/list/combat_dialogue_pairs = list(
		list("Cover me!", "On it!"),
		list("Flanking left!", "Right side covered!"),
		list("Pushing forward!", "Following your lead!"),
		list("Watch our six!", "Got your back!"),
		list("Concentrate fire!", "Focusing on target!"),
		list("Regroup on me!", "Moving to your position!")
	)

	// Define dialogue chains for squads (3+ operatives)
	var/list/idle_dialogue_chains = list(
		list(
			"Team, maintain formation.",
			"Roger, keeping formation.",
			"Formation tight, moving out."
		),
		list(
			"All units, report status.",
			"Unit one, ready.",
			"Unit two, standing by."
		),
		list(
			"Moving as a unit, stay sharp.",
			"Will keep eyes peeled.",
			"Staying alert for contacts."
		),
		list(
			"Watch each other's backs.",
			"Got your six.",
			"Covering all angles."
		)
	)

	var/list/combat_dialogue_chains = list(
		list(
			"Squad, focus fire on my target!",
			"Focusing on your target!",
			"Laying down suppressive fire!"
		),
		list(
			"Team, form a defensive perimeter!",
			"Left flank secured!",
			"Right flank covered!"
		),
		list(
			"All units, advance on my mark!",
			"Ready to advance!",
			"Waiting for your mark!"
		),
		list(
			"Converge on the hostiles!",
			"Moving to engage!",
			"Flanking maneuver initiated!"
		)
	)

	// Handle single operatives
	if(squad_size == 1)
		var/list/chatter_list = (chatter_type == CHATTER_TYPE_IDLE) ? idle_chatter_single : combat_chatter_single
		if(chatter_list && chatter_list.len)
			return pick(chatter_list)

	// Handle pairs and initiate dialogue
	else if(squad_size >= 2)
		// Get the squad members
		var/list/mob/living/basic/trooper/cin_soldier/squad = list()
		if(soldier.is_squad_leader)
			squad = soldier.squad_members.Copy()
			squad += soldier
		else if(soldier.squad_leader)
			squad = soldier.squad_leader.squad_members.Copy()
			squad += soldier.squad_leader

		// Make sure we have a valid squad list
		if(!squad || squad.len < 2)
			return null

		// Select appropriate dialogue based on squad size and chatter type
		var/list/dialogue
		if(squad_size == 2)
			dialogue = pick((chatter_type == CHATTER_TYPE_IDLE) ? idle_dialogue_pairs : combat_dialogue_pairs)
		else
			dialogue = pick((chatter_type == CHATTER_TYPE_IDLE) ? idle_dialogue_chains : combat_dialogue_chains)

		// Check if we're the first speaker in this dialogue
		if(soldier == squad[1])
			// We're the first speaker, set the dialogue in progress if we're a leader
			if(soldier.is_squad_leader)
				idle_behavior.current_dialogue = dialogue
				idle_behavior.mob_dialogue_map[WEAKREF(soldier)] = dialogue
			// Return the first line
			return dialogue[1]
		else
			// We're not the first speaker, so we need to check if a dialogue is already in progress
			var/datum/weakref/leader_ref = WEAKREF(soldier.squad_leader)
			if(leader_ref && idle_behavior.mob_dialogue_map[leader_ref])
				// There's an active dialogue, find our line
				var/our_position = squad.Find(soldier)
				var/list/leader_dialogue = idle_behavior.mob_dialogue_map[leader_ref]
				if(our_position <= leader_dialogue.len)
					// It's our turn to speak
					var/our_line = leader_dialogue[our_position]
					// If we're the last speaker, clear the dialogue
					if(our_position == leader_dialogue.len)
						idle_behavior.mob_dialogue_map -= leader_ref
					return our_line
			else if(soldier.is_squad_leader && idle_behavior.mob_dialogue_map[WEAKREF(soldier)])
				// We're the squad leader with an active dialogue
				var/our_position = squad.Find(soldier)
				var/list/leader_dialogue = idle_behavior.mob_dialogue_map[WEAKREF(soldier)]
				if(our_position <= leader_dialogue.len)
					// It's our turn to speak
					var/our_line = leader_dialogue[our_position]
					// If we're the last speaker, clear the dialogue
					if(our_position == leader_dialogue.len)
						idle_behavior.mob_dialogue_map -= WEAKREF(soldier)
					return our_line
			else
				// No active dialogue, wait for the leader to initiate
				return null
