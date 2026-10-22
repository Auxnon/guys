-- sfx — little synthesized sounds. On an engine built without audio the
-- sound natives are no-ops, so this is safe to call anywhere.
--
-- Channels: 1 gunfire, 2 fists and thuds, 3 voice (whistles, orders),
-- 4 cannon, 5 jingles. Gunfire is rate-limited so a firefight crackles
-- instead of droning.

Sfx = { last_shot = 0.0, last_punch = 0.0 }

function Sfx.init()
	attr({ lanes = { 4, 6, 4, 4, 3, 4 } })
	instr(1, "noise", { atk = 0, dec = 0.09, sus = 0, rel = 0.04 })
	instr(2, "square", { atk = 0, dec = 0.06, sus = 0, rel = 0.02 })
	instr(3, "sine", { atk = 0.01, dec = 0.05, sus = 0.6, rel = 0.05 })
	instr(4, "noise", { atk = 0, dec = 0.5, sus = 0, rel = 0.2 })
	instr(5, "pulse", { wid = 0.25, atk = 0.005, dec = 0.08, sus = 0.4, rel = 0.08 })
	instr(6, "saw", { atk = 0.01, dec = 0.1, sus = 0.5, rel = 0.05 })
end

function Sfx.shot(team)
	local t = G.time
	if t - Sfx.last_shot < 0.05 then
		return
	end
	Sfx.last_shot = t
	local f = 900
	if team == 2 then
		f = 700
	end
	note(f, 0.07, 1, 1)
	note(120, 0.05, 2, 2)
end

function Sfx.punch()
	local t = G.time
	if t - Sfx.last_punch < 0.06 then
		return
	end
	Sfx.last_punch = t
	local f = rnd(80, 120)
	note(f, 0.05, 2, 2)
end

function Sfx.whistle()
	note(1500, 0.09, 3, 3)
	note(1900, 0.14, 3, 3)
end

function Sfx.order()
	note(330, 0.07, 3, 6)
	note(440, 0.09, 3, 6)
end

function Sfx.boom(big)
	if big then
		note(60, 0.5, 4, 4)
		note(45, 0.3, 2, 2)
	else
		note(110, 0.25, 4, 4)
	end
end

function Sfx.pickup()
	note(660, 0.06, 5, 5)
	note(990, 0.08, 5, 5)
end

function Sfx.level()
	note(523, 0.08, 5, 5)
	note(659, 0.08, 5, 5)
	note(784, 0.14, 5, 5)
end

function Sfx.clunk()
	note(140, 0.08, 2, 2)
end

function Sfx.bump()
	note(70, 0.15, 4, 4)
end
