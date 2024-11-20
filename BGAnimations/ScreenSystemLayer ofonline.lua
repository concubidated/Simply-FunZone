-- README: ScreenSystemLayer does not support OnCommands
local t = Def.ActorFrame{}

local scoresubmitted = THEME:GetString("ScreenSystemLayer","OFOnlineScoreSent")
local profilesynced = THEME:GetString("ScreenSystemLayer","OFOnlineProfileSynced")
local profilefailSync = THEME:GetString("ScreenSystemLayer","OFOnlineProfileFailSync")
local connectedtoserver = THEME:GetString("ScreenSystemLayer","OFOnlineConnectedToServer")
local errormessage = THEME:GetString("ScreenSystemLayer","OFOnlineErrorMessage")
local scoresavetimeout = THEME:GetString("ScreenSystemLayer","OFScoreSaveTimeout")

local function getStartScreenPos()
	if SCREENMAN:GetTopScreen():GetName() == "ScreenEvaluationStage" then
		return SCREEN_BOTTOM + 20
	else
		return SCREEN_TOP - 20
	end
end

local function getAnimateToScreenPos()
	if SCREENMAN:GetTopScreen():GetName() == "ScreenEvaluationStage" then
		return SCREEN_BOTTOM - 13
	else
		return (SCREEN_TOP + (SCREEN_TOP + 17))
	end
end

-- animation commands must be activated by a MessageCommand because of how ScreenSystemLayer works in-engine
-- ScreenSystemLayer is immediately drawn when the game booted and persists while game is booted; InitCommand function items are run ONCE at system startup and persist
-- use a MessageCommand to activate animations at key moments because ScreenChangedCommand doesn't work for this persistent screen type

-- header background is intended to only show on screens where a _header is shown
-- at the current time, ScreenEvaluation doesn't use a _footer, so we don't need to show this element/animation on that screen
t[#t+1] = Def.ActorFrame{
	Def.Quad{
		InitCommand=function(self)
			local dark  = {0,0,0,0.9}
			local light = {0.65,0.65,0.65,1}
			
			if ThemePrefs.Get("VisualStyle") == "SRPG8" then
				self:diffuse(GetCurrentColor(true))
			elseif DarkUI() then
				self:diffuse(dark)
			else
				self:diffuse(light)
			end

			self:y(SCREEN_TOP + 16)
			-- initialize as transparent because will be called to turn translucent in the animation command below
			self:zoomto(_screen.w, 32):x(_screen.cx):diffusealpha(0)
		end,
		-- don't use custom MESSAGEMAN's corresponding MessageCommand here because it activates twice on ScreenTitleJoin/ScreenTitleMenu (doesn't match up with the child "Status")
		-- OFOnlineNotificationMessageCommand=function(self)
		MessageOFNetworkResponseMessageCommand=function(self)
			if SCREENMAN:GetTopScreen():GetName() == "ScreenProfileSave" then
				self:finishtweening():y( getStartScreenPos() ):easeoutexpo(0.75):diffusealpha(1):y( getAnimateToScreenPos() ):sleep(1.5):easeinexpo(0.75):diffusealpha(0)
			end
		end,
	}
}

for ind,plr in pairs(PlayerNumber) do

	t[#t+1] = Def.ActorFrame{
		InitCommand=function(self)
			local xPosSeparation = SAFE_WIDTH + WideScale(127,140)
			self:x( plr == PLAYER_1 and xPosSeparation or SCREEN_WIDTH - xPosSeparation )
			self:zoom(1 * (SCREEN_HEIGHT/480)):diffusealpha(0)
		end,
		ActionPlayCommand=function(self)
			-- don't use custom MESSAGEMAN here because it activates twice on ScreenTitleJoin/ScreenTitleMenu (doesn't match up with the child "Status")
			-- MESSAGEMAN:Broadcast("OFOnlineNotification")
			if SCREENMAN:GetTopScreen():GetName() == "ScreenEvaluationStage" then
				self:zoom(0.75 * (SCREEN_HEIGHT/480))
			end
			self:finishtweening():y( getStartScreenPos() ):easeoutexpo(0.75):diffusealpha(1):y( getAnimateToScreenPos() ):sleep(1.5):easeinexpo(0.75):diffusealpha(0)
		end,
		MessageOFNetworkResponseMessageCommand=function(self,params)
			if params.PlayerNumber == plr then
				local xPosSeparation = SAFE_WIDTH + WideScale(127,140)
				self:x( plr == PLAYER_1 and xPosSeparation or SCREEN_WIDTH - xPosSeparation)
				if params.Name == "ScoreSave" then
					if params.Status == "success" then
						self:GetChild("Status"):settext(scoresubmitted)
					else
						if params.Message == "TimeoutRetry" then
							self:GetChild("Status"):settext( scoresavetimeout )
						else 
							self:GetChild("Status"):settext( errormessage:format(params.Message) )
						end
					end
					self:playcommand("ActionPlay")
				end
				if params.Name == "ProfileSave" then
					self:GetChild("Status"):settext( params.StatusCode == 500 and profilefailSync or profilesynced )
					self:playcommand("ActionPlay")
				end
				self:GetChild("RemainingTime"):finishtweening():diffusealpha(1):cropright(0):linear(2.8):cropright(1):sleep(0):diffusealpha(0)
			end
			if params.Name == "MachineLogin" then
				self:x(SCREEN_CENTER_X)
				self:GetChild("Status"):settext(connectedtoserver)
				self:playcommand("ActionPlay")
			end
		end,

		--3px stroke
		Def.Quad{
			InitCommand=function(self)
				self:zoomto(370+3,25+3)
				if DarkUI() then
					self:diffuse(Color.White)
				else
					self:diffuse(Color.Black)
				end
			end
		},	

		-- text body background
		Def.Quad{
			InitCommand=function(self)
				self:zoomto(370,25):diffuse(ColorDarkTone(GetCurrentColor(true)))
			end
		},		
		
		-- icon body background
		Def.Quad{
			InitCommand=function(self)
				self:zoomto(45,25):diffuse(ColorLightTone(GetCurrentColor(true))):x(-163)
			end
		},

		-- OutFox Online Icon
		Def.Sprite{
			Texture=THEME:GetPathG("","OutFoxOnlineIcon.png"),
			Name="OutFoxOnlineIcon",
			InitCommand=function(self)
				self:x(-163):zoom(0.45)
			end,
		},

		-- status text
		Def.BitmapText{
			Font=ThemePrefs.Get("ThemeFont") .. " Normal",
			Name="Status",
			InitCommand=function(self)
				self:xy(21,-1):horizalign(center):maxwidth(300)
			end
		}
	}
end

return t