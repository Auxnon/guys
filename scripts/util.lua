-- util — small maths helpers shared by everything.
--
-- silt style throughout (see petrichor64 AGENTS.md / SILT-BUGS.md): calls are
-- hoisted out of argument lists, table constructors that mention locals are
-- built into a local first, nothing is ever deleted from a table, and there
-- are no anonymous functions.

U = {}
PI = 3.14159265358979

function U.clamp(v, lo, hi)
	if v < lo then
		return lo
	end
	if v > hi then
		return hi
	end
	return v
end

function U.min(a, b)
	if a < b then
		return a
	end
	return b
end

function U.max(a, b)
	if a > b then
		return a
	end
	return b
end

function U.abs(v)
	if v < 0 then
		return -v
	end
	return v
end

function U.sign(v)
	if v < 0 then
		return -1
	end
	return 1
end

-- An angle in -pi..pi.
function U.wrap(a)
	while a > PI do
		a = a - tau
	end
	while a < -PI do
		a = a + tau
	end
	return a
end

-- The turn from a to b, the short way round.
function U.angle_diff(a, b)
	local d = b - a
	return U.wrap(d)
end

-- Fraction of the way to close on a target this frame, at `r` per second.
function U.ease(r, dt)
	local k = r * dt
	if k > 1 then
		k = 1
	end
	return k
end

function U.d2(ax, ay, bx, by)
	local dx = bx - ax
	local dy = by - ay
	return dx * dx + dy * dy
end

function U.dist(ax, ay, bx, by)
	local d = U.d2(ax, ay, bx, by)
	return sqrt(d)
end

function U.chance(p)
	local r = rnd()
	return r < p
end

-- Pick one string from a list, at random.
function U.pick(list)
	local n = #list
	local i = irnd(1, n)
	return list[i]
end
