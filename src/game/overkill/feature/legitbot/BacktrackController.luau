return LPH_JIT_MAX(function()
	local RunService = cloneref(game:GetService("RunService")) :: RunService
	local Workspace = cloneref(game:GetService("Workspace")) :: Workspace
	local Players = cloneref(game:GetService("Players")) :: Players

	local PlayerController = require("@feature/player/PlayerController")
	local SessionController = require("@feature/session/SessionController")
	local botSource = require("@game/overkill/feature/training/botSource")
	local targeting = require("@game/overkill/player/targeting")
	local BaseFeature = require("@game/BaseFeature")
	local gameUi = require("@game/gameUi")
	local instances = require("@share/instances")
	local Charm = require("@pkg/Charm")
	local React = require("@pkg/React")

	local peek = Charm.peek
	local sub = Charm.subscribe
	local subscribeToBinding = (React :: any).__subscribeToBinding

	local LocalPlayer = Players.LocalPlayer

	local SNAPSHOT_INTERVAL = 1 / 60
	local MAX_DELAY_SEC = 0.5
	local BUFFER_COMPACT_AT = 48
	local STILL_THRESHOLD = 0.05
	local DEFAULT_GHOST_COLOR = Color3.fromRGB(93, 231, 190)
	local GHOST_PART_TRANSPARENCY = 0.5
	local GHOST_MATERIAL = Enum.Material.Neon
	local GLOW_SCALE = 5
	local GLOW_SIZE_OFFSET = Vector3.new(0.03, 0.03, 0.03)

	local function isHitboxName(name: string): boolean
		return string.sub(name, 1, 6) == "Hitbox"
	end

	type Snapshot = {
		time: number,
		cframes: { [string]: CFrame },
	}

	type Track = {
		bp: any,
		buffer: { Snapshot },
		bufferStart: number,
		bufferEnd: number,
		lastSnap: number,
		ghost: Model?,
		ghostParts: { [string]: BasePart },
		adorns: { [BasePart]: HandleAdornment },
		charUnsub: () -> (),
		aliveUnsub: () -> (),
		lastCharacter: Model?,
		ghostVisible: boolean?,
		historyValid: boolean,
	}

	local Backtrack = {}
	Backtrack.__index = Backtrack
	setmetatable(Backtrack, { __index = BaseFeature })

	local _instance: any = nil
	local _demand: { [string]: number } = {}

	local isEnemy = targeting.isEnemy

	local compactBuffer = LPH_NO_VIRTUALIZE(function(track: Track): ()
		local buffer = track.buffer
		local start = track.bufferStart
		if start <= 1 then
			return
		end
		local endIdx = track.bufferEnd
		local newLen = endIdx - start + 1
		if newLen <= 0 then
			table.clear(buffer)
			track.bufferStart = 1
			track.bufferEnd = 0
			return
		end
		for i = 1, newLen do
			buffer[i] = buffer[start + i - 1]
		end
		for i = newLen + 1, endIdx do
			buffer[i] = nil
		end
		track.bufferStart = 1
		track.bufferEnd = newLen
	end)

	local getHistoricalSnapshot = LPH_NO_VIRTUALIZE(
		function(buffer: { Snapshot }, startIdx: number, endIdx: number, delay: number): Snapshot?
			local n = endIdx
			if n < startIdx then
				return nil
			end
			local target = os.clock() - delay
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

	function Backtrack.new(link: gameUi.Linker, opts: { setRedirectionActive: ((boolean) -> ())? }?): Backtrack
		local self = BaseFeature.new() :: any
		setmetatable(self, Backtrack)

		self._setRedirectionActive = opts and opts.setRedirectionActive
		self._tracks = {} :: { [any]: Track }
		self._folder = instances.new("Folder", { Secure = true }, Workspace) :: Folder
		self._enabled = false
		self._recording = false
		self._dead = false
		self._heartbeat = nil :: RBXScriptConnection?
		self._addedConn = nil :: RBXScriptConnection?
		self._removingConn = nil :: RBXScriptConnection?
		self._ghostColor = DEFAULT_GHOST_COLOR
		self._behindWalls = false
		self._shiftSec = 0

		local mainToggle = link:Toggle("backtrack", "Backtrack", false):SetTip({
			title = "Backtrack",
			body = "Lets you hit enemies where they were a short time ago.",
		})
		link:Extra(mainToggle, "backtrackOpts", "Submenu", "Backtrack Options")
		local opts = link:OnKey("backtrackOpts")

		opts:Slider("delay", "Delay", 200, 0, 400, 10, nil, "ms")
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
		self:_refreshRecording()
		return self
	end

	function Backtrack._refreshRecording(self: Backtrack): ()
		local want = not self._dead and (self._enabled or next(_demand) ~= nil)
		if want == self._recording then
			return
		end
		self._recording = want

		if want then
			self._addedConn = PlayerController.playerAdded:Connect(function(bp: any): ()
				self:_bindPlayer(bp)
			end) :: any
			self._removingConn = PlayerController.playerRemoving:Connect(function(bp: any): ()
				self:_unbindPlayer(bp:GetPlayer())
			end) :: any

			for _, bp in next, PlayerController.GetAll() do
				self:_bindPlayer(bp)
			end
			for _, bot in next, botSource.GetAll() do
				self:_bindPlayer(bot)
			end

			self._heartbeat = RunService.Heartbeat:Connect(LPH_NO_VIRTUALIZE(function(): ()
				self:_tick()
			end))
			return
		end

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

	function Backtrack._enable(self: Backtrack): ()
		if self._enabled then
			return
		end
		self._enabled = true
		if self._setRedirectionActive then
			self._setRedirectionActive(true)
		end
		self:_refreshRecording()
	end

	function Backtrack._disable(self: Backtrack): ()
		if not self._enabled then
			return
		end
		self._enabled = false
		if self._setRedirectionActive then
			self._setRedirectionActive(false)
		end
		self:_refreshRecording()

		if self._recording then
			for _, track in next, self._tracks do
				self:_destroyGhost(track)
				track.historyValid = false
			end
		end
	end

	function Backtrack._bindPlayer(self: Backtrack, bp: any): ()
		local player: any = bp:GetPlayer()
		if player == LocalPlayer or self._tracks[player] then
			return
		end

		local track: Track = {
			bp = bp,
			buffer = {},
			bufferStart = 1,
			bufferEnd = 0,
			lastSnap = 0,
			ghost = nil,
			ghostParts = {},
			adorns = {},
			charUnsub = function() end,
			aliveUnsub = function() end,
			lastCharacter = nil,
			ghostVisible = nil,
			historyValid = false,
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
			track.bufferEnd = 0
			track.lastSnap = 0
			track.historyValid = false
		end)

		track.aliveUnsub = sub(bp.alive, function(alive: boolean): ()
			if not alive then
				table.clear(track.buffer)
				track.bufferStart = 1
				track.bufferEnd = 0
				track.lastSnap = 0
				track.historyValid = false
				self:_setTrackVisible(track, false)
			end
		end)

		track.lastCharacter = peek(bp.character)
	end

	function Backtrack._unbindPlayer(self: Backtrack, player: any): ()
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

			if self._behindWalls and not isHitboxName(name) then
				track.adorns[clone] = self:_createAdorn(clone)
			end
		end

		track.ghost = model
		track.ghostParts = ghostParts
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
				for name, part in next, track.ghostParts do
					if not isHitboxName(name) and not track.adorns[part] then
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
		for name, part in next, track.ghostParts do
			if isHitboxName(name) then
				if part.Transparency ~= 1 then
					part.Transparency = 1
				end
				continue
			end
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
		local rawDelay = self._delayEl:Peek() or 200
		local delaySec = (rawDelay <= 0 and SessionController.GetPing() * 2 / 1000 or rawDelay / 1000)
		self._shiftSec = delaySec
		local visual = self._visualEl:Peek()
		local maxDemand = 0
		for _, sec in next, _demand do
			if sec > maxDemand then
				maxDemand = sec
			end
		end
		local retention = math.max(MAX_DELAY_SEC, delaySec + 0.5, maxDemand + 0.5)
		local cutoff = now - retention

		for _, bot in next, botSource.GetAll() do
			if not self._tracks[bot:GetPlayer()] then
				self:_bindPlayer(bot)
			end
		end

		for _, track in next, self._tracks do
			local bp = track.bp
			if not isEnemy(bp) then
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

			if self._enabled and not track.ghost then
				self:_createGhost(parts, track)
			end

			if now - track.lastSnap >= SNAPSHOT_INTERVAL then
				track.lastSnap = now
				local cframes: { [string]: CFrame } = {}
				for name, part in next, parts do
					if part:IsA("BasePart") then
						cframes[name] = part.CFrame
					end
				end
				if next(cframes) then
					local buffer = track.buffer
					local endIdx = track.bufferEnd + 1
					buffer[endIdx] = {
						time = now,
						cframes = cframes,
					}
					track.bufferEnd = endIdx
					local start = track.bufferStart
					while start <= endIdx and buffer[start].time < cutoff do
						buffer[start] = nil
						start += 1
					end
					track.bufferStart = start
					if start > BUFFER_COMPACT_AT then
						compactBuffer(track)
					end
				end
			end

			if not self._enabled then
				track.historyValid = false
				continue
			end

			local snap = getHistoricalSnapshot(track.buffer, track.bufferStart, track.bufferEnd, delaySec)
			if not snap then
				self:_setTrackVisible(track, false)
				track.historyValid = false
				continue
			end
			local targetCFs: { [string]: CFrame } = snap.cframes

			local headCF = targetCFs["Head"]
			local realHead = parts["Head"]
			if
				not bp.isBot
				and headCF
				and realHead
				and (headCF.Position - realHead.Position).Magnitude < STILL_THRESHOLD
			then
				self:_setTrackVisible(track, false)
				track.historyValid = false
				continue
			end

			local ghostParts = track.ghostParts
			local adorns = track.adorns
			local anyVisible = false
			for name, ghostPart in next, ghostParts do
				local cf = targetCFs[name]
				local adorn = adorns[ghostPart]
				if cf and isHitboxName(name) then
					ghostPart.CFrame = cf
					if ghostPart.Transparency ~= 1 then
						ghostPart.Transparency = 1
					end
				elseif cf then
					ghostPart.CFrame = cf
					if visual then
						ghostPart.Transparency = GHOST_PART_TRANSPARENCY
						if adorn then
							adorn.Visible = true
						end
						anyVisible = true
					else
						if ghostPart.Transparency ~= 1 then
							ghostPart.Transparency = 1
						end
						if adorn then
							adorn.Visible = false
						end
					end
				else
					if ghostPart.Transparency ~= 1 then
						ghostPart.Transparency = 1
					end
					if adorn then
						adorn.Visible = false
					end
				end
			end
			track.ghostVisible = anyVisible
			track.historyValid = true
		end
	end)

	function Backtrack.Destroy(self: Backtrack): ()
		self:_disable()
		self._dead = true
		self:_refreshRecording()
		self._folder:Destroy()
		if (_instance :: any) == self then
			_instance = nil
		end
		BaseFeature.Destroy(self)
	end

	Backtrack.GetHistoricalPosition = LPH_NO_VIRTUALIZE(function(player: any, partName: string): Vector3?
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
	end)

	function Backtrack.SetHistoryDemand(id: string, seconds: number): ()
		if seconds > 0 then
			_demand[id] = seconds
		else
			_demand[id] = nil
		end
		if _instance then
			_instance:_refreshRecording()
		end
	end

	Backtrack.GetPositionAt = LPH_NO_VIRTUALIZE(function(player: any, partName: string, delaySec: number): Vector3?
		if not _instance or not _instance._recording then
			return nil
		end
		local track = _instance._tracks[player]
		if not track then
			return nil
		end
		local snap = getHistoricalSnapshot(track.buffer, track.bufferStart, track.bufferEnd, delaySec)
		if not snap then
			return nil
		end
		local cf = snap.cframes[partName]
		if not cf then
			return nil
		end
		return cf.Position
	end)

	function Backtrack.IsEnabled(): boolean
		return _instance ~= nil and _instance._enabled == true
	end

	function Backtrack.GetDelaySeconds(): number
		if not _instance or not _instance._enabled then
			return 0
		end
		return _instance._shiftSec or 0
	end

	Backtrack.RayHitsGhost = LPH_NO_VIRTUALIZE(function(origin: Vector3, dir: Vector3): boolean
		if not _instance or not _instance._enabled then
			return false
		end
		for _, track in next, _instance._tracks do
			if not track.historyValid then
				continue
			end
			for _, part in next, track.ghostParts do
				local toPart = part.Position - origin
				local proj = toPart:Dot(dir)
				if proj <= 0 then
					continue
				end
				local closest = origin + dir * proj
				local size = part.Size
				local radius = math.max(size.X, size.Y, size.Z) * 0.5
				if (part.Position - closest).Magnitude <= radius then
					return true
				end
			end
		end
		return false
	end)

	function Backtrack.GetFolder(): Folder?
		if not _instance then
			return nil
		end
		return _instance._folder
	end

	export type Backtrack =
		typeof(setmetatable(
			{} :: {
				_tracks: { [any]: Track },
				_folder: Folder,
				_enabled: boolean,
				_recording: boolean,
				_dead: boolean,
				_heartbeat: RBXScriptConnection?,
				_addedConn: RBXScriptConnection?,
				_removingConn: RBXScriptConnection?,
				_ghostColor: Color3,
				_behindWalls: boolean,
				_shiftSec: number,
				_setRedirectionActive: ((boolean) -> ())?,
				_delayEl: any,
				_visualEl: any,
			},
			Backtrack
		))
		& BaseFeature.BaseFeature

	return Backtrack
end)()
