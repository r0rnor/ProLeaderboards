local ProLeaderboards = require(game.ReplicatedStorage.ProLeaderboards.ProLeaderboards)

local List = workspace.Leaderboard.SurfaceGui.List

local function CleanList()
	for _, Frame in List:GetChildren() do
		if Frame.Name == "Example" or Frame:IsA("UIListLayout") then
			continue
		end

		Frame:Destroy()
	end
end

local function CreateFrames(Page: {})
	for Rank, Info in Page do
		local Frame = List.Example:Clone()
		Frame.Name = Rank
		Frame.Parent = List

		Frame.Key.Text = Info.key
		Frame.Value.Text = Info.value
		Frame.Rank.Text = Rank

		Frame.Visible = true
	end
end

local Leaderboard = ProLeaderboards.new("CoinsStore", 5, { PageSize = 20 }, 20)
Leaderboard.UpdateUI:Connect(function(Page: {}, LastCellIndex: number)
	CleanList()
	CreateFrames(Page)

	List.Parent.CellIndex.Text = "Cell: " .. LastCellIndex
end)

local CoinIndex = 1

while true do
	task.wait(2)
	CoinIndex += 1

	local Key = "Test1"
	local Value = math.random(1, 4) * CoinIndex

	print(Key, Value)

	Leaderboard:SetValue(Key, Value)
end
