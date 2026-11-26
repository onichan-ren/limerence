local ModuleController = require("@game/ar2/module/ModuleController")
local hook = require("@share/hook")

export type StepCallbacks = {
	pre: ((animator: any, localPlayer: any) -> ())?,
	post: ((animator: any, localPlayer: any) -> ())?,
}

local AnimatorHook = {}

local subscribers: { [{}]: StepCallbacks } = {}
local installed = false
local original: ((...any) -> any)?
local localPlayerModule: any

local runCallbacks = LPH_NO_VIRTUALIZE(function(which: string, animator: any, localPlayer: any): ()
	for _, callbacks in next, subscribers do
		local fn = (callbacks :: any)[which]
		if fn then
			fn(animator, localPlayer)
		end
	end
end)

local function install(): ()
	if installed then
		return
	end

	local animators = ModuleController.GetModule("Animators")
	local localPlayer = ModuleController.GetModule("LocalPlayer")

	if not animators or not localPlayer or not animators.protos.stepAnimator then
		return
	end

	localPlayerModule = localPlayer.module

	original = hook.add(
		animators.protos.stepAnimator,
		LPH_NO_VIRTUALIZE(function(animator: any, ...): ...any
			local orig = original :: (...any) -> any
			local arLocalPlayer = localPlayerModule.get()

			if arLocalPlayer and arLocalPlayer.Character and animator == arLocalPlayer.Character.Animator then
				runCallbacks("pre", animator, arLocalPlayer)
				local results = table.pack(orig(animator, ...))
				runCallbacks("post", animator, arLocalPlayer)
				return table.unpack(results, 1, results.n)
			end

			return orig(animator, ...)
		end)
	)
	installed = true
end

local function uninstall(): ()
	if not installed or next(subscribers) then
		return
	end

	local animators = ModuleController.GetModule("Animators")
	if animators and animators.protos.stepAnimator then
		hook.restore(animators.protos.stepAnimator)
	end

	installed = false
	original = nil
	localPlayerModule = nil
end

function AnimatorHook.subscribe(callbacks: StepCallbacks): () -> ()
	local token = {}
	subscribers[token] = callbacks
	install()

	return function(): ()
		if subscribers[token] == nil then
			return
		end
		subscribers[token] = nil
		uninstall()
	end
end

return AnimatorHook
