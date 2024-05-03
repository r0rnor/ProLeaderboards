-- stylua: ignore start
local DataStoreService = game:GetService("DataStoreService")


export type TimeDataStore = {
	data : OrderedDataStore,
	resetTime : number,
}

export type Leaderboard = {
	globalKey : string,
	allTimeDataStore : OrderedDataStore,
	dataStores : {
		[string] : TimeDataStore
	}
}


local ProLeaderboards = {}
ProLeaderboards.__index = ProLeaderboards


function ProLeaderboards.new(globalKey : string)
	local self = setmetatable({}, ProLeaderboards)

	self.globalKey = globalKey
	self.allTimeDataStore = DataStoreService:GetOrderedDataStore(globalKey)

	return self
end

function ProLeaderboards:set(key : string, value : number)
	local self : Leaderboard = self
	
	self.allTimeDataStore:UpdateAsync(key, function()
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
