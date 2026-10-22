-- unit — everyone who walks: soldiers and commanders, ours and theirs.
--
-- A unit is a table wrapping a billboard sprite entity. Its brain (ai.lua for
-- soldiers and enemy commanders, input.lua for the commander you control)
-- only sets a wanted direction `u.wx, u.wy` (length 0..1) and `u.want_jump`;
-- Unit.update turns that into motion the same way for everyone:
--
-- - velocity eases toward the wish (UNIT_ACCEL), so walkers start, stop and
--   turn with a little weight instead of snapping;
-- - bodies push apart softly (Units.separate), so a squad jostles into
--   place rather than overlapping;
-- - x and y move separately against W.ground, so a walker slides along a
--   wall, climbs 1-tile steps on its own, and walks straight off an edge if
--   it's told to (that's how soldiers get lost to the abyss);
-- - anyone standing on a ship is carried with it first (Ships.carry).
--
-- Teams: 0 civilians, 1 us, 2 them. Weapons: "fist", "blade" or "pistol"
-- (a pistol needs rounds: `mag` loaded, `ammo` spare). Levels 0..3 come
-- from kills (LEVEL_KILLS) and buy health, damage and a steadier aim.

Units = { list = {}, n = 0 }
Unit = {}

GRAVITY = 30.0
JUMP_V = 9.2
UNIT_SPEED = 3.0
CMD_SPEED = 3.5
UNIT_ACCEL = 9.0
BODY_R = 0.32 -- body radius for the soft push between walkers
HP_SOLDIER = 100
HP_COMMANDER = 170
CORPSE_SECS = 40
HP_CIVILIAN = 60
MAG = 6
LEVEL_KILLS = { 1, 3, 6 } -- kills to reach levels 1, 2, 3

function Unit_new(team, cmd, x, y, z, weapon)
	local u = {}
	u.team = team
	u.cmd = cmd
	u.x = x
	u.y = y
	u.z = z
	u.vx = 0.0
	u.vy = 0.0
	u.vz = 0.0
	u.wx = 0.0
	u.wy = 0.0
	u.want_jump = false
	u.speed = UNIT_SPEED * (0.92 + rnd() * 0.16)
	u.face = 1
	u.heading = 0.0
	u.grounded = false
	u.on = nil
	u.dead = false
	u.hp = HP_SOLDIER
	if cmd then
		u.hp = HP_COMMANDER
		u.speed = CMD_SPEED
	end
	if team == 0 then
		u.hp = HP_CIVILIAN
		u.speed = UNIT_SPEED * 1.1
	end
	u.max = u.hp
	u.weapon = weapon or "fist"
	u.mag = 0
	u.ammo = 0
	if u.weapon == "pistol" then
		u.mag = MAG
		u.ammo = MAG
	end
	u.level = 0
	u.kills = 0
	u.carry = false
	u.job = nil
	u.order = "idle"
	u.boss = nil
	u.gx = x
	u.gy = y
	u.tgt = nil
	u.think_t = rnd() * 0.4
	u.gun_t = rnd() * 0.8
	u.reload_t = 0.0
	u.melee_t = 0.0
	u.pose = FR_IDLE
	u.pose_t = 0.0
	u.walk_t = rnd()
	u.hurt_t = 0.0
	u.lost_t = 0.0
	u.icon = ""
	u.icon_t = 0.0
	u.frame = -1
	u.tinted = false
	u.bumped = false
	u.dead_t = 0.0
	u.slot = 0
	local name = A.frame(u, FR_IDLE)
	local e = make(name, x, y, z, 1)
	local off = { 0, 0, 0.5 }
	e.offset = off
	u.ent = e
	local ic = make("fx15", x, y, -100, 0.5)
	u.icon_ent = ic
	local pe = make("fx26", x, y, -100, 0.4)
	u.pip_ent = pe
	u.pip_shown = 0
	Units.n = Units.n + 1
	Units.list[Units.n] = u
	u.id = Units.n
	return u
end

-- Swap a soldier's look for a commander's (promotion).
function Unit.make_commander(u)
	u.cmd = true
	u.max = HP_COMMANDER
	u.hp = HP_COMMANDER
	u.speed = CMD_SPEED
	u.frame = -1
	u.carry = false
	u.job = nil
end

-- Hand a unit a weapon (rounds come separately, see Unit.give_ammo).
function Unit.arm(u, weapon)
	u.weapon = weapon
	u.frame = -1
end

function Unit.give_ammo(u, n)
	u.ammo = u.ammo + n
	if u.mag == 0 and u.ammo > 0 then
		local k = U.min(MAG, u.ammo)
		u.mag = k
		u.ammo = u.ammo - k
	end
