-- Single background path for the attract loop (ScreenLogo, ScreenMemoryCard, ScreenRainbow).
-- All three screens redirect their background here so the engine's SharedBGA sees the same
-- path and reuses one actor across transitions (no recreate, no pause).

local t = Def.ActorFrame{}

if ThemePrefs.Get("RainbowMode") then
	t[#t+1] = Def.Quad{
		InitCommand=function(self) self:FullScreen():Center():diffuse(Color.White) end
	}
end

t[#t+1] = LoadActor(THEME:GetPathB("", "_shared background"))

return t
