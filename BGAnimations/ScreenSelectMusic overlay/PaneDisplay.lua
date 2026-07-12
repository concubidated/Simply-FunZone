-- get the machine_profile now at file init; no need to keep fetching with each SetCommand
local machine_profile = PROFILEMAN:GetMachineProfile()

-- the height of the footer is defined in ./Graphics/_footer.lua, but we'll
-- use it here when calculating where to position the PaneDisplay
local footer_height = 32

-- height of the PaneDisplay in pixels
local pane_height = 60

local text_zoom = WideScale(0.8, 0.9)
local request_stable_delay = 0.12
local duplicate_request_seconds = 5

-- -----------------------------------------------------------------------
-- Convenience function to return the SongOrCourse and StepsOrTrail for a
-- for a player.
local GetSongAndSteps = function(player)
	local SongOrCourse = (GAMESTATE:IsCourseMode() and GAMESTATE:GetCurrentCourse()) or GAMESTATE:GetCurrentSong()
	local StepsOrTrail = (GAMESTATE:IsCourseMode() and GAMESTATE:GetCurrentTrail(player)) or GAMESTATE:GetCurrentSteps(player)
	return SongOrCourse, StepsOrTrail
end

-- -----------------------------------------------------------------------
local GetScoreFromProfile = function(profile, SongOrCourse, StepsOrTrail)
	-- if we don't have everything we need, return nil
	if not (profile and SongOrCourse and StepsOrTrail) then return nil end

	local high_score_list = profile:GetHighScoreListIfExists(SongOrCourse, StepsOrTrail)
	if not high_score_list then return nil end
	local high_scores = high_score_list:GetHighScores()
	return high_scores[1]
end

local GetScoreForPlayer = function(player)
	local highScore
	if PROFILEMAN:IsPersistentProfile(player) then
		local SongOrCourse, StepsOrTrail = GetSongAndSteps(player)
		highScore = GetScoreFromProfile(PROFILEMAN:GetProfile(player), SongOrCourse, StepsOrTrail)
	end
	return highScore
end

-- -----------------------------------------------------------------------
local GetPaneChild = function(master, player_index, child_name)
	local paneDisplay = master and master:GetChild("PaneDisplayP"..player_index)
	return paneDisplay and paneDisplay:GetChild(child_name) or nil
end

local SetTextActor = function(actor, text, textColor)
	if not (actor and actor.settext) then return end
	actor:settext(text)
	if textColor then actor:diffuse(color(textColor)) end
end

local QueueActorCommand = function(actor, command)
	if actor then actor:queuecommand(command) end
end

local FormatGrooveStatsScore = function(score)
	local score_value = tonumber(score)
	if not score_value then return nil, nil end
	local percent = score_value / 100
	return string.format("%.2f%%", percent), percent
end

local SetNameAndScore = function(name, score, nameActor, scoreActor, textColor)
	if not scoreActor or not nameActor then return end
	SetTextActor(scoreActor, score, textColor)
	SetTextActor(nameActor, name, textColor)
end

local GetMachineTag = function(gsEntry)
	if not gsEntry then return end
	if type(gsEntry["machineTag"]) == "string" then
		-- Make sure we only use up to 4 characters for space concerns.
		return gsEntry["machineTag"]:sub(1, 4):upper()
	end

	-- User doesn't have a machineTag set. We'll "make" one based off of
	-- their name.
	if type(gsEntry["name"]) == "string" then
		-- 4 Characters is the "intended" length.
		return gsEntry["name"]:sub(1,4):upper()
	end

	return ""
end

