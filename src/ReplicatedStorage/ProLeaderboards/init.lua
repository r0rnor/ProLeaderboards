-- stylua: ignore start

----------------------------------------------------------------------
--						ProLeaderboards module						--
--						by r0rnor (discord)							--
--	github & docs link: "https://github.com/r0rnor/ProLeaderboards"	--											
--																	--
--	  This module helps creating data stores which are resetting	--
--	    every N seconds (or even are not resetting, this is in		--
-- all-time data store case). You can use this module for creating, --
--	    for example, hourly/daily/monthly/all-time leaderboards		--
--				(P.S. this is my first public module)				--
----------------------------------------------------------------------

--[=[
	@class ProLeaderboards

	Module which helps with creating OrderedDataStores which resets periodically. Also creates all-time data store
]=]


local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")


local Signal = require(script.Signal)
local Promise = require(script.Promise)


--[=[
	@within ProLeaderboards
	@interface Leaderboard
	.storeKey string -- first part of data store key
	.pageSettings PageSettings
	.allTimeDataStore OrderedDataStore
	.dictionaryOfTemporaryDataStores {[string] : TemporaryDataStore}
	.leaderboardReset RBXScriptSignal
	.timeUpdated RBXScriptSignal

	Main object of this module.

	```lua
	local leaderboard = ProLeaderboards.new(false, "Power")
	leaderboard:addDataStore("daily", 24 * 60^2)
	leaderboard:addDataStore("weekly", 7 * 24 * 60^2)
	
	while wait(30) do
		for _, player in Players:GetPlayers() do
			leaderboard:set(player.Power.Value)
		end

		for dataStoreKey, page in pairs(leaderboard:getDictionaryOfDataStores()) do
			for rank, playerInfo in ipairs(page) do
				local userId = playerInfo.key
				local powerValue = playerInfo.value

				print(dataStoreKey.." has "..userId.." player, which have "..powerValue.." power")
			end
		end
	end
	```

	This example creates a daily, weekly and all-time (by default) leaderboards.
	Every 30 seconds these leaderboards are updating, and then script prints leaders of this data stores and their amount of power
]=]

--[=[
	@within ProLeaderboards
	@prop leaderboardReset RBXScriptSignal
	@tag Event
	@tag Leaderboard Class

	This event fires when any temporary data store resets.
	Returns TemporaryDataStore key, which was reset, current TemporaryDataStore version index, and previous TemporaryDataStore version index

	```lua
	local leaderboard = ProLeaderboards.new(false, "Coins")
	leaderboard:addDataStore("daily", 24 * 60^2)

	leaderboard.leaderboardReset:Connect(function(temporaryDataStoreKey, currentVersion, previousVersion)
		print(temporaryDataStoreKey.." updated from "..previousVersion.." version to "..currentVersion)
	end)
	```

	This example creates a simple daily leaderboard. There is event, which fires when this daily leaderboard resets (every 24h) and prints it's name, previousVersion and currentVersion
]=]

--[=[
	@within ProLeaderboards
	@prop timeUpdated RBXScriptSignal
	@tag Event
	@tag Leaderboard Class

	This event fires every ≈1 second. Returns TemporaryDataStore key, which was updated and returns seconds till reset of this leaderboard

	```lua
	local leaderboard = ProLeaderboards.new(false, "Coins")
	leaderboard:addDataStore("daily", 24 * 60^2)
	leaderboard:addDataStore("hourly", 60^2)

	leaderboard.timeUpdated:Connect(function(temporaryDataStoreKey, timeUntilReset)
		print(temporaryDataStore.. " will reset in ".. timeUntilReset.. " seconds!")
	end)
	```

]=]


export type Leaderboard = {
	storeKey : string,
	pageSettings : PageSettings,
	allTimeDataStore : OrderedDataStore,
	dictionaryOfTemporaryDataStores : {
		[string] : TemporaryDataStore
	},

	leaderboardReset : RBXScriptSignal,
	timeUpdated : RBXScriptSignal,
}

--[=[
	@interface PageSettings
	@within ProLeaderboards
	.ascending bool -- Is data in pages will be ascending or descending
	.pageSize number -- Determines to what rank the dictionary will be
	.minValue number? -- The minimum amount required to enter the dictionary
	.maxValue number? -- The maximum amount required to enter the dictionary

	Settings for pages you are obtaining on calling :getPage() or :getDictionaryOfDataStores.

]=]

export type PageSettings = {
	ascending : boolean,
	pageSize : number,
	minValue : number?,
	maxValue : number?,
}

