ADDON:ImportAPI(API_TYPE.LOCALE.id)

timeUntilLocale = X2Locale:GetLocale()

if timeUntilLocale ~= "en_us" and timeUntilLocale ~= "ru" and timeUntilLocale ~= "zh_cn" then
	timeUntilLocale = "en_us"
end

eventsName = {
	["ru"] = {
		GR = "Призрачка",
		CR = "Кровь",
		Hiram = "Рамианский",
		SG_CR = "Анталон",
		JMG = "АГЛ",
		Lusca = "Спруты",
		BD = "Ксанатос",
		Kraken = "Кракен",
		Leviathan = "Левиафан",
		Charybdis = "Калидис",
		Anthalon_G = "Анталон(Сады)",
		Halcy = "Даскшир",
		RD = "Гартарейн",
		Abyssal_Atk = "Спруты",
		Hasla = "Зомби",
		Akasch = "Ифнир",
		Prairie = "Луг",
		Wonderland = "Чудесариум",
		Scramble = "Scramble",
		SjinderSon = "SjinderSon",
		Maintenance = "Maintenance",
	},
	["en_us"] = {
		GR = "GR",
		CR = "CR",
		Hiram = "Hiram T6",
		SG_CR = "SG CR",
		JMG = "JMG",
		Lusca = "Lusca",
		BD = "BD",
		Kraken = "Kraken",
		Leviathan = "Leviathan",
		Charybdis = "Charybdis",
		Anthalon_G = "Anthalon(G)",
		Halcy = "Halcyona",
		RD = "RD",
		Abyssal_Atk = "Abyssal Atk",
		Hasla = "Hasla",
		Akasch = "Akasch",
		Prairie = "Prairie",
		Wonderland = "Wonderland",
		Scramble = "Scramble",
		SjinderSon = "SjinderSon",
		Maintenance = "Maintenance",
	},
	["zh_cn"] = {
		GR = "迷雾",
		CR = "征兆",
		Hiram = "Hiram T6",
		SG_CR = "安塔伦",
		JMG = "JMG",
		Lusca = "阿肯",
		BD = "黑龙",
		Kraken = "克拉肯",
		Leviathan = "利维坦",
		Charybdis = "卡里迪斯",
		Anthalon_G = "庭院安塔伦",
		Halcy = "黄金",
		RD = "红龙",
		Abyssal_Atk = "深渊",
		Hasla = "翡翠谷征兆",
		Akasch = "守山",
		Prairie = "大草原",
		Wonderland = "Wonderland",
		Scramble = "Scramble",
		SjinderSon = "SjinderSon",
		Maintenance = "Maintenance",
	},
}

dynamicEventsName = {
	["ru"] = {
		aegis = "Эфен",
		whalesong = "Бухта",
	},
	["en_us"] = {
		aegis = "Aegis",
		whalesong = "Whalesong",
	},
	["zh_cn"] = {
		aegis = "烛台",
		whalesong = "鲸鱼",
	},
}
