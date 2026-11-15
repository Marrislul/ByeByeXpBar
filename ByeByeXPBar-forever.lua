-- WoW Forever has two status bars. XP has the lowest priority there, so it sits in
-- bar 1 when no reputation is watched and in bar 2 when one is. Hiding the whole
-- StatusTrackingBarManager (what the retail version does) would take the reputation
-- bar with it, so this only hides the bar container that currently holds XP.
--
-- Everything runs in hooksecurefunc/HookScript hooks and never calls Blizzard's status
-- bar or Edit Mode code. That code also positions the action bars, so calling it from
-- an addon would taint them and get them blocked in combat.

local Manager = StatusTrackingBarManager
local NONE = StatusTrackingBarInfo.BarsEnum.None
local EXPERIENCE = StatusTrackingBarInfo.BarsEnum.Experience

-- Manager alpha before a wake-up fade (see below), nil when none is running.
local savedAlpha
local wakeUps = 0

local function RestoreAlpha()
	if savedAlpha then
		Manager:SetAlpha(savedAlpha)
		savedAlpha = nil
	end
end

for _, container in ipairs(Manager.barContainers) do
	-- UpdateShownState calls SetShown just before Blizzard stacks the bottom bars,
	-- so a container hidden here leaves no gap. In Edit Mode it stays visible.
	hooksecurefunc(container, "SetShown", function(self)
		if self.shownBarIndex == EXPERIENCE and not self.isInEditMode and self:IsShown() then
			self:Hide()
		end
	end)

	-- FadeIn starts its animation after that. On a hidden frame it would never
	-- finish, and the manager waits for running animations before it moves bars.
	hooksecurefunc(container, "FadeIn", function(self)
		if not self:IsShown() and self.FadeInAnimation:IsPlaying() then
			self.FadeInAnimation:Stop()
		end
	end)

	container.FadeOutAnimation:HookScript("OnFinished", RestoreAlpha)
end

-- When XP has to move to the other container (e.g. you start watching a reputation),
-- Blizzard first empties its container and moves the bars once that container has
-- faded out. A container we hid can't fade, so Blizzard empties it at once and nothing
-- calls the manager again until its next event. Here a hidden container plays
-- Blizzard's own fade-out instead, with the manager made invisible meanwhile. Its
-- finish handler is Blizzard code and calls the manager again, untainted.
hooksecurefunc(Manager, "UpdateBarsShown", function(self)
	if savedAlpha or not self:IsVisible() then
		return
	end

	local stuck, sleeper = false, nil
	for i, container in ipairs(self.barContainers) do
		if container:IsShown() or container:IsAnimating() then
			return
		end
		if container.shownBarIndex ~= (self.shownBarIndices[i] or NONE) then
			stuck = true
		end
		local callbacks = container.animationFinishedCallbacks
		if not sleeper and callbacks and callbacks[self] then
			sleeper = container
		end
	end
	if not (stuck and sleeper) then
		return
	end

	savedAlpha = self:GetAlpha()
	self:SetAlpha(0)
	sleeper:Show()
	sleeper.FadeOutAnimation:Restart()

	-- In case the fade never finishes.
	wakeUps = wakeUps + 1
	local wakeUp = wakeUps
	C_Timer.After(2, function()
		if wakeUp == wakeUps then
			RestoreAlpha()
		end
	end)
end)

--Prints info (personal preference). If you check this code and don't want this, just remove it.
print("Bye Bye XPBar: XPBar removed.")