export type TemporaryDataStore = {
	dataStore : OrderedDataStore,
	resetTime : number,
	pageSettings : PageSettings,
	timeUntilReset : number
}

export type Page = {
	[number] : {
		key : string,
		value : number
	}
}


local metaPageSettings = {
	__index = {
		ascending = false,
		pageSize = 100,
		minValue = 0,
	}
}

local function connectResetting(self : Leaderboard)
	local function resetStore(storeKey : string, temporaryDataStore : TemporaryDataStore)
		local timeIndex = math.floor(os.time() / temporaryDataStore.resetTime)
		local previousTimeIndex = math.floor((os.time() - temporaryDataStore.resetTime) / temporaryDataStore.resetTime)

		if previousTimeIndex ~= timeIndex then
			self.leaderboardReset:Fire(storeKey, timeIndex, previousTimeIndex)
		end

		temporaryDataStore.timeUntilReset = temporaryDataStore.resetTime
		temporaryDataStore.dataStore = DataStoreService:GetOrderedDataStore(self.globalKey..storeKey, timeIndex)
	end

	local currentTime = 0
	RunService.Heartbeat:Connect(function(deltaTime)
		currentTime += deltaTime

		if currentTime < 1 then
			return
		end

		for storeKey, temporaryDataStore in self.dictionaryOfTemporaryDataStores do
			temporaryDataStore.timeUntilReset = math.max(temporaryDataStore.timeUntilReset - currentTime, 0)
			self.timeUpdated:Fire(storeKey, temporaryDataStore.timeUntilReset)

			if temporaryDataStore.timeUntilReset > 0 then
				continue
			end

			resetStore(storeKey, temporaryDataStore)
		end

		currentTime = 0
	end)
end


local ProLeaderboards = {}
ProLeaderboards.__index = function(self : Leaderboard, key : string)
	if
		typeof(ProLeaderboards[key]) ~= "function"
		or key == "new"
	then
		return ProLeaderboards[key]
	end

	if self.promise then
		return Promise.promisify(ProLeaderboards[key])
	else
		return ProLeaderboards[key]
	end
end

ProLeaderboards.leaderboardReset = Signal.new()
ProLeaderboards.timeUpdated = Signal.new()


--[=[
	@within ProLeaderboards
	@function new

	@param promise bool
	@param globalKey string
	@param pageSettings PageSettings?

	@return Leaderboard

	@tag Leaderboard

	Constructs a new Leaderboard (class)
]=]

function ProLeaderboards.new(promise : boolean, globalKey : string, pageSettings : PageSettings?) : Leaderboard
	assert(globalKey, "Global key is not provided to .new()")
	
	local self : Leaderboard = setmetatable({}, ProLeaderboards)

	self.pageSettings = setmetatable(pageSettings or {}, metaPageSettings)
	self.promise = promise
	self.globalKey = globalKey
	self.allTimeDataStore = DataStoreService:GetOrderedDataStore(self.globalKey.."All-Time", 1)
	self.dictionaryOfTemporaryDataStores = {}

	connectResetting(self)

	return self
end


--[=[
	@within ProLeaderboards
	@method addDataStore

	@param storeKey string
	@param resetTime number
	@param pageSettings PageSettings?

	Adding a temporaryDataStore with [storeKey] key that resets every [resetTime] seconds
]=]

function ProLeaderboards:addTemporaryDataStore(storeKey : string, resetTime : number, pageSettings : PageSettings?)
	assert(storeKey, "Store key is not provided to :addTemporaryDataStore()")
	assert(resetTime, "Reset time of data store is not provided to :addTemporaryDataStore()")

	local self : Leaderboard = self

	local temporaryDataStore : TemporaryDataStore = {}
	local timeIndex = math.floor(os.time() / resetTime)

	temporaryDataStore.pageSettings = setmetatable(pageSettings or self.pageSettings, metaPageSettings)
	temporaryDataStore.resetTime = resetTime
	temporaryDataStore.timeUntilReset = 0
	temporaryDataStore.dataStore = DataStoreService:GetOrderedDataStore(self.globalKey..storeKey, timeIndex)

	self.dictionaryOfTemporaryDataStores[storeKey] = temporaryDataStore
end

--[=[
	@within ProLeaderboards
	@method set

	@param key string
	@param value number

	Updates leaderboards
]=]

