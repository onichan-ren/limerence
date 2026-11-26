local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local ModuleController = require("@game/ar2/module/ModuleController")
local hook = require("@share/hook")

local NoStagger = {}
NoStagger.__index = NoStagger

setmetatable(NoStagger, { __index = BaseFeature })

function NoStagger.new(link: gameUi.Linker): NoStagger
	local self = BaseFeature.new() :: any
	setmetatable(self, NoStagger)

	self._fn = nil :: ((...any) -> any)?

	link:Toggle("noStagger", "No Stagger", false):SetTip({
		title = "No Stagger",
		body = "Stops you from getting staggered, so you keep control when hit.",
	})

	self:Track(link:Get("noStagger"):OnChange(function(value: boolean): ()
		if value then
			self:Enable()
		else
			self:Disable()
		end
	end))

	if link:Peek("noStagger") then
		self:Enable()
	end

	return self
end

function NoStagger.Enable(self: NoStagger): ()
	if self._fn then
		return
	end

	local animators = ModuleController.GetModule("Animators")
	local localPlayer = ModuleController.GetModule("LocalPlayer")
	if not animators or not localPlayer then
		return
	end

	local runActionFn = rawget(animators.module, "RunAction")
	if type(runActionFn) ~= "function" then
		return
	end

	local getLocal = localPlayer.module.get

	local original
	original = hook.add(
		runActionFn,
		LPH_NO_VIRTUALIZE(function(animator: any, action: any, ...): ...any
			if action == "Stagger" then
				local arLocalPlayer = getLocal()
				if arLocalPlayer and arLocalPlayer.Character and animator == arLocalPlayer.Character.Animator then
					return
				end
			end
			return original(animator, action, ...)
		end)
	)

	self._fn = runActionFn
end

function NoStagger.Disable(self: NoStagger): ()
	if not self._fn then
		return
	end
	hook.restore(self._fn)
	self._fn = nil
end

function NoStagger.Destroy(self: NoStagger): ()
	self:Disable()
	BaseFeature.Destroy(self)
end

export type NoStagger =
	typeof(setmetatable(
		{} :: {
			_fn: ((...any) -> any)?,
		},
		NoStagger
	))
	& BaseFeature.BaseFeature

return NoStagger
