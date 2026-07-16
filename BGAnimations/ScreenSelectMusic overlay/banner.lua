local path = "/"..THEME:GetCurrentThemeDirectory().."Graphics/_FallbackBanners/"..ThemePrefs.Get("VisualStyle")
local banner_directory = FILEMAN:DoesFileExist(path) and path or THEME:GetPathG("","_FallbackBanners/Arrows")

local stable_delay = 0.12
local function GetSongOrCourse()
	return GAMESTATE:IsCourseMode() and GAMESTATE:GetCurrentCourse() or GAMESTATE:GetCurrentSong()
end

local bannerWidth = 418
local bannerHeight = 164

local t = Def.ActorFrame{
	OnCommand=function(self)
		if IsUsingWideScreen() then
			self:zoom(0.7655)
			self:xy(_screen.cx - 170, 96)
		else
			self:zoom(0.75)
			self:xy(_screen.cx - 166, 96)
		end
	end
}

-- fallback banner
local last_group_banner_path = ""
t[#t+1] = Def.Sprite{
	Name="FallbackBanner",
	Texture=banner_directory.."/banner"..SL.Global.ActiveColorIndex.." (doubleres).png",
	InitCommand=function(self) self:setsize(bannerWidth, bannerHeight) end,

	PreviousSongMessageCommand=function(self) self.PendingSongOrCourse = nil; self:stoptweening():visible(true) end,
	NextSongMessageCommand=function(self) self.PendingSongOrCourse = nil; self:stoptweening():visible(true) end,
	SwitchFocusToGroupsMessageCommand=function(self) self.PendingSongOrCourse = nil; self:stoptweening():visible(true) end,
	CurrentSongChangedMessageCommand=function(self) self:playcommand("QueueSet") end,
	CurrentCourseChangedMessageCommand=function(self) self:playcommand("QueueSet") end,

	QueueSetCommand=function(self)
		self.PendingSongOrCourse = GetSongOrCourse()
		if not self.PendingSongOrCourse then
			self:stoptweening():visible(true)
			return
		end
		self:stoptweening()
		self:sleep(stable_delay)
		self:queuecommand("Set")
	end,

	SetCommand=function(self)
		SL.SelectMusicTelemetry:Pulse("normal.banner.fallback.set")
		local SongOrCourse = GetSongOrCourse()
		if not SongOrCourse then
			self:visible(true)
			return
		end
		if self.PendingSongOrCourse and SongOrCourse ~= self.PendingSongOrCourse then
			self:visible(false)
			return
		end
		-- if ShowBanners preference is false, always just show the fallback banner
		-- don't bother assessing whether to draw or not draw
		if PREFSMAN:GetPreference("ShowBanners") == false then
			self:visible(true)
			return
		end

		if SongOrCourse and SongOrCourse:HasBanner() then
			self:visible(false)
		else
			self:visible(true)
		end
	end
}

t[#t+1] = Def.Sprite{
	Name="GroupBanner",
	OnCommand=function(self) self:setsize(418,164):visible(false):playcommand("Set") end,
	PreviousSongMessageCommand=function(self) self.PendingSongOrCourse = nil; self:stoptweening():visible(false) end,
	NextSongMessageCommand=function(self) self.PendingSongOrCourse = nil; self:stoptweening():visible(false) end,
	SwitchFocusToGroupsMessageCommand=function(self) self.PendingSongOrCourse = nil; self:stoptweening():visible(false) end,
	CurrentSongChangedMessageCommand=function(self) self:playcommand("QueueSet") end,
	CurrentCourseChangedMessageCommand=function(self) self:playcommand("QueueSet") end,
	QueueSetCommand=function(self)
		self.PendingSongOrCourse = GetSongOrCourse()
		if not self.PendingSongOrCourse then
			self:stoptweening():visible(false)
			return
		end
		SL.SelectMusicTelemetry:Pulse("normal.banner.group.queue")
		self:stoptweening()
		self:sleep(stable_delay)
		self:queuecommand("Set")
	end,
	SetCommand=function(self)
		SL.SelectMusicTelemetry:Pulse("normal.banner.group.set")
		local SongOrCourse = GetSongOrCourse()
		if self.PendingSongOrCourse and SongOrCourse ~= self.PendingSongOrCourse then
			return
		end
		local group_banner_path = ""
		if SongOrCourse and not SongOrCourse:HasBanner() then
			group_banner_path = GetGroupBanner() or ""
		end
		if group_banner_path ~= "" then
			if group_banner_path ~= last_group_banner_path then
				self:Load(group_banner_path)
				last_group_banner_path = group_banner_path
			end
			self:setsize(418,164);
			self:visible(true);
		else
			self:visible(false);
		end
	end,
}

