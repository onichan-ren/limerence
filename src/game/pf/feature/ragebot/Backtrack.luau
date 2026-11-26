return LPH_JIT_MAX(function()
	local RunService = cloneref(game:GetService("RunService")) :: RunService
	local Workspace = cloneref(game:GetService("Workspace")) :: Workspace

	local PlayerController = require("@feature/player/PlayerController")
	local SessionController = require("@feature/session/SessionController")
	local ModuleController = require("@game/pf/module/ModuleController")
	local BaseFeature = require("@game/BaseFeature")
	local gameUi = require("@game/gameUi")
	local instances = require("@share/instances")
	local hook = require("@share/hook")
	local backtrackHit = require("@game/pf/feature/ragebot/backtrackHit")
	local Charm = require("@pkg/Charm")
	local React = require("@pkg/React")

	local peek = Charm.peek
	local sub = Charm.subscribe
	local subscribeToBinding = (React :: any).__subscribeToBinding

	local SNAPSHOT_INTERVAL = 1 / 9999
	local MAX_DELAY_SEC = 0.5
	local BUFFER_COMPACT_AT = 48
	local STILL_THRESHOLD = 0.05
	local DEFAULT_GHOST_COLOR = Color3.fromRGB(93, 231, 190)
	local GHOST_PART_TRANSPARENCY = 0.5
	local GHOST_MATERIAL = Enum.Material.Neon
	local GLOW_SCALE = 5
	local GLOW_SIZE_OFFSET = Vector3.new(0.03, 0.03, 0.03)
	local HITBOX_SIZE = Vector3.new(4, 5, 1)

	type Snapshot = {
		time: number,
		gameTime: number,
		cframes: { [string]: CFrame },
	}

	type Track = {
		bp: any,
		buffer: { Snapshot },
		pool: { Snapshot },
		bufferStart: number,
		lastSnap: number,
		ghost: Model?,
		ghostParts: { [string]: BasePart },
		hitbox: BasePart?,
		adorns: { [BasePart]: HandleAdornment },
		charUnsub: () -> (),
		aliveUnsub: () -> (),
		lastCharacter: Model?,
		ghostVisible: boolean?,
		historyValid: boolean,
		historyGameTime: number,
	}

	local Backtrack = {}
	Backtrack.__index = Backtrack
	setmetatable(Backtrack, { __index = BaseFeature })

	local _instance: any = nil

	local function reclaimSnapshot(track: Track, snap: Snapshot): ()
		table.clear(snap.cframes)
		local pool = track.pool
		pool[#pool + 1] = snap
	end

	local function acquireSnapshot(track: Track, now: number, gameTime: number): Snapshot
		local pool = track.pool
		local n = #pool
		if n > 0 then
			local snap = pool[n]
			pool[n] = nil
			snap.time = now
			snap.gameTime = gameTime
			return snap
		end
		return { time = now, gameTime = gameTime, cframes = {} }
	end

	local compactBuffer = LPH_NO_VIRTUALIZE(function(track: Track): ()
		local buffer = track.buffer
		local start = track.bufferStart
		if start <= 1 then
			return
		end
		local n = #buffer
		local newLen = n - start + 1
		if newLen <= 0 then
			table.clear(buffer)
			track.bufferStart = 1
			return
		end
		for i = 1, newLen do
			buffer[i] = buffer[start + i - 1]
		end
		for i = newLen + 1, n do
			buffer[i] = nil
		end
		track.bufferStart = 1
	end)

	local getHistoricalSnapshot = LPH_NO_VIRTUALIZE(
		function(buffer: { Snapshot }, startIdx: number, delay: number, now: number): Snapshot?
			local n = #buffer
			if n < startIdx then
				return nil
			end
			local target = now - delay
			if buffer[n].time <= target then
				return buffer[n]
			end
			if buffer[startIdx].time >= target then
				return buffer[startIdx]
			end
			local lo, hi = startIdx, n
			while lo + 1 < hi do
				local mid = math.floor((lo + hi) / 2)
				if buffer[mid].time < target then
					lo = mid
				else
					hi = mid
				end
			end
			if math.abs(buffer[lo].time - target) <= math.abs(buffer[hi].time - target) then
				return buffer[lo]
			end
			return buffer[hi]
		end
	)

	function Backtrack.new(link: gameUi.Linker): Backtrack
		local self = BaseFeature.new() :: any
		setmetatable(self, Backtrack)

		self._tracks = {} :: { [Player]: Track }
		self._folder = instances.new("Folder", { Secure = true }, Workspace) :: Folder
		self._enabled = false
		self._heartbeat = nil :: RBXScriptConnection?
		self._addedConn = nil :: RBXScriptConnection?
		self._removingConn = nil :: RBXScriptConnection?
		self._ghostColor = DEFAULT_GHOST_COLOR
		self._gameClock = nil :: any

		local mainToggle = link:Toggle("backtrack", "Backtrack", false):SetTip({
			title = "Backtrack",
			body = "Lets you hit enemies where they were a short time ago.",
		})
		link:Extra(mainToggle, "backtrackOpts", "Submenu", "Backtrack Options")
		local opts = link:OnKey("backtrackOpts")
		self._opts = opts
		self._delayEl = nil :: any
		self._visualEl = nil :: any

		opts:Slider("delay", "Delay", 200, 0, 500, 10, nil, "ms")
			:SetTip({
				title = "Delay",
				body = "How far back in time enemy positions are saved. Set to 0 to match your ping automatically.",
			})
			:SetValueTextOverrides({ [0] = "Auto" })
		opts:Toggle("visual", "Show Ghost", true):SetTip({
			title = "Show Ghost",
			body = "Shows a faded copy of the enemy at their backtracked position.",
		})
		opts:Toggle("behindWalls", "Behind Walls", false):SetTip({
			title = "Behind Walls",
			body = "Shows the ghost through walls.",
		})
		opts:Colorpicker("color", "Ghost Color", DEFAULT_GHOST_COLOR, 0):SetTip({
			title = "Ghost Color",
			body = "Color of the backtrack ghost.",
		})

		self._delayEl = opts:Get("delay")
		self._visualEl = opts:Get("visual")
		self._cachedDelay = self._delayEl:Peek() or 200
		self._cachedVisual = self._visualEl:Peek() == true
		self:Track(sub(self._delayEl._state, function(v: number): ()
			self._cachedDelay = v
		end))
		self:Track(sub(self._visualEl._state, function(v: boolean): ()
			self._cachedVisual = v
		end))

		self:Track(link:Get("backtrack"):OnChange(function(v: boolean): ()
			if v then
				self:_enable()
			else
				self:_disable()
			end
		end))
		local colorEl = opts:Get("color")
		local function applyGhostColor(value: Color3): ()
			self._ghostColor = value
			self:_refreshGhostColor()
		end
		applyGhostColor((colorEl._currentColor :: any):getValue())
		self:Track(subscribeToBinding(colorEl._currentColor, applyGhostColor))

		self._behindWalls = opts:Get("behindWalls"):Peek() == true
		self:Track(opts:Get("behindWalls"):OnChange(function(v: boolean): ()
			self:_setBehindWalls(v)
		end))

		_instance = self

		if link:Peek("backtrack") then
			self:_enable()
		end

		return self
	end

	function Backtrack._clock(self: Backtrack): any
		local c = self._gameClock
		if not c then
			c = ModuleController.GetModule("GameClock")
			self._gameClock = c
		end
		return c
	end

	function Backtrack._enable(self: Backtrack): ()
		if self._enabled then
			return
		end
		self._enabled = true

		self._addedConn = PlayerController.playerAdded:Connect(function(bp: any): ()
			self:_bindPlayer(bp)
		end) :: any
		self._removingConn = PlayerController.playerRemoving:Connect(function(bp: any): ()
			self:_unbindPlayer(bp:GetPlayer())
		end) :: any

		for _, bp in next, PlayerController.GetAll() do
			self:_bindPlayer(bp)
		end

		self._heartbeat = RunService.Heartbeat:Connect(LPH_NO_VIRTUALIZE(function(): ()
			self:_tick()
		end))

		backtrackHit.enable({
			getTracks = function(): any
				return self._tracks
			end,
			folder = self._folder,
		})
	end

	function Backtrack._disable(self: Backtrack): ()
		if not self._enabled then
			return
		end
		self._enabled = false

		backtrackHit.disable()

		if self._heartbeat then
			self._heartbeat:Disconnect()
			self._heartbeat = nil
		end
		if self._addedConn then
			self._addedConn:Disconnect()
			self._addedConn = nil
		end
		if self._removingConn then
			self._removingConn:Disconnect()
			self._removingConn = nil
		end

		for player in next, self._tracks do
			self:_unbindPlayer(player)
		end
	end

	function Backtrack._bindPlayer(self: Backtrack, bp: any): ()
		local player: Player = bp:GetPlayer()
		if self._tracks[player] then
			return
		end

		local track: Track = {
			bp = bp,
			buffer = {},
			pool = {},
			bufferStart = 1,
			lastSnap = 0,
			ghost = nil,
			ghostParts = {},
			hitbox = nil,
			adorns = {},
			charUnsub = function() end,
			aliveUnsub = function() end,
			lastCharacter = nil,
			ghostVisible = nil,
			historyValid = false,
			historyGameTime = 0,
		}
		self._tracks[player] = track

		track.charUnsub = sub(bp.character, function(character: any): ()
			if character == track.lastCharacter then
				return
			end
			track.lastCharacter = character
			self:_destroyGhost(track)
			table.clear(track.buffer)
			track.bufferStart = 1
			track.lastSnap = 0
			track.historyValid = false
		end)

		track.aliveUnsub = sub(bp.alive, function(alive: boolean): ()
			if not alive then
				table.clear(track.buffer)
				track.bufferStart = 1
				track.lastSnap = 0
				track.historyValid = false
				self:_setTrackVisible(track, false)
			end
		end)

		track.lastCharacter = peek(bp.character)
	end

	function Backtrack._unbindPlayer(self: Backtrack, player: Player): ()
		local track = self._tracks[player]
		if not track then
			return
		end
		track.charUnsub()
		track.aliveUnsub()
		self:_destroyGhost(track)
		self._tracks[player] = nil
	end

	function Backtrack._createGhost(self: Backtrack, parts: { [string]: any }, track: Track): ()
		local model = instances.new("Model", { Secure = true }, self._folder) :: Model
		local ghostParts: { [string]: BasePart } = {}

		for name, part in next, parts do
			if not part:IsA("BasePart") then
				continue
			end

			local clone = part:Clone() :: BasePart
			for _, c in next, clone:GetChildren() do
				if c:IsA("SpecialMesh") then
					c.TextureId = ""
				else
					c:Destroy()
				end
			end
			if clone:IsA("MeshPart") then
				clone.TextureID = ""
			end

			clone.Anchored = true
			clone.CanCollide = false
			clone.CanQuery = false
			clone.CanTouch = false
			clone.CastShadow = false
			clone.Transparency = 1
			clone.Material = GHOST_MATERIAL
			clone.Color = self._ghostColor
			clone.Parent = model
			ghostParts[name] = clone

			if self._behindWalls then
				track.adorns[clone] = self:_createAdorn(clone)
			end
		end

		local hitbox = instances.new("Part", {
			Anchored = true,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			CastShadow = false,
			Transparency = 1,
			Size = HITBOX_SIZE,
			Material = Enum.Material.SmoothPlastic,
			Secure = true,
		}, model) :: BasePart

		hook.addInstance(hitbox)
		hook.spoofProperty(hitbox, "CanCollide", true)
		hook.spoofProperty(hitbox, "Transparency", 0)

		track.ghost = model
		track.ghostParts = ghostParts
		track.hitbox = hitbox
		track.ghostVisible = nil
	end

	function Backtrack._createAdorn(self: Backtrack, part: BasePart): HandleAdornment
		local color = self._ghostColor
		local glowColor = Color3.new(color.R * GLOW_SCALE, color.G * GLOW_SCALE, color.B * GLOW_SCALE)
		local isHead = part.Name == "Head" or part.Name == "FakeHead"
		local adorn: HandleAdornment
		if isHead then
			local size = part.Size
			adorn = instances.new("CylinderHandleAdornment", {
				Radius = math.max(size.X, size.Z) * 0.5 + GLOW_SIZE_OFFSET.X,
				Height = size.Y * 1.01,
				Angle = 360,
				CFrame = CFrame.Angles(math.rad(90), 0, 0),
				AlwaysOnTop = true,
				ZIndex = 10,
				Adornee = part,
				Color3 = glowColor,
				Transparency = GHOST_PART_TRANSPARENCY,
				Visible = part.Transparency < 1,
			}, part) :: CylinderHandleAdornment
		else
			adorn = instances.new("BoxHandleAdornment", {
				Size = part.Size + GLOW_SIZE_OFFSET,
				AlwaysOnTop = true,
				ZIndex = 9,
				Adornee = part,
				Color3 = glowColor,
				Transparency = GHOST_PART_TRANSPARENCY,
				Visible = part.Transparency < 1,
			}, part) :: BoxHandleAdornment
		end
		(adorn :: any).Shading = Enum.AdornShading.XRayShaded
		return adorn
	end

	function Backtrack._setBehindWalls(self: Backtrack, enabled: boolean): ()
		if self._behindWalls == enabled then
			return
		end
		self._behindWalls = enabled

		for _, track in next, self._tracks do
			if enabled then
				for _, part in next, track.ghostParts do
					if not track.adorns[part] then
						track.adorns[part] = self:_createAdorn(part)
					end
				end
			else
				for part, adorn in next, track.adorns do
					adorn:Destroy()
					track.adorns[part] = nil
				end
			end
		end
	end

	function Backtrack._destroyGhost(self: Backtrack, track: Track): ()
		if track.ghost then
			if track.hitbox then
				hook.restoreInstance(track.hitbox)
				track.hitbox = nil
			end
			track.ghost:Destroy()
			track.ghost = nil
			track.ghostParts = {}
			table.clear(track.adorns)
			track.ghostVisible = nil
		end
	end

	function Backtrack._setTrackVisible(self: Backtrack, track: Track, visible: boolean): ()
		if track.ghostVisible == visible then
			return
		end
		track.ghostVisible = visible
		local transparency = (visible and GHOST_PART_TRANSPARENCY or 1)
		for _, part in next, track.ghostParts do
			part.Transparency = transparency
			local adorn = track.adorns[part]
			if adorn then
				adorn.Visible = visible
			end
		end
	end

	function Backtrack._refreshGhostColor(self: Backtrack): ()
		local color = self._ghostColor
		local glowColor = Color3.new(color.R * GLOW_SCALE, color.G * GLOW_SCALE, color.B * GLOW_SCALE)
		for _, track in next, self._tracks do
			for _, part in next, track.ghostParts do
				part.Color = color
			end
			for _, adorn in next, track.adorns do
				adorn.Color3 = glowColor
			end
		end
	end

	Backtrack._tick = LPH_NO_VIRTUALIZE(function(self: Backtrack): ()
		local now = os.clock()
		backtrackHit.prune(now)
		local clock = self:_clock()
		local rawDelay = self._cachedDelay
		local delaySec = (rawDelay <= 0 and SessionController.GetPing() * 2 / 1000 or rawDelay / 1000)
		local visual = self._cachedVisual
		local retention = math.max(MAX_DELAY_SEC, delaySec + 0.5)
		local cutoff = now - retention

		for _, track in next, self._tracks do
			local bp = track.bp
			local hitbox = track.hitbox
			if hitbox then
				hitbox.CanQuery = false
			end
			if peek(bp.isEnemy) ~= true or not bp:IsAlive() then
				self:_setTrackVisible(track, false)
				track.historyValid = false
				continue
			end

			local parts = peek(bp.parts)
			if next(parts) == nil then
				self:_setTrackVisible(track, false)
				track.historyValid = false
				continue
			end

			if not track.ghost then
				self:_createGhost(parts, track)
			end

			if now - track.lastSnap >= SNAPSHOT_INTERVAL then
				track.lastSnap = now
				local snap = acquireSnapshot(track, now, clock and clock.getTime() or now)
				local cframes = snap.cframes
				for name, part in next, parts do
					cframes[name] = part.CFrame
				end
				if next(cframes) then
					local buffer = track.buffer
					buffer[#buffer + 1] = snap
					local start = track.bufferStart
					while buffer[start] and buffer[start].time < cutoff do
						reclaimSnapshot(track, buffer[start])
						buffer[start] = nil
						start += 1
					end
					track.bufferStart = start
					if start > BUFFER_COMPACT_AT then
						compactBuffer(track)
					end
				else
					reclaimSnapshot(track, snap)
				end
			end

			local snap = getHistoricalSnapshot(track.buffer, track.bufferStart, delaySec, now)
			if not snap then
				self:_setTrackVisible(track, false)
				track.historyValid = false
				continue
			end

			local historyCFs = snap.cframes
			local headCF = historyCFs["Head"]
			local realHead = parts["Head"]
			if headCF and realHead and (headCF.Position - realHead.Position).Magnitude < STILL_THRESHOLD then
				self:_setTrackVisible(track, false)
				track.historyValid = false
				continue
			end

			local ghostParts = track.ghostParts
			local adorns = track.adorns
			local anyVisible = false
			for name, ghostPart in next, ghostParts do
				local cf = historyCFs[name]
				local adorn = adorns[ghostPart]
				if cf then
					ghostPart.CFrame = cf
					if visual then
						if ghostPart.Transparency ~= GHOST_PART_TRANSPARENCY then
							ghostPart.Transparency = GHOST_PART_TRANSPARENCY
						end
						if adorn and not adorn.Visible then
							adorn.Visible = true
						end
						anyVisible = true
					else
						if ghostPart.Transparency ~= 1 then
							ghostPart.Transparency = 1
						end
						if adorn and adorn.Visible then
							adorn.Visible = false
						end
					end
				else
					if ghostPart.Transparency ~= 1 then
						ghostPart.Transparency = 1
					end
					if adorn and adorn.Visible then
						adorn.Visible = false
					end
				end
			end
			track.ghostVisible = anyVisible
			track.historyValid = true
			track.historyGameTime = snap.gameTime

			if hitbox then
				local bodyCF = historyCFs["Torso"] or historyCFs["HumanoidRootPart"] or headCF
				if bodyCF then
					hitbox.CFrame = bodyCF
					hitbox.CanQuery = true
				end
			end
		end
	end)

	function Backtrack.Destroy(self: Backtrack): ()
		self:_disable()
		self._folder:Destroy()
		if (_instance :: any) == self then
			_instance = nil
		end
		BaseFeature.Destroy(self)
	end

	function Backtrack.GetHistoricalPosition(player: Player, partName: string): Vector3?
		if not _instance or not _instance._enabled then
			return nil
		end
		local track = _instance._tracks[player]
		if not track or not track.historyValid then
			return nil
		end
		local part = track.ghostParts[partName]
		if not part then
			return nil
		end
		return part.Position
	end

	function Backtrack.GetHistoricalHit(player: Player, partName: string): (Vector3?, number?)
		if not _instance or not _instance._enabled then
			return nil, nil
		end
		local track = _instance._tracks[player]
		if not track or not track.historyValid then
			return nil, nil
		end
		local part = track.ghostParts[partName]
		if not part then
			return nil, nil
		end
		return part.Position, track.historyGameTime
	end

	function Backtrack.GetFolder(): Folder?
		if not _instance then
			return nil
		end
		return _instance._folder
	end

	function Backtrack.IsEnabled(): boolean
		return _instance ~= nil and _instance._enabled == true
	end

	export type Backtrack =
		typeof(setmetatable(
			{} :: {
				_tracks: { [Player]: Track },
				_folder: Folder,
				_enabled: boolean,
				_heartbeat: RBXScriptConnection?,
				_addedConn: RBXScriptConnection?,
				_removingConn: RBXScriptConnection?,
				_ghostColor: Color3,
				_behindWalls: boolean,
				_gameClock: any,
				_opts: gameUi.Linker,
				_delayEl: any,
				_visualEl: any,
				_cachedDelay: number,
				_cachedVisual: boolean,
			},
			Backtrack
		))
		& BaseFeature.BaseFeature

	return Backtrack
end)()
