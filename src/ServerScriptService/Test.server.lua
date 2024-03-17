local ProLeaderboards = require(game.ReplicatedStorage.ProLeaderboards.ProLeaderboards)

local Leaderboard = ProLeaderboards.new("CoinsStore", 5, { PageSize = 5 })
Leaderboard:ConnectValue("TestBeast", workspace.TestBeastCoins)
Leaderboard:SetValue("MrBeast2", 30)
Leaderboard:SetValue("MrBeast3", 420)
Leaderboard:SetValue("MrBeast4", 10)
Leaderboard:SetValue("MrBeast5", 1488)

Leaderboard.UpdateUI:Connect(function(Pages: {})
	print("Here is the 1st page!: ", Pages)
end)
