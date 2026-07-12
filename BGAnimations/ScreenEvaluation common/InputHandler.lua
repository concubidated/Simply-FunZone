local af, num_panes = unpack(...)

if not af
or type(num_panes) ~= "number"
then
	return
end

-- -----------------------------------------------------------------------
-- local variables

local panes, active_pane, active_graph = {}, {}, {}

local style = ToEnumShortString(GAMESTATE:GetCurrentStyle():GetStyleType())
local players = GAMESTATE:GetHumanPlayers()

local mpn = GAMESTATE:GetMasterPlayerNumber()

-- since we're potentially retrieving from player profile
-- perform some rudimentary validation by clamping both
-- values to be within permitted ranges
-- FIXME: num_panes won't be accurate if any panes were nil,
--        so this is more like "validation" than validation

local primary_i   = clamp(SL[ToEnumShortString(mpn)].EvalPanePrimary,   1, num_panes)
local secondary_i = clamp(SL[ToEnumShortString(mpn)].EvalPaneSecondary, 1, num_panes)

-- -----------------------------------------------------------------------
-- initialize local tables (panes, active_pane) for the the input handling function to use

local panes_af = af:GetChild("Panes")
if not panes_af then return end

for controller=1,2 do

	panes[controller] = {}
	active_graph[controller] = 1

	-- Iterate through all potential panes, and only add the non-nil ones to the
	-- list of panes we want to consider.
	for i=1,num_panes do

		local pane = panes_af:GetChild( ("Pane%i_SideP%i"):format(i, controller) )

		if pane ~= nil then
			-- single, double
			-- initialize the side ("controller") the player is joined as to their profile's EvalPanePrimary
			-- and the other side as their profile's EvalPaneSecondary
			if #players==1 then
				if ("P"..controller)==ToEnumShortString(mpn) then
					pane:visible(i == primary_i)
					active_pane[controller] = primary_i

				elseif ("P"..controller)==ToEnumShortString(OtherPlayer[mpn]) then
					pane:visible(i == secondary_i)
					active_pane[controller] = secondary_i

				end

			-- versus
			else
				-- initialize this player's active_pane to their profile's EvalPanePrimary
				-- will be 1 if no profile/"Guest" profile
				local p = clamp(SL["P"..controller].EvalPanePrimary, 1, num_panes)
				pane:visible(i == p)
				active_pane[controller] = p
			end

		 	table.insert(panes[controller], pane)
		end
	end
end