local GetScoresRequestProcessor = function(res, params)
	params = params or {}
	res = res or {}
	local master = params.master
	if master == nil then return end
	-- If we're not hovering over a song when we get the request, then we don't
	-- have to update anything. We don't have to worry about courses here since
	-- we don't run the RequestResponseActor in CourseMode.
	if GAMESTATE:GetCurrentSong() == nil then return end
	
	local data = res.statusCode == 200 and SL.SafeJsonDecode(res.body) or nil
	local requestCacheKey = params.requestCacheKey
	-- If we have data, and the requestCacheKey is not in the cache, cache it.
	if type(data) == "table" and requestCacheKey and SL.GrooveStats.RequestCache[requestCacheKey] == nil then
		SL.GrooveStats.RequestCache[requestCacheKey] = {
			Response=res,
			Timestamp=GetTimeSinceStart()
		}
	end

	for i=1,2 do
		local machineScore = GetPaneChild(master, i, "MachineHighScore")
		local machineName = GetPaneChild(master, i, "MachineHighScoreName")

		local playerScore = GetPaneChild(master, i, "PlayerHighScore")
		local playerName = GetPaneChild(master, i, "PlayerHighScoreName")

		local loadingText = GetPaneChild(master, i, "Loading")

		local playerStr = "player"..i
		local playerData = type(data) == "table" and type(data[playerStr]) == "table" and data[playerStr] or nil
		local rivalNum = 1
		local worldRecordSet = false
		local personalRecordSet = false
		local foundLeaderboard = false

		-- First check to see if the leaderboard even exists.
		if playerData then
			local showExScore = SL["P"..i].ActiveModifiers.ShowEXScore and type(playerData["exLeaderboard"]) == "table"
			local leaderboardData = nil
			if showExScore then
				leaderboardData = playerData["exLeaderboard"]
			elseif type(playerData["gsLeaderboard"]) == "table" then
				leaderboardData = playerData["gsLeaderboard"]
			end

			if leaderboardData then
				foundLeaderboard = true
			end

			-- And then also ensure that the chart hash matches the currently parsed one.
			-- It's better to just not display anything than display the wrong scores.
			if SL["P"..i].Streams.Hash == playerData["chartHash"] and leaderboardData then
				for gsEntry in ivalues(leaderboardData) do
					if type(gsEntry) == "table" then
						local scoreText, gsScore = FormatGrooveStatsScore(gsEntry["score"])
						if scoreText and gsEntry["rank"] == 1 then
							SetNameAndScore(
								GetMachineTag(gsEntry),
								scoreText,
								machineName,
								machineScore,
								"#000000"
							)
							worldRecordSet = true
						end

						if scoreText and gsEntry["isSelf"] then
							-- Always display personal EX score from the site if it's available.
							-- TODO(teejusb): Grab white count from stats and calculate it to compare local score.
							if showExScore then
								SetNameAndScore(
									GetMachineTag(gsEntry),
									scoreText,
									playerName,
									playerScore,
									"#000000"
								)
								personalRecordSet = true
							else
								-- Let's check if the GS high score is higher than the local high score
								local player = PlayerNumber[i]
								local localScore = GetScoreForPlayer(player)

								-- GetPercentDP() returns a value like 0.9823, so we need to multiply it by 100 to get 98.23
								if not localScore or gsScore >= localScore:GetPercentDP() * 100 then
									-- It is! Let's use it instead of the local one.
									SetNameAndScore(
										GetMachineTag(gsEntry),
										scoreText,
										playerName,
										playerScore,
										"#000000"
									)
									personalRecordSet = true
								end
							end
						end

						if scoreText and gsEntry["isRival"] then
							if rivalNum <= 3 then
								SetNameAndScore(
									GetMachineTag(gsEntry),
									scoreText,
									GetPaneChild(master, i, "Rival"..rivalNum.."Name"),
									GetPaneChild(master, i, "Rival"..rivalNum.."Score"),
									"#000000"
								)
							end
							rivalNum = rivalNum + 1
						end
					end
				end
			end
		elseif playerData and type(playerData["itl"]) == "table" and type(playerData["itl"]["itlLeaderboard"]) == "table" then
			
			-- And then also ensure that the chart hash matches the currently parsed one.
			-- It's better to just not display anything than display the wrong scores.
			if SL["P"..i].Streams.Hash == playerData["chartHash"] then
				for gsEntry in ivalues(playerData["itl"]["itlLeaderboard"]) do
					if type(gsEntry) == "table" then
						local scoreText = FormatGrooveStatsScore(gsEntry["score"])
						if scoreText and gsEntry["rank"] == 1 then
							SetNameAndScore(
								GetMachineTag(gsEntry),
								scoreText,
								machineName,
								machineScore,
								"#21CCE8"
							)
							worldRecordSet = true
						end

						if scoreText and gsEntry["isRival"] then
							if rivalNum <= 3 then
								SetNameAndScore(
									GetMachineTag(gsEntry),
									scoreText,
									GetPaneChild(master, i, "Rival"..rivalNum.."Name"),
									GetPaneChild(master, i, "Rival"..rivalNum.."Score"),
									"#21CCE8"
								)
							end
							rivalNum = rivalNum + 1
						end
					end
				end
			end
		end

		-- Fall back to to using the machine profile's record if we never set the world record.
		-- This chart may not have been ranked, or there is no WR, or the request failed.
		if not worldRecordSet then
			QueueActorCommand(machineName, "SetDefault")
			QueueActorCommand(machineScore, "SetDefault")
		end

		-- Fall back to to using the personal profile's record if we never set the record.
		-- This chart may not have been ranked, or we don't have a score for it, or the request failed.
		if not personalRecordSet then
			QueueActorCommand(playerName, "SetDefault")
			QueueActorCommand(playerScore, "SetDefault")
		end

		-- Iterate over any remaining rivals and hide them.
		-- This also handles the failure case as rivalNum will never have been incremented.
		for j=rivalNum,3 do
			SetTextActor(GetPaneChild(master, i, "Rival"..j.."Score"), "??.??%")
			SetTextActor(GetPaneChild(master, i, "Rival"..j.."Name"), "----")
		end

		if res.error or res.statusCode ~= 200 then
			local error = res.error and ToEnumShortString(res.error) or nil
			if error == "Timeout" then
				SetTextActor(loadingText, "Timed Out")
			elseif error or res.statusCode ~= 200 then
				SetTextActor(loadingText, "Failed")
			end
		else
			if playerData then
				local headers = res.headers or {}
				local boogie = false
				local boogie_ex = false
				if headers["bs-leaderboard-player-" .. i] == "BS" then
					boogie = true
				elseif headers["bs-leaderboard-player-" .. i] == "BS-EX" then
					boogie_ex = true
				end
				
				if foundLeaderboard then
					if boogie then
						SetTextActor(loadingText, "BoogieStats")
					elseif boogie_ex then
						SetTextActor(loadingText, "Boogie EX")
					elseif SL["P"..i].ActiveModifiers.ShowEXScore then
						SetTextActor(loadingText, "EX Score")
					else
						SetTextActor(loadingText, "GrooveStats")
					end
				else
					if boogie then
						SetTextActor(loadingText, "No Boogie Data")
					elseif boogie_ex then
						SetTextActor(loadingText, "No Boogie EX")
					elseif SL["P"..i].ActiveModifiers.ShowEXScore then
						SetTextActor(loadingText, "No EX Data")
					else
						SetTextActor(loadingText, "No Data")
					end
				end
			else
				-- Just hide the text
				QueueActorCommand(loadingText, "Set")
			end
		end
	end
