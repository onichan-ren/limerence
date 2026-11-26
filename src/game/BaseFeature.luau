local BaseFeature = {}
BaseFeature.__index = BaseFeature

function BaseFeature.new(_opts: any?): BaseFeature
	local self = setmetatable({}, BaseFeature) :: BaseFeature
	self._disconnects = {}
	return self
end

function BaseFeature.Track(self: BaseFeature, disconnect: () -> ()): ()
	table.insert(self._disconnects, disconnect)
end

function BaseFeature.Destroy(self: BaseFeature): ()
	for _, disconnect in next, self._disconnects do
		disconnect()
	end
	self._disconnects = {}
end

export type BaseFeature = typeof(setmetatable(
	{} :: {
		_disconnects: { () -> () },
	},
	BaseFeature
))

return BaseFeature