for controller=1,2 do
	if #panes[controller] == 0 then
		active_pane[controller] = nil
	else
		active_pane[controller] = clamp(active_pane[controller] or 1, 1, #panes[controller])
	end
end

local GetPane = function(controller, pane_index)
	if not (panes[controller] and pane_index) then return nil end
	return panes[controller][pane_index]
end

local GetPaneBody = function(controller, pane_index)
	local pane = GetPane(controller, pane_index)
	return pane and pane:GetChild("") or nil
end

local GetPaneChild = function(controller, pane_index, child_name)
	local body = GetPaneBody(controller, pane_index)
	return body and body:GetChild(child_name) or nil
end

local PaneExpandsForDouble = function(controller, pane_index)
	local body = GetPaneBody(controller, pane_index)
	return body and body:GetCommand("ExpandForDouble") ~= nil
end

local MoveActivePane = function(controller, direction)
	if not (panes[controller] and #panes[controller] > 0 and active_pane[controller]) then return end

	if direction > 0 then
		active_pane[controller] = (active_pane[controller] % #panes[controller]) + 1
	else
		active_pane[controller] = ((active_pane[controller] - 2) % #panes[controller]) + 1
	end
end

local SkipSubmittedQRPane = function(controller, direction)
	local help_text = GetPaneChild(controller, active_pane[controller], "HelpText")
	if help_text and help_text:GetText() == "Score has already been submitted :)" then
		MoveActivePane(controller, direction)
	end
end

local GetLeaderboardFirstName = function(controller)
	local high_score_list = GetPaneChild(controller, active_pane[controller], "HighScoreList")
	local entry = high_score_list and high_score_list:GetChild("HighScoreEntry1")
	return entry and entry:GetChild("Name") or nil
end

local SkipEmptyLeaderboardPanes = function(controller, direction)
	if not (panes[controller] and #panes[controller] > 0) then return end

	for i=1,#panes[controller] do
		local leaderboard_name = GetLeaderboardFirstName(controller)
		if not leaderboard_name then return end
		if leaderboard_name:GetText() ~= "----" then return end
		MoveActivePane(controller, direction)
	end
end

local ShowActivePane = function(controller)
	local pane = GetPane(controller, active_pane[controller])
	if pane then pane:visible(true):diffusealpha(1) end
end

local HideActivePane = function(controller)
	local pane = GetPane(controller, active_pane[controller])
	if pane then pane:visible(false) end
end

-- -----------------------------------------------------------------------
-- don't allow double to initialize into a configuration like
-- EvalPanePrimary=3
-- EvalPaneSecondary=4
-- because Pane3 is full-width in double and the other pane is supposed to be hidden when it is visible

if style == "OnePlayerTwoSides" then
	local cn  = PlayerNumber:Reverse()[mpn] + 1
	local ocn = (cn % 2) + 1

	-- if the player wanted their primary pane to be something that is full-width in double
	if PaneExpandsForDouble(cn, active_pane[cn]) then
		-- hide all panes for the other controller
		for pane in ivalues(panes[ocn]) do
			pane:visible(false)
		end
		-- and only show the one full-width pane
		ShowActivePane(cn)
	end

	-- if the player wanted their secondary pane to be something that is full-width in double
	if PaneExpandsForDouble(ocn, active_pane[ocn]) then
		-- arbitrarily opt to hide the secondary pane
		HideActivePane(ocn)

		-- and show the next available pane that doesn't match primary and isn't also full-width
		for i=1,#panes[ocn] do
			MoveActivePane(ocn, 1)

			if active_pane[ocn] ~= active_pane[cn]
			and not PaneExpandsForDouble(ocn, active_pane[ocn])
			then
				ShowActivePane(ocn)
				break
			end
		end
	end
end

-- -----------------------------------------------------------------------
-- input handling function

local OtherController = {
	GameController_1 = "GameController_2",
	GameController_2 = "GameController_1"
}

return function(event)


	if not (event and event.PlayerNumber and event.button) then return false end

	-- Broadcast so the Test Input pane (Pane 6) can show button feedback.
	if event.type ~= "InputEventType_Repeat" then
		MESSAGEMAN:Broadcast("TestInputEvent", event)
	end

	-- get a "controller number" and an "other controller number"
	-- if the input event came from GameController_1, cn will be 1 and ocn will be 2
	-- if the input event came from GameController_2, cn will be 2 and ocn will be 1
	-- fallback: derive from PlayerNumber when event.controller is nil (e.g. some OutFox configs)
	local cn, ocn
	if event.controller and OtherController[event.controller] then
		local other = OtherController[event.controller]
		cn  = tonumber(ToEnumShortString(event.controller))
		ocn = tonumber(ToEnumShortString(other))
	else
		cn  = (event.PlayerNumber == PLAYER_1) and 1 or 2
		ocn = 3 - cn
	end
	if not panes[cn] then return false end
	if not (active_pane[cn] and panes[cn][active_pane[cn]]) then return false end

	if event.type == "InputEventType_FirstPress" then

		if event.GameButton == "MenuUp" or event.GameButton == "MenuDown" then
			if event.GameButton == "MenuUp" then
				active_graph[cn] = (active_graph[cn] - 1) % 3
				if active_graph[cn] == 0 then active_graph[cn] = 3 end
			else
				active_graph[cn] = (active_graph[cn] % 3) + 1
			end
			
			local lower = #players==1 and af:GetChild(ToEnumShortString(mpn) .. "_AF_Lower") or af:GetChild("P" .. cn .. "_AF_Lower")
			local judge_graph = lower and lower:GetChild("JudgeGraph")
			local arrow_graph = lower and lower:GetChild("ArrowGraph")

			if judge_graph then judge_graph:visible(active_graph[cn] == 1) end
			if arrow_graph then
				arrow_graph:visible(active_graph[cn] > 1)
				local arrow_plot = arrow_graph:GetChild("ArrowPlot")
				local foot_plot = arrow_graph:GetChild("FootPlot")
				local feet = arrow_graph:GetChild("Feet")
				if arrow_plot then arrow_plot:visible(active_graph[cn] == 2) end
				if foot_plot then foot_plot:visible(active_graph[cn] == 3) end
				if feet then feet:visible(active_graph[cn] == 3) end
			end

			if #players==1 then
				local secondary_graph_pane = GetPane(ocn, 3)
				if secondary_graph_pane then secondary_graph_pane:playcommand("Graph", {graph=active_graph[cn]}) end
			end

			local graph_pane_2 = GetPane(cn, 2)
			local graph_pane_3 = GetPane(cn, 3)
			if graph_pane_2 then graph_pane_2:playcommand("Graph", {graph=active_graph[cn]}) end
			if graph_pane_3 then graph_pane_3:playcommand("Graph", {graph=active_graph[cn]}) end
		end
		
		if event.GameButton == "MenuRight" or event.GameButton == "MenuLeft" then
			if event.GameButton == "MenuRight" then
				MoveActivePane(cn, 1)
				-- don't allow duplicate panes to show in single/double
				-- if the above change would result in duplicate panes, increment again
				
				-- Skip QR code pane if it has already been submitted
				-- Is there any other instances we want to skip?
				SkipSubmittedQRPane(cn, 1)

				-- Only show the leaderboard panes (GS/RPG/ITL) if they contain any entries.
				-- Can't check the results when the screen loads because of response times,
				-- so we have to check when we change panes.

				-- Originally I made it to remove the actor if it doesn't return results
				-- but the only way I could get that to work was using global variables.
				-- This seems to work for now, until the pane system is revamped.

				-- Skip leaderboard panes that exist but still contain no results.
				SkipEmptyLeaderboardPanes(cn, 1)
				
				if #players==1 and active_pane[cn] == active_pane[ocn] then
					MoveActivePane(cn, 1)

					
					-- Skip QR code pane if it has already been submitted
					-- Is there any other instances we want to skip?
					SkipSubmittedQRPane(cn, 1)

					-- Only show the leaderboard panes (GS/RPG/ITL) if they contain any entries.
					-- Can't check the results when the screen loads because of response times,
					-- so we have to check when we change panes.

					-- Originally I made it to remove the actor if it doesn't return results
					-- but the only way I could get that to work was using global variables.
					-- This seems to work for now, until the pane system is revamped.

					-- Skip leaderboard panes that exist but still contain no results.
					SkipEmptyLeaderboardPanes(cn, 1)

				end

			elseif event.GameButton == "MenuLeft" then
				MoveActivePane(cn, -1)
				-- don't allow duplicate panes to show in single/double
				-- if the above change would result in duplicate panes, decrement again

				-- Only show the leaderboard panes (GS/RPG/ITL) if they contain any entries.
				-- Can't check the results when the screen loads because of response times,
				-- so we have to check when we change panes.

				-- Originally I made it to remove the actor if it doesn't return results
				-- but the only way I could get that to work was using global variables.
				-- This seems to work for now, until the pane system is revamped.

				-- Skip leaderboard panes that exist but still contain no results.
				SkipEmptyLeaderboardPanes(cn, -1)
				
				-- Skip QR code pane if it has already been submitted
				-- Is there any other instances we want to skip?
				SkipSubmittedQRPane(cn, -1)
					
				if #players==1 and active_pane[cn] == active_pane[ocn] then
					MoveActivePane(cn, -1)

					-- Skip leaderboard panes that exist but still contain no results.
					SkipEmptyLeaderboardPanes(cn, -1)
					
					-- Skip QR code pane if it has already been submitted
					-- Is there any other instances we want to skip?
					SkipSubmittedQRPane(cn, -1)


				end
			end


			-- double
			if style == "OnePlayerTwoSides" then
				-- if this controller is switching to Pane3 or Pane6, both of which take over both pane widths
				if PaneExpandsForDouble(cn, active_pane[cn]) then

					-- hide all panes for both controllers
					for controller=1,2 do
						for pane in ivalues(panes[controller]) do
							pane:visible(false)
						end
					end
					-- and only show the one full-width pane
					ShowActivePane(cn)


				-- if this controller is switching panes while the OTHER controller was viewing Pane3 or Pane6
				elseif PaneExpandsForDouble(ocn, active_pane[ocn]) then
					HideActivePane(ocn)
					ShowActivePane(cn)
					-- atribitarily choose to decrement other controller pane
					MoveActivePane(ocn, -1)
					if active_pane[cn] == active_pane[ocn] then
						MoveActivePane(ocn, -1)
					end
					ShowActivePane(ocn)

				else

					-- hide all panes for this side
					for i=1,#panes[cn] do
						panes[cn][i]:visible(false)
					end
					-- show the panes we want on both sides
					ShowActivePane(cn)
					ShowActivePane(ocn)
				end


			-- single, versus
			else
				-- hide all panes for this side
				for i=1,#panes[cn] do
					panes[cn][i]:visible(false)
				end
				-- only show the pane we want on this side
				ShowActivePane(cn)
			end

			af:queuecommand("PaneSwitch")
		end
	end

	return false
end
