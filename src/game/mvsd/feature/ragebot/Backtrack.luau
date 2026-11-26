local RunService = cloneref(game:GetService("RunService")) :: RunService
local Workspace = cloneref(game:GetService("Workspace")) :: Workspace
local Players = cloneref(game:GetService("Players")) :: Players

local Charm = require("@pkg/Charm")
local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local instances = require("@share/instances")
local sessionState = require("@feature/session/sessionState")
local PlayerController = require("@feature/player/PlayerController")
local ClientState = require("@game/mvsd/client/clientState")
local WeaponController = require("@game/mvsd/weapon/WeaponController")

local peek = Charm.peek
local sub = Charm.subscribe

local SNAPSHOT_INTERVAL = 1 / 144
local MAX_DELAY_SEC = 5
local BUFFER_COMPACT_AT = 48
local BOX_EXPAND = 0.1
local IDENTICAL_EPSILON = 0.05
local DEFAULT_GHOST_COLOR = Color3.fromRGB(145, 190, 215)
local GHOST_TRANSPARENCY = 0.55
local GHOST_MATERIAL = Enum.Material.Neon
local HIDDEN_PARTS = {
	HumanoidRootPart = true,
}

type Snapshot = {
	time: number,
	cframes: { [string]: CFrame },
}

type Track = {
	bp: any,
	buffer: { Snapshot },
	bufferStart: number,
	lastSnap: number,
	ghost: Model?,
	ghostParts: { [string]: BasePart },
	resolved: { [string]: CFrame }?,
	charUnsub: () -> (),
	aliveUnsub: () -> (),
	visible: boolean?,
}

local Backtrack = {}
Backtrack.__index = Backtrack
setmetatable(Backtrack, { __index = BaseFeature })

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

local getHistoricalCFrames = LPH_NO_VIRTUALIZE(
	function(buffer: { Snapshot }, startIdx: number, delay: number): { [string]: CFrame }?
		local n = #buffer
		if n < startIdx then
			return nil
		end
		local target = os.clock() - delay
		if buffer[n].time <= target then
			return buffer[n].cframes
		end
		if buffer[startIdx].time >= target then
			return buffer[startIdx].cframes
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
			return buffer[lo].cframes
		end
		return buffer[hi].cframes
	end
)

local slab = LPH_NO_VIRTUALIZE(function(o: number, d: number, h: number, tMin: number, tMax: number): (number, number)
	if math.abs(d) < 1e-6 then
		if o < -h or o > h then
			return 1, 0
		end
		return tMin, tMax
	end
	local inverse = 1 / d
	local near = (-h - o) * inverse
	local far = (h - o) * inverse
	if near > far then
		near, far = far, near
	end
	if near > tMin then
		tMin = near
	end
	if far < tMax then
		tMax = far
	end
	return tMin, tMax
end)

local rayBoxDistance = LPH_NO_VIRTUALIZE(
	function(cf: CFrame, size: Vector3, origin: Vector3, direction: Vector3, maxDistance: number): number?
		local localOrigin = cf:PointToObjectSpace(origin)
		local localDirection = cf:VectorToObjectSpace(direction)

		local tMin, tMax = 0, maxDistance
		tMin, tMax = slab(localOrigin.X, localDirection.X, size.X * 0.5 + BOX_EXPAND, tMin, tMax)
		if tMin > tMax then
			return nil
		end
		tMin, tMax = slab(localOrigin.Y, localDirection.Y, size.Y * 0.5 + BOX_EXPAND, tMin, tMax)
		if tMin > tMax then
			return nil
		end
		tMin, tMax = slab(localOrigin.Z, localDirection.Z, size.Z * 0.5 + BOX_EXPAND, tMin, tMax)
		if tMin > tMax then
			return nil
		end

		return tMin
	end
)

