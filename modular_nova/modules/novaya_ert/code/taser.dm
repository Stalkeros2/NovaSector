/// The caliber used by the cartridge taser.
#define CALIBER_FUSE "fuse"

/obj/item/gun/ballistic/cartridge_taser
	name = "cartridge taser"
	desc = "Seems out-of-place in this day and age, but at least it's reliable."
	icon_state = "taser"
	inhand_icon_state = "taser"
	base_icon_state = "taser"
	icon = 'modular_nova/modules/novaya_ert/icons/taser.dmi'
	lefthand_file = 'icons/mob/inhands/weapons/bows_lefthand.dmi'
	righthand_file = 'icons/mob/inhands/weapons/bows_righthand.dmi'
	load_sound = 'modular_nova/modules/novaya_ert/sound/taser_insert.ogg'
	fire_sound = 'modular_nova/modules/novaya_ert/sound/taser_fire.ogg'
	dry_fire_sound = 'modular_nova/modules/novaya_ert/sound/taser_dry_fire.ogg'
	rack_sound = 'modular_nova/modules/novaya_ert/sound/taser_rack.ogg'
	eject_sound = 'modular_nova/modules/novaya_ert/sound/taser_eject.ogg'
	accepted_magazine_type = /obj/item/ammo_box/magazine/internal/cartridge_taser
	force = 15
	attack_verb_continuous = list("bashed", "pistol-whipped")
	attack_verb_simple = list("bash", "pistol-whip")
	weapon_weight = WEAPON_LIGHT
	w_class = WEIGHT_CLASS_NORMAL
	internal_magazine = TRUE
	cartridge_wording = "fuse"
	item_flags = null
	bolt_type = BOLT_TYPE_NO_BOLT
	click_on_low_ammo = FALSE
	must_hold_to_load = FALSE
	/// whether the taser is cocked
	var/cocked = FALSE

/obj/item/gun/ballistic/cartridge_taser/update_icon_state()
	. = ..()
	icon_state = "[base_icon_state][cocked ? "_cocked" : ""]"

/obj/item/gun/ballistic/cartridge_taser/update_overlays()
	. = ..()
	if(chambered)
		var/icon_state = icon_exists(/obj/item/gun/ballistic/cartridge_taser::icon, chambered.base_icon_state) ? chambered.base_icon_state : "fuse"
		if(cocked)
			icon_state += "_cocked"
		. += icon(/obj/item/gun/ballistic/cartridge_taser::icon, icon_state)

/obj/item/gun/ballistic/cartridge_taser/click_alt(mob/user)
	if(isnull(chambered) || cocked)
		return CLICK_ACTION_BLOCKING

	user.put_in_hands(chambered)
	chambered = magazine.get_round()
	update_appearance()
	return CLICK_ACTION_SUCCESS

/obj/item/gun/ballistic/attackby(obj/item/A, mob/user, params)
	if(istype(A, /obj/item/ammo_casing/fuse))
		var/obj/item/ammo_casing/fuse/pseudofuse = A
		if(pseudofuse.projectile_type == null)
			balloon_alert(user, "fuse burnt!")
			return FALSE
	. = ..()

/obj/item/gun/ballistic/cartridge_taser/chamber_round(spin_cylinder, replace_new_round)
	if(chambered || cocked)
		return
	chambered = magazine.get_round()
	RegisterSignal(chambered, COMSIG_MOVABLE_MOVED, PROC_REF(clear_chambered))
	update_appearance()

/obj/item/gun/ballistic/cartridge_taser/handle_chamber(empty_chamber = TRUE, from_firing = TRUE, chamber_next_round = FALSE)
	. = ..()
	cocked = FALSE

/obj/item/gun/ballistic/cartridge_taser/attack_self(mob/user)
	if(!chambered)
		balloon_alert(user, "no fuse inserted!")
		return
	balloon_alert(user, "[cocked ? "lock released" : "lock engaged"]")
	playsound(src, cocked ? eject_sound : rack_sound, 25, TRUE)
	cocked = !cocked
	update_appearance()

/obj/item/gun/ballistic/cartridge_taser/try_fire_gun(atom/target, mob/living/user, params)
	if(!chambered)
		return FALSE
	if(!cocked)
		to_chat(user, span_warning("Without locking the fuse in place, the gun emits a shower of sparks."))
		do_sparks(2, TRUE, src)
		return FALSE
	return ..() //fires, removing the fuse

/obj/item/ammo_box/magazine/internal/cartridge_taser
	name = "upper fusewell" //Like a magwell but for fuses you know.
	ammo_type = /obj/item/ammo_casing/fuse
	max_ammo = 1
	start_empty = TRUE
	caliber = CALIBER_FUSE

/obj/item/ammo_casing/fuse
	name = "high-performance fuse"
	desc = "A proprietary, single use fuse rated for short-term, high-amount voltages; typically used in cartridge tasers."
	icon = 'modular_nova/modules/novaya_ert/icons/taser.dmi'
	icon_state = "fuse_ammo"
	caliber = CALIBER_FUSE
	harmful = FALSE
	projectile_type = /obj/projectile/energy/electrode/fuse
	newtonian_force = 0.5

/obj/item/ammo_casing/fuse/Initialize(mapload)
	. = ..()

/obj/projectile/energy/electrode/fuse
	stamina = 60
	range = 5
	paralyze = null
	eyeblur = 10 SECONDS
	stutter = 5 SECONDS
	jitter = 20 SECONDS

#undef CALIBER_FUSE
