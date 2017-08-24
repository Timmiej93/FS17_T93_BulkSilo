Logger = {};

local metadata = {
"## Title: PlaceableBulkSilo",
"## Author: Timmiej93",
"## Version: 1.1.0",
"## Date: 22.01.2017",
"## LogAddition: ------------------------------ ",
"## LogAddition2: ----- "
}

local DebugLevel = 10
--  0: Default
--  1: Basic running tests
--  2: Basic creation info
--  3: Basic ID numbers etc.
--  4: Indepth numbers for comparing
-- 11: PlaceableBulkSilo spammy stuff
-- 12: Storage spammy stuff
-- 13: FillTrigger spammy stuff
-- 19: All spammy stuff

local DebugSelection = {0}
local selectionData = {
"## 999: TESTING",
"## 0: Default, everything",
"## 1: PlaceableBulkSilo",
"## 2: PlaceableBulkSilo_Storage",
"## 3: PlaceableBulkSilo_FillTrigger",
"## 4: PlaceableBulkSilo_SiloTrigger",
}

local function arrayContains(tab, val) for i,v in ipairs(tab) do if v == val then return true; end; end; return false; end;
local function getmdata(v) v="## "..v..": "; for i=1,table.getn(metadata) do local _,n=string.find(metadata[i],v);if n then return (string.sub (metadata[i], n+1)); end;end;end;
local function getseldata(v) v="## "..v..": "; for i=1,table.getn(selectionData) do local _,n=string.find(selectionData[i],v);if n then return (string.sub (selectionData[i], n+1)); end;end;end;

-- function Logger:Test(sel,string)
--     print((getmdata("LogAddition")..(getmdata("Title")).." v"..(getmdata("Version"))..":    "..(getseldata(sel)).." - TESTING:    "..tostring(string)))
-- end

-- function Logger:Debug(debug,sel,string)

-- end

-- function Logger:Error(sel,string)
--     print((getmdata("LogAddition")..(getmdata("Title")).." v"..(getmdata("Version"))..":    "..(getseldata(sel)).." - ERROR:    "..tostring(string)))
--     print(debug.traceback())
-- end

local function Debug(debug,sel,s,...) 
    if ((debug <= DebugLevel and ((arrayContains(DebugSelection, 0)) or (arrayContains(DebugSelection, sel)) or sel == -1)) or (sel == 999)) then 
        print(((DebugLevel > 0) and tostring(getmdata("LogAddition")) or tostring(getmdata("LogAddition2")))..tostring((getmdata("Title"))).." v"..tostring((getmdata("Version")))..":    "..tostring((getseldata(sel)))..":    "..tostring(string.format(s,...)));
    end;
end;


--------------------------------------------------------------------------------
-- 
-- 
-- 
-- Own functions
--
--
--
--------------------------------------------------------------------------------

PlaceableBulkSilo = {};
PlaceableBulkSilo_mt = Class(PlaceableBulkSilo, Placeable);
InitObjectClass(PlaceableBulkSilo, "PlaceableBulkSilo");

_gXMLFile = nil;

Debug(-1,-1, "Script starting...")
Debug(1,-1, "DebugLevel: "..DebugLevel)

function PlaceableBulkSilo:new(isServer, isClient, customMt)
	Debug(1,1, "New")
    local mt = customMt;
    if mt == nil then
        mt = PlaceableBulkSilo_mt;
    end;

    local self = Placeable:new(isServer, isClient, mt);
    registerObjectClassName(self, "PlaceableBulkSilo");

    self.siloCapacities = {[FillUtil.FILLTYPE_SEEDS] = 10000, [FillUtil.FILLTYPE_FERTILIZER] = 10000}

    self.bigBagPrices = {[FillUtil.FILLTYPE_SEEDS] = 0.9, [FillUtil.FILLTYPE_FERTILIZER] = 1.6}
	self.bulkDiscount = 0.9;   -- TODO probably make this an XML setting

    self.playerInRange = nil;
    self.vehiclesInRange = {};

    self.activeTriggers = {};
    self.fillable = nil;

    self.isPrecisionFilling = false;

    return self;
end;

