/// Revenant ability: Shapeshift into a character from your preferences
/datum/action/cooldown/spell/shapeshift/revenant
	name = "Spectral Mimicry"
	desc = "Assume the form of a spectral avatar from your memories. While in this form, damage is converted to essence loss."
	panel = "Revenant Abilities"
	background_icon_state = "bg_revenant"
	overlay_icon_state = "bg_revenant_border"
	button_icon = 'icons/mob/actions/actions_revenant.dmi'
	button_icon_state = "shapeshift"

	school = SCHOOL_TRANSMUTATION
	cooldown_time = 30 SECONDS

	antimagic_flags = MAGIC_RESISTANCE_HOLY
	spell_requirements = NONE
	die_with_shapeshifted_form = FALSE
	revert_on_death = TRUE
	convert_damage = TRUE
	convert_damage_type = TOX

	/// How much essence it costs to use
	var/cast_amount = 40
	/// Reference to the revenant's preferences
	var/datum/preferences/revenant_prefs

/datum/action/cooldown/spell/shapeshift/revenant/New(Target)
	. = ..()
	name = "[initial(name)] ([cast_amount]E)"

/datum/action/cooldown/spell/shapeshift/revenant/Destroy()
	revenant_prefs = null
	return ..()

/datum/action/cooldown/spell/shapeshift/revenant/can_cast_spell(feedback = TRUE)
	. = ..()
	if(!.)
		return FALSE

	if(!isrevenant(owner))
		return FALSE

	var/mob/living/basic/revenant/ghost = owner
	if(ghost.dormant || HAS_TRAIT(ghost, TRAIT_REVENANT_INHIBITED))
		return FALSE

	if(ghost.essence <= cast_amount)
		return FALSE

	return TRUE

/datum/action/cooldown/spell/shapeshift/revenant/before_cast(mob/living/cast_on)
	. = ..()
	if(. & SPELL_CANCEL_CAST)
		return

	if(!isrevenant(cast_on))
		return . | SPELL_CANCEL_CAST

	var/mob/living/basic/revenant/ghost = cast_on
	if(!ghost.cast_check(-cast_amount))
		reset_spell_cooldown()
		return . | SPELL_CANCEL_CAST

	// Store preferences if available
	if(ghost.client?.prefs)
		revenant_prefs = ghost.client.prefs
	else
		to_chat(ghost, span_revenwarning("You have no memories to draw upon!"))
		return . | SPELL_CANCEL_CAST

/datum/action/cooldown/spell/shapeshift/revenant/cast(mob/living/cast_on)
	. = ..()

	var/mob/living/basic/revenant/ghost = cast_on

	// Consume essence
	ghost.change_essence_amount(-cast_amount, FALSE, "Spectral Mimicry")

	to_chat(ghost, span_revennotice("You assume a spectral form from your memories."))

/datum/action/cooldown/spell/shapeshift/revenant/create_shapeshift_mob(atom/loc)
	// Make sure our internal revenant can't move
	var/mob/living/basic/revenant/ghost = owner
	ghost.apply_status_effect(/datum/status_effect/incapacitating/paralyzed/revenant)

	// Create a human mob
	var/mob/living/carbon/human/avatar = new(loc)

	// Apply revenant's preferences
	if(revenant_prefs)
		revenant_prefs.safe_transfer_prefs_to(avatar)
	else
		// Fallback basic appearance
		avatar.hairstyle = "Bald"
		avatar.facial_hairstyle = "Shaved"
		avatar.skin_tone = "caucasian1"

	// Give basic equipment
	avatar.equipOutfit(/datum/outfit/job/assistant)

	// Apply revenant-specific visuals
	avatar.alpha = 220
	avatar.add_atom_colour("#8F48C6", TEMPORARY_COLOUR_PRIORITY)
	avatar.set_light(2, 1, "#8F48C6")
	ADD_TRAIT(avatar, TRAIT_REVENANT_AVATAR, "revenant_shapeshift")

	return avatar

/datum/action/cooldown/spell/shapeshift/revenant/do_unshapeshift(mob/living/caster, mob/living/old_shape)
	. = ..()
	var/mob/living/basic/revenant/ghost = caster
	ghost.remove_status_effect(/datum/status_effect/incapacitating/paralyzed/revenant)

	// Add any revenant-specific post-unshape logic here
	to_chat(caster, span_revennotice("You revert to your spectral form."))
	return

/mob/living/basic/revenant/Initialize(mapload)
	. = ..()
	grant_actions_by_list(list(/datum/action/cooldown/spell/shapeshift/revenant))
