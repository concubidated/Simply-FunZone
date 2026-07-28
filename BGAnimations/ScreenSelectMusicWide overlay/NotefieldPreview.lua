-- Majority of code borrowed from Mr. ThatKid and Sudospective; with much help from the OutFox discord.

local NotefieldRenderAfter = 0 --THEME:GetMetric("Player","DrawDistanceAfterTargetsPixels")
local PreviewDelay = THEME:GetMetric("ScreenSelectMusic", "NotefieldPreviewDelay") or 0.35
local MaxPreviewSongLengthSeconds = 15 * 60 -- don't decompress/show preview for songs longer than 15 minutes
local SinglePlayerPreviewYOffset = 240
local TwoPlayerPreviewYOffset = 180
local TwoPlayerProfilePreviewXOffset = 213
local TwoPlayerGuestPreviewXOffset = 293
local TwoPlayerProfilePreviewZoom = 0.4
local TwoPlayerGuestPreviewZoom = 1

local function GetCurrentPreviewSteps(pn, Song)
    local steps = GAMESTATE:GetCurrentSteps(pn)
    if not steps or not Song then return nil end

    local ChartArray = Song:GetAllSteps()
    if not ChartArray then return nil end

    for i=1,#ChartArray do
        if steps == ChartArray[i] then
            return steps, i
        end
    end

    return nil
end

local function GetPreviewRefreshIdentity(pn)
    local Song = GAMESTATE:GetCurrentSong()
    local steps = Song and GAMESTATE:GetCurrentSteps(pn) or nil
    return Song, steps
end

local function SamePendingPreview(actor, Song, steps)
    return actor.RefreshPending
        and actor.PendingSong == Song
        and actor.PendingSteps == steps
end

local function SetPendingPreview(actor, Song, steps)
    actor.RefreshPending = true
    actor.PendingSong = Song
    actor.PendingSteps = steps
end

local function ClearPendingPreview(actor)
    actor.RefreshPending = false
    actor.PendingSong = nil
    actor.PendingSteps = nil
end

local PreviewModsLevels = { "ModsLevel_Stage", "ModsLevel_Song", "ModsLevel_Current" }

local function ApplyPreviewOptions(actor, pn)
    local PlayerModsArray = GAMESTATE:GetPlayerState(pn):GetPlayerOptionsString("ModsLevel_Preferred")
    for _, mods_level in ipairs(PreviewModsLevels) do
        local options = actor:GetPlayerOptions(mods_level)
        options:FromString(PlayerModsArray)
        options:Mini(0)
        options:StealthPastReceptors(true, true)
    end
end

local t = Def.ActorFrame {}