function PlaceableBulkSilo:load(xmlFilename, x,y,z, rx,ry,rz, initRandom)
	Debug(1,1, "Load")

    if not PlaceableBulkSilo:superClass().load(self, xmlFilename, x,y,z, rx,ry,rz, initRandom) then
        return false;
    end

    local xmlFile = loadXMLFile("TempXML", xmlFilename);
    if xmlFile == 0 or xmlFile == nil then
    	Debug(-1,1, "No XML found, terminating script")
        return false;
    end

    _gXMLFile = xmlFile;

    self.customStorage = PlaceableBulkSilo_Storage:new(self.isServer, self.isClient)
    self.customStorage:load(self.nodeId, self.siloCapacities, self)

    -- self.trigger_Tool_Seeds_ID = Utils.indexToObject(self.nodeId, getXMLString(_gXMLFile, "placeable.bulkSilo#toolTrigger"));
    self.trigger_Tool_Seeds_ID = Utils.indexToObject(self.nodeId, getUserAttribute(self.nodeId,"fillTriggerTool"));
    Debug(3,1, "trigger_Tool_Seeds_ID: "..self.trigger_Tool_Seeds_ID)
    if self.trigger_Tool_Seeds_ID ~= nil then
        self.trigger_Tool_Seeds = PlaceableBulkSilo_FillTrigger:new(self.isServer, self.isClient, self.customStorage, self.siloCapacities, self.vehiclesInRange);
        if self.trigger_Tool_Seeds:load(self.trigger_Tool_Seeds_ID, FillUtil.FILLTYPE_SEEDS, self) then
            g_currentMission:addNonUpdateable(self.trigger_Tool_Seeds);
        else
            self.trigger_Tool_Seeds:delete();
        end;
    else
        Debug(-1,1, "ERROR: fillTriggerTool index is nil!")
        return false;
    end

    -- self.trigger_Tool_Fertilizer_ID = Utils.indexToObject(self.nodeId, getXMLString(_gXMLFile, "placeable.bulkSilo#toolTriggerFertilizer"));
    -- Debug(3,1, "trigger_Tool_Fertilizer_ID: "..self.trigger_Tool_Seeds_ID)
    -- self.trigger_Tool_Fertilizer = PlaceableBulkSilo_FillTrigger:new(self.isServer, self.isClient, self.customStorage, self.siloCapacities, self.vehiclesInRange);
    -- if self.trigger_Tool_Fertilizer:load(self.trigger_Tool_Seeds_ID, FillUtil.FILLTYPE_FERTILIZER, self) then
    --     g_currentMission:addNonUpdateable(self.trigger_Tool_Fertilizer);
    -- else
    --     self.trigger_Tool_Fertilizer:delete();
    -- end;

    -- self.trigger_Trailer_ID = Utils.indexToObject(self.nodeId, getXMLString(_gXMLFile, "placeable.bulkSilo#trailerTrigger"));
    self.trigger_Trailer_ID = Utils.indexToObject(self.nodeId, getUserAttribute(self.nodeId,"fillTriggerTrailer"));
    if self.trigger_Trailer_ID ~= nil then
        Debug(3,1, "trigger_Trailer_ID: "..self.trigger_Trailer_ID)
    else
        Debug(-1,1, "ERROR: fillTriggerTrailer index is nil!")
        return false;
    end
    return true;
end

function PlaceableBulkSilo:finalizePlacement()
	Debug(1,1, "finalizePlacement")

    PlaceableBulkSilo:superClass().finalizePlacement(self);

    g_currentMission:addStorage(self.customStorage);
    self.customStorage:register(true)

    for k,v in pairs(self.siloCapacities) do
        self.customStorage:setFillLevel(self.siloCapacities[k], k)
    end

    self.trigger_Trailer = PlaceableBulkSilo_SiloTrigger:new(self.isServer, self.isClient, self);
    self.trigger_Trailer:load(self.trigger_Trailer_ID);
    self.trigger_Trailer:register(true)
    g_currentMission:addStorageToSiloTrigger(self.customStorage, {self.trigger_Trailer})

    local PlayerTriggerIndex = getUserAttribute(self.nodeId,"playerTriggerIndex");
    if PlayerTriggerIndex ~= nil then
        local PlayerTrigger = Utils.indexToObject(self.nodeId, PlayerTriggerIndex);
        if PlayerTrigger ~= nil then
            self.trigger_Player = PlayerTrigger;
            addTrigger(self.trigger_Player, "PlayerTriggerCallback", self);
            Debug(2,1, "PlayerTrigger created")
        end;
    end;
end;

function PlaceableBulkSilo:delete()
	Debug(1,1, "delete")
    if self.trigger_Trailer ~= nil then
        self.trigger_Trailer:unregister(true);
        self.trigger_Trailer:delete()
    end
    if self.trigger_Tool_Seeds ~= nil then
        self.trigger_Tool_Seeds:delete();
    end
    if self.trigger_Tool_Fertilizer ~= nil then
        self.trigger_Tool_Fertilizer:delete();
    end
    if self.trigger_Player ~= nil then
        removeTrigger(self.trigger_Player)
    end
    if self.customStorage ~= nil then
        g_currentMission:removeStorage(self.customStorage)
        self.customStorage:unregister(true);
        self.customStorage:delete()
    end

    unregisterObjectClassName(self);
    PlaceableBulkSilo:superClass().delete(self);
end;

function PlaceableBulkSilo:PlayerTriggerCallback(triggerId, otherId, onEnter, onLeave, onStay)
    Debug(11,1, "PlayerTriggerCallback")
    if (g_currentMission.controlPlayer and g_currentMission.player and otherId == g_currentMission.player.rootNode) then
        if (onEnter) then 
            self.playerInRange = true;
            Debug(2,1, "Player entered trigger")
        elseif (onLeave) then
            self.playerInRange = false;
            Debug(2,1, "Player left trigger")
        end;
    end;
end;

