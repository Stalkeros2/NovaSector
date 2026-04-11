/// Wall Bond - EPF Heritage Security Certificate
/// Value fluctuates based on security personnel count and alert status
/// Matures (updates price) every payday interval
/// Can be sold to the Security budget account (redeemed for credits)
/// Pays periodic coupon interest on paydays

#define WALL_BOND_UPDATE_INTERVAL (5 MINUTES)  // Same as payday
#define WALL_BOND_BASE_VALUE (250)              // Face value in credits
#define WALL_BOND_VALUE_PER_OFFICER (25)        // Credits added per security personnel
#define WALL_BOND_MAX_OFFICER_BONUS (275)       // Cap at 11 officers (25*11=275)

// Alert multipliers (can go above 1.0 for premiums)
#define WALL_BOND_ALERT_MULT_GREEN (1.10)       // SEC_LEVEL_GREEN - +10% premium
#define WALL_BOND_ALERT_MULT_BLUE (1.00)        // SEC_LEVEL_BLUE - Par value
#define WALL_BOND_ALERT_MULT_VIOLET (0.90)      // SEC_LEVEL_VIOLET - -10%
#define WALL_BOND_ALERT_MULT_ORANGE (0.80)      // SEC_LEVEL_ORANGE - -20%
#define WALL_BOND_ALERT_MULT_AMBER (0.65)       // SEC_LEVEL_AMBER - -35%
#define WALL_BOND_ALERT_MULT_RED (0.40)         // SEC_LEVEL_RED - -60%
#define WALL_BOND_ALERT_MULT_DELTA (0.10)       // SEC_LEVEL_DELTA - -90%

#define WALL_BOND_MIN_VALUE (10)                // Floor value
#define WALL_BOND_COUPON_RATE (0.02)            // 2% per payday (periodic interest)
#define WALL_BOND_MATURITY_MIN (30 MINUTES)     // Minimum maturity time
#define WALL_BOND_MATURITY_MAX (90 MINUTES)     // Maximum maturity time

#define WALL_BOND_COUPON_PAYOUT_ANNOUNCE_THRESHOLD (50) // Announce payouts above this amount

/obj/item/wall_bond
	name = "\improper EPF Heritage Wall Bond"
	desc = "A bearer security certificate issued by the Security department, backed by the Heliostatic Coalition's \
		Expeditionary Police Force heritage. Its value fluctuates based on station stability - it matures in value \
		when security is strong and the alert status is calm. Can be sold back to the Security budget account \
		for current market value (or face value at maturity). Pays periodic coupon interest on paydays. \
		Not redeemable for equipment."
	icon = 'icons/obj/economy.dmi'
	icon_state = "rupee"
	w_class = WEIGHT_CLASS_TINY

	/// Face value - what you get at maturity
	var/face_value = WALL_BOND_BASE_VALUE
	/// Current market value in credits (fluctuates)
	var/current_value = WALL_BOND_BASE_VALUE
	/// When this bond was last updated
	var/last_update_time = 0
	/// When this bond matures (world.time)
	var/maturity_time = 0
	/// Whether this bond has matured already
	var/matured = FALSE
	/// Who printed this bond (for tracking)
	var/datum/bank_account/issuing_account
	/// The department name that issued it
	var/issuing_department = "Security"
	/// The ID card linked to this bond (for notifications)
	var/obj/item/card/id/linked_id
	/// Unique bond serial number
	var/bond_serial
	/// The bank account of the person who purchased this bond (null = unpurchased)
	var/datum/bank_account/owner_account
	/// Last payday when coupon was paid (to avoid double payments)
	var/last_coupon_payday = 0

/obj/item/wall_bond/Initialize(mapload)
	. = ..()
	last_update_time = world.time
	maturity_time = world.time + rand(WALL_BOND_MATURITY_MIN, WALL_BOND_MATURITY_MAX)
	bond_serial = generate_bond_serial()
	update_value()
	update_desc()

/obj/item/wall_bond/Destroy()
	// Clean up references
	if(owner_account)
		unregister_from_owner_account()
	linked_id = null
	issuing_account = null
	owner_account = null
	return ..()

