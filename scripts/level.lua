-- level — the region: Ridgeback Pass and the sky beyond it.
--
-- West to east (+x), the walkable band is y -4..4, with cliffs rising
-- behind it and a sea of cloud below:
--
--   -10..14  our camp on the mountain shoulder: two commanders, a few
--            soldiers, a cannon covering the valley and a pile of shells
--   15..34   down into the valley; a megaphone crate; their outpost
--   35..37   a chasm, crossed by a narrow ledge at the front
--   38..52   the ridge climbs through Highdale, a mountain town (civilians
--            to enlist, an armory), to their raiders on the crest
--   53..58   the dock, where our airship is moored; a sound system crate
--   59..      open sky: an island with a radio, Skyholm the floating city
--            (more civilians, more guns), their patrol ship, and at the
--            far end their flying fortress, whose flag wins the region.

Level = {}

CAMP_TOP = 6
VALLEY_TOP = 3
DOCK_TOP = 7

-- Ground height along x for the mountain (nil where it's open sky).
function Level.profile(x)
	if x < -10 then
		return nil
	end
	if x <= 14 then
		return CAMP_TOP
	end
	if x <= 16 then
		return 5
	end
	if x <= 18 then
		return 4
	end
	if x <= 34 then
		return VALLEY_TOP
	end
	if x <= 37 then
		return -1 -- the chasm (bridged at the front)
	end
	if x <= 52 then
		local step = flr((x - 38) / 3)
		return 3 + step
	end
	if x <= 58 then
		return DOCK_TOP
	end
	return nil
end

function Level.build_terrain()
	T.init()
	local x = 0
	local y = 0
	local h = 0
	local top = 0
	local cap = ""
	for x = -12, 58 do
		h = Level.profile(x)
		if h ~= nil then
			for y = -5, 8 do
				top = h
				if h < 0 then
					-- the chasm: only the ledge at the front, and the cliffs
					if y == -4 or y == -3 then
						top = VALLEY_TOP
					elseif y >= 5 then
						top = VALLEY_TOP + 2
					else
						top = nil
					end
				end
				if top ~= nil then
					if y == -5 then
						top = top - 1
					elseif y >= 5 then
						local n = irnd(0, 1)
						top = top + (y - 4) * 2 + n
					end
					if x <= -9 then
						top = 14 -- the mountain closes off the west
					end
					cap = "grass"
					if top >= 11 then
						cap = "snow"
					elseif y >= 6 or x <= -9 then
						cap = "rock"
					end
					T.col(x, y, top, -6, cap, "rock")
				end
			end
		end
	end
	Level.island(70, 76, -3, 3, 9)
	Level.island(86, 96, -4, 4, 5)
	Level.spires()
	-- a sandbag wall at their outpost, one tile high (you can climb it)
	for y = -3, 2 do
		Level.prop("wood", 27, y, VALLEY_TOP)
	end
end

-- A floating island: flat top at `top`, tapering to a point below.
function Level.island(x0, x1, y0, y1, top)
	local x = 0
	local y = 0
	local edge = 0
	local base = 0
	local cap = ""
	for x = x0, x1 do
		for y = y0, y1 do
			edge = U.min(x - x0, x1 - x)
			edge = U.min(edge, y - y0)
			edge = U.min(edge, y1 - y)
			base = top - 2 - edge * 2
			cap = "grass"
			T.col(x, y, top, base, cap, "rock")
		end
	end
end

-- Mountain spires standing out of the clouds behind the open sky.
function Level.spires()
	local x = 62
	local w = 0
	local top = 0
	local i = 0
	local j = 0
	local cap = ""
	local y = 0
	while x < 140 do
		w = irnd(2, 3)
		top = irnd(11, 18)
		y = irnd(8, 10)
		for i = 0, w - 1 do
			for j = 0, 1 do
				cap = "rock"
				if top - j > 12 then
					cap = "snow"
				end
				T.col(x + i, y + j, top - j, -8, cap, "rock")
			end
		end
		x = x + w + irnd(3, 8)
	end
end

-- One tile standing on the ground at (x, y), raising the column.
function Level.prop(tex, x, y, z)
	tile(tex, x, y, z, 0)
	local k = T.key(x, y)
	local top = T.top[k]
	if top == nil or top < z + 1 then
		T.top[k] = z + 1
	end
	if T.base[k] == nil then
		T.base[k] = z
	end
end

-- A little timber house with a green roof, door facing the camera.
function Level.house(x0, y0, w, d, z)
	local x = 0
	local y = 0
	local hz = 0
	local tex = ""
	for x = x0, x0 + w - 1 do
		for y = y0, y0 + d - 1 do
			for hz = z, z + 1 do
				tex = "lil-house5"
				if y == y0 and hz == z + 1 and (x - x0) % 2 == 1 then
					tex = "lil-house0"
				elseif y == y0 and hz == z and x == x0 + 1 then
					tex = "lil-house8"
				end
				Level.prop(tex, x, y, hz)
			end
			Level.prop("lil-house1", x, y, z + 2)
		end
	end
end

function Level.build_scenery()
	-- camp: a bunkhouse and the flag
	Level.house(-7, 2, 4, 3, CAMP_TOP)
	-- Highdale's houses, stepped up the ridge behind the path
	Level.house(41, 3, 3, 2, 4)
	Level.house(45, 3, 2, 2, 5)
	Level.house(48, 2, 3, 2, 6)
	-- Skyholm
	Level.house(87, 2, 3, 3, 5)
	Level.house(91, 2, 2, 2, 5)
	Level.house(94, 1, 3, 3, 5)

	local f = make("fx11", -3, 1, CAMP_TOP + 0.9, 1.6)
	Level.campfire = make("fire0", 1, 3, CAMP_TOP + 0.6, 1.2)
	Level.fire_t = 0.0
	Level.fire_i = 0

	-- a sea of cloud below everything
	Level.clouds = {}
	local i = 0
	local e = nil
	local x = 0.0
	local y = 0.0
	local z = 0.0
	local s = 0.0
	for i = 1, 34 do
		x = rnd(-10, 150)
		y = rnd(-12, 14)
		z = rnd(-7, -3)
		s = rnd(5, 10)
		e = make("fx18", x, y, z, s)
		local c = {}
		c.e = e
		c.x = x
		c.v = rnd(0.1, 0.35)
		Level.clouds[i] = c
	end

	-- cloud drifting in the chasm, so it reads as a drop and not a path
	local k = 0
	local cy = 0.0
	for k = 1, 6 do
		cy = -2.6 + k * 1.1
		make("fx18", 36, cy, 2.1, 2.2)
	end

	-- a camp dog
	local dog = {}
	dog.e = make("dog0", 3, -1, CAMP_TOP + 0.3, 0.7)
	dog.x = 3.0
	dog.y = -1.0
	dog.tx = 3.0
	dog.ty = -1.0
	dog.t = 0.0
	dog.f = 0.0
	Level.dog = dog
	local ch = make("chicken", 43, 1, 4, 0.5)
	Level.chicken = ch
end

-- -- people and things

-- Where someone set down at (x, y) stands: a ship's deck if one is there
-- (not the top of its balloon), else the rock.
function Level.ground_z(x, y)
	local i = 0
	local s = nil
	local g = nil
	local wall = false
	for i = 1, Ships.n do
		s = Ships.list[i]
		g, wall = Ships.ground(s, x, y, s.z + 0.3)
		if g ~= nil then
			return g
		end
	end
	local top, base = T.at(x, y)
	if top == nil then
		return 0
	end
	return top
end

function Level.soldier(team, x, y, weapon, order, level)
	local z = Level.ground_z(x, y)
	local u = Unit_new(team, false, x, y, z, weapon)
	u.brain = "soldier"
	u.order = order
	u.gx = x
	u.gy = y
	u.level = level or 0
	u.max = u.max + u.level * 15
	u.hp = u.max
	if team == 2 then
		u.face = -1
	end
	return u
end

function Level.civilian(x, y)
	local z = Level.ground_z(x, y)
	local u = Unit_new(0, false, x, y, z, "fist")
	u.brain = "civilian"
	u.hx = x
	u.hy = y
	u.gx = x
	u.gy = y
	u.face = U.sign(rnd(-1, 1))
	return u
end

function Level.commander(team, x, y, name)
	local z = Level.ground_z(x, y)
	local u = Unit_new(team, true, x, y, z, "pistol")
	Cmd.enlist_commander(u, name)
	u.ammo = 18
	if team == 1 then
		u.brain = "our_cmd"
	else
		u.brain = "enemy_cmd"
		u.post_x = x
		u.post_y = y
		u.face = -1
	end
	return u
end

-- Soldiers of theirs following commander c.
function Level.squad(c, n, guns, level)
	local i = 0
	local u = nil
	local w = ""
	for i = 1, n do
		w = "fist"
		if i <= guns then
			w = "pistol"
		end
		-- to the west of their commander, in three files
		local oy = (i % 3 - 1) * 0.9
		local ox = 1 + flr((i - 1) / 3) * 0.8
		u = Level.soldier(c.team, c.x - ox, c.y + oy, w, "follow", level)
		Cmd.join(c, u)
	end
end

function Level.populate()
	-- ours
	local rook = Level.commander(1, 5, -1, "SGT ROOK")
	local asha = Level.commander(1, 2, 1, "LT ASHA")
	local i = 0
	local u = nil
	local w = ""
	for i = 1, 6 do
		w = "fist"
		if i <= 4 then
			w = "pistol"
		end
		local sy = rnd(-2, 2)
		u = Level.soldier(1, 2 + i * 0.7, sy, w, "follow", 0)
		if i <= 2 then
			u.level = 1
			u.kills = 1
		end
		if i % 2 == 0 then
			Cmd.join(asha, u)
		else
			Cmd.join(rook, u)
		end
	end
	Cannons.add(1, 12, 0, CAMP_TOP, 1)
	Piles.add(1, 9, 2, CAMP_TOP, 6)
	Pick.add("ammo", -1, -2, CAMP_TOP, AMMO_BOX)

	-- the valley and their outpost
	Pick.add("megaphone", 21, 1, VALLEY_TOP, 0)
	Level.soldier(2, 29, -2, "pistol", "hold", 0)
	Level.soldier(2, 30, 1, "pistol", "hold", 1)
	Level.soldier(2, 32, 0, "pistol", "hold", 0)
	Level.soldier(2, 31, -1, "fist", "hold", 0)
	Level.soldier(2, 33, 2, "blade", "hold", 1)
	Pick.add("ammo", 33, -3, VALLEY_TOP, AMMO_BOX)

	-- Highdale
	local cx = { 41, 42.5, 43.5, 44.5, 45.5, 46.5, 47.5 }
	local cy = { -1, 1, -2, 0, 1, -1, 2 }
	for i = 1, 7 do
		Level.civilian(cx[i], cy[i])
	end
	Pick.add("blade", 42, 2, 4, 0)
	Pick.add("blade", 44, 2, 5, 0)
	Pick.add("gun", 46, 2, 5, 6)
	Pick.add("ammo", 47, 1, 5, AMMO_BOX)

	-- raiders on the crest above town
	local voss = Level.commander(2, 56, 0, "CAPT VOSS")
	voss.watch = 8 -- far enough off that Highdale isn't his to watch
	Level.squad(voss, 5, 3, 1)
	Pick.add("sound", 57, -2, DOCK_TOP, 0)

	-- our airship at the dock, a cannon on its bow and shells aboard
	local ship = Ships.new(64, 0, DOCK_TOP, 0, 1)
	ship.name = "THE MAGPIE"
	Ships.layout_airship(ship)
	Ships.finish(ship)
	Cannons.add(1, 68, 0, DOCK_TOP, 1)
	Piles.add(1, 66, -1, DOCK_TOP, 5)

	-- the radio island
	Pick.add("radio", 75, 0, 9, 0)
	Level.soldier(2, 72, -1, "pistol", "hold", 0)
	Level.soldier(2, 73, 1, "fist", "hold", 0)
	Level.soldier(2, 74, -2, "pistol", "hold", 1)
	Level.soldier(2, 75, 2, "blade", "hold", 0)

	-- Skyholm
	local sx = { 88, 89.5, 90.5, 92, 93, 94.5 }
	local sy = { -1, 0, -2, 1, -1, -2 }
	for i = 1, 6 do
		Level.civilian(sx[i], sy[i])
	end
	Pick.add("gun", 89, 1, 5, 6)
	Pick.add("gun", 93, 0, 5, 6)
	Pick.add("ammo", 91, -3, 5, AMMO_BOX)
	Pick.add("ammo", 95, -3, 5, AMMO_BOX)
	Pick.add("blade", 87, -3, 5, 0)

	-- their patrol ship
	local them = Ships.new(100, 0, 9, PI, 2)
	them.name = "THE GRACKLE"
	Ships.layout_airship(them)
	Ships.finish(them)
	them.home_z = 9
	them.patrol_a = 84
	them.patrol_b = 104
	them.leg = 1
	local hx, hy, hz = Ships.helm_spot(them)
	local pilot = Level.soldier(2, hx, hy, "pistol", "hold", 1)
	pilot.brain = "pilot"
	pilot.ship = them
	Level.soldier(2, 101, -1, "pistol", "hold", 0)
	Level.soldier(2, 99, 1, "pistol", "hold", 0)
	Level.soldier(2, 98, -1, "fist", "hold", 0)
	Level.soldier(2, 102, 1, "blade", "hold", 1)

	-- the flying fortress
	local fort = Ships.new(122, 0, 9, 0, 2)
	fort.name = "FORTRESS KARG"
	fort.static = true
	fort.home_z = 9
	Ships.layout_fortress(fort)
	Ships.finish(fort)
	Level.fort = fort
	local karg = Level.commander(2, 126, 0, "MAJ KARG")
	Level.squad(karg, 4, 3, 2)
	Level.soldier(2, 117, -2, "pistol", "hold", 1)
	Level.soldier(2, 117, 1, "fist", "hold", 1)
	Level.soldier(2, 119, -1, "blade", "hold", 2)
	Level.soldier(2, 120, 2, "pistol", "hold", 0)
	Cannons.add(2, 118, 2, 9, -1)
	local flag = {}
	Gear.attach(flag, 127, 0, 9)
	flag.ent = make("fx12", flag.x, flag.y, flag.z + 0.9, 1.6)
	Level.flag = flag

	Cmd.sel = 1
end

-- -- ambience

function Level.update(dt)
	Level.fire_t = Level.fire_t + dt
	if Level.fire_t > 0.1 then
		Level.fire_t = 0.0
		Level.fire_i = (Level.fire_i + 1) % 6
		local f = Level.campfire
		f.tex = A.fire[Level.fire_i]
	end
	local i = 0
	local c = nil
	local e = nil
	for i = 1, #Level.clouds do
		c = Level.clouds[i]
		c.x = c.x + c.v * dt
		if c.x > 160 then
			c.x = -20
		end
		e = c.e
		e.x = c.x
	end
	Level.update_dog(dt)
	local fl = Level.flag
	if fl ~= nil then
		Gear.follow(fl)
		e = fl.ent
		e.x = fl.x
		e.y = fl.y
		e.z = fl.z + 0.9
	end
end

function Level.update_dog(dt)
	local d = Level.dog
	d.t = d.t - dt
	if d.t <= 0 then
		d.t = rnd(1.5, 4)
		d.tx = rnd(-4, 10)
		d.ty = rnd(-3, 1)
	end
	local dx = d.tx - d.x
	local dy = d.ty - d.y
	local len = sqrt(dx * dx + dy * dy)
	local e = d.e
	if len > 0.2 then
		d.x = d.x + dx / len * 2.2 * dt
		d.y = d.y + dy / len * 2.2 * dt
		d.f = d.f + dt * 10
		local fi = flr(d.f) % 7
		local name = "dog" .. tostring(fi)
		e.tex = name
		e.flipped = dx < 0
	end
	e.x = d.x
	e.y = d.y
end
