-- cmd — commanders: their reach, their orders, their squads in formation,
-- and the circles on the ground that show who can hear them.
--
-- A side fields at most three commanders in a region (CMD_MAX). Soldiers
-- only take orders from a commander whose circle they stand in, and the
-- circle is as wide as the commander's comm tech carries:
--
--   VOICE         shouting, a few tiles
--   MEGAPHONE     a good deal further
--   RADIO         further still, and relays: an order from one radio
--                 commander reaches soldiers in any other radio commander's
--                 circle too
--   SOUND SYSTEM  the widest circle (and a radio), but heavy to lug about
--
-- Soldiers following a commander keep to a formation behind it (rows
-- trailing its heading), but walk there under their own steam: AI.follow
-- steers each to its slot with the usual eased velocity, soft bodies and
-- walls, so the squad files along naturally instead of snapping into place.
-- Anyone following who stays out of the circle too long loses contact and
-- wanders off, lemming-style, until someone rallies them.

Cmd = {}

CMD_MAX = 3
LOST_SECS = 5.0
RING_DOTS = 40
RING_POOL = 6
SLOT_BACK = 1.3 -- first row's distance behind the commander
SLOT_ROW = 0.85 -- between rows
SLOT_COL = 0.85 -- between files
SLOT_FILES = 3

TECH = {
	{ name = "VOICE", short = "VOICE", r = 3.6, slow = 1.0 },
	{ name = "MEGAPHONE", short = "MEGA", r = 5.6, slow = 1.0 },
	{ name = "RADIO", short = "RADIO", r = 7.6, slow = 1.0 },
	{ name = "SOUND SYSTEM", short = "SOUND", r = 10.5, slow = 0.8 },
}

NAMES_US = { "ROOK", "ASHA", "BRASK", "MOTT", "FENN", "IVO", "TAMSIN", "KESTREL", "BODDY", "WREN" }
NAMES_THEM = { "VOSS", "KARG", "DREL", "OSKAR", "MAULE" }

function Cmd.init()
	Cmd.ours = {}
	Cmd.nours = 0
	Cmd.sel = 1
	Cmd.slot_t = 0.0
	Cmd.rings = {}
	local i = 0
	local j = 0
	local dots = nil
	local e = nil
	for i = 1, RING_POOL do
		local r = {}
		dots = {}
		for j = 1, RING_DOTS do
			e = make("fx5", 0, 0, -100, 0.28)
			dots[j] = e
		end
		r.dots = dots
		r.tex = "fx5"
		r.hidden = true
		Cmd.rings[i] = r
	end
	local m = make("fx14", 0, 0, -100, 0.5)
	Cmd.marker = m
end

-- Make unit `u` a commander of its side with a name.
function Cmd.enlist_commander(u, name)
	Unit.make_commander(u)
	u.tech = 1
	u.name = name
	u.pulse_t = 0.0
	u.fh = 0.0
	if u.weapon ~= "pistol" then
		Unit.arm(u, "pistol")
		u.mag = MAG
	end
	u.speed = CMD_SPEED
end

function Cmd.tech_of(kind)
	if kind == "megaphone" then
		return 2
	end
	if kind == "radio" then
		return 3
	end
	if kind == "sound" then
		return 4
	end
	return 1
end

function Cmd.upgrade(c, kind)
	local t = Cmd.tech_of(kind)
	if t <= c.tech then
		return
	end
	c.tech = t
	local tt = TECH[t]
	c.speed = CMD_SPEED * tt.slow
	Cmd.pulse(c)
	local msg = c.name .. " GOT A " .. tt.name
	if t == 3 then
		msg = msg .. " - RELAYS ORDERS"
	end
	HUD.toast(msg)
	Unit.flash_icon(c, "fx17", 1.5)
end

function Cmd.radius(c)
	local t = TECH[c.tech]
	local r = t.r
	if c.pulse_t > 0 then
		-- an order ripples out from the commander
		local k = 1 - c.pulse_t / 0.35
		r = r * (0.35 + 0.65 * k)
	end
	return r
end

function Cmd.full_radius(c)
	local t = TECH[c.tech]
	return t.r
end

-- Is `u` inside commander c's circle?
function Cmd.inside(c, u)
	local r = Cmd.full_radius(c)
	if U.abs(u.z - c.z) > 4 then
		return false
	end
	return U.d2(c.x, c.y, u.x, u.y) <= r * r
