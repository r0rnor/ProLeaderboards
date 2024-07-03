--stylua: ignore start
local DataStoreService = game:GetService("DataStoreService")


local ConstantLeaderboard = require(script.Parent.ConstantLeaderboard)
local PageSettings = require(script.Parent.PageSettings)

local Signal = require(script.Parent.Signal)


export type TemporaryLeaderboard = ConstantLeaderboard.ConstantLeaderboard & {
    timeUntilReset : number,
    resetTime : number,

    leaderboardReset : RBXScriptSignal,
    timeUpdated : RBXScriptSignal,
}


local TemporaryLeaderboard = {}
TemporaryLeaderboard.__index = function(_, key : string)
    return rawget(TemporaryLeaderboard, key) or rawget(ConstantLeaderboard, key)
end

function TemporaryLeaderboard.new(leaderboardHandlerKey : string, leaderboardKey : string, resetTime : number, pageSettings : PageSettings.PageSettings)
    local self : TemporaryLeaderboard = ConstantLeaderboard.new(leaderboardHandlerKey, leaderboardKey, pageSettings)
    setmetatable(self, TemporaryLeaderboard)

    self.classType = "TemporaryLeaderboard"
    self.leaderboardKey = leaderboardHandlerKey.. "-" ..leaderboardKey
    self.resetTime = resetTime
    self.timeUntilReset = resetTime * (self:getVersion() + 1) - os.time()
    self.leaderboardReset = Signal.new()
    self.timeUpdated = Signal.new()

    self:resetData()

    return self
end

function TemporaryLeaderboard:resetData()
    local version = self:getVersion()

    self.leaderboardReset:Fire(version, version - 1)
end

function TemporaryLeaderboard:decreaseTimeUntilReset(number : number)
    local self : TemporaryLeaderboard = self

    self.timeUntilReset = math.max(self.timeUntilReset - number, 0)

    if self.timeUntilReset == 0 then
        self.timeUntilReset = self.resetTime
        self:resetData()
    end

    self.timeUpdated:Fire(self.timeUntilReset)
end


function TemporaryLeaderboard:getOrderedDataStore(regionalScope : string?)
    local version = self:getVersion()
    local orderedDataStore = DataStoreService:GetOrderedDataStore(self.leaderboardKey.."-"..version, regionalScope)

    return orderedDataStore
end

function TemporaryLeaderboard:getVersion() : number
    local version = math.floor(os.time() / self.resetTime)

    return version
end


return TemporaryLeaderboard

--stylua: ignore end
