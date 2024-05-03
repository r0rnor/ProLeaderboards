-- stylua: ignore start
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")


export type TimeDataStore = {
	data : OrderedDataStore,
	resetTime : number,
}

export type Leaderboard = {
	globalKey : string,
	allTimeDataStore : OrderedDataStore,
	timeDataStores : {
		[string] : TimeDataStore
	}
}


local function updateTimeDataStores(self : Leaderboard, deltaValue : number, key : string)
	for _, timeDataStore in self.timeDataStores do
		timeDataStore.data:UpdateAsync(key, function(timeOldValue)
			return if timeOldValue then deltaValue + timeOldValue else 0
		end)
	end
end


local ProLeaderboards = {}
ProLeaderboards.__index = ProLeaderboards


function ProLeaderboards.new(globalKey : string, updateTime : number?, startTime : number?)
	local startTime = startTime or 0
	local updateTime = updateTime or 60

	local self : Leaderboard = setmetatable({}, ProLeaderboards)

	self.globalKey = globalKey
	self.allTimeDataStore = DataStoreService:GetOrderedDataStore(self.globalKey.."All-Time", 1)
	self.timeDataStores = {}

	local currentTime = startTime
	RunService.Heartbeat:Connect(function(deltaTime)
		currentTime += deltaTime

		if currentTime < updateTime then
			return
		end

		currentTime = 0

		for storeKey, timeDataStore in self.timeDataStores do
			local timeIndex = math.floor(os.time() / timeDataStore.resetTime)
			timeDataStore.data = DataStoreService:GetOrderedDataStore(self.globalKey..storeKey, timeIndex)
		end
	end)

	return self
end

function ProLeaderboards:addDataStore(storeKey : string, resetTime : number)
	local self : Leaderboard = self

	local timeDataStore : TimeDataStore = {}
	local timeIndex = math.floor(os.time() / resetTime)

	timeDataStore.resetTime = resetTime
	timeDataStore.data = DataStoreService:GetOrderedDataStore(self.globalKey..storeKey, timeIndex)

	self.timeDataStores[storeKey] = timeDataStore
end

function ProLeaderboards:set(key : string, value : number)
	local self : Leaderboard = self
	
	self.allTimeDataStore:UpdateAsync(key, function(oldValue)
		local deltaValue = value - oldValue

		updateTimeDataStores(self, deltaValue, key)

		return value
	end)
end

function ProLeaderboards:getPages(numberOfPages : number)
	local self : Leaderboard = self
	local numberOfPages = numberOfPages or 10^4

	local pages = self.allTimeDataStore:GetSortedAsync(true, 100, 0)
	local resultPages = {}
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

	return resultPages
end



return ProLeaderboards
-- stylua: ignore end
