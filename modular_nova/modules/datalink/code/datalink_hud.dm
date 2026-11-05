// MODULE ID: DATALINK
// Client-side marker HUD (design doc §7, option B: screen-object markers).
// A small pooled set of screen objects lives on the holder's client and is
// refreshed at the network tick (4 Hz) plus on demand: nearest contacts,
// two-hop contacts, command markers, with out-of-view contacts pinned to the
// screen edge by offset_to_screen_loc() clamping. No lines are drawn.

/atom/movable/screen/datalink_marker
	name = "datalink contact"
	// Text-only marker: MUST null the inherited screen_gen icon, same pattern as
	// /atom/movable/screen/text and /atom/movable/screen/screentip. Leaving the
	// parent icon in place makes BYOND draw the icon's default state as a sprite
	// at every marker position — that was the HUD/screen artifacting.
	icon = null
	icon_state = null
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	invisibility = INVISIBILITY_ABSTRACT

/// Per-node marker controller; created by the node, refreshed by SSdatalink.
/datum/datalink_hud
	/// The node we render for
	var/datum/datalink_node/node
	/// Owns the screen objects on the client (handles client loss for us)
	var/datum/screen_object_holder/screen_holder
	/// Client we last attached screen objects to
	var/client/synced_client
	/// Marker pool, index-matched during each paint
	var/list/atom/movable/screen/datalink_marker/markers = list()
	/// Set when contacts/commands change (movement is detected live in refresh)
	var/dirty = TRUE

/datum/datalink_hud/New(datum/datalink_node/owner)
	node = owner

/datum/datalink_hud/Destroy()
	markers.Cut()
	QDEL_NULL(screen_holder)
	node = null
	return ..()

/datum/datalink_hud/proc/mark_dirty()
	dirty = TRUE

/// Hide every marker without destroying the pool (e.g. node went SILENT).
/datum/datalink_hud/proc/clear()
	for(var/atom/movable/screen/datalink_marker/marker as anything in markers)
		marker.invisibility = INVISIBILITY_ABSTRACT
	dirty = TRUE

/// Make sure our screen objects are on the current client of our holder.
/datum/datalink_hud/proc/sync_client()
	var/client/active = node?.get_user()?.client
	if(!active)
		if(screen_holder)
			QDEL_NULL(screen_holder)
			markers.Cut()
		synced_client = null
		return FALSE
	if(synced_client != active)
		QDEL_NULL(screen_holder)
		markers.Cut()
		screen_holder = new(active)
		synced_client = active
		dirty = TRUE
		return TRUE
	if(!screen_holder)
		screen_holder = new(active)
		return TRUE
	return TRUE

/// Fetch (or grow) the marker pool to at least `index` entries.
/datum/datalink_hud/proc/get_marker(index)
	while(length(markers) < index)
		var/atom/movable/screen/datalink_marker/marker = new
		marker.maptext_width = 128
		marker.maptext_height = 24
		marker.maptext_y = -8
		marker.maptext_x = -4
		screen_holder.give_screen_object(marker)
		markers += marker
	return markers[index]

/// Repaint every marker. Called each network tick for registered nodes.
/datum/datalink_hud/proc/refresh()
	// Unregistered or disabled (SILENT) nodes paint nothing on the HUD.
	if(!node?.registered || node.state != DATALINK_STATE_ACTIVE)
		clear()
		return
	if(!sync_client())
		return
	var/mob/living/user = node.get_user()
	var/client/active = user?.client
	if(!active)
		return
	var/turf/eye_turf = get_turf(active.eye)
	if(!eye_turf)
		return
	var/list/pixel_size = view_to_pixels(active.view)
	var/center_x = pixel_size[1] * 0.5
	var/center_y = pixel_size[2] * 0.5
	// Gather render entries: command markers first (they matter most), then
	// the nearest contacts. Each entry = list(x, y, label, glyph, color).
	var/list/entries = list()
	for(var/key in node.active_commands)
		if(length(entries) >= DATALINK_MAX_COMMAND_MARKERS)
			break
		var/datum/datalink_command/command = node.active_commands[key]
		if(command.target_z != eye_turf.z)
			continue
		entries += list(list(command.target_x, command.target_y, "[command.origin_callsign]: [command.get_marker_label()]", "▲", COLOR_RED))
	var/contact_markers = 0
	for(var/datum/datalink_contact/contact as anything in node.get_contacts())
		if(contact_markers >= DATALINK_MAX_CONTACT_MARKERS)
			break
		if(contact.z != eye_turf.z)
			continue
		// Never draw a marker on your own tile (the mech you're seated in,
		// your own suit node mirrored through the mech's contact table, an
		// ally standing on you). This stops the suit/mech pair from drawing
		// two overlapping markers at screen center while piloting.
		if(contact.x == eye_turf.x && contact.y == eye_turf.y)
			continue
		contact_markers++
		var/two_hop = contact.hops > 1
		var/label = "[contact.callsign] [round(contact.dist)]m[two_hop ? " (2-hop)" : ""]"
		entries += list(list(contact.x, contact.y, label, two_hop ? "◆" : "●", two_hop ? COLOR_CYAN : COLOR_GREEN))
	// Paint
	var/index = 1
	for(var/list/entry as anything in entries)
		var/atom/movable/screen/datalink_marker/marker = get_marker(index++)
		marker.invisibility = 0
		var/new_text = MAPTEXT("<b>[entry[4]]</b> [entry[3]]")
		if(marker.maptext != new_text)
			marker.maptext = new_text
		var/off_x = center_x + (entry[1] - eye_turf.x) * ICON_SIZE_X + (ICON_SIZE_X * 0.5)
		var/off_y = center_y + (entry[2] - eye_turf.y) * ICON_SIZE_Y + (ICON_SIZE_Y * 0.5)
		// Clamp inside the visible tile grid (tile 1..N, matching
		// offset_to_screen_loc's own clamping convention): in-view contacts land
		// exactly on their tile, out-of-view contacts pin to the screen edge
		// (design doc §7). Never emit tile 0/negative screen_locs.
		off_x = clamp(off_x, min(ICON_SIZE_X, pixel_size[1]), pixel_size[1])
		off_y = clamp(off_y, min(ICON_SIZE_Y, pixel_size[2]), pixel_size[2])
		var/new_loc = offset_to_screen_loc(off_x, off_y)
		if(marker.screen_loc != new_loc)
			marker.screen_loc = new_loc
	for(var/rest_index in index to length(markers))
		markers[rest_index].invisibility = INVISIBILITY_ABSTRACT
	dirty = FALSE
