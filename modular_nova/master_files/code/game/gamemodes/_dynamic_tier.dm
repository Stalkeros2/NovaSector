/datum/dynamic_tier/New(list/dynamic_config)
	. = ..()
	advisory_report = replacetext(advisory_report, "Spinward", "Nova")
