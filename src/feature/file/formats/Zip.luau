local EOCD_SIGNATURE = 0x06054b50
local CDIR_SIGNATURE = 0x02014b50

local LOCAL_HEADER_SIZE = 30
local CDIR_HEADER_SIZE = 46
local EOCD_SIZE = 22
local MAX_COMMENT = 65535

local METHOD_STORED = 0
local METHOD_DEFLATE = 8
local METHOD_LZMA = 14

local FLAG_ENCRYPTED = 0x1

local LENGTH_BASE = {
	3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 15, 17, 19, 23, 27, 31, 35, 43, 51, 59, 67, 83, 99, 115, 131, 163, 195, 227, 258,
}
local LENGTH_BITS = {
	0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5, 5, 0,
}
local DIST_BASE = {
	1, 2, 3, 4, 5, 7, 9, 13, 17, 25, 33, 49, 65, 97, 129, 193, 257, 385, 513, 769, 1025, 1537, 2049, 3073, 4097, 6145,
	8193, 12289, 16385, 24577,
}
local DIST_BITS = {
	0, 0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9, 9, 10, 10, 11, 11, 12, 12, 13, 13,
}
local CODE_LENGTH_ORDER = { 16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15 }

local function buildTree(lengths, count)
	local counts = {}
	for i = 0, 15 do
		counts[i] = 0
	end
	for i = 0, count - 1 do
		counts[lengths[i]] += 1
	end
	counts[0] = 0

	local offsets = {}
	local sum = 0
	for i = 1, 15 do
		offsets[i] = sum
		sum += counts[i]
	end

	local symbols = {}
	for i = 0, count - 1 do
		local length = lengths[i]
		if length ~= 0 then
			symbols[offsets[length]] = i
			offsets[length] += 1
		end
	end

	return { counts = counts, symbols = symbols }
end

local FIXED_LENGTH_TREE
local FIXED_DISTANCE_TREE

do
	local litLengths = {}
	for i = 0, 143 do
		litLengths[i] = 8
	end
	for i = 144, 255 do
		litLengths[i] = 9
	end
	for i = 256, 279 do
		litLengths[i] = 7
	end
	for i = 280, 287 do
		litLengths[i] = 8
	end
	FIXED_LENGTH_TREE = buildTree(litLengths, 288)

	local distLengths = {}
	for i = 0, 29 do
		distLengths[i] = 5
	end
	FIXED_DISTANCE_TREE = buildTree(distLengths, 30)
end

local inflate = LPH_NO_VIRTUALIZE(function(input: buffer, startOffset: number, outputSize: number): string
	local output = buffer.create(outputSize)
	local outPos = 0

	local pos = startOffset
	local tag = 0
	local bitCount = 0

	local function getBit(): number
		if bitCount == 0 then
			tag = buffer.readu8(input, pos)
			pos += 1
			bitCount = 8
		end
		local bit = bit32.band(tag, 1)
		tag = bit32.rshift(tag, 1)
		bitCount -= 1
		return bit
	end

	local function getBits(amount: number): number
		local value = 0
		for i = 0, amount - 1 do
			value += bit32.lshift(getBit(), i)
		end
		return value
	end

	local function decodeSymbol(tree): number
		local counts = tree.counts
		local sum, cur, length = 0, 0, 0
		repeat
			cur = cur * 2 + getBit()
			length += 1
			sum += counts[length]
			cur -= counts[length]
		until cur < 0
		return tree.symbols[sum + cur]
	end

	local function inflateBlock(lengthTree, distanceTree): ()
		while true do
			local symbol = decodeSymbol(lengthTree)

			if symbol == 256 then
				return
			end

			if symbol < 256 then
				buffer.writeu8(output, outPos, symbol)
				outPos += 1
			else
				symbol -= 257
				local length = LENGTH_BASE[symbol + 1] + getBits(LENGTH_BITS[symbol + 1])
				local distanceSymbol = decodeSymbol(distanceTree)
				local distance = DIST_BASE[distanceSymbol + 1] + getBits(DIST_BITS[distanceSymbol + 1])

				local from = outPos - distance
				for _ = 1, length do
					buffer.writeu8(output, outPos, buffer.readu8(output, from))
					outPos += 1
					from += 1
				end
			end
		end
	end

	local function inflateStored(): ()
		bitCount = 0
		local length = buffer.readu16(input, pos)
		pos += 4
		for _ = 1, length do
			buffer.writeu8(output, outPos, buffer.readu8(input, pos))
			outPos += 1
			pos += 1
		end
	end

	local function decodeTrees()
		local hlit = getBits(5) + 257
		local hdist = getBits(5) + 1
		local hclen = getBits(4) + 4

		local codeLengths = {}
		for i = 0, 18 do
			codeLengths[i] = 0
		end
		for i = 1, hclen do
			codeLengths[CODE_LENGTH_ORDER[i]] = getBits(3)
		end

		local codeTree = buildTree(codeLengths, 19)

		local lengths = {}
		local num = 0
		while num < hlit + hdist do
			local symbol = decodeSymbol(codeTree)

			if symbol < 16 then
				lengths[num] = symbol
				num += 1
			elseif symbol == 16 then
				local previous = lengths[num - 1]
				for _ = 1, getBits(2) + 3 do
					lengths[num] = previous
					num += 1
				end
			elseif symbol == 17 then
				for _ = 1, getBits(3) + 3 do
					lengths[num] = 0
					num += 1
				end
			else
				for _ = 1, getBits(7) + 11 do
					lengths[num] = 0
					num += 1
				end
			end
		end

		local litLengths = {}
		for i = 0, hlit - 1 do
			litLengths[i] = lengths[i]
		end
		local distLengths = {}
		for i = 0, hdist - 1 do
			distLengths[i] = lengths[hlit + i]
		end

		return buildTree(litLengths, hlit), buildTree(distLengths, hdist)
	end

	local final = 0
	repeat
		final = getBit()
		local blockType = getBits(2)

		if blockType == 0 then
			inflateStored()
		elseif blockType == 1 then
			inflateBlock(FIXED_LENGTH_TREE, FIXED_DISTANCE_TREE)
		elseif blockType == 2 then
			local lengthTree, distanceTree = decodeTrees()
			inflateBlock(lengthTree, distanceTree)
		else
			error("Zip: invalid deflate block type")
		end
	until final == 1

	return buffer.readstring(output, 0, outputSize)
end)

