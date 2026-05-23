local locale = timeUntilLocale or "en_us"

ruServerEvents = {
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
		{ times = { { hour = 12, minute = 20, duration = 30 } }, days = { 1, 2, 3, 4, 5, 6, 7 } },
	},
	[eventsName[locale].BD] = {
		{ times = { { hour = 21, minute = 30, duration = 60 } }, days = { 3, 5 } },
		{ times = { { hour = 18, minute = 30, duration = 60 } }, days = { 7 } },
	},
	[eventsName[locale].Kraken] = {
		{ times = { { hour = 22, minute = 30, duration = 60 } }, days = { 3, 5 } },
		{ times = { { hour = 19, minute = 30, duration = 60 } }, days = { 7 } },
	},
	[eventsName[locale].Leviathan] = {
		{ times = { { hour = 20, minute = 5, duration = 60 } }, days = { 3, 5 } },
		{ times = { { hour = 17, minute = 5, duration = 60 } }, days = { 7 } },
	},
	[eventsName[locale].Charybdis] = {
		{ times = { { hour = 21, minute = 30, duration = 60 } }, days = { 1, 5 } },
	},
	[eventsName[locale].Anthalon_G] = {
		{ times = { { hour = 21, minute = 30, duration = 45 } }, days = { 1, 2, 6 } },
	},
	[eventsName[locale].Halcy] = {
		{
			times = {
				{ hour = 1, minute = 30, duration = 30 },
				{ hour = 11, minute = 0, duration = 10 },
				{ hour = 20, minute = 30, duration = 10 },
			},
			days = { 1, 2, 3, 4, 5, 6, 7 },
		},
	},
	[eventsName[locale].RD] = {
		{
			times = {
				{ hour = 2, minute = 0, duration = 15 },
				{ hour = 10, minute = 30, duration = 15 },
				{ hour = 20, minute = 0, duration = 15 },
			},
			days = { 1, 2, 4, 6 },
		},
	},
	[eventsName[locale].Abyssal_Atk] = {
		{
			times = { { hour = 12, minute = 0, duration = 30 }, { hour = 22, minute = 30, duration = 30 } },
			days = { 3, 5, 7 },
		},
	},
	[eventsName[locale].Hasla] = {
		{
			times = { { hour = 18, minute = 49, duration = 15 }, { hour = 20, minute = 49, duration = 15 } },
			days = { 1, 2, 3, 4 },
		},
	},
	[eventsName[locale].Akasch] = {
		{
			times = {
				{ hour = 15, minute = 0, duration = 20 },
				{ hour = 18, minute = 30, duration = 20 },
				{ hour = 21, minute = 30, duration = 20 },
			},
			days = { 7 },
		},
		{
			times = {
				{ hour = 15, minute = 0, duration = 20 },
				{ hour = 18, minute = 30, duration = 20 },
				{ hour = 22, minute = 0, duration = 20 },
			},
			days = { 6 },
		},
	},
	[eventsName[locale].Prairie] = {
		{
			times = { { hour = 9, minute = 0, duration = 20 }, { hour = 22, minute = 0, duration = 20 } },
			days = { 6, 7 },
		},
	},
	[eventsName[locale].Wonderland] = {
		{
			times = {
				{ hour = 11, minute = 0, duration = 5 },
				{ hour = 19, minute = 0, duration = 5 },
			},
			days = { 1, 2, 3, 4, 5, 6, 7 },
		},
	},
}