if PREFSMAN:GetPreference("ShowBanners") then
	t[#t+1] = Def.ActorProxy{
		Name="BannerProxy",
		OnCommand=cmd(setsize,418,164),
		BeginCommand=function(self)
			local banner = SCREENMAN:GetTopScreen():GetChild('Banner')
			self:SetTarget(banner)
		end
	}
end

-- the MusicRate Quad and text
t[#t+1] = Def.ActorFrame{
	InitCommand=function(self)
		self:visible( SL.Global.ActiveModifiers.MusicRate ~= 1 ):y(75)
	end,

	--quad behind the music rate text
	Def.Quad{
		InitCommand=function(self) self:diffuse( color("#1E282FCC") ):zoomto(418,14) end
	},

	--the music rate text
	LoadFont(ThemePrefs.Get("ThemeFont") .. " Normal")..{
		InitCommand=function(self) self:shadowlength(1):zoom(0.85) end,
		OnCommand=function(self)
			self:settext(("%g"):format(SL.Global.ActiveModifiers.MusicRate) .. "x " .. THEME:GetString("OptionTitles", "MusicRate"))
		end
	}
}

if not GAMESTATE:IsCourseMode() and ThemePrefs.Get("ShowCDTitles") then
	local last_cdtitle_path = ""
	t[#t+1] = Def.Sprite {
		Name="CdTitle",
		OnCommand=function(self)
			self:draworder(101)
			self:playcommand("SetCD")
		end,
		OffCommand=function(self)
			self:bouncebegin(0.15)
		end,
		PreviousSongMessageCommand=function(self) self.PendingSongOrCourse = nil; self:stoptweening():visible(false) end,
		NextSongMessageCommand=function(self) self.PendingSongOrCourse = nil; self:stoptweening():visible(false) end,
		CurrentSongChangedMessageCommand=function(self) self:playcommand("QueueSetCD") end,
		SwitchFocusToGroupsMessageCommand=function(self) self.PendingSongOrCourse = nil; self:stoptweening():visible(false) end,
		QueueSetCDCommand=function(self)
			self.PendingSongOrCourse = GetSongOrCourse()
			if not self.PendingSongOrCourse then
				self:stoptweening():visible(false)
				return
			end
			SL.SelectMusicTelemetry:Pulse("normal.cdtitle.queue")
			self:stoptweening()
			self:sleep(stable_delay)
			self:queuecommand("SetCD")
		end,
		SetCDCommand=function(self)
			SL.SelectMusicTelemetry:Pulse("normal.cdtitle.set")
			local SongOrCourse = GetSongOrCourse()
			if self.PendingSongOrCourse and SongOrCourse ~= self.PendingSongOrCourse then
				return
			end
			if SongOrCourse and SongOrCourse:HasCDTitle() then
				self:visible(true)
				local cdtitle_path = SongOrCourse:GetCDTitlePath()
				if cdtitle_path ~= last_cdtitle_path then
					self:Load(cdtitle_path)
					last_cdtitle_path = cdtitle_path
				end
				local dim1, dim2 = math.max(self:GetWidth(), self:GetHeight()), math.min(self:GetWidth(), self:GetHeight())
				if dim2 <= 0 then
					self:visible(false)
					return
				end
				local ratio = math.max(dim1 / dim2, 2.5)

				local toScale = self:GetWidth() > self:GetHeight() and self:GetWidth() or self:GetHeight()
				if toScale <= 0 then
					self:visible(false)
					return
				end
				self:xy((bannerWidth - 30) / 2, (bannerHeight - 30)/ 2)
				self:zoom(22 / toScale * ratio)
				self:finishtweening():addrotationy(0):linear(.5):addrotationy(360)
			else
				self:visible(false)
			end
		end
	}
end

return t
