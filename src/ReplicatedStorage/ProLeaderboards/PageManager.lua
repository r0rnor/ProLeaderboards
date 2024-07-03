--stylua: ignore start

local PageSettings = require(script.Parent.PageSettings)


type Leaderboard = {
    orderedDataStore : OrderedDataStore,
    pageSettings : PageSettings.PageSettings
}

type PageArray = {
    [number] : rankInfo
}

type rankInfo = {
    key : string,
    value : number
}

export type PageManager = {
    leaderboard : Leaderboard
}

local PageManager = {}
PageManager.__index = PageManager

function PageManager.new(leaderboard : Leaderboard) : PageManager
    local self : PageManager = setmetatable({}, PageManager)

    self.leaderboard = leaderboard

    return self
end

function PageManager:getPage(regionalScope : string?) : {[number] : rankInfo}
    local self : PageManager = self

    local pages = self:getAllPages(regionalScope)
    local page = pages:GetCurrentPage()

    return page
end

function PageManager:getAllPages(regionalScope : string?) : DataStorePages
    local self : PageManager = self

    local pageSettingsArguments = self.leaderboard.pageSettings:convertToArgument()
    local orderedDataStore = self.leaderboard:getOrderedDataStore(regionalScope)
    local pages = orderedDataStore:GetSortedAsync(table.unpack(pageSettingsArguments))

    return pages
end

function PageManager:getValueByKey(key : string, regionalScope : string?) : number
    local self : PageManager = self

    local function getValueIfExist(page : PageArray)
        return self:getValueByKeyInPage(page, key)
    end

    local value = self:goThroughAllPagesAndCallFunctionEveryPage(getValueIfExist, regionalScope)

	return value
end

function PageManager:getRankByKey(key : string, regionalScope : string?) : number
    local self : PageManager = self

    local function getRankIfExist(page : PageArray, previousRanks : number)
        local rankInPage = self:getRankByKeyInPage(page, key)
        local rank = rankInPage and rankInPage + previousRanks

        return rank
    end

    local rank = self:goThroughAllPagesAndCallFunctionEveryPage(getRankIfExist, regionalScope)

	return rank
end

function PageManager:goThroughAllPagesAndCallFunctionEveryPage(functionToCall : (page : PageArray, previousRanks : number) -> (), regionalScope : string?)
    local self : PageManager = self

    local pages = self:getAllPages(regionalScope)
    local pageIndex = 1
    local value

    repeat
        local page = pages:GetCurrentPage()
        local previousRanks = #page * (pageIndex - 1)

        value = functionToCall(page, previousRanks)

        if not pages.IsFinished then
            pages:AdvanceToNextPageAsync()
        end

        pageIndex += 1

        wait()
    until pages.IsFinished or value

	return value
end

function PageManager:getValueByKeyInPage(page : PageArray, key : string)
    local _, rankInfo = PageManager:getRankAndRankInfoByKeyInPage(page, key)

    return rankInfo.value
end

function PageManager:getRankByKeyInPage(page : PageArray, key : string)
    local rank = PageManager:getRankAndRankInfoByKeyInPage(page, key)

    return rank
end

function PageManager:getRankAndRankInfoByKeyInPage(page : PageArray, key : string)
    for rank, rankInfo in ipairs(page) do
        if tostring(rankInfo.key) == tostring(key) then
            return rank, rankInfo
        end
    end
end

return PageManager

--stylua: ignore end