local PROB_INIT = 1024
local TOP_VALUE = 0x1000000
local END_MARKER = 0xFFFFFFFF

local decodeLzma = LPH_NO_VIRTUALIZE(function(input: buffer, propsOffset: number, streamStart: number, outputSize: number): string
	local propsByte = buffer.readu8(input, propsOffset)
	local lc = propsByte % 9
	local rest = math.floor(propsByte / 9)
	local lp = rest % 5
	local pb = math.floor(rest / 5)

	local pbMask = bit32.lshift(1, pb) - 1
	local lpMask = bit32.lshift(1, lp) - 1

	local output = buffer.create(outputSize)
	local outPos = 0

	local pos = streamStart
	local function readByte(): number
		local byte = buffer.readu8(input, pos)
		pos += 1
		return byte
	end

	readByte()
	local code = 0
	for _ = 1, 4 do
		code = bit32.bor(bit32.lshift(code, 8), readByte())
	end
	local range = END_MARKER

	local function decodeBit(probs, index: number): number
		local prob = probs[index]
		local bound = bit32.rshift(range, 11) * prob
		local bit

		if code < bound then
			range = bound
			probs[index] = prob + bit32.rshift(2048 - prob, 5)
			bit = 0
		else
			range -= bound
			code -= bound
			probs[index] = prob - bit32.rshift(prob, 5)
			bit = 1
		end

		if range < TOP_VALUE then
			range = bit32.lshift(range, 8)
			code = bit32.bor(bit32.lshift(code, 8), readByte())
		end

		return bit
	end

	local function decodeDirectBits(count: number): number
		local result = 0
		for _ = 1, count do
			range = bit32.rshift(range, 1)
			code -= range
			local bit
			if code < 0 then
				code += range
				bit = 0
			else
				bit = 1
			end
			result = result * 2 + bit

			if range < TOP_VALUE then
				range = bit32.lshift(range, 8)
				code = bit32.bor(bit32.lshift(code, 8), readByte())
			end
		end
		return result
	end

	local function bitTreeDecode(probs, numBits: number): number
		local m = 1
		for _ = 1, numBits do
			m = m * 2 + decodeBit(probs, m)
		end
		return m - bit32.lshift(1, numBits)
	end

	local function reverseBitTreeDecode(probs, base: number, numBits: number): number
		local m = 1
		local symbol = 0
		for i = 0, numBits - 1 do
			local bit = decodeBit(probs, base + m)
			m = m * 2 + bit
			symbol += bit32.lshift(bit, i)
		end
		return symbol
	end

	local function newLenCoder()
		local low = {}
		local mid = {}
		for i = 1, 16 do
			low[i] = table.create(8, PROB_INIT)
			mid[i] = table.create(8, PROB_INIT)
		end
		return {
			choice = table.create(2, PROB_INIT),
			low = low,
			mid = mid,
			high = table.create(256, PROB_INIT),
		}
	end

	local function lenDecode(coder, posState: number): number
		if decodeBit(coder.choice, 1) == 0 then
			return bitTreeDecode(coder.low[posState + 1], 3)
		elseif decodeBit(coder.choice, 2) == 0 then
			return 8 + bitTreeDecode(coder.mid[posState + 1], 3)
		end
		return 16 + bitTreeDecode(coder.high, 8)
	end

	local isMatch = table.create(192, PROB_INIT)
	local isRep = table.create(12, PROB_INIT)
	local isRepG0 = table.create(12, PROB_INIT)
	local isRepG1 = table.create(12, PROB_INIT)
	local isRepG2 = table.create(12, PROB_INIT)
	local isRep0Long = table.create(192, PROB_INIT)
	local posSlotDecoders = { table.create(64, PROB_INIT), table.create(64, PROB_INIT), table.create(64, PROB_INIT), table.create(64, PROB_INIT) }
	local specPos = table.create(128, PROB_INIT)
	local alignDecoder = table.create(16, PROB_INIT)
	local lenCoder = newLenCoder()
	local repLenCoder = newLenCoder()
	local litProbs = table.create(0x300 * bit32.lshift(1, lc + lp), PROB_INIT)

	local function decodeDistance(length: number): number
		local lenState = if length < 4 then length else 3
		local posSlot = bitTreeDecode(posSlotDecoders[lenState + 1], 6)

		if posSlot < 4 then
			return posSlot
		end

		local numDirect = bit32.rshift(posSlot, 1) - 1
		local dist = bit32.lshift(bit32.bor(2, bit32.band(posSlot, 1)), numDirect)

		if posSlot < 14 then
			dist += reverseBitTreeDecode(specPos, dist - posSlot, numDirect)
		else
			dist += bit32.lshift(decodeDirectBits(numDirect - 4), 4)
			dist += reverseBitTreeDecode(alignDecoder, 0, 4)
		end

		return dist
	end

	local function decodeLiteral(state: number, rep0: number): ()
		local prevByte = if outPos > 0 then buffer.readu8(output, outPos - 1) else 0
		local litState = bit32.lshift(bit32.band(outPos, lpMask), lc) + bit32.rshift(prevByte, 8 - lc)
		local base = 0x300 * litState
		local symbol = 1

		if state >= 7 then
			local matchByte = buffer.readu8(output, outPos - rep0 - 1)
			repeat
				local matchBit = bit32.band(bit32.rshift(matchByte, 7), 1)
				matchByte = bit32.band(bit32.lshift(matchByte, 1), 0xFF)
				local bit = decodeBit(litProbs, base + bit32.lshift(1 + matchBit, 8) + symbol)
				symbol = symbol * 2 + bit
				if matchBit ~= bit then
					break
				end
			until symbol >= 0x100
		end

		while symbol < 0x100 do
			symbol = symbol * 2 + decodeBit(litProbs, base + symbol)
		end

		buffer.writeu8(output, outPos, bit32.band(symbol, 0xFF))
		outPos += 1
	end

	local state = 0
	local rep0, rep1, rep2, rep3 = 0, 0, 0, 0

	while outPos < outputSize do
		local posState = bit32.band(outPos, pbMask)

		if decodeBit(isMatch, state * 16 + posState + 1) == 0 then
			decodeLiteral(state, rep0)
			if state < 4 then
				state = 0
			elseif state < 10 then
				state -= 3
			else
				state -= 6
			end
			continue
		end

		local length

		if decodeBit(isRep, state + 1) ~= 0 then
			if decodeBit(isRepG0, state + 1) == 0 then
				if decodeBit(isRep0Long, state * 16 + posState + 1) == 0 then
					state = if state < 7 then 9 else 11
					buffer.writeu8(output, outPos, buffer.readu8(output, outPos - rep0 - 1))
					outPos += 1
					continue
				end
			else
				local dist
				if decodeBit(isRepG1, state + 1) == 0 then
					dist = rep1
				else
					if decodeBit(isRepG2, state + 1) == 0 then
						dist = rep2
					else
						dist = rep3
						rep3 = rep2
					end
					rep2 = rep1
				end
				rep1 = rep0
				rep0 = dist
			end
			length = lenDecode(repLenCoder, posState)
			state = if state < 7 then 8 else 11
		else
			rep3 = rep2
			rep2 = rep1
			rep1 = rep0
			length = lenDecode(lenCoder, posState)
			state = if state < 7 then 7 else 10
			rep0 = decodeDistance(length)
			if rep0 == END_MARKER then
				break
			end
		end

		length += 2
		local from = outPos - rep0 - 1
		for _ = 1, length do
			buffer.writeu8(output, outPos, buffer.readu8(output, from))
			outPos += 1
			from += 1
		end
	end

	return buffer.readstring(output, 0, outputSize)
end)

