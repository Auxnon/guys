-- art — texture names for the generated sheets (tools/gen_art.py), the
-- textures made in code, and the sky.
--
-- sol.16.png slices into sol0..sol55: seven rows of eight frames (our
-- soldier, their soldier, our commander, their commander, a civilian, our
-- unarmed militia, their unarmed conscript). fx.16.png slices
-- into fx0..; FX_* below are its indices. Names are built once in A.init so
-- per-frame code never concatenates strings.

A = {}

FR_IDLE = 0
FR_WALK1 = 1
FR_WALK2 = 2
FR_SHOOT = 3
FR_PUNCH = 4
FR_FALL = 5
FR_CHEER = 5 -- arms up: falling, cheering and carrying share a frame
FR_DEAD = 6
FR_SLASH = 7

FX_FLASH = 0
FX_BULLET = 1
FX_DUST = 2
FX_SPARK = 3
FX_RING_SEL = 4
FX_RING = 5
FX_RING_FOE = 6
FX_POW = 7
FX_CRATE_MEGA = 8
FX_CRATE_RADIO = 9
FX_CRATE_SOUND = 10
FX_FLAG_US = 11
FX_FLAG_THEM = 12
FX_RETICLE = 13
FX_CHEVRON = 14
FX_LOST = 15
FX_ALERT = 16
FX_STAR = 17
FX_CLOUD = 18
FX_RING_RADIO = 19
FX_GUN = 20
FX_AMMO = 21
FX_BLADE = 22
FX_SHELL = 23
FX_PILE = 24
FX_CANNON = 25
FX_PIPS = 25 -- + level (1..3)
FX_BLAST = 29
FX_RING_TOWN = 30

function A.init()
	-- A.sol[row][frame + 1]; rows as in the header
	A.sol = {}
	local r = 0
	local f = 0
	local n = 0
	local name = ""
	for r = 1, 7 do
		local row = {}
		for f = 0, 7 do
			n = (r - 1) * 8 + f
			name = "sol" .. tostring(n)
			row[f + 1] = name
		end
		A.sol[r] = row
	end
	A.fx = {}
	local i = 0
	for i = 0, 31 do
		name = "fx" .. tostring(i)
		A.fx[i] = name
	end
	A.fire = {}
	for i = 0, 5 do
		name = "fire" .. tostring(i)
		A.fire[i] = name
	end
	A.make_textures()
	A.paint_sky()
end

-- The frame name for a unit, by team (0 civilian, 1 us, 2 them), rank and
-- whether it carries a pistol.
function A.frame(u, frame)
	local row = 5
	if u.team == 0 then
		row = 5
	elseif u.cmd then
		row = u.team + 2
	elseif u.weapon == "pistol" then
		row = u.team
	else
		row = u.team + 5
	end
	local r = A.sol[row]
	return r[frame + 1]
end

-- Textures drawn in code: snow caps and a darker rock for cliff faces.
function A.make_textures()
	local im = nimg(16, 16)
	im:fill("EEF2FA")
	local i = 0
	local x = 0
	local y = 0
	for i = 1, 14 do
		x = irnd(0, 15)
		y = irnd(0, 15)
		im:pixel(x, y, "C4D2EA")
	end
	tex("snow", im)

	local rk = nimg(16, 16)
	rk:fill("6B6470")
	for i = 1, 30 do
		x = irnd(0, 15)
		y = irnd(0, 15)
		rk:pixel(x, y, "57505C")
	end
	for i = 1, 10 do
		x = irnd(0, 15)
		y = irnd(0, 15)
		rk:pixel(x, y, "847C88")
	end
	tex("rock", rk)
end

-- A high-altitude sky: deep blue overhead fading to a pale haze at the
-- horizon, with a few streaks of cloud.
function A.paint_sky()
	local w = sky.w
	local h = sky.h
	local y = 0
	local t = 0.0
	local r = 0
	local g = 0
	local b = 0
	for y = 0, h - 1 do
		t = y / h
		r = flr(70 + t * 150)
		g = flr(110 + t * 120)
		b = flr(180 + t * 60)
		local col = { r, g, b }
		sky:rect(0, y, w, 1, col)
	end
	local i = 0
	local cx = 0
	local cy = 0
	local cw = 0
	for i = 1, 16 do
		cx = irnd(0, w)
		local lo = flr(h * 0.45)
		local hi = flr(h * 0.8)
		cy = irnd(lo, hi)
		cw = irnd(20, 70)
		sky:rect(cx, cy, cw, 2, "F2F4FA")
		sky:rect(cx + 6, cy - 1, cw - 12, 1, "FFFFFF")
	end
end
