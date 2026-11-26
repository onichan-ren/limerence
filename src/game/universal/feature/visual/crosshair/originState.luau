local Charm = require("@pkg/Charm")

local at = Charm.atom
local peek = Charm.peek

local originState = {
	ragebotPart = at(nil :: BasePart?),
	ragebotAt = 0,
	muzzleProvider = nil :: (() -> BasePart?)?,
	thirdPersonProvider = nil :: (() -> BasePart?)?,
	muzzlePositionProvider = nil :: (() -> Vector3?)?,
	forceCenterProvider = nil :: (() -> boolean)?,
}

function originState.SetForceCenterProvider(fn: (() -> boolean)?): ()
	originState.forceCenterProvider = fn
end

function originState.ShouldForceCenter(): boolean
	local fn = originState.forceCenterProvider
	return fn ~= nil and fn() == true
end

function originState.SetMuzzleProvider(fn: (() -> BasePart?)?): ()
	originState.muzzleProvider = fn
end

function originState.SetMuzzlePositionProvider(fn: (() -> Vector3?)?): ()
	originState.muzzlePositionProvider = fn
end

function originState.GetMuzzlePosition(): Vector3?
	local fn = originState.muzzlePositionProvider
	return fn and fn() or nil
end

function originState.SetThirdPersonMuzzleProvider(fn: (() -> BasePart?)?): ()
	originState.thirdPersonProvider = fn
end

function originState.GetMuzzlePart(): BasePart?
	local tp = originState.thirdPersonProvider
	if tp then
		local part = tp()
		if part then
			return part
		end
	end
	local fn = originState.muzzleProvider
	return fn and fn() or nil
end

function originState.NotifyRagebotTarget(part: BasePart?): ()
	if peek(originState.ragebotPart) ~= part then
		originState.ragebotPart(part)
	end
	originState.ragebotAt = os.clock()
end

function originState.GetRagebotPart(maxAge: number): BasePart?
	if os.clock() - originState.ragebotAt > maxAge then
		return nil
	end
	return peek(originState.ragebotPart)
end

return originState
