-- assault: rally, walk the squad down into the valley in formation, pick up
-- the megaphone, then send everyone at their outpost and watch the fight.
TT = { t = 0, step = 0, sec = 0 }
ORIG_DEATH = Game.on_death
function Game.on_death(u, why)
	print("T", "death", u.team, u.cmd, why, flr(u.x), flr(u.y), "by", u.hit_by ~= nil)
	ORIG_DEATH(u, why)
end
function walk_to(c, x, y)
	local dx = x - c.x
	local dy = y - c.y
	local d = sqrt(dx * dx + dy * dy)
	if d < 0.3 then
		WALK_FAKE = { 0, 0 }
		return true
	end
	WALK_FAKE = { dx / d, dy / d }
	return false
end
function report()
	local us = 0
	local them = 0
	local i = 0
	local u = nil
	local lv = 0
	for i = 1, Units.n do
		u = Units.list[i]
		if not u.dead then
			if u.team == 1 then
				us = us + 1
				lv = lv + u.level
			elseif u.team == 2 then
				them = them + 1
			end
		end
	end
	local c = Cmd.selected()
	print("T", flr(G.time), "step", TT.step, "us", us, "them", them, "levels", lv, "cmd", c.name, flr(c.x * 10) / 10, flr(c.y * 10) / 10, c.z, "tech", c.tech)
end
function formation()
	local c = Cmd.selected()
	local i = 0
	local u = nil
	for i = 1, Units.n do
		u = Units.list[i]
		if not u.dead and u.boss == c then
			local sx, sy = Cmd.slot_pos(c, u)
			print("T", "  f", u.rank, u.order, flr(u.x * 10) / 10, flr(u.y * 10) / 10, u.z, "slot", flr(sx * 10) / 10, flr(sy * 10) / 10)
		end
	end
end
function TEST_HOOK(dt)
	TT.t = TT.t + dt
	local c = Cmd.selected()
	if TT.step == 0 and TT.t > 0.5 then
		TT.step = 1
		Game.start()
		Cmd.rally(c)
	elseif TT.step == 1 then
		if walk_to(c, 21, 1) then
			TT.step = 2
			TT.t2 = TT.t
			formation()
		end
	elseif TT.step == 2 and TT.t > TT.t2 + 1.5 then
		TT.step = 3
		formation()
		Cmd.go(c, 31, 0, 3)
		TT.t3 = TT.t
	elseif TT.step == 3 then
		walk_to(c, 25, 0)
	end
	if TT.t > TT.sec + 1 then
		TT.sec = TT.sec + 1
		report()
		if TT.sec == 4 then
			formation()
		end
	end
end
