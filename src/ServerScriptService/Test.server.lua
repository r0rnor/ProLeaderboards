local ProLeaderboards = require(game.ReplicatedStorage.ProLeaderboards.ProLeaderboards)

local Leaderboard = ProLeaderboards.new("CoinsStore", 5, { PageSize = 5 })

local TestTable = {
	Coins = 30,
	Gems = 20,
	Name = "Topaz228",
}

Leaderboard:ConnectDictionaryValue("Topaz228", TestTable, "Coins")

while true do
	task.wait(2)

	TestTable.Coins += math.random(-1, 3)
	print(TestTable)

	task.wait(2)

	TestTable.Gems += 2
	print(TestTable)
end
