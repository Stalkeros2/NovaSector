/datum/component/kinetic_absorption
	/// Callback to call when damage is absorbed
	var/datum/callback/absorption_callback
	/// List of damage flags that this component will attempt to absorb
	var/list/absorbable_damage_flags = list(
		MELEE,
		BULLET,
		LASER,
		ENERGY,
		BOMB,
		BIO,
		FIRE,
		ACID,
		STAMINA
	)
	/// The total amount of "stored" damage the item is holding
	var/stored_damage = 0
	/// List to store different damage types with their amounts
	var/list/stored_damage_types = list()
	/// The COOLDOWN for applying damage over time
	COOLDOWN_DECLARE(damage_timer)
	/// Whether this component is processing damage over time
	var/processing = FALSE
	/// Who is wearing the target?
	var/mob/living/wearer

/datum/component/kinetic_absorption/Initialize(datum/callback/absorption_callback)
	if(!isitem(parent))
		return COMPONENT_INCOMPATIBLE

	if(absorption_callback)
		src.absorption_callback = absorption_callback

	// Set up initial wearer if the item is already equipped
	var/obj/item/parent_item = parent
	if(ismob(parent_item.loc))
		var/mob/holder = parent_item.loc
		if(holder.is_holding(parent_item))
			return
		set_wearer(holder)

/datum/component/kinetic_absorption/RegisterWithParent()
	RegisterSignal(parent, COMSIG_ATOM_TAKE_DAMAGE, PROC_REF(on_take_damage))
	RegisterSignal(parent, COMSIG_ITEM_EQUIPPED, PROC_REF(on_equipped))
	RegisterSignal(parent, COMSIG_ITEM_DROPPED, PROC_REF(lost_wearer))

/datum/component/kinetic_absorption/UnregisterFromParent()
	UnregisterSignal(parent, list(COMSIG_ATOM_TAKE_DAMAGE, COMSIG_ITEM_EQUIPPED, COMSIG_ITEM_DROPPED))
	if(wearer)
		UnregisterSignal(wearer, COMSIG_QDELETING)

/// Check if we've been equipped to a valid slot
/datum/component/kinetic_absorption/proc/on_equipped(datum/source, mob/user, slot)
	SIGNAL_HANDLER

	if((slot & ITEM_SLOT_HANDS))
		lost_wearer(source, user)
		return
	set_wearer(user)

/// Either we've been dropped or our wearer has been QDEL'd
/datum/component/kinetic_absorption/proc/lost_wearer(datum/source, mob/user)
	SIGNAL_HANDLER

	wearer = null
	if(processing)
		processing = FALSE
		STOP_PROCESSING(SSobj, src)

/// Sets the wearer and registers the appropriate signals
/datum/component/kinetic_absorption/proc/set_wearer(mob/user)
	if(wearer == user)
		return
	if(!isnull(wearer))
		CRASH("[type] called set_wearer with [user] but [wearer] was already the wearer!")

	wearer = user
	RegisterSignal(wearer, COMSIG_QDELETING, PROC_REF(lost_wearer))

/**
 * Called when the parent takes damage
 *
 * Arguments:
 * * source The atom dealing the damage
 * * damage_amount The amount of damage being dealt
 * * damage_type The type of damage being dealt
 * * damage_flag The damage flag being used
 * * armor_penetration The amount of armor penetration being applied
 */
/datum/component/kinetic_absorption/proc/on_take_damage(datum/source, damage_amount, damage_type, damage_flag, armor_penetration)
	SIGNAL_HANDLER

	if(!isitem(parent) || !wearer)
		return

	// Only absorb damage that matches our absorbable flags
	if(!(damage_flag in absorbable_damage_flags))
		return

	// Process damage absorption
	. = absorb_damage(damage_amount, damage_type, damage_flag)

	if(.)
		// If we absorbed the damage, start processing if not already
		if(!processing && stored_damage > 0)
			processing = TRUE
			START_PROCESSING(SSobj, src)
		// Prevent the standard damage application
		return COMPONENT_NO_TAKE_DAMAGE