function PlaceableBulkSilo:getShowInfo()
    if (g_currentMission.controlPlayer and self.playerInRange) then
        Debug(11,1, "getShowInfo: True player")
        return true, true;
    end;
    if not g_currentMission.controlPlayer then
        if g_gui:getIsGuiVisible() or g_currentMission.isPlayerFrozen then
            Debug(11,1, "getShowInfo: Blocked by GUI visibility or Frozen player (?)")
            return false;
        end;
        if activeIfIngameMessageShown == nil or activeIfIngameMessageShown == false then
            if g_currentMission.inGameMessage:getIsVisible() then
                Debug(11,1, "getShowInfo: Blocked by inGameMessage")
                return false;
            end
        end
        for vehicle in pairs(self.vehiclesInRange) do
        	if (vehicle ~= nil) and (vehicle.getIsAttachedTo ~= nil) then
            	if (vehicle == g_currentMission.controlledVehicle) or (vehicle:getIsAttachedTo(g_currentMission.controlledVehicle)) then
                	Debug(11,1, "getShowInfo: True vehicle")
                	return true, false;
                end
            end
        end;
    end;
	Debug(11,1, "getShowInfo: False")
    return false;
end;

function PlaceableBulkSilo:update(dt)
    PlaceableBulkSilo:superClass().update(self, dt);
    local showInfo, isPlayer = self:getShowInfo();
    if showInfo then
    	local seedFillLevel = self.customStorage:getFillLevel(FillUtil.FILLTYPE_SEEDS)
    	local fertilizerFillLevel = self.customStorage:getFillLevel(FillUtil.FILLTYPE_FERTILIZER)
    	Debug(11,1, "Seeds: "..tostring(seedFillLevel).." - Fertilizer: "..tostring(fertilizerFillLevel))
        g_currentMission:addExtraPrintText(g_i18n:getText("F1_UI_SeedFillLevel").." "..math.floor(seedFillLevel).." / "..self.siloCapacities[FillUtil.FILLTYPE_SEEDS].." ("..math.floor(100*seedFillLevel/self.siloCapacities[FillUtil.FILLTYPE_SEEDS]).."%)");
        g_currentMission:addExtraPrintText(g_i18n:getText("F1_UI_FertilizerFillLevel").." "..math.floor(fertilizerFillLevel).." / "..self.siloCapacities[FillUtil.FILLTYPE_FERTILIZER].." ("..math.floor(100*fertilizerFillLevel/self.siloCapacities[FillUtil.FILLTYPE_FERTILIZER]).."%)");
    end;

    if isPlayer then
        g_currentMission:addHelpButtonText(g_i18n:getText("F1_UI_TEMP_InstantRefill"), InputBinding.TEMP_InstantRefill);

        if InputBinding.hasEvent(InputBinding.TEMP_InstantRefill) then
            self:TEMP_InstantRefill()
        end
    end
end;

function PlaceableBulkSilo:TEMP_InstantRefill()
    for k,v in pairs(self.siloCapacities) do
        if k ~= nil then
            self.customStorage:setFillLevel(self.siloCapacities[k], k, true)
        end
    end
end

function PlaceableBulkSilo:loadFromAttributesAndNodes(xmlFile, key, resetVehicles)
    Debug(1,1, "loadFromAttributesAndNodes")
    if not PlaceableBulkSilo:superClass().loadFromAttributesAndNodes(self, xmlFile, key, resetVehicles) then
        return false;
    end;

    if not self.customStorage:loadFromAttributesAndNodes(xmlFile, key) then
        return false
    end

    return true;
end;

function PlaceableBulkSilo:getSaveAttributesAndNodes(nodeIdent)
    Debug(1,1, "getSaveAttributesAndNodes")
    local attributes, nodes = PlaceableBulkSilo:superClass().getSaveAttributesAndNodes(self, nodeIdent);

    local a, n = self.customStorage:getSaveAttributesAndNodes(nodeIdent)
    attributes = attributes .. " " .. a
    nodes = nodes .. n

    return attributes, nodes;
end;

function PlaceableBulkSilo:dayChanged()
    Debug(1,1, "Day changed, refilled silos")
    for k,v in pairs(self.siloCapacities) do
        if k ~= nil then
            self.customStorage:setFillLevel(self.siloCapacities[k], k, true)
        end
    end
end;

function PlaceableBulkSilo:fill(acceptedFillTypes, fillable)    -- Checks amount of accepted filltypes. If 1, fill. If more, dialog
    self.fillable = fillable;

    if (tableSize(acceptedFillTypes) == 1) then     -- Only one filltype is accepted, no dialog needed
        self.trigger_Tool_Seeds:setFillType(acceptedFillTypes[1])
        self.fillable.fillTrigger = self.trigger_Tool_Seeds;
        self.fillable.isFilling = true;

        self:precisionFillingEffectCheck(acceptedFillTypes[1])
    elseif (tableSize(acceptedFillTypes) > 1) then  -- Multiple filltypes accepted, dialog needed
        self:showBulkSiloDialog_Trigger(self.fillable);
    end
