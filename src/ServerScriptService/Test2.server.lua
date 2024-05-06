local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ProLeaderboards = require(ReplicatedStorage.ProLeaderboards.ProLeaderboards)

local ORDER = { "all-time", "minute" }

local leaderboardPart = workspace.Leaderboard
local leaderboardUi = leaderboardPart.SurfaceGui
local scrollingFrames = leaderboardUi.ScrollingFrames
local switchButton = leaderboardUi.Switch
local slotTemplate = ReplicatedStorage.Slot

local leaderboard = ProLeaderboards.new(false, "global1")
leaderboard:addDataStore("minute", 20)

local coins = 0
local anyaCoins = 0

local function updateUi()
	for storeKey: string, list in leaderboard:getData() do
		local leaderboardFrame = scrollingFrames:FindFirstChild(storeKey)

		for _, slot: Frame in leaderboardFrame:GetChildren() do
			if not slot:IsA("Frame") then
				continue
			end

			slot:Destroy()
		end

		for index, info in pairs(list) do
			local slot = slotTemplate:Clone()
			slot.Parent = leaderboardFrame

			slot.IndexLabel.Text = "#" .. index
			slot.NameLabel.Text = info.key
			slot.ValueLabel.Text = info.value
		end
	end
end

leaderboard.resetLeaderboard:Connect(function(storeKey: string)
	print(storeKey, "updated!")

	wait(1)
end)

switchButton.MouseButton1Click:Connect(function()
	local currentType = switchButton.Text
	local currentIndex = table.find(ORDER, currentType)

	local nextIndex = if currentIndex == #ORDER then 1 else currentIndex + 1
	local nextType = ORDER[nextIndex]

	switchButton.Text = nextType

	scrollingFrames:FindFirstChild(currentType).Visible = false
	scrollingFrames:FindFirstChild(nextType).Visible = true
end)

leaderboard.timeUpdated:Connect(function(storeKey: string, time: number)
	print(storeKey, "time now:", time)
end)

while true do
	wait(3)

	coins += 5
	anyaCoins += math.random(3, 7)

	leaderboard:set("r0rnor", coins)
	leaderboard:set("anya<3", anyaCoins)

	updateUi()
end
