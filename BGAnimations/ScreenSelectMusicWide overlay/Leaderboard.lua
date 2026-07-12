local NumEntries = 13
local RowHeight = 24

local GetChild = function(actor, child_name)
	return actor and actor:GetChild(child_name) or nil
end

local SetActorText = function(actor, text)
	if actor then actor:settext(text or "") end
end

local SetActorVisible = function(actor, visible)
	if actor then actor:visible(visible) end
end

local FormatLeaderboardScore = function(score)
	local score_value = tonumber(score)
	if not score_value then return "" end
	return string.format("%.2f%%", score_value/100)
end

local GetLeaderboardMaster = function()
	local top_screen = SCREENMAN:GetTopScreen()
	if not top_screen then return nil end
	local overlay = top_screen:GetChild("Overlay")
	return overlay and overlay:GetChild("LeaderboardMaster") or nil
end

local SetEntryText = function(rank, name, score, date, actor)
	if actor == nil then return end

	SetActorText(GetChild(actor, "Rank"), rank)
	SetActorText(GetChild(actor, "Name"), name)
	SetActorText(GetChild(actor, "Score"), score)
	SetActorText(GetChild(actor, "Date"), date)
end

local SetLeaderboardRows = function(leaderboard, first_row_text)
	if not leaderboard then return end
	for j=1, NumEntries do
		local entry = leaderboard:GetChild("LeaderboardEntry"..j)
		if j == 1 then
			SetEntryText("", first_row_text, "", "", entry)
		else
			SetEntryText("", "", "", "", entry)
		end
	end
end

local SetLeaderboardForPlayer = function(player_num, leaderboard, leaderboardData, isRanked)
	if leaderboard == nil or leaderboardData == nil then return end
	local playerStr = "player"..player_num
	local entryNum = 1
	local rivalNum = 1

	-- Hide the rival and self highlights.
	-- They will be unhidden and repositioned as needed below.
	for i=1,3 do
		SetActorVisible(GetChild(leaderboard, "Rival"..i), false)
	end
	SetActorVisible(GetChild(leaderboard, "Self"), false)

	-- Hide/Unhide EX score display
	SetActorVisible(GetChild(leaderboard, "EX"), leaderboardData["IsEX"])

	if leaderboardData then
		if type(leaderboardData["Name"]) == "string" then
			local name = leaderboardData["Name"]:gsub("ITL Online", "ITL")
			SetActorText(GetChild(leaderboard, "Header"), name)
		elseif leaderboardData["Name"] then
			SetActorText(GetChild(leaderboard, "Header"), tostring(leaderboardData["Name"]))
		end

		if type(leaderboardData["Data"]) == "table" then
			for gsEntry in ivalues(leaderboardData["Data"]) do
				if type(gsEntry) ~= "table" then gsEntry = {} end
				local entry = leaderboard:GetChild("LeaderboardEntry"..entryNum)
				SetEntryText(
					tostring(gsEntry["rank"] or "")..".",
					gsEntry["name"] or "",
					FormatLeaderboardScore(gsEntry["score"]),
					gsEntry["date"] and ParseGroovestatsDate(gsEntry["date"]) or "",
					entry
				)
				if entry and gsEntry["isRival"] then
					if gsEntry["isFail"] then
						local rank = entry:GetChild("Rank")
						local name = entry:GetChild("Name")
						local score = entry:GetChild("Score")
						local date = entry:GetChild("Date")
						if rank then rank:diffuse(Color.Black) end
						if name then name:diffuse(Color.Black) end
						if score then score:diffuse(Color.Red) end
						if date then date:diffuse(Color.Black) end
					else
						entry:diffuse(Color.Black)
					end
					local rival = leaderboard:GetChild("Rival"..rivalNum)
					if rival then rival:y(entry:GetY()):visible(true) end
					rivalNum = rivalNum + 1
				elseif entry and gsEntry["isSelf"] then
					if gsEntry["isFail"] then
						local rank = entry:GetChild("Rank")
						local name = entry:GetChild("Name")
						local score = entry:GetChild("Score")
						local date = entry:GetChild("Date")
						if rank then rank:diffuse(Color.Black) end
						if name then name:diffuse(Color.Black) end
						if score then score:diffuse(Color.Red) end
						if date then date:diffuse(Color.Black) end
					else
						entry:diffuse(Color.Black)
					end
					local self_highlight = leaderboard:GetChild("Self")
					if self_highlight then self_highlight:y(entry:GetY()):visible(true) end
				elseif entry then
					entry:diffuse(Color.White)
				end

				-- Why does this work for normal entries but not for Rivals/Self where
				-- I have to explicitly set the colors for each child??
				if entry and gsEntry["isFail"] then
					local score = entry:GetChild("Score")
					if score then score:diffuse(Color.Red) end
				end
				entryNum = entryNum + 1
			end
		end
	end

	-- Empty out any remaining entries.
	-- This also handles the error case. If success is false, then the above if block will not run.
	-- and we will set the first entry to "Failed to Load 😞".
	for i=entryNum, NumEntries do
		local entry = leaderboard:GetChild("LeaderboardEntry"..i)
		-- We didn't get any scores if i is still == 1.
		if i == 1 then
			SetEntryText("", "No Scores", "", "", entry)
		else
			-- Empty out the remaining rows.
			SetEntryText("", "", "", "", entry)
		end
	end
