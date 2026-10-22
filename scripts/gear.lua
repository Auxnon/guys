-- gear — things lying about to pick up, cannons, and their munitions.
--
-- Pickups: pistols (with whatever rounds were left in them), boxes of
-- rounds, blades, and comm-tech crates (megaphone, radio, sound system)
-- that only a commander can use. Guns are in hot demand: anyone who dies
-- with a pistol drops it, and unarmed soldiers nearby go for it (ai.lua).
--
-- Cannons don't load themselves. A crew assigned to one (the "haul" order)
-- walks shells one at a time from the nearest munitions pile of their side
-- to the cannon; it fires whatever's in it at hostiles in range. Cannons
-- and piles can sit on a ship's deck and ride along with it.

Gear = {}
Pick = { list = {}, n = 0 }
Cannons = { list = {}, n = 0 }
Piles = { list = {}, n = 0 }

PICK_REACH = 0.7
CANNON_RANGE = 24
CANNON_MIN = 3.5
CANNON_GAP = 2.4
CANNON_HOLD = 4 -- shells a cannon holds
AMMO_BOX = 12

PICK_TEX = { gun = "fx20", ammo = "fx21", blade = "fx22", megaphone = "fx8", radio = "fx9", sound = "fx10" }

-- Somewhere a prop sits: either the world, or a deck (`ship` set and
-- lx, ly, lz in its frame).
function Gear.attach(p, x, y, z)
	local g, wall, ship = W.ground(x, y, z + 0.5)
	if g == nil then
		g = z
	end
	p.x = x
	p.y = y
	p.z = g
	p.ship = ship
	if ship ~= nil then
		local lx, ly, lz = Ships.to_local(ship, x, y, g)
		p.lx = lx
		p.ly = ly
		p.lz = lz
	end
end

function Gear.follow(p)
	local s = p.ship
	if s ~= nil then
		local x, y, z = Ships.to_world(s, p.lx, p.ly, p.lz)
		p.x = x
		p.y = y
		p.z = z
	end
end

-- -- pickups

function Pick.add(kind, x, y, z, n)
	local p = {}
	p.kind = kind
	p.n = n or 0
	p.taken = false
	p.bob = rnd() * tau
	Gear.attach(p, x, y, z)
	local name = PICK_TEX[kind]
	local scale = 0.6
	if kind == "megaphone" or kind == "radio" or kind == "sound" then
		scale = 0.9
	end
	local e = make(name, p.x, p.y, p.z + 0.4, scale)
	p.ent = e
	Pick.n = Pick.n + 1
	Pick.list[Pick.n] = p
	return p
end

-- The nearest pickup of a kind `u` can use within r, or nil.
function Pick.wanted(u, r)
	local best = nil
	local bd = r * r
	local i = 0
	local p = nil
	local d = 0.0
	local want = false
	for i = 1, Pick.n do
		p = Pick.list[i]
		if not p.taken and U.abs(p.z - u.z) < 1.5 then
			want = Pick.useful(u, p)
			if want then
				d = U.d2(u.x, u.y, p.x, p.y)
				if d < bd then
					bd = d
					best = p
				end
			end
		end
	end
	return best
end

function Pick.useful(u, p)
	if u.team == 0 then
		return false
	end
	local k = p.kind
	if k == "megaphone" or k == "radio" or k == "sound" then
		return u.cmd and u.team == 1 and Cmd.tech_of(k) > u.tech
	end
	if k == "gun" then
		if u.weapon ~= "pistol" then
			return true
		end
		return p.n > 0 and u.mag + u.ammo < 18
	end
	if k == "ammo" then
		return u.weapon == "pistol" and u.mag + u.ammo < 18
	end
	if k == "blade" then
		return u.weapon == "fist"
	end
	return false
end

function Pick.take(u, p)
	p.taken = true
	local e = p.ent
	e.z = -100
	local k = p.kind
	if k == "gun" then
		if u.weapon ~= "pistol" then
			if u.weapon == "blade" then
				-- swap: the blade stays for someone with bare fists
				Pick.add("blade", p.x, p.y, p.z, 0)
			end
			Unit.arm(u, "pistol")
			u.mag = 0
			Unit.give_ammo(u, p.n)
			Unit.flash_icon(u, "fx20", 1.0)
		else
			Unit.give_ammo(u, p.n)
			-- the empty gun stays for someone who has none
			if not u.cmd then
				Pick.add("gun", p.x, p.y, p.z, 0)
			end
		end
	elseif k == "ammo" then
		Unit.give_ammo(u, p.n)
		Unit.flash_icon(u, "fx21", 1.0)
	elseif k == "blade" then
		Unit.arm(u, "blade")
		Unit.flash_icon(u, "fx22", 1.0)
	else
		Cmd.upgrade(u, k)
	end
	if u.team == 1 then
		Sfx.pickup()
	end
end