local hitsPlayer = LPH_NO_VIRTUALIZE(function(hitInstance: any): boolean
	if typeof(hitInstance) ~= "Instance" or not hitInstance:IsA("BasePart") then
		return false
	end
	local model = hitInstance.Parent
	if not model or not model:IsA("Model") then
		return false
	end
	return Players:GetPlayerFromCharacter(model) ~= nil
end)

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
	self._delaySec = 0.2
	self._resolver = function(origin: Vector3, target: Vector3, hitInstance: any, hitPosition: any): (BasePart?, Vector3?)
		return self:_resolve(origin, target, hitInstance, hitPosition)
	end

	local mainToggle = link:Toggle("backtrack", "Backtrack", false):SetTip({
		title = "Backtrack",
		body = "Lets you hit enemies where they were a short time ago.",
	})
	link:Extra(mainToggle, "backtrackOpts", "Submenu", "Backtrack Options")
	local opts = link:OnKey("backtrackOpts")
	self._opts = opts
	self._delayEl = nil :: any
	self._visualEl = nil :: any

	opts:Slider("delay", "Delay", 200, 0, 1000, 10, nil, "ms")
		:SetTip({
			title = "Delay",
			body = "How far back in time enemy positions are saved. Set to 0 to match your ping automatically.",
		})
		:SetValueTextOverrides({ [0] = "Auto" })
	opts:Toggle("visual", "Show Ghost", true):SetTip({
		title = "Show Ghost",
		body = "Shows a faded copy of the enemy at their backtracked position.",
	})
	opts:Colorpicker("color", "Ghost Color", DEFAULT_GHOST_COLOR, 0):SetTip({
		title = "Ghost Color",
		body = "Color of the backtrack ghost.",
	})

	self:Track(link:Get("backtrack"):OnChange(function(value: boolean): ()
		if value then
			self:_enable()
		else
			self:_disable()
		end
	end))

	local colorEl = opts:Get("color")
	self:Track(colorEl:OnColorChange(function(): ()
		self._ghostColor = colorEl:GetSnapshot().color
		self:_refreshGhostColor()
	end))

	if link:Peek("backtrack") then
		self:_enable()
	end

	return self
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
	WeaponController.SetHitResolver(self._resolver)
end

function Backtrack._disable(self: Backtrack): ()
	if not self._enabled then
		return
	end
	self._enabled = false

	WeaponController.SetHitResolver(nil)

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
	if self._tracks[player] or player == Players.LocalPlayer then
		return
	end

	local track: Track = {
		bp = bp,
		buffer = {},
		bufferStart = 1,
		lastSnap = 0,
		ghost = nil,
		ghostParts = {},
		resolved = nil,
		charUnsub = function() end,
		aliveUnsub = function() end,
		visible = nil,
	}
	self._tracks[player] = track

	track.charUnsub = sub(bp.parts, function(parts: any): ()
		if not next(parts) then
			self:_destroyGhost(track)
		else
			self:_syncGhost(track)
		end
	end)

	track.aliveUnsub = sub(bp.alive, function(alive: boolean): ()
		if not alive then
			table.clear(track.buffer)
			track.bufferStart = 1
			track.lastSnap = 0
			track.resolved = nil
			self:_setVisible(track, false)
		end
	end)

	if next(peek(bp.parts)) then
		self:_syncGhost(track)
	end
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

function Backtrack._syncGhost(self: Backtrack, track: Track): ()
	local parts = peek(track.bp.parts)
	if not next(parts) then
		return
	end

	local model = track.ghost
	if not model or not model.Parent then
		model = instances.new("Model", { Secure = true }, self._folder) :: Model
		track.ghost = model
		track.ghostParts = {}
		track.visible = nil
	end

	local ghostParts = track.ghostParts
	for name, child in next, parts do
		if ghostParts[name] or HIDDEN_PARTS[name] or not child:IsA("BasePart") then
			continue
		end

		local clone = child:Clone() :: BasePart
		for _, descendant in next, clone:GetChildren() do
			if descendant:IsA("SpecialMesh") then
				descendant.TextureId = ""
			else
				descendant:Destroy()
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
		clone.Massless = true
		clone.Transparency = 1
		clone.Material = GHOST_MATERIAL
		clone.Color = self._ghostColor
		clone.Parent = model
		ghostParts[name] = clone
	end
end

function Backtrack._destroyGhost(self: Backtrack, track: Track): ()
	if track.ghost then
		track.ghost:Destroy()
		track.ghost = nil
		track.ghostParts = {}
		track.visible = nil
	end
end

function Backtrack._setVisible(self: Backtrack, track: Track, visible: boolean): ()
	if track.visible == visible then
		return
	end
	track.visible = visible
	local transparency = (visible and GHOST_TRANSPARENCY or 1)
	for _, part in next, track.ghostParts do
		part.Transparency = transparency
	end
end

function Backtrack._refreshGhostColor(self: Backtrack): ()
	local color = self._ghostColor
	for _, track in next, self._tracks do
		for _, part in next, track.ghostParts do
			part.Color = color
		end
	end