end

local LeaderboardRequestProcessor = function(res, master)
	if master == nil then return end

	if res.error or res.statusCode ~= 200 then
		local error = res.error and ToEnumShortString(res.error) or nil
		local text = ""
		if error == "Timeout" then
			text = "Timed Out"
		elseif error or (res.statusCode ~= nil and res.statusCode ~= 200) then
			text = "Failed to Load 😞"
		end
		for i=1, 2 do
			local pn = "P"..i
			local leaderboard = master:GetChild(pn.."Leaderboard")
			SetLeaderboardRows(leaderboard, text)
		end
		return
	end

	local data = SL.SafeJsonDecode(res.body)
	if not data then
		for i=1, 2 do
			local pn = "P"..i
			local leaderboard = master:GetChild(pn.."Leaderboard")
			SetLeaderboardRows(leaderboard, "Failed to Load")
		end
		return
	end

	for i=1, 2 do
		local playerStr = "player"..i
		local pn = "P"..i
		local leaderboard = master:GetChild(pn.."Leaderboard")
		if not master[pn] or type(master[pn]["Leaderboards"]) ~= "table" then return end
		local leaderboardList = master[pn]["Leaderboards"]
		local headers = res.headers or {}
		local boogie = false
		local boogie_ex = false
		if headers["bs-leaderboard-player-" .. i] == "BS" then
			boogie = true
		elseif headers["bs-leaderboard-player-" .. i] == "BS-EX" then
			boogie_ex = true
		end

		if type(data[playerStr]) == "table" then
			master[pn].isRanked = data[playerStr]["isRanked"]

			-- First add the main leaderboard.
			if boogie then
				if type(data[playerStr]["gsLeaderboard"]) == "table" then
					leaderboardList[#leaderboardList + 1] = {
						Name="BoogieStats",
						Data=DeepCopy(data[playerStr]["gsLeaderboard"]),
						IsEX=false
					}
					master[pn]["LeaderboardIndex"] = 1
				end
			elseif boogie_ex then
				if type(data[playerStr]["gsLeaderboard"]) == "table" then
					leaderboardList[#leaderboardList + 1] = {
						Name="BoogieStats",
						Data=DeepCopy(data[playerStr]["gsLeaderboard"]),
						IsEX=true
					}
					master[pn]["LeaderboardIndex"] = 1
				end
			elseif SL["P"..i].ActiveModifiers.ShowEXScore then
				-- If the player is using EX scoring, then we want to display the EX leaderboard first.
				if type(data[playerStr]["exLeaderboard"]) == "table" then
					leaderboardList[#leaderboardList + 1] = {
						Name="GrooveStats",
						Data=DeepCopy(data[playerStr]["exLeaderboard"]),
						IsEX=true
					}
					master[pn]["LeaderboardIndex"] = 1
				end

				if type(data[playerStr]["gsLeaderboard"]) == "table" then
					leaderboardList[#leaderboardList + 1] = {
						Name="GrooveStats",
						Data=DeepCopy(data[playerStr]["gsLeaderboard"]),
						IsEX=false
					}
					master[pn]["LeaderboardIndex"] = 1
				end
			else
				-- Display the main GrooveStats leaderboard first if player is not using EX scoring.
				if type(data[playerStr]["gsLeaderboard"]) == "table" then
					leaderboardList[#leaderboardList + 1] = {
						Name="GrooveStats",
						Data=DeepCopy(data[playerStr]["gsLeaderboard"]),
						IsEX=false
					}
					master[pn]["LeaderboardIndex"] = 1
				end
				
				if type(data[playerStr]["exLeaderboard"]) == "table" then
					leaderboardList[#leaderboardList + 1] = {
						Name="GrooveStats",
						Data=DeepCopy(data[playerStr]["exLeaderboard"]),
						IsEX=true
					}
					master[pn]["LeaderboardIndex"] = 1
				end
			end

			-- Then any event leaderboards.
			local events = {"rpg", "itl"}
			for event in ivalues(events) do
				if type(data[playerStr][event]) == "table" and type(data[playerStr][event][event.."Leaderboard"]) == "table" then
					leaderboardList[#leaderboardList + 1] = {
						Name=data[playerStr][event]["name"],
						Data=DeepCopy(data[playerStr][event][event.."Leaderboard"]),
						IsEX=(event == "itl")
					}
					master[pn]["LeaderboardIndex"] = 1
				end
			end

			SetActorVisible(GetChild(leaderboard, "PaneIcons"), #leaderboardList > 1)
		end

		-- We assume that at least one leaderboard has been added.
		-- If leaderboardData is nil as a result, the SetLeaderboardForPlayer
		-- function will handle it.
		local leaderboardData = leaderboardList[1]
		SetLeaderboardForPlayer(i, leaderboard, leaderboardData, master[pn].isRanked)
	end
end

local af = Def.ActorFrame{
	Name="LeaderboardMaster",
	InitCommand=function(self) self:visible(false) end,
	ShowLeaderboardCommand=function(self)
		self:visible(true)
		for i=1, 2 do
			local pn = "P"..i
			self[pn] = {}
			self[pn].isRanked = false
			self[pn].Leaderboards = {}
			self[pn].LeaderboardIndex = 0
		end
		MESSAGEMAN:Broadcast("ResetEntry")
		-- Only make the request when this actor gets actually displayed through the sort menu.
		self:queuecommand("SendLeaderboardRequest")
	end,
	HideLeaderboardCommand=function(self) self:visible(false) end,
	LeaderboardInputEventMessageCommand=function(self, event)
		if not event or not event.PlayerNumber then return end
		local pn = ToEnumShortString(event.PlayerNumber)
		if not self[pn] or type(self[pn].Leaderboards) ~= "table" or #self[pn].Leaderboards == 0 then return end

		if event.type == "InputEventType_FirstPress" then
			-- We don't use modulus because #Leaderboards might be zero.
			if event.GameButton == "MenuLeft" then
				self[pn].LeaderboardIndex = self[pn].LeaderboardIndex - 1

				if self[pn].LeaderboardIndex == 0 then
					-- Wrap around if we decremented from 1 to 0.
					self[pn].LeaderboardIndex = #self[pn].Leaderboards
				end
			elseif event.GameButton == "MenuRight" then
				self[pn].LeaderboardIndex = self[pn].LeaderboardIndex + 1

				if self[pn].LeaderboardIndex > #self[pn].Leaderboards then
					-- Wrap around if we incremented past #Leaderboards
					self[pn].LeaderboardIndex = 1
				end
			end

			if event.GameButton == "MenuLeft" or event.GameButton == "MenuRight" then
				local leaderboard = self:GetChild(pn.."Leaderboard")
				local leaderboardList = self[pn]["Leaderboards"]
				local leaderboardData = leaderboardList[self[pn].LeaderboardIndex]
				SetLeaderboardForPlayer("P1" == pn and 1 or 2, leaderboard, leaderboardData, self[pn].isRanked)
			end
		end
	end,

	Def.Quad{ InitCommand=function(self) self:FullScreen():diffuse(0,0,0,0.875) end },
	LoadFont(ThemePrefs.Get("ThemeFont") .. " Normal")..{
		Text=THEME:GetString("Common", "PopupDismissText"),
		InitCommand=function(self) self:xy(_screen.cx, _screen.h-50):zoom(1.1) end
	},
	RequestResponseActor(17, 50)..{
		SendLeaderboardRequestCommand=function(self)
			if not IsServiceAllowed(SL.GrooveStats.Leaderboard) then
				if SL.GrooveStats.IsConnected then
					-- If we disable the service from a previous request, surface it to the user here.
					-- (Even though the Leaderboard option is already removed from the sort menu, so this is extra).
					local parent = self:GetParent()
					if not parent then return end
					for i=1, 2 do
						local pn = "P"..i
						local leaderboard = parent:GetChild(pn.."Leaderboard")
						SetLeaderboardRows(leaderboard, "Disabled")
					end
				end
				return
			end

			local sendRequest = false
			local headers = {}
			local query = {
				maxLeaderboardResults=NumEntries,
			}

			for i=1,2 do
				local pn = "P"..i
				if SL[pn].ApiKey ~= "" and SL[pn].Streams.Hash ~= "" then
					query["chartHashP"..i] = SL[pn].Streams.Hash
					headers["x-api-key-player-"..i] = SL[pn].ApiKey
					sendRequest = true
				end
			end
			-- Only send the request if it's applicable.
			-- Technically this should always be true since otherwise we wouldn't even get to this screen.
			if sendRequest then
				local master = GetLeaderboardMaster()
				if not master then return end
				self:playcommand("MakeGrooveStatsRequest", {
					endpoint="player-leaderboards.php?"..NETWORK:EncodeQueryParameters(query),
					method="GET",
					headers=headers,
					timeout=10,
					callback=LeaderboardRequestProcessor,
					args=master,
				})
			end
		end
	}
}

local paneWidth1Player = 330
local paneWidth2Player = 230
local paneWidth = (GAMESTATE:GetNumSidesJoined() == 1) and paneWidth1Player or paneWidth2Player
local paneHeight = 360
local borderWidth = 2

for player in ivalues( PlayerNumber ) do
	af[#af+1] = Def.ActorFrame{
		Name=ToEnumShortString(player).."Leaderboard",
		InitCommand=function(self)
			self:y(_screen.cy - 15)
			self:queuecommand("Refresh")
		end,
		PlayerJoinedMessageCommand=function(self)
			self:queuecommand("Refresh")
		end,

		RefreshCommand=function(self)
			self:visible(GAMESTATE:IsSideJoined(player))

			if GAMESTATE:GetNumSidesJoined() == 1 then
				self:xy(_screen.cx, _screen.cy - 15)
			else
				self:xy(_screen.cx + 160 * (player==PLAYER_1 and -1 or 1), _screen.cy - 15)
			end
			self:SetWidth(paneWidth)
		end,

		-- White border
		Def.Quad {
			InitCommand=function(self)
				self:diffuse(Color.White)
			end,
			RefreshCommand=function(self)
				local width = self:GetParent():GetWidth()
				self:zoomto(width + borderWidth, paneHeight + borderWidth)
			end
		},

		-- Main black body
		Def.Quad {
			InitCommand=function(self)
				self:diffuse(Color.Black)
			end,
			RefreshCommand=function(self)
				local width = self:GetParent():GetWidth()
				self:zoomto(width, paneHeight)
			end
		},

		-- Header border
		Def.Quad {
			InitCommand=function(self)
				self:diffuse(Color.White):y(-paneHeight/2 + RowHeight/2)
			end,
			RefreshCommand=function(self)
				local width = self:GetParent():GetWidth()
				self:zoomto(width + borderWidth, RowHeight + borderWidth)
			end
		},

		-- Blue Header
		Def.Quad {
			InitCommand=function(self)
				self:diffuse(Color.Blue):y(-paneHeight/2 + RowHeight/2)
			end,
			RefreshCommand=function(self)
				local width = self:GetParent():GetWidth()
				self:zoomto(width, RowHeight)
			end
		},

		-- Header Text
		LoadFont("Wendy/_wendy small").. {
			Name="Header",
			Text="GrooveStats",
			InitCommand=function(self)
				self:zoom(0.5)
				self:y(-paneHeight/2 + 12)
			end
		},

		-- EX Text
		LoadFont("Wendy/_wendy small").. {
			Name="EX",
			Text="EX",
			InitCommand=function(self)
				self:zoom(0.5)
				self:y(-paneHeight/2 + 12)
				self:x(paneWidth/2 - 16)
				self:visible(false)
			end
		},

		-- Highlight backgrounds for the leaderboard. Initially hidden.
		Def.Quad {
			Name="Rival1",
			InitCommand=function(self)
				self:diffuse(color("#BD94FF")):visible(false)
			end,
			ResetEntryMessageCommand=function(self)
				self:visible(false)
			end,
			RefreshCommand=function(self)
				local width = self:GetParent():GetWidth()
				self:zoomto(width, RowHeight)
			end
		},

		Def.Quad {
			Name="Rival2",
			InitCommand=function(self)
				self:diffuse(color("#BD94FF")):visible(false)
			end,
			ResetEntryMessageCommand=function(self)
				self:visible(false)
			end,
			RefreshCommand=function(self)
				local width = self:GetParent():GetWidth()
				self:zoomto(width, RowHeight)
			end
		},

		Def.Quad {
			Name="Rival3",
			InitCommand=function(self)
				self:diffuse(color("#BD94FF")):visible(false)
			end,
			ResetEntryMessageCommand=function(self)
				self:visible(false)
			end,
			RefreshCommand=function(self)
				local width = self:GetParent():GetWidth()
				self:zoomto(width, RowHeight)
			end
		},

		Def.Quad {
			Name="Self",
			InitCommand=function(self)
				self:diffuse(color("#A1FF94")):visible(false)
			end,
			ResetEntryMessageCommand=function(self)
				self:visible(false)
			end,
			RefreshCommand=function(self)
				local width = self:GetParent():GetWidth()
				self:zoomto(width, RowHeight)
			end
		},

		-- Marker for the additional panes. Hidden by default.
		Def.ActorFrame{
			Name="PaneIcons",
			InitCommand=function(self)
				self:y(paneHeight/2 - RowHeight/2)
				self:visible(false)
			end,
			ResetEntryMessageCommand=function(self)
				self:visible(false)
			end,

			LoadFont(ThemePrefs.Get("ThemeFont") .. " Normal").. {
				Name="LeftIcon",
				Text="&MENULEFT;",
				InitCommand=function(self)
					self:x(-paneWidth/2 + 10)
				end,
				OnCommand=function(self) self:queuecommand("Bounce") end,
				BounceCommand=function(self)
					self:decelerate(0.5):addx(10):accelerate(0.5):addx(-10)
					self:queuecommand("Bounce")
				end,
			},

			LoadFont(ThemePrefs.Get("ThemeFont") .. " Normal").. {
				Name="Text",
				Text="More Leaderboards",
				InitCommand=function(self)
					self:diffuse(Color.White)
				end,
			},

			LoadFont(ThemePrefs.Get("ThemeFont") .. " Normal").. {
				Name="RightIcon",
				Text="&MENURiGHT;",
				InitCommand=function(self)
					self:x(paneWidth/2 - 10)
				end,
				OnCommand=function(self) self:queuecommand("Bounce") end,
				BounceCommand=function(self)
					self:decelerate(0.5):addx(-10):accelerate(0.5):addx(10)
					self:queuecommand("Bounce")
				end,
			},
		}
	}

	local af2 = af[#af]
	for i=1, NumEntries do
		--- Each entry has a Rank, Name, and Score subactor.
		af2[#af2+1] = Def.ActorFrame{
			Name="LeaderboardEntry"..i,
			InitCommand=function(self)
				if NumEntries % 2 == 1 then
					self:y(RowHeight*(i - (NumEntries+1)/2) )
				else
					self:y(RowHeight*(i - NumEntries/2))
				end
			end,
			RefreshCommand=function(self)
				local width = self:GetParent():GetWidth()
				self:x(-(width-paneWidth2Player)/2)
				self:GetChild("Date"):visible(GAMESTATE:GetNumSidesJoined() == 1)
			end,

			LoadFont(ThemePrefs.Get("ThemeFont") .. " Normal").. {
				Name="Rank",
				Text="",
				InitCommand=function(self)
					self:horizalign(right)
					self:maxwidth(30)
					self:x(-paneWidth2Player/2 + 30 + borderWidth)
					self:diffuse(Color.White)
				end,
				ResetEntryMessageCommand=function(self)
					self:settext("")
					self:diffuse(Color.White)
				end
			},

			LoadFont(ThemePrefs.Get("ThemeFont") .. " Normal").. {
				Name="Name",
				Text=(i==1 and "Loading" or ""),
				InitCommand=function(self)
					self:horizalign(center)
					self:maxwidth(130)
					self:x(-paneWidth2Player/2 + 100)
					self:diffuse(Color.White)
				end,
				ResetEntryMessageCommand=function(self)
					self:settext(i==1 and "Loading" or "")
					self:diffuse(Color.White)
				end
			},

			LoadFont(ThemePrefs.Get("ThemeFont") .. " Normal").. {
				Name="Score",
				Text="",
				InitCommand=function(self)
					self:horizalign(right)
					self:x(paneWidth2Player/2-borderWidth)
					self:diffuse(Color.White)
				end,
				ResetEntryMessageCommand=function(self)
					self:settext("")
					self:diffuse(Color.White)
				end
			},
			LoadFont(ThemePrefs.Get("ThemeFont") .. " Normal").. {
				Name="Date",
				Text="",
				InitCommand=function(self)
					self:horizalign(right)
					self:x(paneWidth2Player/2 + 100 - borderWidth)
					self:diffuse(Color.White)
				end,
				ResetEntryMessageCommand=function(self)
					self:settext("")
					self:diffuse(Color.White)
				end
			},
		}
	end
end

return af