export type Data = {
	name: string,
	content: string?,
	size: number?,
	isDirectory: boolean,
}

type Entry = {
	name: string,
	flag: number,
	method: number,
	compressedSize: number,
	uncompressedSize: number,
	localOffset: number,
}

local ZipReader = {}
ZipReader.__index = ZipReader

function ZipReader.new(content: buffer)
	local self = setmetatable({}, ZipReader)
	self.content = content
	self.entries = {} :: { Entry }
	self.index = 0

	self:parse()

	return self
end

function ZipReader.parse(self): ()
	local content = self.content
	local size = buffer.len(content)

	if size < EOCD_SIZE then
		error("Not a valid zip file!")
	end

	local eocd = -1
	local minPos = math.max(0, size - EOCD_SIZE - MAX_COMMENT)
	for i = size - EOCD_SIZE, minPos, -1 do
		if buffer.readu32(content, i) == EOCD_SIGNATURE then
			eocd = i
			break
		end
	end

	if eocd < 0 then
		error("Not a valid zip file!")
	end

	local total = buffer.readu16(content, eocd + 10)
	local pos = buffer.readu32(content, eocd + 16)

	for _ = 1, total do
		if buffer.readu32(content, pos) ~= CDIR_SIGNATURE then
			break
		end

		local flag = buffer.readu16(content, pos + 8)
		local method = buffer.readu16(content, pos + 10)
		local compressedSize = buffer.readu32(content, pos + 20)
		local uncompressedSize = buffer.readu32(content, pos + 24)
		local nameLength = buffer.readu16(content, pos + 28)
		local extraLength = buffer.readu16(content, pos + 30)
		local commentLength = buffer.readu16(content, pos + 32)
		local localOffset = buffer.readu32(content, pos + 42)
		local name = buffer.readstring(content, pos + CDIR_HEADER_SIZE, nameLength)

		self.entries[#self.entries + 1] = {
			name = name,
			flag = flag,
			method = method,
			compressedSize = compressedSize,
			uncompressedSize = uncompressedSize,
			localOffset = localOffset,
		}

		pos += CDIR_HEADER_SIZE + nameLength + extraLength + commentLength
	end
