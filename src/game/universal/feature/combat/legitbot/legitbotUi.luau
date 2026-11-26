local gameUi = require("@game/gameUi")

export type UiOpts = {
	targettingConditions: { string }?,
	defaultTargettingConditions: { string }?,
	showBlindThreshold: boolean?,
	showSmokeThreshold: boolean?,
	hitboxes: { string }?,
	defaultHitboxes: { string }?,
	showTrigger: boolean?,
	showTriggerBullets: boolean?,
	showTriggerWaitForScope: boolean?,
	showTriggerWaitForScopeIgnoreCrossbow: boolean?,
	showTriggerWaitForAim: boolean?,
	showTriggerWaitForCharge: boolean?,
	showTriggerAvoidDeflecting: boolean?,
	showHitChance: boolean?,
	showMinDamage: boolean?,
	showAutowall: boolean?,
	showRcs: boolean?,
	showAimFirstBulletDelay: boolean?,
	showTriggerFirstBulletDelay: boolean?,
	showPrediction: boolean?,
	showBulletRedirection: boolean?,
	showManipulation: boolean?,
	showMaxDistance: boolean?,
	extraTargetting: ((link: gameUi.Linker) -> ())?,
	extraAim: ((link: gameUi.Linker) -> ())?,
	extraTrigger: ((link: gameUi.Linker) -> ())?,
	extraTriggerFilters: ((link: gameUi.Linker) -> ())?,
	extraRcs: ((link: gameUi.Linker) -> ())?,
	extraVisuals: ((link: gameUi.Linker) -> ())?,
}

local DEFAULT_HITBOXES: { string } = { "Head", "Torso", "Arms", "Legs", "Feet" }
local DEFAULT_DEFAULT_HITBOXES: { string } = { "Head", "Torso" }