end

-- -----------------------------------------------------------------------
-- define the x positions of four columns, and the y positions of three rows of PaneItems
local pos = {
	col = { WideScale(-104,-133), WideScale(-36,-38), WideScale(54,76), WideScale(150, 190) },
	row = { 13, 31, 49 }
}

local num_rows = 3
local num_cols = 2

-- HighScores handled as special cases for now until further refactoring
local PaneItems = {
	-- first row
	{ name=THEME:GetString("RadarCategory","Taps"),  rc='RadarCategory_TapsAndHolds'},
	{ name=THEME:GetString("RadarCategory","Mines"), rc='RadarCategory_Mines'},
	-- { name=THEME:GetString("ScreenSelectMusic","NPS") },

	-- second row
	{ name=THEME:GetString("RadarCategory","Jumps"), rc='RadarCategory_Jumps'},
	{ name=THEME:GetString("RadarCategory","Hands"), rc='RadarCategory_Hands'},
	-- { name=THEME:GetString("RadarCategory","Lifts"), rc='RadarCategory_Lifts'},

	-- third row
	{ name=THEME:GetString("RadarCategory","Holds"), rc='RadarCategory_Holds'},
	{ name=THEME:GetString("RadarCategory","Rolls"), rc='RadarCategory_Rolls'},
	-- { name=THEME:GetString("RadarCategory","Fakes"), rc='RadarCategory_Fakes'},
}

