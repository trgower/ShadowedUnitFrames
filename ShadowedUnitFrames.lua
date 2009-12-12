--[[ 
	Shadowed Unit Frames, Mayen of Mal'Ganis (US) PvP
]]

ShadowUF = {playerUnit = "player", raidUnits = {}, partyUnits = {}, arenaUnits = {}, bossUnits = {}, modules = {}, moduleOrder = {}, units = {"player", "pet", "pettarget", "target", "targettarget", "targettargettarget", "focus", "focustarget", "party", "partypet", "partytarget", "raid", "boss", "bosstarget", "maintank", "maintanktarget", "mainassist", "mainassisttarget", "arena", "arenatarget", "arenapet"}}

local L = ShadowUFLocals
local units = ShadowUF.units
local _G = getfenv(0)

-- Cache the units so we don't have to concat every time it updates
for i=1, MAX_PARTY_MEMBERS do ShadowUF.partyUnits[i] = "party" .. i end
for i=1, MAX_RAID_MEMBERS do ShadowUF.raidUnits[i] = "raid" .. i end
for i=1, MAX_BOSS_FRAMES do table.insert(ShadowUF.bossUnits, "boss" .. i) end
for i=1, 5 do ShadowUF.arenaUnits[i] = "arena" .. i end
ShadowUF.unitTarget = setmetatable({}, {__index = function(tbl, unit) rawset(tbl, unit, unit .. "target"); return unit .. "target" end})

function ShadowUF:OnInitialize()
	self.defaults = {
		profile = {
			locked = false,
			advanced = false,
			tooltipCombat = false,
			tags = {},
			units = {},
			positions = {},
			filters = {zones = {}, whitelists = {}, blacklists = {}},
			visibility = {arena = {}, pvp = {}, party = {}, raid = {}},
			hidden = {cast = false, runes = true, buffs = true},
		},
	}
	
	self:LoadUnitDefaults()
	
	-- Initialize DB
	self.db = LibStub:GetLibrary("AceDB-3.0"):New("ShadowedUFDB", self.defaults, true)
	self.db.RegisterCallback(self, "OnProfileChanged", "ProfilesChanged")
	self.db.RegisterCallback(self, "OnProfileCopied", "ProfilesChanged")
	self.db.RegisterCallback(self, "OnProfileReset", "ProfileReset")
		
	-- Setup tag cache
	self.tagFunc = setmetatable({}, {
		__index = function(tbl, index)
			if( not ShadowUF.Tags.defaultTags[index] and not ShadowUF.db.profile.tags[index] ) then
				tbl[index] = false
				return false
			end
			
			local func, msg = loadstring("return " .. (ShadowUF.Tags.defaultTags[index] or ShadowUF.db.profile.tags[index].func or ""))
			if( func ) then
				func = func()
			elseif( msg ) then
				error(msg, 3)
			end
			
			tbl[index] = func
			return tbl[index]
	end})
	
	if( not self.db.profile.loadedLayout ) then
		self:LoadDefaultLayout()
	else
		self:CheckUpgrade()
	end
	
	self:HideBlizzardFrames()
	self.Layout:LoadSML()
	self:LoadUnits()
	self.modules.movers:Update()
end

