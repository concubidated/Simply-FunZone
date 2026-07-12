if not IsServiceAllowed(SL.GrooveStats.AutoSubmit) or GAMESTATE:IsCourseMode() then return end

local NumEntries = 10

local SetEntryText = function(rank, name, score, date, actor)
	if actor == nil then return end

	local rank_text = actor:GetChild("Rank")
	local name_text = actor:GetChild("Name")
	local score_text = actor:GetChild("Score")
	local date_text = actor:GetChild("Date")

	if rank_text then rank_text:settext(rank) end
	if name_text then name_text:settext(name) end
	if score_text then score_text:settext(score) end
	if date_text then date_text:settext(date) end
end

local GetChild = function(actor, name)
	return actor and actor:GetChild(name) or nil
end

local GetPaneBody = function(panes, pane_number, side_number)
	local pane = GetChild(panes, ("Pane%i_SideP%i"):format(pane_number, side_number))
	return GetChild(pane, "")
end

local GetHighScoreEntry = function(pane, entry_number)
	local high_score_list = GetChild(pane, "HighScoreList")
	return GetChild(high_score_list, "HighScoreEntry"..entry_number)
end

local DiffuseEntryScore = function(entry, diffuse)
	local score = GetChild(entry, "Score")
	if score then score:diffuse(diffuse) end
end

local MarkQRSubmitted = function(QRPane)
	local qr_code = GetChild(QRPane, "QRCode")
	local help_text = GetChild(QRPane, "HelpText")

	if qr_code then qr_code:queuecommand("Hide") end
	if help_text then help_text:settext("Score has already been submitted :)") end
end

local GetScreenEvalPanes = function()
	local top_screen = SCREENMAN:GetTopScreen()
	local overlay = GetChild(top_screen, "Overlay")
	local common = GetChild(overlay, "ScreenEval Common")
	return GetChild(common, "Panes")
end

local RestorePaneAndHideQR = function(side_number, pane_number)
	local panes = GetScreenEvalPanes()
	if not panes then return false end

	local pane = GetChild(panes, ("Pane%i_SideP%i"):format(pane_number, side_number))
	if pane then pane:visible(false):diffusealpha(0):sleep(0.2):visible(true):diffusealpha(1) end

	local QRPane = GetChild(panes, ("Pane7_SideP%i"):format(side_number))
	if QRPane then QRPane:visible(true):sleep(0.2):diffusealpha(0) end

	return pane ~= nil or QRPane ~= nil
end

local GetMachineTag = function(gsEntry)
	if not gsEntry then return end	
	-- Groovestats username.
	if gsEntry["name"] then
		-- 4 Characters is the "intended" length.
		return gsEntry["name"]
	end

	if gsEntry["machineTag"] then
		-- User doesn't have a username (?).
		return gsEntry["machineTag"]:sub(1, 4):upper()
	end

	return ""
end

local GetJudgmentCounts = function(player)
	local counts = GetExJudgmentCounts(player)
	local translation = {
		["W0"] = "fantasticPlus",
		["W1"] = "fantastic",
		["W2"] = "excellent",
		["W3"] = "great",
		["W4"] = "decent",
		["W5"] = "wayOff",
		["Miss"] = "miss",
		["totalSteps"] = "totalSteps",
		["Holds"] = "holdsHeld",
		["totalHolds"] = "totalHolds",
		["Mines"] = "minesHit",
		["totalMines"] = "totalMines",
		["Rolls"] = "rollsHeld",
		["totalRolls"] = "totalRolls"
	}

	local judgmentCounts = {}

	for key, value in pairs(counts) do
		if translation[key] ~= nil then
			judgmentCounts[translation[key]] = value
		end
	end

	return judgmentCounts
end

local GetRescoredJudgmentCounts = function(player)
	local pn = ToEnumShortString(player)

	local translation = {
		["W0"] = "fantasticPlus",
		["W1"] = "fantastic",
		["W2"] = "excellent",
		["W3"] = "great",
		["W4"] = "decent",
		["W5"] = "wayOff",
	}

	local rescored = {
		["fantasticPlus"] = 0,
		["fantastic"] = 0,
		["excellent"] = 0,
		["great"] = 0,
		["decent"] = 0,
		["wayOff"] = 0
	}

	local stage_stat = SL[pn].Stages.Stats[SL.Global.Stages.PlayedThisGame + 1]
	for i=1,GAMESTATE:GetCurrentStyle():ColumnsPerPlayer() do
		local col = stage_stat.column_judgments and stage_stat.column_judgments[i]
		local early = col and col["Early"]
		if early then
			for window, name in pairs(translation) do
				rescored[name] = rescored[name] + (early[window] or 0)
			end
		end
	end

	return rescored
