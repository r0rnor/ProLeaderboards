-- stylua: ignore start
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local Signal = require(game.ReplicatedStorage.Packages.Signal)
local Trove = require(game.ReplicatedStorage.Packages.Trove)
local Promise = require(game.ReplicatedStorage.Packages.Promise)


export type PageSettings = {
	Ascending: boolean,
	PageSize: number,
	MinValue: number,
	MaxValue: number,
}

export type UISettings = {
	List : ScrollingFrame
}

export type KeyInfo = {
	CellIndex : number,
	PreviousValue : number,
	Value : number,
}

export type Cell = {
	StartTime : number,
	Data : OrderedDataStore
}

export type Leaderboard = {
	_trove : Trove,

	LiveDataStore: OrderedDataStore,
	KeysDataStore: GlobalDataStore,
	Cells : {[number] : Cell},
	LastCellIndex : number,
	DataStoreName: string,
	ReloadTime: number,
	UpdateTime : number,
	FirstTimeLoad : boolean,
	UpdateType : "All-Time" | "Regular",


	PageSettings: PageSettings,

	UpdateUI: RBXScriptSignal,
}



local ProLeaderboards = {}
ProLeaderboards.__index = ProLeaderboards


local function FirstTimeLoadCells(self : Leaderboard)
	local Cells : {[number] : Cell} = {}

	self.FirstTimeLoad = false
	local Index = 0
	local LastNumberOfRanks = 0

	repeat
		Index += 1

		Cells[Index] = {}
		local Cell = Cells[Index]
		
		Cell.StartTime = DataStoreService:GetDataStore(self.DataStoreName, "Cell"..Index):GetAsync("StartTime") or 0
		Cell.Data = DataStoreService:GetOrderedDataStore(self.DataStoreName, "Cell"..Index)

		local Ranks = self:GetPages(1, Cell.Data)[1]

		LastNumberOfRanks = #Ranks
	until LastNumberOfRanks <= 1

	Cells[#Cells] = nil

	DataStoreService:GetDataStore(self.DataStoreName, "CellsInfo"):SetAsync("LastCellIndex", #Cells)

	return Cells
end

local function LoadCells(self : Leaderboard)
	local Cells : {[number] : Cell} = {}
	local LastCellIndex : number = DataStoreService:GetDataStore(self.DataStoreName, "CellsInfo"):GetAsync("LastCellIndex") or 1

	for Index = 1, LastCellIndex do
		Promise.try(function()
			Cells[Index] = {}
			local Cell = Cells[Index]
			
			Cell.StartTime = DataStoreService:GetDataStore(self.DataStoreName, "Cell"..Index):GetAsync("StartTime") or 0
			Cell.Data = DataStoreService:GetOrderedDataStore(self.DataStoreName, "Cell"..Index)
		end)
	end

	return Cells
end

local function GetCells(self : Leaderboard)
	local Cells : {[number] : Cell} = self.FirstTimeLoad and FirstTimeLoadCells(self) or LoadCells(self)

	print("Cells:", #Cells, Cells)

	self.LiveDataStore = DataStoreService:GetOrderedDataStore(self.DataStoreName, "Cell"..#Cells)

	return Cells
end

local function UpdateCells(self : Leaderboard)
	self.Cells = GetCells(self)
	self.LastCellIndex = #self.Cells

	print("Cells updated!")
	print("-------------------------------")
end

local function CreateCell(self : Leaderboard)
	DataStoreService:GetDataStore(self.DataStoreName, "CellsInfo"):SetAsync("LastCellIndex", self.LastCellIndex + 1)
	DataStoreService:GetDataStore(self.DataStoreName, "Cell"..self.LastCellIndex + 1):SetAsync("StartTime", os.time())

	print("New cell created!")

	UpdateCells(self)
end


function ProLeaderboards.new(DataStoreName: string?, ReloadTime: number?, PageSettings : PageSettings?, UpdateTime : number?)
	local self: Leaderboard = setmetatable({}, ProLeaderboards)

	self._trove = Trove.new()
	self.FirstTimeLoad = true

	self.ReloadTime = ReloadTime or 60
	self.UpdateTime = UpdateTime or -1
	self.UpdateType = self.UpdateTime > 0 and "Regular" or "All-Time"
	self.UpdateUI = Signal.new()

	self.PageSettings = PageSettings or {Ascending = false, PageSize = 100}
	self.PageSettings.Ascending = self.PageSettings.Ascending or false
	self.PageSettings.PageSize = self.PageSettings.PageSize and math.clamp(self.PageSettings.PageSize, 0, 100) or 100

	self.DataStoreName = DataStoreName or "Basic"
	self.Cells = GetCells(self)
	self.LastCellIndex = #self.Cells

	if self.UpdateType == "Regular" and self.Cells[self.LastCellIndex].StartTime + self.UpdateTime <= os.time() then 
		CreateCell(self)
	end

	self.KeysDataStore = DataStoreService:GetDataStore(self.DataStoreName, "Keys")

	local ReloadCurrentTime = 0
	local UpdateCurrentTime = 0
	self._trove:Connect(RunService.Heartbeat, function(deltaTime)
		ReloadCurrentTime += deltaTime
		UpdateCurrentTime += deltaTime

		if ReloadCurrentTime >= self.ReloadTime then
			ReloadCurrentTime = 0
			self.UpdateUI:Fire(self:GetPages(1)[1], self.LastCellIndex)
		end
		
		if UpdateCurrentTime >= 10 then
			UpdateCurrentTime = 0
			if self.UpdateType ~= "Regular" or self.Cells[self.LastCellIndex].StartTime + self.UpdateTime > os.time() then return end

			CreateCell(self)
		end
	end)

	return self
end

function ProLeaderboards:GetPages(NumberOfPages : number?, DataStore : OrderedDataStore?)
	local self: Leaderboard = self
	local NumberOfPages = NumberOfPages or 10^4
	local DataStore = DataStore or self.LiveDataStore

	local Pages : DataStorePages = DataStore:GetSortedAsync(self.PageSettings.Ascending, self.PageSettings.PageSize, self.PageSettings.MinValue, self.PageSettings.MaxValue)

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

local function SetKeyInfo(self : Leaderboard, CellIndex : number, SetKey : string, NewValue : number, PreviousValue : number)
	local NewKeyInfo : KeyInfo = {
		Cell = CellIndex,
		Value = NewValue,
		PreviousValue = PreviousValue
	}

	self.KeysDataStore:SetAsync(SetKey, NewKeyInfo)
	
	return NewKeyInfo
end

local function CalculateLeaderboardValue(self : Leaderboard, SetKey : string, NewValue : number)
	local KeyInfo = self.KeysDataStore:GetAsync(SetKey)

	if not KeyInfo then
		KeyInfo = SetKeyInfo(self, self.LastCellIndex, SetKey, NewValue, 0)
	end

	if KeyInfo.Cell < self.LastCellIndex then
		print("[😨] Updating KeyInfo OLD", KeyInfo)
		KeyInfo = SetKeyInfo(self, self.LastCellIndex, SetKey, NewValue, KeyInfo.Value)
		print("[😨] Updating KeyInfo NEW", KeyInfo)
	end

	print("[😨] NewValue, PreviousValue, NV - PV, Result", NewValue, KeyInfo.PreviousValue, NewValue - KeyInfo.PreviousValue, math.max(NewValue - KeyInfo.PreviousValue, 0))

	return math.max(NewValue - KeyInfo.PreviousValue, KeyInfo.PreviousValue)
end

function ProLeaderboards:SetValue(Player: Player | string, NewValue: any)
	local self: Leaderboard = self

	assert(Player, "Player or string wasn't provided to :SetValue")
	assert(NewValue, "New value wasn't provided to :SetValue")

	local SetKey = typeof(Player) ~= "string" and Player.UserId or Player

	local LeaderboardValue = CalculateLeaderboardValue(self, SetKey, NewValue)

	self.LiveDataStore:SetAsync(SetKey, LeaderboardValue)
end

function ProLeaderboards:ConnectValue(Player: Player | string, ValueInstance: ValueBase)
	local self: Leaderboard = self

	self:SetValue(Player, ValueInstance.Value)

	ValueInstance.Changed:Connect(function()
		self:SetValue(Player, ValueInstance.Value)
	end)
end

function ProLeaderboards:ConnectDictionaryValue(Player : Player | string, Table : {}, Key : string, SetDataCooldown : number)
	local self: Leaderboard = self

	local CurrentTime = 0

	local UpdateLeaderboardDataConnection = self._trove:Connect(RunService.Heartbeat, function(deltaTime)
		CurrentTime += deltaTime
		if CurrentTime < SetDataCooldown then return end
		CurrentTime = 0

		self:SetValue(Player, Table[Key])
	end)

	return UpdateLeaderboardDataConnection
end

function ProLeaderboards:Destroy()
	self._trove:Destroy()
end

return ProLeaderboards

-- stylua: ignore end
