/datum/language/spinwarder
	name = "Pan-Slavic"
	desc = "The primary language of the Commonwealth of Zvirndyn Dominions and the de facto administrative tongue of the Heliostatic Coalition, \
	Pan-Slavic evolved organically from the Eastern and Central European linguistic roots of the founding colonists who settled Vistula and its \
	surrounding systems during the First Great Interstellar Migration. Isolated from Sol for centuries during the 'Quiet Century,' the scattered \
	colonies saw their inherited languages, -primarily drawn from Slavic, Baltic, and Central Asian linguistic families-, drift, merge, and \
	simplify under the pressures of survival and limited communication between settlements. When the colonies re-established contact in the \
	late 2390s and formalized the Heliostatic Compact in 2405, the Vistulan dialect emerged as the natural standard. Its speakers had \
	maintained the most robust educational and administrative institutions during the isolation, and their variant became the language of \
	Coalition governance by default. The Commonwealth's Charter of 2377 had already codified Pan-Slavic as the official language of the CZD, \
	and the Coalition followed suit, adopting it as the language of the Chamber of Legislation, the Unified High Command, the Expeditionary \
	Police Force, and other relevant institutional bodies. Linguistically, Pan-Slavic retains the Slavic verbal aspect system (perfective vs. \
	imperfective) and much of its foundational vocabulary: body parts, family, nature, and basic actions. However, centuries of separation \
	and the mixing of settlers from different regional backgrounds simplified its noun morphology dramatically, reducing the complex Slavic \
	case system to a two-case distinction (Nominative and Oblique). Its default word order shifted from SVO to SOV under influence from the \
	Central Asian linguistic heritage present among the colonists, and fixed final-syllable stress replaced the mobile stress patterns of \
	older Slavic languages. Today, Pan-Slavic is spoken natively by the human majority of the CZD and as a second language by most other \
	Coalition citizens. Its written form uses a 30-letter phonetic Latin alphabet, standardized in the 24th century for compatibility with \
	Coalition military and civilian systems. The 'Vistula Standard' dialect of Pan-Slavic is the prestige dialect of Coalition administration, \
	taught in schools across the Coalition and used in all official documents. While Sol Common remains the language of interstellar communication, \
	Pan-Slavic is the language of home, of the Chamber, and of the Long Arm. To an outsider, it sounds simultaneously familiar and alien - \
	recognizably Slavic in its rhythm and consonant clusters, but spoken with a steady final-syllable stress that flattens the melodic rise \
	and fall of its ancestral tongues, and punctuated by loanwords from the Turkic and Persian linguistic strata that survived the Quiet Century."
	key = "P"
	flags = TONGUELESS_SPEECH
	space_chance = 35
	sentence_chance = 5
	between_word_sentence_chance = 10
	between_word_space_chance = 60
	additional_syllable_low = 0
	additional_syllable_high = 2
	syllables = list(
		// Slavic stratum (core grammar, basic vocab)
		"brat", "žen", "vod", "dom", "zvezd", "nog", "ruk", "syn", "mat", "otc", "serd", "neb", "ogn", "zem", "živ", "spa", "jed", "pij", "govor", "pis", "del", "vid", "slov", "hleb", "trud", "put", "dobr", "zly", "velik", "mal", "stary", "nov", "čorn", "zelen", "běl", "červen",
		// Consonant clusters (common in Slavic)
		"zd", "st", "sk", "zn", "zv", "tv", "dv", "kr", "tr", "pl", "bl", "gl", "chl", "kak", "tak", "čto", "kto", "gd", "vš", "čl", "čn", "str", "spr", "vz", "dr", "dl",
		// Vowel-harmonized grammatical particles (Central Asian influence)
		"da", "dä", "em", "bul", "mož", "ne", "je", "si", "či", "li", "že", "bo", "no", "aj", "ej", "uj", "ij", "yj", "in", "š", "aš",
		// Cultural/administrative stratum leaking from Vistulan
		"šäh", "nan", "pul", "dost", "čaj", "hükü", "met", "baš", "lyk", "hay", "qay", "ğu", "süy", "sanak", "učqu", "aläm", "bazar", "til", "jay", "hatun", "düšman", "rahmat", "salam", "kečir", "diqqat", "nešč", "ölke", "kilem", "čapan", "fan",
		// Common phrases and grammaticalized forms
		"prosim", "hair", "s-pis", "s-del", "poš", "zaš", "naš", "vaš", "moj", "tvoj", "onin", "onäin", "oniv",
	)
	icon_state = "panslavic"
	icon = 'modular_nova/master_files/icons/misc/language.dmi'
	default_priority = 95
	mutual_understanding = list(
		/datum/language/common = 25,
		/datum/language/spacer = 30,
		/datum/language/xerxian = 15,
	)
