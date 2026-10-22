-- idle: start and do nothing; every death is a bug or an ambient fight worth knowing about.
TT = { t = 0, step = 0 }
ORIG_DEATH = Game.on_death
function Game.on_death(u, why)
	print("T", "death", flr(G.time * 10) / 10, "team", u.team, "brain", u.brain, "order", u.order, why, flr(u.x * 10) / 10, flr(u.y * 10) / 10, flr(u.z * 10) / 10, "on", u.on ~= nil, "by", u.hit_by ~= nil)
	ORIG_DEATH(u, why)
end
function TEST_HOOK(dt)
	TT.t = TT.t + dt
	if TT.step == 0 and TT.t > 0.5 then
		TT.step = 1
		Game.start()
	end
end