function ShadowUF:CheckUpgrade()
	-- September 21th, 2009
	for _, unit in pairs(self.units) do
		if( self.db.profile.units[unit].indicators.role and not self.db.profile.units[unit].indicators.role.anchorTo ) then
			self.db.profile.units[unit].indicators.role.anchorTo = "$parent"
			self.db.profile.units[unit].indicators.role.anchorPoint = "BR"
			self.db.profile.units[unit].indicators.role.x = 0
			self.db.profile.units[unit].indicators.role.y = 16
			self.db.profile.units[unit].indicators.role.size = 16
		end
		
		if( self.db.profile.units[unit].indicators.status and not self.db.profile.units[unit].indicators.status.anchorTo ) then
			self.db.profile.units[unit].indicators.status.anchorTo = "$parent"
			self.db.profile.units[unit].indicators.status.anchorPoint = "LB"
			self.db.profile.units[unit].indicators.status.x = 12
			self.db.profile.units[unit].indicators.status.y = -2
			self.db.profile.units[unit].indicators.status.size = 16
		end
	end

	-- October 10th, 2009
	if( self.db.profile.units.party.showAsRaid ~= nil ) then
		self.db.profile.units.raid.showParty = self.db.profile.units.party.showAsRaid
		self.db.profile.units.party.showAsRaid = nil
	end
	
	-- December 1th, 2009
	if( not self.db.profile.units.player.indicators.lfdRole.anchorPoint and not self.db.profile.units.party.indicators.lfdRole.anchorPoint ) then
		self.db.profile.units.player.indicators.lfdRole = {enabled = true, size = 16, x = 6, y = 14, anchorPoint = "BR", anchorTo = "$parent"}
		self.db.profile.units.party.indicators.lfdRole = {enabled = true, size = 16, x = 6, y = 14, anchorPoint = "BR", anchorTo = "$parent"}
	end
	
	-- Put the units into a state where the next loop will force them all to reset
	if( self.db.profile.positions.arenatarget.anchorTo ~= "$parent" or self.db.profile.positions.arenapet.anchorTo ~= "$parent" ) then
		for _, unit in pairs({"arena", "arenapet", "arenatarget"}) do
			self.db.profile.units[unit].enabled = nil
			self.db.profile.units[unit].width = 0
			self.db.profile.units[unit].height = 0
			self.db.profile.positions[unit].anchorPoint = ""
			self.db.profile.positions[unit].relativePoint = ""
			self.db.profile.positions[unit].point = ""
			self.db.profile.positions[unit].x = 0
			self.db.profile.positions[unit].y = 0
		end
	end

	for _, unit in pairs(self.units) do
		if( not self.db.profile.units[unit].enabled and self.db.profile.units[unit].height == 0 and self.db.profile.units[unit].width == 0 and self.db.profile.positions[unit].anchorPoint == "" and self.db.profile.positions[unit].point == "" ) then
			ShadowUF:LoadDefaultLayout(true)
			break
		end
	end
		
	if( not ShadowUF.Config and select(6, GetAddOnInfo("ShadowedUF_Options")) ) then
		SlashCmdList["SUF"] = function()
			DEFAULT_CHAT_FRAME:AddMessage(L["[WARNING!] Configuration in SUF has been split into a separate addon, you will need to restart your game before you can open the configuration."])
		end
	end
	
	if( not ShadowUF.db.profile.healthColors.offline ) then
		ShadowUF.db.profile.healthColors.offline = {r = 0.50, g = 0.50, b = 0.50}
	end
	
	-- December 9th
	for unit, config in pairs(self.db.profile.units) do
		if( not config.healthBar.colorType or config.healthBar.reaction ~= nil ) then
			config.healthBar.colorType = config.healthBar.colorType or "percent"
			if( config.healthBar.reaction ) then
				config.healthBar.reactionType = unit == "pet" and "happiness" or "npc"
			else
				config.healthBar.reactionType = "none"
			end
			
			config.healthBar.reaction = nil
		end
		
		if( config.emptyBar.reaction ~= nil ) then
			config.emptyBar.reactionType = config.emptyBar.reaction and "npc" or "none"
			config.emptyBar.reaction = nil
		end
		
		config.emptyBar.reactionType = config.emptyBar.reactionType or "none"
		config.healthBar.reactionType = config.healthBar.reactionType or "none"
		config.highlight.alpha = config.highlight.alpha or 1.0
		config.highlight.size = config.highlight.size or 30
	end
end
	
function ShadowUF:LoadUnits()
	local instanceType = select(2, IsInInstance())
	for _, type in pairs(units) do
		local enabled = self.db.profile.units[type].enabled
		if( ShadowUF.Units.zoneUnits[type] and enabled ) then
			enabled = ShadowUF.Units.zoneUnits[type] == instanceType
		elseif( instanceType ~= "none" ) then
			if( self.db.profile.visibility[instanceType][type] == false ) then
				enabled = false
			elseif( self.db.profile.visibility[instanceType][type] == true ) then
				enabled = true
			end
		end
		
		if( enabled ) then
			self.Units:InitializeFrame(type)
		else
			self.Units:UninitializeFrame(type)
		end
	end
end