function ProLeaderboards:set(key : string, value : number)
	assert(key, "Key is not provided to :set()")
	assert(value, "Value is not provided to :set()")

	local self : Leaderboard = self

	local function updateTemporaryDataStores(deltaValue : number, key : string)
		for _, temporaryDataStore in self.dictionaryOfTemporaryDataStores do
			temporaryDataStore.dataStore:UpdateAsync(key, function(timeOldValue)
				return if timeOldValue then deltaValue + timeOldValue else deltaValue
			end)
		end
	end

	self.allTimeDataStore:UpdateAsync(key, function(oldValue)
		oldValue = oldValue or 0

		local deltaValue = math.max(value - oldValue, 0)

		coroutine.wrap(function()
			updateTemporaryDataStores(deltaValue, key)
		end)()

		return value
	end)
end

--[=[
	@within ProLeaderboards
	@method getPage

	@param storeKey string?

	@return Page

	Return page of data store, which storeKey given. If storeKey == nil, then return page of all-time dataStore
	Page is dictionary, whose key is number (rank of a player) and value is another table,
	which contains key (user ID of player) and value (value, which was saved)
]=]

function ProLeaderboards:getPage(storeKey : string?) : Page
	local self : Leaderboard = self
	
	local dataStore = if not storeKey then self.allTimeDataStore else self.dictionaryOfTemporaryDataStores[storeKey].dataStore
	local pageSettings = if not storeKey then self.pageSettings else self.dictionaryOfTemporaryDataStores[storeKey].pageSettings
	local pages = dataStore:GetSortedAsync(pageSettings.ascending, pageSettings.pageSize, pageSettings.minValue, pageSettings.maxValue)

	return pages:GetCurrentPage()
end

--[=[
	@within ProLeaderboards
	@method getDictionaryOfDataStores

	@param storeKey string?

	@return {[string] : Page} 

	Return dictionary whose key is dataStore key and whose value is :getPage() runned over it
]=]

function ProLeaderboards:getDictionaryOfDataStores() : {[string] : Page}
	local self : Leaderboard = self
	local dictionaryOfDataStores = {}

	for storeKey, _ in self.dictionaryOfTemporaryDataStores do
		if not self.promise then
			dictionaryOfDataStores[storeKey] = self:getPage(storeKey)
		else
			local _, pages = self:getPage(storeKey):await()
			dictionaryOfDataStores[storeKey] = pages
		end
	end

	if not self.promise then
		dictionaryOfDataStores["all-time"] = self:getPage()
	else
		local _, pages = self:getPage():await()
		dictionaryOfDataStores["all-time"] = pages
	end

	return dictionaryOfDataStores
end


--[=[
	@within ProLeaderboards
	@method getDataByKey

	@param lostKey string
	@param storeKey string?

	@return (number, number)


]=]


function ProLeaderboards:getDataByKey(lostKey : string, storeKey : string?) : (number, number)
	local dataStore = if not storeKey then self.allTimeDataStore else self.dictionaryOfTemporaryDataStores[storeKey].dataStore
	local pageSettings = if not storeKey then self.pageSettings else self.dictionaryOfTemporaryDataStores[storeKey].pageSettings
	local pages = dataStore:GetSortedAsync(pageSettings.ascending, pageSettings.pageSize, pageSettings.minValue, pageSettings.maxValue)
	local pageIndex = 0

	local function getRankByKey() : number | nil
		local page = pages:GetCurrentPage()
	
		pageIndex += 1

		for rank : number, rankInfo : {key : string, value : number} in ipairs(page) do
			if tostring(rankInfo.key) == tostring(lostKey) then
				return rank + (pageIndex - 1) * #page, rankInfo.value
			end
		end

		if pages.IsFinished then
			return nil, nil
		else
			pages:AdvanceToNextPageAsync()
		end

		wait()
	
		return getRankByKey()
	end

	return getRankByKey()
end



function ProLeaderboards:getDictionaryOfDataByKey(lostKey : string)
	local self : Leaderboard = self
	local dictionaryOfRanks = {}

	for storeKey, _ in self.dictionaryOfTemporaryDataStores do
		if not self.promise then
			dictionaryOfRanks[storeKey] = self:getRank(lostKey, storeKey)
		else
			local _, rank = self:getRank(lostKey, storeKey):await()
			dictionaryOfRanks[storeKey] = rank
		end
	end

	if not self.promise then
		dictionaryOfRanks["all-time"] = self:getRank(lostKey)
	else
		local _, rank = self:getRank(lostKey):await()
		dictionaryOfRanks["all-time"] = rank
	end

	return dictionaryOfRanks
end


return ProLeaderboards
-- stylua: ignore end
