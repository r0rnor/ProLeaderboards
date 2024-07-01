--stylua: ignore start
local DataStoreService = game:GetService("DataStoreService")


local ConstantLeaderboard = require(script.Parent.ConstantLeaderboard)
local PageSettings = require(script.Parent.PageSettings)

local Signal = require(script.Parent.Signal)


export type TemporaryLeaderboard = ConstantLeaderboard.ConstantLeaderboard & {
    leaderboardKey : string,
    timeUntilReset : number,
    resetTime : number,

    leaderboardReset : RBXScriptSignal
}


local TemporaryLeaderboard = {}
TemporaryLeaderboard.__index = function(_, key : string)
    return rawget(TemporaryLeaderboard, key) or rawget(ConstantLeaderboard, key)
end

function TemporaryLeaderboard.new(leaderboardHandlerKey : string, leaderboardKey : string, pageSettings : PageSettings.PageSettings, resetTime : number)
    local self : TemporaryLeaderboard = ConstantLeaderboard.new(leaderboardHandlerKey, leaderboardKey, pageSettings)
    setmetatable(self, TemporaryLeaderboard)

    self.leaderboardKey = leaderboardHandlerKey.. "-" ..leaderboardKey
    self.resetTime = resetTime
    self.timeUntilReset = 0
    self.leaderboardReset = Signal.new()

    self:resetData()

    return self
end

function TemporaryLeaderboard:resetData()
    local version = self:getVersion()

    self.orderedDataStore = DataStoreService:GetOrderedDataStore(self.leaderboardKey, version)

    self.leaderboardReset:Fire(self.leaderboardKey, version, version - 1)
end

function TemporaryLeaderboard:decreaseTimeUntilReset(number : number)
    local self : TemporaryLeaderboard = self

    self.timeUntilReset = math.max(self.timeUntilReset - number, 0)

    if self.timeUntilReset == 0 then
        self:resetData()
    end
end

function TemporaryLeaderboard:getVersion() : number
    local version = math.floor(os.time() / self.resetTime)

    return version
end




return TemporaryLeaderboard

--stylua: ignore end