/obj/item/wall_bond/examine(mob/user)
	. = ..()
	. += span_info("Bearer Security Certificate #[bond_serial]")

	if(owner_account)
		. += span_notice("STATUS: Active investment")
		if(linked_id && linked_id.registered_name)
			. += span_info("Investor: [linked_id.registered_name]")
		if(matured)
			. += span_warning("STATUS: MATURED - Redeem immediately for face value!")
		else
			var/time_left = max(0, (maturity_time - world.time) / 600)
			. += span_info("Matures in: [round(time_left)] minutes")
			. += span_info("Next coupon: [WALL_BOND_COUPON_RATE * 100]% of [current_value] credits ([round(current_value * WALL_BOND_COUPON_RATE)] credits)")
	else
		. += span_warning("STATUS: Available for purchase - use your ID on this bond to invest")

	. += span_info("Face value at maturity: [face_value] credits.")
	. += span_info("Current market value: [current_value] credits.")
	. += span_info("Coupon rate: [WALL_BOND_COUPON_RATE * 100]% per payday.")
	. += span_info("Value updates every [WALL_BOND_UPDATE_INTERVAL / 600] minutes based on:")
	. += span_info("- Active security personnel (currently [get_active_security_count()])")
	. += span_info("- Station alert status (currently [get_alert_status_name()])")
	. += span_info("Redeem via any cargo console, or trade to another player who can claim it with their ID.")

	if(issuing_account)
		. += span_notice("Backed by: [issuing_department || issuing_account.account_holder]")

/obj/item/wall_bond/proc/generate_bond_serial()
	return "[uppertext(random_string(3, GLOB.hex_characters))]-[rand(1000, 9999)]"

/obj/item/wall_bond/proc/update_value()
	// Calculate base from security personnel count
	var/security_count = get_active_security_count()
	var/officer_bonus = min(security_count * WALL_BOND_VALUE_PER_OFFICER, WALL_BOND_MAX_OFFICER_BONUS)
	var/new_value = WALL_BOND_BASE_VALUE + officer_bonus

	// Apply alert multiplier (can be >1 for premium or <1 for penalty)
	var/alert_mult = get_alert_multiplier()
	new_value = new_value * alert_mult

	// Apply floor
	var/old_value = current_value
	current_value = max(new_value, WALL_BOND_MIN_VALUE)
	last_update_time = world.time

	// Notify the linked ID card owner if value changed significantly
	if(old_value != current_value && linked_id && owner_account)
		notify_bond_holder(old_value, current_value)

/obj/item/wall_bond/proc/notify_bond_holder(old_value, new_value, coupon_payout = 0)
	if(!owner_account || !linked_id)
		return  // Only purchased bonds notify

	var/mob/holder = linked_id.loc
	var/message = ""

	if(coupon_payout > 0)
		var/yield_text = " ([round((coupon_payout / current_value) * 100, 0.1)]% yield)"
		message = "Wall Bond [bond_serial] paid you [coupon_payout] credits in coupon interest[yield_text]!"
		if(coupon_payout >= WALL_BOND_COUPON_PAYOUT_ANNOUNCE_THRESHOLD)
			message += " Nice return!"
	else
		var/delta = new_value - old_value
		var/delta_text = delta > 0 ? "increased by [delta]" : "decreased by [abs(delta)]"
		var/delta_percent = (delta / old_value) * 100
		message = "Wall Bond [bond_serial] value has [delta_text] ([delta_percent > 0 ? "+" : ""][round(delta_percent, 0.1)]%) to [new_value] credits."

	if(ismob(holder) && holder.client)
		to_chat(holder, span_notice("[icon2html(linked_id.get_cached_flat_icon(), holder)] [message]"))
		playsound(holder, 'sound/machines/beep/twobeep_high.ogg', 50, TRUE)
	else
		var/datum/bank_account/account = linked_id.registered_account
		if(account)
			account.bank_card_talk(message)

/obj/item/wall_bond/proc/get_active_security_count()
	var/list/sec_officers = SSjob.get_all_sec()
	return length(sec_officers)

