local Charm = require("@pkg/Charm")

local peek = Charm.peek

export type ResultElement = any

export type Result = {
	tabGroup: any,
	tab: any,
	section: any,
	submenu: any?,
	submenuTitle: string?,
	elements: { ResultElement },
}

local searchUtil = {}

local lowerContains = LPH_NO_VIRTUALIZE(function(haystack: string?, needleLower: string): boolean
	if not haystack or haystack == "" then
		return false
	end
	if needleLower == "" then
		return true
	end
	return string.find(string.lower(haystack), needleLower, 1, true) ~= nil
end)

type WalkContext = {
	q: string,
	tabGroup: any,
	tab: any,
	section: any,
	results: { Result },
}

local extraMatches = LPH_NO_VIRTUALIZE(function(element: any, q: string): boolean
	if not element._extras then
		return false
	end
	local extras = peek(element._extras)
	for _, extra in next, extras do
		if lowerContains(peek(extra._text), q) then
			return true
		end
	end
	return false
end)

local function recurseInto(elements: { any }, ctx: WalkContext, currentSubmenu: any?, currentTitle: string?): ()
	local matched: { any } = {}
	for _, element in next, elements do
		local elText = peek(element._text)
		if not element._searchHidden and (lowerContains(elText, ctx.q) or extraMatches(element, ctx.q)) then
			table.insert(matched, element)
		end

		if element._elements then
			recurseInto(peek(element._elements), ctx, element, elText)
		end
		if element._extras then
			for _, extra in next, peek(element._extras) do
				if extra._elements then
					recurseInto(peek(extra._elements), ctx, extra, peek(extra._text))
				end
			end
		end
	end
	if #matched > 0 then
		table.insert(ctx.results, {
			tabGroup = ctx.tabGroup,
			tab = ctx.tab,
			section = ctx.section,
			submenu = currentSubmenu,
			submenuTitle = currentTitle,
			elements = matched,
		})
	end
end

local function walkTab(tabGroup: any, tab: any, tabMatch: boolean, q: string, results: { Result }): ()
	local containers = peek(tab._containers)
	for _, container in next, containers do
		local sections = peek(container._sections)
		for _, section in next, sections do
			local sectionMatch = tabMatch or lowerContains(section._title, q)
			if sectionMatch then
				local elements = peek(section._elements)
				local included: { any } = {}
				for _, element in next, elements do
					if not element._searchHidden then
						table.insert(included, element)
					end
				end
				if #included > 0 then
					table.insert(results, {
						tabGroup = tabGroup,
						tab = tab,
						section = section,
						submenu = nil,
						submenuTitle = nil,
						elements = included,
					})
				end
			else
				local ctx: WalkContext = {
					q = q,
					tabGroup = tabGroup,
					tab = tab,
					section = section,
					results = results,
				}
				recurseInto(peek(section._elements), ctx, nil, nil)
			end
		end
	end
end

searchUtil.walk = LPH_NO_VIRTUALIZE(function(window: any, query: string): { Result }
	local q = string.lower(query)
	local results: { Result } = {}

	local tabGroups = peek(window._tabGroups)
	for _, tabGroup in next, tabGroups do
		local groupMatch = lowerContains(tabGroup.title, q)
		local tabs = peek(tabGroup.tabs)
		for _, tab in next, tabs do
			local tabMatch = groupMatch or lowerContains(tab.title, q)
			walkTab(tabGroup, tab, tabMatch, q, results)
			for _, subtab in next, peek(tab._subtabs) do
				walkTab(tabGroup, subtab, tabMatch or lowerContains(subtab.title, q), q, results)
			end
		end
	end

	return results
end)

return searchUtil
