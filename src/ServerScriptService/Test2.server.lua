local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProLeaderboards = require(ReplicatedStorage.ProLeaderboards.ProLeaderboards)

local leaderboard = ProLeaderboards.new("test1k", 10, 7)
leaderboard:addDataStore("half", 30)

print(leaderboard)

-- game.Players.PlayerAdded:Connect(function(player)
-- 	leaderboard:set(player.UserId, 10)

-- 	wait(3)

-- 	local page = leaderboard:getPages(1)[1]
-- 	print(page)
-- end)
