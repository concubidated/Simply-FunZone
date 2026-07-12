--Code based on Simply Fantasy by Poog which is based off Digital Dance by Aoreo

--if not ThemePrefs.Get("ShowCD") then return end

local t = Def.ActorFrame{}

local stable_delay = 0.12
local function GetSongOrCourse()
	return GAMESTATE:IsCourseMode() and GAMESTATE:GetCurrentCourse() or GAMESTATE:GetCurrentSong()
end

if not GAMESTATE:IsCourseMode() then
	local last_cdtitle_path = ""
    t[#t+1] = Def.ActorFrame {
        OnCommand= function(self)
            self:draworder(101)
            :x(_screen.cx)
            :y(SCREEN_CENTER_Y-150)
            :playcommand("SetCD")
        end,
        OffCommand= function(self)
            self:bouncebegin(0.15)
        end,
        PreviousSongMessageCommand=function(self)
            self:stoptweening()
            self:GetChild("CdTitle"):visible(false)
        end,
        NextSongMessageCommand=function(self)
            self:stoptweening()
            self:GetChild("CdTitle"):visible(false)
        end,
        CurrentSongChangedMessageCommand=function(self) self:playcommand("QueueSetCD") end,
        SwitchFocusToGroupsMessageCommand=function(self)
            self:stoptweening()
            self:GetChild("CdTitle"):visible(false)
        end,
        QueueSetCDCommand=function(self)
            self:stoptweening()
            self:sleep(stable_delay)
            self:queuecommand("SetCD")
        end,
        SetCDCommand=function(self)
			local SongOrCourse = GetSongOrCourse()
            local cdtitle = self:GetChild("CdTitle")
            if SongOrCourse and SongOrCourse:HasCDTitle() then
                cdtitle:visible(true)
                local cdtitle_path = SongOrCourse:GetCDTitlePath()
                if cdtitle_path ~= last_cdtitle_path then
                    cdtitle:Load(cdtitle_path)
                    last_cdtitle_path = cdtitle_path
                end
                local dim1, dim2=math.max(cdtitle:GetWidth(), cdtitle:GetHeight()), math.min(cdtitle:GetWidth(), cdtitle:GetHeight())
                if dim2 <= 0 then
                    cdtitle:visible(false)
                    return
                end
                local ratio=math.max(dim1/dim2, 2.5)
            
                local toScale = cdtitle:GetWidth() > cdtitle:GetHeight() and cdtitle:GetWidth() or cdtitle:GetHeight()
                if toScale <= 0 then
                    cdtitle:visible(false)
                    return
                end
                self:zoom(22/toScale * ratio)
                self:finishtweening():addrotationy(0):linear(.5):addrotationy(360):bounce()
			else
				cdtitle:visible(false)
			end
        end,
        Def.Sprite{
			Name="CdTitle",
		},
    }
end

return t
