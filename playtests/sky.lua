-- sky: put Rook's squad on the dock, board the airship, take the helm, fly
-- up and east, and check the crew rides along (and the ship stops at rock).
TT = { t = 0, step = 0, sec = 0 }
ORIG_DEATH = Game.on_death
function Game.on_death(u, why)
	print("T", "death", u.team, u.cmd, why, flr(u.x), flr(u.y), flr(u.z))
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
function crew()
	local s = Ships.player_ship()
	local c = Cmd.selected()
	local aboard = 0
	local n = 0
	local i = 0
	local u = nil
	for i = 1, Units.n do
		u = Units.list[i]
		if not u.dead and u.boss == c then
			n = n + 1
			if u.on == s then
				aboard = aboard + 1
			end
		end
	end
	print("T", flr(G.time), "step", TT.step, "ship", flr(s.x * 10) / 10, flr(s.z * 10) / 10, "spd", flr(s.speed * 100) / 100, "crew", aboard, "/", n, "cmd", flr(c.x * 10) / 10, flr(c.z * 10) / 10, "helm", c.helm ~= nil)
end
function TEST_HOOK(dt)
	TT.t = TT.t + dt
	local c = Cmd.selected()
	if TT.step == 0 and TT.t > 0.5 then
		TT.step = 1
		Game.start()
		-- everyone of Rook's to the dock (well short of their raiders' post)
		local i = 0
		local u = nil
		local k = 0
		for i = 1, Units.n do
			u = Units.list[i]
			if u.team == 1 and (u == c or u.boss == c) then
				k = k + 1
				u.x = 56 + (k % 3) * 0.6
				u.y = -1 + flr(k / 3) * 0.7
				u.z = 7
			end
		end
		-- and their raiders out of the way
		for i = 1, Units.n do
			u = Units.list[i]
			if u.team == 2 and u.x > 50 and u.x < 58 then
				Unit.die(u, "test")
			end
		end
		Cmd.rally(c)
	elseif TT.step == 1 then
		local s = Ships.player_ship()
		local hx, hy, hz = Ships.helm_spot(s)
		if walk_to(c, hx, hy) then
			TT.step = 2
			TT.t2 = TT.t
			Input.helm(c)
		end
	elseif TT.step == 2 and TT.t > TT.t2 + 2 then
		TT.step = 3
		TT.t3 = TT.t
		FLY_FAKE = { 0, 1 }
	elseif TT.step == 3 and TT.t > TT.t3 + 5 then
		TT.step = 4
		TT.t4 = TT.t
		FLY_FAKE = { 1, 0 }
	elseif TT.step == 4 and TT.t > TT.t4 + 10 then
		TT.step = 5
		FLY_FAKE = { 0, 0 }
	end
	if TT.t > TT.sec + 1 then
		TT.sec = TT.sec + 1
		crew()
	end
end
