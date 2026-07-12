local player = ...
local pn = ToEnumShortString(player)
local p = PlayerNumber:Reverse()[player]

local text_table, marquee_index

-- EX score is a number like 92.67
local GetPointsForSong = function(maxPoints, exScore)
	local thresholdEx = 50.0
	local percentPoints = 40.0

	-- Helper function to take the logarithm with a specific base.
	local logn = function(x, y)
		return math.log(x) / math.log(y)
	end

	-- The first half (logarithmic portion) of the scoring curve.
	local first = logn(
		math.min(exScore, thresholdEx) + 1,
		math.pow(thresholdEx + 1, 1 / percentPoints)
	)

	-- The seconf half (exponential portion) of the scoring curve.
	local second = math.pow(
		100 - percentPoints + 1,
		math.max(0, exScore - thresholdEx) / (100 - thresholdEx)
	) - 1

	-- Helper function to round to a specific number of decimal places.
	-- We want 100% EX to actually grant 100% of the points.
	-- We don't want to  lose out on any single points if possible. E.g. If
	-- 100% EX returns a number like 0.9999999999999997 and the chart points is
	-- 6500, then 6500 * 0.9999999999999997 = 6499.99999999999805, where
	-- flooring would give us 6499 which is wrong.
	local roundPlaces = function(x, places)
		local factor = 10 ^ places
		return math.floor(x * factor + 0.5) / factor
	end

	local percent = roundPlaces((first + second) / 100.0, 6)
	return math.floor(maxPoints * percent)
end

