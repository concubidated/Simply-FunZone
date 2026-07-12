local args = {...}
local player = args[1]
local pn = ToEnumShortString(player)

local IsUltraWide = (GetScreenAspectRatio() > 21/9)

local AwardMap = {
	["StageAward_FullComboW1"] = 1,
	["StageAward_FullComboW2"] = 2,
	["StageAward_SingleDigitW2"] = 2,
	["StageAward_OneW2"] = 2,
	["StageAward_FullComboW3"] = 3,
	["StageAward_SingleDigitW3"] = 3,
	["StageAward_OneW3"] = 3,
	["StageAward_100PercentW3"] = 3,
	-- FullComboW4 technically doesn't exist, but we create it on the fly below.
	["StageAward_FullComboW4"] = 4,
}

local ClearLamp = { color("#0000CC"), color("#990000") }

local lamp_cache = {}
local function GetSongKey(song)
	local song_dir = song:GetSongDir()
	if song_dir ~= nil and #song_dir ~= 0 then return song_dir end
	return song:GetDisplayFullTitle() or ""
end

local function GetLamp(song)
	if not song then return nil end
	
	local current_steps = GAMESTATE:GetCurrentSteps(pn)
	if not current_steps then return nil end
	
	local diff = current_steps:GetDifficulty()
	local stepstype = GAMESTATE:GetCurrentStyle():GetStepsType()
	local profile = PROFILEMAN:GetProfile(player)
	local profileName = profile:GetDisplayName()
	local cache_key = profileName .. "|" .. GetSongKey(song) .. "|" .. tostring(diff) .. "|" .. tostring(stepstype) .. "|" .. SL.Global.GameMode
	if lamp_cache[cache_key] ~= nil then
		return lamp_cache[cache_key].lamp, lamp_cache[cache_key].tap_count
	end
	
	local stepsList = song:GetAllSteps()
	local steps = nil
	
	for check in ivalues(stepsList) do
		if check:GetDifficulty() == diff and check:GetStepsType() == stepstype then
			steps = check
			break
		end
	end
	
	if steps == nil then
		lamp_cache[cache_key] = {}
		return nil
	end
	
	local high_score_list = profile:GetHighScoreListIfExists(song, steps)

	-- If no scores then just return.
	if high_score_list == nil then
		lamp_cache[cache_key] = {}
		return nil
	end

	local high_scores = high_score_list:GetHighScores()
	if #high_scores == 0 then
		lamp_cache[cache_key] = {}
		return nil
	end

	local best_lamp = nil
	local tap_count = 99

	for score in ivalues(high_scores) do
		local award = score:GetStageAward()

		if award == nil and SL.Global.GameMode == "FA+" and score:GetGrade() ~= "Grade_Failed" then
			-- Dropping a roll/hold breaks the StageAward, but hitting a mine does not.
			local misses = score:GetTapNoteScore("TapNoteScore_Miss") +
					score:GetHoldNoteScore("HoldNoteScore_LetGo") +
					score:GetTapNoteScore("TapNoteScore_CheckpointMiss")
			if misses + score:GetTapNoteScore("TapNoteScore_W5") == 0 then
				award = "StageAward_FullComboW4"
			end
		end
		
		if award and AwardMap[award] ~= nil then
			-- Reset tap count if the best lamp goes up
			if best_lamp ~= nil and AwardMap[award] < best_lamp then
				tap_count = 99
			end
			best_lamp = math.min(best_lamp and best_lamp or 999, AwardMap[award])
		end
		
		-- Single Digit Judge Count
		if AwardMap[award] == best_lamp then
			if best_lamp == 1 and score:GetScore() > 0 then
				tap_count = math.min(tap_count, score:GetScore())
			elseif best_lamp == 2 then
				tap_count = math.min(tap_count, score:GetTapNoteScore("TapNoteScore_W2"))
			elseif best_lamp == 3 then
				tap_count = math.min(tap_count, score:GetTapNoteScore("TapNoteScore_W3"))
			end
		end
			
		
		if AwardMap[award] == best_lamp and best_lamp == 1 and score:GetScore() == 0 then
			best_lamp = 0
		elseif best_lamp == nil then
			if score:GetGrade() == "Grade_Failed" then best_lamp = 52
			else best_lamp = 51 end
		end
	end

	lamp_cache[cache_key] = { lamp=best_lamp, tap_count=tap_count }
	return best_lamp,tap_count
