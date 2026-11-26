local STROKE_INSET = 1
local PADDING_X = 4
local PADDING_Y = 8
local CELL_GAP_X = 10
local CELL_GAP_Y = 12
local SCROLLBAR_THICKNESS = 3
local MAX_COLUMNS = 4

local function computeColumns(availableWidth: number, minCellWidth: number): number
	if availableWidth <= 0 then
		return 1
	end

	local maxCols = math.min(MAX_COLUMNS, math.max(1, math.floor(availableWidth / minCellWidth)))
	for try = maxCols, 1, -1 do
		local cellW = (availableWidth - CELL_GAP_X * (try - 1)) / try
		if cellW >= minCellWidth then
			return try
		end
	end

	return 1
end

local gridLayout = {}

gridLayout.STROKE_INSET = STROKE_INSET
gridLayout.PADDING_X = PADDING_X
gridLayout.PADDING_Y = PADDING_Y
gridLayout.GAP_X = CELL_GAP_X
gridLayout.GAP_Y = CELL_GAP_Y
gridLayout.SCROLLBAR_THICKNESS = SCROLLBAR_THICKNESS

function gridLayout.availableWidth(containerWidth: number, paddingX: number?, reserveScrollbar: boolean?): number
	local pad = paddingX or PADDING_X
	local scroll = (reserveScrollbar and SCROLLBAR_THICKNESS or 0)
	return math.max(0, containerWidth - pad * 2 - scroll)
end

function gridLayout.compute(
	containerWidth: number,
	minCellWidth: number,
	cardHeight: number,
	itemCount: number,
	paddingX: number?,
	reserveScrollbar: boolean?
): {
	columns: number,
	cellWidth: number,
	availableWidth: number,
	rows: number,
	contentHeight: number,
}
	local availableWidth = gridLayout.availableWidth(containerWidth, paddingX, reserveScrollbar)
	local columns = computeColumns(availableWidth, minCellWidth)
	local cellWidth = (availableWidth - CELL_GAP_X * (columns - 1)) / columns
	local rows = math.max(0, math.ceil(itemCount / columns))
	local contentHeight = rows * cardHeight + math.max(0, rows - 1) * CELL_GAP_Y + PADDING_Y * 2

	return {
		columns = columns,
		cellWidth = cellWidth,
		availableWidth = availableWidth,
		rows = rows,
		contentHeight = contentHeight,
	}
end

return gridLayout