end

-- A kill: the first makes a recruit a soldier; LEVEL_KILLS sets the rest.
function Unit.add_kill(u)
	u.kills = u.kills + 1
	if u.level >= 3 then
		return
	end
	local need = LEVEL_KILLS[u.level + 1]
	if u.kills >= need then
		u.level = u.level + 1
		u.max = u.max + 15
		u.hp = u.max
		Unit.flash_icon(u, "fx17", 1.2)
		if u.team == 1 then
			Fx.star(u.x, u.y, u.z + 1.4)
			Sfx.level()
		end
	end
end

-- One horizontal step; returns true if a wall stopped it. A `careful`
-- step also refuses to drop further than `u.edge` (STEP for soldiers, so
-- they never step off a ledge unordered; a bigger one for the commander you
-- control, so only a jump takes you into the clouds). That isn't a bump.
function Unit.try(u, dx, dy, careful)
	local nx = u.x + dx
	local ny = u.y + dy
	local g, wall, ship = W.ground(nx, ny, u.z)
	if wall then
		return true
	end
	if careful and u.grounded then
		local drop = u.edge or STEP
		if g == nil or g < u.z - drop then
			return false
		end
	end
	u.x = nx
	u.y = ny
	if u.grounded and g ~= nil and g > u.z and g <= u.z + STEP then
		u.z = g -- auto-climb a 1-tile step
		u.on = ship
	end
	return false
end

-- Is there ground to stand on a step ahead in direction (dx, dy)?
function Unit.ground_ahead(u, dx, dy, dist)
	local len = sqrt(dx * dx + dy * dy)
	if len < 0.0001 then
		return true
	end
	local x = u.x + dx / len * dist
	local y = u.y + dy / len * dist
	local g, wall, ship = W.ground(x, y, u.z)
	if wall then
		return true
	end
	return g ~= nil and g > u.z - STEP
end

-- Ground within a running jump: (x, y) of a landing spot 2 tiles ahead.
function Unit.landing_ahead(u, dx, dy)
	local len = sqrt(dx * dx + dy * dy)
	if len < 0.0001 then
		return false
	end
	local x = u.x + dx / len * 2.0
	local y = u.y + dy / len * 2.0
	local g, wall, ship = W.ground(x, y, u.z + 0.5)
	return g ~= nil and g > u.z - 1.5 and not wall
end

function Unit.jump(u)
	if u.grounded then
		u.vz = JUMP_V
		u.grounded = false
		u.on = nil
	end
end

-- Damage from `by` (a unit, or nil for a blast or a fall); a kill counts
-- toward their level.
function Unit.hurt(u, dmg, kx, ky, by)
	if u.dead then
		return
	end
	u.hp = u.hp - dmg
	u.hurt_t = 0.15
	u.vx = u.vx + kx
	u.vy = u.vy + ky
	u.hit_by = by
	if kx * kx + ky * ky > 1 then
		u.stagger_t = 0.35 -- a real shove can put you over the edge
	end
	if u.hp <= 0 then
		Unit.die(u, "fight")
		if by ~= nil and not by.dead then
			Unit.add_kill(by)
		end
	end
end

function Unit.die(u, why)
	if u.dead then
		return
	end
	u.dead = true
	u.hp = 0
	u.dead_t = 0.0
	u.why = why
	u.vx = u.vx * 0.3
	u.vy = u.vy * 0.3
	local ic = u.icon_ent
	ic.z = -100
	local pe = u.pip_ent
	pe.z = -100
	Game.on_death(u, why)
end

-- -- per frame

