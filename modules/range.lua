local Range = {
	friendly = {
		["PRIEST"] = GetSpellInfo(17), -- Power Word: Shield
		["DRUID"] = GetSpellInfo(8936), -- Regrowth
		["PALADIN"] = GetSpellInfo(19750), -- Flash of Light
		["SHAMAN"] = GetSpellInfo(8004), -- Healing Surge
		["WARLOCK"] = GetSpellInfo(5697), -- Unending Breath
		["MONK"] = GetSpellInfo(115450), -- Detox
        ["MAGE"] = GetSpellInfo(475), -- Remove Curse
	},
	hostile = {
		["DEATHKNIGHT"] = GetSpellInfo(49576), -- Death Grip
		["DEMONHUNTER"] = GetSpellInfo(185123), -- Throw Glaive
		["DRUID"] = GetSpellInfo(8921), -- Moonfire
		["HUNTER"] = GetSpellInfo(185358), -- Remove Curse
		["MAGE"] = GetSpellInfo(116), -- Frostbolt
		["MONK"] = GetSpellInfo(115546), -- Provoke
		["PALADIN"] = GetSpellInfo(62124), -- Hand of Reckoning
		["PRIEST"] = GetSpellInfo(589), -- Shadow Word: Pain
		["SHAMAN"] = GetSpellInfo(403), -- Lightning Bolt
		["WARLOCK"] = GetSpellInfo(686), -- Shadow Bolt
		["WARRIOR"] = GetSpellInfo(355), -- Taunt
	},
    resurrect = {
		["DEATHKNIGHT"] = GetSpellInfo(61999), -- Raise Ally
		["DRUID"] = GetSpellInfo(20484), -- Rebirth
		["MONK"] = GetSpellInfo(115178), -- Resuscitate
		["PALADIN"] = GetSpellInfo(7328), -- Redemption
		["PRIEST"] = GetSpellInfo(2006), -- Resurrection
		["SHAMAN"] = GetSpellInfo(2008), -- Ancestral Spirit
		["WARLOCK"] = GetSpellInfo(20707), -- Soulstone
	},
}

ShadowUF:RegisterModule(Range, "range", ShadowUF.L["Range indicator"])

local LSR = LibStub("SpellRange-1.0")

local playerClass = select(2, UnitClass("player"))
--local playerSpec = GetSpecialization()
--local playerSpecName = playerSpec and select(2, GetSpecializationInfo(playerSpec)) or "None"
local rangeSpells = {}

local function checkRange(self)
	local frame = self.parent

	-- Check which spell to use
	local spell
    local help = false
    local harm = false
	if( UnitCanAssist("player", frame.unit) ) then
        if UnitIsDeadOrGhost(frame.unit) then
            spell = rangeSpells.resurrect
        else 
            spell = rangeSpells.friendly
        end
        help = true
	elseif( UnitCanAttack("player", frame.unit) ) then
		spell = rangeSpells.hostile
        harm = true
	end
    
    if not UnitIsConnected(frame.unit) then
        frame:SetRangeAlpha(ShadowUF.db.profile.units[frame.unitType].range.inAlpha)
    elseif (UnitPhaseReason(frame.unit)) then
        frame:SetRangeAlpha(ShadowUF.db.profile.units[frame.unitType].range.oorAlpha)
    elseif (spell) then
        frame:SetRangeAlpha(LSR.IsSpellInRange(spell, frame.unit) == 1 and ShadowUF.db.profile.units[frame.unitType].range.inAlpha or ShadowUF.db.profile.units[frame.unitType].range.oorAlpha)
    elseif (UnitInRaid(frame.unit) or UnitInParty(frame.unit)) then
        frame:SetRangeAlpha(UnitInRange(frame.unit, "player") and ShadowUF.db.profile.units[frame.unitType].range.inAlpha or ShadowUF.db.profile.units[frame.unitType].range.oorAlpha)  
    else
        frame:SetRangeAlpha(CheckInteractDistance(frame.unit, 1) and ShadowUF.db.profile.units[frame.unitType].range.inAlpha or ShadowUF.db.profile.units[frame.unitType].range.oorAlpha)
    end
end

local function updateSpellCache(category)
	rangeSpells[category] = nil
	if( IsUsableSpell(ShadowUF.db.profile.range[category .. playerClass]) ) then
		rangeSpells[category] = ShadowUF.db.profile.range[category .. playerClass]

	elseif( IsUsableSpell(ShadowUF.db.profile.range[category .. "Alt" .. playerClass]) ) then
		rangeSpells[category] = ShadowUF.db.profile.range[category .. "Alt" .. playerClass]

	elseif( Range[category][playerClass] ) then
		--if( type(Range[category][playerClass]) == "table" ) then
		--	rangeSpells[category] = Range[category][playerClass][playerSpecName]
		--else
			rangeSpells[category] = Range[category][playerClass]
		--end
	end
end

local function createTimer(frame)
	if( not frame.range.timer ) then
		frame.range.timer = C_Timer.NewTicker(0.5, checkRange)
		frame.range.timer.parent = frame
	end
end

local function cancelTimer(frame)
	if( frame.range and frame.range.timer ) then
		frame.range.timer:Cancel()
		frame.range.timer = nil
	end
end

function Range:ForceUpdate(frame)
	if( UnitIsUnit(frame.unit, "player") ) then
		frame:SetRangeAlpha(ShadowUF.db.profile.units[frame.unitType].range.inAlpha)
		cancelTimer(frame)
	else
		createTimer(frame)
		checkRange(frame.range.timer)
	end
end

function Range:OnEnable(frame)
	if( not frame.range ) then
		frame.range = CreateFrame("Frame", nil, frame)
	end

	frame:RegisterNormalEvent("PLAYER_SPECIALIZATION_CHANGED", self, "SpellChecks")
	frame:RegisterUpdateFunc(self, "ForceUpdate")

	createTimer(frame)
end

function Range:OnLayoutApplied(frame)
	self:SpellChecks(frame)
end

function Range:OnDisable(frame)
	frame:UnregisterAll(self)

	if( frame.range ) then
		cancelTimer(frame)
		frame:SetRangeAlpha(1.0)
	end
end


function Range:SpellChecks(frame)
    --playerSpec = GetSpecialization()
    --playerSpecName = playerSpec and select(2, GetSpecializationInfo(playerSpec)) or "None"
	updateSpellCache("friendly")
	updateSpellCache("hostile")
    updateSpellCache("resurrect")
	if( frame.range ) then
		self:ForceUpdate(frame)
	end
end
