-- stylua: ignore start
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")


local packages = ReplicatedStorage.Packages
local Signal = require(packages.Signal)


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

	resetedDataStore : RBXScriptSignal,
	updatedLeaderboards : RBXScriptSignal,
}


local function updateTimeDataStores(self : Leaderboard, deltaValue : number, key : string)
	for _, timeDataStore in self.timeDataStores do
		timeDataStore.data:UpdateAsync(key, function(timeOldValue)
			return if timeOldValue then deltaValue + timeOldValue else deltaValue
		end)
	end
end

local function connectResetting(self : Leaderboard, startTime : number?, updateTime : number?)
	local startTime = startTime or 0
	local updateTime = updateTime or 60

	local function resetStore(storeKey : string, dataStore : TimeDataStore)
		local timeIndex = math.floor(os.time() / dataStore.resetTime)
		local previousTimeIndex = math.floor((os.time() - updateTime) / dataStore.resetTime)

		if previousTimeIndex ~= timeIndex then
			self.resetLeaderboard:Fire(storeKey, timeIndex, previousTimeIndex)
		end

		dataStore.data = DataStoreService:GetOrderedDataStore(self.globalKey..storeKey, timeIndex)
	end

	local currentTime = startTime
	RunService.Heartbeat:Connect(function(deltaTime)
		currentTime += deltaTime

		if currentTime < updateTime then
			return
		end

		currentTime = 0

		for storeKey, timeDataStore in self.timeDataStores do
			resetStore(storeKey, timeDataStore)
		end

		self.updatedLeaderboards:Fire()
	end)
end


local ProLeaderboards = {}
ProLeaderboards.__index = ProLeaderboards

ProLeaderboards.resetLeaderboard = Signal.new()
ProLeaderboards.updatedLeaderboards = Signal.new()


function ProLeaderboards.new(globalKey : string, updateTime : number?, startTime : number?, pageSettings : PageSettings?) : Leaderboard
	assert(globalKey, "Global key is not provided to .new()")

	local self : Leaderboard = setmetatable({}, ProLeaderboards)

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

	connectResetting(self, startTime, updateTime)

	return self
end

function ProLeaderboards:addDataStore(storeKey : string, resetTime : number, pageSettings : PageSettings?)
	assert(storeKey, "Store key is not provided to :addDataStore()")
	assert(resetTime, "Reset time of data store is not provided to :addDataStore()")

	local self : Leaderboard = self

	local timeDataStore : TimeDataStore = {}
	local timeIndex = math.floor(os.time() / resetTime)

	timeDataStore.pageSettings = pageSettings or self.defaultPageSettings
	timeDataStore.pageSettings.ascending = if timeDataStore.pageSettings.ascending == nil then true else timeDataStore.pageSettings.ascending
	timeDataStore.pageSettings.pageSize = if self.defaultPageSettings.pageSize == nil then 100 else self.defaultPageSettings.pageSize

	timeDataStore.resetTime = resetTime
	timeDataStore.data = DataStoreService:GetOrderedDataStore(self.globalKey..storeKey, timeIndex)

	self.timeDataStores[storeKey] = timeDataStore
end

function ProLeaderboards:set(key : string, value : number)
	assert(key, "Key is not provided to :set()")
	assert(value, "Value is not provided to :set()")

	local self : Leaderboard = self
	
	self.allTimeDataStore:UpdateAsync(key, function(oldValue)
		oldValue = oldValue or 0

		local deltaValue = math.max(value - oldValue, 0)

		delay(0, function()
			updateTimeDataStores(self, deltaValue, key)
		end)

		return value
	end)
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

	repeat
		local Entries = pages:GetCurrentPage()
		resultPages[pageIndex] = {}

		for _, Entry in pairs(Entries) do
			rank += 1
			resultPages[pageIndex][rank] = Entry
		end

		if not pages.IsFinished then pages:AdvanceToNextPageAsync() pageIndex += 1 end
	until pages.IsFinished or pageIndex > numberOfPages

	return if numberOfPages ~= 1 then resultPages else resultPages[1]
end



return ProLeaderboards
-- stylua: ignore end
