--stylua: ignore start
local RunService = game:GetService("RunService")

local TemporaryLeaderboard = require(script.TemporaryLeaderboard)
local ConstantLeaderboard = require(script.ConstantLeaderboard)
local PageSettings = require(script.PageSettings)
local RegionalDataManager = require(script.RegionalDataManager)

local Signal = require(script.Signal)
local Promise = require(script.Promise)

type TemporaryLeaderboard = TemporaryLeaderboard.TemporaryLeaderboard
type ConstantLeaderboard = ConstantLeaderboard.ConstantLeaderboard

export type LeaderboardHandler = {
	_leaderboardHandlerKey : string,
	_updateTemporaryLeaderboardsConnection : RBXScriptConnection,

	promise : boolean,
	leaderboardReset : RBXScriptSignal,
	timeUpdated : RBXScriptSignal,

	regionalDataManager : RegionalDataManager.RegionalDataManager,

	leaderboards : {
		[string] : TemporaryLeaderboard | ConstantLeaderboard
	}
}


local ProLeaderboards = {}


local function getPromisedOrDefaultFunction(self : Leaderboard, key : string)
	local indexedFunction = ProLeaderboards[key]

	if typeof(indexedFunction) ~= "function" or not self.promise then
		return indexedFunction
	end

	return Promise.promisify(indexedFunction)
end


ProLeaderboards.__index = getPromisedOrDefaultFunction

function ProLeaderboards.new(leaderboardHandlerKey : string, promise : boolean?, includesRegional : boolean?, pageSettings : PageSettings.PageSettings?)
	local self : LeaderboardHandler = setmetatable({}, ProLeaderboards)

	self.promise = if promise then true else false
	self.leaderboardReset = Signal.new()
	self.timeUpdated = Signal.new()

	self._leaderboardHandlerKey = leaderboardHandlerKey
	self.leaderboards = {}
	self.leaderboards["All-Time"] = ConstantLeaderboard.new(self._leaderboardHandlerKey, "All-Time", pageSettings)

	self.regionalDataManager = if includesRegional == true then RegionalDataManager.new(self._leaderboardHandlerKey) else nil

	self:startUpdatingTemporaryLeaderboards()

	return self
end


function ProLeaderboards:addTemporaryLeaderboard(leaderboardKey : string, resetTime : number, pageSettings : PageSettings.PageSettings?)
	self:_createAndAssignTemporaryLeaderboard(leaderboardKey, resetTime, pageSettings)
	self:_connectTemporaryLeaderboardEvents(leaderboardKey)
end

function ProLeaderboards:_createAndAssignTemporaryLeaderboard(leaderboardKey : string, resetTime : number, pageSettings : PageSettings.PageSettings?)
	local temporaryLeaderboard = TemporaryLeaderboard.new(self._leaderboardHandlerKey, leaderboardKey, resetTime, pageSettings)	
	self.leaderboards[leaderboardKey] = temporaryLeaderboard
end

function ProLeaderboards:_connectTemporaryLeaderboardEvents(leaderboardKey : string)
	local temporaryLeaderboard = self.leaderboards[leaderboardKey]

	temporaryLeaderboard.leaderboardReset:Connect(function(version, previousVersion)
		self.leaderboardReset:Fire(leaderboardKey, version, previousVersion)
	end)

	temporaryLeaderboard.timeUpdated:Connect(function(timeUntilReset)
		self.timeUpdated:Fire(leaderboardKey, timeUntilReset)
	end)
end


function ProLeaderboards:getValueInLeaderboardByKeys(leaderboardKey : string, key : string)
	local leaderboard = self.leaderboards[leaderboardKey]

	return leaderboard:getValueByKey(key)
end

function ProLeaderboards:getRankInLeaderboardByKeys(leaderboardKey : string, key : string)
	local leaderboard = self.leaderboards[leaderboardKey]

	return leaderboard:getRankByKey(key)
end