return function(
	link: gameUi.Linker,
	targettingLink: gameUi.Linker,
	aimLink: gameUi.Linker,
	triggerLink: gameUi.Linker,
	rcsLink: gameUi.Linker?,
	visualsLink: gameUi.Linker,
	bulletRedirectionLink: gameUi.Linker,
	uiOpts: UiOpts?
): ()
	local opts = uiOpts or ({} :: UiOpts)
	local conditions = opts.targettingConditions or { "While Reloading", "While Out Of Ammo" }
	local hitboxes = opts.hitboxes or DEFAULT_HITBOXES
	local defaultHitboxes = opts.defaultHitboxes or DEFAULT_DEFAULT_HITBOXES
	local showTrigger = opts.showTrigger ~= false
	local showRcs = opts.showRcs ~= false
	local showAutowall = opts.showAutowall ~= false
	local showBlindThreshold = opts.showBlindThreshold ~= false
	local showSmokeThreshold = opts.showSmokeThreshold ~= false
	local showAimFirstBulletDelay = opts.showAimFirstBulletDelay ~= false
	local showTriggerFirstBulletDelay = opts.showTriggerFirstBulletDelay ~= false
	local showBulletRedirection = opts.showBulletRedirection ~= false
	local showHitChance = opts.showHitChance ~= false
	local showMinDamage = opts.showMinDamage ~= false

	link:Toggle("enabled", "Enable Legitbot", false):SetTip({
		title = "Enable Legitbot",
		body = "Turns on legitbot aim, trigger, and related options below.",
	})

	if #conditions > 0 then
		local conditionsHasWhileBlind = false
		local conditionsHasThroughSmokes = false
		for _, name in next, conditions do
			if name == "While Blind" then
				conditionsHasWhileBlind = true
			elseif name == "Through Smokes" then
				conditionsHasThroughSmokes = true
			end
		end

		targettingLink
			:Dropdown("conditions", "Conditions", conditions, opts.defaultTargettingConditions)
			:SetMode("multi")
			:SetTip({
				title = "Conditions",
				body = "Extra requirements before legitbot can target anyone.",
			})

		local targetConditionsLink = targettingLink:OnKey("conditions")
		local needsOptsSubmenu = showBlindThreshold and conditionsHasWhileBlind
			or showSmokeThreshold and conditionsHasThroughSmokes
		if needsOptsSubmenu then
			targetConditionsLink:Submenu("opts", "Condition Limits")
			local targetConditionsOptsLink = targetConditionsLink:OnKey("opts")
			if showBlindThreshold and conditionsHasWhileBlind then
				targetConditionsOptsLink:Slider("blindThreshold", "Blind Limit", 50, 0, 100, 1, nil, "%"):SetTip({
					title = "Blind Limit",
					body = "Maximum flashbang visibility (lower = stricter). Targets above this are ignored when While Blind is enabled.",
				})
			end
			if showSmokeThreshold and conditionsHasThroughSmokes then
				targetConditionsOptsLink:Slider("smokeThreshold", "Smoke Limit", 50, 0, 100, 1, nil, "%"):SetTip({
					title = "Smoke Limit",
					body = "Maximum smoke visibility (lower = stricter). Targets above this are ignored when Through Smokes is enabled.",
				})
			end
		end
	end

	targettingLink:Options("selection", "Target Selection")
	local targetSelectionLink = targettingLink:OnKey("selection")
	targetSelectionLink:Dropdown("hitboxes", "Hitboxes", hitboxes, defaultHitboxes):SetMode("multi"):SetMin(1):SetTip({
		title = "Hitboxes",
		body = "Body parts the aimbot is allowed to lock onto.",
	})
	targetSelectionLink:Slider("reactionTime", "Reaction Time", 130, 0, 500, 1, nil, "ms"):SetTip({
		title = "Reaction Time",
		body = "How long a target must stay inside your aim FOV before the aimbot starts helping.",
	})
	local switchDelaySlider =
		targetSelectionLink:Slider("switchDelay", "Switch Delay", 90, 0, 500, 1, nil, "ms"):SetTip({
			title = "Switch Delay",
			body = "Delay before switching from one locked target to another.",
		})
	targetSelectionLink:Toggle("stickyTarget", "Sticky Target", false):SetTip({
		title = "Sticky Target",
		body = "Keeps the same target until it dies or you turn this off, instead of switching to closer enemies.",
	})
	local function updateStickyDisabled(v: any): ()
		switchDelaySlider:SetDisabled(v == true)
	end
	updateStickyDisabled(targetSelectionLink:Peek("stickyTarget"))
	targetSelectionLink:Watch("stickyTarget", updateStickyDisabled)

	if opts.extraTargetting then
		opts.extraTargetting(targettingLink)
	end

	if showTrigger then
		triggerLink:Toggle("enabled", "Enable Triggerbot", false):SetTip({
			title = "Enable Triggerbot",
			body = "Automatically shoots when an enemy is in your trigger FOV.",
		})

		triggerLink:Options("engagement", "Engagement")
		local triggerEngagementLink = triggerLink:OnKey("engagement")
		if showTriggerFirstBulletDelay then
			triggerEngagementLink
				:Slider("firstBulletDelay", "First Bullet Delay", 0, 0, 500, 1, nil, "ms")
				:SetValueTextOverrides({ [0] = "Off" })
				:SetTip({
					title = "First Bullet Delay",
					body = "Holds the Triggerbot until you manually fire a shot at the target first, then waits this delay before taking over the rest of the burst. Set to Off to disable.",
				})
		end
		triggerEngagementLink:Slider("shotDelay", "Shot Delay", 130, 0, 500, 1, nil, "ms"):SetTip({
			title = "Shot Delay",
			body = "How long a target must stay inside trigger FOV before a shot is fired.",
		})
		triggerEngagementLink
			:Slider("resetDelay", "Reset Delay", 95, 0, 500, 1, nil, "ms")
			:SetValueTextOverrides({ [0] = "Off" })
			:SetTip({
				title = "Reset Delay",
				body = "After an engagement ends (target leaves FOV or bullet limit is reached), wait this long before the Triggerbot may start a new engagement.",
			})
		if opts.showTriggerBullets ~= false then
			triggerEngagementLink
				:Slider("bullets", "Bullets", 30, 0, 30, 1, nil, "x")
				:SetValueTextOverrides({ [0] = "Off" })
				:SetTip({
					title = "Bullets",
					body = "The number of bullets the Triggerbot fires per engagement before stopping. Set to Off to keep firing while on target.",
				})
		end

		triggerLink:Options("targeting", "Targeting")
		local triggerTargetingLink = triggerLink:OnKey("targeting")
		triggerTargetingLink
			:Dropdown("hitboxes", "Hitboxes", hitboxes, defaultHitboxes)
			:SetMode("multi")
			:SetMin(1)
			:SetTip({
				title = "Hitboxes",
				body = "Body parts the triggerbot is allowed to fire at.",
			})
		triggerTargetingLink:Slider("fov", "Field of View", 2, 0, 30, 1, nil, "°"):SetTip({
			title = "Field of View",
			body = "Size of the area around your crosshair where triggerbot can shoot.",
		})
		triggerTargetingLink:Dropdown("mode", "Mode", { "FOV", "On Hitbox" }, "FOV"):SetTip({
			title = "Mode",
			body = "FOV shoots any valid enemy inside the circle. On Hitbox only shoots when your crosshair is on their body.",
		})

		triggerLink:Options("filters", "Filters")
		local triggerFiltersLink = triggerLink:OnKey("filters")
		if opts.extraTriggerFilters then
			opts.extraTriggerFilters(triggerFiltersLink)
		end
		if showHitChance then
			triggerFiltersLink:Slider("hitChance", "Hit Chance", 65, 0, 100, 1, nil, "%"):SetTip({
				title = "Hit Chance",
				body = "Minimum estimated chance to hit before triggerbot fires.",
			})
		end
		local minDamageOverrides: { [number]: string } = { [0] = "Off" }
		for i = 1, 10 do
			minDamageOverrides[100 + i] = "+" .. tostring(i)
		end
		if showMinDamage then
			triggerFiltersLink
				:Slider("minDamage", "Minimum Damage", 0, 0, 110, 1, nil, "hp")
				:SetValueTextOverrides(minDamageOverrides)
				:SetTip({
					title = "Minimum Damage",
					body = "For direct shots (no wallbang). Estimates the damage the next bullet will deal. Values above 100 require lethal: 101 = target HP + 1, 110 = target HP + 10. Set to Off to disable.",
				})
		end
		if opts.showTriggerAvoidDeflecting then
			triggerFiltersLink:Toggle("avoidDeflecting", "Avoid Deflecting", false):SetTip({
				title = "Avoid Deflecting",
				body = "Holds fire while the target is deflecting toward you, so shots are not reflected back.",
			})
		end
		if opts.showTriggerWaitForCharge then
			triggerFiltersLink:Toggle("waitForCharge", "Wait For Charge", true):SetTip({
				title = "Wait For Charge",
				body = "For charge weapons (bow, crossbow): hold the draw and only release once it reaches the set charge.",
			})
			local waitForChargeLink = triggerFiltersLink:OnKey("waitForCharge")
			waitForChargeLink:Submenu("opts", "Wait For Charge")
			waitForChargeLink:OnKey("opts"):Slider("charge", "Charge", 100, 1, 100, 1, nil, "%"):SetTip({
				title = "Charge",
				body = "Minimum charge before the shot is released. 100% waits for a full draw.",
			})
		end
		if opts.showTriggerWaitForScope then
			triggerFiltersLink:Toggle("waitForScope", "Wait For Scope", true):SetTip({
				title = "Wait For Scope",
				body = "Only let the triggerbot fire while you are scoped in with a scoped weapon (e.g. sniper).",
			})
			if opts.showTriggerWaitForScopeIgnoreCrossbow then
				local waitForScopeLink = triggerFiltersLink:OnKey("waitForScope")
				waitForScopeLink:Submenu("opts", "Wait For Scope")
				waitForScopeLink:OnKey("opts"):Toggle("ignoreCrossbow", "Ignore Crossbow", false):SetTip({
					title = "Ignore Crossbow",
					body = "Skip the scope wait while holding a crossbow, so it fires without scoping.",
				})
			end
		end
		if opts.showTriggerWaitForAim then
			triggerFiltersLink:Toggle("waitForAim", "Wait For Aim", false):SetTip({
				title = "Wait For Aim",
				body = "Only let the triggerbot fire while you are aiming down sights.",
			})
		end
		if showAutowall then
			triggerFiltersLink:Toggle("autowall", "Autowall", false):SetTip({
				title = "Autowall",
				body = "Allows the Triggerbot to shoot through penetrable walls.",
			})
			local autowallLink = triggerFiltersLink:OnKey("autowall")
			autowallLink:Submenu("opts", "Autowall")
			local autowallOptsLink = autowallLink:OnKey("opts")
			autowallOptsLink
				:Slider("minDamage", "Minimum Damage", 0, 0, 110, 1, nil, "hp")
				:SetValueTextOverrides(minDamageOverrides)
				:SetTip({
					title = "Minimum Damage",
					body = "For autowall shots only. Same scaling as Minimum Damage. Set to Off to skip the damage check on wallbangs.",
				})
		end

		triggerLink:Toggle("magnet", "Magnet", false):SetTip({
			title = "Magnet",
			body = "Moves your crosshair toward the target while they stay inside trigger FOV. Strength scales with how centered they are (Pull Strength curve).",
		})
		local magnetLink = triggerLink:OnKey("magnet")
		magnetLink:Submenu("opts", "Magnet")
		local magnetOptsLink = magnetLink:OnKey("opts")
		magnetOptsLink
			:CurveEditor("pullStrengthCurve", "Pull Strength", 1, 100, {
				{ x = 0, y = 0.1 },
				{ x = 0.45, y = 0.5 },
				{ x = 1, y = 1 },
			})
			:SetTip({
				title = "Pull Strength",
				body = "How hard the magnet pulls at each alignment inside trigger FOV. X is alignment (edge to center); Y is pull strength.",
			})
		magnetOptsLink:Slider("reactionTime", "Reaction Time", 130, 0, 500, 1, nil, "ms"):SetTip({
			title = "Reaction Time",
			body = "Time in milliseconds a target must stay inside the trigger FOV before the magnet may pull.",
		})

		if opts.extraTrigger then
			opts.extraTrigger(triggerLink)
		end
	end

	aimLink:Toggle("enabled", "Enable Aimbot", false):SetTip({
		title = "Enable Aimbot",
		body = "Smoothly moves your aim toward valid targets in FOV.",
	})

	aimLink:Options("humanization", "Humanization")
	local humanizationLink = aimLink:OnKey("humanization")

	humanizationLink:Toggle("overshoot", "Overshoot", false):SetTip({
		title = "Overshoot",
		body = "Slips slightly past a target when you flick onto it, then settles back, so snaps look less machine-perfect.",
	})
	local overshootLink = humanizationLink:OnKey("overshoot")
	overshootLink:Submenu("opts", "Overshoot")
	local overshootOptsLink = overshootLink:OnKey("opts")
	overshootOptsLink:Dropdown("feel", "Feel", { "Subtle", "Natural", "Heavy", "Custom" }, "Subtle"):SetTip({
		title = "Feel",
		body = "Preset overshoot style. Subtle barely slips; Heavy slips far and settles slower. Custom reveals the manual sliders.",
	})
	local overshootChance = overshootOptsLink:Slider("chance", "Chance", 50, 0, 100, 1, nil, "%"):SetTip({
		title = "Chance",
		body = "How often a fast flick slips past the target instead of landing clean.",
	})
	local overshootAmount = overshootOptsLink:Slider("amount", "Amount", 50, 0, 100, 1, nil, "%"):SetTip({
		title = "Amount",
		body = "How far past the target it slips. Also scales with how hard you flick.",
	})
	local overshootRecovery = overshootOptsLink:Slider("recovery", "Recovery", 50, 0, 100, 1, nil, "%"):SetTip({
		title = "Recovery",
		body = "How quickly it settles back onto the target after slipping past. Higher corrects faster.",
	})
	local overshootTrigger = overshootOptsLink:Slider("trigger", "Trigger", 50, 0, 100, 1, nil, "%"):SetTip({
		title = "Trigger",
		body = "How easily it triggers. Higher fires on gentler flicks; lower needs a hard flick.",
	})
	local function updateOvershootFeelVisibility(feel: any): ()
		local custom = feel == "Custom"
		overshootChance:SetVisible(custom)
		overshootAmount:SetVisible(custom)
		overshootRecovery:SetVisible(custom)
		overshootTrigger:SetVisible(custom)
	end
	updateOvershootFeelVisibility(overshootOptsLink:Peek("feel"))
	overshootOptsLink:Watch("feel", updateOvershootFeelVisibility)

	humanizationLink:Toggle("tracking", "Tracking", false):SetTip({
		title = "Tracking",
		body = "Adds reaction lag and a small aim deadzone so tracking reacts and settles like a real hand instead of following perfectly.",
	})
	local trackingLink = humanizationLink:OnKey("tracking")
	trackingLink:Submenu("opts", "Tracking")
	local trackingOptsLink = trackingLink:OnKey("opts")
	trackingOptsLink:Slider("reaction", "Reaction", 50, 0, 100, 1, nil, "%"):SetTip({
		title = "Reaction",
		body = "Delay before aim responds to a target changing direction. Steady movement stays smooth; higher reacts slower to sudden changes.",
	})
	trackingOptsLink:Slider("deadzone", "Deadzone", 100, 0, 100, 1, nil, "%"):SetTip({
		title = "Deadzone",
		body = "Ignores tiny aim errors near the target instead of constantly correcting them. Higher tolerates more before adjusting.",
	})

	aimLink:Options("engagement", "Engagement")
	local aimEngagementLink = aimLink:OnKey("engagement")
	aimEngagementLink:Dropdown("assistance", "Activation", { "Assisted", "Always On" }, "Always On"):SetTip({
		title = "Activation",
		body = "Assisted only pulls after you recently moved the mouse. Always On pulls whenever a target is in FOV, without needing movement.",
	})
	if showAimFirstBulletDelay then
		aimEngagementLink
			:Slider("firstBulletDelay", "First Bullet Delay", 0, 0, 500, 1, nil, "ms")
			:SetValueTextOverrides({ [0] = "Off" })
			:SetTip({
				title = "First Bullet Delay",
				body = "Holds aim assist until you manually fire a shot at the target first, then waits this delay before pulling. Set to Off to disable.",
			})
	end
	if opts.showPrediction then
		aimEngagementLink:Toggle("prediction", "Prediction", true):SetTip({
			title = "Prediction",
			body = "Leads moving targets and accounts for bullet travel so your aim lands where the shot will connect.",
		})
		local predictionLink = aimEngagementLink:OnKey("prediction")
		predictionLink:Submenu("opts", "Prediction")
		local predictionOptsLink = predictionLink:OnKey("opts")
		predictionOptsLink:Toggle("movementCompensation", "Movement Compensation", true):SetTip({
			title = "Movement Compensation",
			body = "Leads the target based on how fast they are moving.",
		})
		predictionOptsLink:Toggle("bulletCompensation", "Bullet Compensation", true):SetTip({
			title = "Bullet Compensation",
			body = "Aims to counter bullet drop and travel time over distance.",
		})
	end

	aimLink:Options("smoothing", "Aim Curves")
	local smoothingLink = aimLink:OnKey("smoothing")
	smoothingLink:Slider("sensitivity", "Sensitivity", 70, 0, 100, 1, nil, "%"):SetTip({
		title = "Sensitivity",
		body = "Overall strength of aim assist. Works together with the Smoothing curve.",
	})
	smoothingLink
		:CurveEditor("smoothingCurve", "Smoothing", 1, 100, {
			{ x = 0, y = 0.466 },
			{ x = 0.344, y = 0.557 },
			{ x = 0.462, y = 0.489 },
			{ x = 0.665, y = 0.455 },
			{ x = 0.892, y = 0.227 },
			{ x = 0.953, y = 0.159 },
			{ x = 1, y = 0.102 },
		})
		:SetTip({
			title = "Smoothing",
			body = "Scales aim pull over time. X is progress toward the target; Y is how much smoothing to apply — top is super smooth, bottom is no smoothing (instant pull).",
		})

	aimLink:Options("targeting", "Targeting")
	local aimTargetingLink = aimLink:OnKey("targeting")
	aimTargetingLink:Slider("fov", "Field of View", 20, 0, 180, 1, nil, "°"):SetTip({
		title = "Field of View",
		body = "How wide the aim assist search area is. Triggerbot has its own FOV setting.",
	})
	aimTargetingLink:Toggle("closestPoint", "Closest Point", true):SetTip({
		title = "Closest Point",
		body = "Holds aim at the nearest edge of the target instead of the center, so you can move freely across them.",
	})

	if opts.extraAim then
		opts.extraAim(aimLink)
	end

	if showRcs then
		rcsLink:Toggle("enabled", "Enable", false):SetTip({
			title = "Enable",
			body = "Pulls your aim down while shooting to counter weapon recoil.",
		})
		rcsLink:Toggle("verticalOnly", "Vertical Only", false):SetTip({
			title = "Vertical Only",
			body = "Only counters up/down recoil, not left/right.",
		})
		rcsLink:Slider("strength", "Strength", 100, 0, 150, 1, nil, "%"):SetTip({
			title = "Strength",
			body = "How strongly the Recoil Control System counters weapon recoil while shooting.",
		})

		if opts.extraRcs then
			opts.extraRcs(rcsLink)
		end
	end

	if showBulletRedirection then
		bulletRedirectionLink:Toggle("enabled", "Enable Redirection", false):SetTip({
			title = "Enable Redirection",
			body = "Redirects your bullets towards the enemy.",
		})

		bulletRedirectionLink:Slider("fov", "Field of View", 30, 0, 180, 1, nil, "°"):SetTip({
			title = "Field of View",
			body = "How wide the bullet redirection search area is.",
		})
		bulletRedirectionLink:Slider("chance", "Redirect Chance", 100, 0, 100, 1, nil, "%"):SetTip({
			title = "Redirect Chance",
			body = "Percent of your shots that get redirected to the target. Lower values let some bullets fly where you actually aimed.",
		})
		if showAutowall then
			bulletRedirectionLink:Toggle("autowall", "Autowall", false):SetTip({
				title = "Autowall",
				body = "Allows bullet redirection to lock targets through penetrable walls.",
			})
		end

		bulletRedirectionLink
			:Dropdown("hitboxes", "Hitboxes", hitboxes, defaultHitboxes)
			:SetMode("multi")
			:SetMin(1)
			:SetTip({
				title = "Hitboxes",
				body = "Body parts the bullets can redirect to.",
			})

		if opts.showManipulation then
			bulletRedirectionLink:Toggle("manipulation", "Manipulation", false):SetTip({
				title = "Manipulation",
				body = "Experimental: shifts where shots start from to clear walls or floors, keeping your aim point.",
			})
		end
	end

	visualsLink:Toggle("fieldOfView", "Field of View", false):SetTip({
		title = "Field of View",
		body = "Draws circles on screen showing aim and trigger range. Does not change how targeting works.",
	})
	local fieldOfViewLink = visualsLink:OnKey("fieldOfView")
	fieldOfViewLink:Submenu("opts", "Field of View")
	local fovOptsLink = fieldOfViewLink:OnKey("opts")
	fovOptsLink:Toggle("aim", "Aim Assist", true):SetTip({
		title = "Aim Assist",
		body = "Shows the aimbot FOV circle while Field of View visuals are enabled.",
	})
	local fovAimLink = fovOptsLink:OnKey("aim")
	fovAimLink:Submenu("opts", "Aim Assist")
	local aimOptsLink = fovAimLink:OnKey("opts")
	aimOptsLink
		:Colorpicker(
			"outlineColor",
			"Outline Color",
			ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 255, 144)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 247, 255)),
			}),
			0
		)
		:SetTip({
			title = "Outline Color",
			body = "Border color of the aim assist FOV circle.",
		})
	aimOptsLink
		:Colorpicker(
			"color",
			"Fill Color",
			ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(9, 255, 181)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(184, 246, 255)),
			}),
			0.5
		)
		:SetTip({
			title = "Fill Color",
			body = "Fill color of the aim assist FOV circle.",
		})

	if showTrigger then
		fovOptsLink:Toggle("triggerbot", "Triggerbot", true):SetTip({
			title = "Triggerbot",
			body = "Shows the triggerbot FOV circle. Uses the separate trigger FOV slider, not aim FOV.",
		})
		local triggerbotAimLink = fovOptsLink:OnKey("triggerbot")
		triggerbotAimLink:Submenu("opts", "Triggerbot")
		local triggerbotOptsLink = triggerbotAimLink:OnKey("opts")
		triggerbotOptsLink
			:Colorpicker("outlineColor", "Outline Color", ColorSequence.new(Color3.fromRGB(255, 85, 88)), 0)
			:SetTip({
				title = "Outline Color",
				body = "Border color of the triggerbot FOV circle.",
			})
		triggerbotOptsLink
			:Colorpicker("color", "Fill Color", ColorSequence.new(Color3.fromRGB(255, 85, 88)), 0.5)
			:SetTip({
				title = "Fill Color",
				body = "Fill color of the triggerbot FOV circle.",
			})
	end

	if showBulletRedirection then
		fovOptsLink:Toggle("bulletRedirection", "Bullet Redirection", true):SetTip({
			title = "Bullet Redirection",
			body = "Shows the bullet redirection FOV circle. Uses the separate bullet redirection FOV slider, not aim FOV.",
		})
		local bulletRedirectionAimLink = fovOptsLink:OnKey("bulletRedirection")
		bulletRedirectionAimLink:Submenu("opts", "Bullet Redirection")
		local bulletRedirectionOptsLink = bulletRedirectionAimLink:OnKey("opts")
		bulletRedirectionOptsLink
			:Colorpicker("outlineColor", "Outline Color", ColorSequence.new(Color3.fromRGB(111, 0, 255)), 0)
			:SetTip({
				title = "Outline Color",
				body = "Border color of the bullet redirection FOV circle.",
			})
		bulletRedirectionOptsLink
			:Colorpicker("color", "Fill Color", ColorSequence.new(Color3.fromRGB(111, 0, 255)), 0.5)
			:SetTip({
				title = "Fill Color",
				body = "Fill color of the bullet redirection FOV circle.",
			})
	end

	if opts.extraVisuals then
		opts.extraVisuals(visualsLink)
	end
end
