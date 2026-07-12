local GIFdir = THEME:GetCurrentThemeDirectory() .. "BGAnimations/ScreenGameplay underlay/PerPlayer/StepStatistics/GIFs/"
local GIFs = findFiles(GIFdir, "lua")

if #GIFs == 0 then return NullActor end

t = Def.ActorFrame {
	LoadActor(GIFs[math.random(1,#GIFs)])
}

return t
