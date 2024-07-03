--stylua: ignore start

export type PageSettings = {
    ascending : boolean?,
	pageSize : number?,
	minValue : number?,
	maxValue : number?,
}

local PageSettings = {}
PageSettings.__index = PageSettings

function PageSettings.new(pageSettings : PageSettings?) : PageSettings
	pageSettings = pageSettings or {}

    local self : PageSettings = setmetatable(pageSettings, PageSettings)

	self.ascending = pageSettings.ascending or false
	self.pageSize = pageSettings.pageSize or 100
	self.minValue = pageSettings.minValue or 0
	self.maxValue = pageSettings.maxValue

    return self
end

function PageSettings:convertToArgument() : {number | boolean}
    local self : PageSettings = self

    return {self.ascending, self.pageSize, self.minValue, self.maxValue}
end

return PageSettings

--stylua: ignore end