end

function PlaceableBulkSilo:showBulkSiloDialog_Trigger(fillable) -- Show dialog
    local fillLevels, capacity = self.trigger_Trailer:getAllFillLevels();

    g_gui:showSiloDialog({title=string.format("%s", "BulkSiloTestTitle"), fillLevels=fillLevels, capacity=capacity, callback=self.reactToBulkSiloDialog_Trigger, target=self})
end

function PlaceableBulkSilo:reactToBulkSiloDialog_Trigger(fillType)  -- React to dialog
    if fillType ~= nil and fillType ~= FillUtil.FILLTYPE_UNKNOWN then
        self.trigger_Tool_Seeds:setFillType(fillType)
        self.fillable.fillTrigger = self.trigger_Tool_Seeds;
        self.fillable.isFilling = true;

        self:precisionFillingEffectCheck(fillType)
    end;
end

function PlaceableBulkSilo:precisionFillingEffectCheck(fillType)     -- Only do precision filling if all triggers are triggered
    if (tableSize(self.activeTriggers) >= 4) then
        self:precisionFilling(true, fillType)       -- Just visual
    else
        self:precisionFilling(false, FillUtil.FILLTYPE_UNKNOWN)
    end
end

function PlaceableBulkSilo:precisionFilling(isFilling, fillType)
    Debug(1,4, "precisionFilling")
    Debug(1,4, "isfilling: "..tostring(isFilling).." - filltype: "..tostring(fillType))
    if isFilling then
        self:precisionFillingStart(fillType);
    else
        self:precisionFillingStop();
    end;
end;

function PlaceableBulkSilo:precisionFillingStart(fillType)
    Debug(1,4, "precisionFillingStart")

    if not self.isPrecisionFilling then
        self.isPrecisionFilling = true;

        if self.trigger_Trailer.dropParticleSystems ~= nil then
            for _, ps in pairs(self.trigger_Trailer.dropParticleSystems) do
                ParticleUtil.setEmittingState(ps, true);
            end
        end
        if self.trigger_Trailer.lyingParticleSystems ~= nil then
            for _, ps in pairs(self.trigger_Trailer.lyingParticleSystems) do
                ParticleUtil.setParticleSystemTimeScale(ps, 1.0);
            end
        end
        if self.trigger_Trailer.dropEffects ~= nil then
            EffectManager:setFillType(self.trigger_Trailer.dropEffects, fillType)
            EffectManager:startEffects(self.trigger_Trailer.dropEffects);
        end;

        if self.trigger_Trailer.scroller ~= nil then
            setShaderParameter(self.trigger_Trailer.scroller, self.trigger_Trailer.scrollerShaderParameterName, self.trigger_Trailer.scrollerSpeedX, self.trigger_Trailer.scrollerSpeedY, 0, 0, false);
        end
    end
end

function PlaceableBulkSilo:precisionFillingStop()
    Debug(1,4, "precisionFillingStop")

    if self.isPrecisionFilling then
        self.isPrecisionFilling = false;

        if self.trigger_Trailer.dropParticleSystems ~= nil then
            for _, ps in pairs(self.trigger_Trailer.dropParticleSystems) do
                ParticleUtil.setEmittingState(ps, false);
            end
        end
        if self.trigger_Trailer.lyingParticleSystems ~= nil then
            for _, ps in pairs(self.trigger_Trailer.lyingParticleSystems) do
                ParticleUtil.setParticleSystemTimeScale(ps, 0);
            end
        end
        if self.trigger_Trailer.dropEffects ~= nil then
            EffectManager:stopEffects(self.trigger_Trailer.dropEffects);
        end;
        if self.trigger_Trailer.scroller ~= nil then
            setShaderParameter(self.trigger_Trailer.scroller, self.trigger_Trailer.scrollerShaderParameterName, 0, 0, 0, 0, false);
        end
    end;
end

function PlaceableBulkSilo:custom_FillableSetIsFilling(superFunc, isFilling, noEventSend)
    local BulkSiloTriggers = {};

    for _, trigger in ipairs(self.fillTriggers) do
        if (trigger["fillTriggerName"] ~= nil and trigger["fillTriggerName"] == "PlaceableBulkSilo_FillTrigger") then
            table.insert(BulkSiloTriggers, trigger)
        end
    end
    local BulkSiloTriggersSize = tableSize(BulkSiloTriggers)

    if (BulkSiloTriggersSize > 0) then
        -- BulkSiloTrigger found
        -- Do special behaviour

        SetIsFillingEvent.sendEvent(self, isFilling, noEventSend)
        if self.isFilling ~= isFilling then

            if isFilling then
                if (BulkSiloTriggersSize > 1) then
                    Debug(-1,1, "Multiple BulkSilos found! Not good!")
                    -- TODO error message?
                end

                local acceptedFillTypes = {};
                self.fillTrigger = BulkSiloTriggers[1];                 -- Force the first trigger in the list to be the trigger. Should be fine, since you normally only have one
                for k,_ in pairs(self.fillTrigger.fillTriggerCapacities) do     -- for each fillType in the silo do
                    if (self:allowFillType(k, false)) then         -- if silo fillType allowed, add to acceptedFillTypes list
                        table.insert(acceptedFillTypes, k)
                    end
                end

                self.fillTrigger.parent:fill(acceptedFillTypes, self)
            else
                self.isFilling = false;
                self.fillTrigger.parent:precisionFilling(false, FillUtil.FILLTYPE_UNKNOWN)
                self.fillTrigger = nil;
            end
        end

    else
        -- No BulkSiloTriggerfound
        -- Do normal behaviour

        if superFunc ~= nil then
            superFunc(self, isFilling, noEventSend)
        end
    end