function Unit.update(u, dt)
	if u.on ~= nil then
		local s = u.on
		local nx, ny, nz, dh = Ships.carry(s, u.x, u.y, u.z)
		u.x = nx
		u.y = ny
		u.z = nz
	end
	if u.dead then
		Unit.update_corpse(u, dt)
		return
	end

	-- ease velocity toward the wish; knockback rides on top and decays
	local k = U.ease(UNIT_ACCEL, dt)
	if not u.grounded then
		k = k * 0.25
	end
	local tx = u.wx * u.speed
	local ty = u.wy * u.speed
	u.vx = u.vx + (tx - u.vx) * k
	u.vy = u.vy + (ty - u.vy) * k

	u.bumped = false
	u.stagger_t = (u.stagger_t or 0) - dt
	local careful = u.careful == true and u.stagger_t <= 0
	local b1 = false
	local b2 = false
	if U.abs(u.vx) > 0.001 then
		b1 = Unit.try(u, u.vx * dt, 0, careful)
		if b1 then
			u.vx = 0.0
		end
	end
	if U.abs(u.vy) > 0.001 then
		b2 = Unit.try(u, 0, u.vy * dt, careful)
		if b2 then
			u.vy = 0.0
		end
	end
	u.bumped = b1 or b2

	if u.want_jump then
		Unit.jump(u)
		u.want_jump = false
	end
	Unit.fall(u, dt)

	if U.abs(u.vx) > 0.3 then
		u.face = U.sign(u.vx)
	end
	local sp = u.vx * u.vx + u.vy * u.vy
	if sp > 0.2 then
		u.heading = atan2(u.vy, u.vx)
	end
	u.hurt_t = u.hurt_t - dt
	u.melee_t = u.melee_t - dt
	u.pose_t = u.pose_t - dt
	Unit.draw(u, dt)
end

function Unit.fall(u, dt)
	u.vz = u.vz - GRAVITY * dt
	if u.vz < -25 then
		u.vz = -25
	end
	u.z = u.z + u.vz * dt
	local g, wall, ship = W.ground(u.x, u.y, u.z)
	if g ~= nil and u.z <= g and u.vz <= 0 then
		if not u.grounded and u.vz < -14 then
			Fx.dust(u.x, u.y, g)
		end
		u.z = g
		u.vz = 0.0
		u.grounded = true
		u.on = ship
	else
		u.grounded = false
		if g == nil or u.z > g + 0.05 then
			u.on = nil
		end
	end
	if u.z < ABYSS_Z then
		local by = u.hit_by
		Unit.die(u, "abyss")
		if by ~= nil and not by.dead then
			Unit.add_kill(by)
		end
	end
end

-- The dead lie where they fell (and go on falling, if they fell into the
-- abyss), then are cleared away after a while.
function Unit.update_corpse(u, dt)
	u.dead_t = u.dead_t + dt
	local e = u.ent
	if u.dead_t > CORPSE_SECS or u.z < ABYSS_Z - 20 then
		if not u.gone then
			e.z = -200
			u.gone = true
		end
		return
	end
	if not u.grounded then
		u.vz = u.vz - GRAVITY * dt
		u.z = u.z + u.vz * dt
		u.x = u.x + u.vx * dt
		u.y = u.y + u.vy * dt
		local g, wall, ship = W.ground(u.x, u.y, u.z)
		if g ~= nil and u.z <= g and u.vz <= 0 then
			u.z = g
			u.grounded = true
			u.on = ship
		end
	end
	local name = A.frame(u, FR_DEAD)
	if u.grounded then
		Unit.set_frame(u, name)
	else
		name = A.frame(u, FR_FALL)
		Unit.set_frame(u, name)
	end
	e.x = u.x
	e.y = u.y
	e.z = u.z
	if u.tinted then
		e.tint = { 1, 1, 1, 1 }
		u.tinted = false
	end
end

function Unit.set_frame(u, name)
	if u.frame ~= name then
		u.frame = name
		local e = u.ent
		e.tex = name
	end
end

-- Show a pose (FR_SHOOT, FR_PUNCH, FR_CHEER) for a moment.
function Unit.pose(u, pose, secs)
	u.pose = pose
	u.pose_t = secs
end

function Unit.draw(u, dt)
	local e = u.ent
	e.x = u.x
	e.y = u.y
	e.z = u.z
	e.flipped = u.face < 0
	local f = FR_IDLE
	if not u.grounded and u.vz < -6 then
		f = FR_FALL
	elseif u.pose_t > 0 then
		f = u.pose
	elseif u.carry then
		f = FR_CHEER
	else
		local sp = u.vx * u.vx + u.vy * u.vy
		if sp > 0.3 then
			u.walk_t = u.walk_t + dt * sqrt(sp) * 2.2
			if flr(u.walk_t) % 2 == 0 then
				f = FR_WALK1
			else
				f = FR_WALK2
			end
		end
	end
	local name = A.frame(u, f)
	Unit.set_frame(u, name)
	if u.hurt_t > 0 then
		if not u.tinted then
			e.tint = { 1, 0.45, 0.45, 1 }
			u.tinted = true
		end
	elseif u.tinted then
		e.tint = { 1, 1, 1, 1 }
		u.tinted = false
	end
	-- the icon over its head: ? lost, ! alerted, star promoted
	local ic = u.icon_ent
	u.icon_t = u.icon_t - dt
	local want = ""
	local iz = 1.55
	if u.carry then
		want = "fx23"
		iz = 1.25
	elseif u.order == "lost" then
		want = "fx15"
	elseif u.icon_t > 0 then
		want = u.icon
	end
	if want == "" then
		if u.icon_shown then
			ic.z = -100
			u.icon_shown = false
		end
	else
		if u.icon_name ~= want then
			ic.tex = want
			u.icon_name = want
		end
		ic.x = u.x
		ic.y = u.y
		ic.z = u.z + iz
		u.icon_shown = true
	end
	-- level pips, just over the helmet
	local pe = u.pip_ent
	if u.level > 0 then
		if u.pip_shown ~= u.level then
			local pn = A.fx[FX_PIPS + u.level]
			pe.tex = pn
			u.pip_shown = u.level
		end
		pe.x = u.x
		pe.y = u.y - 0.05
		pe.z = u.z + 1.18
	elseif u.pip_shown ~= 0 then
		pe.z = -100
		u.pip_shown = 0
	end
