/obj/structure/closet/crate/secure/bitrunning/encrypted/wrench_act(mob/living/user, obj/item/tool)
	if(user?.mind?.has_antag_datum(/datum/antagonist/domain_ghost_actor, TRUE) || user?.mind?.has_antag_datum(/datum/antagonist/bitrunning_glitch, TRUE))
		balloon_alert(user, "read-only!")
		return ITEM_INTERACT_BLOCKING

/obj/structure/closet/crate/secure/bitrunning/encrypted/item_ctrl_click(mob/user)
	if(user?.mind?.has_antag_datum(/datum/antagonist/domain_ghost_actor, TRUE) || user?.mind?.has_antag_datum(/datum/antagonist/bitrunning_glitch, TRUE))
		balloon_alert(user, "read-only!")
		return NONE

/obj/structure/closet/crate/secure/bitrunning/encrypted/CanAllowThrough(atom/movable/mover, border_dir)
	if(ismob(mover))
		var/mob/pusher = mover
		if(pusher?.mind?.has_antag_datum(/datum/antagonist/domain_ghost_actor, TRUE) || pusher?.mind?.has_antag_datum(/datum/antagonist/bitrunning_glitch, TRUE))
			balloon_alert(pusher, "read-only!")
			return FALSE
	return ..()