end

--------------------------------------------------------------------------------
-- 
-- 
-- 
-- Storage functions
--
--
--
--------------------------------------------------------------------------------

PlaceableBulkSilo_Storage = {};
PlaceableBulkSilo_Storage_mt = Class(PlaceableBulkSilo_Storage, Object);
InitObjectClass(PlaceableBulkSilo_Storage, "PlaceableBulkSilo_Storage");

function PlaceableBulkSilo_Storage:new(isServer, isClient)
    Debug(1,2, "new")
    mt = PlaceableBulkSilo_Storage_mt;

    local self = Object:new(isServer, isClient, mt);

    self.tipTriggers = {}
    self.siloTriggers = {}
    self.rootNode = 0;

    return self;
end

function PlaceableBulkSilo_Storage:load(id, capacityArray, parent)
    Debug(1,2, "load")

	self.rootNode = id;
    self.ownsRootNode = false;
    self.parent = parent;

    self.storageName = "BulkSilo";
    -- self.capacity = 10000
    self.capacities = capacityArray;
    self.costsPerFillLevelAndDay = 0;

    self.sortedFillTypes = {};
    self.fillLevels = {};
    self.fillTypes = {};

    for k,v in pairs(self.capacities) do
        self.fillLevels[k] = 0
        self.fillTypes[k] = k;
    end

    self.loadedValues = {}

    self.movingNode = nil;
    self.saveId = Utils.getNoNil(getUserAttribute(id, "saveId"), "Storage_"..getName(id));

    self.storageDirtyFlag = self:getNextDirtyFlag();
	return true;
end

function PlaceableBulkSilo_Storage:setFillLevel(fillLevel, fillType, fillable)
    Debug(1,2, "setFillLevel "..fillLevel)
    fillLevel = Utils.clamp(fillLevel, 0, self.capacities[fillType]);
    if self.fillLevels[fillType] ~= nil and fillLevel ~= self.fillLevels[fillType] then
        self.fillLevels[fillType] = fillLevel;
        if self.isServer then
            self:raiseDirtyFlags(self.storageDirtyFlag);
        end
    end
end

function PlaceableBulkSilo_Storage:getFillLevel(fillType)
    return self.fillLevels[fillType];
end

function PlaceableBulkSilo_Storage:loadFromAttributesAndNodes(xmlFile, key)
    Debug(1,2, "loadFromAttributesAndNodes")
    local i = 0;
    while true do
        local siloKey = string.format(key .. ".node(%d)", i);
        if not hasXMLProperty(xmlFile, siloKey) then
            break;
        end
        local fillTypeStr = getXMLString(xmlFile, siloKey.."#fillType");
        local fillLevel = math.max(Utils.getNoNil(getXMLFloat(xmlFile, siloKey.."#fillLevel"), 0), 0);
        local fillType = FillUtil.fillTypeNameToInt[fillTypeStr];
        if fillType ~= nil then
            if self.fillLevels[fillType] ~= nil then
                self:setFillLevel(fillLevel, fillType, nil);
            else
                print("Warning: Filltype '"..fillTypeStr.."' not supported by Storage "..getName(self.rootNode));
            end
        else
            print("Error: Invalid filltype '"..fillTypeStr.."'");
        end
        i = i + 1;
    end
    return true;
end

function PlaceableBulkSilo_Storage:getSaveAttributesAndNodes(nodeIdent)
    Debug(1,2, "getSaveAttributesAndNodes")
    local attributes = "";
    local nodes = "";

    local n = 0;
    for fillType, fillLevel in pairs(self.fillLevels) do
        if n > 0 then
            nodes = nodes .. "\n";
        end
        local fillTypeName = FillUtil.fillTypeIntToName[fillType];
        nodes = nodes .. '       <node fillType="'..tostring(fillTypeName)..'" fillLevel="'..tostring(fillLevel)..'" capacity="'..tostring(self.capacities[fillType])..'"/>';
        n = n + 1;
    end
    return attributes, nodes;
end

function PlaceableBulkSilo_Storage:addTipTrigger(tipTrigger)
    Debug(1,2, "addTipTrigger")
    self.tipTriggers[tipTrigger] = tipTrigger
    if tipTrigger ~= nil and tipTrigger.acceptedFillTypes ~= nil then
        for fillType, enabled in pairs(tipTrigger.acceptedFillTypes) do
            if enabled then
                self:addFillType(fillType)
            end
        end
    end
