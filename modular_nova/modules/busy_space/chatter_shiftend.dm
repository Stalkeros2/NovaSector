/datum/atc_chatter/shift_end/squak()
	switch(phase)
		if(1)
			SSatc.msg("[GLOB.station_name], this is Traffic Control, you are cleared to complete routine transfer from [GLOB.station_name] to Interlink.")
			next()
		else
			SSatc.msg("[GLOB.station_name] departing for Interlink on routine transfer route. Estimated time to arrival: ten minutes.")
			finish()
