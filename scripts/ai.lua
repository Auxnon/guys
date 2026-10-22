-- ai — what everyone but the commander you control decides each frame.
--
-- A brain only sets `u.wx, u.wy` (where it wants to go, length 0..1) and
-- `u.want_jump`; unit.lua does the walking. Each kind of unit:
--
-- soldier    fights first (fists or blade up close, the pistol at range
--            while rounds last), then carries out its order: follow (its
--            formation slot), go, hold, march, haul (shells to a cannon),
--            lost (wander, lemming-style) or idle. Unarmed soldiers with a
--            free moment go for any gun or blade lying nearby.
-- civilian   potters about at home and runs from raiders.
-- commander  theirs guard a post and send their squad at whoever comes
--            near; ours that you're not controlling stand and defend
--            themselves.
-- pilot      one of theirs who stands at a ship's helm and flies it.

AI = {}

ENGAGE_R = 9.0 -- how far a soldier looks for a fight
BRAWL_R = 2.6 -- armed soldiers close to fists inside this
RUSH_R = 6.0 -- unarmed ones charge from this far
SEEK_GEAR_R = 5.5

function AI.think(u, dt)
	Combat.tick_gun(u, dt)
	local b = u.brain
	if b == "our_cmd" and u == Cmd.selected() then
		-- input.lua drives this one; it only throws a punch on its own
		local t = Units.nearest_foe(u, MELEE_REACH)
		if t ~= nil then
			Combat.melee(u, t)
		end
		return
	end
	u.want_jump = false
	if b == "soldier" then
		AI.soldier(u, dt)
	elseif b == "civilian" then
		AI.civilian(u, dt)
	elseif b == "enemy_cmd" then
		AI.enemy_cmd(u, dt)
	elseif b == "our_cmd" then
		AI.our_cmd(u, dt)
	elseif b == "pilot" then
		AI.pilot(u, dt)
	end
end

-- -- moving

-- Head for (tx, ty). Slows on arrival, won't step off an edge unless told
-- to (`reckless`), and slides round whatever it bumps into. Returns true
-- once within `near`.
function AI.steer(u, tx, ty, near, scale, reckless)
	u.careful = not reckless
	u.edge = STEP
	local dx = tx - u.x
	local dy = ty - u.y
	local d = sqrt(dx * dx + dy * dy)
	if d < near then
		u.wx = 0.0
		u.wy = 0.0
		return true
	end
	local k = U.clamp(d / 1.2, 0.3, 1.0) * scale
	local wx = dx / d * k
	local wy = dy / d * k
	-- bumped a wall lately: swing off to one side for a moment
	if u.bumped and (u.dodge_t or 0) <= 0 then
		u.dodge_t = 0.45
		if U.chance(0.5) then
			u.dodge = 1.1
		else
			u.dodge = -1.1
		end
	end
	if (u.dodge_t or 0) > 0 then
		u.dodge_t = u.dodge_t - 0.016
		local c = cos(u.dodge)
		local s = sin(u.dodge)
		local rx = wx * c - wy * s
		local ry = wx * s + wy * c
		wx = rx
		wy = ry
	end
	if not reckless then
		local safe = Unit.ground_ahead(u, wx, wy, 0.5)
		if not safe then
			-- a gap: jump it if there's ground within a leap, else wait here
			local land = Unit.landing_ahead(u, wx, wy)
			if land and d > 1.5 and u.grounded then
				u.want_jump = true
			else
				wx = 0.0
				wy = 0.0
			end
		end
	end
	u.wx = wx
	u.wy = wy
	return false
end

function AI.stop(u)
	u.wx = 0.0
	u.wy = 0.0
end

-- -- fighting

-- Pick a fight if there is one. Returns true if fighting took over this
-- frame's movement.
function AI.fight(u, dt, may_chase)
	u.think_t = u.think_t - dt
	if u.think_t <= 0 then
		u.think_t = 0.3 + rnd() * 0.2
		local prev = u.tgt
		u.tgt = Units.nearest_foe(u, ENGAGE_R)
		if u.tgt ~= nil and prev == nil and u.team == 2 then
			Unit.flash_icon(u, "fx16", 0.8)
		end
	end
	local t = u.tgt
	if t == nil or t.dead then
		u.tgt = nil
		return false
	end
	local dx = t.x - u.x
	local dy = t.y - u.y
	local d = sqrt(dx * dx + dy * dy)
	if d > ENGAGE_R + 1 then
		u.tgt = nil
		return false
	end
	if d < MELEE_REACH then
		Combat.melee(u, t)
		AI.steer(u, t.x, t.y, 0.45, 0.6, false)
		return true
	end
	local loaded = u.weapon == "pistol" and (u.mag > 0 or u.reload_t > 0)
	if loaded and d > 1.4 and Combat.ready(u) then
		Combat.shoot(u, t.x, t.y, t.z + 0.6)
	end
	if u.carry then
		return false
	end
	local rush = BRAWL_R
	if not loaded then
		rush = RUSH_R
	end
	if may_chase and d < rush then
		AI.steer(u, t.x, t.y, 0.5, 1.1, false)
		return true
	end
	if loaded then
		u.face = U.sign(dx)
	end
	return false