end

function PlaceableBulkSilo_Storage:removeTipTrigger(tipTrigger)
    self.tipTriggers[tipTrigger] = nil
end

function PlaceableBulkSilo_Storage:addSiloTrigger(siloTrigger)
    self.siloTriggers[siloTrigger] = siloTrigger
end

function PlaceableBulkSilo_Storage:removeSiloTrigger(siloTrigger)
    self.siloTriggers[siloTrigger] = nil
end

--------------------------------------------------------------------------------
--
--
--
-- Filltrigger functions
--
--
--
--------------------------------------------------------------------------------

PlaceableBulkSilo_FillTrigger = {};
PlaceableBulkSilo_FillTrigger_mt = Class(PlaceableBulkSilo_FillTrigger, Trigger);
InitObjectClass(PlaceableBulkSilo_FillTrigger, "PlaceableBulkSilo_FillTrigger");

function PlaceableBulkSilo_FillTrigger:new(isServer, isClient, storage, capacities, vehiclesInRange)
    Debug(1,3, "new")
    mt = PlaceableBulkSilo_FillTrigger_mt;

    if storage == nil then
        Debug(-1,3, "No storage entered for filltrigger, terminating script.")
        return;
    end

    local self = Object:new(isServer, isClient, mt);

    self.fillTriggerName = "PlaceableBulkSilo_FillTrigger";

    self.fillTriggerStorage = storage;
    self.fillTriggerCapacities = capacities;
    self.vehiclesInRange = vehiclesInRange;

    self.bulkSiloFillType = FillUtil.FILLTYPE_UNKNOWN;

    self.triggerId = 0;
    self.precisionTriggerIds = {};
    self.financeCategory = "other";

    self.moneyChangeId = getMoneyTypeId();

    return self;
end;

function PlaceableBulkSilo_FillTrigger:load(nodeId, fillType, parent)
    Debug(1,3, "load")
    self.triggerId = nodeId;

    -- Add big box trigger
    addTrigger(self.triggerId, "triggerCallback", self);

    -- Add precision trigger
    for i=1, 4 do
        local child = getChildAt(self.triggerId, (i+1))
        table.insert(self.precisionTriggerIds, child)
        addTrigger(child, "precisionTriggerCallback", self)
    end

    if fillType ~= nil then
        self.fillType = fillType;
    else
        self.fillType = FillUtil.FILLTYPE_UNKNOWN;
        local fillTypeStr = getUserAttribute(self.triggerId, "fillType");
        if fillTypeStr ~= nil then
            local desc = FillUtil.fillTypeNameToDesc[fillTypeStr];
            if desc ~= nil then
                self.fillType = desc.index;
            end;
        end
    end;

    self.parent = parent;
    self.fillableObjects = {};
    self.isEnabled = true;

    return true;
end;

function PlaceableBulkSilo_FillTrigger:delete()
    Debug(1,3, "delete")
    removeTrigger(self.triggerId);
    for i=1, table.getn(self.precisionTriggerIds) do
        removeTrigger(self.precisionTriggerIds[i]);
    end
    for _,fillable in pairs(self.fillableObjects) do
        if fillable ~= nil then
            fillable:removeFillTrigger(self);
        end
    end
end;

function PlaceableBulkSilo_FillTrigger:getIsActivatable(fillable)
    Debug(12,3, "getIsActivatable")
	for k,v in pairs(self.fillTriggerCapacities) do
        if k ~= nil then
            if fillable:allowFillType(k, false) then
                return true;
            end;
		end;
	end
	return false;	
end;

function PlaceableBulkSilo_FillTrigger:triggerCallback(triggerId, otherActorId, onEnter, onLeave, onStay, otherShapeId)
    Debug(12,3, "triggerCallback")
    for k,v in pairs(self.fillTriggerCapacities) do
        if k ~= nil then
            if self.isEnabled and (onEnter or onLeave) then
                local fillable = Utils.getNoNil(g_currentMission.objectToTrailer[otherShapeId], g_currentMission.objectToTrailer[otherActorId]);
                if fillable ~= nil and fillable.addFillTrigger ~= nil and fillable.removeFillTrigger ~= nil and fillable ~= self.parent then
                    if onEnter then
                        if fillable:allowFillType(k, false) and self.fillableObjects[fillable] == nil then
                            fillable:addFillTrigger(self);
                            self.fillableObjects[fillable] = fillable;
                        end
                    elseif onLeave then
                        fillable:removeFillTrigger(self);
                        g_currentMission:showMoneyChange(self.moneyChangeId, g_i18n:getText("finance_"..self.financeCategory));
                        self.fillableObjects[fillable] = nil;
                    end;
                end;
            end;
        end;
    end;

    if not g_currentMission.player ~= nil then
        local vehicle = g_currentMission.nodeToVehicle[otherActorId];
        if vehicle ~= nil then
            if onEnter then
                self.vehiclesInRange[vehicle] = true;
            else
                self.vehiclesInRange[vehicle] = nil;
            end;
        end;
    end