end

local AttemptDownloads = function(res)
	local data = SL.SafeJsonDecode(res.body)
	if not data then return end

	for i=1,2 do
		local playerStr = "player"..i
		local events = {"rpg", "itl"}

		for event in ivalues(events) do
			if data and data[playerStr] and data[playerStr][event] then
				local eventData = data[playerStr][event]
				local eventName = eventData["name"] or "Unknown Event"
			
				-- See if any quests were completed.
				if eventData["progress"] and eventData["progress"]["questsCompleted"] then
					local quests = eventData["progress"]["questsCompleted"]
					-- Iterate through the quests...
					for quest in ivalues(quests) do
						-- ...and check for any unlocks.
						if quest["songDownloadUrl"] then
							local url = quest["songDownloadUrl"]
							local title = quest["title"] or ""

							if ThemePrefs.Get("SeparateUnlocksByPlayer") then
								local profileName = "NoName"
								local player = "PlayerNumber_P"..i
								if (PROFILEMAN:IsPersistentProfile(player) and
										PROFILEMAN:GetProfile(player)) then
									profileName = PROFILEMAN:GetProfile(player):GetDisplayName()
								end
								title = title.." - "..profileName
								DownloadEventUnlock(url, "["..eventName.."] "..title, eventName.." Unlocks - "..profileName)
							else
								DownloadEventUnlock(url, "["..eventName.."] "..title, eventName.." Unlocks")
							end
						end
					end
				end
			end
		end
	end
end

local ScreenshotQR = function(playernum)
	-- format a localized month string like "06-June" or "12-Diciembre"
	local month = ("%02d-%s"):format(MonthOfYear()+1, THEME:GetString("Months", "Month"..MonthOfYear()+1))

	-- get the FullTitle of the song or course that was just played
	local SongOrCourse = GAMESTATE:IsCourseMode() and GAMESTATE:GetCurrentCourse() or GAMESTATE:GetCurrentSong()
	local title = SongOrCourse and SongOrCourse:GetDisplayFullTitle() or ""

	-- song titles can be very long, and the engine's SaveScreenshot() function
	-- is already hardcoded to make the filename long via DateTime::GetNowDateTime()
	-- so, let's use only the first 25 characters of the title in the screenshot filename
	title = title:utf8sub(1,25)

	-- substitute all symbols with underscores to avoid file name conflicts
	title = title:gsub("%W", "_")

	-- organize screenshots Love into directories, like...
	--      ./Screenshots/Simply_Love/2020/04-April/DVNO-2020-04-22_175951.png
	-- note that the engine's SaveScreenshot() function will convert whitespace
	-- characters to underscores, so we might as well just use underscores here
	local prefix = "Simply_Love/QRCodes/" .. Year() .. "/" .. month .. "/"
	local suffix = "_" .. title

	-- attempt to write a screenshot to disk
	-- arg1 is playernumber that requsted the screenshot; if they are using a profile, the screenshot will be saved there
	-- arg2 is a boolean for whether to use lossy compression on the screenshot before writing to disk
	-- arg3 is a boolean for whther to have CRYPTMAN use the machine's private key to sign the screenshot
	--      (there is currently no online system in place that I know that would benefit from that^)
	-- arg4 is an optional string to prefix the filename with
	-- arg5 is an optional string to append to the end of the filename
	--
	-- first return value is boolean indicating success/failure to write to disk
	-- second return value is
	--     (directory + filename) if write to disk was successful
	--     (filename)             if write to disk failed
		
	local success, path = SaveScreenshot(playernum, false, false , prefix, suffix)

	if success then
		MESSAGEMAN:Broadcast("ScreenshotCurrentScreen")
		SM("Automatically saved QR screenshot")
	end
end

