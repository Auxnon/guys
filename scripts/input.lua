-- input — keys and mouse for the commander you control.
--
-- Everything routes through plain functions (Cmd.go, Cmd.rally, Input.helm
-- …) so playtests can drive the same code. The mouse is read through
-- MOUSE_FAKE when a test sets it.
--
--   WASD / arrows  walk (or fly, at a helm)      SPACE  jump
--   LMB            go there / crew a cannon       RMB    rally (hold: keep calling)
--   H hold   F march   Q fire   E helm   P promote   1 2 3 / C  pick commander
--   F1 / ESC orders   scroll zoom   ENTER restart (after the end)

Input = { last_m1 = false, last_m2 = false, rally_t = 0.0 }

function Input.init()
	local e = make("fx13", 0, 0, -100, 0.7)
	Input.cursor = e
end

function Input.mouse()
	local m = mus()
	if MOUSE_FAKE ~= nil then
		m = MOUSE_FAKE
	end
	return m
end

-- Where the pointer meets the world (rock or deck), or nil.
function Input.pick(m)
	return W.ray(Cam.ex, Cam.ey, Cam.ez, m.vx, m.vy, m.vz, 90)
end

function Input.update(dt)
	local m = Input.mouse()
	local m1 = m.m1 == true
	local m2 = m.m2 == true
	local click1 = m1 and not Input.last_m1
	local click2 = m2 and not Input.last_m2
	Input.last_m1 = m1
	Input.last_m2 = m2

	if G.state == "intro" then
		local go = key("space", true) or key("enter", true)
		if click1 or go then
			Game.start()
		end
		return
	end
	if G.state == "won" or G.state == "lost" then
		local again = key("enter", true)
		if again then
			Game.restart()
		end
		return
	end
	local help = key("f1", true) or key("escape", true)
	if help then
		G.paused = not G.paused
	end
	if G.paused then
		return
	end

	Input.choose()
	Input.idle_ship()
	local c = Cmd.selected()
	local cur = Input.cursor
	if c == nil then
		cur.z = -100
		return
	end

	local px, py, pz = Input.pick(m)
	if px ~= nil then
		cur.x = px
		cur.y = py
		cur.z = pz + 0.12
	else
		cur.z = -100
	end

	if c.helm ~= nil then
		Input.fly(c, dt)
	else
		Input.walk(c)
	end

	if click1 and px ~= nil then
		Cmd.go(c, px, py, pz)
	end
	if click2 then
		Cmd.rally(c)
		Input.rally_t = 0.5
	elseif m2 then
		-- keep whistling while the button is held
		Input.rally_t = Input.rally_t - dt
		if Input.rally_t <= 0 then
			Input.rally_t = 0.5
			Cmd.rally(c)
		end
	end
	if key("h", true) then
		Cmd.hold(c)
	end
	if key("f", true) then
		Cmd.march(c)
	end
	if key("p", true) then
		Cmd.promote(c)
	end
	if key("e", true) then
		Input.helm(c)
	end
	if key("q") and px ~= nil then
		Input.fire(c, px, py, pz)
	end
	if m.scroll ~= nil and m.scroll ~= 0 then
		Cam.dist = U.clamp(Cam.dist - m.scroll * 1.5, 9, 30)
	end
end

-- 1 2 3 pick a commander, C goes to the next.
function Input.choose()
	local i = 0
	local k = false
	local names = { "1", "2", "3" }
	for i = 1, 3 do
		k = key(names[i], true)
		if k and i <= Cmd.nours then
			Cmd.sel = i
		end
	end
	if key("c", true) and Cmd.nours > 0 then
		Cmd.sel = Cmd.sel % Cmd.nours + 1
	end
end

function Input.walk(c)
	c.careful = true
	c.edge = 3.2
	local ix = 0.0
	local iy = 0.0
	if key("w") or key("up") or btn("dup") then
		iy = iy + 1.0
	end
	if key("s") or key("down") or btn("ddown") then
		iy = iy - 1.0
	end
	if key("a") or key("left") or btn("dleft") then
		ix = ix - 1.0
	end
	if key("d") or key("right") or btn("dright") then
		ix = ix + 1.0
	end
	if WALK_FAKE ~= nil then
		ix = WALK_FAKE[1]
		iy = WALK_FAKE[2]
	end
	local len = sqrt(ix * ix + iy * iy)
	if len > 0.0001 then
		c.wx = ix / len
		c.wy = iy / len
	else
		c.wx = 0.0
		c.wy = 0.0
	end
	if key("space", true) or btn("south") then
		c.want_jump = true
	end
end

-- Take the helm of a ship within reach, or let go of it.
function Input.helm(c)
	if c.helm ~= nil then
		local s = c.helm
		s.pilot = nil
		c.helm = nil
		return
	end
	local s = Ships.helm_near(c.x, c.y, c.z)
	if s ~= nil and s.team == 1 then
		c.helm = s
		s.pilot = c
		HUD.toast("YOU HAVE THE HELM")
	end
end

-- At the helm: A/D ahead and astern (along the screen), W/S climb and sink.
-- The pilot stays at the wheel; the crew ride along.
function Input.fly(c, dt)
	local s = c.helm
	if s.pilot ~= c or c.dead then
		c.helm = nil
		return
	end
	local dir = 0.0
	if key("a") or key("left") then
		dir = dir - 1.0
	end
	if key("d") or key("right") then
		dir = dir + 1.0
	end
	local lift = 0.0
	if key("w") or key("up") then
		lift = lift + 1.0
	end
	if key("s") or key("down") then
		lift = lift - 1.0
	end
	if FLY_FAKE ~= nil then
		dir = FLY_FAKE[1]
		lift = FLY_FAKE[2]
	end
	local ch = cos(s.h)
	s.thrust = dir * U.sign(ch)
	s.lift = lift
	s.turn = 0.0
	local hx, hy, hz = Ships.helm_spot(s)
	c.wx = (hx - c.x) * 4
	c.wy = (hy - c.y) * 4
	c.wx = U.clamp(c.wx, -1, 1)
	c.wy = U.clamp(c.wy, -1, 1)
	c.face = U.sign(ch)
end

-- Our ship only answers the commander you're controlling: anyone else at
-- the helm just holds her where she is.
function Input.idle_ship()
	local s = Ships.player_ship()
	if s == nil then
		return
	end
	local c = Cmd.selected()
	if s.pilot ~= nil and s.pilot ~= c then
		s.thrust = 0.0
		s.lift = 0.0
		s.turn = 0.0
	end
end

-- The commander's own pistol, at the pointer.
function Input.fire(c, px, py, pz)
	local ok = Combat.shoot(c, px, py, pz + 0.6)
	if not ok and c.mag == 0 and c.ammo == 0 and c.weapon == "pistol" and not Input.warned_dry then
		Input.warned_dry = true
		HUD.toast("OUT OF ROUNDS")
	end
end
