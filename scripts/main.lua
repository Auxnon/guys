-- guys — a squad brawler in the mountains and the sky, on Petrichor64.
--
-- Metal Slug's guns, Pikmin's squads, Lemmings' sense of direction. You lead
-- up to three commanders; soldiers only hear a commander whose circle they
-- stand in (cmd.lua). Pistols are powerful, wild and short of rounds, so
-- most fights are fists and blades. Towns have civilians to enlist; shells
-- have to be carried to cannons by hand; and the way on is by airship
-- (ships.lua, after sosh's). Take the flag on their flying fortress to win.
--
-- Files: util art terrain ships unit combat gear cmd ai fx sfx hud input
-- level, and this one, which owns the game state, the camera and the frame
-- loop. Top level everywhere is definitions only; setup happens in main().
-- Z is up; the camera looks along +y, so +x is screen right.

G = { time = 0.0, last = -1.0, state = "intro", paused = false, play_time = 0.0 }
Game = { capture_t = 0.0, tombs = {}, ntombs = 0 }
Cam = { x = 4.0, y = 0.0, z = 6.0, ex = 0.0, ey = 0.0, ez = 0.0, dist = 15.0, pitch = -0.46 }

CAPTURE_SECS = 4.0

function main()
	attr({ title = "GUYS" })
	A.init()
	Sfx.init()
	fog(1100)
	tileset("ground", { "grass", "rock", "snow" }, { look = "block" })
	Level.build_terrain()
	Level.build_scenery()
	Fx.init()
	Combat.init()
	Cmd.init()
	Input.init()
	Game.reset_stats()
	Level.populate()
	Cam.update(1.0, true)
end

function loop()
	local now_t = now()
	local dt = 0.016
	if G.last >= 0 then
		dt = now_t - G.last
	end
	G.last = now_t
	if dt > 0.05 then
		dt = 0.05
	end
	if dt <= 0 then
		dt = 0.001
	end
	if TEST_HOOK ~= nil then
		TEST_HOOK(dt)
	end
	G.time = G.time + dt

	Input.update(dt)
	local live = (G.state == "play" or G.state == "won") and not G.paused
	if live then
		if G.state == "play" then
			G.play_time = G.play_time + dt
		end
		Ships.update(dt)
		Units.update(dt)
		Combat.update(dt)
		Gear.update(dt)
	end
	Cmd.update(dt)
	Level.update(dt)
	if live then
		Game.update(dt)
	end
	Fx.update(dt)
	Cam.update(dt, false)
	HUD.draw()
end

function draw() end

-- -- camera

-- Follows the commander you control (or the ship they're flying) from the
-- front and above, easing so it glides.
function Cam.update(dt, snap)
	local c = Cmd.selected()
	local tx = Cam.x
	local ty = Cam.y
	local tz = Cam.z
	local extra = 0.0
	if c ~= nil then
		if c.helm ~= nil then
			local s = c.helm
			tx = s.x
			ty = s.y
			tz = s.z
			extra = 4.0
		else
			tx = c.x
			ty = c.y * 0.5
			tz = c.z
		end
	end
	local k = U.ease(3.5, dt)
	if snap then
		k = 1.0
	end
	Cam.x = Cam.x + (tx - Cam.x) * k
	Cam.y = Cam.y + (ty - Cam.y) * k
	Cam.z = Cam.z + (tz - Cam.z) * k
	Cam.d = (Cam.d or Cam.dist) + (Cam.dist + extra - (Cam.d or Cam.dist)) * k
	local p = Cam.pitch
	local cp = cos(p)
	local sp = sin(p)
	Cam.ex = Cam.x
	Cam.ey = Cam.y - cp * Cam.d
	Cam.ez = Cam.z + 1.0 - sp * Cam.d
	local pos = { Cam.ex, Cam.ey, Cam.ez }
	local rot = { tau / 4, p }
	cam({ pos = pos, rot = rot })
end

-- -- game state

function Game.reset_stats()
	local st = {}
	st.enlisted = 0
	st.fallen_us = 0
	st.fallen_them = 0
	st.abyss = 0
	st.civilians = 0
	Game.stats = st
	Game.capture_t = 0.0
	Game.warned_shells = false
	G.play_time = 0.0
end

function Game.start()
	G.state = "play"
	HUD.toast("TAKE THE VALLEY. RMB RALLIES YOUR SQUAD")
end

-- Someone fell: drop what they carried, keep the tally, mark commanders.
function Game.on_death(u, why)
	local st = Game.stats
	if u.team == 0 then
		st.civilians = st.civilians + 1
	elseif u.team == 1 then
		st.fallen_us = st.fallen_us + 1
		if why == "abyss" then
			st.abyss = st.abyss + 1
		end
	else
		st.fallen_them = st.fallen_them + 1
	end
	if why ~= "abyss" then
		if u.weapon == "pistol" then
			local rounds = u.mag + u.ammo
			Pick.add("gun", u.x, u.y, u.z, rounds)
		elseif u.weapon == "blade" then
			Pick.add("blade", u.x, u.y, u.z, 0)
		end
	end
	u.carry = false
	if u.cmd then
		local msg = u.name .. " HAS FALLEN"
		if u.team == 2 then
			msg = u.name .. " IS DOWN - THEY SCATTER"
		end
		HUD.toast(msg)
		if why ~= "abyss" then
			local e = make("tombstone", u.x, u.y + 0.3, u.z + 0.5, 1.0)
			Game.ntombs = Game.ntombs + 1
			Game.tombs[Game.ntombs] = e
		end
		if u.helm ~= nil then
			local s = u.helm
			s.pilot = nil
			u.helm = nil
		end
	elseif u.team == 1 and why == "abyss" then
		HUD.toast("ONE OF OURS FELL INTO THE CLOUDS")
	end
end

function Game.update(dt)
	if G.state ~= "play" then
		return
	end
	if Cmd.nours == 0 then
		G.state = "lost"
		return
	end
	-- a commander of ours at their flag, with none of them close by
	local fl = Level.flag
	local holder = nil
	local i = 0
	local u = nil
	local foes = 0
	for i = 1, Units.n do
		u = Units.list[i]
		if not u.dead then
			if u.cmd and u.team == 1 and U.abs(u.z - fl.z) < 1.5 then
				if U.d2(u.x, u.y, fl.x, fl.y) < 3.2 then
					holder = u
				end
			end
			if u.team == 2 and U.d2(u.x, u.y, fl.x, fl.y) < 36 and U.abs(u.z - fl.z) < 3 then
				foes = foes + 1
			end
		end
	end
	if holder ~= nil and foes == 0 then
		Game.capture_t = Game.capture_t + dt
		if Game.capture_t >= CAPTURE_SECS then
			G.state = "won"
			local e = fl.ent
			e.tex = "fx11"
			Unit.pose(holder, FR_CHEER, 3)
			Sfx.level()
		end
	else
		Game.capture_t = U.max(0, Game.capture_t - dt * 2)
	end
end

-- Start over: clear everything but the mountains, and populate again.
function Game.restart()
	local i = 0
	local u = nil
	local e = nil
	for i = 1, Units.n do
		u = Units.list[i]
		e = u.ent
		e:kill()
		e = u.icon_ent
		e:kill()
		e = u.pip_ent
		e:kill()
	end
	Units.list = {}
	Units.n = 0
	local s = nil
	for i = 1, Ships.n do
		s = Ships.list[i]
		e = s.ent
		e:kill()
	end
	Ships.list = {}
	Ships.n = 0
	local p = nil
	for i = 1, Pick.n do
		p = Pick.list[i]
		e = p.ent
		e:kill()
	end
	Pick.list = {}
	Pick.n = 0
	for i = 1, Piles.n do
		p = Piles.list[i]
		e = p.ent
		e:kill()
	end
	Piles.list = {}
	Piles.n = 0
	for i = 1, Cannons.n do
		p = Cannons.list[i]
		e = p.ent
		e:kill()
	end
	Cannons.list = {}
	Cannons.n = 0
	for i = 1, Game.ntombs do
		e = Game.tombs[i]
		e:kill()
	end
	Game.tombs = {}
	Game.ntombs = 0
	local fl = Level.flag
	e = fl.ent
	e:kill()
	for i = 1, Bul.n do
		p = Bul.list[i]
		p.alive = false
		e = p.ent
		e.z = -100
	end
	for i = 1, Shells.n do
		p = Shells.list[i]
		p.alive = false
		e = p.ent
		e.z = -100
	end
	HUD.toasts = {}
	HUD.nt = 0
	Cmd.next_slot = 0
	Input.warned_dry = false
	Game.reset_stats()
	Level.populate()
	G.state = "play"
	G.paused = false
	Cam.update(1.0, true)
end