end

-- Can `u` hear an order from c, directly or by radio relay?
function Cmd.hears(c, u)
	if Cmd.inside(c, u) then
		return true
	end
	if c.tech < 3 then
		return false
	end
	local i = 0
	local o = nil
	for i = 1, Units.n do
		o = Units.list[i]
		if o.cmd and not o.dead and o ~= c and o.team == c.team and o.tech ~= nil and o.tech >= 3 then
			if Cmd.inside(o, u) then
				return true
			end
		end
	end
	return false
end

function Cmd.pulse(c)
	c.pulse_t = 0.35
end

-- Everyone (not a commander) on c's side, or a civilian, who hears c.
function Cmd.listeners(c, out)
	local n = 0
	local i = 0
	local u = nil
	for i = 1, Units.n do
		u = Units.list[i]
		if not u.dead and not u.cmd and (u.team == c.team or (u.team == 0 and c.team == 1)) then
			if Cmd.hears(c, u) then
				n = n + 1
				out[n] = u
			end
		end
	end
	return n
end

function Cmd.join(c, u)
	if u.team == 0 then
		-- a civilian signs up: level 0, bare fists until someone finds them better
		u.team = 1
		u.frame = -1
		u.speed = UNIT_SPEED * (0.92 + rnd() * 0.16)
		Unit.pose(u, FR_CHEER, 0.6)
		Fx.star(u.x, u.y, u.z + 1.3)
		Game.stats.enlisted = Game.stats.enlisted + 1
	end
	if u.boss ~= c then
		Cmd.next_slot = (Cmd.next_slot or 0) + 1
		u.slot = Cmd.next_slot
	end
	u.boss = c
	u.lost_t = 0.0
end

-- -- orders (the commander you control gives these from input.lua; enemy
-- commanders from ai.lua)

-- Rally: everyone who hears comes and follows; civilians sign up.
function Cmd.rally(c)
	local list = {}
	local n = Cmd.listeners(c, list)
	local i = 0
	local u = nil
	local joined = 0
	local civ = 0
	for i = 1, n do
		u = list[i]
		if u.team == 0 then
			civ = civ + 1
		end
		if u.boss ~= c or u.order ~= "follow" then
			joined = joined + 1
		end
		Cmd.join(c, u)
		u.order = "follow"
		u.job = nil
		u.carry = false
	end
	Cmd.pulse(c)
	if c.team == 1 then
		Sfx.whistle()
		local msg = ""
		if civ > 0 then
			msg = tostring(civ)
			HUD.toast(msg .. " CIVILIANS ENLISTED")
		elseif joined > 0 then
			msg = tostring(joined)
			HUD.toast(msg .. " FALL IN")
		end
	end
	return n
end

-- Go: the squad (and anyone else who hears) heads for a point, spread out
-- round it, and fights whatever it meets. Pointing at a cannon instead puts
-- them to hauling shells for it.
function Cmd.go(c, px, py, pz)
	local list = {}
	local n = Cmd.listeners(c, list)
	local can = Cannons.near(px, py, pz, 1.6)
	if can ~= nil and can.team ~= c.team then
		can = nil
	end
	local i = 0
	local u = nil
	local k = 0
	local ox = 0.0
	local oy = 0.0
	local ring = 0
	local a = 0.0
	for i = 1, n do
		u = list[i]
		if u.team == c.team or u.team == 0 then
			Cmd.join(c, u)
			if can ~= nil then
				u.order = "haul"
				u.job = can
			else
				-- a sunflower spread, so they fan out instead of piling up
				k = k + 1
				ring = sqrt(k) * 0.55
				a = k * 2.4
				ox = cos(a) * ring
				oy = sin(a) * ring * 0.8
				u.order = "go"
				u.gx = px + ox
				u.gy = py + oy
				u.job = nil
				u.carry = false
			end
		end
	end
	Cmd.pulse(c)
	if c.team == 1 then
		Sfx.order()
		Fx.reticle(px, py, pz)
		if can ~= nil then
			HUD.toast("CREW TO THE CANNON: HAUL SHELLS")
		end
	end
	return n
end