end

-- -- soldiers

function AI.soldier(u, dt)
	local o = u.order
	local chase = o ~= "haul" and o ~= "march"
	if o == "hold" then
		-- holders only brawl with whoever comes right up to them
		local t = u.tgt
		chase = t ~= nil and U.d2(u.x, u.y, t.x, t.y) < 4
	end
	-- busy soldiers (in a fight, or fetching gear) don't count as out of
	-- contact while they're about it (Cmd.check_contact)
	u.busy = AI.fight(u, dt, chase)
	if u.busy then
		return
	end
	u.busy = AI.seek_gear(u)
	if u.busy then
		return
	end
	if o == "follow" then
		AI.follow(u, dt)
	elseif o == "go" then
		local there = AI.steer(u, u.gx, u.gy, 0.45, 1.0, false)
		if there then
			u.order = "hold"
		end
	elseif o == "hold" then
		AI.steer(u, u.gx, u.gy, 0.5, 0.8, false)
	elseif o == "march" then
		AI.march(u, 1.0)
	elseif o == "lost" then
		AI.wander(u, dt)
	elseif o == "haul" then
		AI.haul(u, dt)
	else
		AI.stop(u)
	end
end

-- Walk to my slot in the formation behind the boss: hurry when far behind,
-- ease in when close, and face the way the boss faces once there.
function AI.follow(u, dt)
	local c = u.boss
	if c == nil then
		u.order = "idle"
		return
	end
	local sx, sy = Cmd.slot_pos(c, u)
	local d = U.dist(u.x, u.y, sx, sy)
	local scale = 1.0
	if d > 4 then
		scale = 1.18
	end
	local there = AI.steer(u, sx, sy, 0.3, scale, false)
	if there then
		u.face = c.face
	end
end

-- Straight ahead whatever's there: turn round at walls, not at edges.
function AI.march(u, scale)
	u.careful = false
	if u.bumped then
		u.mdir = -(u.mdir or 1)
	end
	u.wx = (u.mdir or 1) * scale
	u.wy = 0.0
end

-- Lost soldiers wander like lemmings: plod on, stop now and then to look
-- about, turn at walls, and never mind the drop.
function AI.wander(u, dt)
	u.pause_t = (u.pause_t or 0) - dt
	if u.pause_t > 0 then
		AI.stop(u)
		return
	end
	if u.pause_t < -4 then
		u.pause_t = 1.0 + rnd() * 1.5
		if U.chance(0.3) then
			u.mdir = -(u.mdir or 1)
		end
		return
	end
	AI.march(u, 0.5)
end

-- An unarmed soldier (or one short of rounds) with nothing better to do
-- goes for gear lying close by.
function AI.seek_gear(u)
	local o = u.order
	if o == "haul" or o == "march" or o == "lost" then
		return false
	end
	if u.weapon == "pistol" and u.mag + u.ammo >= 6 then
		return false
	end
	local p = Pick.wanted(u, SEEK_GEAR_R)
	if p == nil then
		return false
	end
	AI.steer(u, p.x, p.y, 0.1, 1.0, false)
	return true
end

-- Shells from the nearest pile to the cannon, one at a time.
function AI.haul(u, dt)
	local c = u.job
	if c == nil then
		u.order = "hold"
		u.gx = u.x
		u.gy = u.y
		return
	end
	if not u.carry then
		local p = Piles.nearest(u.team, u.x, u.y, u.z)
		if p == nil then
			if u.team == 1 and not Game.warned_shells then
				Game.warned_shells = true
				HUD.toast("NO SHELLS LEFT TO HAUL")
			end
			u.order = "hold"
			u.gx = u.x
			u.gy = u.y
			u.job = nil
			return
		end
		local at = AI.steer(u, p.x, p.y, 0.7, 1.0, false)
		if at and U.abs(p.z - u.z) < 1.2 then
			p.stock = p.stock - 1
			u.carry = true
		end
	else
		local at = AI.steer(u, c.x, c.y, 0.9, 0.65, false)
		if at and U.abs(c.z - u.z) < 1.2 then
			if c.loaded < CANNON_HOLD then
				c.loaded = c.loaded + 1
				u.carry = false
				Sfx.clunk()
			else
				AI.stop(u)
			end
		end
	end
