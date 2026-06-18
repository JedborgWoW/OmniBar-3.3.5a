-- OmniBar 3.3.5a backport compatibility shim
-- Provides the modern WoW API surface that OmniBar expects but that does not
-- exist on the original Wrath of the Lich King 3.3.5a client (interface 30300).
--
-- This file MUST be loaded before OmniBar.lua / Options.lua so that the globals
-- and namespaces below exist when those files are parsed.

local addonName, addon = ...

-- Only apply the shim on clients that are missing the modern API. On any client
-- that already provides these (retail, modern classic) the guards below are
-- no-ops, so the addon stays portable.

----------------------------------------------------------------------
-- WOW_PROJECT_* constants
--
-- 3.3.5a does not define WOW_PROJECT_ID. OmniBar branches heavily on it, and a
-- nil value makes `WOW_PROJECT_ID == WOW_PROJECT_MAINLINE` evaluate true
-- (nil == nil), which would enable retail-only code paths. Define the family of
-- constants and pin this client to the Wrath project so the correct branches run.
----------------------------------------------------------------------
WOW_PROJECT_MAINLINE              = WOW_PROJECT_MAINLINE or 1
WOW_PROJECT_CLASSIC               = WOW_PROJECT_CLASSIC or 2
WOW_PROJECT_BURNING_CRUSADE_CLASSIC = WOW_PROJECT_BURNING_CRUSADE_CLASSIC or 5
WOW_PROJECT_WRATH_CLASSIC         = WOW_PROJECT_WRATH_CLASSIC or 11
WOW_PROJECT_CATACLYSM_CLASSIC     = WOW_PROJECT_CATACLYSM_CLASSIC or 14
WOW_PROJECT_MISTS_CLASSIC         = WOW_PROJECT_MISTS_CLASSIC or 19

if WOW_PROJECT_ID == nil then
	WOW_PROJECT_ID = WOW_PROJECT_WRATH_CLASSIC
end

----------------------------------------------------------------------
-- C_Timer
--
-- 3.3.5a has no C_Timer. Implement After / NewTimer / NewTicker on top of a
-- single OnUpdate driver frame.
----------------------------------------------------------------------
if not C_Timer then
	C_Timer = {}

	local driver = CreateFrame("Frame")
	local timers = {}

	driver:Hide()
	driver:SetScript("OnUpdate", function(self, elapsed)
		local now = GetTime()
		for handle, t in pairs(timers) do
			if now >= t.expires then
				if t.iterations then
					t.iterations = t.iterations - 1
				end
				local cancelled = t.cancelled
				local ok, err = pcall(t.callback, handle)
				if not ok then
					geterrorhandler()(err)
				end
				if cancelled or t.cancelled or not t.looping or (t.iterations and t.iterations <= 0) then
					timers[handle] = nil
				else
					t.expires = now + t.duration
				end
			end
		end
		if not next(timers) then self:Hide() end
	end)

	local function schedule(duration, callback, looping, iterations)
		if type(duration) ~= "number" or type(callback) ~= "function" then return end
		if duration < 0 then duration = 0 end
		local handle = {}
		handle.Cancel = function(self)
			local t = timers[self]
			if t then t.cancelled = true end
		end
		handle.IsCancelled = function(self)
			local t = timers[self]
			return (not t) or t.cancelled or false
		end
		timers[handle] = {
			callback = callback,
			duration = duration,
			expires = GetTime() + duration,
			looping = looping,
			iterations = iterations,
		}
		driver:Show()
		return handle
	end

	function C_Timer.After(duration, callback)
		schedule(duration, callback, false)
	end

	function C_Timer.NewTimer(duration, callback)
		return schedule(duration, callback, false)
	end

	function C_Timer.NewTicker(duration, callback, iterations)
		return schedule(duration, callback, true, iterations)
	end
end

----------------------------------------------------------------------
-- C_AddOns / C_PvP / C_Spell scaffolding
----------------------------------------------------------------------
if not C_AddOns then
	C_AddOns = {
		GetAddOnMetadata = GetAddOnMetadata,
		IsAddOnLoaded = IsAddOnLoaded,
		LoadAddOn = LoadAddOn,
		EnableAddOn = EnableAddOn,
		DisableAddOn = DisableAddOn,
		GetNumAddOns = GetNumAddOns,
		GetAddOnInfo = GetAddOnInfo,
	}
end

if not C_PvP then C_PvP = {} end
if not C_PvP.IsRatedBattleground then
	-- 3.3.5a has no rated battlegrounds.
	C_PvP.IsRatedBattleground = function() return false end
end

-- NOTE: We deliberately leave C_Spell undefined. OmniBar already guards every
-- C_Spell call with `if C_Spell and C_Spell.X`, falling back to the classic
-- GetSpellInfo / GetSpellTexture globals, which is exactly what we want here.

----------------------------------------------------------------------
-- Misc globals added after 3.3.5a
----------------------------------------------------------------------
if not GetServerTime then
	-- Good enough for OmniBar's purpose (de-duplicating synced spell casts).
	GetServerTime = function() return time() end
end

-- `nop` (a do-nothing function) does not exist on 3.3.5a; Options.lua uses it.
if not nop then
	function nop() end
