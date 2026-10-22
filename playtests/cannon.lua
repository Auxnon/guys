-- cannon: Rook's squad crews the camp cannon (shells from the pile), and a
-- raiding party walks up the valley into its range.
TT = { t = 0, step = 0, sec = 0 }
ORIG_BLAST = Combat.blast
function Combat.blast(x, y, z, team)
	print("T", "blast", flr(x), flr(y), flr(z))
	ORIG_BLAST(x, y, z, team)
end
function TEST_HOOK(dt)
	TT.t = TT.t + dt
	local c = Cmd.selected()
	if TT.step == 0 and TT.t > 0.5 then
		TT.step = 1
		Game.start()
		local can = Cannons.list[1]
		Cmd.go(c, can.x, can.y, can.z)
	elseif TT.step == 1 and TT.t > 8 then
		TT.step = 2
		-- the outpost marches on the camp
		local i = 0
		local u = nil
		for i = 1, Units.n do
			u = Units.list[i]
			if u.team == 2 and u.x > 26 and u.x < 34 then
				u.order = "go"
				u.gx = 17
				u.gy = u.y
			end
		end
	end
	if TT.t > TT.sec + 1 then
		TT.sec = TT.sec + 1
		local can = Cannons.list[1]
		local pile = Piles.list[1]
		local carrying = 0
		local hauling = 0
		local i = 0
		local u = nil
		local them = 0
		for i = 1, Units.n do
			u = Units.list[i]
			if not u.dead and u.order == "haul" then
				hauling = hauling + 1
				if u.carry then
					carrying = carrying + 1
				end
			end
			if not u.dead and u.team == 2 and u.x < 36 then
				them = them + 1
			end
		end
		print("T", flr(G.time), "loaded", can.loaded, "pile", pile.stock, "hauling", hauling, "carrying", carrying, "outpost", them)
	end
end
