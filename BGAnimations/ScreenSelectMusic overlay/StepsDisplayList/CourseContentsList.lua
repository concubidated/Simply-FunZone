local numItemsToDraw = 8
local scrolling_down = true

local transform_function = function(self,offsetFromCenter,itemIndex,numitems)
	self:y( offsetFromCenter * 23 )
end

-- ccl is a reference to the CourseContentsList actor that this update function is called on
-- dt is "delta time" (time in seconds since the last frame); we don't need it here
local update = function(ccl, dt)

	-- CourseContentsList:GetCurrentItem() returns a float, so call math.floor() on it
	-- while it's scrolling down or math.ceil() while its scrolling up to do integer comparison.
	--
	-- if we've reached the bottom of the list and want the CCL to scroll up
	if math.floor(ccl:GetCurrentItem()) == (ccl:GetNumItems() - (numItemsToDraw/2)) then
		scrolling_down = false
		ccl:SetDestinationItem( 0 )

	-- elseif we've reached the top of the list and want the CCL to scroll down
	elseif math.ceil(ccl:GetCurrentItem()) == 0 then
		scrolling_down = true
		ccl:SetDestinationItem( math.max(0,ccl:GetNumItems() - numItemsToDraw/2) )

	end
end



local af = Def.ActorFrame{
	InitCommand=function(self)
		self:xy(_screen.cx-170, _screen.cy + 40)
	end,

	---------------------------------------------------------------------
	-- Masks (as used here) are just Quads that serve to hide the rows
	-- of the CourseContentsList above and below where we want to see them.
	-- To see what I mean, try commenting out the two calls to MaskSource()
	-- (one per Quad) and refreshing the screen.
	--
	-- Normally, we would also have to call MaskDest() on the thing we wanted to
	-- be hidden by the mask, but that is effectively already called on the
	-- entire "Display" ActorFrame of the CourseContentsList in the engine's code.

	-- lower mask
	Def.Quad{
		InitCommand=function(self)
			self:xy(IsUsingWideScreen() and -44 or 0,98)
				:zoomto(_screen.w/2, 40)
				:MaskSource()
		end
	},

	-- upper mask
	Def.Quad{
		InitCommand=function(self)
			self:vertalign(bottom)
				:xy(IsUsingWideScreen() and -44 or 0,-18)
				:zoomto(_screen.w/2, 100)
				:MaskSource()
		end
	},
	---------------------------------------------------------------------

	-- gray background Quad
	Def.Quad{
		InitCommand=function(self)
			self:diffuse(color("#1e282f")):zoomto(320, 96)
				:xy(0, 30)

			if ThemePrefs.Get("RainbowMode") then
				self:diffusealpha(0.75)
			end
		end
	},
}

af[#af+1] = Def.CourseContentsList {
	-- ???
	MaxSongs=1000,
	-- ???
	NumItemsToDraw=numItemsToDraw,

	CurrentTrailP1ChangedMessageCommand=function(self) self:playcommand("Set") end,
	CurrentTrailP2ChangedMessageCommand=function(self) self:playcommand("Set") end,

	InitCommand=function(self)
		self:xy(40,-4)
			:SetUpdateFunction( update )
	end,

	-- ???
	SetCommand=function(self)
		self:SetFromGameState()
			:SetCurrentAndDestinationItem(0)
			:SetTransformFromFunction(transform_function)
			:PositionItems()

			:SetLoop(false)
			:SetPauseCountdownSeconds(1)
			:SetSecondsPauseBetweenItems( 0.2 )

		if scrolling_down then
			self:SetDestinationItem( math.max(0,self:GetNumItems() - numItemsToDraw/2) )
		else
			self:SetDestinationItem( 0 )
		end
	end,

	-- a generic row in the CourseContentsList
	Display=Def.ActorFrame {
		SetSongCommand=function(self, params)
			self:finishtweening()
				:zoomy(0)
				:sleep(0.125*params.Number)
				:linear(0.125):zoomy(1)
				:linear(0.05):zoomx(1)
				:decelerate(0.1):zoom(0.875)
		end,

		-- song title
		Def.BitmapText{
			Font="_miso",
			InitCommand=function(self)
				self:xy(-160, 0)
					:horizalign(left)
					:maxwidth(240)
			end,
			SetSongCommand=function(self, params)
				if params.Song then
					self:settext( params.Song:GetDisplayFullTitle() )
				else
					self:SetFromString( "??????????", "??????????", "", "", "", "" )
				end
			end
		},

		-- PLAYER_1 song difficulty
		Def.BitmapText{
			Font="_miso",
			Text="",
			InitCommand=function(self)
				self:xy(-170, 0):horizalign(right)
			end,
			SetSongCommand=function(self, params)
				if params.PlayerNumber ~= PLAYER_1 then return end

				self:settext( params.Meter ):diffuse( CustomDifficultyToColor(params.Difficulty) )
			end
		},

		-- PLAYER_2 song difficulty
		Def.BitmapText{
			Font="_miso",
			Text="",
			InitCommand=function(self)
				self:xy(114,0):horizalign(right)
			end,
			SetSongCommand=function(self, params)
				if params.PlayerNumber ~= PLAYER_2 then return end

				self:settext( params.Meter ):diffuse( CustomDifficultyToColor(params.Difficulty) )
			end
		}
	}
}

return af