-- -----------------------------------------------------------------------
local af = Def.ActorFrame{ Name="PaneDisplayMaster" }

af[#af+1] = RequestResponseActor(17, 50)..{
	Name="GetScoresRequester",
	OnCommand=function(self)
		-- Create variables for both players, even if they're not currently active.
		self.IsParsing = {false, false}
		self.LastRequestCacheKey = ""
		self.LastRequestTime = 0
	end,
	-- Broadcasted from ./PerPlayer/DensityGraph.lua
	P1ChartParsingMessageCommand=function(self)	self.IsParsing[1] = true end,
	P2ChartParsingMessageCommand=function(self)	self.IsParsing[2] = true end,
	P1ChartParsedMessageCommand=function(self)
		self.IsParsing[1] = false
		self:stoptweening()
		self:sleep(request_stable_delay)
		self:queuecommand("ChartParsed")
	end,
	P2ChartParsedMessageCommand=function(self)
		self.IsParsing[2] = false
		self:stoptweening()
		self:sleep(request_stable_delay)
		self:queuecommand("ChartParsed")
	end,
	ChartParsedCommand=function(self)
		local master = self:GetParent()
		if not master then return end

		if not IsServiceAllowed(SL.GrooveStats.GetScores) then
			if SL.GrooveStats.IsConnected then
				-- loadingText is made visible when requests complete.
				-- If we disable the service from a previous request, surface it to the user here.
				for i=1,2 do
					local loadingText = GetPaneChild(master, i, "Loading")
					SetTextActor(loadingText, "Disabled")
					if loadingText then loadingText:visible(true) end
				end
			end
			return
		end

		-- Make sure we're still not parsing either chart.
		if self.IsParsing[1] or self.IsParsing[2] then return end

		-- This makes sure that the Hash in the ChartInfo cache exists.
		local sendRequest = false
		local headers = {}
		local query = {
			maxLeaderboardResults=NumEntries,
		}
		local requestCacheKey = ""

		if ThemePrefs.Get("MusicWheelGS") == "Pane" then
			for i=1,2 do
				local pn = "P"..i
				if IsItlSong(PlayerNumber[i]) then
					UpdatePathMap(PlayerNumber[i], SL[pn].Streams.Hash)
				end
				if SL[pn].ApiKey ~= "" and SL[pn].Streams.Hash ~= "" then
					query["chartHashP"..i] = SL[pn].Streams.Hash
					headers["x-api-key-player-"..i] = SL[pn].ApiKey
					requestCacheKey = requestCacheKey .. SL[pn].Streams.Hash .. SL[pn].ApiKey .. pn
					local loadingText = GetPaneChild(master, i, "Loading")
					if loadingText and loadingText.settext then
						loadingText:visible(true)
						loadingText:settext("Loading ..."):diffuse(Color.Black)
					end
					sendRequest = true
				end
			end
		end

		-- Only send the request if it's applicable.
		if sendRequest then
			requestCacheKey = CRYPTMAN:SHA256String(requestCacheKey.."-player-scores")
			local now = GetTimeSinceStart()
			if requestCacheKey == self.LastRequestCacheKey and now - self.LastRequestTime < duplicate_request_seconds then
				return
			end
			self.LastRequestCacheKey = requestCacheKey
			self.LastRequestTime = now
			local params = {requestCacheKey=requestCacheKey, master=master}
			RemoveStaleCachedRequests()
			-- If the data is still in the cache, run the request processor directly
			-- without making a request with the cached response.
			if SL.GrooveStats.RequestCache[requestCacheKey] ~= nil then
				SL.SelectMusicTelemetry:Pulse("normal.pane.gs.cache")
				local res = SL.GrooveStats.RequestCache[requestCacheKey].Response
				GetScoresRequestProcessor(res, params)
			else
				SL.SelectMusicTelemetry:Pulse("normal.pane.gs.request")
				self:playcommand("MakeGrooveStatsRequest", {
					endpoint="player-scores.php?"..NETWORK:EncodeQueryParameters(query),
					method="GET",
					headers=headers,
					timeout=10,
					callback=GetScoresRequestProcessor,
					args=params,
				})
			end
		end
	end
}

