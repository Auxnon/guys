-- fx — short-lived sprites: muzzle flashes, sparks, dust, punches, blasts.
--
-- A fixed pool made at startup; a free sprite is parked far below the
-- world (z -100) rather than killed, so nothing is created per frame.

Fx = { list = {}, n = 0, next = 1 }

FX_POOL = 70

function Fx.init()
	local i = 0
	local p = nil
	local e = nil
	for i = 1, FX_POOL do
		p = {}
		e = make("fx2", 0, 0, -100, 0.5)
		p.ent = e
		p.t = 0.0
		p.alive = false
		p.tex = "fx2"
		Fx.list[i] = p
	end
	Fx.n = FX_POOL
end

-- Show texture `tex` at (x, y, z) for `life` seconds, growing from scale
-- s0 to s1 and drifting up at vz.
function Fx.spawn(tex, x, y, z, life, s0, s1, vz)
	local p = Fx.list[Fx.next]
	Fx.next = Fx.next + 1
	if Fx.next > Fx.n then
		Fx.next = 1
	end
	p.x = x
	p.y = y
	p.z = z
	p.life = life
	p.t = 0.0
	p.s0 = s0
	p.s1 = s1
	p.vz = vz
	p.alive = true
	local e = p.ent
	if p.tex ~= tex then
		e.tex = tex
		p.tex = tex
	end
	e.x = x
	e.y = y
	e.z = z
	e.scale = s0
	return p
end

function Fx.update(dt)
	local i = 0
	local p = nil
	local e = nil
	local k = 0.0
	for i = 1, Fx.n do
		p = Fx.list[i]
		if p.alive then
			p.t = p.t + dt
			e = p.ent
			if p.t >= p.life then
				p.alive = false
				e.z = -100
			else
				k = p.t / p.life
				p.z = p.z + p.vz * dt
				e.z = p.z
				e.scale = p.s0 + (p.s1 - p.s0) * k
			end
		end
	end
end

function Fx.flash(x, y, z)
	Fx.spawn("fx0", x, y, z, 0.06, 0.55, 0.3, 0)
end

function Fx.spark(x, y, z)
	Fx.spawn("fx3", x, y, z, 0.14, 0.35, 0.6, 0)
end

function Fx.dust(x, y, z)
	local ox = rnd(-0.2, 0.2)
	Fx.spawn("fx2", x + ox, y - 0.1, z + 0.2, 0.5, 0.45, 0.9, 0.6)
end

function Fx.pow(x, y, z)
	Fx.spawn("fx7", x, y - 0.1, z, 0.16, 0.45, 0.65, 0)
end

function Fx.star(x, y, z)
	Fx.spawn("fx17", x, y, z, 0.9, 0.5, 0.25, 0.9)
end

function Fx.reticle(x, y, z)
	Fx.spawn("fx13", x, y, z + 0.15, 0.7, 1.1, 0.5, 0)
end

function Fx.blast(x, y, z)
	Fx.spawn("fx29", x, y - 0.2, z + 0.4, 0.3, 1.6, 3.4, 0.5)
	local i = 0
	local ox = 0.0
	local oy = 0.0
	for i = 1, 5 do
		ox = rnd(-1.2, 1.2)
		oy = rnd(-0.6, 0.6)
		Fx.spawn("fx2", x + ox, y + oy, z + 0.3, 0.8, 0.8, 1.6, 1.4)
	end
	Fx.spawn("fx0", x, y - 0.3, z + 0.6, 0.12, 2.2, 1.0, 0)
end
