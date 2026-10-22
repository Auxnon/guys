-- town: Asha's squad goes to Highdale and rallies the civilians, who sign up
-- and scavenge the armory; then Asha falls and her squad loses contact.
TT = { t = 0, step = 0, sec = 0 }
function census(tag)
	local i = 0
	local u = nil
	local c = Cmd.ours[2]
	local n = 0
	local civ = 0
	local lost = 0
	local fist = 0
	local blade = 0
	local gun = 0
	for i = 1, Units.n do
		u = Units.list[i]
		if not u.dead then
			if u.team == 0 then
				civ = civ + 1
			end
			if u.team == 1 and not u.cmd then
				if u.order == "lost" then
					lost = lost + 1
				end
				if u.weapon == "fist" then
					fist = fist + 1
				elseif u.weapon == "blade" then
					blade = blade + 1
				else
					gun = gun + 1
				end
			end
		end
	end
	print("T", tag, flr(G.time), "civilians", civ, "enlisted", Game.stats.enlisted, "fist", fist, "blade", blade, "gun", gun, "lost", lost, "abyss", Game.stats.abyss)
end
function TEST_HOOK(dt)
	TT.t = TT.t + dt
	if TT.step == 0 and TT.t > 0.5 then
		TT.step = 1
		Game.start()
		Cmd.sel = 2
		local c = Cmd.ours[2]
		local i = 0
		local u = nil
		for i = 1, Units.n do
			u = Units.list[i]
			if u == c or u.boss == c then
				u.x = 41 + rnd(-0.5, 0.5)
				u.y = rnd(-1, 1)
				u.z = 4
			end
		end
	elseif TT.step == 1 and TT.t > 1.5 then
		TT.step = 2
		local c = Cmd.selected()
		census("before")
		Cmd.rally(c)
		census("rallied")
	elseif TT.step == 2 and TT.t > 7 then
		TT.step = 3
		census("scavenged")
		local c = Cmd.selected()
		Unit.die(c, "test")
	end
	if TT.t > TT.sec + 1 then
		TT.sec = TT.sec + 1
		if TT.step >= 3 then
			census("after")
		end
	end
end