/obj/item/wall_bond/proc/get_alert_multiplier()
	if(!SSsecurity_level?.current_security_level)
		return WALL_BOND_ALERT_MULT_GREEN

	switch(SSsecurity_level.current_security_level.number_level)
		if(SEC_LEVEL_GREEN)
			return WALL_BOND_ALERT_MULT_GREEN
		if(SEC_LEVEL_BLUE)
			return WALL_BOND_ALERT_MULT_BLUE
		if(SEC_LEVEL_VIOLET)
			return WALL_BOND_ALERT_MULT_VIOLET
		if(SEC_LEVEL_ORANGE)
			return WALL_BOND_ALERT_MULT_ORANGE
		if(SEC_LEVEL_AMBER)
			return WALL_BOND_ALERT_MULT_AMBER
		if(SEC_LEVEL_RED)
			return WALL_BOND_ALERT_MULT_RED
		if(SEC_LEVEL_DELTA)
			return WALL_BOND_ALERT_MULT_DELTA

	return WALL_BOND_ALERT_MULT_GREEN

/obj/item/wall_bond/proc/get_alert_status_name()
	if(!SSsecurity_level?.current_security_level)
		return "GREEN (Standby) - +10% premium"

	switch(SSsecurity_level.current_security_level.number_level)
		if(SEC_LEVEL_GREEN)  return "GREEN (Standby) - +10% premium"
		if(SEC_LEVEL_BLUE)   return "BLUE (Routine) - par value"
		if(SEC_LEVEL_VIOLET) return "VIOLET (Elevated Threat) - -10%"
		if(SEC_LEVEL_ORANGE) return "ORANGE (Hostile Intent) - -20%"
		if(SEC_LEVEL_AMBER)  return "AMBER (High Alert) - -35%"
		if(SEC_LEVEL_RED)    return "RED (Combat) - -60%"
		if(SEC_LEVEL_DELTA)  return "DELTA (Code Red+) - -90%"
	return "UNKNOWN"

/obj/item/wall_bond/proc/needs_update()
	return (world.time - last_update_time) >= WALL_BOND_UPDATE_INTERVAL

/obj/item/wall_bond/proc/check_maturity()
	if(matured || !owner_account)
		return FALSE

	if(world.time >= maturity_time)
		matured = TRUE
		if(linked_id)
			notify_maturity()
		return TRUE
	return FALSE

/obj/item/wall_bond/proc/notify_maturity()
	if(!linked_id)
		return

	var/mob/holder = linked_id.loc
	var/message = "Wall Bond [bond_serial] has MATURED! Redeem it via cargo console for its face value of [face_value] credits."

	if(ismob(holder) && holder.client)
		to_chat(holder, span_warning("[icon2html(linked_id.get_cached_flat_icon(), holder)] [message]"))
		playsound(holder, 'sound/machines/chime.ogg', 50, TRUE)
	else
		var/datum/bank_account/account = linked_id.registered_account
		if(account)
			account.bank_card_talk(message)

// Called by the payday system for value updates
/obj/item/wall_bond/proc/tick_update()
	if(needs_update())
		update_value()
	check_maturity()

// Called by the owner's bank_account/payday() for coupon interest
/obj/item/wall_bond/proc/payday_coupon_payout(payday_id = 0)
	// Only pay if:
	// - Bond is purchased
	// - Not matured yet (matured bonds should be redeemed, not accrue more interest)
	// - Haven't paid this payday already (using payday_id to track)
	if(!owner_account || !issuing_account || matured)
		return FALSE

	// Prevent double payment on same payday
	if(last_coupon_payday == payday_id)
		return FALSE

	var/payout = round(current_value * WALL_BOND_COUPON_RATE)

	if(payout <= 0)
		return FALSE

	// Ensure Security has enough funds
	if(!issuing_account.has_money(payout))
		// Log insufficient funds but don't fail silently - notify holder
		if(linked_id)
			var/mob/holder = linked_id.loc
			if(ismob(holder) && holder.client)
				to_chat(holder, span_warning("Wall Bond [bond_serial] coupon payment failed: Security budget insufficient!"))
		return FALSE

	if(issuing_account.transfer_money(owner_account, payout))
		last_coupon_payday = payday_id

		// Log to account history
		if(owner_account)
			owner_account.add_log_to_history(payout, "Wall Bond [bond_serial] Coupon Payment")

		notify_bond_holder(current_value, current_value, coupon_payout = payout)
		return TRUE

	return FALSE

