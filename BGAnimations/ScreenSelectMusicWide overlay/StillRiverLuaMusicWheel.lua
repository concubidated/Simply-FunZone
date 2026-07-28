local row_count = 9
local row_spacing = _screen.h / 15
local center_row = math.floor(row_count / 2) + 1
local item_width = _screen.w / 2.125
local row_height = _screen.h / 15
local wheel_x = _screen.cx - 186
local wheel_y = _screen.cy + 98
local grade_refresh_delay = (THEME:GetMetric("ScreenSelectMusic", "NotefieldPreviewDelay") or 0.35) + 0.05
local grade_refresh_enabled = true

local num_grade_tiers = THEME:GetMetric("PlayerStageStats", "NumGradeTiersUsed")
local grade_states = {}
for i = 1, num_grade_tiers do
	grade_states[("Grade_Tier%02d"):format(i)] = i - 1
end
grade_states["Grade_Failed"] = num_grade_tiers

local function type_matches(value, short)
	if not value then return false end
	return value == short or value == "MusicWheelItemType_" .. short or value == "WheelItemDataType_" .. short
end

local function item_is_song(item)
	return type_matches(item.WheelItemDataType, "Song") or type_matches(item.Type, "Song")
end

local function item_is_course(item)
	return type_matches(item.WheelItemDataType, "Course") or type_matches(item.Type, "Course")
end

local function item_is_section(item)
	return type_matches(item.WheelItemDataType, "Section")
		or type_matches(item.Type, "SectionExpanded")
		or type_matches(item.Type, "SectionCollapsed")
		or type_matches(item.Type, "FavoriteExpanded")
		or type_matches(item.Type, "FavoriteCollapsed")
end

local function hide_child(parent, name)
	local child = parent:GetChild(name)
	if child then child:visible(false) end
end

local function queue_grade_refresh(actor)
	if not grade_refresh_enabled then return end
	local timer = actor:GetChild("GradeRefreshTimer")
	if timer then timer:playcommand("QueueRefreshGrades") end
end

local function item_cache_key(item)
	if not item or not (item_is_song(item) or item_is_course(item)) or item.Index == nil then
		return nil
	end
	return tostring(item.Index) .. ":" .. (item.WheelItemDataType or item.Type or "")
end

local function set_item_text(actor, item)
	local text = item.DisplayText or item.Text or item.Label or ""
	if item_is_song(item) then
		text = item.MainTitle or text
	end
	actor:settext(text)
	if item_is_song(item) then
		actor:diffuse(ThemePrefs.Get("RainbowMode") and color("#0a141b") or Color.White)
		if item.MainTitle == "DVNO" then actor:diffuse(1, 0.8, 0, 1) end
	elseif item.Color then
		actor:diffuse(item.Color)
	end
end

local function set_grade_sprite(actor, item, field)
	if not item or not (item_is_song(item) or item_is_course(item)) or not item[field] then
		actor.LastGradeState = nil
		actor:visible(false)
		return
	end

	local state = grade_states[item[field]]
	if not state then
		actor.LastGradeState = nil
		actor:visible(false)
		return
	end

	if actor.LastGradeState ~= state then
		actor:setstate(state)
		actor.LastGradeState = state
	end
	actor:visible(true)
end

local function set_cached_grade_sprites(row, item)
	local key = item_cache_key(item)
	if not key then
		hide_child(row, "GradeP1")
		hide_child(row, "GradeP2")
		return
	end

	local cache = row:GetParent().GradeCache
	local cached = cache and cache[key]
	if not cached then
		hide_child(row, "GradeP1")
		hide_child(row, "GradeP2")
		return
	end

	set_grade_sprite(row:GetChild("GradeP1"), cached, "GradeP1")
	set_grade_sprite(row:GetChild("GradeP2"), cached, "GradeP2")
end

local function set_stage_marker(actor, item)
	if not item or not item_is_song(item) or not item.StagesForSong or item.StagesForSong <= 1 then
		if actor.LastStageMarker then
			actor:settext("")
			actor.LastStageMarker = nil
		end
		actor:visible(false)
		return
	end

	local marker = item.StagesForSong >= 3 and "MARATHON" or "LONG SONG"
	if actor.LastStageMarker ~= marker then
		actor:settext(marker)
		actor:diffuse(item.StagesForSong >= 3 and color("#ff7ace") or color("#85f7ff"))
		actor.LastStageMarker = marker
	end
	actor:visible(true)
end