local AutoSubmitRequestProcessor = function(res, overlay)
	if not res then return end
	if not overlay then return end

	local autoSubmitMaster = GetChild(overlay, "AutoSubmitMaster")
	local P1SubmitText = GetChild(autoSubmitMaster, "P1SubmitText")
	local P2SubmitText = GetChild(autoSubmitMaster, "P2SubmitText")

	if res.error or res.statusCode ~= 200 then
		local error = res.error and ToEnumShortString(res.error) or nil
		if error == "Timeout" then
			if P1SubmitText then P1SubmitText:queuecommand("TimedOut") end
			if P2SubmitText then P2SubmitText:queuecommand("TimedOut") end
		elseif error or (res.statusCode ~= nil and res.statusCode ~= 200) then
			if P1SubmitText then P1SubmitText:queuecommand("SubmitFailed") end
			if P2SubmitText then P2SubmitText:queuecommand("SubmitFailed") end
		end
		return
	end

	local panes = GetChild(overlay, "Panes")
	local shouldDisplayOverlay = false

	-- Hijack the leaderboard pane to display the GrooveStats leaderboards.
	if panes then
		local data = SL.SafeJsonDecode(res.body)
		local headers = res.headers or {}
		for i=1,2 do
			local playerStr = "player"..i
			local entryNum = 1
			local rivalNum = 1
			-- Pane 8 is the groovestats highscores pane.
			local highScorePane = GetPaneBody(panes, 8, i)
			local QRPane = GetPaneBody(panes, 7, i)

			local RPGPane = GetPaneBody(panes, 9, i)
			local ITLPane = GetPaneBody(panes, 10, i)

			local boogie = false
			local boogie_ex = false
			if headers["bs-leaderboard-player-" .. i] == "BS" then
				boogie = true
				MESSAGEMAN:Broadcast("BoogieLogo",{ player = i })
			elseif headers["bs-leaderboard-player-" .. i] == "BS-EX" then
				boogie_ex = true
				MESSAGEMAN:Broadcast("BoogieEXLogo",{ player = i })
			end
		
			-- If only one player is joined, we then need to update both panes with only
			-- one players' data.
			local side = i
			if data and GAMESTATE:GetNumSidesJoined() == 1 then
				if data["player1"] then
					side = 1
				else
					side = 2
				end
				playerStr = "player"..side
			end

			if data and data[playerStr] then
				-- And then also ensure that the chart hash matches the currently parsed one.
				-- It's better to just not display anything than display the wrong scores.
				if SL["P"..side].Streams.Hash == data[playerStr]["chartHash"] then
					local personalRank = nil
					local showExScore = SL["P"..side].ActiveModifiers.ShowEXScore and data[playerStr]["exLeaderboard"]

					local leaderboardData = data[playerStr] and (
						showExScore and data[playerStr]["exLeaderboard"] or data[playerStr]["gsLeaderboard"]
					)

					if type(leaderboardData) == "table" and highScorePane then
						for gsEntry in ivalues(leaderboardData) do
							local entry = GetHighScoreEntry(highScorePane, entryNum)
							if not entry then break end
							entry:stoptweening()
							entry:diffuse(Color.White)
							SetEntryText(
								gsEntry["rank"]..".",
								GetMachineTag(gsEntry),
								string.format("%.2f%%", gsEntry["score"]/100),
								ParseGroovestatsDate(gsEntry["date"]),
								entry
							)

							-- TODO(teejusb): Determine how we want to easily display EX scores.
							-- For now just highlight blue because it's simple.
							if showExScore then
								DiffuseEntryScore(entry, SL.JudgmentColors["FA+"][1])
							else
								DiffuseEntryScore(entry, Color.White)
							end

							if gsEntry["isRival"] then
								entry:diffuse(color("#BD94FF"))
								rivalNum = rivalNum + 1
							elseif gsEntry["isSelf"] then
								entry:diffuse(color("#A1FF94"))
								personalRank = gsEntry["rank"]
							end

							if gsEntry["isFail"] then
								DiffuseEntryScore(entry, Color.Red)
							end
							entryNum = entryNum + 1
						end

						MarkQRSubmitted(QRPane)
						if i == 1 and P1SubmitText then
							P1SubmitText:queuecommand("Submit")
						elseif i == 2 and P2SubmitText then
							P2SubmitText:queuecommand("Submit")
						end
					elseif data[playerStr]["result"] == "score-added" or data[playerStr]["result"] == "improved" then
						MarkQRSubmitted(QRPane)
						if i == 1 and P1SubmitText then
							P1SubmitText:queuecommand("Submit")
						elseif i == 2 and P2SubmitText then
							P2SubmitText:queuecommand("Submit")
						end
					end

					if data[playerStr]["rpg"] and RPGPane and type(data[playerStr]["rpg"]["rpgLeaderboard"]) == "table" then
						local rpgEntry = 1
						local rpgRival = 1
						for gsEntry in ivalues(data[playerStr]["rpg"]["rpgLeaderboard"]) do
							local entry = GetHighScoreEntry(RPGPane, rpgEntry)
							if not entry then break end
							entry:stoptweening()
							entry:diffuse(Color.White)
							SetEntryText(
								gsEntry["rank"]..".",
								GetMachineTag(gsEntry),
								string.format("%.2f%%", gsEntry["score"]/100),
								ParseGroovestatsDate(gsEntry["date"]),
								entry
							)
							if gsEntry["isRival"] then
								entry:diffuse(color("#BD94FF"))
								rpgRival = rpgRival + 1
							elseif gsEntry["isSelf"] then
								entry:diffuse(color("#A1FF94"))
								-- personalRank = gsEntry["rank"]
							end

							if gsEntry["isFail"] then
								DiffuseEntryScore(entry, Color.Red)
							end
							rpgEntry = rpgEntry + 1
						end
					end

					if data[playerStr]["itl"] and ITLPane and type(data[playerStr]["itl"]["itlLeaderboard"]) == "table" then
						local itlEntry = 1
						local itlRival = 1
						for gsEntry in ivalues(data[playerStr]["itl"]["itlLeaderboard"]) do
							local entry = GetHighScoreEntry(ITLPane, itlEntry)
							if not entry then break end
							entry:stoptweening()
							entry:diffuse(Color.White)
							SetEntryText(
								gsEntry["rank"]..".",
								GetMachineTag(gsEntry),
								string.format("%.2f%%", gsEntry["score"]/100),
								ParseGroovestatsDate(gsEntry["date"]),
								entry
							)
							-- ITL leaderboard is EX scores, so highlight them blue.
							DiffuseEntryScore(entry, SL.JudgmentColors["FA+"][1])
							if gsEntry["isRival"] then
								entry:diffuse(color("#BD94FF"))
								itlRival = itlRival + 1
							elseif gsEntry["isSelf"] then
								entry:diffuse(color("#A1FF94"))
								-- personalRank = gsEntry["rank"]
							end

							if gsEntry["isFail"] then
								DiffuseEntryScore(entry, Color.Red)
							end
							itlEntry = itlEntry + 1
						end
					end

					-- Only display the overlay on the sides that are actually joined.
					if ToEnumShortString("PLAYER_P"..i) == "P"..side and (data[playerStr]["rpg"] or data[playerStr]["itl"]) then
						local eventOverlay = GetChild(autoSubmitMaster, "EventOverlay")
						local eventAf = GetChild(eventOverlay, "P"..i.."EventAf")
						if eventAf then
							eventAf:playcommand("Show", {data=data[playerStr]})
							shouldDisplayOverlay = true
						end
					end

					-- Only update PB/WR messages on the side that is joined
					if ToEnumShortString("PLAYER_P"..i) == "P"..side then
						local upperPane = GetChild(overlay, "P"..side.."_AF_Upper")
						if upperPane then
							if data[playerStr]["result"] == "score-added" or data[playerStr]["result"] == "improved" then
								local recordText = GetChild(autoSubmitMaster, "P"..side.."RecordText")
								local GSIcon = GetChild(autoSubmitMaster, "P"..side.."GrooveStats_Logo")
								local BSIcon = GetChild(autoSubmitMaster, "P"..side.."BoogieStats_Logo")
								local BSEXIcon = GetChild(autoSubmitMaster, "P"..side.."BoogieStatsEX_Logo")

								if recordText then recordText:visible(true) end

								if boogie then
									if BSIcon then BSIcon:visible(true) end
								elseif boogie_ex then
									if BSEXIcon then BSEXIcon:visible(true) end
								else
									if GSIcon then GSIcon:visible(true) end
								end

								if recordText then recordText:diffuseshift():effectcolor1(Color.White):effectcolor2(Color.Yellow):effectperiod(3) end
								local soundDir = THEME:GetCurrentThemeDirectory() .. "Sounds/"
								if personalRank == 1 then
									local worldRecordText = "World Record!"
									if showExScore then
										worldRecordText = worldRecordText .. " (EX)"
									end
									if recordText then recordText:settext(worldRecordText) end
									-- Play random sound in Sounds/Evaluation WR/
									soundDir = soundDir .. "Evaluation WR/"
									local audio_files = findFiles(soundDir)
									if #audio_files > 0 then
										SOUND:PlayOnce(audio_files[math.random(#audio_files)])
									end
								else
									if recordText then recordText:settext("Personal Best!") end
									-- Play random sound in Sounds/Evaluation PB/
									soundDir = soundDir .. "Evaluation PB/"
									local audio_files = findFiles(soundDir)
									if #audio_files > 0 then
										SOUND:PlayOnce(audio_files[math.random(#audio_files)])
									end
								end
								if recordText then
									local recordTextXStart = recordText:GetX() - recordText:GetWidth()*recordText:GetZoom()/2
									-- This will automatically adjust based on the length of the recordText length.
									if GSIcon then GSIcon:xy(recordTextXStart - GSIcon:GetWidth()*GSIcon:GetZoom()/2, recordText:GetY()) end
									if BSIcon then BSIcon:xy(recordTextXStart - BSIcon:GetWidth()*BSIcon:GetZoom()/2, recordText:GetY()) end
									if BSEXIcon then BSEXIcon:xy(recordTextXStart - BSEXIcon:GetWidth()*BSEXIcon:GetZoom()/2, recordText:GetY()) end
								end
							end
						end
					end
				end
			end

			-- Empty out any remaining entries on a successful response.
			-- For failed responses we fallback to the scores available in the machine.
			if highScorePane and res["status"] == "success" then
				for j=entryNum, NumEntries do
					local entry = GetHighScoreEntry(highScorePane, j)
					if not entry then break end
					entry:stoptweening()
					-- We didn't get any scores if i is still == 1.
					if j == 1 then
						SetEntryText("", "No Scores", "", "", entry)
					else
						-- Empty out the remaining rows.
						SetEntryText("---", "----", "------", "----------", entry)
					end
				end
			end
		end
	end

	if shouldDisplayOverlay then
		local eventOverlay = GetChild(autoSubmitMaster, "EventOverlay")
		if eventOverlay then
			eventOverlay:visible(true)
			overlay:queuecommand("DirectInputToEventOverlayHandler")
		end
	end

	if ThemePrefs.Get("AutoDownloadUnlocks") then
		-- This will only download if the expected data exists.
		AttemptDownloads(res)
	end
end

local af = Def.ActorFrame {
	Name="AutoSubmitMaster",
	OnCommand=function(self)
		-- local overlay = SCREENMAN:GetTopScreen():GetChild("Overlay"):GetChild("ScreenEval Common")
		-- overlay:GetChild("AutoSubmitMaster"):GetChild("EventOverlay"):visible(true)
		-- overlay:queuecommand("DirectInputToEventOverlayHandler")

		-- local eventAf = overlay:GetChild("AutoSubmitMaster"):GetChild("EventOverlay"):GetChild("P1EventAf")
		-- eventAf:playcommand("Show", {data={
		-- 	["rpg"] = {
		-- 		["name"] = "SRPG8",
		-- 		["result"] = "score-added",
		-- 		["rpgLeaderboard"] = {
		-- 			{
		-- 				["rank"] = 1,
		-- 				["name"] = "Player1",
		-- 				["score"] = 9900,
		-- 				["date"] ="2024-05-05 1:20:30",
		-- 				["isRival"] = false,
		-- 				["isSelf"] = false,
		-- 			},
		-- 			{
		-- 				["rank"] = 2,
		-- 				["name"] = "Player2",
		-- 				["score"] = 9800,
		-- 				["date"] ="2024-05-05 1:20:30",
		-- 				["isRival"] = true,
		-- 				["isSelf"] = false,
		-- 			},
		-- 			{
		-- 				["rank"] = 3,
		-- 				["name"] = "Player3",
		-- 				["score"] = 9700,
		-- 				["date"] ="2024-05-05 1:20:30",
		-- 				["isRival"] = false,
		-- 				["isSelf"] = true,
		-- 			}
		-- 		}
		-- 	}
		-- }})
	end,
	RequestResponseActor(17, 50)..{
		OnCommand=function(self)
			local sendRequest = false
			local headers = {}
			local query = {
				maxLeaderboardResults=NumEntries,
			}
			local body = {}

			local rate = SL.Global.ActiveModifiers.MusicRate * 100
			for i=1,2 do
				local player = "PlayerNumber_P"..i
				local pn = ToEnumShortString(player)

				if GAMESTATE:IsHumanPlayer(player) and GAMESTATE:IsSideJoined(player) then
					local _, valid = ValidForGrooveStats(player)
					local stats = STATSMAN:GetCurStageStats():GetPlayerStageStats(player)
					local submitForPlayer = false

					if valid and not stats:GetFailed() and SL[pn].IsPadPlayer then
						local percentDP = stats:GetPercentDancePoints()
						local score = tonumber(("%.0f"):format(percentDP * 10000))

						local profileName = ""
						if PROFILEMAN:IsPersistentProfile(player) and PROFILEMAN:GetProfile(player) then
							profileName = PROFILEMAN:GetProfile(player):GetDisplayName()
						end

						if SL[pn].ApiKey ~= "" and SL[pn].Streams.Hash ~= "" then
							query["chartHashP"..i] = SL[pn].Streams.Hash
							headers["x-api-key-player-"..i] = SL[pn].ApiKey

							body["player"..i] = {
								rate=rate,
								score=score,
								judgmentCounts=GetJudgmentCounts(player),
								rescoreCounts=GetRescoredJudgmentCounts(player),
								usedCmod=(GAMESTATE:GetPlayerState(pn):GetPlayerOptions("ModsLevel_Preferred"):CMod() ~= nil),
								comment=CreateCommentString(player),
							}
							sendRequest = true
							submitForPlayer = true
						end
					end

					if not submitForPlayer then
						-- Hide the submit text if we're not submitting a score for a player.
						-- For example in versus, if one player fails and the other passes, we
						-- want to show that the first player score won't be submitted.
						local submitText = self:GetParent():GetChild("P"..i.."SubmitText")
						if submitText then submitText:visible(false) end
					end
				end
			end
			-- Only send the request if it's applicable.
			if sendRequest then
				-- Unjoined players won't have the text displayed.
				local P1SubmitText = self:GetParent():GetChild("P1SubmitText")
				local P2SubmitText = self:GetParent():GetChild("P2SubmitText")
				if P1SubmitText then P1SubmitText:settext("Submitting ...") end
				if P2SubmitText then P2SubmitText:settext("Submitting ...") end
				self:playcommand("MakeGrooveStatsRequest", {
					endpoint="score-submit.php?"..NETWORK:EncodeQueryParameters(query),
					method="POST",
					headers=headers,
					body=JsonEncode(body),
					timeout=30,
					callback=AutoSubmitRequestProcessor,
					args=GetChild(GetChild(SCREENMAN:GetTopScreen(), "Overlay"), "ScreenEval Common"),
				})
			end
		end
	}
}

local textColor = Color.White
local shadowLength = 0
if ThemePrefs.Get("RainbowMode") then
	textColor = Color.Black
end

af[#af+1] = LoadFont(ThemePrefs.Get("ThemeFont") .. " Normal").. {
	Name="P1SubmitText",
	Text="",
	InitCommand=function(self)
		self:xy(_screen.w * 0.25, _screen.h - 15)
		self:diffuse(textColor)
		self:shadowlength(shadowLength)
		self:zoom(0.8)
		self:visible(GAMESTATE:IsSideJoined(PLAYER_1))
	end,
	SubmitCommand=function(self)
		self:settext("Submitted!")
	end,
	SubmitFailedCommand=function(self)
		self:settext("Submit Failed 😞")
		DiffuseEmojis(self)
		
		if PROFILEMAN:IsPersistentProfile(PLAYER_1) then
			if PROFILEMAN:IsPersistentProfile(PLAYER_2) then
				RestorePaneAndHideQR(2, SL["P2"].EvalPanePrimary)
			else
				RestorePaneAndHideQR(2, SL["P2"].EvalPaneSecondary)
			end
			self:sleep(0.1):queuecommand("SS")
		end
	end,
	TimedOutCommand=function(self)
		self:settext("Timed Out")
		
		if PROFILEMAN:IsPersistentProfile(PLAYER_1) then
			if PROFILEMAN:IsPersistentProfile(PLAYER_2) then
				RestorePaneAndHideQR(2, SL["P2"].EvalPanePrimary)
			else
				RestorePaneAndHideQR(2, SL["P2"].EvalPaneSecondary)
			end
			self:sleep(0.1):queuecommand("SS")
		end
	end,
	SSCommand=function(self)
		ScreenshotQR("P1")
	end
}

af[#af+1] = LoadFont(ThemePrefs.Get("ThemeFont") .. " Normal").. {
	Name="P2SubmitText",
	Text="",
	InitCommand=function(self)
		self:xy(_screen.w * 0.75, _screen.h - 15)
		self:diffuse(textColor)
		self:shadowlength(shadowLength)
		self:zoom(0.8)
		self:visible(GAMESTATE:IsSideJoined(PLAYER_2))
	end,
	SubmitCommand=function(self)
		self:settext("Submitted!")
	end,
	SubmitFailedCommand=function(self)
		self:settext("Submit Failed 😞")
		DiffuseEmojis(self)
		
		if PROFILEMAN:IsPersistentProfile(PLAYER_2) then
			if PROFILEMAN:IsPersistentProfile(PLAYER_1) then
				RestorePaneAndHideQR(1, SL["P1"].EvalPanePrimary)
			else
				RestorePaneAndHideQR(1, SL["P1"].EvalPaneSecondary)
			end
			self:sleep(0.1):queuecommand("SS")
		end
	end,
	TimedOutCommand=function(self)
		self:settext("Timed Out")
		
		if PROFILEMAN:IsPersistentProfile(PLAYER_2) then
			if PROFILEMAN:IsPersistentProfile(PLAYER_1) then
				RestorePaneAndHideQR(2, SL["P2"].EvalPanePrimary)
			else
				RestorePaneAndHideQR(2, SL["P2"].EvalPaneSecondary)
			end
			self:sleep(0.1):queuecommand("SS")
		end
	end,
	SSCommand=function(self)
		ScreenshotQR("P2")
	end
}

af[#af+1] = Def.Sprite{
	Texture=THEME:GetPathG("","GrooveStats.png"),
	Name="P1GrooveStats_Logo",
	InitCommand=function(self)
		self:zoom(0.2)
		self:visible(false)
	end,
}

af[#af+1] = Def.Sprite{
	Texture=THEME:GetPathG("","BoogieStats.png"),
	Name="P1BoogieStats_Logo",
	InitCommand=function(self)
		self:zoom(0.2)
		self:visible(false)
	end,
}

af[#af+1] = Def.Sprite{
	Texture=THEME:GetPathG("","BoogieStatsEX.png"),
	Name="P1BoogieStatsEX_Logo",
	InitCommand=function(self)
		self:zoom(0.2)
		self:visible(false)
	end,
}

af[#af+1] = LoadFont(ThemePrefs.Get("ThemeFont") .. " Bold")..{
	Name="P1RecordText",
	InitCommand=function(self)
		local x = _screen.cx - 225
		self:zoom(0.225)
		self:xy(x,40)
		self:visible(false)
	end,
}

af[#af+1] = Def.Sprite{
	Texture=THEME:GetPathG("","GrooveStats.png"),
	Name="P2GrooveStats_Logo",
	InitCommand=function(self)
		self:zoom(0.2)
		self:visible(false)
	end,
}

af[#af+1] = Def.Sprite{
	Texture=THEME:GetPathG("","BoogieStats.png"),
	Name="P2BoogieStats_Logo",
	InitCommand=function(self)
		self:zoom(0.2)
		self:visible(false)
	end,
}

af[#af+1] = Def.Sprite{
	Texture=THEME:GetPathG("","BoogieStatsEX.png"),
	Name="P2BoogieStatsEX_Logo",
	InitCommand=function(self)
		self:zoom(0.2)
		self:visible(false)
	end,
}

af[#af+1] = LoadFont(ThemePrefs.Get("ThemeFont") .. " Bold")..{
	Name="P2RecordText",
	InitCommand=function(self)
		local x = _screen.cx + 225
		self:zoom(0.225)
		self:xy(x,40)
		self:visible(false)
	end,
}

af[#af+1] = LoadActor("./EventOverlay.lua")

return af
