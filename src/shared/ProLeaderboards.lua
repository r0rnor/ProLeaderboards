export type Leaderboard = {}

local ProLeaderboards = {}
ProLeaderboards.__index = ProLeaderboards

function ProLeaderboards.new()
	local self: Leaderboard = setmetatable({}, ProLeaderboards)
end

return ProLeaderboards
