if GAMESTATE:GetCurrentStageIndex() == 0 then
	local memoryCardInUse = false
	local lastPlayed = false
	for i,pn in ipairs(GAMESTATE:GetHumanPlayers()) do
		if MEMCARDMAN:GetCardState(pn) == "MemoryCardState_ready" then
			memoryCardInUse = true
			local prof = PROFILEMAN:GetProfile(pn)
			song = prof:GetLastPlayedSong()
			if song ~= nil then
				lastPlayed = true
			end
		end
	end

	if not memoryCardInUse or not lastPlayed then
		local t = {
			"In The Groove 2/Birdie",
			"In The Groove 2/Bumble Bee",
			"In The Groove 3/Dance Vibrations",
			"In The Groove 3/Coming Out",
		};
		local s = SONGMAN:FindSong( t[ math.random(1,table.getn(t)) ] )
		GAMESTATE:SetPreferredSong( s )
	end
end

local af = Def.ActorFrame{
	-- GameplayReloadCheck is a kludgy global variable used in ScreenGameplay in.lua to check
	-- if ScreenGameplay is being entered "properly" or being reloaded by a scripted mod-chart.
	-- If we're here in SelectMusic, set GameplayReloadCheck to false, signifying that the next
	-- time ScreenGameplay loads, it should have a properly animated entrance.
	InitCommand=function(self)
		SL.Global.GameplayReloadCheck = false

		-- While other SM versions don't need this, Outfox resets the
		-- the music rate to 1 between songs, but we want to be using
		-- the preselected music rate.
		local songOptions = GAMESTATE:GetSongOptionsObject("ModsLevel_Preferred")
		songOptions:MusicRate(SL.Global.ActiveModifiers.MusicRate)
	end,

	-- ---------------------------------------------------
	--  first, load files that contain no visual elements, just code that needs to run

	-- MenuTimer code for preserving SSM's timer value when going
	-- from SSM to Player Options and then back to SSM
	LoadActor("./PreserveMenuTimer.lua"),
	-- Apply player modifiers from profile
	LoadActor("./PlayerModifiers.lua"),

	-- ---------------------------------------------------
	-- next, load visual elements; the order of these matters
	-- i.e. content in PerPlayer/Over needs to draw on top of content from PerPlayer/Under

	-- make the MusicWheel appear to cascade down; this should draw underneath P2's PaneDisplay
	LoadActor("./MusicWheelAnimation.lua"),

	-- number of steps, jumps, holds, etc., and high scores associated with the current stepchart
	LoadActor("./PaneDisplay.lua"),

	--reorder StepsDisplayList here so that the tail for the stepartistbubble isn't covered in CourseMode
	-- The grid for the difficulty picker (normal) or CourseContentsList (CourseMode)
	LoadActor("./StepsDisplayList/default.lua"),

	-- elements we need two of (one for each player) that draw underneath the StepsDisplayList
	-- this includes the stepartist boxes, the density graph, and the cursors.
	LoadActor("./PerPlayer/default.lua"),

	-- Song's Musical Artist, BPM, Duration
	LoadActor("./SongDescription/SongDescription.lua"),
	-- Banner Art
	LoadActor("./Banner.lua"),

	-- ---------------------------------------------------
	-- finally, load the overlay used for sorting the MusicWheel (and more), hidden by default
	LoadActor("./SortMenu/default.lua"),
	-- a Test Input overlay can (maybe) be accessed from the SortMenu
	LoadActor("./TestInput.lua"),

	-- The GrooveStats leaderboard that can (maybe) be accessed from the SortMenu
	-- This is only added in "dance" mode and if the service is available.
	LoadActor("./Leaderboard.lua"),

	-- a yes/no prompt overlay for backing out of SelectMusic when in EventMode can be
	-- activated via "CodeEscapeFromEventMode" under [ScreenSelectMusic] in Metrics.ini
	LoadActor("./EscapeFromEventMode.lua"),

	LoadActor("./SongSearch/default.lua"),
}

return af
