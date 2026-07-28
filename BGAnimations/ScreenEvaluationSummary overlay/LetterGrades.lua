-- hide the entire ActorFrame (and, thus, its children) in the InitCommand
local af = Def.ActorFrame{
	Name="LetterGradesAF",
	InitCommand=function(self) self:visible(false) end
}

local grades_needed = {}
local grade_order = {}

local function add_grade(grade)
	if type(grade) ~= "string" or grade == "" or grades_needed[grade] then return end
	grades_needed[grade] = true
	grade_order[#grade_order+1] = grade
end

local function add_grade_from_stats(stats)
	if not stats then return end

	if stats.judgments and stats.judgments.W0 and stats.exscore == 100 then
		add_grade("Grade_Tier00")
	else
		add_grade(stats.grade)
	end
end

local num_stages = SL.Global.Stages.PlayedThisGame
for player in ivalues(PlayerNumber) do
	local pn = ToEnumShortString(player)
	local player_stats = SL[pn] and SL[pn].Stages and SL[pn].Stages.Stats
	if player_stats then
		for i=1,num_stages do
			add_grade_from_stats(player_stats[i])
		end
	end
end

for i=1,#grade_order do
	local grade = grade_order[i]
	af[#af+1] = LoadActor(THEME:GetPathG("", "_grades/"..grade..".lua"))..{ Name=grade }
end

return af