local function update_row(self, item)
	hide_child(self, "Focus")
	hide_child(self, "FocusEdge")
	hide_child(self, "HasEdit")

	if not item then
		hide_child(self, "GradeP1")
		hide_child(self, "GradeP2")
		hide_child(self, "StageMarker")
		self:visible(false)
		return
	end

	self:visible(true)
	self:GetChild("RowOuter"):visible(true)
	self:GetChild("RowInner"):visible(true)
	self:GetChild("HasEdit"):visible((item_is_song(item) or item_is_course(item)) and item.HasEdits and true or false)
	self:GetChild("Focus"):visible(item.HasFocus and true or false)
	self:GetChild("FocusEdge"):visible(item.HasFocus and true or false)
	self:GetChild("Title"):playcommand("SetStillRiverWheelText", item)
	self:GetChild("SectionCount"):playcommand("SetStillRiverWheelText", item)
	set_cached_grade_sprites(self, item)
	self:GetChild("StageMarker"):playcommand("SetStillRiverWheelStageMarker", item)
end

local function make_row(index)
	return Def.ActorFrame{
		Name="Row" .. index,
		InitCommand=function(self)
			self:y((index - center_row) * row_spacing)
		end,
		SetStillRiverWheelItemCommand=function(self, item)
			update_row(self, item)
		end,

		Def.Quad{
			Name="RowOuter",
			InitCommand=function(self)
				self:horizalign(left):x(WideScale(28, 33)):zoomto(item_width, row_height)
					:diffuse(color("#000000")):diffusealpha(0.85)
			end,
		},

		Def.Quad{
			Name="RowInner",
			InitCommand=function(self)
				self:horizalign(left):x(WideScale(28, 33)):zoomto(item_width, row_height - 1)
					:diffuse(color("#0a141b")):diffusealpha(0.95)
				if ThemePrefs.Get("VisualStyle") == "SRPG8" or ThemePrefs.Get("VisualStyle") == "Technique" then
					self:diffusealpha(0.5)
				end
			end,
		},

		Def.Quad{
			Name="Focus",
			InitCommand=function(self)
				self:horizalign(left):x(WideScale(28, 33)):zoomto(item_width, row_height - 1)
					:diffuse(color("#f240b0")):diffusealpha(0.35):visible(false)
			end,
		},

		Def.Quad{
			Name="FocusEdge",
			InitCommand=function(self)
				self:horizalign(left):x(WideScale(28, 33)):zoomto(4, row_height - 1)
					:diffuse(color("#ff7ace")):diffusealpha(0.95):visible(false)
			end,
		},

		Def.Sprite{
			Name="GradeP1",
			Texture=THEME:GetPathG("MusicWheelItem","Grades/grades 1x18.png"),
			InitCommand=function(self)
				self:x(WideScale(50, 64)):y(-1):zoom(SL_WideScale(0.18, 0.3)):animate(false):visible(false)
			end,
			SetStillRiverWheelGradeCommand=function(self, item)
				set_grade_sprite(self, item, "GradeP1")
			end,
		},

		Def.Sprite{
			Name="GradeP2",
			Texture=THEME:GetPathG("MusicWheelItem","Grades/grades 1x18.png"),
			InitCommand=function(self)
				self:x(WideScale(70, 88)):y(-1):zoom(SL_WideScale(0.18, 0.3)):animate(false):visible(false)
			end,
			SetStillRiverWheelGradeCommand=function(self, item)
				set_grade_sprite(self, item, "GradeP2")
			end,
		},

		LoadFont(ThemePrefs.Get("ThemeFont") .. " Normal")..{
			Name="StageMarker",
			InitCommand=function(self)
				self:horizalign(right):x(_screen.w / 2 - WideScale(58, 68)):zoom(0.42):visible(false)
			end,
			SetStillRiverWheelStageMarkerCommand=function(self, item)
				set_stage_marker(self, item)
			end,
		},

		Def.Sprite{
			Name="HasEdit",
			Texture=THEME:GetPathG("", "Has Edit (doubleres).png"),
			InitCommand=function(self)
				self:horizalign(left):visible(false):zoom(0.375)
				self:x(_screen.w/WideScale(2.19, 2.125) - self:GetWidth()*self:GetZoom())
			end,
		},

		LoadFont(ThemePrefs.Get("ThemeFont") .. " Normal")..{
			Name="Title",
			InitCommand=function(self)
				self:horizalign(left):x(WideScale(75, 111)):maxwidth(WideScale(245, 340)):zoom(0.85)
					:diffuse(Color.White)
			end,
			SetStillRiverWheelTextCommand=function(self, item)
				if not item then
					self:settext("")
					return
				end
				set_item_text(self, item)
			end,
		},

		LoadFont(ThemePrefs.Get("ThemeFont") .. " Normal")..{
			Name="SectionCount",
			InitCommand=function(self)
				self:horizalign(right):x(_screen.w / 2 - WideScale(9, 10)):zoom(0.75)
			end,
			SetStillRiverWheelTextCommand=function(self, item)
				if not item or not item_is_section(item) or not item.SectionCount or item.SectionCount <= 0 then
					self:settext("")
					return
				end
				self:settext(tostring(item.SectionCount))
				self:playcommand("Set")
			end,
		},
	}
