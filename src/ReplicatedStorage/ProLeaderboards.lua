-- stylua: ignore start
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local Signal = require(game.ReplicatedStorage.Packages.Signal)



export type PageSettings = {
	Ascending: boolean,
	PageSize: number,
	MinValue: number,
	MaxValue: number,
}

export type UISettings = {
	List : ScrollingFrame
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

function ProLeaderboards.new(DataStoreName: string?, UpdateTime: number?, PageSettings : PageSettings?)
	local self: Leaderboard = setmetatable({}, ProLeaderboards)

	self.DataStoreName = DataStoreName or "Basic"
	self.DataStore = DataStoreService:GetOrderedDataStore(self.DataStoreName)
	self.UpdateTime = UpdateTime or 60
	self.UpdateUI = Signal.new()

	self.PageSettings = PageSettings or {Ascending = false, PageSize = 100}
	self.PageSettings.Ascending = self.PageSettings.Ascending or false
	self.PageSettings.PageSize = self.PageSettings.PageSize and math.clamp(self.PageSettings.PageSize, 0, 100) or 100

	--a

	local CurrentTime = 0
	RunService.Heartbeat:Connect(function(deltaTime)
		CurrentTime += deltaTime
		if CurrentTime < self.UpdateTime then return end
		CurrentTime = 0
		self.UpdateUI:Fire(self:GetPages(1)[1])
	end)

	return self
end

function ProLeaderboards:GetPages(NumberOfPages : number?)
	local self: Leaderboard = self
	local NumberOfPages = NumberOfPages or 10^4

	local Pages : DataStorePages = self.DataStore:GetSortedAsync(self.PageSettings.Ascending, self.PageSettings.PageSize, self.PageSettings.MinValue, self.PageSettings.MaxValue)

	local ResultPages = {}
	local PageIndex : number = 1
	local Rank : number = 0

	repeat
		local Entries = Pages:GetCurrentPage()
		ResultPages[PageIndex] = {}

		for _, Entry in pairs(Entries) do
			Rank += 1
			ResultPages[PageIndex][Rank] = Entry
		end

		if not Pages.IsFinished then Pages:AdvanceToNextPageAsync() PageIndex += 1 end
	until Pages.IsFinished or PageIndex > NumberOfPages

	return ResultPages
end

function ProLeaderboards:SetValue(Player: Player | string, NewValue: any)
	local self: Leaderboard = self

	assert(Player, "Player or string wasn't provided to :SetValue")
	assert(NewValue, "New value wasn't provided to :SetValue")

	local SetKey = typeof(Player) ~= "string" and Player.UserId or Player

	self.DataStore:SetAsync(SetKey, NewValue)
end

function ProLeaderboards:ConnectValue(Player: Player | string, ValueInstance: ValueBase)
	local self: Leaderboard = self

	self:SetValue(Player, ValueInstance.Value)

	ValueInstance.Changed:Connect(function()
		self:SetValue(Player, ValueInstance.Value)
	end)
end

return ProLeaderboards

-- stylua: ignore end
