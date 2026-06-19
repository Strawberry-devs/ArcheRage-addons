
local locale = timeUntilLocale or "en_us"

naServerEvents = {
	[eventsName[locale].GR] = {
		{
			times = {
				{ hour = 2, minute = 20, duration = 20 },
				{ hour = 6, minute = 20, duration = 20 },
				{ hour = 10, minute = 20, duration = 20 },
				{ hour = 14, minute = 20, duration = 20 },
				{ hour = 18, minute = 20, duration = 20 },
				{ hour = 22, minute = 20, duration = 20 },
			},
			days = { 1, 2, 3, 4, 5, 6, 7 },
		},
	},
	[eventsName[locale].CR] = {
		{
			times = {
				{ hour = 0, minute = 20, duration = 10 },
				{ hour = 4, minute = 20, duration = 10 },
				{ hour = 8, minute = 20, duration = 10 },
				{ hour = 12, minute = 20, duration = 10 },
				{ hour = 16, minute = 20, duration = 10 },
				{ hour = 20, minute = 20, duration = 10 },
			},
			days = { 1, 2, 3, 4, 5, 6, 7 },
		},
	},
	[eventsName[locale].Hiram] = {
		{
			times = {
				{ hour = 1, minute = 50, duration = 40 },
				{ hour = 5, minute = 50, duration = 40 },
				{ hour = 9, minute = 50, duration = 40 },
				{ hour = 13, minute = 50, duration = 40 },
				{ hour = 17, minute = 50, duration = 40 },
				{ hour = 21, minute = 50, duration = 40 },
			},
			days = { 1, 2, 3, 4, 5, 6, 7 },
		},
	},
	[eventsName[locale].SG_CR] = {
		{
			times = {
				{ hour = 1, minute = 20, duration = 10 },
				{ hour = 5, minute = 20, duration = 10 },
				{ hour = 9, minute = 20, duration = 10 },
				{ hour = 13, minute = 20, duration = 10 },
				{ hour = 17, minute = 20, duration = 10 },
				{ hour = 21, minute = 20, duration = 10 },
			},
			days = { 1, 2, 3, 4, 5, 6, 7 },
		},
	},
	[eventsName[locale].JMG] = {
		{
			times = {
				{ hour = 3, minute = 20, duration = 15 },
				{ hour = 7, minute = 20, duration = 15 },
				{ hour = 11, minute = 20, duration = 15 },
				{ hour = 15, minute = 20, duration = 15 },
				{ hour = 19, minute = 20, duration = 15 },
				{ hour = 23, minute = 20, duration = 15 },
			},
			days = { 1, 2, 3, 4, 5, 6, 7 },
		},
	},
	[eventsName[locale].Lusca] = {
		{ times = { { hour = 16, minute = 30, duration = 60 }, { hour = 21, minute = 0, duration = 60 } }, days = { 1, 2, 3, 4, 5, 6, 7 } },
	},
	[eventsName[locale].BD] = {
		{ times = { { hour = 9, minute = 0, duration = 60 } }, days = { 1 } },
		{ times = { { hour = 20, minute = 0, duration = 60 } }, days = { 3 } },
		{ times = { { hour = 17, minute = 0, duration = 60 } }, days = { 7 } },
	},
	[eventsName[locale].Kraken] = {
		{ times = { { hour = 10, minute = 30, duration = 60 } }, days = { 1 } },
		{ times = { { hour = 18, minute = 30, duration = 60 } }, days = { 3, 7 } },
	},
	[eventsName[locale].Leviathan] = {
		{ times = { { hour = 20, minute = 5, duration = 120 } }, days = { 2, 4, 6 } },
	},
	[eventsName[locale].Charybdis] = {
		{ times = { { hour = 21, minute = 30, duration = 60 } }, days = { 1, 5 } },
	},
	[eventsName[locale].Anthalon_G] = {
		{ times = { { hour = 13, minute = 0, duration = 60 } }, days = { 1 } },
		{ times = { { hour = 21, minute = 0, duration = 60 } }, days = { 4, 7 } },
	},
	[eventsName[locale].Halcy] = {
		{ times = { { hour = 8, minute = 0, duration = 30 } }, days = { 1, 2, 3, 4, 5, 6, 7 } },
		{ times = { { hour = 12, minute = 30, duration = 60 }, { hour = 22, minute = 30, duration = 60 } }, days = { 1, 7 } },
		{ times = { { hour = 14, minute = 0, duration = 60 }, { hour = 22, minute = 0, duration = 60 } }, days = { 2, 3, 4, 5, 6 } },
	},
	[eventsName[locale].RD] = {
		{ times = { { hour = 7, minute = 30, duration = 60 }, { hour = 11, minute = 0, duration = 60 }, { hour = 20, minute = 0, duration = 60 } }, days = { 1, 2, 4, 6 } },
	},
	[eventsName[locale].Abyssal_Atk] = {
		{ times = { { hour = 15, minute = 59, duration = 60 }, { hour = 20, minute = 29, duration = 60 } }, days = { 3, 5, 7 } },
	},
	[eventsName[locale].Hasla] = {
		{ times = { { hour = 19, minute = 0, duration = 30 }, { hour = 21, minute = 0, duration = 30 } }, days = { 1, 2, 3, 4, 5, 6, 7 } },
	},
	[eventsName[locale].Akasch] = {
		{ times = { { hour = 8, minute = 30, duration = 41 }, { hour = 16, minute = 30, duration = 41 }, { hour = 21, minute = 30, duration = 41 } }, days = { 7, 2 } },
	},
	[eventsName[locale].Scramble] = {
		{ times = { { hour = 9, minute = 0, duration = 60 }, { hour = 21, minute = 0, duration = 60 } }, days = { 1, 3 } },
	},
	[eventsName[locale].GM_Dragon] = {
		{ times = { { hour = 14, minute = 0, duration = 30 } }, days = { 7 } },
	},
	[eventsName[locale].Maintenance] = {
		{ times = { { hour = 7, minute = 0, duration = 40 } }, days = { 3 } },
	},
	[eventsName[locale].Watermelon] = {
		{
			times = {
				{ hour = 0, minute = 0, duration = 5 },
				{ hour = 8, minute = 0, duration = 5 },
				{ hour = 14, minute = 0, duration = 5 },
				{ hour = 19, minute = 0, duration = 5 },
			},
			days = { 1, 2, 3, 4, 5, 6, 7 },
		},
	},
}
