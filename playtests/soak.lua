-- soak: random orders, walking, helm, switching and promotion for a minute
-- or so, to shake out rare Lua errors. Prints a heartbeat each 5s.
TT = { t = 0, act = 0, beat = 0, n = 0 }
ACTS = { "go", "go", "rally", "hold", "march", "walk", "walk", "switch", "promote", "helm", "fire" }
function TEST_HOOK(dt)
	TT.t = TT.t + dt
	if TT.t < 0.5 then
		return
	end
	if G.state == "intro" then
		Game.start()
	end
	if G.state ~= "play" then
		print("T", "restart from", G.state, "cmds", Cmd.nours, "t", TT.t)
		Game.restart()
	end
	local c = Cmd.selected()
	if c == nil then
		return
	end
	TT.act = TT.act - dt
	if TT.act <= 0 then
		TT.act = rnd(0.3, 0.8)
		TT.n = TT.n + 1
		local a = U.pick(ACTS)
		if a == "go" then
			local gx = c.x + rnd(-6, 8)
			local gy = rnd(-4, 4)
			Cmd.go(c, gx, gy, c.z)
		elseif a == "rally" then
			Cmd.rally(c)
		elseif a == "hold" then
			Cmd.hold(c)
		elseif a == "march" then
			Cmd.march(c)
		elseif a == "walk" then
			local wx = rnd(-0.3, 1)
			local wy = rnd(-1, 1)
			WALK_FAKE = { wx, wy }
		elseif a == "switch" then
			Cmd.sel = irnd(1, 3)
		elseif a == "promote" then
			Cmd.promote(c)
		elseif a == "helm" then
			Input.helm(c)
			FLY_FAKE = { 1, 0.3 }
		elseif a == "fire" then
			Input.fire(c, c.x + 5, c.y, c.z)
		end
	end
	if TT.t > TT.beat + 5 then
		TT.beat = TT.beat + 5
		local alive = 0
		local i = 0
		for i = 1, Units.n do
			local u = Units.list[i]
			if not u.dead then
				alive = alive + 1
			end
		end
		print("T", flr(TT.t), "acts", TT.n, "alive", alive, "units", Units.n, "cmds", Cmd.nours, "x", flr(c.x), "picks", Pick.n)
	end
end
