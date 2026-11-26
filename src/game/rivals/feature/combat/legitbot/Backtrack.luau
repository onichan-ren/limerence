local RunService = cloneref(game:GetService("RunService")) :: RunService
local Workspace = cloneref(game:GetService("Workspace")) :: Workspace
local CollectionService = cloneref(game:GetService("CollectionService")) :: CollectionService
local sessionState = require("@feature/session/sessionState")

local PlayerController = require("@feature/player/PlayerController")
local ClientState = require("@game/rivals/client/clientState")
local WeaponController = require("@game/rivals/weapon/WeaponController")
local BaseFeature = require("@game/BaseFeature")
local gameUi = require("@game/gameUi")
local instances = require("@share/instances")
local Charm = require("@pkg/Charm")

local peek = Charm.peek
local sub = Charm.subscribe

local SNAPSHOT_INTERVAL = 1 / 144
local MAX_DELAY_SEC = 5
local BUFFER_COMPACT_AT = 48
local DEFAULT_GHOST_COLOR = Color3.fromRGB(93, 231, 190)
local GHOST_PART_TRANSPARENCY = 0.5
local GHOST_MATERIAL = Enum.Material.Neon

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
	charUnsub: () -> (),
	aliveUnsub: () -> (),
	ghostVisible: boolean?,
}

local Backtrack = {}
Backtrack.__index = Backtrack
setmetatable(Backtrack, { __index = BaseFeature })

local _instance: any = nil

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

local resolveGhostParent = LPH_NO_VIRTUALIZE(function(): Instance
	local arena = Workspace:FindFirstChild("Arena")
	local extra = arena and arena:FindFirstChild("Extra")
	return extra or Workspace
end)

