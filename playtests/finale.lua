-- finale: bring the Magpie (with Rook's squad and Asha's) nose-to-west-gate
-- of the fortress, storm it, and walk Rook to their flag. With CLEAR set the
-- garrison is removed first, to check the capture itself.
TT = { t = 0, step = 0, sec = 0 }
CLEAR = true
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
function TEST_HOOK(dt)
	TT.t = TT.t + dt
	local c = Cmd.selected()
	if c == nil then
		return
	end
	if TT.step == 0 and TT.t > 0.5 then
		TT.step = 1
		Game.start()
		local s = Ships.player_ship()
		local fort = Level.fort
		local x = fort.x + fort.lox - s.hix - 0.05
		local dx = x - s.x
		local dz = 9 - s.z
		s.x = x
		s.z = 9
		s.px = x
		s.pz = 9
		local i = 0
		local u = nil
		local k = 0
		for i = 1, Units.n do
			u = Units.list[i]
			if not u.dead and u.team == 1 then
				k = k + 1
				u.x = x - 3 + (k % 5) * 1.1
				u.y = -1 + flr(k / 5) * 0.8
				u.z = 9
				u.on = s
			end
		end
		-- the gear on deck moves too
		for i = 1, Cannons.n do
			local cn = Cannons.list[i]
			if cn.ship == s then
				Gear.follow(cn)
			end
		end
		if CLEAR then
			for i = 1, Units.n do
				u = Units.list[i]
				if not u.dead and u.team == 2 and u.x > 108 then
					Unit.die(u, "test")
				end
			end
		end
		Cmd.rally(c)
		print("T", "ship at", s.x, s.z, "fort west edge", fort.x + fort.lox)
	elseif TT.step == 1 and TT.t > 2 then
		TT.step = 2
		Cmd.go(c, 120, 0, 9)
		local a = Cmd.ours[2]
		Cmd.go(a, 119, -1, 9)
	elseif TT.step == 2 and TT.t > 6 then
		-- round the barricade (local x -1, y -2..0), then to the flag
		if walk_to(c, 120, 1.6) then
			TT.step = 3
		end
	elseif TT.step == 3 then
		walk_to(c, 125.6, 0.6)
	end
	if TT.t > TT.sec + 1 then
		TT.sec = TT.sec + 1
		local us = 0
		local them = 0
		local i = 0
		local u = nil
		for i = 1, Units.n do
			u = Units.list[i]
			if not u.dead and u.x > 108 then
				if u.team == 1 then
					us = us + 1
				elseif u.team == 2 then
					them = them + 1
				end
			end
		end
		print("T", flr(G.time), "state", G.state, "us", us, "them", them, "cmd", c.name, flr(c.x * 10) / 10, flr(c.z * 10) / 10, "capture", flr(Game.capture_t * 10) / 10, "dead", Game.stats.fallen_us, "abyss", Game.stats.abyss)
	end
end