-- Anyone standing on something they can use takes it.
function Pick.update(dt)
	local i = 0
	local p = nil
	local e = nil
	local j = 0
	local u = nil
	for i = 1, Pick.n do
		p = Pick.list[i]
		if not p.taken then
			Gear.follow(p)
			p.bob = p.bob + dt * 3
			e = p.ent
			e.x = p.x
			e.y = p.y
			e.z = p.z + 0.35 + sin(p.bob) * 0.06
			for j = 1, Units.n do
				u = Units.list[j]
				if not u.dead and not p.taken and U.abs(u.z - p.z) < 1.0 then
					if U.d2(u.x, u.y, p.x, p.y) < PICK_REACH * PICK_REACH then
						if Pick.useful(u, p) then
							Pick.take(u, p)
						end
					end
				end
			end
		end
	end
end

-- -- munitions piles

function Piles.add(team, x, y, z, stock)
	local p = {}
	p.team = team
	p.stock = stock
	Gear.attach(p, x, y, z)
	local e = make("fx24", p.x, p.y, p.z + 0.4, 0.9)
	p.ent = e
	Piles.n = Piles.n + 1
	Piles.list[Piles.n] = p
	return p
end

function Piles.nearest(team, x, y, z)
	local best = nil
	local bd = 60 * 60
	local i = 0
	local p = nil
	local d = 0.0
	for i = 1, Piles.n do
		p = Piles.list[i]
		if p.team == team and p.stock > 0 then
			d = U.d2(x, y, p.x, p.y) + (p.z - z) * (p.z - z) * 4
			if d < bd then
				bd = d
				best = p
			end
		end
	end
	return best
end

-- -- cannons

function Cannons.add(team, x, y, z, face)
	local c = {}
	c.team = team
	c.face = face
	c.loaded = 0
	c.cd = 0.0
	c.self_load = 0.0
	Gear.attach(c, x, y, z)
	local e = make("fx25", c.x, c.y, c.z + 0.6, 1.3)
	e.flipped = face < 0
	c.ent = e
	Cannons.n = Cannons.n + 1
	Cannons.list[Cannons.n] = c
	return c
end

-- The cannon nearest world point (x, y) within r, or nil.
function Cannons.near(x, y, z, r)
	local best = nil
	local bd = r * r
	local i = 0
	local c = nil
	local d = 0.0
	for i = 1, Cannons.n do
		c = Cannons.list[i]
		if U.abs(c.z - z) < 3 then
			d = U.d2(x, y, c.x, c.y)
			if d < bd then
				bd = d
				best = c
			end
		end
	end
	return best
end

-- A target for cannon `c`: the hostile in range it would hurt most (the
-- one with the most company), or nil.
function Cannons.target(c)
	local best = nil
	local score = 0
	local i = 0
	local o = nil
	local d = 0.0
	local j = 0
	local q = nil
	local n = 0
	for i = 1, Units.n do
		o = Units.list[i]
		if not o.dead and o.team ~= 0 and o.team ~= c.team then
			d = U.dist(c.x, c.y, o.x, o.y)
			if d < CANNON_RANGE and d > CANNON_MIN and (o.x - c.x) * c.face > 0 then
				n = 1
				for j = 1, Units.n do
					q = Units.list[j]
					if q ~= o and not q.dead and q.team == o.team then
						if U.d2(o.x, o.y, q.x, q.y) < 4 then
							n = n + 1
						end
					end
				end
				if n > score then
					score = n
					best = o
				end
			end
		end
	end
	return best
end

function Cannons.update(dt)
	local i = 0
	local c = nil
	local e = nil
	local t = nil
	local crew = {}
	local n = 0
	for i = 1, Cannons.n do
		c = Cannons.list[i]
		Gear.follow(c)
		e = c.ent
		e.x = c.x
		e.y = c.y
		e.z = c.z + 0.6
		c.cd = c.cd - dt
		-- their gunners keep their own guns fed while anyone's nearby
		if c.team == 2 and c.loaded < CANNON_HOLD then
			n = Units.near(2, c.x, c.y, c.z, 3.5, crew)
			if n > 0 then
				c.self_load = c.self_load + dt
				if c.self_load > 6 then
					c.self_load = 0.0
					c.loaded = c.loaded + 1
				end
			end
		end
		if c.loaded > 0 and c.cd <= 0 then
			t = Cannons.target(c)
			if t ~= nil then
				c.loaded = c.loaded - 1
				c.cd = CANNON_GAP
				Combat.lob(c.x + c.face * 0.7, c.y, c.z + 0.9, t.x, t.y, t.z + 0.2, c.team)
			else
				c.cd = 0.5
			end
		end
	end
end

function Gear.update(dt)
	Pick.update(dt)
	local i = 0
	local p = nil
	local e = nil
	for i = 1, Piles.n do
		p = Piles.list[i]
		Gear.follow(p)
		e = p.ent
		e.x = p.x
		e.y = p.y
		e.z = p.z + 0.4
		if p.stock <= 0 and not p.empty then
			p.empty = true
			e.scale = 0.5
		end
	end
	Cannons.update(dt)
end
