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
	bolt_wording = "lock"
	cartridge_wording = "fuse"
	item_flags = null
	bolt_type = BOLT_TYPE_LOCKING
	click_on_low_ammo = FALSE
	tac_reloads = FALSE

/obj/item/gun/ballistic/cartridge_taser/update_overlays()
	. = ..()
	if(chambered)
		var/icon_state = icon_exists(/obj/item/gun/ballistic/cartridge_taser::icon, chambered.base_icon_state) ? chambered.base_icon_state : "fuse"
		if(bolt_locked)
			icon_state += "_locked"
		. += icon(/obj/item/gun/ballistic/cartridge_taser::icon, icon_state)

/obj/item/gun/ballistic/cartridge_taser/try_fire_gun(atom/target, mob/living/user, params)
	. = ..()
	if(!bolt_locked)
		to_chat(user, span_warning("Without locking the fuse in place, the gun emits a shower of sparks."))
		do_sparks(2, TRUE, src)
		return FALSE

/obj/item/gun/ballistic/cartridge_taser/handle_chamber(empty_chamber = TRUE, from_firing = TRUE, chamber_next_round = FALSE)
	. = ..()
	bolt_locked = FALSE

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
