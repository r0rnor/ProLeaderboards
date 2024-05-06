local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ProLeaderboards = require(ReplicatedStorage.ProLeaderboards.ProLeaderboards)

local ORDER = { "all-time", "minute" }

local leaderboardPart = workspace.Leaderboard
local leaderboardUi = leaderboardPart.SurfaceGui
local scrollingFrames = leaderboardUi.ScrollingFrames
local switchButton = leaderboardUi.Switch
local slotTemplate = ReplicatedStorage.Slot

local leaderboard = ProLeaderboards.new("global1", 10, 7)
leaderboard:addDataStore("minute", 60)

local coins = 0
local anyaCoins = 0

local function updateLeaderboardUi()
	for _, leaderboardFrame: ScrollingFrame in scrollingFrames:GetChildren() do
		for _, slot: Frame in leaderboardFrame:GetChildren() do
			if not slot:IsA("Frame") then
				continue
			end

			slot:Destroy()
		end

		local dataStoreKey = leaderboardFrame.Name

		if dataStoreKey == "all-time" then
			dataStoreKey = nil
		end

		local list = leaderboard:getPages(dataStoreKey)

		for index, info in pairs(list) do
			local slot = slotTemplate:Clone()
			slot.Parent = leaderboardFrame

			slot.IndexLabel.Text = "#" .. index
			slot.NameLabel.Text = info.key
			slot.ValueLabel.Text = info.value
		end
	end
end

leaderboard.updatedLeaderboards:Connect(function()
	wait(1)

	updateLeaderboardUi()
end)

leaderboard.resetedDataStore:Connect(function(storeKey: string)
	wait(1)

	print(storeKey, "updated!")

	updateLeaderboardUi()
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

while true do
	wait(3)

	coins += 5
	anyaCoins += math.random(3, 7)

	leaderboard:set("r0rnor", coins)
	leaderboard:set("anya<3", anyaCoins)
end
