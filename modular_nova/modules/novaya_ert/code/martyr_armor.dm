// Martyr armor absorbs damage incredibly effectively, but the wearer pays the price for it later.
/datum/armor/armor_cin_martyr
	melee = ARMOR_LEVEL_WEAK
	bullet = ARMOR_LEVEL_INSANE // The armor itself barely takes a scratch...
	laser = ARMOR_LEVEL_TINY
	energy = ARMOR_LEVEL_TINY
	bomb = ARMOR_LEVEL_WEAK
	fire = ARMOR_LEVEL_MID
	acid = ARMOR_LEVEL_WEAK
	wound = WOUND_ARMOR_STANDARD

// Vests

/obj/item/clothing/suit/armor/vest/cin_martyr
	name = "\improper GZ-04 'Muchenik' kinetic redistribution vest"
	desc = "A heavy, boxy plate carrier of NRI design, covered in thick, angled plasteel plates and a network of piezoelectric dampeners. 	A small, red warning stencil on the shoulder reads: 'WARNING: KINETIC DEFLECTION SYSTEM - DO NOT REMOVE UNDER LOAD'. 	It is exceptionally effective at stopping ballistic impacts, seemingly too good to be true."
	icon = 'modular_nova/modules/novaya_ert/icons/armor.dmi'
	worn_icon = 'modular_nova/modules/novaya_ert/icons/wornarmor.dmi'
	icon_state = "police_vest"
	inhand_icon_state = "armor"
	blood_overlay_type = "armor"
	armor_type = /datum/armor/armor_cin_martyr
	supports_variations_flags = CLOTHING_DIGITIGRADE_VARIATION_NO_NEW_ICON
	resistance_flags = FIRE_PROOF

	/// List of damage flags that this will attempt to absorb
	var/list/absorbable_armor_flags = list(
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
	/// List to store different damage types with their amounts
	var/list/stored_damage_types = list()
	/// The total amount of "stored" damage the item is holding
	var/stored_damage = 0
	/// Timer ID for applying damage over time
	var/damage_timer_id
	/// Whether this is processing damage over time
	var/processing = FALSE

/obj/item/clothing/suit/armor/vest/cin_martyr/equipped(mob/living/carbon/human/user, slot)
	. = ..()
	if(!(slot & ITEM_SLOT_OCLOTHING))
		return
	RegisterSignals(user, list(COMSIG_ITEM_ATTACK, COMSIG_ITEM_ATTACK_ATOM, COMSIG_ITEM_HIT_REACT), PROC_REF(on_take_damage))
	RegisterSignal(user, COMSIG_PROJECTILE_PREHIT, PROC_REF(on_projectile_hit))
	RegisterSignal(user, COMSIG_LIVING_DEATH, PROC_REF(on_user_death))
	START_PROCESSING(SSobj, src)

/obj/item/clothing/suit/armor/vest/cin_martyr/dropped(mob/living/carbon/human/user)
	. = ..()
	UnregisterSignal(user, list(COMSIG_ITEM_ATTACK, COMSIG_ITEM_ATTACK_ATOM, COMSIG_ITEM_HIT_REACT, COMSIG_PROJECTILE_PREHIT, COMSIG_LIVING_DEATH))

	// Cancel any active timer
	if(damage_timer_id)
		deltimer(damage_timer_id)
		damage_timer_id = null

	// If removed while still holding damage, apply it all at once in a final, brutal reckoning.
	if(stored_damage > 0)
		release_all_damage(user)

	if(processing)
		processing = FALSE
		STOP_PROCESSING(SSobj, src)

/obj/item/clothing/suit/armor/vest/cin_martyr/process(seconds_per_tick)
	var/total_damage = 0
	for(var/damage_type in stored_damage_types)
		total_damage += stored_damage_types[damage_type]

	if(!ishuman(loc) || total_damage <= 0)
		processing = FALSE
		STOP_PROCESSING(SSobj, src)
		return

	var/mob/living/carbon/human/wearer = loc

	// Cancel any existing timer
	if(damage_timer_id)
		deltimer(damage_timer_id)
		damage_timer_id = null

	apply_damage(wearer)

/// Apply stored damage to the wearer
/obj/item/clothing/suit/armor/vest/cin_martyr/proc/apply_damage(mob/living/carbon/human/wearer)
	if(!ishuman(wearer))
		return

	// Calculate total stored damage
	var/total_damage = 0
	for(var/damage_type in stored_damage_types)
		total_damage += stored_damage_types[damage_type]

	if(total_damage <= 0)
		return

	// Calculate how much damage to apply in total
	var/damage_to_apply = min(total_damage, 5) // Apply it in chunks of 5

	// Apply damage proportionally based on stored damage types
	for(var/damage_type in stored_damage_types)
		if(stored_damage_types[damage_type] <= 0)
			continue

		// Calculate the proportion of this damage type
		var/proportion = stored_damage_types[damage_type] / total_damage
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
		stored_damage -= type_damage // Fix: Decrement the total stored damage

	// Check if all damage has been applied
	var/remaining_damage = 0
	for(var/damage_type in stored_damage_types)
		remaining_damage += stored_damage_types[damage_type]

	if(remaining_damage <= 0)
		wearer.visible_message(span_notice("The faint hum from [wearer]'s [src] finally ceases."),
			span_notice("The deep ache in your bones subsides as the item's systems power down."))
		stored_damage = 0 // Ensure stored_damage is zeroed out
		processing = FALSE
		STOP_PROCESSING(SSobj, src)
	else
		// Set up the next damage application if there's still damage left
		damage_timer_id = addtimer(CALLBACK(src, PROC_REF(apply_damage), wearer), 3 SECONDS, TIMER_STOPPABLE)
		if(!processing)
			processing = TRUE
			START_PROCESSING(SSobj, src)

/// Called when the wearer dies
/obj/item/clothing/suit/armor/vest/cin_martyr/proc/on_user_death(mob/living/source)
	SIGNAL_HANDLER
	// Clear all stored damage when user dies
	stored_damage = 0
	stored_damage_types = list()
	if(damage_timer_id)
		deltimer(damage_timer_id)
		damage_timer_id = null
	processing = FALSE
	STOP_PROCESSING(SSobj, src)

/// Called when the wearer is hit by a projectile
/obj/item/clothing/suit/armor/vest/cin_martyr/proc/on_projectile_hit(mob/living/source, obj/projectile/incoming_projectile)
	SIGNAL_HANDLER

	if(!ishuman(loc))
		return

	// Check if the projectile hit the chest area
	if(incoming_projectile.def_zone != BODY_ZONE_CHEST && incoming_projectile.def_zone != BODY_ZONE_PRECISE_GROIN)
		return

	// Process projectile damage absorption
	var/damage_amount = incoming_projectile.damage
	var/damage_type = incoming_projectile.damage_type
	var/armor_flag = incoming_projectile.armor_flag

	// Only absorb damage that matches our absorbable flags
	if(!(armor_flag in absorbable_armor_flags))
		return

	// Process damage absorption
	if(absorb_damage(damage_amount, damage_type, armor_flag))
		// Also absorb stamina damage if the projectile has it
		if(incoming_projectile.stamina > 0)
			absorb_damage(incoming_projectile.stamina, STAMINA, STAMINA)
		// If we absorbed the damage, start processing if not already
		if(!processing && stored_damage > 0)
			processing = TRUE
			START_PROCESSING(SSobj, src)
		// Prevent the projectile from dealing damage
		incoming_projectile.damage = 0
		return NONE

/// Called when the wearer takes damage
/obj/item/clothing/suit/armor/vest/cin_martyr/proc/on_take_damage(datum/source, damage_amount, damage_type, armor_flag, armor_penetration)
	SIGNAL_HANDLER

	if(!ishuman(loc))
		return

	// Only absorb damage that matches our absorbable flags
	if(!(armor_flag in absorbable_armor_flags))
		return

	// Process damage absorption
	. = absorb_damage(damage_amount, damage_type, armor_flag)

	if(.)
		// If we absorbed the damage, start processing if not already
		if(!processing && stored_damage > 0)
			processing = TRUE
			START_PROCESSING(SSobj, src)
		// Prevent the standard damage application
		return COMPONENT_NO_TAKE_DAMAGE

/// Process damage absorption based on damage type
/obj/item/clothing/suit/armor/vest/cin_martyr/proc/absorb_damage(damage_amount, damage_type, armor_flag)
	. = TRUE // Return TRUE to indicate we are absorbing the hit

	// Different damage types have different absorption rates
	var/absorption_rate = 0.5 // Default absorption rate

	// Determine the actual damage type to store
	var/stored_damage_type = BRUTE // Default to brute damage
	switch(armor_flag)
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

/// Apply all stored damage at once (when item is removed)
/obj/item/clothing/suit/armor/vest/cin_martyr/proc/release_all_damage(mob/living/user)
	if(stored_damage <= 0 || !user)
		return

	to_chat(user, span_userdanger("The pent-up kinetic energy in [src] releases in a violent wave of pain!"))

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

/obj/item/clothing/suit/armor/vest/cin_martyr/examine_more(mob/user)
	. = ..()

	. += "The GZ-04 'Muchenik' (Martyr) system is a terrifyingly pragmatic piece of Imperial technology. \
		Rather than simply stopping a projectile, its piezoelectric lattice captures and redistributes the kinetic energy \
		throughout the entire vest, preventing penetration and catastrophic failure of the plates. \
		The catch is that this energy isn't dissipated safely; it's stored in capacitor-like systems and slowly released \
		as vibrational energy into the wearer's body, transmuting what would have been a lethal wound into a deep, \
		agonizing ache that cripples the user over time. <br>\
		The official doctrine is to wear it only for short, critical engagements, and to never, under any circumstances, \
		remove the vest until its systems show a full discharge. To do so is to risk every ounce of pain it has absorbed \
		being unleashed upon the wearer all at once. It is the choice between a certain, immediate death and a probable, \
		protracted one; a true soldier's sacrifice for the preservation of the Motherland."

	return .

// Hats

/obj/item/clothing/head/helmet/cin_martyr
	name = "\improper GZ-04 'Muchenik' kinetic redistribution helmet"
	desc = "A heavy, full-face helmet that complements the 'Muchenik' vest. It features the same ominous piezoelectric dampening technology.\
	 The visor is a thick, slightly hazy polycarbonate, designed to withstand impacts that would turn a standard helmet to shrapnel."
	icon = 'modular_nova/modules/novaya_ert/icons/armor.dmi'
	worn_icon = 'modular_nova/modules/novaya_ert/icons/wornarmor.dmi'
	icon_state = "police_helmet"
	inhand_icon_state = "helmet"
	armor_type = /datum/armor/armor_cin_martyr
	flags_inv = HIDEMASK|HIDEEARS|HIDEEYES|HIDEFACE|HIDEHAIR|HIDEFACIALHAIR|HIDESNOUT
	flags_cover = HEADCOVERSEYES | HEADCOVERSMOUTH | PEPPERPROOF
	dog_fashion = null
	supports_variations_flags = CLOTHING_SNOUTED_VARIATION_NO_NEW_ICON
	resistance_flags = FIRE_PROOF

	/// List of damage flags that this will attempt to absorb
	var/list/absorbable_armor_flags = list(
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
	/// List to store different damage types with their amounts
	var/list/stored_damage_types = list()
	/// The total amount of "stored" damage the item is holding
	var/stored_damage = 0
	/// Timer ID for applying damage over time
	var/damage_timer_id
	/// Whether this is processing damage over time
	var/processing = FALSE

/obj/item/clothing/head/helmet/cin_martyr/Initialize(mapload)
	. = ..()

/obj/item/clothing/head/helmet/cin_martyr/equipped(mob/living/carbon/human/user, slot)
	. = ..()
	if(!(slot & ITEM_SLOT_HEAD))
		return
	RegisterSignals(user, list(COMSIG_ITEM_ATTACK, COMSIG_ITEM_ATTACK_ATOM, COMSIG_ITEM_HIT_REACT), PROC_REF(on_take_damage))
	RegisterSignal(user, COMSIG_PROJECTILE_PREHIT, PROC_REF(on_projectile_hit))
	RegisterSignal(user, COMSIG_LIVING_DEATH, PROC_REF(on_user_death))
	START_PROCESSING(SSobj, src)

/obj/item/clothing/head/helmet/cin_martyr/dropped(mob/living/carbon/human/user)
	. = ..()
	UnregisterSignal(user, list(COMSIG_ITEM_ATTACK, COMSIG_ITEM_ATTACK_ATOM, COMSIG_ITEM_HIT_REACT, COMSIG_PROJECTILE_PREHIT, COMSIG_LIVING_DEATH))

	// Cancel any active timer
	if(damage_timer_id)
		deltimer(damage_timer_id)
		damage_timer_id = null

	// If removed while still holding damage, apply it all at once in a final, brutal reckoning.
	if(stored_damage > 0)
		release_all_damage(user)

	if(processing)
		processing = FALSE
		STOP_PROCESSING(SSobj, src)

/obj/item/clothing/head/helmet/cin_martyr/process(seconds_per_tick)
	var/total_damage = 0
	for(var/damage_type in stored_damage_types)
		total_damage += stored_damage_types[damage_type]

	if(!ishuman(loc) || total_damage <= 0)
		processing = FALSE
		STOP_PROCESSING(SSobj, src)
		return

	var/mob/living/carbon/human/wearer = loc

	// Cancel any existing timer
	if(damage_timer_id)
		deltimer(damage_timer_id)
		damage_timer_id = null

	apply_damage(wearer)

/// Apply stored damage to the wearer
/obj/item/clothing/head/helmet/cin_martyr/proc/apply_damage(mob/living/carbon/human/wearer)
	if(!ishuman(wearer))
		return

	// Calculate total stored damage
	var/total_damage = 0
	for(var/damage_type in stored_damage_types)
		total_damage += stored_damage_types[damage_type]

	if(total_damage <= 0)
		return

	// Calculate how much damage to apply in total
	var/damage_to_apply = min(total_damage, 5) // Apply it in chunks of 5

	// Apply damage proportionally based on stored damage types
	for(var/damage_type in stored_damage_types)
		if(stored_damage_types[damage_type] <= 0)
			continue

		// Calculate the proportion of this damage type
		var/proportion = stored_damage_types[damage_type] / total_damage
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
		stored_damage -= type_damage // Fix: Decrement the total stored damage

	// Check if all damage has been applied
	var/remaining_damage = 0
	for(var/damage_type in stored_damage_types)
		remaining_damage += stored_damage_types[damage_type]

	if(remaining_damage <= 0)
		wearer.visible_message(span_notice("The faint hum from [wearer]'s [src] finally ceases."),
			span_notice("The deep ache in your bones subsides as the item's systems power down."))
		stored_damage = 0 // Ensure stored_damage is zeroed out
		processing = FALSE
		STOP_PROCESSING(SSobj, src)
	else
		// Set up the next damage application if there's still damage left
		damage_timer_id = addtimer(CALLBACK(src, PROC_REF(apply_damage), wearer), 3 SECONDS, TIMER_STOPPABLE)
		if(!processing)
			processing = TRUE
			START_PROCESSING(SSobj, src)

/// Called when the wearer dies
/obj/item/clothing/head/helmet/cin_martyr/proc/on_user_death(mob/living/source)
	SIGNAL_HANDLER
	// Clear all stored damage when user dies
	stored_damage = 0
	stored_damage_types = list()
	if(damage_timer_id)
		deltimer(damage_timer_id)
		damage_timer_id = null
	processing = FALSE
	STOP_PROCESSING(SSobj, src)

/// Called when the wearer is hit by a projectile
/obj/item/clothing/head/helmet/cin_martyr/proc/on_projectile_hit(mob/living/source, obj/projectile/incoming_projectile)
	SIGNAL_HANDLER

	if(!ishuman(loc))
		return

	// Check if the projectile hit the head area
	if(incoming_projectile.def_zone != BODY_ZONE_HEAD && incoming_projectile.def_zone != BODY_ZONE_PRECISE_EYES && incoming_projectile.def_zone != BODY_ZONE_PRECISE_MOUTH)
		return

	// Process projectile damage absorption
	var/damage_amount = incoming_projectile.damage
	var/damage_type = incoming_projectile.damage_type
	var/armor_flag = incoming_projectile.armor_flag

	// Only absorb damage that matches our absorbable flags
	if(!(armor_flag in absorbable_armor_flags))
		return

	// Process damage absorption
	if(absorb_damage(damage_amount, damage_type, armor_flag))
		// Also absorb stamina damage if the projectile has it
		if(incoming_projectile.stamina > 0)
			absorb_damage(incoming_projectile.stamina, STAMINA, STAMINA)
		// If we absorbed the damage, start processing if not already
		if(!processing && stored_damage > 0)
			processing = TRUE
			START_PROCESSING(SSobj, src)
		// Prevent the projectile from dealing damage
		incoming_projectile.damage = 0
		return NONE

/// Called when the wearer takes damage
/obj/item/clothing/head/helmet/cin_martyr/proc/on_take_damage(datum/source, damage_amount, damage_type, armor_flag, armor_penetration)
	SIGNAL_HANDLER

	if(!ishuman(loc))
		return

	// Only absorb damage that matches our absorbable flags
	if(!(armor_flag in absorbable_armor_flags))
		return

	// Process damage absorption
	. = absorb_damage(damage_amount, damage_type, armor_flag)

	if(.)
		// If we absorbed the damage, start processing if not already
		if(!processing && stored_damage > 0)
			processing = TRUE
			START_PROCESSING(SSobj, src)
		// Prevent the standard damage application
		return COMPONENT_NO_TAKE_DAMAGE

/// Process damage absorption based on damage type
/obj/item/clothing/head/helmet/cin_martyr/proc/absorb_damage(damage_amount, damage_type, armor_flag)
	. = TRUE // Return TRUE to indicate we are absorbing the hit

	// Different damage types have different absorption rates
	var/absorption_rate = 0.5 // Default absorption rate

	// Determine the actual damage type to store
	var/stored_damage_type = BRUTE // Default to brute damage
	switch(armor_flag)
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

/// Apply all stored damage at once (when item is removed)
/obj/item/clothing/head/helmet/cin_martyr/proc/release_all_damage(mob/living/user)
	if(stored_damage <= 0 || !user)
		return

	to_chat(user, span_userdanger("The pent-up kinetic energy in [src] releases in a violent wave of pain!"))

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

/obj/item/clothing/head/helmet/cin_martyr/examine_more(mob/user)
	. = ..()

	. += "The helmet of the 'Muchenik' system operates on the same brutal principle as the vest. \
		A shot to the head that should have been fatal instead results in a concussive force distributed \
		as a debilitating migraine and internal trauma, stored within the helmet's systems. \
		The recommended procedure is to keep it sealed until the vest's dispersal cycle is complete, \
		allowing the energy to be safely bled off through the neural interface in the collar. \
		Removing it early is known to cause catastrophic cerebral hemorrhaging in test subjects. \
		It is the ultimate act of faith in Imperial engineering: betting your mind and body that the battle \
		will be over before the armor's price claims you."

	return .
