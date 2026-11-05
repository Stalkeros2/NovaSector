// MODULE ID: DATALINK
// Command packets are plain assoc lists while in flight; a node that accepts a
// command wraps it in this datum so the HUD and console can render it until it
// expires (design doc §5.3).

/datum/datalink_command
	/// node_id of the originating node
	var/origin_id
	/// Callsign of the originating node at issue time
	var/origin_callsign
	/// Sequence number on the origin node, for dedupe
	var/seq
	/// One of the DATALINK_CMD_* defines
	var/cmd_type
	/// Target position the command points at, if any
	var/target_x
	var/target_y
	var/target_z
	/// Free text for DATALINK_CMD_CUSTOM
	var/payload
	/// DATALINK_PRIORITY_*
	var/priority = DATALINK_PRIORITY_NORMAL
	/// world.time the command was issued
	var/issued_at
	/// world.time the command stops being displayed
	var/expires_at

/datum/datalink_command/New(list/packet)
	origin_id = packet["origin"]
	origin_callsign = packet["call"]
	seq = packet["seq"]
	cmd_type = packet["cmd"]
	target_x = packet["tx"]
	target_y = packet["ty"]
	target_z = packet["tz"]
	payload = packet["payload"]
	priority = packet["priority"] || DATALINK_PRIORITY_NORMAL
	issued_at = packet["time"]
	expires_at = issued_at + DATALINK_COMMAND_EXPIRY

/// Short human-readable line for chat and the console.
/datum/datalink_command/proc/get_text()
	switch(cmd_type)
		if(DATALINK_CMD_MOVE_TO)
			return "MOVE TO ([target_x], [target_y])"
		if(DATALINK_CMD_FOCUS)
			return "FOCUS marked position ([target_x], [target_y])"
		if(DATALINK_CMD_HOLD)
			return "HOLD position"
		if(DATALINK_CMD_REGROUP)
			return "REGROUP at ([target_x], [target_y])"
		if(DATALINK_CMD_PING)
			return "PING — position marked ([target_x], [target_y])"
		if(DATALINK_CMD_CUSTOM)
			return payload || "CUSTOM"
	return "UNKNOWN COMMAND"

/// Very short label for HUD markers.
/datum/datalink_command/proc/get_marker_label()
	switch(cmd_type)
		if(DATALINK_CMD_MOVE_TO)
			return "MOVE"
		if(DATALINK_CMD_FOCUS)
			return "FOCUS"
		if(DATALINK_CMD_HOLD)
			return "HOLD"
		if(DATALINK_CMD_REGROUP)
			return "REGROUP"
		if(DATALINK_CMD_PING)
			return "PING"
		if(DATALINK_CMD_CUSTOM)
			return copytext(payload || "MSG", 1, 12)
	return "CMD"
