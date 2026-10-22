-- tour: log every death, and hop the selected commander along the level so
-- each stop gets a snapshot (frames 300, 420, 540, ... see the stops table).
TT = { t = 0, step = 0, stop = 0 }
STOPS = { { 30, -2 }, { 44, -1 }, { 56, -1 }, { 64, 0 }, { 90, 0 }, { 118, -2 } }
ORIG_DEATH = Game.on_death
function Game.on_death(u, why)
	print("T", "death", u.team, u.cmd, why, flr(u.x), flr(u.y), flr(u.z), u.hit_by ~= nil)
	ORIG_DEATH(u, why)
end
function TEST_HOOK(dt)
	TT.t = TT.t + dt
	if TT.step == 0 and TT.t > 0.5 then
		TT.step = 1
		Game.start()
	end
	-- every 2s, teleport to the next stop (the snapshot comes ~1.5s later)
	local want = flr((TT.t - 1) / 2) + 1
	if TT.t > 1 and want ~= TT.stop and want <= #STOPS then
		TT.stop = want
		local c = Cmd.selected()
		local s = STOPS[want]
		c.x = s[1]
		c.y = s[2]
		c.z = Level.ground_z(s[1], s[2])
		c.vz = 0
		print("T", "stop", want, c.x, c.y, c.z, "frame-ish", flr(G.time * 60))
	end
end