end

-- Group roster helpers were added in 5.0 (Mists). Map them to the 3.3.5a API.
if not GetNumGroupMembers then
	function GetNumGroupMembers()
		local raid = GetNumRaidMembers and GetNumRaidMembers() or 0
		if raid > 0 then return raid end
		local party = GetNumPartyMembers and GetNumPartyMembers() or 0
		return party
	end
end

if not IsInRaid then
	function IsInRaid()
		return (GetNumRaidMembers and GetNumRaidMembers() or 0) > 0
	end
end

if not IsInGroup then
	function IsInGroup()
		return ((GetNumPartyMembers and GetNumPartyMembers() or 0) > 0)
			or ((GetNumRaidMembers and GetNumRaidMembers() or 0) > 0)
	end
end

----------------------------------------------------------------------
-- Widget method polyfills (Cooldown / Frame / GameTooltip)
----------------------------------------------------------------------
do
	-- Cooldown: 3.3.5a supports SetCooldown(start, duration) but lacks the
	-- swipe/countdown/state accessors the modern code relies on.
	local cd = CreateFrame("Cooldown", nil, UIParent, "CooldownFrameTemplate")
	local cdMeta = getmetatable(cd).__index

	if not cdMeta.GetCooldownTimes then
		local SetCooldown = cdMeta.SetCooldown
		-- Track start/duration so GetCooldownTimes can report running state.
		function cdMeta:SetCooldown(start, duration, ...)
			self.__obStart = start
			self.__obDuration = duration
			return SetCooldown(self, start, duration, ...)
		end
		-- Modern GetCooldownTimes returns milliseconds; OmniBar only checks for
		-- 0 (idle) vs > 0 (running), so the exact units do not matter.
		function cdMeta:GetCooldownTimes()
			local start, duration = self.__obStart, self.__obDuration
			if not start or not duration or duration == 0 then return 0 end
			if (start + duration) <= GetTime() then return 0 end
			return start * 1000, duration * 1000
		end
	end

	local noop = function() end
	for _, method in ipairs({
		"SetSwipeColor", "SetHideCountdownNumbers", "SetDrawBling",
		"SetDrawEdge", "SetDrawSwipe", "SetSwipeTexture", "SetEdgeTexture",
	}) do
		if not cdMeta[method] then cdMeta[method] = noop end
	end

	-- Frame: SetClipsChildren is used by the AceGUI import/export windows.
	local frame = CreateFrame("Frame")
	local frameMeta = getmetatable(frame).__index
	if not frameMeta.SetClipsChildren then
		frameMeta.SetClipsChildren = noop
	end

	-- GameTooltip:SetSpellByID was added in 4.0; emulate via SetHyperlink.
	if GameTooltip and not GameTooltip.SetSpellByID then
		local meta = getmetatable(GameTooltip)
		local target = (meta and meta.__index) or GameTooltip
		target.SetSpellByID = function(self, spellID)
			if spellID then self:SetHyperlink("spell:" .. spellID) end
		end
	end
end

----------------------------------------------------------------------
-- Lightweight alpha animation helper
--
-- The retail OmniBar.xml drives its glow/flash with the modern animation system
-- (fromAlpha/toAlpha + childKey sub-region targeting), none of which exists on
-- 3.3.5a. We strip those animations from the XML and reproduce the effect here
-- with a tiny OnUpdate-based alpha tween.
----------------------------------------------------------------------
do
	local pulses = {}
	local pulser = CreateFrame("Frame")
	pulser:Hide()
	pulser:SetScript("OnUpdate", function(self, elapsed)
		for region, p in pairs(pulses) do
			p.elapsed = p.elapsed + elapsed
			local t = p.elapsed / p.duration
			if t >= 1 then
				region:SetAlpha(p.toAlpha)
				pulses[region] = nil
				if p.onFinished then p.onFinished() end
			else
				region:SetAlpha(p.fromAlpha + (p.toAlpha - p.fromAlpha) * t)
			end
		end
		if not next(pulses) then self:Hide() end
	end)

	-- Tween region alpha from fromAlpha to toAlpha over `duration` seconds.
	function addon.AlphaPulse(region, fromAlpha, toAlpha, duration, onFinished)
		if not region then return end
		region:SetAlpha(fromAlpha)
		pulses[region] = {
			elapsed = 0,
			fromAlpha = fromAlpha,
			toAlpha = toAlpha,
			duration = duration > 0 and duration or 0.0001,
			onFinished = onFinished,
		}
		pulser:Show()
	end

	function addon.AlphaPulseStop(region)
		if region then pulses[region] = nil end
	end
end

----------------------------------------------------------------------
-- Safe event detection
--
-- Registering an unknown event on 3.3.5a throws a hard Lua error. Some events
-- OmniBar wants (e.g. ARENA_OPPONENT_UPDATE) only exist on certain 3.3.5a
-- cores, so probe before registering.
----------------------------------------------------------------------
do
	local probe = CreateFrame("Frame")
	function addon.EventExists(event)
		local ok = pcall(probe.RegisterEvent, probe, event)
		if ok then probe:UnregisterEvent(event) end
		return ok
	end
end
