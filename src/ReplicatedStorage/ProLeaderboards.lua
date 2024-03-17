local DataStoreService = game:GetService("DataStoreService")
local Signal = require(game.ReplicatedStorage.Packages.Signal)

export type PageSettings = {
	Ascending: boolean,
	PageSize: number,
	MinValue: number,
	MaxValue: number,
}

export type Leaderboard = {
	DataStore: OrderedDataStore,
	DataStoreName: string,
	UpdateTime: number,
	PageSettings: PageSettings,

	UpdateUI: RBXScriptSignal,
}

local ProLeaderboards = {}
ProLeaderboards.__index = ProLeaderboards

function ProLeaderboards.new(DataStoreName: string?, UpdateTime: number?, Ascending: boolean?, PageSize: number?, MinValue: number?, MaxValue: number?)
	local self: Leaderboard = setmetatable({}, ProLeaderboards)

	self.DataStoreName = DataStoreName or "Basic"
	self.DataStore = DataStoreService:GetOrderedDataStore(self.DataStoreName)
	self.UpdateTime = UpdateTime or 60
	self.UpdateUI = Signal.new()
	self.PageSettings = {
		Ascending = Ascending or true,
		PageSize = PageSize and math.clamp(PageSize, 1, 100) or 100,
		MinValue = MinValue,
		MaxValue = MaxValue,
	}

	while true do
		task.wait(20)
		self.UpdateUI:Fire(ProLeaderboards.GetPages(self)[1])
	end

	return self
end

function ProLeaderboards.GetPages(self: Leaderboard)
	local ResultPages = {}

	local Pages = self.DataStore:GetSortedAsync(self.PageSettings.Ascending, self.PageSettings.PageSize, self.PageSettings.MinValue, self.PageSettings.MaxValue)

	repeat
		local Entries = Pages:GetCurrentPage()

		table.insert(ResultPages, Entries)

		if not Pages.IsFinished then
			Pages:AdvanceToNextPageAsync()
		end
	until Pages.IsFinished

	print(ResultPages)

	return ResultPages
end

function ProLeaderboards.SetValue(self: Leaderboard, Player: Player, NewValue: any)
	self.DataStore:SetAsync(Player.UserId, NewValue)
end

function ProLeaderboards.ConnectValueInstance(self: Leaderboard, Player: Player, ValueInstance: ValueBase)
	ValueInstance.Changed:Connect(function()
		ProLeaderboards.SetValue(self, Player, ValueInstance.Value)
	end)
end

return ProLeaderboards