function ShadowUF:LoadUnitDefaults()
	for _, unit in pairs(units) do
		self.defaults.profile.positions[unit] = {point = "", relativePoint = "", anchorPoint = "", anchorTo = "UIParent", x = 0, y = 0}
		
		-- The reason why the defaults are so sparse, is because the layout needs to specify most of this. The reason I set tables here is basically
		-- as an indication that hey, the unit wants this, if it doesn't that it won't want it.
		self.defaults.profile.units[unit] = {
			enabled = false, height = 0, width = 0, scale = 1.0,
			healthBar = {enabled = true},
			powerBar = {enabled = true},
			emptyBar = {enabled = false},
			portrait = {enabled = false, type = "3D", fullBefore = 0, fullAfter = 100, order = 40, height = 0.50},
			text = {
				{enabled = true, name = L["Left text"], text = "[name]", anchorPoint = "C", anchorTo = "$healthBar", size = 0},
				{enabled = true, name = L["Right text"], text = "[curmaxhp]", anchorPoint = "C", anchorTo = "$healthBar", size = 0},
				{enabled = true, name = L["Left text"], text = "[level] [race]", anchorPoint = "C", anchorTo = "$powerBar", size = 0},
				{enabled = true, name = L["Right text"], text = "[curmaxpp]", anchorPoint = "C", anchorTo = "$powerBar", size = 0},
				{enabled = true, name = L["Text"], text = "", anchorTo = "$emptyBar", anchorPoint = "C", size = 0, x = 0, y = 0},
			},
			indicators = {raidTarget = {enabled = true, size = 0}}, 
			highlight = {},
			auras = {
				buffs = {enabled = false, perRow = 10, maxRows = 4, selfScale = 1.30, prioritize = true, enlargeSelf = false},
				debuffs = {enabled = false, perRow = 10, maxRows = 4, selfScale = 1.30, enlargeSelf = true},
			},
		}
				
		-- These modules are not enabled for "fake" units so don't bother with adding defaults
		if( not string.match(unit, "%w+target") ) then
			self.defaults.profile.units[unit].castBar = {enabled = false, icon = "HIDE", name = {enabled = true, size = 0, anchorTo = "$parent", rank = true, anchorPoint = "CLI", x = 1, y = 0}, time = {enabled = true, size = 0, anchorTo = "$parent", anchorPoint = "CRI", x = -1, y = 0}}
			self.defaults.profile.units[unit].combatText = {enabled = true, anchorTo = "$parent", anchorPoint = "C", x = 0, y = 0}

			if( unit ~= "boss" and unit ~= "arena" and unit ~= "arenapet" ) then
				self.defaults.profile.units[unit].incHeal = {enabled = false, cap = 1.30}
			end
		end
		
		if( unit ~= "player" ) then
			self.defaults.profile.units[unit].range = {enabled = false, oorAlpha = 0.80, inAlpha = 1.0}
		end
			
		-- Want pvp/leader/ML enabled for these units
		if( unit == "player" or unit == "party" or unit == "target" or unit == "raid" or unit == "focus" ) then
			self.defaults.profile.units[unit].indicators.leader = {enabled = true, size = 0}
			self.defaults.profile.units[unit].indicators.masterLoot = {enabled = true, size = 0}
			self.defaults.profile.units[unit].indicators.pvp = {enabled = true, size = 0}
			self.defaults.profile.units[unit].indicators.role = {enabled = true, size = 0}
			self.defaults.profile.units[unit].indicators.status = {enabled = false, size = 19}
			
			if( unit ~= "focus" and unit ~= "target" ) then
				self.defaults.profile.units[unit].indicators.ready = {enabled = true, size = 0}
			end
		end
	end
		
	-- PLAYER
	self.defaults.profile.units.player.enabled = true
	self.defaults.profile.units.player.healthBar.predicted = true
	self.defaults.profile.units.player.powerBar.predicted = true
	self.defaults.profile.units.player.indicators.status.enabled = true
	self.defaults.profile.units.player.runeBar = {enabled = false}
	self.defaults.profile.units.player.totemBar = {enabled = false}
	self.defaults.profile.units.player.druidBar = {enabled = false}
	self.defaults.profile.units.player.xpBar = {enabled = false}
	self.defaults.profile.units.player.fader = {enabled = false, combatAlpha = 1.0, inactiveAlpha = 0.60}
	self.defaults.profile.units.player.indicators.lfdRole = {enabled = true, size = 0, x = 0, y = 0}
	-- PET
	self.defaults.profile.units.pet.enabled = true
	self.defaults.profile.units.pet.indicators.happiness = {enabled = true, size = 16, anchorPoint = "BR", anchorTo = "$parent", x = 2, y = -2}
	self.defaults.profile.units.pet.fader = {enabled = false, combatAlpha = 1.0, inactiveAlpha = 0.60}
	self.defaults.profile.units.pet.xpBar = {enabled = false}
	-- FOCUS
	self.defaults.profile.units.focus.enabled = true
	self.defaults.profile.units.focus.fader = {enabled = false, combatAlpha = 1.0, inactiveAlpha = 0.60}
	-- FOCUSTARGET
	self.defaults.profile.units.focustarget.enabled = true
	self.defaults.profile.units.focustarget.fader = {enabled = false, combatAlpha = 1.0, inactiveAlpha = 0.60}
	-- TARGET
	self.defaults.profile.units.target.enabled = true
	self.defaults.profile.units.target.comboPoints = {enabled = true, isBar = false, height = 0.40, order = 30, anchorTo = "$parent", anchorPoint = "BR", x = 0, y = 0}
	-- TARGETTARGET/TARGETTARGETTARGET
	self.defaults.profile.units.targettarget.enabled = true
	self.defaults.profile.units.targettargettarget.enabled = true
	-- PARTY
	self.defaults.profile.units.party.enabled = true
	self.defaults.profile.units.party.sortMethod = "INDEX"
	self.defaults.profile.units.party.sortOrder = "ASC"
	self.defaults.profile.units.party.attribPoint = "TOP"
	self.defaults.profile.units.party.attribAnchorPoint = "LEFT"
	self.defaults.profile.units.party.auras.debuffs.maxRows = 1
	self.defaults.profile.units.party.auras.buffs.maxRows = 1
	self.defaults.profile.units.party.offset = 0
	self.defaults.profile.units.party.columnSpacing = 0
	self.defaults.profile.units.party.fader = {enabled = false, combatAlpha = 1.0, inactiveAlpha = 0.60}
	self.defaults.profile.units.party.combatText.enabled = false
	self.defaults.profile.units.party.indicators.lfdRole = {enabled = true, size = 0, x = 0, y = 0}
	-- ARENA
	self.defaults.profile.units.arena.enabled = false
	self.defaults.profile.units.arena.attribPoint = "TOP"
	self.defaults.profile.units.arena.attribAnchorPoint = "LEFT"
	self.defaults.profile.units.arena.auras.debuffs.maxRows = 1
	self.defaults.profile.units.arena.auras.buffs.maxRows = 1
	self.defaults.profile.units.arena.offset = 0
	-- BOSS
	self.defaults.profile.units.boss.enabled = false
	self.defaults.profile.units.boss.attribPoint = "TOP"
	self.defaults.profile.units.boss.attribAnchorPoint = "LEFT"
	self.defaults.profile.units.boss.auras.debuffs.maxRows = 1
	self.defaults.profile.units.boss.auras.buffs.maxRows = 1
	self.defaults.profile.units.boss.offset = 0
	-- RAID
	self.defaults.profile.units.raid.groupBy = "GROUP"
	self.defaults.profile.units.raid.sortOrder = "ASC"
	self.defaults.profile.units.raid.sortMethod = "INDEX"
	self.defaults.profile.units.raid.attribPoint = "TOP"
	self.defaults.profile.units.raid.attribAnchorPoint = "RIGHT"
	self.defaults.profile.units.raid.offset = 0
	self.defaults.profile.units.raid.filters = {[1] = true, [2] = true, [3] = true, [4] = true, [5] = true, [6] = true, [7] = true, [8] = true}
	self.defaults.profile.units.raid.fader = {enabled = false, combatAlpha = 1.0, inactiveAlpha = 0.60}
	self.defaults.profile.units.raid.combatText.enabled = false
	-- MAINTANK
	self.defaults.profile.units.maintank.groupFilter = "MAINTANK"
	self.defaults.profile.units.maintank.groupBy = "GROUP"
	self.defaults.profile.units.maintank.sortOrder = "ASC"
	self.defaults.profile.units.maintank.sortMethod = "INDEX"
	self.defaults.profile.units.maintank.attribPoint = "TOP"
	self.defaults.profile.units.maintank.attribAnchorPoint = "RIGHT"
	self.defaults.profile.units.maintank.offset = 0
	self.defaults.profile.units.maintank.fader = {enabled = false, combatAlpha = 1.0, inactiveAlpha = 0.60}
	-- MAINASSIST
	self.defaults.profile.units.mainassist.groupFilter = "MAINASSIST"
	self.defaults.profile.units.mainassist.groupBy = "GROUP"
	self.defaults.profile.units.mainassist.sortOrder = "ASC"
	self.defaults.profile.units.mainassist.sortMethod = "INDEX"
	self.defaults.profile.units.mainassist.attribPoint = "TOP"
	self.defaults.profile.units.mainassist.attribAnchorPoint = "RIGHT"
	self.defaults.profile.units.mainassist.offset = 0
	self.defaults.profile.units.mainassist.fader = {enabled = false, combatAlpha = 1.0, inactiveAlpha = 0.60}
	-- PARTYPET
	self.defaults.profile.positions.partypet.anchorTo = "$parent"
	self.defaults.profile.positions.partypet.anchorPoint = "RB"
	self.defaults.profile.units.partypet.fader = {enabled = false, combatAlpha = 1.0, inactiveAlpha = 0.60}
	-- PARTYTARGET
	self.defaults.profile.positions.partytarget.anchorTo = "$parent"
	self.defaults.profile.positions.partytarget.anchorPoint = "RT"
	self.defaults.profile.units.partytarget.fader = {enabled = false, combatAlpha = 1.0, inactiveAlpha = 0.60}
		
	self:FireModuleEvent("OnDefaultsSet")
