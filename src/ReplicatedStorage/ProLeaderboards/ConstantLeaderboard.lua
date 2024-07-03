--stylua: ignore start
local DataStoreService = game:GetService("DataStoreService")


local PageSettings = require(script.Parent.PageSettings)
local PageManager = require(script.Parent.PageManager)


type rankInfo = {
    key : string,
    value : number
}

export type ConstantLeaderboard = {
    classType : string,

    pageSettings : PageSettings.PageSettings,
    pageManager : PageSettings.PageManager,
    leaderboardKey : string,
}


local ConstantLeaderboard = {}
ConstantLeaderboard.__index = ConstantLeaderboard

function ConstantLeaderboard.new(leaderboardHandlerKey : string, leaderboardKey : string, pageSettings : PageSettings.PageSettings?)
    local self : ConstantLeaderboard = setmetatable({}, ConstantLeaderboard)

    self.classType = "ConstantLeaderboard"
    self.leaderboardKey = leaderboardHandlerKey.. "-" .. leaderboardKey
    self.pageSettings = PageSettings.new(pageSettings)
    self.pageManager = PageManager.new(self)

    return self
end

function ConstantLeaderboard:update(key : string, value : number, regionalScope : string) : number
    local orderedDataStore = self:getOrderedDataStore()
    local regionalOrderedDataStore = if regionalScope then self:getOrderedDataStore(regionalScope) else nil
    local deltaValue : number = 0

    orderedDataStore:UpdateAsync(key, function(oldValue : number)
        deltaValue = math.max(value - (oldValue or 0), 0)

        return value
    end)

    if regionalScope then
        regionalOrderedDataStore:SetAsync(key, value)
    end

    return deltaValue
end

function ConstantLeaderboard:add(key : string, value : number, regionalScope : string) : number
    local orderedDataStore = self:getOrderedDataStore()
    local regionalOrderedDataStore = if regionalScope then self:getOrderedDataStore(regionalScope) else nil

    orderedDataStore:UpdateAsync(key, function(oldValue : number)
        return math.max((oldValue or 0) + value, 0)
    end)

    if regionalScope then
        regionalOrderedDataStore:UpdateAsync(key, function(oldValue : number)
            return math.max((oldValue or 0) + value, 0)
        end)
    end
end

function ConstantLeaderboard:getValueByKey(key : string, regionalScope : string?) : number?
    local value = self.pageManager:getValueByKey(key, regionalScope)

    return value
end

function ConstantLeaderboard:getRankByKey(key : string, regionalScope : string?) : number?
    local rank = self.pageManager:getRankByKey(key, regionalScope)

    return rank
end

function ConstantLeaderboard:getPage(regionalScope : string?) : {[number] : rankInfo}
    local page = self.pageManager:getPage(regionalScope)

    return page
end

function ConstantLeaderboard:getAllPages(regionalScope : string?) : DataStorePages
    local pages = self.pageManager:getAllPages(regionalScope)

    return pages
end

function ConstantLeaderboard:getOrderedDataStore(regionalScope : string?)
    return DataStoreService:GetOrderedDataStore(self.leaderboardKey, regionalScope)
end

return ConstantLeaderboard

--stylua: ignore end
