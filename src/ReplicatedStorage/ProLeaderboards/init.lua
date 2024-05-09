-- stylua: ignore start

----------------------------------------------------------------------
--						ProLeaderboards module						--
--						by r0rnor (discord)						--
--	github & docs link: "https://github.com/r0rnor/ProLeaderboards"	--											--
--																	--
--	  This module helps creating data stores which are resetting	--
--	    every N seconds (or even are not resetting, this is in		--
-- all-time data store case). You can use this module for creating, --
--	    for example, hourly/daily/monthly/all-time leaderboards		--
--				(P.S. this is my first public module)				--
----------------------------------------------------------------------

--[=[
	@class ProLeaderboards

	Test
]=]


local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")


local Signal = require(script.Signal)
local Promise = require(script.Promise)


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

export type Pages = {
	[number] : Page
}

export type Page = {
	[number] : {
		key : string,
		value : number
	}
}

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


local metaPageSettings = {
	__index = {
		ascending = false,
		pageSize = 100,
		minValue = 0,
	}
}

local function connectResetting(self : Leaderboard)
	local function resetStore(storeKey : string, dataStore : TemporaryDataStore)
		local timeIndex = math.floor(os.time() / dataStore.resetTime)
		local previousTimeIndex = math.floor((os.time() - dataStore.resetTime) / dataStore.resetTime)

		if previousTimeIndex ~= timeIndex then
			self.leaderboardReset:Fire(storeKey, timeIndex, previousTimeIndex)
		end

		dataStore.timeUntilReset = dataStore.resetTime
		dataStore.dataStore = DataStoreService:GetOrderedDataStore(self.globalKey..storeKey, timeIndex)
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
ProLeaderboards.__index = ProLeaderboards

ProLeaderboards.leaderboardReset = Signal.new()
ProLeaderboards.timeUpdated = Signal.new()


--[=[
	@within ProLeaderboards
	@function new

	@param promise bool
	@param globalKey string
	@param pageSettings PageSettings?

	@return Leaderboard

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

	Adding a temporaryDataStore that resets every <resetTime> seconds
]=]

function ProLeaderboards:addTemporaryDataStore(storeKey : string, resetTime : number, pageSettings : PageSettings?)
	assert(storeKey, "Store key is not provided to :addTemporaryDataStore()")
	assert(resetTime, "Reset time of data store is not provided to :addTemporaryDataStore()")

	local self : Leaderboard = self

	local function newDataStore()
		local temporaryDataStore : TemporaryDataStore = {}
		local timeIndex = math.floor(os.time() / resetTime)
	
		temporaryDataStore.pageSettings = setmetatable(pageSettings or self.pageSettings, metaPageSettings)
		temporaryDataStore.resetTime = resetTime
		temporaryDataStore.timeUntilReset = 0
		temporaryDataStore.dataStore = DataStoreService:GetOrderedDataStore(self.globalKey..storeKey, timeIndex)
	
		self.dictionaryOfTemporaryDataStores[storeKey] = temporaryDataStore
	end

	if not self.promise then
		return newDataStore()
	else
		return Promise.try(newDataStore)
	end
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

	local function updateTimeDataStore(temporaryDataStore : TemporaryDataStore, key : string, deltaValue : number)
		temporaryDataStore.dataStore:UpdateAsync(key, function(timeOldValue)
			return if timeOldValue then deltaValue + timeOldValue else deltaValue
		end)
	end

	local function updateTimeDataStores(deltaValue : number, key : string)
		for _, temporaryDataStore in self.dictionaryOfTemporaryDataStores do
			updateTimeDataStore(temporaryDataStore, key, deltaValue)
		end
	end

	local function updateDataStores()
		self.allTimeDataStore:UpdateAsync(key, function(oldValue)
			oldValue = oldValue or 0
	
			local deltaValue = math.max(value - oldValue, 0)
	
			coroutine.wrap(function()
				updateTimeDataStores(deltaValue, key)
			end)()
	
			return value
		end)
	end
	
	if not self.promise then
		return updateDataStores()
	else
		return Promise.try(updateDataStores)
	end
end

--[=[
	@within ProLeaderboards
	@method getPages

	@param storeKey string?
	@param numberOfPages number?

	@return Page | {[number] : Page}

	Return pages (if numberOfPages ~= nil or > 1) or page (if numberOfPages == nil or ==1).
	Page is dictionary, whose key is number (rank of a player) and value is another table,
	which contains key (user ID of player) and value (value, which was saved)
]=]

function ProLeaderboards:getPages(storeKey : string?, numberOfPages : number?) : Pages | Page
	local self : Leaderboard = self
	
	local dataStore = if not storeKey then self.allTimeDataStore else self.dictionaryOfTemporaryDataStores[storeKey].dataStore
	local pageSettings = if not storeKey then self.pageSettings else self.dictionaryOfTemporaryDataStores[storeKey].pageSettings
	local numberOfPages = numberOfPages or 1

	local pages = dataStore:GetSortedAsync(pageSettings.ascending, pageSettings.pageSize, pageSettings.minValue, pageSettings.maxValue)
	local resultPages : Pages = {}
	local pageIndex = 1
	local rank = 0

	local function insertList(Entries : {})
		for _, Entry in pairs(Entries) do
			rank += 1
			resultPages[pageIndex][rank] = Entry
		end
	end

	local function loopThroughPages()
		repeat
			local Entries = pages:GetCurrentPage()
			resultPages[pageIndex] = {}
	
			insertList(Entries)
	
			if not pages.IsFinished then
				pages:AdvanceToNextPageAsync() pageIndex += 1
			end
		until pages.IsFinished or pageIndex > numberOfPages

		return if numberOfPages ~= 1 then resultPages else resultPages[1]
	end

	if not self.promise then
		return loopThroughPages()
	else
		return Promise.try(loopThroughPages)
	end
end

--[=[
	@within ProLeaderboards
	@method getData

	@param numberOfPages number?

	@return {[string] : Page | {[number] : Page}} 

	Return dictionary whose key is Data Store key and whose value is :getPages() runned over it
]=]

function ProLeaderboards:getDictionaryOfDataStores(numberOfPages : number?)
	local self : Leaderboard = self

	local function getDictionaryOfDataStores()
		local dictionaryOfDataStores = {}

		for storeKey, _ in self.dictionaryOfTemporaryDataStores do
			if not self.promise then
				dictionaryOfDataStores[storeKey] = self:getPages(storeKey, numberOfPages)
			else
				self:getPages(storeKey, numberOfPages):andThen(function(pages : Pages | Page)
					dictionaryOfDataStores[storeKey] = pages
				end)
			end
		end
	
		if not self.promise then
			dictionaryOfDataStores["all-time"] = self:getPages(nil, numberOfPages)
		else
			self:getPages(nil, numberOfPages):andThen(function(pages : Pages | Page)
				dictionaryOfDataStores["all-time"] = pages
			end)
		end
	
		return dictionaryOfDataStores
	end

	if not self.promise then
		return getDictionaryOfDataStores()
	else
		return Promise.try(getDictionaryOfDataStores)
	end
end



return ProLeaderboards
-- stylua: ignore end