end

-- Module APIs
function ShadowUF:RegisterModule(module, key, name, isBar, class)
	self.modules[key] = module

	module.moduleKey = key
	module.moduleHasBar = isBar
	module.moduleName = name
	module.moduleClass = class
	
	table.insert(self.moduleOrder, module)
end

function ShadowUF:FireModuleEvent(event, frame, unit)
	for _, module in pairs(self.moduleOrder) do
		if( module[event] ) then
			module[event](module, frame, unit)
		end
	end
end

-- Profiles changed
-- I really dislike this solution, but if we don't do it then there is setting issues
-- because when copying a profile, AceDB-3.0 fires OnProfileReset -> OnProfileCopied
-- SUF then sees that on the new reset profile has no profile, tries to load one in
-- ... followed by the profile copying happen and it doesn't copy everything correctly
-- due to variables being reset already.
local resetTimer
function ShadowUF:ProfileReset()
	if( not resetTimer ) then
		resetTimer = CreateFrame("Frame")
		resetTimer:SetScript("OnUpdate", function(self)
			ShadowUF:ProfilesChanged()
			self:Hide()
		end)
	end
	
	resetTimer:Show()
end

function ShadowUF:ProfilesChanged()
	if( self.layoutImporting ) then return end
	if( resetTimer ) then resetTimer:Hide() end
	table.wipe(self.tagFunc)
	
	self.db:RegisterDefaults(self.defaults)
	
	-- No active layout, register the default one
	if( not self.db.profile.loadedLayout ) then
		self:LoadDefaultLayout()
	else
		self:CheckUpgrade()
	end
	
	self:LoadUnits()
	self:HideBlizzardFrames()
	self.Layout:CheckMedia()
	self.Units:ProfileChanged()
	self.modules.movers:Update()