function Backtrack.new(link: gameUi.Linker): Backtrack
	local self = BaseFeature.new() :: any
	setmetatable(self, Backtrack)

	self._tracks = {} :: { [Player]: Track }
	self._ghostPartMap = {} :: { [BasePart]: { player: Player, partName: string } }
	self._ghostParent = resolveGhostParent()
	self._folder = instances.new("Folder", { Secure = false }, self._ghostParent) :: Folder
	self._lastFolderCheck = 0
	self._enabled = false
	self._heartbeat = nil :: RBXScriptConnection?
	self._addedConn = nil :: RBXScriptConnection?
	self._removingConn = nil :: RBXScriptConnection?
	self._ghostColor = DEFAULT_GHOST_COLOR
	self._impactCallback = function(instance: BasePart): BasePart
		local entry = self._ghostPartMap[instance]
		if not entry then
			return instance
		end
		local track = self._tracks[entry.player]
		if not track then
			return instance
		end
		local realPart = peek(track.bp.parts)[entry.partName]
		return realPart or instance
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

	opts:Slider("delay", "Delay", 200, 0, 5000, 10, nil, "ms")
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

	self:Track(link:Get("backtrack"):OnChange(function(v: boolean): ()
		if v then
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

	_instance = self
	return self
end

function Backtrack._enable(self: Backtrack): ()
	if self._enabled then
		return
	end
	self._enabled = true

	self:_ensureFolder()

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
	WeaponController.AddImpactCallback(self._impactCallback)
end

function Backtrack._disable(self: Backtrack): ()
	if not self._enabled then
		return
	end
	self._enabled = false

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

	WeaponController.RemoveImpactCallback(self._impactCallback)
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
		bufferStart = 1,
		lastSnap = 0,
		ghost = nil,
		ghostParts = {},
		charUnsub = function() end,
		aliveUnsub = function() end,
		ghostVisible = nil,
	}
	self._tracks[player] = track

	track.charUnsub = sub(bp.parts, function(parts: any): ()
		if not next(parts) then
			self:_destroyGhost(track)
		else
			self:_syncGhost(track, player)
		end
	end)

	track.aliveUnsub = sub(bp.alive, function(alive: boolean): ()
		if not alive then
			table.clear(track.buffer)
			track.bufferStart = 1
			track.lastSnap = 0
			self:_setTrackVisible(track, false)
		end
	end)

	if next(peek(bp.parts)) then
		self:_syncGhost(track, player)
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

function Backtrack._syncGhost(self: Backtrack, track: Track, player: Player): ()
	local parts = peek(track.bp.parts)
	if not next(parts) then
		return
	end

	local model = track.ghost
	if not model then
		model = instances.new("Model", { Secure = true }, self._folder) :: Model
		track.ghost = model
		track.ghostParts = {}
		track.ghostVisible = nil
	end

	local ghostParts = track.ghostParts
	for name, child in next, parts do
		if ghostParts[name] then
			continue
		end
		if not child:IsA("BasePart") then
			continue
		end
		if child.Transparency ~= 0 then
			continue
		end

		local clone = child:Clone() :: BasePart
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
		clone.CanCollide = true
		clone.CanQuery = true
		clone.CanTouch = true
		clone.CastShadow = false
		clone.Transparency = 1
		clone.Material = GHOST_MATERIAL
		clone.Color = self._ghostColor
		clone.Parent = model
		ghostParts[name] = clone

		self._ghostPartMap[clone] = { player = player, partName = name }
	end
end

function Backtrack._destroyGhost(self: Backtrack, track: Track): ()
	if track.ghost then
		for _, part in next, track.ghostParts do
			self._ghostPartMap[part] = nil
		end
		track.ghost:Destroy()
		track.ghost = nil
		track.ghostParts = {}
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
		if not visible then
			part.CanQuery = false
		end
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

function Backtrack._ensureFolder(self: Backtrack): ()
	local desired = resolveGhostParent()
	local folder = self._folder
	if folder and folder.Parent then
		if folder.Parent ~= desired then
			folder.Parent = desired
		end
		self._ghostParent = desired
		return
	end

	self._ghostParent = desired
	self._folder = instances.new("Folder", { Secure = true }, desired) :: Folder
	table.clear(self._ghostPartMap)
	for player, track in next, self._tracks do
		track.ghost = nil
		track.ghostParts = {}
		track.ghostVisible = nil
		if next(peek(track.bp.parts)) then
			self:_syncGhost(track, player)
		end
	end
end

Backtrack._tick = LPH_NO_VIRTUALIZE(function(self: Backtrack): ()
	local now = os.clock()
	if now - self._lastFolderCheck > 0.5 then
		self._lastFolderCheck = now
		self:_ensureFolder()
	end
	local localTeam = peek(ClientState.team)
	local delayEl = self._delayEl
	if not delayEl then
		delayEl = self._opts:Get("delay")
		self._delayEl = delayEl
		self._visualEl = self._opts:Get("visual")
	end
	local rawDelay = delayEl:Peek() or 200
	local delaySec = (rawDelay <= 0 and peek(sessionState.ping) * 2 / 1000 or rawDelay / 1000)
	local visual = self._visualEl:Peek()
	local hiddenTransparency = 1
	local visibleTransparency = GHOST_PART_TRANSPARENCY

	local localEnv = peek(ClientState.environmentId)
	if localEnv == "" then
		for _, track in next, self._tracks do
			self:_setTrackVisible(track, false)
		end
		return
	end

	for _, track in next, self._tracks do
		local bp = track.bp
		if peek(bp.environmentId) ~= localEnv then
			self:_setTrackVisible(track, false)
			continue
		end
		if localTeam ~= "" and bp:GetTeam() == localTeam then
			self:_setTrackVisible(track, false)
			continue
		end

		local alive = bp:IsAlive()

		if alive and now - track.lastSnap >= SNAPSHOT_INTERVAL then
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
				local retention = math.max(MAX_DELAY_SEC, delaySec + 0.5)
				local cutoff = now - retention
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

		local ghost = track.ghost
		if not ghost then
			continue
		end
		if not alive then
			self:_setTrackVisible(track, false)
			continue
		end

		local historyCFs = getHistoricalCFrames(track.buffer, track.bufferStart, delaySec)
		if not historyCFs then
			self:_setTrackVisible(track, false)
			continue
		end

		local realParts = peek(bp.parts)
		local headCF = historyCFs["Head"]
		local realHead = realParts["Head"]
		if headCF and realHead and (headCF.Position - realHead.CFrame.Position).Magnitude < 0.05 then
			self:_setTrackVisible(track, false)
			continue
		end

		local anyVisible = false
		local ghostParts = track.ghostParts
		for name, part in next, ghostParts do
			local cf = historyCFs[name]
			if cf then
				part.CFrame = cf
				part.CanQuery = true
				if visual then
					part.Transparency = visibleTransparency
					anyVisible = true
				elseif part.Transparency ~= hiddenTransparency then
					part.Transparency = hiddenTransparency
				end
			else
				if part.Transparency ~= hiddenTransparency then
					part.Transparency = hiddenTransparency
				end
				part.CanQuery = false
			end
		end
		if track.ghostVisible ~= anyVisible then
			track.ghostVisible = anyVisible
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
	if not track then
		return nil
	end
	local part = track.ghostParts[partName]
	if not part or not part.CanQuery then
		return nil
	end
	return part.CFrame.Position
end

function Backtrack.GetHistoricalPart(player: Player, partName: string): BasePart?
	if not _instance or not _instance._enabled then
		return nil
	end
	local track = _instance._tracks[player]
	if not track then
		return nil
	end
	local part = track.ghostParts[partName]
	if not part or not part.CanQuery then
		return nil
	end
	return part
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
			_ghostPartMap: { [BasePart]: { player: Player, partName: string } },
			_folder: Folder,
			_ghostParent: Instance,
			_lastFolderCheck: number,
			_enabled: boolean,
			_heartbeat: RBXScriptConnection?,
			_addedConn: RBXScriptConnection?,
			_removingConn: RBXScriptConnection?,
			_ghostColor: Color3,
			_impactCallback: (BasePart) -> BasePart,
			_opts: gameUi.Linker,
			_delayEl: any,
			_visualEl: any,
		},
		Backtrack
	))
	& BaseFeature.BaseFeature

return Backtrack