-- Hold: stay put and shoot from where you stand.
function Cmd.hold(c)
	local list = {}
	local n = Cmd.listeners(c, list)
	local i = 0
	local u = nil
	for i = 1, n do
		u = list[i]
		if u.team == c.team then
			Cmd.join(c, u)
			u.order = "hold"
			u.gx = u.x
			u.gy = u.y
			u.job = nil
		end
	end
	Cmd.pulse(c)
	if c.team == 1 then
		Sfx.order()
		HUD.toast("HOLD THE LINE")
	end
end

-- March: forward the way the commander faces, and keep going. They turn at
-- walls, but not at edges.
function Cmd.march(c)
	local list = {}
	local n = Cmd.listeners(c, list)
	local i = 0
	local u = nil
	for i = 1, n do
		u = list[i]
		if u.team == c.team then
			Cmd.join(c, u)
			u.order = "march"
			u.mdir = c.face
			u.job = nil
		end
	end
	Cmd.pulse(c)
	if c.team == 1 then
		Sfx.order()
		HUD.toast("FORWARD MARCH!")
	end
end

-- Promote: a proven soldier (level 1+) in the circle takes a commission,
-- if the side has room for another commander.
function Cmd.promote(c)
	if Cmd.nours >= CMD_MAX then
		HUD.toast("THREE COMMANDERS ALREADY")
		return
	end
	local list = {}
	local n = Cmd.listeners(c, list)
	local best = nil
	local i = 0
	local u = nil
	for i = 1, n do
		u = list[i]
		if u.team == 1 and u.level >= 1 and (best == nil or u.level > best.level or (u.level == best.level and u.kills > best.kills)) then
			best = u
		end
	end
	if best == nil then
		HUD.toast("NEEDS A VETERAN IN THE CIRCLE (LEVEL 1+)")
		return
	end
	local nm = U.pick(NAMES_US)
	local name = "SGT " .. nm
	best.boss = nil
	best.order = "idle"
	Cmd.enlist_commander(best, name)
	Fx.star(best.x, best.y, best.z + 1.5)
	Sfx.level()
	HUD.toast(name .. " TAKES COMMAND")
end

-- -- every frame

function Cmd.update(dt)
	-- our living commanders, in a stable order
	local ours = {}
	local n = 0
	local i = 0
	local u = nil
	for i = 1, Units.n do
		u = Units.list[i]
		if u.cmd and not u.dead and u.team == 1 then
			n = n + 1
			ours[n] = u
		end
	end
	Cmd.ours = ours
	Cmd.nours = n
	if Cmd.sel > n then
		Cmd.sel = 1
	end
	for i = 1, Units.n do
		u = Units.list[i]
		if u.cmd and not u.dead then
			u.pulse_t = u.pulse_t - dt
			Cmd.steer_formation(u, dt)
		end
	end
	Cmd.slot_t = Cmd.slot_t - dt
	if Cmd.slot_t <= 0 then
		Cmd.slot_t = 0.5
		Cmd.assign_slots()
	end
	Cmd.check_contact(dt)
	Cmd.draw_rings()
end

function Cmd.selected()
	if Cmd.nours == 0 then
		return nil
	end
	return Cmd.ours[Cmd.sel]
end

-- The formation faces where the commander has been heading, eased so a
-- small dodge doesn't swing the whole squad round.
function Cmd.steer_formation(c, dt)
	local sp = c.vx * c.vx + c.vy * c.vy
	if sp > 0.5 then
		local d = U.angle_diff(c.fh, c.heading)
		local k = U.ease(2.5, dt)
		c.fh = U.wrap(c.fh + d * k)
	end
end