function ProLeaderboards:set(key : string, value : number)
	local self : LeaderboardHandler = self
	local regionalScope

	if self.regionalDataManager then
		regionalScope = self.regionalDataManager:getRegionByUserId(key)
	end

	local differenceBetweenOldAndNewValue = if not self.promise then self:updateAllTimeLeaderboard(key, value, regionalScope) else self:updateAllTimeLeaderboard(key, value, regionalScope):expect()
	self:addValueToAllTemporaryLeaderboards(key, differenceBetweenOldAndNewValue, regionalScope)
end

function ProLeaderboards:addValueToAllTemporaryLeaderboards(key : string, value : number, regionalScope : string?)
	local self : LeaderboardHandler = self
	local allTemporaryLeaderboards = if not self.promise then self:getAllTemporaryLeaderboards() else self:getAllTemporaryLeaderboards():expect()

	for _, leaderboard in pairs(allTemporaryLeaderboards) do
		leaderboard:add(key, value, regionalScope)
	end
end

function ProLeaderboards:updateAllTimeLeaderboard(key : string, value : number, regionalScope : string?)
	local self : LeaderboardHandler = self
	local allTimeLeaderboard : ConstantLeaderboard = self.leaderboards["All-Time"]
	local deltaValue = allTimeLeaderboard:update(key, value, regionalScope)

	return deltaValue
end


function ProLeaderboards:getPageOfEveryLeaderboard(regionalScope : string?)
	local self : LeaderboardHandler = self
	local allPages = {}

	for leaderboardName, leaderboard in pairs(self.leaderboards) do
		allPages[leaderboardName] = leaderboard:getPage(regionalScope)
	end

	return allPages
end


function ProLeaderboards:startUpdatingTemporaryLeaderboards()
	local self : LeaderboardHandler = self
	local currentTime = 0

	self._updateTemporaryLeaderboardsConnection = RunService.Heartbeat:Connect(function(deltaTime : number)
		currentTime += deltaTime
		
		if currentTime < 1 then
			return
		end

		self:decreaseAllTemporaryLeaderboardsTimes(currentTime)
		currentTime = 0
	end)
end

function ProLeaderboards:stopUpdatingTemporaryLeaderboards()
	self._updateTemporaryLeaderboardsConnection:Disconnect()
end

function ProLeaderboards:decreaseAllTemporaryLeaderboardsTimes(decreaseNumber : number)
	local self : LeaderboardHandler = self
	local allTemporaryLeaderboards = if not self.promise then self:getAllTemporaryLeaderboards() else self:getAllTemporaryLeaderboards():expect()

	for _, leaderboard : TemporaryLeaderboard in pairs(allTemporaryLeaderboards) do
		leaderboard:decreaseTimeUntilReset(decreaseNumber)
	end
end

function ProLeaderboards:getAllTemporaryLeaderboards() : {[string] : TemporaryLeaderboard}
	local self : LeaderboardHandler = self

	local allTemporaryLeaderboards = if not self.promise then self:_filterAllLeaderboardsByClass("TemporaryLeaderboard") else self:_filterAllLeaderboardsByClass("TemporaryLeaderboard"):expect()

	return allTemporaryLeaderboards
end

function ProLeaderboards:_filterAllLeaderboardsByClass(className : string) : {[string] : TemporaryLeaderboard | ConstantLeaderboard}
	local self : LeaderboardHandler = self
	local filteredLeaderboards = {}

	for leaderboardName : string, leaderboard : TemporaryLeaderboard | ConstantLeaderboard in pairs(self.leaderboards) do
		if leaderboard.classType == className then
			filteredLeaderboards[leaderboardName] = leaderboard
		end
	end

	return filteredLeaderboards
end


function ProLeaderboards:getRegionByUserId(userId : string)
	local self : LeaderboardHandler = self
	
	if not self.regionalDataManager then
		return
	end

	userId = tostring(userId)

	return self.regionalDataManager:getRegionByUserId(userId)
end


return ProLeaderboards

--stylua: ignore end