for i, pn in ipairs(GAMESTATE:GetEnabledPlayers()) do
    -- To avoid crashes with player 2
    local pnNoteField = PlayerNumber:Reverse()[pn]

    -- the draw distance needs to be dependant on doubles mode because the notefield has to be zoomed out in order for the doubles NoteField to fit onscreen
    local function NotefieldRenderBefore()  --THEME:GetMetric("Player","DrawDistanceBeforeTargetsPixels")
      if GAMESTATE:GetCurrentStyle():GetStyleType() == "StyleType_OnePlayerTwoSides" then
        return 815
      else
        return 430
      end
    end

    local function NotefieldX()
      -- 2 players joined UI
      if GAMESTATE:GetNumPlayersEnabled() == 2 then
        local offset = PROFILEMAN:IsPersistentProfile(pn) and TwoPlayerProfilePreviewXOffset or TwoPlayerGuestPreviewXOffset

        --player 1
        if pnNoteField == 0 then
          return _screen.cx - offset
        --player 2
        elseif pnNoteField == 1 then
          return _screen.cx + offset
        end
      -- single player UI (won't differ based on whether a profile is loaded)
      else
        --player 1
        if pnNoteField == 0 then
          return _screen.cx+293
        --player 2
        elseif pnNoteField == 1 then
          return _screen.cx-293
        end
      end
    end

    local function NotefieldZoom()
      --2 players
      if GAMESTATE:GetNumPlayersEnabled() == 2 then
        if PROFILEMAN:IsPersistentProfile(pn) then
          return TwoPlayerProfilePreviewZoom
        end

        return TwoPlayerGuestPreviewZoom
      --1 player
      else
        --doubles mode
        if GAMESTATE:GetCurrentStyle():GetStyleType() == "StyleType_OnePlayerTwoSides" then
          return 0.5
        end
        --default to zoom(1) outside of doubles mode
        return 1
      end
    end

    local function NotefieldFrameY()
      if GAMESTATE:GetNumPlayersEnabled() == 2 then
        return TwoPlayerPreviewYOffset
      end

      if GAMESTATE:GetCurrentStyle():GetStyleType() ~= "StyleType_OnePlayerTwoSides" then
        return SinglePlayerPreviewYOffset
      end

      return 0
    end

    local function ReceptorPosNormal()
      --2 players
      if GAMESTATE:GetNumPlayersEnabled() == 2 then
        --with profiles
        if PROFILEMAN:IsPersistentProfile(pn) then
          return _screen.cy-115
        --without profiles
        else
          return _screen.cy-170
        end
      --1 player
      else
        --doubles mode
        if GAMESTATE:GetCurrentStyle():GetStyleType() == "StyleType_OnePlayerTwoSides" then
          return _screen.cy-135
        end

        return _screen.cy-170
      end
    end

    local function ReceptorPosReverse()
      --2 players
      if GAMESTATE:GetNumPlayersEnabled() == 2 then
        --with profiles
        if PROFILEMAN:IsPersistentProfile(pn) then
          return _screen.cy+492
        --without profiles
        else
          return _screen.cy+35
        end
      --1 player
      else
        --doubles mode
        if GAMESTATE:GetCurrentStyle():GetStyleType() == "StyleType_OnePlayerTwoSides" then
          return _screen.cy+615
        end

        return _screen.cy+170
      end
    end

    local ReceptorOffset = ReceptorPosReverse() - ReceptorPosNormal()

  --upgrade to OutFox LTS 0.4.18 or later for NoteField previews
  if not ActorUtil.IsRegisteredClass("NoteField") then
    t[#t+1] = Def.ActorFrame {
        Name="Player" .. ToEnumShortString(pn),
        FOV=45,
        InitCommand=function(self)
          self:x(NotefieldX())
          self:y(NotefieldFrameY())
          self:zoom(NotefieldZoom())
        end,

        LoadFont("Common Normal")..{
          InitCommand=function(self)
            self:y(_screen.cy)
            self:settext("Upgrade To OutFox LTS 0.4.18 Or Later For NoteField Previews \n \n (missing NoteField class)")
            self:wrapwidthpixels(250)
    				self:vertspacing(-5)
          end,
        },
    }
  else
    t[#t+1] = Def.ActorFrame {
        Name="Player" .. ToEnumShortString(pn),
        FOV=45,
        InitCommand=function(self)
          self:x(NotefieldX())
          self:y(NotefieldFrameY())
          self:zoom(NotefieldZoom())
        end,
        Def.NoteField {
            Name = "NotefieldPreview",
            Player = pnNoteField,
            NoteSkin = GAMESTATE:GetPlayerState(pn):GetPlayerOptions('ModsLevel_Preferred'):NoteSkin(),
            Chart = Challenge,
            DrawDistanceAfterTargetsPixels = NotefieldRenderAfter,
            DrawDistanceBeforeTargetsPixels = NotefieldRenderBefore(),
            YReverseOffsetPixels = ReceptorOffset,
            FieldID=-1,
            OnCommand=function(self)
              self:y(0)
              ApplyPreviewOptions(self, pn)
              local Song = GAMESTATE:GetCurrentSong()
              local steps = Song and Song:GetLastSecond() <= MaxPreviewSongLengthSeconds and GAMESTATE:GetCurrentSteps(pn) or nil
              if steps then
                self:ChangeReload(steps)
                self:AutoPlay(true)
                self:visible(true)
              else
                self:visible(false)
              end
              self:playcommand("Refresh")
            end,

            CurrentStepsP1ChangedMessageCommand=function(self) self:playcommand("Refresh") end,
            CurrentStepsP2ChangedMessageCommand=function(self) self:playcommand("Refresh") end,
            --we don't need to use a messagecommand to refresh when switching from Single to Double style because the whole screen refreshes anyway
            OptionsListStartMessageCommand=function(self) self:playcommand("Refresh") end,

            -- Hide immediately when the wheel starts moving or the song changes mid-scroll
            PreviousSongMessageCommand=function(self) self:playcommand("Refresh") end,
            NextSongMessageCommand=function(self) self:playcommand("Refresh") end,
            CurrentSongChangedMessageCommand=function(self) self:playcommand("Refresh") end,

            ClearPreviewCommand=function(self)
                self:stoptweening()
                self:AutoPlay(false)
                if self:IsGenerated() then
                    self:SetNoteDataFromLua({})
                end
            end,

            -- Schedule decompress/load after delay; rapid scroll cancels so only the final selection loads
            RefreshCommand=function(self)
                local Song, steps = GetPreviewRefreshIdentity(pn)
                if SamePendingPreview(self, Song, steps) then return end

                SL.SelectMusicTelemetry:Pulse("wide.notefield.refresh")
                self:playcommand("ClearPreview")
                SetPendingPreview(self, Song, steps)
                self:sleep(PreviewDelay)
                self:queuecommand("DoRefresh")
            end,
            DoRefreshCommand=function(self)
                SL.SelectMusicTelemetry:Pulse("wide.notefield.do")
                local pendingSong = self.PendingSong
                local pendingSteps = self.PendingSteps
                ClearPendingPreview(self)

                self:AutoPlay(false)
                local Song = GAMESTATE:GetCurrentSong()
                if not Song then return end
                if pendingSong and Song ~= pendingSong then return end
                if Song:GetLastSecond() > MaxPreviewSongLengthSeconds then
                    if self:IsGenerated() then
                        self:SetNoteDataFromLua({})
                    end
                    self:visible(false)
                    return
                end
                if not self:IsGenerated() then return end
                local steps, ChartIndex = GetCurrentPreviewSteps(pn, Song)
                if not ChartIndex then return end
                if pendingSteps and steps ~= pendingSteps then return end

                ApplyPreviewOptions(self, pn)

                local NoteData = Song:GetNoteData(ChartIndex)
                if not NoteData then
                    self:visible(false)
                    return
                end

                self:SetNoteDataFromLua({})
                self:SetNoteDataFromLua(NoteData)
                self:visible(true)
                self:AutoPlay(true)
            end
        }
    }
    end
end

return t