end

local function MaybeSetLampForUnmarkedItlSong(self, player)
	local pn = ToEnumShortString(player)
	local hash = SL[pn].Streams.Hash
	if SL[pn].ITLData["hashMap"][hash] ~= nil then
		local song = GAMESTATE:GetCurrentSong()
		local song_dir = song:GetSongDir()
		if song_dir ~= nil and #song_dir ~= 0 then
			if SL[pn].ITLData["pathMap"][song_dir] == nil then
				SL[pn].ITLData["pathMap"][song_dir] = hash

				-- TODO: This seems to be offset for whatever reason when initially hovering over the song.
				-- Figure out what's going on.

				-- local itl_lamp = 6 - SL[pn].ITLData["hashMap"][hash]["clearType"]
				-- if itl_lamp == 5 then
				-- 	self:visible(false)
				-- else
				-- 	self:visible(true)
				-- 	self:diffuseshift():effectperiod(0.8)
				-- 	self:effectcolor1(SL.JudgmentColors["FA+"][itl_lamp])
				-- 	self:effectcolor2(lerp_color(0.70, color("#ffffff"), SL.JudgmentColors["FA+"][itl_lamp]))
				-- end

				-- if player == PLAYER_2 and GAMESTATE:GetNumSidesJoined() == 2 then
				-- 	-- Ultrawide is quite hard to align, manually scale for it.
				-- 	if IsUltraWide then
				-- 		self:x(SL_WideScale(18, 30) * 2 + SL_WideScale(5, 8) + 40)
				-- 	else
				-- 		self:x(SL_WideScale(18, 30) * 2 + SL_WideScale(5, 8))
				-- 	end
				-- end
				WriteItlFile(player)
			end
		end
	end
end