-- Followers get slots 1..n in the order they joined, so the formation
-- closes ranks when someone falls.
function Cmd.assign_slots()
	local i = 0
	local u = nil
	local c = nil
	local per = {}
	for i = 1, Units.n do
		u = Units.list[i]
		if not u.dead and u.order == "follow" and u.boss ~= nil then
			c = u.boss
			local list = per[c.id]
			if list == nil then
				list = {}
				per[c.id] = list
			end
			list[#list + 1] = u
		end
	end
	local id = 0
	local list = nil
	local j = 0
	local k = 0
	local tmp = nil
	for id, list in pairs(per) do
		-- insertion sort by join order (lists are small)
		for j = 2, #list do
			k = j
			while k > 1 and list[k - 1].slot > list[k].slot do
				tmp = list[k - 1]
				list[k - 1] = list[k]
				list[k] = tmp
				k = k - 1
			end
		end
		for j = 1, #list do
			u = list[j]
			u.rank = j
		end
	end
end

-- Where follower `u`'s slot is: rows of SLOT_FILES trailing the commander,
-- every other row staggered by half a file.
function Cmd.slot_pos(c, u)
	local r = (u.rank or 1) - 1
	local row = flr(r / SLOT_FILES)
	local col = r - row * SLOT_FILES
	local back = SLOT_BACK + row * SLOT_ROW
	local side = (col - (SLOT_FILES - 1) / 2) * SLOT_COL
	if row % 2 == 1 then
		side = side + SLOT_COL * 0.5
	end
	local fx = cos(c.fh)
	local fy = sin(c.fh)
	return c.x - fx * back - fy * side, c.y - fy * back + fx * side
end

-- Followers out of their commander's circle too long lose contact, and so
-- does everyone whose commander has fallen.
function Cmd.check_contact(dt)
	local i = 0
	local u = nil
	local c = nil
	local lost = 0
	for i = 1, Units.n do
		u = Units.list[i]
		if not u.dead and not u.cmd and u.boss ~= nil then
			c = u.boss
			if c.dead then
				Cmd.lose(u)
				if u.team == 1 then
					lost = lost + 1
				end
			elseif u.order == "follow" then
				if u.busy or Cmd.hears(c, u) then
					u.lost_t = 0.0
				else
					u.lost_t = u.lost_t + dt
					if u.lost_t > LOST_SECS then
						Cmd.lose(u)
						if u.team == 1 then
							lost = lost + 1
						end
					end
				end
			end
		end
	end
	if lost > 0 then
		local msg = tostring(lost) .. " LOST CONTACT"
		HUD.toast(msg)
	end
end

function Cmd.lose(u)
	u.boss = nil
	u.order = "lost"
	u.job = nil
	u.carry = false
	if U.chance(0.5) then
		u.mdir = 1
	else
		u.mdir = -1
	end
end

-- -- the circles

function Cmd.draw_rings()
	local used = 0
	local i = 0
	local c = nil
	local sel = Cmd.selected()
	local tex = ""
	for i = 1, Cmd.nours do
		c = Cmd.ours[i]
		used = used + 1
		tex = "fx5"
		if c == sel then
			tex = "fx4"
		elseif c.tech >= 3 then
			tex = "fx19"
		end
		Cmd.draw_ring(Cmd.rings[used], c, tex)
	end
	-- their commanders near the camera
	local u = nil
	for i = 1, Units.n do
		u = Units.list[i]
		if used < RING_POOL and u.cmd and not u.dead and u.team == 2 then
			if U.abs(u.x - Cam.x) < 26 then
				used = used + 1
				Cmd.draw_ring(Cmd.rings[used], u, "fx6")
			end
		end
	end
	for i = used + 1, RING_POOL do
		Cmd.hide_ring(Cmd.rings[i])
	end
	-- the chevron over the commander you're controlling
	local m = Cmd.marker
	if sel ~= nil then
		m.x = sel.x
		m.y = sel.y
		m.z = sel.z + 2.1 + sin(G.time * 4) * 0.08
	else
		m.z = -100
	end
end

function Cmd.hide_ring(r)
	if r.hidden then
		return
	end
	local j = 0
	local e = nil
	for j = 1, RING_DOTS do
		e = r.dots[j]
		e.z = -100
	end
	r.hidden = true
end

-- Dots round the circle, each set down on whatever ground is under it so
-- the ring drapes over steps and decks; none over the abyss.
function Cmd.draw_ring(r, c, tex)
	local rad = Cmd.radius(c)
	local spin = G.time * 0.15
	local j = 0
	local e = nil
	local a = 0.0
	local x = 0.0
	local y = 0.0
	local g = nil
	local wall = false
	local ship = nil
	local retex = r.tex ~= tex
	r.tex = tex
	r.hidden = false
	for j = 1, RING_DOTS do
		e = r.dots[j]
		if retex then
			e.tex = tex
		end
		a = j / RING_DOTS * tau + spin
		x = c.x + cos(a) * rad
		y = c.y + sin(a) * rad
		g, wall, ship = W.ground(x, y, c.z + 2.5)
		if g ~= nil and g > c.z - 4 then
			e.x = x
			e.y = y
			e.z = g + 0.08
		else
			e.z = -100
		end
	end
end
