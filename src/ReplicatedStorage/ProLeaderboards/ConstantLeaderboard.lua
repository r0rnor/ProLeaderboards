--stylua: ignore start
local DataStoreService = game:GetService("DataStoreService")


local PageSettings = require(script.Parent.PageSettings)
local PageManager = require(script.Parent.PageManager)


export type ConstantLeaderboard = {
    pageSettings : PageSettings.PageSettings,
    pageManager : PageSettings.PageManager,
    orderedDataStore : OrderedDataStore,
}


local ConstantLeaderboard = {}
ConstantLeaderboard.__index = ConstantLeaderboard

function ConstantLeaderboard.new(leaderboardHandlerKey : string, leaderboardKey : string, pageSettings : PageSettings.PageSettings?)
    local self : ConstantLeaderboard = setmetatable({}, ConstantLeaderboard)

    self.orderedDataStore = DataStoreService:GetOrderedDataStore(leaderboardHandlerKey.. "-" .. leaderboardKey)
    self.pageSettings = PageSettings.new(pageSettings)
    self.pageManager = PageManager.new(self)

    return self
end

function ConstantLeaderboard:update(key : string, value : number) : number
    local deltaValue : number = 0

    self.orderedDataStore:UpdateAsync(key, function(oldValue : number)
        deltaValue = math.max(value - oldValue, 0)

        return value
    end)

    return deltaValue
end

function ConstantLeaderboard:getValueByKey(key : string) : number?
    local value = self.pageManager:getValueByKey(key)

    return value
end

function ConstantLeaderboard:getRankByKey(key : string) : number?
    local rank = self.pageManager:getRankByKey(key)

    return rank
end

return ConstantLeaderboard

--stylua: ignore end