// Register this bond with the owner's bank account for payday processing
/obj/item/wall_bond/proc/register_with_owner_account()
	if(owner_account && !matured)
		LAZYADD(owner_account.owned_wall_bonds, src)

// Unregister from owner's bank account
/obj/item/wall_bond/proc/unregister_from_owner_account()
	if(owner_account)
		LAZYREMOVE(owner_account.owned_wall_bonds, src)

// Purchase bond with ID card
/obj/item/wall_bond/attackby(obj/item/I, mob/user, params)
	if(istype(I, /obj/item/card/id))
		if(owner_account)
			balloon_alert(user, "bond already purchased!")
			return

		// If the bond has matured, you can't buy it (should be redeemed only)
		if(matured)
			balloon_alert(user, "bond has matured!")
			to_chat(user, span_warning("This bond has already matured and must be redeemed, not purchased."))
			return

		var/obj/item/card/id/id_card = I
		var/datum/bank_account/player_account = id_card.registered_account

		if(!player_account)
			balloon_alert(user, "no bank account linked to ID!")
			return

		// Ensure value is current
		if(needs_update())
			update_value()

		// Get the Security department account
		var/datum/bank_account/security_account = SSeconomy.get_dep_account(ACCOUNT_SEC)
		if(!security_account)
			balloon_alert(user, "no security budget account!")
			return

		// Player must have enough credits
		if(!player_account.has_money(current_value))
			balloon_alert(user, "insufficient funds!")
			to_chat(user, span_warning("You need [current_value] credits to purchase this bond, but only have [player_account.account_balance]."))
			return

		// Transfer FROM player TO Security (player buys bond, Security gets funds)
		if(player_account.transfer_money(security_account, current_value))
			owner_account = player_account
			linked_id = id_card
			issuing_account = security_account

			// Register with owner's account for payday processing
			register_with_owner_account()

			balloon_alert(user, "bond purchased!")
			to_chat(user, span_notice("You purchased Wall Bond [bond_serial] for [current_value] credits."))
			to_chat(user, span_notice("The Security department now holds your [current_value] credits as collateral."))
			to_chat(user, span_notice("The bond pays [WALL_BOND_COUPON_RATE * 100]% ([round(current_value * WALL_BOND_COUPON_RATE)] credits) coupon interest each payday."))
			to_chat(user, span_notice("It matures in [round((maturity_time - world.time) / 600)] minutes for [face_value] credits."))
			playsound(src, 'sound/machines/terminal/terminal_insert_disc.ogg', 50, FALSE)
		else
			balloon_alert(user, "transaction failed!")
		return

	return ..()

// Transfer ownership to another player (for P2P trading)
/obj/item/wall_bond/proc/transfer_ownership(mob/new_owner, obj/item/card/id/new_id)
	if(!owner_account)
		to_chat(new_owner, span_warning("This bond hasn't been purchased yet! It must be bought from Security first."))
		return FALSE

	if(matured)
		to_chat(new_owner, span_warning("This bond has already matured and cannot be transferred. Redeem it instead."))
		return FALSE

	if(!new_id?.registered_account)
		to_chat(new_owner, span_warning("You need a valid ID with a bank account to claim this bond."))
		return FALSE

	// Unregister from old owner
	unregister_from_owner_account()

	// Transfer ownership
	owner_account = new_id.registered_account
	linked_id = new_id

	// Register with new owner
	register_with_owner_account()

	to_chat(new_owner, span_notice("You are now the registered owner of Wall Bond [bond_serial]."))
	to_chat(new_owner, span_notice("Current market value: [current_value] credits. Matures in [round(max(0, (maturity_time - world.time) / 600))] minutes."))

	playsound(src, 'sound/machines/terminal/terminal_insert_disc.ogg', 50, FALSE)
	return TRUE