end

local af = Def.ActorFrame{
	Name="StillRiverLuaMusicWheel",
	InitCommand=function(self)
		self.GradeCache = {}
		self:x(wheel_x):y(wheel_y):zoom(0.796):zoomy(0.772)
	end,
	OnCommand=function(self)
		self:queuecommand("Refresh")
	end,
	RefreshCommand=function(self)
		local screen = SCREENMAN:GetTopScreen()
		if not screen then
			self:visible(false)
			return
		end

		local got_wheel, wheel = pcall(function() return screen:GetMusicWheel() end)
		if not got_wheel or not wheel then
			self:visible(false)
			return
		end

		local got_items, items = pcall(function() return wheel:GetVisibleItemData(row_count) end)
		if not got_items then
			self:visible(false)
			return
		end

		for i = 1, row_count do
			local row = self:GetChild("Row" .. i)
			if row then
				row:playcommand("SetStillRiverWheelItem", items and items[i] or nil)
			end
		end
	end,
	ApplyGradeRefreshCommand=function(self)
		if not grade_refresh_enabled then return end

		local screen = SCREENMAN:GetTopScreen()
		if not screen then return end

		local got_wheel, wheel = pcall(function() return screen:GetMusicWheel() end)
		if not got_wheel or not wheel then return end

		if not wheel.GetVisibleGradeData then return end

		local got_items, items = pcall(function() return wheel:GetVisibleGradeData(row_count) end)
		if not got_items or not items then return end

		for i = 1, row_count do
			local row = self:GetChild("Row" .. i)
			local item = items[i]
			if row then
				local key = item_cache_key(item)
				if key then
					self.GradeCache[key] = { GradeP1=item.GradeP1, GradeP2=item.GradeP2, Type=item.Type, WheelItemDataType=item.WheelItemDataType }
				end
				row:GetChild("GradeP1"):playcommand("SetStillRiverWheelGrade", item)
				row:GetChild("GradeP2"):playcommand("SetStillRiverWheelGrade", item)
			end
		end
	end,
	CurrentSongChangedMessageCommand=function(self) self:queuecommand("Refresh"); queue_grade_refresh(self) end,
	PreviousSongMessageCommand=function(self) self:queuecommand("Refresh"); queue_grade_refresh(self) end,
	NextSongMessageCommand=function(self) self:queuecommand("Refresh"); queue_grade_refresh(self) end,
	MusicWheelItemsChangedMessageCommand=function(self) self.GradeCache = {}; self:queuecommand("Refresh") end,
	SortOrderChangedMessageCommand=function(self) self.GradeCache = {}; self:queuecommand("Refresh") end,
	SortOrderChangingMessageCommand=function(self) self.GradeCache = {}; self:queuecommand("Refresh") end,
	CurrentStepsP1ChangedMessageCommand=function(self) self:queuecommand("Refresh"); queue_grade_refresh(self) end,
	CurrentStepsP2ChangedMessageCommand=function(self) self:queuecommand("Refresh"); queue_grade_refresh(self) end,
	PlayerJoinedMessageCommand=function(self) self:queuecommand("Refresh") end,
	PlayerUnjoinedMessageCommand=function(self) self:queuecommand("Refresh") end,

	Def.Actor{
		Name="GradeRefreshTimer",
		QueueRefreshGradesCommand=function(self)
			self:stoptweening()
			self:sleep(grade_refresh_delay)
			self:queuecommand("RefreshGrades")
		end,
		RefreshGradesCommand=function(self)
			self:GetParent():queuecommand("ApplyGradeRefresh")
		end,
	},
}

for i = 1, row_count do
	af[#af+1] = make_row(i)
end

return af
