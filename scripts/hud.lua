-- hud — the 2D layer: commander cards, the troop count, toasts, hints, and
-- the title and end screens.
--
-- The gui raster is small (about 320x240, it stretches with the window) and
-- the font is caps-only with an 8px advance, so everything here is terse.
-- Integer coordinates are pixels.

HUD = { toasts = {}, nt = 0 }

TOAST_SECS = 2.8
C_PANEL = "141A26C8"
C_SHADOW = "00000060"
C_TEXT = "F2ECDC"
C_DIM = "A8B0C0"
C_GOLD = "F0C440"
C_RED = "E05050"
C_GREEN = "70D080"

function HUD.toast(msg)
	-- newest on top; old ones just age out (never deleted, see util.lua)
	HUD.nt = HUD.nt + 1
	local t = {}
	t.msg = msg
	t.t = G.time
	HUD.toasts[HUD.nt] = t
end

function HUD.panel(x, y, w, h)
	gui:rrect(x + 2, y + 2, w, h, 3, C_SHADOW)
	gui:rrect(x, y, w, h, 3, C_PANEL)
end

function HUD.bar(x, y, w, frac, col)
	gui:rect(x, y, w, 3, "30303A")
	local f = U.clamp(frac, 0, 1)
	local fw = flr(w * f)
	if fw > 0 then
		gui:rect(x, y, fw, 3, col)
	end
end

function HUD.draw()
	clr()
	local s = attr()
	local W = s.gw or 320
	local H = s.gh or 240
	if G.state == "intro" then
		HUD.intro(W, H)
		return
	end
	HUD.cards(W, H)
	HUD.counts(W, H)
	HUD.context(W, H)
	HUD.draw_toasts(W, H)
	if G.state == "won" or G.state == "lost" then
		HUD.ending(W, H)
	elseif G.paused then
		HUD.help(W, H)
	end
end

-- One card per commander of ours: number, name, tech, squad, health.
function HUD.cards(W, H)
	local i = 0
	local c = nil
	local y = 4
	local sel = Cmd.selected()
	local n = 0
	local armed = 0
	local line = ""
	local t = nil
	for i = 1, Cmd.nours do
		c = Cmd.ours[i]
		t = TECH[c.tech]
		HUD.panel(4, y, 156, 27)
		if c == sel then
			gui:rect(4, y, 156, 1, C_GOLD)
			gui:rect(4, y + 26, 156, 1, C_GOLD)
		end
		local num = tostring(i)
		gui:text(num, 8, y + 3, C_GOLD)
		gui:text(c.name, 20, y + 3, C_TEXT)
		n, armed = HUD.squad_of(c)
		local sn = tostring(n)
		local an = tostring(armed)
		local rounds = tostring(c.mag + c.ammo)
		line = t.short .. " SQ" .. sn .. " G" .. an .. " R" .. rounds
		gui:text(line, 8, y + 13, C_DIM)
		HUD.bar(8, y + 22, 146, c.hp / c.max, C_GREEN)
		y = y + 30
	end
end

function HUD.squad_of(c)
	local n = 0
	local armed = 0
	local i = 0
	local u = nil
	for i = 1, Units.n do
		u = Units.list[i]
		if not u.dead and u.boss == c then
			n = n + 1
			if u.weapon == "pistol" then
				armed = armed + 1
			end
		end
	end
	return n, armed
end

-- Top right: what we've got, what we've lost.
function HUD.counts(W, H)
	local troops = 0
	local armed = 0
	local rounds = 0
	local lost = 0
	local foes = 0
	local i = 0
	local u = nil
	for i = 1, Units.n do
		u = Units.list[i]
		if not u.dead then
			if u.team == 1 and not u.cmd then
				troops = troops + 1
				if u.weapon == "pistol" then
					armed = armed + 1
					rounds = rounds + u.mag + u.ammo
				end
				if u.order == "lost" then
					lost = lost + 1
				end
			elseif u.team == 2 then
				foes = foes + 1
			end
		end
	end
	local x = W - 108
	HUD.panel(x, 4, 104, 42)
	local a = tostring(troops)
	local b = tostring(armed)
	gui:text("TROOPS " .. a, x + 4, 7, C_TEXT)
	gui:text("ARMED  " .. b, x + 4, 16, C_TEXT)
	local r = tostring(rounds)
	gui:text("ROUNDS " .. r, x + 4, 25, C_GOLD)
	local f = tostring(foes)
	gui:text("ENEMY  " .. f, x + 4, 34, C_RED)
	if lost > 0 then
		local l = tostring(lost)
		gui:text(l .. " LOST", x + 4, 48, C_RED)
	end
end