// Click on bond with an ID to claim ownership (for P2P trading)
/obj/item/wall_bond/attack_self(mob/living/user)
	. = ..()

	// If bond is already purchased and user has an ID, allow claiming ownership
	if(owner_account && !matured)
		var/obj/item/card/id/user_id = user.get_idcard()
		if(user_id && user_id.registered_account)
			if(linked_id == user_id)
				balloon_alert(user, "you already own this bond!")
				return

			// This bond was given/traded to the user physically
			to_chat(user, span_notice("You claim ownership of Wall Bond [bond_serial] with your ID."))
			transfer_ownership(user, user_id)
		else
			balloon_alert(user, "you need an ID with a bank account to claim this bond!")
	else if(!owner_account)
		balloon_alert(user, "this bond hasn't been purchased yet! Use your ID on it to buy it.")
	else if(matured)
		balloon_alert(user, "this bond has matured! Redeem it at a cargo console.")

// Sell bond back to Security department via cargo console
/obj/item/wall_bond/attack_atom(obj/machinery/computer/cargo/cargo_computer, mob/living/user)
	if(!istype(cargo_computer))
		return ..()

	if(!user.can_perform_action(cargo_computer))
		return

	// Only purchased bonds can be redeemed
	if(!owner_account)
		balloon_alert(user, "bond not yet purchased!")
		to_chat(user, span_warning("This bond hasn't been purchased yet. Use your ID on it to buy it first."))
		return

	// Verify ownership
	var/obj/item/card/id/user_id = user.get_idcard()
	if(linked_id && (!user_id || user_id != linked_id))
		balloon_alert(user, "not your bond!")
		to_chat(user, span_warning("This bond is linked to another ID. Only the registered owner can redeem it."))
		return

	// Ensure we're up to date
	if(needs_update())
		update_value()

	// Determine payout amount
	var/payout_amount
	if(matured)
		payout_amount = face_value
		to_chat(user, span_notice("Redeeming matured bond at face value: [face_value] credits."))
	else
		payout_amount = current_value
		to_chat(user, span_notice("Redeeming bond early at current market value: [current_value] credits."))

	// Get Security account
	var/datum/bank_account/security_account = SSeconomy.get_dep_account(ACCOUNT_SEC)
	if(!security_account)
		balloon_alert(user, "no security budget account!")
		return

	// Security must have enough funds to buy back
	if(!security_account.has_money(payout_amount))
		balloon_alert(user, "security budget insufficient!")
		to_chat(user, span_warning("The Security budget only has [security_account.account_balance] credits, but the redemption value is [payout_amount]."))
		return

	// Transfer FROM Security TO owner (Security buys back bond)
	if(owner_account.transfer_money(security_account, payout_amount))
		// Log the transaction
		owner_account.add_log_to_history(payout_amount, "Wall Bond [bond_serial] Redemption")

		// Unregister before deletion
		unregister_from_owner_account()

		to_chat(user, span_notice("You redeem Wall Bond [bond_serial] for [payout_amount] credits!"))
		if(!matured && payout_amount < face_value)
			to_chat(user, span_warning("Note: You redeemed early. Holding until maturity would have yielded [face_value] credits."))
		else if(!matured && payout_amount > face_value)
			to_chat(user, span_notice("Great timing! You sold above face value due to favorable market conditions."))

		playsound(src, 'sound/machines/terminal/terminal_insert_disc.ogg', 50, TRUE)
		qdel(src)
	else
		balloon_alert(user, "redemption failed!")

// Alt-click to unlink ID (optional)
/obj/item/wall_bond/click_alt(mob/living/user)
	if(owner_account && linked_id && user.get_idcard() == linked_id)
		linked_id = null
		balloon_alert(user, "bond unlinked from ID")
		to_chat(user, span_notice("Wall Bond [bond_serial] is no longer linked to your ID. You will not receive automatic value updates."))
	else if(owner_account)
		balloon_alert(user, "not your bond!")
	else
		balloon_alert(user, "bond not purchased yet!")

// ============================================================
// WALL BOND PRINTER
// ============================================================

