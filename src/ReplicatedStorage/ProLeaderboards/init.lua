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

export type TimeDataStore = {
	data : OrderedDataStore,
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
	globalKey : string,
	defaultPageSettings : PageSettings,
	allTimeDataStore : OrderedDataStore,
	timeDataStores : {
		[string] : TimeDataStore
	},

	resetLeaderboard : RBXScriptSignal,
	timeUpdated : RBXScriptSignal,
}



local function connectResetting(self : Leaderboard)
	local function resetStore(storeKey : string, dataStore : TimeDataStore)
		local timeIndex = math.floor(os.time() / dataStore.resetTime)
		local previousTimeIndex = math.floor((os.time() - dataStore.resetTime) / dataStore.resetTime)

		if previousTimeIndex ~= timeIndex then
			self.resetLeaderboard:Fire(storeKey, timeIndex, previousTimeIndex)
		end

		dataStore.timeUntilReset = dataStore.resetTime
		dataStore.data = DataStoreService:GetOrderedDataStore(self.globalKey..storeKey, timeIndex)
	end

	local currentTime = 0
	RunService.Heartbeat:Connect(function(deltaTime)
		currentTime += deltaTime

		if currentTime < 1 then
			return
		end

		for storeKey, timeDataStore in self.timeDataStores do
			timeDataStore.timeUntilReset = math.max(timeDataStore.timeUntilReset - currentTime, 0)
			self.timeUpdated:Fire(storeKey, timeDataStore.timeUntilReset)

			if timeDataStore.timeUntilReset > 0 then
				continue
			end

			resetStore(storeKey, timeDataStore)
		end

		currentTime = 0
	end)
end


local ProLeaderboards = {}
ProLeaderboards.__index = ProLeaderboards

ProLeaderboards.resetLeaderboard = Signal.new()
ProLeaderboards.timeUpdated = Signal.new()


function ProLeaderboards.new(promise : boolean, globalKey : string, pageSettings : PageSettings?) : Leaderboard
	assert(globalKey, "Global key is not provided to .new()")
	
	local self : Leaderboard = setmetatable({}, ProLeaderboards)
	self.promise = promise

	self.defaultPageSettings = pageSettings or {
		ascending = false,
		pageSize = 100,
		minValue = 0
	}

	self.defaultPageSettings.ascending = if self.defaultPageSettings.ascending == nil then true else self.defaultPageSettings.ascending
	self.defaultPageSettings.pageSize = if self.defaultPageSettings.pageSize == nil then 100 else self.defaultPageSettings.pageSize

	self.globalKey = globalKey
	self.allTimeDataStore = DataStoreService:GetOrderedDataStore(self.globalKey.."All-Time", 1)
	self.timeDataStores = {}

	connectResetting(self)

	return self
end

function ProLeaderboards:addDataStore(storeKey : string, resetTime : number, pageSettings : PageSettings?)
	assert(storeKey, "Store key is not provided to :addDataStore()")
	assert(resetTime, "Reset time of data store is not provided to :addDataStore()")

	local self : Leaderboard = self

	local function newDataStore()
		local timeDataStore : TimeDataStore = {}
		local timeIndex = math.floor(os.time() / resetTime)
	
		timeDataStore.pageSettings = pageSettings or self.defaultPageSettings
		timeDataStore.pageSettings.ascending = if timeDataStore.pageSettings.ascending == nil then true else timeDataStore.pageSettings.ascending
		timeDataStore.pageSettings.pageSize = if self.defaultPageSettings.pageSize == nil then 100 else self.defaultPageSettings.pageSize
	
		timeDataStore.resetTime = resetTime
		timeDataStore.timeUntilReset = 0
		timeDataStore.timeUpdated = Signal.new()
		timeDataStore.data = DataStoreService:GetOrderedDataStore(self.globalKey..storeKey, timeIndex)
	
		self.timeDataStores[storeKey] = timeDataStore
	end

	if not self.promise then
		return newDataStore()
	elseif self.promise then
		return Promise.try(newDataStore)
	end
end

function ProLeaderboards:set(key : string, value : number)
	assert(key, "Key is not provided to :set()")
	assert(value, "Value is not provided to :set()")

	local self : Leaderboard = self

	local function updateTimeDataStore(timeDataStore : TimeDataStore, key : string, deltaValue : number)
		timeDataStore.data:UpdateAsync(key, function(timeOldValue)
			return if timeOldValue then deltaValue + timeOldValue else deltaValue
		end)
	end

	local function updateTimeDataStores(deltaValue : number, key : string)
		for _, timeDataStore in self.timeDataStores do
			updateTimeDataStore(timeDataStore, key, deltaValue)
		end
	end

	local function updateDataStores()
		self.allTimeDataStore:UpdateAsync(key, function(oldValue)
			oldValue = oldValue or 0
	
			local deltaValue = math.max(value - oldValue, 0)
	
			delay(0, function()
				updateTimeDataStores(deltaValue, key)
			end)
	
			return value
		end)
	end
	
	if not self.promise then
		return updateDataStores()
	elseif self.promise then
		return Promise.try(updateDataStores)
	end
end

function ProLeaderboards:getPages(storeKey : string?, numberOfPages : number?) : Pages | Page
	local self : Leaderboard = self
	
	local dataStore = if not storeKey then self.allTimeDataStore else self.timeDataStores[storeKey].data
	local pageSettings = if not storeKey then self.defaultPageSettings else self.timeDataStores[storeKey].pageSettings
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
	elseif self.promise then
		return Promise.try(loopThroughPages)
	end
end

function ProLeaderboards:getData(numberOfPages : number?)
	local self : Leaderboard = self

	local function getData()
		local resultTable = {}

		for storeKey, _ in self.timeDataStores do
			if not self.promise then
				resultTable[storeKey] = self:getPages(storeKey, numberOfPages)
			elseif self.promise then
				self:getPages(storeKey, numberOfPages):andThen(function(pages : Pages | Page)
					resultTable[storeKey] = pages
				end)
			end
		end
	
		if not self.promise then
			resultTable["all-time"] = self:getPages(nil, numberOfPages)
		elseif self.promise then
			self:getPages(nil, numberOfPages):andThen(function(pages : Pages | Page)
				resultTable["all-time"] = pages
			end)
		end
	
		return resultTable
	end

	if not self.promise then
		return getData()
	elseif self.promise then
		return Promise.try(getData)
	end
end



return ProLeaderboards
-- stylua: ignore end
