///Credit costs for different ticket types
#define CREDITS_TO_PRINT_STANDARD (100)
#define CREDITS_TO_PRINT_LUXURY (250)

/obj/item/ration_printer
	name = "\improper R-ATIO Automated Ration Dispenser"
	desc = "A portable device that prints ration tickets in exchange for departmental funds. \
	Click with a budget card to set the charging account, then use in-hand to select and print a ticket."
	icon = 'icons/obj/devices/scanner.dmi'
	icon_state = "inspector" // You may want a unique icon
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

	///The budget account currently set to charge for prints
	var/datum/bank_account/charged_account = null
	///The name of the department we're charging (for display)
	var/charged_department_name = null

	/// Static radial menu options
	var/static/list/radial_ticket_options = list(
		"Standard Ration (100)" = image(icon = 'modular_nova/modules/paycheck_rations/icons/tickets.dmi', icon_state = "ticket_food"),
		"Luxury Ration (250)" = image(icon = 'modular_nova/modules/paycheck_rations/icons/tickets.dmi', icon_state = "ticket_luxury"),
	)

/obj/item/ration_printer/Initialize(mapload)
	. = ..()
	register_context()
	register_item_context()

/obj/item/ration_printer/examine(mob/user)
	. = ..()
	. += span_info("Use in-hand to select and print a ration ticket.")
	. += span_info("Click with a department budget card to set the charging account.")
	. += span_info("Alt-click to clear the current charging account.")

	if(charged_account)
		. += span_notice("Currently charging to: [charged_department_name || charged_account.account_holder]")
		. += span_notice("Account balance: [charged_account.account_balance] credits.")
	else
		. += span_warning("No charging account set. Click with a budget card to set one.")

/obj/item/ration_printer/attackby(obj/item/I, mob/user, list/modifiers, list/attack_modifiers)
	if(istype(I, /obj/item/card))
		if(!istype(I, /obj/item/card/id/departmental_budget))
			balloon_alert(user, "department budget only!")
			return
		else
			var/obj/item/card/id/departmental_budget/budget_card = I
			var/datum/bank_account/account = budget_card.registered_account

			if(!account)
				balloon_alert(user, "card has no account!")
				return

			// Store the account and department name for display
			charged_account = account
			charged_department_name = budget_card.department_name || budget_card.name

			balloon_alert(user, "charging to [charged_department_name]")
			playsound(src, 'sound/machines/terminal/terminal_insert_disc.ogg', 50, FALSE)
			return

	return ..()

/obj/item/ration_printer/click_alt(mob/user)
	if(!charged_account)
		balloon_alert(user, "no account set!")
		return

	charged_account = null
	charged_department_name = null
	balloon_alert(user, "account cleared!")
	playsound(src, 'sound/machines/terminal/terminal_eject.ogg', 50, FALSE)

/obj/item/ration_printer/attack_self(mob/user)
	. = ..()

	if(!charged_account)
		balloon_alert(user, "no account set!")
		to_chat(user, span_warning("Click [src] with a department budget card to set the charging account first."))
		return

	open_ticket_menu(user)

/obj/item/ration_printer/proc/open_ticket_menu(mob/user)
	var/choice = show_radial_menu(user, src, radial_ticket_options, require_near = TRUE, tooltips = TRUE)

	if(!choice)
		return

	switch(choice)
		if("Standard Ration (100)")
			try_print_ticket(user, "standard", CREDITS_TO_PRINT_STANDARD)
		if("Luxury Ration (250)")
			try_print_ticket(user, "luxury", CREDITS_TO_PRINT_LUXURY)

/obj/item/ration_printer/proc/try_print_ticket(mob/user, ticket_type, cost)
	if(!charged_account)
		balloon_alert(user, "no linked account!")
		return

	if(!charged_account.has_money(cost))
		balloon_alert(user, "insufficient funds!")
		to_chat(user, span_warning("[charged_department_name] account only has [charged_account.account_balance] credits, need [cost]."))
		playsound(src, 'sound/machines/uplink/uplinkerror.ogg', 40)
		return

	// Play printing animation/sound
	playsound(src, 'sound/machines/high_tech_confirm.ogg', 50, FALSE)
	balloon_alert(user, "printing ticket...")

	// Small delay for effect
	if(do_after(user, 0.5 SECONDS, target = src, progress = TRUE))
		print_ticket(user, ticket_type, cost)

/obj/item/ration_printer/proc/print_ticket(mob/user, ticket_type, cost)
	var/obj/item/paper/paperslip/ration_ticket/new_ticket

	switch(ticket_type)
		if("standard")
			new_ticket = new /obj/item/paper/paperslip/ration_ticket(drop_location())
		if("luxury")
			new_ticket = new /obj/item/paper/paperslip/ration_ticket/luxury(drop_location())

	// Charge the account
	if(!charged_account.adjust_money(-cost, "Ration Printer: [capitalize(ticket_type)] Ration Ticket"))
		balloon_alert(user, "transaction failed!")
		return

	new_ticket.add_fingerprint(user)
	playsound(src, 'sound/machines/printer.ogg', 50, FALSE)
	balloon_alert(user, "[capitalize(ticket_type)] ticket printed!")

/obj/item/ration_printer/add_item_context(obj/item/source, list/context, atom/target, mob/living/user)
	if(istype(target, /obj/item/card/id/departmental_budget))
		context[SCREENTIP_CONTEXT_LMB] = "Set charging account"
		return CONTEXTUAL_SCREENTIP_SET
	return NONE

#undef CREDITS_TO_PRINT_STANDARD
#undef CREDITS_TO_PRINT_LUXURY