/obj/item/wall_bond_printer
	name = "\improper EPF Bond Issuer"
	desc = "A portable device that prints Wall Bonds. Click with a department budget card to set the charging account, then use in-hand to print a bond. \
		Wall Bonds can be linked to an ID card for value notifications. Bonds start unpurchased - investors must use their ID on the bond to buy it. \
		Bonds mature after 30-90 minutes, at which point they can be redeemed for face value. They pay 2% coupon interest each payday."
	icon = 'icons/obj/devices/scanner.dmi'
	icon_state = "inspector"
	worn_icon_state = "salestagger"
	inhand_icon_state = "electronic"
	lefthand_file = 'icons/mob/inhands/items/devices_lefthand.dmi'
	righthand_file = 'icons/mob/inhands/items/devices_righthand.dmi'
	throwforce = 0
	w_class = WEIGHT_CLASS_SMALL
	interaction_flags_click = NEED_DEXTERITY
	throw_range = 3
	throw_speed = 1
	sound_vary = TRUE
	pickup_sound = SFX_GENERIC_DEVICE_PICKUP
	drop_sound = SFX_GENERIC_DEVICE_DROP

	/// The budget account currently set to charge for prints (tracking only, no money taken at print time)
	var/datum/bank_account/charged_account = null
	/// The name of the department we're charging (for display)
	var/charged_department_name = null

/obj/item/wall_bond_printer/Initialize(mapload)
	. = ..()
	register_context()
	register_item_context()

/obj/item/wall_bond_printer/examine(mob/user)
	. = ..()
	. += span_info("Use in-hand to print a Wall Bond.")
	. += span_info("Click with a department budget card to set the issuing department.")
	. += span_info("Alt-click to clear the current issuing department.")
	. += span_info("Wall Bonds start unpurchased - investors must use their ID on the bond to buy it.")
	. += span_info("Bonds mature in 30-90 minutes and pay [WALL_BOND_COUPON_RATE * 100]% coupon interest each payday.")

	if(charged_account)
		. += span_notice("Issuing department: [charged_department_name || charged_account.account_holder]")
	else
		. += span_warning("No issuing department set. Click with a budget card to set one.")

/obj/item/wall_bond_printer/attackby(obj/item/I, mob/user, params)
	if(istype(I, /obj/item/card/id/departmental_budget))
		var/obj/item/card/id/departmental_budget/budget_card = I
		var/datum/bank_account/account = budget_card.registered_account

		if(!account)
			balloon_alert(user, "card has no account!")
			return

		// Only Security department can issue Wall Bonds
		var/dept_name = budget_card.department_name || budget_card.name
		if(dept_name != ACCOUNT_SEC_NAME && dept_name != "Security")
			balloon_alert(user, "only Security can issue Wall Bonds!")
			to_chat(user, span_warning("Wall Bonds can only be issued by the Security department."))
			return

		charged_account = account
		charged_department_name = dept_name

		balloon_alert(user, "issuing department set to [charged_department_name]")
		playsound(src, 'sound/machines/terminal/terminal_insert_disc.ogg', 50, FALSE)
		return

	return ..()

/obj/item/wall_bond_printer/click_alt(mob/user)
	if(!charged_account)
		balloon_alert(user, "no department set!")
		return

	charged_account = null
	charged_department_name = null
	balloon_alert(user, "issuing department cleared!")
	playsound(src, 'sound/machines/terminal/terminal_eject.ogg', 50, FALSE)

/obj/item/wall_bond_printer/attack_self(mob/user)
	. = ..()

	if(!charged_account)
		balloon_alert(user, "no issuing department set!")
		to_chat(user, span_warning("Click [src] with a department budget card to set the issuing department first."))
		return

	try_print_bond(user)

/obj/item/wall_bond_printer/proc/try_print_bond(mob/user)
	if(!charged_account)
		balloon_alert(user, "no issuing department!")
		return

	// Play printing animation/sound
	playsound(src, 'sound/machines/high_tech_confirm.ogg', 50, FALSE)
	balloon_alert(user, "printing bond...")

	// Small delay for effect
	if(do_after(user, 1 SECONDS, target = src, progress = TRUE))
		print_bond(user)