return Def.ActorFrame{
	Name="StepArtistAF_" .. pn,

	-- song and course changes
	OnCommand=function(self) self:queuecommand("Reset") end,
	["CurrentSteps"..pn.."ChangedMessageCommand"]=function(self) self:queuecommand("Reset") end,
	CurrentSongChangedMessageCommand=function(self) self:queuecommand("Reset") end,
	CurrentCourseChangedMessageCommand=function(self) self:queuecommand("Reset") end,

	PlayerJoinedMessageCommand=function(self, params)
		if params.Player == player then
			self:queuecommand("Appear" .. pn)
		end
	end,

	-- Simply Love doesn't support player unjoining (that I'm aware of!) but this
	-- animation is left here as a reminder to a future me to maybe look into it.
	PlayerUnjoinedMessageCommand=function(self, params)
		if params.Player == player then
			self:accelerate(0.1):zoomy(0.6):decelerate(0.2):zoomy(1):accelerate(0.2):sleep(0.2):zoomy(0):visible(false)
		end
	end,

	-- depending on the value of pn, this will either become
	-- an AppearP1Command or an AppearP2Command when the screen initializes
	["Appear"..pn.."Command"]=function(self) self:visible(true):zoomy(0):sleep(0.2):accelerate(0.2):zoomy(1):decelerate(0.2):zoomy(0.6):accelerate(0.1):zoomy(1) end,

	InitCommand=function(self)
		self:visible( false ):halign( p )

		-- P1 and P2 actorframe coords differ because the background element gets rotated for P2
		if GAMESTATE:IsCourseMode() then
			if player == PLAYER_1 then
				self:x( _screen.cx - (IsUsingWideScreen() and 356 or 346))
				self:y(_screen.cy + 2)
			else
				self:x( _screen.cx - (IsUsingWideScreen() and 356 or 355))
				self:y(_screen.cy + 122)
			end
		else
			if player == PLAYER_1 then
				self:x( _screen.cx - (IsUsingWideScreen() and 356 or 347))
				self:y(_screen.cy - 18)
			else
				self:x( _screen.cx - (IsUsingWideScreen() and 356 or 356))
				self:y(_screen.cy + 70)
			end
		end

		if GAMESTATE:IsHumanPlayer(player) then
			self:queuecommand("Appear" .. pn)
		end
	end,

	-- background
	Def.ActorMultiVertex{
		InitCommand=function(self)
			-- don't set verts in InitCommand because late joining will not reset the dimensions of this element belonging to the first joined player
			self:diffuse(GetCurrentColor())
			self:zoom(0.5)
			self:queuecommand("Reset")
		end,
		ResetCommand=function(self)
			local StepsOrTrail = GAMESTATE:IsCourseMode() and GAMESTATE:GetCurrentTrail(player) or GAMESTATE:GetCurrentSteps(player)
			if StepsOrTrail then
				local difficulty = StepsOrTrail:GetDifficulty()
				self:diffuse( DifficultyColor(difficulty) )
			else
				self:diffuse( PlayerColor(player) )
			end

			-- these coordinates aren't neat and tidy, but they do create three triangles
			-- that fit together to approximate hurtpiggypig's original png asset

			-- use different sets of verts for each size variant of this element; this is far better than conditionally warping the element
			-- maxtrix numerical coordinates differ in the different elements below

			-- coordinates at matrix spot explanation: IsUsingWideScreen() addition adds length, -104 changes the height, and +14 moves the "carrot" to under "STEPS"
			local SingleHumanPlayerVerts = {
				--   x   y  z    r,g,b,a
				{{-113, -104, 0}, {1,1,1,1}},
				{{ (IsUsingWideScreen() and 113+346 or 113+328), -104, 0}, {1,1,1,1}},
				{{ (IsUsingWideScreen() and 113+346 or 113+328), 16, 0}, {1,1,1,1}},
				{{ (IsUsingWideScreen() and 113+346 or 113+328), 16, 0}, {1,1,1,1}},
				{{-113, 16, 0}, {1,1,1,1}},
				{{-113, -104, 0}, {1,1,1,1}},
				{{ -98+14, 16, 0}, {1,1,1,1}},
				{{ -78+14, 16, 0}, {1,1,1,1}},
				{{ -88+14, 29, 0}, {1,1,1,1}},
			}

			local VersusModeVerts = {
				--   x   y  z    r,g,b,a
				{{-113, -26, 0}, {1,1,1,1}},
				{{ (IsUsingWideScreen() and 113+346 or 113+328), -26, 0}, {1,1,1,1}},
				{{ (IsUsingWideScreen() and 113+346 or 113+328), 16, 0}, {1,1,1,1}},
				{{ (IsUsingWideScreen() and 113+346 or 113+328), 16, 0}, {1,1,1,1}},
				{{-113, 16, 0}, {1,1,1,1}},
				{{-113, -26, 0}, {1,1,1,1}},
				{{ -98+18, 16, 0}, {1,1,1,1}},
				{{ -78+18, 16, 0}, {1,1,1,1}},
				{{ -88+18, 29, 0}, {1,1,1,1}},
			}

			local CourseModeVerts = {
				--   x   y  z    r,g,b,a
				{{-113, -15-17, 0}, {1,1,1,1}},
				{{ (IsUsingWideScreen() and 113+414 or 113+394), -15-17, 0}, {1,1,1,1}},
				{{ (IsUsingWideScreen() and 113+414 or 113+394), 16, 0}, {1,1,1,1}},
				{{ (IsUsingWideScreen() and 113+414 or 113+394), 16, 0}, {1,1,1,1}},
				{{-113, 16, 0}, {1,1,1,1}},
				{{-113, -15-17, 0}, {1,1,1,1}},
				{{ -98-15, 16, 0}, {1,1,1,1}},
				{{ -78-15, 16, 0}, {1,1,1,1}},
				{{ -88-15, 29, 0}, {1,1,1,1}},
			}


			if GAMESTATE:IsCourseMode() then
				self:SetDrawState({Mode="DrawMode_Triangles"}):SetVertices(CourseModeVerts)
				if player == PLAYER_1 then
					self:xy(82,0)
				else
					-- something is wrong here... DensityGraph and PaneDisplay are off
					-- since this UI will only be used in legacy 4:3 aspect ratio let's just be lazy and nudge things into the correct spot 
					-- without rotating this element about the y axis, there is a single pixel difference between P1 and P2 locations
					self:xy(289,-8)
					self:rotationy(180):rotationx(180)
				end
			else
				if #GAMESTATE:GetHumanPlayers() == 1 then
					self:SetDrawState({Mode="DrawMode_Triangles"}):SetVertices(SingleHumanPlayerVerts)
					if player == PLAYER_1 then
						self:xy(82,40)
					else
						-- something is wrong here... DensityGraph and PaneDisplay are off
						-- since this UI will only be used in legacy 4:3 aspect ratio let's just be lazy and nudge things into the correct spot 
						-- without rotating this element about the y axis, there is a single pixel difference between P1 and P2 locations
						self:xy(256,40)
						self:rotationy(180)
					end
				else
					self:SetDrawState({Mode="DrawMode_Triangles"}):SetVertices(VersusModeVerts)
					if player == PLAYER_1 then
						self:xy(82,1)
					else
						-- same comment as above *shrug*
						self:xy(256,1)
						self:rotationy(180)
					end
				end
			end
		end
	},

	--STEPS label
	LoadFont(ThemePrefs.Get("ThemeFont") .. " Normal")..{
		Text=GAMESTATE:IsCourseMode() and Screen.String("SongNumber"):format(1) or Screen.String("STEPS"),
		InitCommand=function(self)
			self:diffuse(0,0,0,1):maxwidth(40):zoom(0.8):y(-2)
			if GAMESTATE:IsCourseMode() then
				self:y(-4)
				if player == PLAYER_1 then
					self:horizalign(left):x(30)
				else
					self:horizalign(right):x(340)
				end
			else
				if player == PLAYER_1 then
					self:horizalign(left):x(30)
				else
					self:horizalign(right):x(306)
				end
			end
		end,
		UpdateTrailTextMessageCommand=function(self, params)
			self:settext( THEME:GetString("ScreenSelectCourse", "SongNumber"):format(params.index) )
		end
	},

	--stepartist text
	LoadFont(ThemePrefs.Get("ThemeFont") .. " Normal")..{
		InitCommand=function(self)
			-- if we don't set vertalign here, latejoining will cause the text to be center aligned until a ResetCommand is initiated (by changing the selected song)
			-- there's nothing to lose here by just Top_Aligning all text and just changing the y-positions to match
			self:zoom(0.8):diffuse(color("#000000")):vertalign("VertAlign_Top")
			self:queuecommand("Reset")
		end,
		ResetCommand=function(self)

			local SongOrCourse = GAMESTATE:IsCourseMode() and GAMESTATE:GetCurrentCourse() or GAMESTATE:GetCurrentSong()
			local StepsOrTrail = GAMESTATE:IsCourseMode() and GAMESTATE:GetCurrentTrail(player) or GAMESTATE:GetCurrentSteps(player)

			-- always stop tweening when steps change in case a MarqueeCommand is queued
			self:stoptweening()

			self:maxwidth(WideScale(278,292)):y(-8)
			if GAMESTATE:IsCourseMode() then
				self:y(-10):maxwidth(350)
				if player == PLAYER_1 then
					self:horizalign(left):x(50)
				else
					self:horizalign(right):x(320)
				end
			else
				if player == PLAYER_1 then
					self:horizalign(left):x(70)
				else
					self:horizalign(right):x(266)
				end
			end

			if SongOrCourse and StepsOrTrail then

				text_table = GetStepsCredit(player)
				marquee_index = 0

				-- don't queue a Marquee in CourseMode
				-- each TrailEntry text change will be broadcast from CourseContentsList.lua
				-- to ensure it stays synced with the scrolling list of songs
				if not GAMESTATE:IsCourseMode() then
					-- only queue a Marquee if there are things in the text_table to display

					if #text_table > 0 then
						if #GAMESTATE:GetHumanPlayers() > 1 and not GAMESTATE:GetCurrentSteps(player):IsAutogen() then self:queuecommand("Marquee") end
						local fulldesc = ""
						for i=1,#text_table do
							local curText = text_table[i]
							fulldesc = fulldesc .. curText .. "\n"
						end
						self:settext(fulldesc)
						DiffuseEmojis(self, fulldesc)
						if GAMESTATE:GetCurrentSteps(player):IsAutogen() then
							self:settext(THEME:GetString("ScreenSelectMusic", "AUTOGEN"))
							DiffuseEmojis(self)
						end
					else
						-- no credit information was specified in the simfile for this stepchart, so just set to an empty string
						self:settext("")
					end
				end
			else
				-- there wasn't a song/course or a steps object, so the MusicWheel is probably hovering
				-- on a group title, which means we want to set the stepartist text to an empty string for now
				self:settext("")
			end
		end,
		ITLCommand=function(self)
			if #GAMESTATE:GetHumanPlayers() == 1 then
				local SongOrCourse = GAMESTATE:IsCourseMode() and GAMESTATE:GetCurrentCourse() or GAMESTATE:GetCurrentSong()
				local StepsOrTrail = GAMESTATE:IsCourseMode() and GAMESTATE:GetCurrentTrail(player) or GAMESTATE:GetCurrentSteps(player)

				-- always stop tweening when steps change in case a MarqueeCommand is queued
				self:stoptweening()

				if SongOrCourse and StepsOrTrail then

					text_table = GetStepsCredit(player)
					marquee_index = 0

					-- don't queue a Marquee in CourseMode
					-- each TrailEntry text change will be broadcast from CourseContentsList.lua
					-- to ensure it stays synced with the scrolling list of songs
					if not GAMESTATE:IsCourseMode() then
						-- only queue a Marquee if there are things in the text_table to display
						if #text_table > 0 then
							-- self:queuecommand("Marquee")
							local fulldesc = ""
							for i=1,#text_table do
							local curText = text_table[i]
							if string.sub(curText, string.len(curText) - 3, string.len(curText)) == " pts" then
								local max_points = tonumber(string.sub(curText, 1, string.len(curText) - 4))
								local itlScore = tonumber(SL[pn].itlScore)
								if itlScore and max_points and max_points > 0 then
									local exscore = itlScore / 100
									local points = GetPointsForSong(max_points, exscore)
									local pointsPercent = string.format("%.2f%%", points / max_points * 100)
									curText = points .. "/" .. curText .. " ("..pointsPercent..")"
								end
							end
								fulldesc = fulldesc .. curText .. "\n"
							end
							self:settext(fulldesc)
							DiffuseEmojis(self, fulldesc)
							if GAMESTATE:GetCurrentSteps(player):IsAutogen() then
								self:settext(THEME:GetString("ScreenSelectMusic", "AUTOGEN"))
								DiffuseEmojis(self)
							end
						else
							-- no credit information was specified in the simfile for this stepchart, so just set to an empty string
							self:settext("")
						end
					end
				else
					-- there wasn't a song/course or a steps object, so the MusicWheel is probably hovering
					-- on a group title, which means we want to set the stepartist text to an empty string for now
					self:settext("")
				end
			end
		end,
		-- MarqueeCommand doesn't get queued if the Current Song is Autogenerated
		MarqueeCommand=function(self)
			-- increment the marquee_index, and keep it in bounds
			marquee_index = (marquee_index % #text_table) + 1
			-- retrieve the text we want to display
			local text = text_table[marquee_index]

			-- set this BitmapText actor to display that text
			self:settext( text )

			-- check for emojis; they shouldn't be diffused to Color.Black
			DiffuseEmojis(self, text)

			if not GAMESTATE:IsCourseMode() then
				-- sleep 2 seconds before queueing the next Marquee command to do this again
				if #text_table > 1 then
					self:sleep(2):queuecommand("Marquee")
				end
			else
				self:sleep(0.5):queuecommand("m")
			end
		end,
		UpdateTrailTextMessageCommand=function(self, params)
			if text_table then
				self:settext( text_table[params.index] or "" )
				DiffuseEmojis(self, fulldesc)
			end
		end,
		OffCommand=function(self) self:stoptweening() end
	}
}
