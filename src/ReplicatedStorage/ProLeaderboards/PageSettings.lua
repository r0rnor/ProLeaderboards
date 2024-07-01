--stylua: ignore start

export type PageSettings = {
    ascending : boolean?,
	pageSize : number?,
	minValue : number?,
	maxValue : number?,
}

local PageSettings = {}
PageSettings.metaPageSettings = {
	__index = {
		ascending = false,
		pageSize = 100,
		minValue = 0,
	}
}

function PageSettings.new(pageSettings : PageSettings?) : PageSettings
    local self : PageSettings = setmetatable(pageSettings or {}, PageSettings.metaPageSettings)

    return self
end

function PageSettings:convertToArgument() : {number | boolean}
    local self : PageSettings = self

    return {self.ascending, self.pageSize, self.minValue, self.maxValue}
end

return PageSettings

--stylua: ignore end