-- Bottom: what the commander can do here, or the help line.
function HUD.context(W, H)
	local c = Cmd.selected()
	local msg = ""
	local msg2 = ""
	if c ~= nil and c.helm ~= nil then
		local s = c.helm
		msg = "AT THE HELM OF " .. s.name
		msg2 = "A/D FLY  W/S UP/DOWN  E LEAVE"
	elseif c ~= nil then
		local can = Cannons.near(c.x, c.y, c.z, 2.5)
		local helm = Ships.helm_near(c.x, c.y, c.z)
		if can ~= nil and can.team == 1 then
			local l = tostring(can.loaded)
			msg = "CANNON " .. l .. "/4: CLICK IT TO SET A CREW"
		elseif helm ~= nil and helm.team == 1 then
			msg = "E TAKE THE HELM"
		end
		msg2 = "LMB GO  RMB RALLY  F1 ORDERS"
	end
	if msg ~= "" then
		HUD.panel(4, H - 30, #msg * 8 + 8, 12)
		gui:text(msg, 8, H - 28, C_GOLD)
	end
	if msg2 ~= "" then
		gui:text(msg2, 6, H - 12, C_DIM)
	end
	-- capture progress at their flag
	if Game.capture_t > 0 then
		local w = 120
		local x = flr((W - w) / 2)
		HUD.panel(x - 4, 50, w + 8, 18)
		gui:text("TAKING THE FLAG", x, 52, C_GOLD)
		HUD.bar(x, 62, w, Game.capture_t / CAPTURE_SECS, C_GOLD)
	end
end

function HUD.draw_toasts(W, H)
	local y = 74
	local i = 0
	local t = nil
	local age = 0.0
	local shown = 0
	for i = HUD.nt, 1, -1 do
		t = HUD.toasts[i]
		age = G.time - t.t
		if age < TOAST_SECS and shown < 3 then
			shown = shown + 1
			local w = #t.msg * 8 + 8
			local x = flr((W - w) / 2)
			HUD.panel(x, y, w, 12)
			gui:text(t.msg, x + 4, y + 2, C_TEXT)
			y = y + 15
		end
		if age > 10 then
			break
		end
	end
end

function HUD.lines(lines, x, y, col)
	local i = 0
	for i = 1, #lines do
		gui:text(lines[i], x, y + (i - 1) * 10, col)
	end
end

function HUD.intro(W, H)
	local x = flr(W / 2) - 150
	HUD.panel(x, 20, 300, 196)
	gui:text("G U Y S", x + 120, 28, C_GOLD)
	local lines = {
		"THE GROUND IS NO PLACE TO LIVE.",
		"TAKE RIDGEBACK PASS AND THEIR",
		"FLYING FORTRESS AT THE END OF IT.",
		"",
		"YOUR SOLDIERS ONLY HEAR COMMANDERS",
		"WHOSE CIRCLE THEY STAND IN. FIND",
		"MEGAPHONES, RADIOS AND SOUND",
		"SYSTEMS TO REACH FURTHER.",
		"",
		"ENLIST CIVILIANS IN TOWNS. GUNS",
		"AND ROUNDS ARE SCARCE - PICK THEM",
		"UP. HAUL SHELLS TO CANNONS.",
		"LOSE CONTACT AND THEY WANDER OFF.",
	}
	HUD.lines(lines, x + 12, 44, C_TEXT)
	gui:text("CLICK OR PRESS SPACE", x + 70, 200, C_GOLD)
end

function HUD.help(W, H)
	local x = flr(W / 2) - 150
	HUD.panel(x, 30, 300, 176)
	gui:text("ORDERS", x + 120, 36, C_GOLD)
	local lines = {
		"WASD   MOVE      SPACE  JUMP",
		"LMB    GO THERE (OR CREW A CANNON)",
		"RMB    RALLY: FOLLOW ME / ENLIST",
		"H      HOLD THE LINE",
		"F      FORWARD MARCH",
		"Q      FIRE YOUR PISTOL",
		"E      TAKE / LEAVE THE HELM",
		"P      PROMOTE A VETERAN",
		"1 2 3  PICK A COMMANDER  C NEXT",
		"SCROLL ZOOM",
		"",
		"F1 OR ESC TO CLOSE",
	}
	HUD.lines(lines, x + 12, 52, C_TEXT)
end

function HUD.ending(W, H)
	local x = flr(W / 2) - 130
	HUD.panel(x, 46, 260, 130)
	local title = "THE PASS IS OURS"
	local col = C_GOLD
	if G.state == "lost" then
		title = "NO ONE LEFT TO COMMAND"
		col = C_RED
	end
	local tw = #title * 8
	gui:text(title, x + flr((260 - tw) / 2), 54, col)
	local st = Game.stats
	local a = tostring(st.enlisted)
	local b = tostring(st.fallen_us)
	local c = tostring(st.abyss)
	local d = tostring(st.fallen_them)
	local mins = flr(G.play_time / 60)
	local secs = flr(G.play_time % 60)
	local m = tostring(mins)
	local sc = tostring(secs)
	local lines = {}
	lines[1] = "CIVILIANS ENLISTED  " .. a
	lines[2] = "OURS FALLEN         " .. b
	lines[3] = "LOST TO THE CLOUDS  " .. c
	lines[4] = "ENEMIES DOWN        " .. d
	lines[5] = "TIME                " .. m .. "M " .. sc .. "S"
	HUD.lines(lines, x + 16, 74, C_TEXT)
	gui:text("PRESS ENTER TO PLAY AGAIN", x + 30, 158, C_GOLD)
end
