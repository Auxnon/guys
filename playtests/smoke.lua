-- smoke: start, stand still, print what's going on each second.
TT = { t = 0, step = 0, sec = 0 }
function TEST_HOOK(dt)
	TT.t = TT.t + dt
	if TT.step == 0 and TT.t > 0.5 then
		TT.step = 1
		Game.start()
	end
	if TT.t > TT.sec + 1 then
		TT.sec = TT.sec + 1
		local c = Cmd.selected()
		local alive = 0
		local i = 0
		for i = 1, Units.n do
			local u = Units.list[i]
			if not u.dead then
				alive = alive + 1
			end
		end
		print("T", TT.sec, "state", G.state, "units", Units.n, "alive", alive, "cmd", c.name, c.x, c.y, c.z, "cam", Cam.ex, Cam.ey, Cam.ez)
	end
end