end;

function PlaceableBulkSilo_FillTrigger:precisionTriggerCallback(triggerId, otherActorId, onEnter, onLeave, onStay, otherShapeId)
    Debug(12,3, "precisionTriggerCallback")
	for k,v in pairs(self.fillTriggerCapacities) do
        if k ~= nil then
    	    if self.isEnabled and (onEnter or onLeave) then
    	        local fillable = Utils.getNoNil(g_currentMission.objectToTrailer[otherShapeId], g_currentMission.objectToTrailer[otherActorId]);
    	        if fillable ~= nil and fillable.addFillTrigger ~= nil and fillable.removeFillTrigger ~= nil and fillable ~= self.parent then
    	            if onEnter then
                        if fillable:allowFillType(k, false) then
                            self.parent.activeTriggers[triggerId] = true;
                        end
    	            elseif onLeave then
                        self.parent:precisionFilling(false, FillUtil.FILLTYPE_UNKNOWN)
                        self.parent.activeTriggers[triggerId] = nil;
                        if fillable.setIsFilling ~= nil then
                        	fillable:setIsFilling(false)
                        end
    	            end;
    	        end;
    	    end;
        end;
    end;
end;

function PlaceableBulkSilo_FillTrigger:fill(tool, delta)
    Debug(12,3, "fill")

	local fillType = self.bulkSiloFillType
	local fillAllowed = false;

    local testvalue = self.fillTriggerStorage:getFillLevel(fillType)

	local siloFillLevel = testvalue
    if not (siloFillLevel > 0) then
    	Debug(1,3, "Silo empty")
        return 0.0;
    end

    local oldFillLevel = tool:getFillLevel(fillType);

    tool:setFillLevel(oldFillLevel + delta, fillType, true);
    delta = tool:getFillLevel(fillType) - oldFillLevel;

    if not (siloFillLevel > 0) then
    	Debug(1,3, "Silo is empty")
        -- TODO add popup
    	return 0.0
    end

    self.fillTriggerStorage:setFillLevel(siloFillLevel - delta, fillType, true)

    local price = delta * (self.parent.bigBagPrices[fillType] * self.parent.bulkDiscount);
    self.financeCategory = "other";
    if fillType == FillUtil.FILLTYPE_SEEDS then
        self.financeCategory = "purchaseSeeds";
    elseif self.fillType == FillUtil.FILLTYPE_FERTILIZER then
        self.financeCategory = "purchaseFertilizer";
    end
    g_currentMission.missionStats:updateStats("expenses", price);
    g_currentMission:addSharedMoney(-price, self.financeCategory);
    g_currentMission:addMoneyChange(-price, self.moneyChangeId);

    return delta;
end

function PlaceableBulkSilo_FillTrigger:setFillType(fillType)
    self.bulkSiloFillType = fillType;
end

--------------------------------------------------------------------------------
--
--
--
-- SiloTrigger
--
--
--
--------------------------------------------------------------------------------

PlaceableBulkSilo_SiloTrigger = {};
PlaceableBulkSilo_SiloTrigger_mt = Class(PlaceableBulkSilo_SiloTrigger, SiloTrigger);
InitObjectClass(PlaceableBulkSilo_SiloTrigger, "PlaceableBulkSilo_SiloTrigger");

function PlaceableBulkSilo_SiloTrigger:new(isServer, isClient, parent)
    Debug(1,4, "new")
    local self = Object:new(isServer, isClient, PlaceableBulkSilo_SiloTrigger_mt);
    self.parent = parent;
    self.rootNode = 0;

    self.activeTriggers = 0;

   	self.financeCategory = "other";
    self.moneyChangeId = getMoneyTypeId();

    self.siloTriggerIgnore = {"sowingMachine", "sowingMachineSprayer", "sprayer_animated"}

    self.siloTriggerDirtyFlag = self:getNextDirtyFlag();
    g_currentMission:addSiloTrigger(self);
    return self;
end;

function PlaceableBulkSilo_SiloTrigger:updateFillTypes()
    Debug(1,4, "updateFillTypes")
    self.fillTypes = {};
    if self.siloSources ~= nil then
        for siloSource,_ in pairs(self.siloSources) do -- for each Storage in SiloSources
            for fillType,_ in pairs(siloSource.fillTypes) do -- for each filltype in the Storage
                self.fillTypes[fillType] = fillType;
            end;
        end;
    end;
 end;

function PlaceableBulkSilo_SiloTrigger:getAllFillLevels()
    Debug(1,4, "getAllFillLevels")
    local fillLevels = {};
    local capacity = 0

    for siloSource,_ in pairs(self.siloSources) do
        for fillType, fillLevel in pairs(siloSource.fillLevels) do
            fillLevels[fillType] = Utils.getNoNil(fillLevels[fillType], 0) + fillLevel;
        end;
        for _,capacityPerFillType in pairs(siloSource.capacities) do
            capacity = capacity + capacityPerFillType;
        end
    end;
    return fillLevels, capacity;
