// MODULE ID: DATALINK
// Cached, budgeted line-of-sight for datalink transmissions (design doc §6).
// Hard-block policy: any opaque turf between the two endpoints stops the
// signal. Vacuum is a legit flanking route; interior walls are a comms problem.

/**
 * Checks whether a datalink transmission can pass between two turfs.
 *
 * Returns TRUE (visible), FALSE (blocked), or DATALINK_LOS_DEFERRED when the
 * per-tick budget is exhausted and `force` is not set. Callers should treat
 * DEFERRED as "try again next tick" for commands, or drop for beacons (they
 * recur every second anyway).
 *
 * Arguments:
 * * source, target — endpoints of the transmission.
 * * force — bypass the budget (used when draining deferred command packets).
 */
/proc/datalink_can_see(turf/source, turf/target, force = FALSE)
	if(!source || !target)
		return FALSE
	if(source.z != target.z)
		return FALSE
	if(source == target)
		return TRUE
	var/key = "[source.x],[source.y]|[target.x],[target.y]"
	var/reverse = "[target.x],[target.y]|[source.x],[source.y]"
	var/list/cached = SSdatalink.los_cache[key] || SSdatalink.los_cache[reverse]
	if(cached && cached[1] > world.time)
		SSdatalink.metric_los_hits++
		return cached[2]
	if(!force)
		if(SSdatalink.los_budget <= 0)
			return DATALINK_LOS_DEFERRED
		SSdatalink.los_budget--
	SSdatalink.metric_los_checks++
	var/blocked = datalink_line_blocked(source, target)
	if(length(SSdatalink.los_cache) >= DATALINK_LOS_CACHE_SIZE)
		SSdatalink.los_cache.Cut()
	// Return *visibility* (the inverse of blocked) so this matches the
	// documented contract — callers treat TRUE as "signal passes".
	SSdatalink.los_cache[key] = list(world.time + DATALINK_LOS_CACHE_TIME, !blocked)
	return !blocked


/// TRUE when an opaque turf sits between source and target (endpoints excluded).
/proc/datalink_line_blocked(turf/source, turf/target)
	for(var/turf/obstacle as anything in get_line(source, target))
		if(obstacle == source || obstacle == target)
			continue
		if(obstacle.opacity)
			return TRUE
	return FALSE
