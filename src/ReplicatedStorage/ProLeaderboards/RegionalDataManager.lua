--stylua: ignore start
local Players = game:GetService("Players")
local LocaliztionService = game:GetService("LocalizationService")
local DataStoreService = game:GetService("DataStoreService")


export type RegionalDataManager = {
	regionalDataStore : GlobalDataStore
}

local REGIONAL_INDICATORS = {
	a = "🇦",
	b = "🇧",
	c = "🇨",
	d = "🇩",
	e = "🇪",
	f = "🇫",
	g = "🇬",
	h = "🇭",
	i = "🇮",	
	j = "🇯",
	k = "🇰",
	l = "🇱",
	m = "🇲",
	n = "🇳",
	o = "🇴",
	p = "🇵",
	q = "🇶",
	r = "🇷",
	s = "🇸",
	t = "🇹",
	u = "🇺",
	v = "🇻",
	w = "🇼",
	x = "🇽",
	y = "🇾",
	z = "🇿",
}


local RegionalDataManager = {}
RegionalDataManager.__index = RegionalDataManager

function RegionalDataManager.new(dataStoreKey : string)
	local self : RegionalDataManager = setmetatable({}, RegionalDataManager)

    self.regionalDataStore = DataStoreService:GetDataStore(dataStoreKey.."-Regional")
	self:_addPlayersToRegionDataStore()

	return self
end

function RegionalDataManager:_addPlayersToRegionDataStore()
	for _, player in Players:GetPlayers() do
		self:setPlayerRegionToDataStore(player)
	end

	Players.PlayerAdded:Connect(function(player : Player)
		self:setPlayerRegionToDataStore(player)
	end)
end

function RegionalDataManager:setPlayerRegionToDataStore(player : Player)
	local regionName = self:getRegionByPlayer(player)

	self.regionalDataStore:SetAsync(player.UserId, regionName)
end

function RegionalDataManager:getRegionByPlayer(player : Player)
	local regionID = string.lower(LocaliztionService:GetCountryRegionForPlayerAsync(player))
	local letter1 = string.sub(regionID, 1, 1)
	local letter2 = string.sub(regionID, 2, 2)
	return REGIONAL_INDICATORS[letter1]..REGIONAL_INDICATORS[letter2]
end

function RegionalDataManager:getRegionByUserId(userId : string)
	return self.regionalDataStore:GetAsync(userId)
end

return RegionalDataManager
--stylua: ignore end