end

function Unit.flash_icon(u, name, secs)
	u.icon = name
	u.icon_t = secs
end

-- -- everyone

-- Soft bodies: any two living walkers closer than two radii are pushed
-- apart, half each. Bucketed along x so it isn't every pair.
function Units.separate(dt)
	local buckets = {}
	local i = 0
	local u = nil
	local b = 0
	local list = nil
	for i = 1, Units.n do
		u = Units.list[i]
		if not u.dead then
			b = flr(u.x)
			list = buckets[b]
			if list == nil then
				list = {}
				buckets[b] = list
			end
			list[#list + 1] = u
		end
	end
	local j = 0
	local o = nil
	local dx = 0.0
	local dy = 0.0
	local d2 = 0.0
	local d = 0.0
	local push = 0.0
	local min = BODY_R * 2
	local bb = 0
	for i = 1, Units.n do
		u = Units.list[i]
		if not u.dead and u.grounded then
			for bb = -1, 1 do
				b = flr(u.x) + bb
				list = buckets[b]
				if list ~= nil then
					for j = 1, #list do
						o = list[j]
						if o.id > u.id and o.grounded and U.abs(o.z - u.z) < 0.8 then
							dx = u.x - o.x
							dy = u.y - o.y
							d2 = dx * dx + dy * dy
							if d2 < min * min then
								d = sqrt(d2)
								if d < 0.001 then
									dx = rnd(-1, 1)
									dy = rnd(-1, 1)
									d = 0.5
								end
								push = (min - d) * 0.5 * U.ease(10, dt)
								Unit.try(u, dx / d * push, 0, true)
								Unit.try(u, 0, dy / d * push, true)
								Unit.try(o, -dx / d * push, 0, true)
								Unit.try(o, 0, -dy / d * push, true)
							end
						end
					end
				end
			end
		end
	end
end

function Units.update(dt)
	local i = 0
	local u = nil
	for i = 1, Units.n do
		u = Units.list[i]
		if not u.dead and u.brain ~= nil then
			AI.think(u, dt)
		end
	end
	Units.separate(dt)
	for i = 1, Units.n do
		u = Units.list[i]
		if not u.gone then
			Unit.update(u, dt)
		end
	end
end

-- Living units of `team` within r of (x, y) and roughly level with z.
function Units.near(team, x, y, z, r, out)
	local n = 0
	local i = 0
	local u = nil
	local r2 = r * r
	for i = 1, Units.n do
		u = Units.list[i]
		if not u.dead and u.team == team and U.abs(u.z - z) < 4 then
			if U.d2(x, y, u.x, u.y) <= r2 then
				n = n + 1
				out[n] = u
			end
		end
	end
	return n
end

-- Who fights whom: we and they fight; their raiders also prey on
-- civilians; civilians fight nobody (they run, see AI.civilian).
function Units.hostile(a, b)
	if a == 0 then
		return false
	end
	if a == 1 then
		return b == 2
	end
	return b == 1 or b == 0
end

-- The nearest living enemy of `u` within r, or nil.
function Units.nearest_foe(u, r)
	local best = nil
	local bd = r * r
	local i = 0
	local o = nil
	local d = 0.0
	for i = 1, Units.n do
		o = Units.list[i]
		if not o.dead and U.abs(o.z - u.z) < 3.5 and Units.hostile(u.team, o.team) then
			d = U.d2(u.x, u.y, o.x, o.y)
			if o.team == 0 then
				-- a raider only goes for a civilian it stumbles on
				d = d * 4
			end
			if d < bd then
				bd = d
				best = o
			end
		end
	end
	return best
end