end

-- -- civilians

function AI.civilian(u, dt)
	u.think_t = u.think_t - dt
	if u.think_t <= 0 then
		u.think_t = 0.4 + rnd() * 0.4
		u.tgt = AI.nearest_raider(u, 6)
		if u.tgt ~= nil then
			Unit.flash_icon(u, "fx16", 0.6)
		elseif U.chance(0.25) then
			local hx = u.hx or u.x
			local hy = u.hy or u.y
			u.gx = hx + rnd(-2.5, 2.5)
			u.gy = hy + rnd(-1.5, 1.5)
		end
	end
	local t = u.tgt
	if t ~= nil and not t.dead then
		-- run the other way
		local dx = u.x - t.x
		local dy = u.y - t.y
		local d = sqrt(dx * dx + dy * dy) + 0.01
		AI.steer(u, u.x + dx / d * 3, u.y + dy / d * 3, 0.1, 1.15, false)
		return
	end
	AI.steer(u, u.gx, u.gy, 0.4, 0.45, false)
end

function AI.nearest_raider(u, r)
	local best = nil
	local bd = r * r
	local i = 0
	local o = nil
	local d = 0.0
	for i = 1, Units.n do
		o = Units.list[i]
		if not o.dead and o.team == 2 and U.abs(o.z - u.z) < 3 then
			d = U.d2(u.x, u.y, o.x, o.y)
			if d < bd then
				bd = d
				best = o
			end
		end
	end
	return best
end

-- -- commanders

-- Theirs: keep the squad together at the post; when anyone of ours (or a
-- civilian to raid) comes within reach, send everyone at them and join in.
function AI.enemy_cmd(u, dt)
	u.order_t = (u.order_t or 0) - dt
	local foe = AI.nearest_soldier_to(u, u.post_x, u.post_y, u.z, u.watch or 11)
	if u.order_t <= 0 then
		u.order_t = 1.6 + rnd() * 0.6
		if foe ~= nil then
			Cmd.go(u, foe.x, foe.y, foe.z)
			Unit.flash_icon(u, "fx16", 1.0)
		else
			Cmd.rally(u)
		end
	end
	local fought = AI.fight(u, dt, true)
	if fought then
		return
	end
	if foe ~= nil then
		-- keep a few tiles off and let the pistol work
		local d = U.dist(u.x, u.y, foe.x, foe.y)
		if d > 5 then
			AI.steer(u, foe.x, foe.y, 4.5, 0.8, false)
		else
			AI.stop(u)
		end
	else
		AI.steer(u, u.post_x, u.post_y, 0.6, 0.7, false)
	end
end

-- Ours you're not controlling: stand, shoot back, brawl if rushed.
function AI.our_cmd(u, dt)
	local fought = AI.fight(u, dt, false)
	if not fought then
		AI.stop(u)
	end
end

-- Our troops (not civilians) nearest a point, for their commanders.
function AI.nearest_soldier_to(u, x, y, z, r)
	local best = nil
	local bd = r * r
	local i = 0
	local o = nil
	local d = 0.0
	for i = 1, Units.n do
		o = Units.list[i]
		if not o.dead and o.team ~= 0 and Units.hostile(u.team, o.team) and U.abs(o.z - z) < 4 then
			d = U.d2(x, y, o.x, o.y)
			if d < bd then
				bd = d
				best = o
			end
		end
	end
	return best
end

-- -- pilots

function AI.pilot(u, dt)
	local s = u.ship
	if s == nil then
		u.brain = "soldier"
		return
	end
	AI.fight(u, dt, false)
	local hx, hy, hz = Ships.helm_spot(s)
	local at = AI.steer(u, hx, hy, 0.35, 0.8, false)
	if at and U.abs(u.z - hz) < 0.6 then
		s.pilot = u
		local ch = cos(s.h)
		u.face = U.sign(ch)
	elseif s.pilot == u then
		s.pilot = nil
	end
end