for player in ivalues(PlayerNumber) do
	local pn = ToEnumShortString(player)

	af[#af+1] = Def.ActorFrame{ Name="PaneDisplay"..ToEnumShortString(player) }

	local af2 = af[#af]

	af2.InitCommand=function(self)
		self:visible(GAMESTATE:IsHumanPlayer(player))

		if player == PLAYER_1 then
			self:x(_screen.w * 0.25 - 5)
		elseif player == PLAYER_2 then
			self:x(_screen.w * 0.75 + 5)
		end

		self:y(_screen.h - footer_height - pane_height)
	end

	af2.PlayerJoinedMessageCommand=function(self, params)
		if player==params.Player then
			-- ensure BackgroundQuad is colored before it is made visible
			self:GetChild("BackgroundQuad"):playcommand("Set")
			self:visible(true)
				:zoom(0):croptop(0):bounceend(0.3):zoom(1)
				:playcommand("Update")
		end
	end

	af2.PlayerUnjoinedMessageCommand=function(self, params)
		if player==params.Player then
			self:accelerate(0.3):croptop(1):sleep(0.01):zoom(0):queuecommand("Hide")
		end
	end

	af2.PlayerProfileSetMessageCommand=function(self, params)
		if player == params.Player then
			self:playcommand("Set")
		end
	end

	af2.HideCommand=function(self) self:visible(false) end

	af2.OnCommand=function(self)                                    SL.SelectMusicTelemetry:Pulse("normal.pane."..pn..".on"); self:playcommand("Set") end
	af2.SLGameModeChangedMessageCommand=function(self)              SL.SelectMusicTelemetry:Pulse("normal.pane."..pn..".mode"); self:playcommand("Set") end
	af2.CurrentCourseChangedMessageCommand=function(self)			SL.SelectMusicTelemetry:Pulse("normal.pane."..pn..".course"); self:playcommand("Set") end
	af2.CurrentSongChangedMessageCommand=function(self)				SL.SelectMusicTelemetry:Pulse("normal.pane."..pn..".song"); self:playcommand("Set") end
	af2["CurrentSteps"..pn.."ChangedMessageCommand"]=function(self) SL.SelectMusicTelemetry:Pulse("normal.pane."..pn..".steps"); self:playcommand("Set") end
	af2["CurrentTrail"..pn.."ChangedMessageCommand"]=function(self) SL.SelectMusicTelemetry:Pulse("normal.pane."..pn..".trail"); self:playcommand("Set") end

	-- -----------------------------------------------------------------------
	-- colored background Quad

	af2[#af2+1] = Def.Quad{
		Name="BackgroundQuad",
		InitCommand=function(self)
			self:zoomtowidth(_screen.w/2-10)
			self:zoomtoheight(pane_height)
			self:vertalign(top)
		end,
		SetCommand=function(self)
			local SongOrCourse, StepsOrTrail = GetSongAndSteps(player)
			if GAMESTATE:IsHumanPlayer(player) then
				if StepsOrTrail then
					local difficulty = StepsOrTrail:GetDifficulty()
					self:diffuse( DifficultyColor(difficulty) )
				else
					self:diffuse( PlayerColor(player) )
				end
			end
		end
	}

	-- -----------------------------------------------------------------------
	-- loop through the six sub-tables in the PaneItems table
	-- add one BitmapText as the label and one BitmapText as the value for each PaneItem

	for i, item in ipairs(PaneItems) do

		local col = ((i-1)%num_cols) + 1
		local row = math.floor((i-1)/num_cols) + 1

		af2[#af2+1] = Def.ActorFrame{

			Name=item.name,

			-- numerical value
			LoadFont(ThemePrefs.Get("ThemeFont") .. " Normal")..{
				InitCommand=function(self)
					self:zoom(text_zoom):diffuse(Color.Black):horizalign(right)
					self:x(pos.col[col])
					self:y(pos.row[row])
				end,

				SetCommand=function(self)
					local SongOrCourse, StepsOrTrail = GetSongAndSteps(player)
					if not SongOrCourse then self:settext("?"); return end
					if not StepsOrTrail then self:settext("");  return end

					if item.rc then
						local val = StepsOrTrail:GetRadarValues(player):GetValue( item.rc )
						-- the engine will return -1 as the value for autogenerated content; show a question mark instead if so
						self:settext( val >= 0 and val or "?" )
					end
				end
			},

			-- label
			LoadFont(ThemePrefs.Get("ThemeFont") .. " Normal")..{
				Text=item.name,
				InitCommand=function(self)
					self:zoom(text_zoom):diffuse(Color.Black):horizalign(left)
					self:x(pos.col[col]+3)
					self:y(pos.row[row])
				end
			},
		}
	end

	-- Machine/World Record Machine Tag
	af2[#af2+1] = LoadFont(ThemePrefs.Get("ThemeFont") .. " Normal")..{
		Name="MachineHighScoreName",
		InitCommand=function(self)
			self:zoom(text_zoom):diffuse(Color.Black):maxwidth(30)
			self:x(pos.col[3]-50*text_zoom)
			self:y(pos.row[1])
		end,
		SetCommand=function(self)
			-- We overload this actor to work both for GrooveStats and also offline.
			-- If we're connected, we let the ResponseProcessor set the text
			if IsServiceAllowed(SL.GrooveStats.GetScores) and ThemePrefs.Get("MusicWheelGS") == "Pane" then
				self:settext("----"):diffuse(Color.Black)
			else
				self:queuecommand("SetDefault")
			end
		end,
		SetDefaultCommand=function(self)
			local SongOrCourse, StepsOrTrail = GetSongAndSteps(player)
			local machineScore = GetScoreFromProfile(machine_profile, SongOrCourse, StepsOrTrail)
			self:settext(machineScore and machineScore:GetName() or "----"):diffuse(Color.Black)
			DiffuseEmojis(self:ClearAttributes())
		end
	}

	-- Machine/World Record HighScore
	af2[#af2+1] = LoadFont(ThemePrefs.Get("ThemeFont") .. " Normal")..{
		Name="MachineHighScore",
		InitCommand=function(self)
			self:zoom(text_zoom):diffuse(Color.Black):horizalign(right)
			self:x(pos.col[3]+25*text_zoom)
			self:y(pos.row[1])
		end,
		SetCommand=function(self)
			-- We overload this actor to work both for GrooveStats and also offline.
			-- If we're connected, we let the ResponseProcessor set the text
			if IsServiceAllowed(SL.GrooveStats.GetScores) and ThemePrefs.Get("MusicWheelGS") == "Pane" then
				self:settext("??.??%"):diffuse(Color.Black)
			else
				self:queuecommand("SetDefault")
			end
		end,
		SetDefaultCommand=function(self)
			local SongOrCourse, StepsOrTrail = GetSongAndSteps(player)
			local machineScore = GetScoreFromProfile(machine_profile, SongOrCourse, StepsOrTrail)
			if machineScore ~= nil then
				self:settext(FormatPercentScore(machineScore:GetPercentDP())):diffuse(Color.Black)
			else
				self:settext("??.??%"):diffuse(Color.Black)
			end
		end
	}

	-- Player Profile/GrooveStats Machine Tag
	af2[#af2+1] = LoadFont(ThemePrefs.Get("ThemeFont") .. " Normal")..{
		Name="PlayerHighScoreName",
		InitCommand=function(self)
			self:zoom(text_zoom):diffuse(Color.Black):maxwidth(30)
			self:x(pos.col[3]-50*text_zoom)
			self:y(pos.row[2])
		end,
		SetCommand=function(self)
			-- We overload this actor to work both for GrooveStats and also offline.
			-- If we're connected, we let the ResponseProcessor set the text
			if IsServiceAllowed(SL.GrooveStats.GetScores) and ThemePrefs.Get("MusicWheelGS") == "Pane" then
				self:settext("----")
			else
				self:queuecommand("SetDefault")
			end
		end,
		SetDefaultCommand=function(self)
			local playerScore = GetScoreForPlayer(player)
			self:settext(playerScore and playerScore:GetName() or "----"):diffuse(Color.Black)
			DiffuseEmojis(self:ClearAttributes())
		end
	}

	-- Player Profile/GrooveStats HighScore
	af2[#af2+1] = LoadFont(ThemePrefs.Get("ThemeFont") .. " Normal")..{
		Name="PlayerHighScore",
		InitCommand=function(self)
			self:zoom(text_zoom):diffuse(Color.Black):horizalign(right)
			self:x(pos.col[3]+25*text_zoom)
			self:y(pos.row[2])
		end,
		SetCommand=function(self)
			-- We overload this actor to work both for GrooveStats and also offline.
			-- If we're connected, we let the ResponseProcessor set the text
			if IsServiceAllowed(SL.GrooveStats.GetScores) and ThemePrefs.Get("MusicWheelGS") == "Pane" then
				self:settext("??.??%")
			else
				self:queuecommand("SetDefault")
			end
		end,
		SetDefaultCommand=function(self)
			local playerScore = GetScoreForPlayer(player)
			if playerScore ~= nil then
				self:settext(FormatPercentScore(playerScore:GetPercentDP())):diffuse(Color.Black)
			else
				self:settext("??.??%"):diffuse(Color.Black)
			end
		end
	}

	af2[#af2+1] = LoadFont(ThemePrefs.Get("ThemeFont") .. " Normal")..{
		Name="Loading",
		Text="Loading ... ",
		InitCommand=function(self)
			self:zoom(text_zoom):diffuse(Color.Black)
			self:x(pos.col[3]-15)
			self:y(pos.row[3])
			self:visible(false)
		end,
		SetCommand=function(self)
			self:settext("Loading ...")
			self:visible(false)
		end
	}

	-- Chart Difficulty Meter
	af2[#af2+1] = LoadFont("Wendy/_wendy small")..{
		Name="DifficultyMeter",
		InitCommand=function(self)
			self:horizalign(right):diffuse(Color.Black)
			self:xy(pos.col[4], pos.row[2])
			if not IsUsingWideScreen() then self:maxwidth(66) else self:maxwidth(45) end
			self:queuecommand("Set")
		end,
		SetCommand=function(self)
			-- Hide the difficulty number if we're connected.
			if IsServiceAllowed(SL.GrooveStats.GetScores) then
				self:visible(false)
			end

			local SongOrCourse, StepsOrTrail = GetSongAndSteps(player)
			if not SongOrCourse then self:settext("") return end
			local meter = StepsOrTrail and StepsOrTrail:GetMeter() or "?"

			self:settext( meter )
		end
	}

	-- Add actors for Rival score data. Hidden by default
	-- We position relative to column 3 for spacing reasons.
	if ThemePrefs.Get("MusicWheelGS") == "Pane" then
		for i=1,3 do
			-- Rival Machine Tag
			af2[#af2+1] = LoadFont(ThemePrefs.Get("ThemeFont") .. " Normal")..{
				Name="Rival"..i.."Name",
				InitCommand=function(self)
					self:zoom(text_zoom):diffuse(Color.Black):maxwidth(30)
					self:x(pos.col[3]+50*text_zoom)
					self:y(pos.row[i])
				end,
				OnCommand=function(self)
					self:visible(IsServiceAllowed(SL.GrooveStats.GetScores))
				end,
				SetCommand=function(self)
					self:settext("----"):diffuse(Color.Black)
				end
			}
	
			-- Rival HighScore
			af2[#af2+1] = LoadFont(ThemePrefs.Get("ThemeFont") .. " Normal")..{
				Name="Rival"..i.."Score",
				InitCommand=function(self)
					self:zoom(text_zoom):diffuse(Color.Black):horizalign(right)
					self:x(pos.col[3]+125*text_zoom)
					self:y(pos.row[i])
				end,
				OnCommand=function(self)
					self:visible(IsServiceAllowed(SL.GrooveStats.GetScores))
				end,
				SetCommand=function(self)
					self:settext("??.??%"):diffuse(Color.Black)
				end
			}
		end
	end
end

return af