/obj/item/wall_bond_printer/proc/print_bond(mob/user)
	var/obj/item/wall_bond/new_bond = new(drop_location())
	new_bond.issuing_account = charged_account
	new_bond.issuing_department = charged_department_name
	new_bond.update_value()  // Sets initial value based on current conditions
	// owner_account starts as null - bond is unpurchased

	new_bond.add_fingerprint(user)
	playsound(src, 'sound/machines/printer.ogg', 50, FALSE)
	balloon_alert(user, "Wall Bond printed! Serial: [new_bond.bond_serial]")
	to_chat(user, span_notice("The bond starts unpurchased. An investor must use their ID on the bond to buy it at current market value."))
	to_chat(user, span_notice("The bond will mature in [rand(WALL_BOND_MATURITY_MIN / 600, WALL_BOND_MATURITY_MAX / 600)] minutes and pays [WALL_BOND_COUPON_RATE * 100]% coupon interest each payday."))

/obj/item/wall_bond_printer/add_item_context(obj/item/source, list/context, atom/target, mob/living/user)
	if(istype(target, /obj/item/card/id/departmental_budget))
		context[SCREENTIP_CONTEXT_LMB] = "Set issuing department"
		return CONTEXTUAL_SCREENTIP_SET
	return NONE

// Add to /datum/bank_account variable declarations
/datum/bank_account
	// ... existing vars ...

	/// List of wall bonds owned by this account
	var/list/obj/item/wall_bond/owned_wall_bonds

// Modify the existing payday proc (add bond processing)
/datum/bank_account/payday(amount_of_paychecks, free = FALSE, skippable = FALSE, event = "Payday")
	. = ..()  // Call parent first (handles the actual paycheck)
	if(!.)
		return

	process_wall_bond_coupons()

// Add this new proc to process bonds owned by this account
/datum/bank_account/proc/process_wall_bond_coupons()
	if(!LAZYLEN(owned_wall_bonds))
		return

	var/payday_id = world.time  // Unique identifier for this payday instance
	var/payouts_made = 0
	var/total_payout = 0

	for(var/obj/item/wall_bond/bond in owned_wall_bonds)
		if(!bond)
			LAZYREMOVE(owned_wall_bonds, bond)
			continue

		// Update bond value if needed (market fluctuations)
		if(bond.needs_update())
			bond.update_value()

		// Pay coupon interest
		if(bond.payday_coupon_payout(payday_id))
			payouts_made++
			total_payout += round(bond.current_value * WALL_BOND_COUPON_RATE)

	// Notify about bond payouts (optional - adds flavor)
	if(payouts_made > 0 && payouts_made == length(owned_wall_bonds))
		bank_card_talk("All [payouts_made] of your Wall Bonds paid out this payday, totaling [total_payout] credits.")
	else if(payouts_made > 0)
		bank_card_talk("[payouts_made] of your Wall Bonds paid out this payday, totaling [total_payout] credits.")

// Also add cleanup in Destroy() if needed
/datum/bank_account/Destroy()
	// Clear bond references
	if(LAZYLEN(owned_wall_bonds))
		for(var/obj/item/wall_bond/bond in owned_wall_bonds)
			if(bond)
				bond.owner_account = null  // Break reference
		owned_wall_bonds = null
	return ..()

#undef WALL_BOND_UPDATE_INTERVAL
#undef WALL_BOND_BASE_VALUE
#undef WALL_BOND_VALUE_PER_OFFICER
#undef WALL_BOND_MAX_OFFICER_BONUS
#undef WALL_BOND_ALERT_MULT_GREEN
#undef WALL_BOND_ALERT_MULT_BLUE
#undef WALL_BOND_ALERT_MULT_VIOLET
#undef WALL_BOND_ALERT_MULT_ORANGE
#undef WALL_BOND_ALERT_MULT_AMBER
#undef WALL_BOND_ALERT_MULT_RED
#undef WALL_BOND_ALERT_MULT_DELTA
#undef WALL_BOND_MIN_VALUE
#undef WALL_BOND_COUPON_RATE
#undef WALL_BOND_MATURITY_MIN
#undef WALL_BOND_MATURITY_MAX
#undef WALL_BOND_COUPON_PAYOUT_ANNOUNCE_THRESHOLD