end

Backtrack._tick = LPH_NO_VIRTUALIZE(function(self: Backtrack): ()
	local delayEl = self._delayEl
	if not delayEl then
		delayEl = self._opts:Get("delay")
		self._delayEl = delayEl
		self._visualEl = self._opts:Get("visual")
	end

	local rawDelay = delayEl:Peek() or 200
	local delaySec = rawDelay <= 0 and peek(sessionState.ping) * 2 / 1000 or rawDelay / 1000
	self._delaySec = delaySec

	local visual = self._visualEl:Peek() == true
	local localMatch = peek(ClientState.matchId)
	local localTeam = peek(ClientState.team)
	local now = os.clock()

	for _, track in next, self._tracks do
		local bp = track.bp

		if localMatch == nil or peek(bp.matchId) ~= localMatch or bp:GetTeam() == localTeam or not bp:IsAlive() then
			track.resolved = nil
			self:_setVisible(track, false)
			continue
		end

		if now - track.lastSnap >= SNAPSHOT_INTERVAL then
			track.lastSnap = now
			local parts = peek(bp.parts)
			local cframes: { [string]: CFrame } = {}
			for name, part in next, parts do
				if part:IsA("BasePart") then
					cframes[name] = part.CFrame
				end
			end
			if next(cframes) then
				local buffer = track.buffer
				buffer[#buffer + 1] = { time = now, cframes = cframes }
				local cutoff = now - math.max(MAX_DELAY_SEC, delaySec + 0.5)
				local start = track.bufferStart
				while buffer[start] and buffer[start].time < cutoff do
					buffer[start] = nil
					start += 1
				end
				track.bufferStart = start
				if start > BUFFER_COMPACT_AT then
					compactBuffer(track)
				end
			end
		end

		local history = getHistoricalCFrames(track.buffer, track.bufferStart, delaySec)
		if not history then
			track.resolved = nil
			self:_setVisible(track, false)
			continue
		end

		local realParts = peek(bp.parts)
		local historyRoot = history.HumanoidRootPart
		local realRoot = realParts.HumanoidRootPart
		if
			historyRoot
			and realRoot
			and (historyRoot.Position - (realRoot :: BasePart).Position).Magnitude < IDENTICAL_EPSILON
		then
			track.resolved = nil
			self:_setVisible(track, false)
			continue
		end

		track.resolved = history

		for name, part in next, track.ghostParts do
			local cf = history[name]
			if cf then
				part.CFrame = cf
			end
		end
		self:_setVisible(track, visual)
	end
end)

Backtrack._resolve = LPH_NO_VIRTUALIZE(
	function(self: Backtrack, origin: Vector3, target: Vector3, hitInstance: any, hitPosition: any): (BasePart?, Vector3?)
		if not self._enabled or peek(ClientState.weapon) ~= "gun" or hitsPlayer(hitInstance) then
			return nil, nil
		end

		local endPosition = typeof(hitPosition) == "Vector3" and hitPosition or target
		local offset = target - origin
		local distance = offset.Magnitude
		if distance < 1e-3 then
			return nil, nil
		end

		local direction = offset / distance
		local maxDistance = math.min(distance, (endPosition - origin).Magnitude)
		if maxDistance < 1e-3 then
			return nil, nil
		end

		local bestPart: BasePart? = nil
		local bestDistance = maxDistance

		for _, track in next, self._tracks do
			local history = track.resolved
			if not history then
				continue
			end

			local realParts = peek(track.bp.parts)
			for name, cf in next, history do
				local real = realParts[name]
				if not real or not real:IsA("BasePart") then
					continue
				end

				local hitDistance = rayBoxDistance(cf, (real :: BasePart).Size, origin, direction, bestDistance)
				if hitDistance and hitDistance < bestDistance then
					bestDistance = hitDistance
					bestPart = real :: BasePart
				end
			end
		end

		if not bestPart then
			return nil, nil
		end

		return bestPart, origin + direction * bestDistance
	end
)

function Backtrack.Destroy(self: Backtrack): ()
	self:_disable()
	self._folder:Destroy()
	BaseFeature.Destroy(self)
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
			_delaySec: number,
			_resolver: (Vector3, Vector3, any, any) -> (BasePart?, Vector3?),
			_opts: gameUi.Linker,
			_delayEl: any,
			_visualEl: any,
		},
		Backtrack
	))
	& BaseFeature.BaseFeature

return Backtrack
