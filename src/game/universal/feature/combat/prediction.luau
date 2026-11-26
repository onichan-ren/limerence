local prediction = {}

prediction.effectiveMinDamage = LPH_NO_VIRTUALIZE(function(minDamageSetting: number, targetHealth: number): number
	if minDamageSetting > 100 then
		return targetHealth + (minDamageSetting - 100)
	end
	return minDamageSetting
end)

return prediction
