-- combat — pistols, fists and blades, and cannon shells.
--
-- Pistols hit hard and miss a lot: a shot leaves along the line to its
-- target, thrown off by a wide random spread that tightens with level. Six
-- in the magazine, and rounds are scarce (`u.ammo`), so most fights end up
-- hand to hand anyway. Bullets are a fixed pool of sprites that fly, stop
-- in rock or ship planking, and hit the first hostile body they pass.
--
-- Cannon shells (gear.lua fires them) arc under gravity and burst, hurting
-- and flinging everyone hostile nearby. A shell is a good way to knock a
-- squad off a ledge.

Combat = {}
Bul = { list = {}, n = 0 }
Shells = { list = {}, n = 0 }

BULLET_SPEED = 26.0
BULLET_RANGE = 14.0
BULLET_DMG = 46
SPREAD = 0.24 -- radians either side at level 0
RELOAD_SECS = 2.2
SHOT_GAP = 0.75 -- seconds between shots, roughly
FIST_DMG = 12
BLADE_DMG = 27
MELEE_GAP = 0.5
MELEE_REACH = 0.75
SHELL_G = 16.0
SHELL_SPEED = 13.0
BLAST_R = 2.6
BLAST_DMG = 95

function Combat.init()
	local i = 0
	local b = nil
	local e = nil
	for i = 1, 60 do
		b = {}
		e = make("fx1", 0, 0, -100, 0.32)
		b.ent = e
		b.alive = false
		Bul.list[i] = b
	end
	Bul.n = 60
	for i = 1, 8 do
		b = {}
		e = make("fx23", 0, 0, -100, 0.5)
		b.ent = e
		b.alive = false
		Shells.list[i] = b
	end
	Shells.n = 8
end

function Combat.power(u)
	return 1 + u.level * 0.15
end

-- Can `u` fire right now?
function Combat.ready(u)
	return u.weapon == "pistol" and u.mag > 0 and u.gun_t <= 0 and u.reload_t <= 0
end

-- Fire at a world point.
function Combat.shoot(u, tx, ty, tz)
	if not Combat.ready(u) then
		return false
	end
	local b = nil
	local i = 0
	for i = 1, Bul.n do
		local c = Bul.list[i]
		if not c.alive then
			b = c
			break
		end
	end
	if b == nil then
		return false
	end
	local ox = u.x
	local oy = u.y
	local oz = u.z + 0.78
	local dx = tx - ox
	local dy = ty - oy
	local dz = tz - oz
	local flat = sqrt(dx * dx + dy * dy)
	if flat < 0.01 then
		return false
	end
	local ang = atan2(dy, dx)
	local sp = SPREAD * (1 - u.level * 0.2)
	ang = ang + rnd(-sp, sp)
	local pitch = dz / flat + rnd(-0.08, 0.08)
	local c = cos(ang)
	local s = sin(ang)
	b.x = ox + c * 0.45
	b.y = oy + s * 0.45
	b.z = oz
	b.vx = c * BULLET_SPEED
	b.vy = s * BULLET_SPEED
	b.vz = pitch * BULLET_SPEED
	b.t = BULLET_RANGE / BULLET_SPEED
	b.team = u.team
	b.by = u
	b.dmg = BULLET_DMG * Combat.power(u)
	b.alive = true
	u.mag = u.mag - 1
	u.gun_t = SHOT_GAP * (0.8 + rnd() * 0.6)
	if u.mag == 0 and u.ammo > 0 then
		u.reload_t = RELOAD_SECS
	end
	u.face = U.sign(c)
	Unit.pose(u, FR_SHOOT, 0.22)
	Fx.flash(b.x, b.y, b.z)
	Sfx.shot(u.team)
	return true
end

-- Reloading and gun cool-down tick for everyone with a pistol.
function Combat.tick_gun(u, dt)
	u.gun_t = u.gun_t - dt
	if u.reload_t > 0 then
		u.reload_t = u.reload_t - dt
		if u.reload_t <= 0 then
			local k = U.min(MAG, u.ammo)
			u.mag = u.mag + k
			u.ammo = u.ammo - k
		end
	elseif u.mag == 0 and u.ammo > 0 and u.weapon == "pistol" then
		u.reload_t = RELOAD_SECS
	end
end

-- Swing at `o` if it's in reach.
function Combat.melee(u, o)
	if u.melee_t > 0 then
		return false
	end
	local dx = o.x - u.x
	local dy = o.y - u.y
	local d = sqrt(dx * dx + dy * dy)
	if d > MELEE_REACH or U.abs(o.z - u.z) > 0.8 then
		return false
	end
	if d < 0.01 then
		d = 0.01
	end
	local dmg = FIST_DMG
	local kb = 3.2
	local pose = FR_PUNCH
	if u.weapon == "blade" then
		dmg = BLADE_DMG
		kb = 2.0
		pose = FR_SLASH
	end
	dmg = dmg * Combat.power(u) * (0.8 + rnd() * 0.4)
	u.melee_t = MELEE_GAP * (0.8 + rnd() * 0.5) * (1 - u.level * 0.1)
	u.face = U.sign(dx)
	Unit.pose(u, pose, 0.2)
	Unit.hurt(o, dmg, dx / d * kb, dy / d * kb, u)
	Fx.pow(o.x - dx / d * 0.2, o.y - dy / d * 0.2, o.z + 0.7)
	Sfx.punch()
	return true