end

function ZipReader.hasNext(self): boolean
	return self.index < #self.entries
end

function ZipReader.next(self): Data?
	self.index += 1
	local entry = self.entries[self.index]
	if not entry then
		return nil
	end

	local name = entry.name
	local isDirectory = name:sub(-1) == "/"

	local data: Data = {
		name = name,
		isDirectory = isDirectory,
	}

	if isDirectory then
		return data
	end

	if bit32.band(entry.flag, FLAG_ENCRYPTED) ~= 0 then
		error(`Zip: encrypted entries are not supported: {name}`)
	end

	local content = self.content
	local localOffset = entry.localOffset
	local nameLength = buffer.readu16(content, localOffset + 26)
	local extraLength = buffer.readu16(content, localOffset + 28)
	local dataStart = localOffset + LOCAL_HEADER_SIZE + nameLength + extraLength

	if entry.method == METHOD_STORED then
		data.content = buffer.readstring(content, dataStart, entry.compressedSize)
	elseif entry.uncompressedSize == 0 then
		data.content = ""
	elseif entry.method == METHOD_DEFLATE then
		data.content = inflate(content, dataStart, entry.uncompressedSize)
	elseif entry.method == METHOD_LZMA then
		local propsSize = buffer.readu16(content, dataStart + 2)
		data.content = decodeLzma(content, dataStart + 4, dataStart + 4 + propsSize, entry.uncompressedSize)
	else
		error(`Zip: unsupported compression method {entry.method}`)
	end

	data.size = entry.uncompressedSize
	return data
end

return {
	read = function(file: buffer)
		return ZipReader.new(file)
	end,
}
