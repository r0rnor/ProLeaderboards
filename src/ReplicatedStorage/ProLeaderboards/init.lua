--stylua: ignore start
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")


local Signal = require(script.Signal)
local Promise = require(script.Promise)


export type Leaderboard = {
	globalKey : string,
	pageSettings : PageSettings,
	allTimeDataStore : OrderedDataStore,
	dictionaryOfTemporaryDataStores : {
		[string] : TemporaryDataStore
	},

	leaderboardReset : RBXScriptSignal,
	timeUpdated : RBXScriptSignal,
}

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


local ProLeaderboards = {}
local metaPageSettings = {
	__index = {
		ascending = false,
		pageSize = 100,
		minValue = 0,
	}
}

local function resetStoreIfTimeEqualsToZero(self : Leaderboard, storeKey : string)
	local temporaryDataStore = self.dictionaryOfTemporaryDataStores[storeKey]
	local timeIndex = math.floor(os.time() / temporaryDataStore.resetTime)
	local previousTimeIndex = math.floor((os.time() - temporaryDataStore.resetTime) / temporaryDataStore.resetTime)

	if temporaryDataStore.timeUntilReset > 0 then
		return
	end

	if previousTimeIndex ~= timeIndex then
		self.leaderboardReset:Fire(storeKey, timeIndex, previousTimeIndex)
	end

	temporaryDataStore.timeUntilReset = temporaryDataStore.resetTime
	temporaryDataStore.dataStore = DataStoreService:GetOrderedDataStore(self.globalKey..storeKey, timeIndex)
end

local function decreaseTimeOfTemporaryDataStore(self : Leaderboard, storeKey : string, currentTime : number)
	local temporaryDataStore = self.dictionaryOfTemporaryDataStores[storeKey]
	
	temporaryDataStore.timeUntilReset = math.max(temporaryDataStore.timeUntilReset - currentTime, 0)
	self.timeUpdated:Fire(storeKey, temporaryDataStore.timeUntilReset)
end

local function decreaseTimeOfAllTemporaryDataStores(self : Leaderboard, currentTime : number)
	for storeKey, _ in self.dictionaryOfTemporaryDataStores do
		decreaseTimeOfTemporaryDataStore(self, storeKey, currentTime)
		resetStoreIfTimeEqualsToZero(self, storeKey)
	end
end

local function decreaseTimeOfTemporaryDataStoresEverySecond(self : Leaderboard)
	local currentTime = 0
	RunService.Heartbeat:Connect(function(deltaTime)
		currentTime += deltaTime

		if currentTime < 1 then
			return
		end

		decreaseTimeOfAllTemporaryDataStores(self, currentTime)
		currentTime = 0
	end)
end

local function getPromisedOrDefaultFunction(self : Leaderboard, key : string)
	local indexedFunction = ProLeaderboards[key]

	if typeof(indexedFunction) ~= "function" or not self.promise then
		return indexedFunction
	end

	return Promise.promisify(indexedFunction)
end

local function createLeaderboard(promise : boolean, globalKey : string, pageSettings : PageSettings?) : Leaderboard
	local self : Leaderboard = setmetatable({}, ProLeaderboards)

	self.pageSettings = setmetatable(pageSettings or {}, metaPageSettings)
	self.promise = promise
	self.globalKey = globalKey
	self.allTimeDataStore = DataStoreService:GetOrderedDataStore(self.globalKey.."All-Time", 1)
	self.dictionaryOfTemporaryDataStores = {}

	return self
end


ProLeaderboards.__index = getPromisedOrDefaultFunction
ProLeaderboards.leaderboardReset = Signal.new()
ProLeaderboards.timeUpdated = Signal.new()


function ProLeaderboards.new(promise : boolean, globalKey : string, pageSettings : PageSettings?) : Leaderboard
	local self = createLeaderboard(promise, globalKey, pageSettings)
	decreaseTimeOfTemporaryDataStoresEverySecond(self)

	return self
end


function ProLeaderboards:addTemporaryDataStore(storeKey : string, resetTime : number, pageSettings : PageSettings?)
	local self : Leaderboard = self

	local temporaryDataStore : TemporaryDataStore = {}
	local timeIndex = math.floor(os.time() / resetTime)

	temporaryDataStore.dataStore = DataStoreService:GetOrderedDataStore(self.globalKey..storeKey, timeIndex)
	temporaryDataStore.pageSettings = setmetatable(pageSettings or self.pageSettings, metaPageSettings)
	temporaryDataStore.resetTime = resetTime
	temporaryDataStore.timeUntilReset = 0

	self.dictionaryOfTemporaryDataStores[storeKey] = temporaryDataStore
end


function ProLeaderboards:set(key : string, value : number)
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


function ProLeaderboards:getPage(storeKey : string?) : Page
	local self : Leaderboard = self
	local dataStore = if not storeKey then self.allTimeDataStore else self.dictionaryOfTemporaryDataStores[storeKey].dataStore
	local pageSettings = if not storeKey then self.pageSettings else self.dictionaryOfTemporaryDataStores[storeKey].pageSettings
	local pages = dataStore:GetSortedAsync(pageSettings.ascending, pageSettings.pageSize, pageSettings.minValue, pageSettings.maxValue)

	return pages:GetCurrentPage()
end


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