end

function Combat.update(dt)
	local i = 0
	local b = nil
	local e = nil
	local k = 0
	local h = 0.0
	for i = 1, Bul.n do
		b = Bul.list[i]
		if b.alive then
			-- two substeps so a fast round can't skip through a body
			for k = 1, 2 do
				if b.alive then
					h = dt * 0.5
					b.x = b.x + b.vx * h
					b.y = b.y + b.vy * h
					b.z = b.z + b.vz * h
					Combat.bullet_hits(b)
				end
			end
			b.t = b.t - dt
			if b.t <= 0 then
				b.alive = false
			end
			e = b.ent
			if b.alive then
				e.x = b.x
				e.y = b.y
				e.z = b.z
			else
				e.z = -100
			end
		end
	end
	Combat.update_shells(dt)
end

function Combat.bullet_hits(b)
	local solid = W.solid(b.x, b.y, b.z)
	if solid then
		b.alive = false
		Fx.spark(b.x, b.y, b.z)
		return
	end
	local i = 0
	local o = nil
	local dx = 0.0
	local dy = 0.0
	for i = 1, Units.n do
		o = Units.list[i]
		if not o.dead and Units.hostile(b.team, o.team) then
			if b.z > o.z and b.z < o.z + 1.25 then
				dx = o.x - b.x
				dy = o.y - b.y
				if dx * dx + dy * dy < 0.16 then
					b.alive = false
					local sp = BULLET_SPEED
					Unit.hurt(o, b.dmg, b.vx / sp * 1.5, b.vy / sp * 1.5, b.by)
					Fx.spark(b.x, b.y, b.z)
					return
				end
			end
		end
	end
end

-- -- shells

-- Lob a shell from (x, y, z) to land near (tx, ty, tz).
function Combat.lob(x, y, z, tx, ty, tz, team)
	local b = nil
	local i = 0
	for i = 1, Shells.n do
		local c = Shells.list[i]
		if not c.alive then
			b = c
			break
		end
	end
	if b == nil then
		return
	end
	tx = tx + rnd(-1.3, 1.3)
	ty = ty + rnd(-0.8, 0.8)
	local dx = tx - x
	local dy = ty - y
	local flat = sqrt(dx * dx + dy * dy)
	local t = flat / SHELL_SPEED
	if t < 0.4 then
		t = 0.4
	end
	b.x = x
	b.y = y
	b.z = z
	b.vx = dx / t
	b.vy = dy / t
	b.vz = (tz - z + 0.5 * SHELL_G * t * t) / t
	b.team = team
	b.alive = true
	b.age = 0.0
	Fx.flash(x, y, z)
	Fx.dust(x, y, z)
	Sfx.boom(false)
end

function Combat.update_shells(dt)
	local i = 0
	local b = nil
	local e = nil
	for i = 1, Shells.n do
		b = Shells.list[i]
		if b.alive then
			b.age = b.age + dt
			b.vz = b.vz - SHELL_G * dt
			b.x = b.x + b.vx * dt
			b.y = b.y + b.vy * dt
			b.z = b.z + b.vz * dt
			local solid = W.solid(b.x, b.y, b.z)
			local close = Combat.body_near(b.x, b.y, b.z, b.team)
			if (solid or close) and b.age > 0.15 then
				b.alive = false
				Combat.blast(b.x, b.y, b.z, b.team)
			elseif b.z < ABYSS_Z then
				b.alive = false
			end
			e = b.ent
			if b.alive then
				e.x = b.x
				e.y = b.y
				e.z = b.z
			else
				e.z = -100
			end
		end
	end
end

function Combat.body_near(x, y, z, team)
	local i = 0
	local o = nil
	for i = 1, Units.n do
		o = Units.list[i]
		if not o.dead and o.team ~= team and z > o.z and z < o.z + 1.2 then
			if U.d2(x, y, o.x, o.y) < 0.25 then
				return true
			end
		end
	end
	return false
end

-- A shell bursts: everyone not on `team` within BLAST_R is hurt and flung
-- outward and up, more the closer they were.
function Combat.blast(x, y, z, team)
	Fx.blast(x, y, z)
	Sfx.boom(true)
	local i = 0
	local o = nil
	local dx = 0.0
	local dy = 0.0
	local d = 0.0
	local f = 0.0
	for i = 1, Units.n do
		o = Units.list[i]
		if not o.dead and o.team ~= team and U.abs(o.z - z) < BLAST_R then
			dx = o.x - x
			dy = o.y - y
			d = sqrt(dx * dx + dy * dy)
			if d < BLAST_R then
				f = 1 - d / BLAST_R
				if d < 0.05 then
					dx = 1
					d = 1
				end
				o.vz = 5 + f * 6
				o.grounded = false
				o.on = nil
				Unit.hurt(o, BLAST_DMG * f, dx / d * 7 * f, dy / d * 7 * f, nil)
			end
		end
	end
end