/// Process damage absorption based on damage type
/datum/component/kinetic_absorption/proc/absorb_damage(damage_amount, damage_type, damage_flag)
	. = TRUE // Return TRUE to indicate we are absorbing the hit

	// Different damage types have different absorption rates
	var/absorption_rate = 0.5 // Default absorption rate

	// Determine the actual damage type to store
	var/stored_damage_type = BRUTE // Default to brute damage
	switch(damage_flag)
		if(BULLET)
			absorption_rate = 0.8 // Excellent bullet protection
			stored_damage_type = BRUTE
		if(MELEE)
			absorption_rate = 0.7 // Good melee protection
			stored_damage_type = BRUTE
		if(LASER, ENERGY)
			absorption_rate = 0.3 // Poor energy protection
			stored_damage_type = BURN
		if(BOMB)
			absorption_rate = 0.6 // Moderate explosion protection
			stored_damage_type = BRUTE // Bomb damage is typically brute
		if(FIRE)
			absorption_rate = 0.4 // Low environmental protection
			stored_damage_type = BURN
		if(ACID)
			absorption_rate = 0.4 // Low environmental protection
			stored_damage_type = BURN
		if(TOX)
			absorption_rate = 0.5 // Toxin damage
			stored_damage_type = TOX
		if(OXY)
			absorption_rate = 0.5 // Oxygen damage
			stored_damage_type = OXY
		if(BIO)
			absorption_rate = 0.5 // Biological damage
			stored_damage_type = TOX // Treat bio as toxin
		if(STAMINA)
			absorption_rate = 0.5 // Stamina damage
			stored_damage_type = STAMINA
		else
			absorption_rate = 0.5 // Default for other types
			stored_damage_type = BRUTE

	var/damage_to_store = damage_amount * absorption_rate
	stored_damage += damage_to_store // Store total damage amount

	// Store damage by type
	if(!stored_damage_types[stored_damage_type])
		stored_damage_types[stored_damage_type] = 0
	stored_damage_types[stored_damage_type] += damage_to_store

	return TRUE

/// Process damage over time
/datum/component/kinetic_absorption/process(seconds_per_tick)
	if(!isitem(parent) || !wearer || !ishuman(wearer) || stored_damage <= 0)
		processing = FALSE
		STOP_PROCESSING(SSobj, src)
		return

	if(!COOLDOWN_FINISHED(src, damage_timer))
		return

	COOLDOWN_START(src, damage_timer, 1 SECONDS) // Apply stored damage every second

	// Calculate how much damage to apply in total
	var/damage_to_apply = min(stored_damage, 5) // Apply it in chunks of 5

	// Apply damage proportionally based on stored damage types
	for(var/damage_type in stored_damage_types)
		if(stored_damage_types[damage_type] <= 0)
			continue

		// Calculate the proportion of this damage type
		var/proportion = stored_damage_types[damage_type] / stored_damage
		var/type_damage = damage_to_apply * proportion

		// Apply the appropriate damage type
		switch(damage_type)
			if(BRUTE)
				wearer.adjustBruteLoss(type_damage)
			if(BURN)
				wearer.adjustFireLoss(type_damage)
			if(TOX)
				wearer.adjustToxLoss(type_damage)
			if(OXY)
				wearer.adjustOxyLoss(type_damage)
			if(STAMINA)
				wearer.adjustStaminaLoss(type_damage)

		// Update the stored damage amounts
		stored_damage_types[damage_type] -= type_damage

	// Update total stored damage
	stored_damage -= damage_to_apply

	if(stored_damage <= 0)
		wearer.visible_message(span_notice("The faint hum from [wearer]'s [parent] finally ceases."),
			span_notice("The deep ache in your bones subsides as the item's systems power down."))
		processing = FALSE
		STOP_PROCESSING(SSobj, src)

/// Apply all stored damage at once (when item is removed)
/datum/component/kinetic_absorption/proc/release_all_damage(mob/living/user)
	if(stored_damage <= 0 || !user)
		return

	to_chat(user, span_userdanger("The pent-up kinetic energy in [parent] releases in a violent wave of pain!"))

	// Apply all stored damage types at once
	for(var/damage_type in stored_damage_types)
		if(stored_damage_types[damage_type] <= 0)
			continue

		// Apply the appropriate damage type
		switch(damage_type)
			if(BRUTE)
				user.adjustBruteLoss(stored_damage_types[damage_type])
			if(BURN)
				user.adjustFireLoss(stored_damage_types[damage_type])
			if(TOX)
				user.adjustToxLoss(stored_damage_types[damage_type])
			if(OXY)
				user.adjustOxyLoss(stored_damage_types[damage_type])
			if(STAMINA)
				user.adjustStaminaLoss(stored_damage_types[damage_type])

	user.Paralyze(2 SECONDS)
	stored_damage = 0
	stored_damage_types = list() // Clear the damage types list
	processing = FALSE
	STOP_PROCESSING(SSobj, src)
