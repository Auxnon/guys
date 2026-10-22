-- ships — airships and flying fortresses: blocks that fly together.
--
-- The airship idea comes from sosh (~/projects/sosh: server/native/universe/
-- src/ships.rs flies them, client/scripts/ships.lua draws them), brought
-- here single-player: the flight step that lived on the server runs in Lua.
--
-- A ship is a grid of blocks in its own frame (+x ahead, +y to port, z up;
-- a block at (x, y, z) spans x-0.5..x+0.5, y-0.5..y+0.5, z..z+1, and the
-- deck's top is local z 0) and a pose placing that frame in the world,
-- turning only about z. It's drawn as one entity owning a tile grid of its
-- blocks (`ent:tile`), scaled to nothing so only the tiles show, so the
-- whole ship moves and turns as one.
--
-- Whoever stands at the helm steers: thrust ahead or astern, turn, climb or
-- sink. Every axis closes slowly on what the pilot asks (SHIP_ACCEL) — these
-- are clunky old gasbags. A ship can't fly into rock or another ship: it
-- slides along what it can't go through. Anyone standing on deck is carried
-- by the change in pose each frame (Ships.carry), so riders never part from
-- it.

Ships = { list = {}, n = 0 }

SHIP_SPEED = 2.6 -- tiles a second, flat out
SHIP_CLIMB = 1.3
SHIP_TURN = 0.35 -- radians a second, hard over
SHIP_ACCEL = 0.55 -- rate it closes on what the pilot asks, per second
SHIP_INSET = 0.12 -- collision points sit this far inside a block's faces
HELM_REACH = 2.4
SHIP_Z_MIN = 1
SHIP_Z_MAX = 15
SHIP_X_MIN = -14
SHIP_X_MAX = 150

B_HULL = 1
B_DECK = 2
B_RAIL = 3
B_HELM = 4
B_MAST = 5
B_BALLOON = 6
B_STONE = 7
B_WALL = 8
B_ROOF = 9

BLOCK_TEX = { "hull", "deck", "rail", "helm", "wood", "balloon", "stone", "lil-house5", "lil-house1" }
-- blocks you can't step up onto (they hold the crew in)
BLOCK_WALL = { false, false, true, true, true, true, false, true, true }

function Ships.key(x, y, z)
	return (x + 32) * 4096 + (y + 32) * 64 + (z + 32)
end

function Ships.new(x, y, z, h, team)
	local s = {}
	s.x = x
	s.y = y
	s.z = z
	s.h = h
	s.px = x
	s.py = y
	s.pz = z
	s.ph = h
	s.team = team
	s.speed = 0.0
	s.vz = 0.0
	s.spin = 0.0
	s.thrust = 0.0
	s.turn = 0.0
	s.lift = 0.0
	s.pilot = nil
	s.cells = {}
	s.nc = 0
	s.map = {}
	s.static = false
	s.name = "AIRSHIP"
	Ships.n = Ships.n + 1
	Ships.list[Ships.n] = s
	return s
end

function Ships.put(s, x, y, z, b)
	local k = Ships.key(x, y, z)
	if s.map[k] == nil then
		s.nc = s.nc + 1
		local c = { x, y, z, b }
		s.cells[s.nc] = c
	end
	s.map[k] = b
	if b == B_HELM then
		local hc = { x, y, z }
		s.helm = hc
	end
end

function Ships.block_at(s, x, y, z)
	local k = Ships.key(x, y, z)
	return s.map[k]
end

-- The standard airship, after sosh's `standard_blocks`: a hull, a railed
-- deck, the helm at the stern and a balloon on masts. Here the region runs
-- along x, so ships moor nose or tail to the shore and to each other: the
-- bow and stern are open gangways and the sides are railed all the way
-- (sosh's opened amidships instead). The balloon sits high and to the back
-- so the camera can see the deck under it.
function Ships.layout_airship(s)
	local x = 0
	local y = 0
	local z = 0
	for x = -2, 2 do
		Ships.put(s, x, 0, -3, B_HULL)
	end
	for x = -4, 3 do
		for y = -1, 1 do
			Ships.put(s, x, y, -2, B_HULL)
		end
	end
	for x = -5, 5 do
		for y = -2, 2 do
			Ships.put(s, x, y, -1, B_DECK)
		end
	end
	for x = -5, 5 do
		Ships.put(s, x, 2, 0, B_RAIL)
		Ships.put(s, x, -2, 0, B_RAIL)
	end
	-- the wheel stands to the back, clear of the stern gangway
	Ships.put(s, -4, 1, 0, B_HELM)
	local masts = { -3, 3 }
	local i = 0
	for i = 1, 2 do
		x = masts[i]
		for z = 0, 3 do
			Ships.put(s, x, 2, z, B_MAST)
		end
	end
	for x = -4, 4 do
		for y = 1, 2 do
			for z = 4, 5 do
				Ships.put(s, x, y, z, B_BALLOON)
			end
		end
	end
end

-- A flying fortress: a floating rock with stone walls and corner towers,
-- open to the west where boarders come in, and the enemy flag at its heart.
function Ships.layout_fortress(s)
	local x = 0
	local y = 0
	local z = 0
	local d = 0
	-- the rock it's built on, tapering to a point below
	for z = -6, -1 do
		d = -z - 1
		for x = -9 + d, 9 - d do
			for y = -4 + flr(d / 2), 4 - flr(d / 2) do
				if z == -1 then
					Ships.put(s, x, y, z, B_STONE)
				else
					Ships.put(s, x, y, z, B_HULL)
				end
			end
		end
	end
	-- walls round the edge, two high, the west side left open
	for x = -9, 9 do
		Ships.put(s, x, 4, 0, B_WALL)
		Ships.put(s, x, 4, 1, B_WALL)
		if x > -6 then
			Ships.put(s, x, -4, 0, B_RAIL)
		end
	end
	for y = -4, 4 do
		Ships.put(s, 9, y, 0, B_WALL)
		Ships.put(s, 9, y, 1, B_WALL)
	end
	-- towers at the far corners, and a keep at the back
	for z = 0, 4 do
		Ships.put(s, 9, 4, z, B_WALL)
		Ships.put(s, -9, 4, z, B_WALL)
	end
	Ships.put(s, 9, 4, 5, B_ROOF)
	Ships.put(s, -9, 4, 5, B_ROOF)
	for x = 4, 8 do
		for z = 0, 2 do
			Ships.put(s, x, 3, z, B_WALL)
		end
		Ships.put(s, x, 3, 3, B_ROOF)
	end
	-- a low barricade mid-deck to fight round
	for y = -2, 0 do
		Ships.put(s, -1, y, 0, B_RAIL)
	end
end

-- Work out what collision and drawing need once the blocks are in: the
-- columns (one per x, y with their lowest and highest block), the box the
-- blocks fill, and the entity with a tile per block.
function Ships.finish(s)
	local cols = {}
	local byk = {}
	local nc = 0
	local i = 0
	local c = nil
	local k = 0
	local col = nil
	local lox = 99
	local hix = -99
	local loy = 99
	local hiy = -99
	local loz = 99
	local hiz = -99
	for i = 1, s.nc do
		c = s.cells[i]
		k = (c[1] + 32) * 64 + (c[2] + 32)
		col = byk[k]
		if col == nil then
			col = {}
			col.x = c[1]
			col.y = c[2]
			col.lo = c[3]
			col.hi = c[3]
			nc = nc + 1
			cols[nc] = col
			byk[k] = col
		end
		if c[3] < col.lo then
			col.lo = c[3]
		end
		if c[3] > col.hi then
			col.hi = c[3]
		end
		lox = U.min(lox, c[1])
		hix = U.max(hix, c[1])
		loy = U.min(loy, c[2])
		hiy = U.max(hiy, c[2])
		loz = U.min(loz, c[3])
		hiz = U.max(hiz, c[3])
	end
	s.cols = cols
	s.ncols = nc
	s.lox = lox - 0.5
	s.hix = hix + 0.5
	s.loy = loy - 0.5
	s.hiy = hiy + 0.5
	s.loz = loz
	s.hiz = hiz + 1
	local ax = U.max(-s.lox, s.hix)
	local ay = U.max(-s.loy, s.hiy)
	s.rad = sqrt(ax * ax + ay * ay)
	Ships.build(s)
end

function Ships.build(s)
	if s.ent ~= nil then
		s.ent:kill()
	end
	local e = make("hull", s.x, s.y, s.z, 0)
	local i = 0
	local c = nil
	local name = ""
	for i = 1, s.nc do
		c = s.cells[i]
		name = BLOCK_TEX[c[4]]
		e:tile(name, c[1], c[2], c[3], 0)
	end
	e.rz = s.h
	s.ent = e
end

-- -- frames

function Ships.to_world(s, lx, ly, lz)
	local c = cos(s.h)
	local n = sin(s.h)
	return s.x + lx * c - ly * n, s.y + lx * n + ly * c, s.z + lz
end

function Ships.to_local(s, x, y, z)
	local c = cos(s.h)
	local n = sin(s.h)
	local dx = x - s.x
	local dy = y - s.y
	return dx * c + dy * n, -dx * n + dy * c, z - s.z
end

-- Where a world point that rode on `s` last frame is now, and how much the
-- ship turned.
function Ships.carry(s, x, y, z)
	local c = cos(s.ph)
	local n = sin(s.ph)
	local dx = x - s.px
	local dy = y - s.py
	local lx = dx * c + dy * n
	local ly = -dx * n + dy * c
	local wx, wy, wz = Ships.to_world(s, lx, ly, z - s.pz)
	local dh = U.angle_diff(s.ph, s.h)
	return wx, wy, wz, dh
end

-- -- standing on it

-- As W.ground, for this ship alone: the deck (or any block top) under feet
-- at world (x, y, z) no more than STEP up, and whether a wall stands there.
function Ships.ground(s, x, y, z)
	local dx = x - s.x
	local dy = y - s.y
	local r = s.rad + 1
	if dx * dx + dy * dy > r * r then
		return nil, false
	end
	local lx, ly, lz = Ships.to_local(s, x, y, z)
	if lz < s.loz - 2 or lz > s.hiz + 1 then
		return nil, false
	end
	local cx = flr(lx + 0.5)
	local cy = flr(ly + 0.5)
	local top = flr(lz + 0.05)
	local wall = false
	local b = Ships.block_at(s, cx, cy, top + 1)
	if b ~= nil then
		wall = true
	end
	local bz = 0
	for bz = top, top - 8, -1 do
		b = Ships.block_at(s, cx, cy, bz)
		if b ~= nil then
			if BLOCK_WALL[b] and bz + 1 > lz + 0.05 then
				return nil, true
			end
			return s.z + bz + 1, wall
		end
	end
	return nil, wall
end

-- The ship with a block at world point (x, y, z), or nil.
function Ships.solid_at(x, y, z)
	local i = 0
	local s = nil
	local dx = 0.0
	local dy = 0.0
	local r = 0.0
	local lx = 0.0
	local ly = 0.0
	local lz = 0.0
	local cx = 0
	local cy = 0
	local cz = 0
	for i = 1, Ships.n do
		s = Ships.list[i]
		dx = x - s.x
		dy = y - s.y
		r = s.rad + 0.5
		if dx * dx + dy * dy <= r * r then
			lx, ly, lz = Ships.to_local(s, x, y, z)
			cx = flr(lx + 0.5)
			cy = flr(ly + 0.5)
			cz = flr(lz)
			if Ships.block_at(s, cx, cy, cz) ~= nil then
				return s
			end
		end
	end
	return nil
end

-- Feet at the helm: where the pilot stands, a step ahead of the wheel.
function Ships.helm_spot(s)
	local hc = s.helm
	if hc == nil then
		return nil
	end
	return Ships.to_world(s, hc[1] + 1, hc[2], 0)
end

-- A ship whose helm the feet at (x, y, z) can reach, or nil.
function Ships.helm_near(x, y, z)
	local i = 0
	local s = nil
	local hx = 0.0
	local hy = 0.0
	local hz = 0.0
	for i = 1, Ships.n do
		s = Ships.list[i]
		if s.helm ~= nil then
			hx, hy, hz = Ships.helm_spot(s)
			local d = U.d2(x, y, hx, hy)
			if d < HELM_REACH * HELM_REACH and U.abs(z - hz) < 1.5 then
				return s
			end
		end
	end
	return nil
end

-- -- flying

-- Would ship `s` overlap rock or another ship at this pose?
function Ships.collides(s, x, y, z, h)
	if Ships.hits_terrain(s, x, y, z, h) then
		return true
	end
	local i = 0
	local o = nil
	for i = 1, Ships.n do
		o = Ships.list[i]
		if o ~= s and Ships.hits_ship(s, x, y, z, h, o) then
			return true
		end
	end
	return false
end

-- Each column of blocks is tested at its four corners, pulled in by
-- SHIP_INSET, against the rock column there (a ship only yaws, so a column
-- stays a column).
function Ships.hits_terrain(s, x, y, z, h)
	local c = cos(h)
	local n = sin(h)
	local e = 0.5 - SHIP_INSET
	local i = 0
	local j = 0
	local col = nil
	local lx = 0.0
	local ly = 0.0
	local wx = 0.0
	local wy = 0.0
	local lo = 0.0
	local hi = 0.0
	local top = nil
	local base = nil
	for i = 1, s.ncols do
		col = s.cols[i]
		lo = z + col.lo + SHIP_INSET
		hi = z + col.hi + 1 - SHIP_INSET
		for j = 1, 4 do
			lx = col.x - e
			ly = col.y - e
			if j == 2 or j == 4 then
				lx = col.x + e
			end
			if j > 2 then
				ly = col.y + e
			end
			wx = x + lx * c - ly * n
			wy = y + lx * n + ly * c
			top, base = T.at(wx, wy)
			if top ~= nil and top > lo and base < hi then
				return true
			end
		end
	end
	return false
end

-- The world box a ship's blocks fill at a pose.
function Ships.box(s, x, y, h)
	local c = cos(h)
	local n = sin(h)
	local ax = U.abs(c)
	local an = U.abs(n)
	local mx = (s.lox + s.hix) / 2
	local my = (s.loy + s.hiy) / 2
	local hx = (s.hix - s.lox) / 2
	local hy = (s.hiy - s.loy) / 2
	local cx = x + mx * c - my * n
	local cy = y + mx * n + my * c
	local ex = hx * ax + hy * an
	local ey = hx * an + hy * ax
	return cx - ex, cx + ex, cy - ey, cy + ey
end

-- Ships bump as boxes: close enough for craft that mostly fly level and
-- square, and it lets decks come right alongside for boarding.
function Ships.hits_ship(s, x, y, z, h, o)
	local gap = U.dist(x, y, o.x, o.y)
	if gap > s.rad + o.rad + 1 then
		return false
	end
	local ax0, ax1, ay0, ay1 = Ships.box(s, x, y, h)
	local bx0, bx1, by0, by1 = Ships.box(o, o.x, o.y, o.h)
	local i = SHIP_INSET * 2
	if ax1 - i <= bx0 or bx1 - i <= ax0 then
		return false
	end
	if ay1 - i <= by0 or by1 - i <= ay0 then
		return false
	end
	if z + s.hiz - i <= o.z + o.loz or o.z + o.hiz - i <= z + s.loz then
		return false
	end
	return true
end

-- Move for dt as the helm asks; ported from sosh's Ship::step.
function Ships.step(s, dt)
	local k = U.ease(SHIP_ACCEL, dt)
	s.speed = s.speed + (s.thrust * SHIP_SPEED - s.speed) * k
	s.spin = s.spin + (s.turn * SHIP_TURN - s.spin) * k
	s.vz = s.vz + (s.lift * SHIP_CLIMB - s.vz) * k
	if U.abs(s.speed) < 0.01 then
		s.speed = 0.0
	end
	if U.abs(s.spin) < 0.005 then
		s.spin = 0.0
	end
	if U.abs(s.vz) < 0.01 then
		s.vz = 0.0
	end
	if s.speed == 0.0 and s.spin == 0.0 and s.vz == 0.0 then
		return
	end
	-- wedged in already: let it move until it's free
	local stuck = Ships.collides(s, s.x, s.y, s.z, s.h)
	local x = s.x
	local y = s.y
	local z = s.z
	local h = s.h
	local hit = false
	if s.spin ~= 0.0 then
		local nh = U.wrap(h + s.spin * dt)
		hit = Ships.collides(s, x, y, z, nh)
		if stuck or not hit then
			h = nh
		else
			s.spin = 0.0
		end
	end
	local c = cos(h)
	local n = sin(h)
	local dx = c * s.speed * dt
	local dy = n * s.speed * dt
	local blocked = 0
	if dx ~= 0.0 then
		hit = Ships.collides(s, x + dx, y, z, h)
		if stuck or not hit then
			x = x + dx
		else
			blocked = blocked + 1
		end
	end
	if U.abs(dy) > 0.0001 then
		hit = Ships.collides(s, x, y + dy, z, h)
		if stuck or not hit then
			y = y + dy
		else
			blocked = blocked + 1
		end
	end
	if blocked > 0 and U.abs(s.speed) > 0.6 then
		Sfx.bump()
	end
	if blocked == 2 or (blocked == 1 and U.abs(dy) < 0.0001) then
		s.speed = s.speed * 0.3
	end
	if s.vz ~= 0.0 then
		local nz = z + s.vz * dt
		nz = U.clamp(nz, SHIP_Z_MIN, SHIP_Z_MAX)
		hit = Ships.collides(s, x, y, nz, h)
		if stuck or not hit then
			z = nz
		else
			s.vz = 0.0
		end
	end
	x = U.clamp(x, SHIP_X_MIN, SHIP_X_MAX)
	s.x = x
	s.y = y
	s.z = z
	s.h = h
end

-- Remember last frame's pose (riders are carried by the difference), fly,
-- and move the drawing.
function Ships.update(dt)
	local i = 0
	local s = nil
	local e = nil
	for i = 1, Ships.n do
		s = Ships.list[i]
		s.px = s.x
		s.py = s.y
		s.pz = s.z
		s.ph = s.h
		if s.static then
			-- a fortress only bobs on its engines
			s.z = s.home_z + sin(G.time * 0.6) * 0.12
		else
			if s.pilot == nil or s.pilot.dead then
				s.pilot = nil
				s.thrust = 0.0
				s.turn = 0.0
				s.lift = 0.0
			end
			if s.team == 2 then
				Ships.ai(s, dt)
			end
			Ships.step(s, dt)
		end
		e = s.ent
		e.x = s.x
		e.y = s.y
		e.z = s.z
		e.rz = s.h
	end
end

-- An enemy pilot patrols between two points; once our ship comes within
-- reach it comes alongside at deck height so its crew can shoot and board.
function Ships.ai(s, dt)
	if s.pilot == nil then
		return
	end
	local tx = s.patrol_a
	if s.leg == 2 then
		tx = s.patrol_b
	end
	local tz = s.home_z
	local ours = Ships.player_ship()
	if ours ~= nil then
		local d = U.abs(ours.x - s.x)
		if d < 22 and U.abs(ours.z - s.z) < 8 then
			-- park beside it, on whichever side we're already on
			local side = U.sign(s.x - ours.x)
			local half = (ours.hix - ours.lox) / 2 + (s.hix - s.lox) / 2
			tx = ours.x + side * (half + 0.2)
			tz = ours.z
			s.engaged = true
		end
	end
	local c = cos(s.h)
	local want = (tx - s.x) * c / 3
	s.thrust = U.clamp(want, -1, 1)
	s.lift = U.clamp((tz - s.z) / 2, -1, 1)
	if not s.engaged and U.abs(tx - s.x) < 1.5 then
		if s.leg == 2 then
			s.leg = 1
		else
			s.leg = 2
		end
	end
	s.engaged = false
end

function Ships.player_ship()
	local i = 0
	local s = nil
	for i = 1, Ships.n do
		s = Ships.list[i]
		if s.team == 1 then
			return s
		end
	end
	return nil
end