end

-- Stolen from haste
ShadowUF.noop = function() end
function ShadowUF:HideBlizzardFrames()
	if( ShadowUF.db.profile.hidden.runes ) then
		RuneFrame.Show = self.noop
		RuneFrame:Hide()
	end
	
	if( ShadowUF.db.profile.hidden.cast ) then
		CastingBarFrame:UnregisterAllEvents()
		PetCastingBarFrame:UnregisterAllEvents()
	end

	if( ShadowUF.db.profile.hidden.buffs ) then
		BuffFrame:UnregisterAllEvents()
		BuffFrame.Show = self.noop
		BuffFrame:Hide()
		ConsolidatedBuffs.Show = self.noop
		ConsolidatedBuffs:Hide()
		TemporaryEnchantFrame.Show = self.noop
		TemporaryEnchantFrame:Hide()
	end
	
	if( ShadowUF.db.profile.units.player.enabled ) then
		PlayerFrame:UnregisterAllEvents()
		PlayerFrame.Show = self.noop
		PlayerFrame:Hide()

		PlayerFrameHealthBar:UnregisterAllEvents()
		PlayerFrameManaBar:UnregisterAllEvents()
	end
	
	if( ShadowUF.db.profile.units.player.enabled or ShadowUF.db.profile.units.pet.enabled ) then
		PetFrame:UnregisterAllEvents()
		PetFrame.Show = self.noop
		PetFrame:Hide()

		PetFrameHealthBar:UnregisterAllEvents()
		PetFrameManaBar:UnregisterAllEvents()
	end
	
	if( ShadowUF.db.profile.units.target.enabled ) then
		TargetFrame:UnregisterAllEvents()
		TargetFrame.Show = self.noop
		TargetFrame:Hide()

		TargetFrameHealthBar:UnregisterAllEvents()
		TargetFrameManaBar:UnregisterAllEvents()
		TargetFrameSpellBar:UnregisterAllEvents()

		ComboFrame:UnregisterAllEvents()
		ComboFrame.Show = self.noop
		ComboFrame:Hide()
	end
	
	if( ShadowUF.db.profile.units.focus.enabled ) then
		FocusFrame:UnregisterAllEvents()
		FocusFrame.Show = self.noop
		FocusFrame:Hide()

		FocusFrameHealthBar:UnregisterAllEvents()
		FocusFrameManaBar:UnregisterAllEvents()
		FocusFrameSpellBar:UnregisterAllEvents()
	end
	
	if( ShadowUF.db.profile.units.party.enabled ) then
		for i=1, MAX_PARTY_MEMBERS do
			local name = "PartyMemberFrame" .. i
			local frame = _G[name]

			frame:UnregisterAllEvents()
			frame.Show = self.noop
			frame:Hide()

			_G[name .. "HealthBar"]:UnregisterAllEvents()
			_G[name .. "ManaBar"]:UnregisterAllEvents()
		end
	end
	
	if( ShadowUF.db.profile.units.boss.enabled ) then
		for i=1, MAX_BOSS_FRAMES do
			local name = "Boss" .. i .. "TargetFrame"
			local frame = _G[name]

			frame:UnregisterAllEvents()
			frame.Show = self.noop
			frame:Hide()

			_G[name .. "HealthBar"]:UnregisterAllEvents()
			_G[name .. "ManaBar"]:UnregisterAllEvents()
		end
	end
	
	if( ShadowUF.db.profile.units.arena.enabled ) then
		Arena_LoadUI = self.noop
	end

	for _, list in pairs(UnitPopupMenus) do
		for i=#(list), 1, -1 do
			if( list[i] == "SET_FOCUS" or list[i] == "CLEAR_FOCUS" or list[i] == "LOCK_FOCUS_FRAME" or list[i] == "UNLOCK_FOCUS_FRAME" ) then
				table.remove(list, i)
			end
		end
	end
