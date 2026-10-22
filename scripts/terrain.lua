-- terrain — the mountains: tiles plus a column lookup, and W, the one ground
-- query everything that walks or flies through the world uses.
--
-- Z-up. A column at integer (x, y) spans x-0.5..x+0.5, y-0.5..y+0.5 and is
-- solid from `base` up to `top` (tiles base..top-1; a tile at z fills
-- z..z+1). T.top/T.base are flat lookups keyed by T.key, so a walker asks
-- "how tall is this column" in O(1) instead of scanning gtile(). Columns
-- with no entry are open air: the abyss.
--
-- W.ground also folds in airship decks (ships.lua), so a soldier walks from
-- a ledge onto a moored ship and is carried off with it without any special
-- case.

T = {}
W = {}

STEP = 1.05 -- the most a walker climbs without a jump
BODY = 1.6 -- a walker's height, for what counts as a wall
ABYSS_Z = -12 -- fall past this and you're gone

function T.init()
	T.top = {}
	T.base = {}
end

-- x in -64..191, y in -32..31.
function T.key(x, y)
	return (x + 64) * 64 + (y + 32)
end

-- Fill column (x, y) from z = base up to top-1 with tiles; the last one
-- gets `cap`, the rest `fill`.
function T.col(x, y, top, base, cap, fill)
	local z = 0
	for z = base, top - 2 do
		tile(fill, x, y, z, 0)
	end
	tile(cap, x, y, top - 1, 0)
	local k = T.key(x, y)
	T.top[k] = top
	T.base[k] = base
end

-- The column under world point (x, y): top, base; nil over the abyss.
function T.at(x, y)
	local cx = flr(x + 0.5)
	local cy = flr(y + 0.5)
	local k = T.key(cx, cy)
	return T.top[k], T.base[k]
end

-- Is world point (x, y, z) inside rock?
function T.solid(x, y, z)
	local top, base = T.at(x, y)
	if top == nil then
		return false
	end
	return z < top and z >= base
end

-- Where feet at (x, y, z) come to rest: the highest surface no more than
-- STEP above them. Returns ground (or nil), wall (true if something too
-- tall to step onto stands there at body height) and the ship whose deck it
-- is (nil for rock).
function W.ground(x, y, z)
	local best = nil
	local ship = nil
	local wall = false
	local top, base = T.at(x, y)
	if top ~= nil then
		if top <= z + STEP then
			best = top
		elseif base < z + BODY then
			wall = true
		end
	end
	local i = 0
	local s = nil
	local sg = nil
	local sw = false
	for i = 1, Ships.n do
		s = Ships.list[i]
		sg, sw = Ships.ground(s, x, y, z)
		if sw then
			wall = true
		end
		if sg ~= nil and (best == nil or sg > best) then
			best = sg
			ship = s
		end
	end
	return best, wall, ship
end

-- Is world point (x, y, z) inside rock or any ship's block?
function W.solid(x, y, z)
	local r = T.solid(x, y, z)
	if r then
		return true
	end
	local s = Ships.solid_at(x, y, z)
	return s ~= nil
end

-- March a ray from (ox, oy, oz) along (dx, dy, dz) until it enters rock or
-- a ship; returns the point just before it, or nil within max_t.
function W.ray(ox, oy, oz, dx, dy, dz, max_t)
	local t = 1.0
	local x = 0.0
	local y = 0.0
	local z = 0.0
	local hit = false
	while t < max_t do
		x = ox + dx * t
		y = oy + dy * t
		z = oz + dz * t
		hit = W.solid(x, y, z)
		if hit then
			-- back off a little, then creep forward finely
			t = t - 0.25
			local k = 0
			for k = 1, 10 do
				x = ox + dx * t
				y = oy + dy * t
				z = oz + dz * t
				hit = W.solid(x, y, z)
				if hit then
					return x, y, z
				end
				t = t + 0.03
			end
			return x, y, z
		end
		t = t + 0.25
	end
	return nil
end