end;

function PlaceableBulkSilo_SiloTrigger:update(dt)
    if self.isServer then
        local trailer = self.siloTrailer;
        if self.activeTriggers >= 4 and trailer ~= nil then
            if self.isFilling then
                trailer:resetFillLevelIfNeeded(self.selectedFillType);
                local fillLevel = trailer:getFillLevel(self.selectedFillType);

                local siloAmount, siloSource = self:getFillLevelTarget(self.selectedFillType);
                if siloAmount > 0 and trailer:allowFillType(self.selectedFillType, false) and trailer:getAllowFillFromAir() then
                    local deltaFillLevel = math.min(self.fillLitersPerSecond*0.001*dt, siloAmount);
                    trailer:setFillLevel(fillLevel+deltaFillLevel, self.selectedFillType, false, self.fillVolumeDischargeInfos);
                    local newFillLevel = trailer:getFillLevel(self.selectedFillType);

                    if fillLevel ~= newFillLevel then
                        siloSource:setFillLevel(math.max(siloAmount-(newFillLevel-fillLevel), 0), self.selectedFillType, trailer);
                    else
                        self:setIsFilling(false, FillUtil.FILLTYPE_UNKNOWN);
                    end;

				    local price = deltaFillLevel * (self.parent.bigBagPrices[self.selectedFillType] * self.parent.bulkDiscount);
				    self.financeCategory = "other";
				    if fillType == FillUtil.FILLTYPE_SEEDS then
				        self.financeCategory = "purchaseSeeds";
				    elseif self.fillType == FillUtil.FILLTYPE_FERTILIZER then
				        self.financeCategory = "purchaseFertilizer";
				    end
				    g_currentMission.missionStats:updateStats("expenses", price);
				    g_currentMission:addSharedMoney(-price, self.financeCategory);
				    g_currentMission:addMoneyChange(-price, self.moneyChangeId);
                else
                    self:setIsFilling(false, FillUtil.FILLTYPE_UNKNOWN);
                end;
            end;
        elseif self.isFilling then
            self:setIsFilling(false, FillUtil.FILLTYPE_UNKNOWN);
        end;

        if self.siloTrailerSend ~= self.siloTrailer then
            self.siloTrailerSend = self.siloTrailer;
            self:raiseDirtyFlags(self.siloTriggerDirtyFlag);
        end;
    end;
end;

function PlaceableBulkSilo_SiloTrigger:triggerCallback(triggerId, otherActorId, onEnter, onLeave, onStay, otherShapeId)
    if self.isEnabled then
        local trailer = g_currentMission.objectToTrailer[otherActorId];
        if trailer ~= nil and otherActorId == trailer.exactFillRootNode and self:getIsValidTrailer(trailer) then
    		if (trailer.typeName ~= nil and not tableContains(self.siloTriggerIgnore, trailer.typeName)) then  -- probably not optimal way to check if it is a tool or not
	            if onEnter and trailer.getAllowFillFromAir ~= nil then
	                self.activeTriggers = self.activeTriggers + 1;
	                self.siloTrailer = trailer;
	                g_currentMission:addActivatableObject(self);

	                if self.activeTriggers >= 4 then
	                    if self.siloTrailer.coverAnimation ~= nil and self.siloTrailer.autoReactToTrigger == true then
	                        self.siloTrailer:setCoverState(true);
	                    end
	                end
	            elseif onLeave then
	                if self.siloTrailer ~= nil and self.siloTrailer.coverAnimation ~= nil and self.siloTrailer.autoReactToTrigger == true then
	                    self.siloTrailer:setCoverState(false);
	                end

	                self.activeTriggers = math.max(self.activeTriggers - 1, 0);
	                self.siloTrailer = nil;
	                self:setIsFilling(false, FillUtil.FILLTYPE_UNKNOWN);
	                g_currentMission:removeActivatableObject(self);

	                g_currentMission:showMoneyChange(self.moneyChangeId, g_i18n:getText("finance_"..self.financeCategory));
	            end;
	        end
        end;
    end;
end;


--------------------------------------------------------------------------------
--
--
--
-- Register
--
--
--
--------------------------------------------------------------------------------

registerPlaceableType("placeableBulkSilo", PlaceableBulkSilo);
Fillable.setIsFilling = Utils.overwrittenFunction(Fillable.setIsFilling, PlaceableBulkSilo.custom_FillableSetIsFilling);


--------------------------------------------------------------------------------
--
--
--
-- Custom functions
--
--
--
--------------------------------------------------------------------------------

function tableSize(table)
    local count = 0;
    for k,v in pairs(table) do
        count = count + 1
    end
    return count
end

function tableContains(table, value)
	for k,v in pairs(table) do
		if (v == value) then
			return true
		end
	end
	return false
end

function tableContainsTable(table, checkTable)
	for k1,v1 in pairs(table) do
		for k2,v2 in pairs(checkTable) do
			if (v == v2) then
				return true
			end
		end
	end
	return false
end