end

CONFIGMODE_CALLBACKS = CONFIGMODE_CALLBACKS or {}
CONFIGMODE_CALLBACKS["Shadowed Unit Frames"] = function(mode)
	if( mode == "ON" ) then
		ShadowUF.db.profile.locked = false
	elseif( mode == "OFF" ) then
		ShadowUF.db.profile.locked = true
	end
	
	ShadowUF.modules.movers:Update()
end

SLASH_SHADOWEDUF1 = "/suf"
SLASH_SHADOWEDUF2 = "/shadowuf"
SLASH_SHADOWEDUF3 = "/shadoweduf"
SLASH_SHADOWEDUF4 = "/shadowedunitframes"
SlashCmdList["SHADOWEDUF"] = function(msg)
	local loaded, reason = LoadAddOn("ShadowedUF_Options")
	if( not ShadowUF.Config ) then
		DEFAULT_CHAT_FRAME:AddMessage(string.format(L["Failed to load ShadowedUF_Options, cannot open configuration. Error returned: %s"], reason and _G["ADDON_" .. reason] or ""))
		return
	end
	
	ShadowUF.Config:Open()
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:SetScript("OnEvent", function(self, event)
	if( event == "PLAYER_ENTERING_WORLD" ) then
		ShadowUF:OnInitialize()
		self:UnregisterEvent("PLAYER_ENTERING_WORLD")
	end
end)

--@debug@
ShadowUFLocals = setmetatable(ShadowUFLocals, {
	__index = function(tbl, value)
		rawset(tbl, value, value)
		return value
	end,
})
--@end-debug@