local formatPlayTime = {}

function formatPlayTime.format(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	if seconds >= 3600 then
		local h = math.floor(seconds / 3600)
		local m = math.floor((seconds % 3600) / 60)
		local s = seconds % 60
		return string.format("%d:%02d:%02d", h, m, s)
	end
	local m = math.floor(seconds / 60)
	local s = seconds % 60
	return string.format("%d:%02d", m, s)
end

return formatPlayTime