return Def.ActorFrame{
	Def.Quad{
		P1ChartParsedMessageCommand=function(self)
			if player ~= PLAYER_1 then return end
			MaybeSetLampForUnmarkedItlSong(self, player)
		end,
		P2ChartParsedMessageCommand=function(self)
			if player ~= PLAYER_2 then return end
			MaybeSetLampForUnmarkedItlSong(self, player)
		end,
		PlayerJoinedMessageCommand=function(self)
			self:visible(GAMESTATE:IsPlayerEnabled(player))
		end,
		PlayerUnjoinedMessageCommand=function(self)
			self:visible(GAMESTATE:IsPlayerEnabled(player))
		end,
		SetCommand=function(self, param)
			-- Only use lamps if a profile is found for an enabled player.
			if not GAMESTATE:IsPlayerEnabled(player) or not PROFILEMAN:IsPersistentProfile(player) then
				self:visible(false)
				return
			end

			self:scaletoclipped(SL_WideScale(13, 21), SL_WideScale(5, 3))
			self:y(14)
			self:horizalign(center)
			if IsUltraWide then
				if player == PLAYER_1 then
					self:x(_screen.w/43)
				elseif player == PLAYER_2 then
					self:x(_screen.w/15.25)
				end
			else
				if player == PLAYER_1 then
					self:x(SL_WideScale(10, 17))
				elseif player == PLAYER_2 then
					self:x(SL_WideScale(26, 47))
				end
			end
			--TODO use GetX and GetParent to get the Xpos of MusicWheelItem grades (fixes positioning issues in odd aspect ratios; add a name to that Sprite!
			-- if player == PLAYER_1 then
			-- 	self:x(GetParent():GetParent():GetChild("Grade"..pn):GetX())
			-- elseif player == PLAYER_2 then
			-- 	self:x(GetParent():GetParent():GetChild("Grade"..pn):GetX())
			-- end

			-- Check ITL File
			local itl_lamp = nil
			local itl_taps = 99
			if param.Song ~= nil then
				local song = param.Song
				local song_dir = song:GetSongDir()
				if song_dir ~= nil and #song_dir ~= 0 then
					if SL[pn].ITLData["pathMap"][song_dir] ~= nil then
						local hash = SL[pn].ITLData["pathMap"][song_dir]
						if SL[pn].ITLData["hashMap"][hash] ~= nil then
							itl_lamp = 5 - SL[pn].ITLData["hashMap"][hash]["clearType"]
							if SL[pn].ITLData["hashMap"][hash]["judgments"]["W" .. itl_lamp] then
								itl_taps = math.min(itl_taps, SL[pn].ITLData["hashMap"][hash]["judgments"]["W" .. itl_lamp])
							end
						end
					end
				end
			end

			if itl_lamp ~= nil then
				-- Disable for normal clear types. The wheel grade should cover it.
				if itl_lamp >= 4 then
					self:visible(true):stopeffect()
					self:diffuse(ClearLamp[1])
					self:GetParent():GetChild("Judge"):playcommand("Hide")
				else
					self:visible(true)
					self:diffuseshift():effectperiod(0.8)
					if itl_lamp == 0 then
						-- Quinted, use a special color
						local ItlPink = color("1,0.2,0.406,1")
						self:effectcolor1(ItlPink)
						self:effectcolor2(lerp_color(0.70, color("#ffffff"), ItlPink))
						self:GetParent():GetChild("Judge"):playcommand("Hide")
					else
						self:effectcolor1(SL.JudgmentColors["ITG"][itl_lamp])
						self:effectcolor2(lerp_color(0.70, color("#ffffff"), SL.JudgmentColors["ITG"][itl_lamp]))
						if itl_taps < 10 then
							self:GetParent():GetChild("Judge"):playcommand("Count", {count=itl_taps,lamp=itl_lamp})
						end
					end
				end
			else
				local lamp, tap_count = GetLamp(param.Song)
				if lamp == nil then
					self:visible(false)
					self:GetParent():GetChild("Judge"):playcommand("Hide")
				elseif lamp > 50 then
					self:visible(true)
					self:stopeffect()
					self:diffuse(ClearLamp[lamp - 50])
					self:GetParent():GetChild("Judge"):playcommand("Hide")
				elseif lamp == 0 then
					-- Quinted, use a special color
					self:visible(true)
					local ItlPink = color("1,0.2,0.406,1")
					self:diffuseshift():effectperiod(0.8)
					self:effectcolor1(ItlPink)
					self:effectcolor2(lerp_color(0.70, color("#ffffff"), ItlPink))
					self:GetParent():GetChild("Judge"):playcommand("Hide")
				else
					self:visible(true)
					self:diffuseshift():effectperiod(0.8)
					self:effectcolor1(SL.JudgmentColors[SL.Global.GameMode][lamp])
					self:effectcolor2(lerp_color(
						0.70, color("#ffffff"), SL.JudgmentColors[SL.Global.GameMode][lamp]))
						
					if tap_count and tap_count < 10 then
						self:GetParent():GetChild("Judge"):playcommand("Count", {count=tap_count,lamp=lamp})
					else
						self:GetParent():GetChild("Judge"):playcommand("Hide")
					end
				end
			end
		end
	},
	
	Def.BitmapText{
		Font=ThemePrefs.Get("ThemeFont") .. " ScreenEval",
		Name="Judge",
		Text="5",
		InitCommand=function(self)
			self:visible(false)
			self:zoom(0.12)
			self:addy(8)
			self:diffuse(1,1,1,1)
		end,
		CountCommand=function(self, param)
			if player == PLAYER_2 and GAMESTATE:GetNumSidesJoined() == 2 then
				-- Ultrawide is quite hard to align, manually scale for it.
				if IsUltraWide then
					self:x(SL_WideScale(18, 30) * 2 + SL_WideScale(5, 8) + 40 -9.2)
				else
					self:x(SL_WideScale(18, 30) * 2 + SL_WideScale(5, 8) -9.2)
				end
			else
				self:x(3)
			end
			self:settext(param.count):visible(true):diffuse(SL.JudgmentColors["FA+"][param.lamp+1])
		end,
		HideCommand=function(self)
			self:settext(""):visible(false)
		end,
	}
		
}
