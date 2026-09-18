-- ============================================================
-- FS25_Employees.lua
-- by Marcus (Cobra Modding)
-- 
--
-- Version 1.0.0.0
--
--
-- Keine Änderung am Skript ohne meine Erlaubnis
-- ============================================================

Employees = {directory=g_currentModDirectory}
local M = Employees
M.modVersion = "1.0.0.0"

M.contracts = {
    {name="Geringfuegig", salary=600, hours=40},
    {name="Teilzeit", salary=1600, hours=80},
    {name="Vollzeit", salary=3200, hours=160},
	{name="Leiharbeiter", salary=120, hours=8, temporary=true}
}
M.maxEmployees = 10
M.roster = {
    {name="Robin Schmitz",  age=24, helper="A"},
    {name="Sophie Kleinert",  age=19, helper="B"},
    {name="Jabari Ochieng",  age=38, helper="C"},
    {name="Ling Chen",  age=22, helper="D"}, 
    {name="Niklas Jäger",  age=41, helper="E"}, 
    {name="Imani Bekele",  age=32, helper="F"}, 
    {name="Pablo García",  age=29, helper="G"}, 
    {name="Lisa Schneider",  age=49, helper="H"},
    {name="Bao Zhang",  age=33, helper="I"},
    {name="Valeria Rodríguez",  age=34, helper="J"},
}

M.trainingTypes = {
    {key="fieldwork", label="Feldarbeit", maxLevel=3},
    {key="transport", label="Transport", maxLevel=3},
    {key="animals", label="Tierhaltung", maxLevel=3},
    {key="machinery", label="Maschinentechnik", maxLevel=3}
}
M.trainingBaseCost = 750
M.trainingHours = {2, 5, 8}
M.trainingSpeedByLevel = {[0]=0.25, [1]=0.50, [2]=0.75, [3]=1.00}

M.roles = {
    {key="none", label="Nicht zugewiesen"},
    {key="fieldwork", label="Feldarbeit"},
    {key="transport", label="Transport"},
    {key="animals", label="Tierhaltung"},
    {key="machinery", label="Maschinentechnik"}
}
M.animalServiceThreshold = 0.20
M.animalServiceTarget = 0.95
M.pigletFeedMaxAgeMonths = 6
M.animalCheckHours = {8, 17}
M.machineWorkStartHour = 8
M.machineWorkEndHour = 17
M.machineRepairThreshold = 0.20
M.autoServiceIntervalMs = 10000
M.animalServiceHours = 0.25
M.machineServiceHours = 0.50
M.repairNoticeDurationMs = 7000
M.retirementAge = 65
M.illnessMonthlyChance = 0.03
M.illnessTypes = {
    {key="cold", label="Erkältung", minHours=4, maxHours=8, weight=40},
    {key="stomach", label="Magen-Darm", minHours=6, maxHours=12, weight=25},
    {key="flu", label="Grippe", minHours=12, maxHours=20, weight=25},
    {key="back", label="Rückenprobleme", minHours=16, maxHours=32, weight=10}
}

M.notificationProblemColor = {1.0, 0.72, 0.05, 1.0}

function M:notify(text, color)
    if g_currentMission == nil then return end
    if self.isServer == true and self.isMultiplayer == true and g_client == nil then
        if Logging ~= nil and Logging.info ~= nil then Logging.info("[Employees] %s", tostring(text)) end
        return
    end
    g_currentMission:addIngameNotification(color or FSBaseMission.INGAME_NOTIFICATION_INFO, text)
end

function M:notifyProblem(text)
    self:notify(text, self.notificationProblemColor)
end

function M:formatDurationHours(hours)
    local totalMinutes = math.max(1, math.floor((tonumber(hours) or 0) * 60 + 0.5))
    local fullHours = math.floor(totalMinutes / 60)
    local minutes = totalMinutes % 60
    if fullHours <= 0 then
        return string.format("%d Spielminuten", minutes)
    elseif minutes == 0 then
        return string.format("%d Spielstunde%s", fullHours, fullHours == 1 and "" or "n")
    end
    return string.format("%d Std. %d Min. Spielzeit", fullHours, minutes)
end

function M:showRepairCenterNotice(vehicleName, workHours)
end

function M:updateCenterNotice(dt)
end

function M:draw()
end

function M:getMaintenanceTaskForVehicle(vehicle)
    if vehicle == nil then return nil end
    if vehicle.fsEmployeesMaintenance ~= nil then return vehicle.fsEmployeesMaintenance end
    local root = self:getVehicleRoot(vehicle)
    if root ~= nil and root.fsEmployeesMaintenance ~= nil then return root.fsEmployeesMaintenance end
    local id = self:getVehicleUniqueId(vehicle)
    local rootId = self:getVehicleUniqueId(root)
    for _, task in pairs(self.maintenanceTasks or {}) do
        if (id ~= nil and task.vehicleId == id)
            or (rootId ~= nil and (task.rootVehicleId == rootId or task.vehicleId == rootId)) then
            return task
        end
    end
    return nil
end

function M:getMaintenanceRemainingText(vehicle)
    local task = self:getMaintenanceTaskForVehicle(vehicle)
    if task == nil or task.endClock == nil then return nil end
    local now = self:trainingClock()
    if now == nil then return nil end
    local remaining = math.max(0, task.endClock - now)
    if remaining <= 0.000001 then
        return "wird abgeschlossen"
    end
    return self:formatDurationHours(remaining)
end

function M:farmId()
    return g_currentMission:getFarmId()
end

function M:defaultAgeForId(id)
    local index = ((math.max(1, tonumber(id) or 1) - 1) % self.maxEmployees) + 1
    return self.roster[index].age, 0
end

function M:getEmployeeHelperName(e)
    if e == nil then return nil end
    local rosterId = tonumber(e.rosterId)
    local person = rosterId ~= nil and self.roster[rosterId] or nil
    return person ~= nil and person.helper or nil
end

function M:getFreeRosterId(farmId)
    local used, count = {}, 0
    for _,e in ipairs(self.staff) do
        if e.farmId == farmId then used[e.rosterId or ((e.id-1)%self.maxEmployees+1)] = true; count = count + 1 end
    end
    if count >= self.maxEmployees then return nil end
    for i=1,self.maxEmployees do if not used[i] then return i end end
end

function M:markRosterRetired(farmId, rosterId)
    farmId, rosterId = tonumber(farmId), tonumber(rosterId)
    if farmId == nil or rosterId == nil then return end
    self.retiredRoster = self.retiredRoster or {}
    self.retiredRoster[farmId] = self.retiredRoster[farmId] or {}
    self.retiredRoster[farmId][rosterId] = true
end

function M:assignRoster()
    local used, active, archived = {}, {}, self.legacyStaff or {}
    for _,e in ipairs(self.staff) do
        used[e.farmId] = used[e.farmId] or {}
        local slots = used[e.farmId]
        local index = tonumber(e.rosterId)
        if index == nil or self.roster[index] == nil or slots[index] then
            index = nil
            for i=1,self.maxEmployees do if not slots[i] then index=i; break end end
            if index then
                e.rosterId=index
                e.age,e.ageMonths=self.roster[index].age,0
            end
        end
        if index then
            slots[index]=true
            e.name=self.roster[index].name
            table.insert(active,e)
        else
            table.insert(archived,e)
        end
    end
    self.staff,self.legacyStaff=active,archived
end

function M:isValidRole(role)
    for _, info in ipairs(self.roles) do
        if info.key == role then return true end
    end
    return false
end

function M:getRoleLabel(role)
    for _, info in ipairs(self.roles) do
        if info.key == role then return info.label end
    end
    return "Nicht zugewiesen"
end

function M:getRoleSortIndex(role)
    local order = {fieldwork=1, transport=2, animals=3, machinery=4, none=5}
    return order[role] or 6
end

function M:getSortedStaff(farmId)
    local list = {}
    for _, e in ipairs(self.staff or {}) do
        if e.farmId == farmId then
            self:ensureDevelopment(e)
            table.insert(list, e)
        end
    end
    table.sort(list, function(a, b)
        if a.contract ~= b.contract then return a.contract < b.contract end
        local ar, br = self:getRoleSortIndex(a.role), self:getRoleSortIndex(b.role)
        if ar ~= br then return ar < br end
        return tostring(a.name) < tostring(b.name)
    end)
    return list
end

function M:getStaffOverviewCounts(farmId)
    local contracts = {0, 0, 0, 0}
    local roles = {none=0, fieldwork=0, transport=0, animals=0, machinery=0}
    local contractRoles = {
        {none=0, fieldwork=0, transport=0, animals=0, machinery=0},
        {none=0, fieldwork=0, transport=0, animals=0, machinery=0},
        {none=0, fieldwork=0, transport=0, animals=0, machinery=0},
        {none=0, fieldwork=0, transport=0, animals=0, machinery=0}
    }
    for _, e in ipairs(self.staff or {}) do
        if e.farmId == farmId then
            self:ensureDevelopment(e)
            if contracts[e.contract] ~= nil then
                contracts[e.contract] = contracts[e.contract] + 1
                local contractRole = contractRoles[e.contract]
                if contractRole ~= nil then
                    contractRole[e.role] = (contractRole[e.role] or 0) + 1
                end
            end
            roles[e.role] = (roles[e.role] or 0) + 1
        end
    end
    return contracts, roles, contractRoles
end

function M:setRole(e, role)
    if e == nil or not self:isValidRole(role) then return false end
    if self:isEmployeeInJob(e) or self:isTraining(e) or self:isEmployeeInMaintenance(e) then return false end
    e.role = role
    return true
end

function M:ensureDevelopment(e)
    if e == nil then return end
    if e.age == nil then
        e.age, e.ageMonths = self:defaultAgeForId(e.rosterId or e.id)
    end
    e.age = math.max(17, math.floor(tonumber(e.age) or 17))
    e.ageMonths = math.max(0, math.min(11, math.floor(tonumber(e.ageMonths) or 0)))
    e.training = e.training or {}
    for _, training in ipairs(self.trainingTypes) do
        local level = math.floor(tonumber(e.training[training.key]) or 0)
        e.training[training.key] = math.max(0, math.min(training.maxLevel, level))
    end
    if not self:isValidRole(e.role) then e.role = "none" end
    if e.illnessRemaining ~= nil then
        e.illnessRemaining = math.max(0, tonumber(e.illnessRemaining) or 0)
        if e.illnessRemaining <= 0 then e.illnessKey, e.illnessRemaining = nil, nil end
    end
end

function M:getTrainingLevel(e, key)
    self:ensureDevelopment(e)
    return e ~= nil and e.training ~= nil and (e.training[key] or 0) or 0
end


function M:getTrainingSpeedFactor(e, key)
    if self:isTemporaryEmployee(e) then return 1.00 end
    local level = self:getTrainingLevel(e, key)
    return self.trainingSpeedByLevel[level] or 0.25
end

function M:getTrainingSpeedPercent(e, key)
    return math.floor(self:getTrainingSpeedFactor(e, key) * 100 + 0.5)
end

function M:getTrainingSpeedPercentForLevel(level)
    return math.floor((self.trainingSpeedByLevel[math.floor(tonumber(level) or 0)] or 0.25) * 100 + 0.5)
end

function M:getServiceWorkHours(e, key, baseHours)
    local factor = math.max(0.01, self:getTrainingSpeedFactor(e, key))
    return (baseHours or 0) / factor
end

function M:setTrainingLevel(e, key, level)
    if e == nil then return false end
    self:ensureDevelopment(e)
    for _, training in ipairs(self.trainingTypes) do
        if training.key == key then
            e.training[key] = math.max(0, math.min(training.maxLevel, math.floor(tonumber(level) or 0)))
            return true
        end
    end
    return false
end

function M:getTrainingSummary(e)
    if e == nil then return "-" end
    self:ensureDevelopment(e)
    local parts = {}
    for _, training in ipairs(self.trainingTypes) do
        table.insert(parts, string.format("%s %d/%d", training.label, e.training[training.key] or 0, training.maxLevel))
    end
    return table.concat(parts, "  ·  ")
end


function M:getTrainingOffer(e, key)
    if e == nil then return nil end
    self:ensureDevelopment(e)
    local best, bestLevel
    for _, training in ipairs(self.trainingTypes) do
        local level = e.training[training.key] or 0
        if (key == nil or training.key == key) and level < training.maxLevel and (best == nil or level < bestLevel) then
            best = training
            bestLevel = level
        end
    end
    if best == nil then return nil end
    local nextLevel = bestLevel + 1
    return best, bestLevel, nextLevel, self.trainingBaseCost * nextLevel
end

function M:getIllnessInfo(e)
    if e == nil or e.illnessKey == nil then return nil end
    for _, illness in ipairs(self.illnessTypes) do
        if illness.key == e.illnessKey then return illness end
    end
    return nil
end

function M:isSick(e)
    return e ~= nil and e.illnessKey ~= nil and (tonumber(e.illnessRemaining) or 0) > 0
end

function M:illnessTimeText(e)
    local minutes = math.max(0, math.ceil((tonumber(e and e.illnessRemaining) or 0) * 60 - 0.000001))
    return string.format("%d:%02d h", math.floor(minutes / 60), minutes % 60)
end

function M:getIllnessStatusText(e)
    if not self:isSick(e) then return nil end
    local illness = self:getIllnessInfo(e)
    return string.format("Krank · %s · %s", illness and illness.label or "Erkrankung", self:illnessTimeText(e))
end

function M:chooseIllness()
    local total = 0
    for _, illness in ipairs(self.illnessTypes) do total = total + math.max(0, illness.weight or 0) end
    if total <= 0 then return self.illnessTypes[1] end
    local roll = math.random() * total
    local current = 0
    for _, illness in ipairs(self.illnessTypes) do
        current = current + math.max(0, illness.weight or 0)
        if roll <= current then return illness end
    end
    return self.illnessTypes[#self.illnessTypes]
end

function M:startIllness(e, illness)
    if e == nil or illness == nil or self:isSick(e) or self:isTemporaryEmployee(e) or self:isTraining(e) then return false end
    local minHours = math.max(0.5, tonumber(illness.minHours) or 1)
    local maxHours = math.max(minHours, tonumber(illness.maxHours) or minHours)
    local halfSteps = math.max(0, math.floor((maxHours - minHours) * 2 + 0.5))
    local duration = minHours + math.random(0, halfSteps) * 0.5
    if e.job ~= nil then g_currentMission.aiSystem:stopJob(e.job, AIMessageSuccessFinishedJob.new()) end
    self:cancelMaintenanceForEmployee(e.id)
    e.illnessKey = illness.key
    e.illnessRemaining = duration
    self:notifyProblem(string.format("%s ist krank: %s (%s).", e.name, illness.label, self:illnessTimeText(e)))
    return true
end

function M:rollMonthlyIllnesses()
    for _, e in ipairs(self.staff or {}) do
        if not self:isTemporaryEmployee(e) and not self:isSick(e) and not self:isTraining(e)
            and (e.leave or -1) < 0 and math.random() < self.illnessMonthlyChance then
            self:startIllness(e, self:chooseIllness())
        end
    end
end

function M:advanceIllness(hours)
    if hours <= 0 then return end
    for _, e in ipairs(self.staff or {}) do
        if self:isSick(e) then
            e.illnessRemaining = math.max(0, (e.illnessRemaining or 0) - hours)
            if e.illnessRemaining < 0.0000001 then
                local illness = self:getIllnessInfo(e)
                e.illnessKey, e.illnessRemaining = nil, nil
                self:notify(string.format("%s ist nach %s wieder gesund und verfügbar.", e.name, illness and illness.label or "der Erkrankung"))
            end
        end
    end
end

function M:updateIllnessClock()
    if self.isMultiplayer and not self.isServer then return end
    local now = self:trainingClock()
    if now == nil then return end
    if self.lastIllnessClock ~= nil then self:advanceIllness(math.max(0, now - self.lastIllnessClock)) end
    self.lastIllnessClock = now
end

function M:trainingClock()
    local env = g_currentMission and g_currentMission.environment
    if env == nil or env.currentDay == nil or env.dayTime == nil then return nil end
    return env.currentDay * 24 + env.dayTime / 3600000
end

function M:isTraining(e)
    return e ~= nil and e.activeTraining ~= nil
end

function M:trainingTimeText(e)
    local minutes = math.max(0, math.ceil((e.trainingRemaining or 0) * 60 - 0.000001))
    return string.format("%d:%02d h", math.floor(minutes / 60), minutes % 60)
end

function M:advanceTraining(hours)
    if hours <= 0 then return end
    for _,e in ipairs(self.staff or {}) do
        if self:isTraining(e) then
            e.trainingRemaining = math.max(0, (e.trainingRemaining or 0) - hours)
            if e.trainingRemaining < 0.0000001 then
                local key, level = e.activeTraining, e.trainingTarget
                self:setTrainingLevel(e, key, level)
                e.activeTraining, e.trainingTarget, e.trainingRemaining = nil, nil, nil
                self:notify(e.name .. ": Weiterbildung abgeschlossen. Wieder verfügbar.")
            end
        end
    end
end

function M:updateTrainingClock()
    if self.isMultiplayer and not self.isServer then return end
    local now = self:trainingClock()
    if now == nil then return end
    if self.lastTrainingClock ~= nil then self:advanceTraining(math.max(0, now - self.lastTrainingClock)) end
    self.lastTrainingClock = now
end

function M:canTrain(e, key)
    local training, _, _, cost = self:getTrainingOffer(e, key)
    if training == nil or e == nil or self:isTemporaryEmployee(e) or self:isEmployeeInJob(e) or self:isTraining(e) or self:isEmployeeInMaintenance(e) or self:isSick(e) then return false, cost end
    local farm = g_farmManager:getFarmById(e.farmId)
    return farm ~= nil and farm:getBalance() >= cost, cost
end

function M:train(e, key)
    self:updateTrainingClock()
    local training, _, nextLevel, cost = self:getTrainingOffer(e, key)
    if training == nil or e == nil then return false end
    if self:isTemporaryEmployee(e) then self:notify("Leiharbeiter können nicht weitergebildet werden."); return false end
    if self:isTraining(e) then self:notify(e.name .. " ist bereits auf Fortbildung."); return false end
    if self:isSick(e) then self:notify(e.name .. " ist krank und kann keine Weiterbildung beginnen."); return false end
    if self:isEmployeeInJob(e) then self:notify(e.name .. " ist aktuell im Einsatz."); return false end
    if self:isEmployeeInMaintenance(e) then self:notify(e.name .. " führt aktuell eine Wartung durch."); return false end
    if not self:canTrain(e, key) then self:notify("Zu wenig Geld für die Weiterbildung."); return false end
    g_currentMission:addMoney(-cost, e.farmId, MoneyType.AI, true)
    e.activeTraining = training.key
    e.trainingTarget = nextLevel
    e.trainingRemaining = self.trainingHours[nextLevel]
    self:notify(string.format("%s: %s Stufe %d gestartet (%d Spielstunden).", e.name, training.label, nextLevel, e.trainingRemaining))
    return true
end

function M:isTemporaryEmployee(e)
    if e == nil then return false end
    local c = self.contracts[e.contract]
    return c ~= nil and c.temporary == true
end

function M:removeTemporaryEmployee(e)
    if e == nil or not self:isTemporaryEmployee(e) then return false end
    if e.job ~= nil and g_currentMission ~= nil and g_currentMission.aiSystem ~= nil then
        g_currentMission.aiSystem:stopJob(e.job, AIMessageSuccessFinishedJob.new())
    end
    self:cancelMaintenanceForEmployee(e.id)
    for i = #(self.staff or {}), 1, -1 do
        if self.staff[i] == e or self.staff[i].id == e.id then
            table.remove(self.staff, i)
            self:notify(e.name .. ": 8 Spielstunden beendet. Leiharbeiter verlässt den Hof.")
            return true
        end
    end
    return false
end

function M:processTemporaryEmployees()
    local now = self:trainingClock()
    if now == nil then return end
    for i = #(self.staff or {}), 1, -1 do
        local e = self.staff[i]
        if self:isTemporaryEmployee(e) then
            if e.temporaryEndClock == nil then
                local remaining = math.max(0, (e.limit or 8) - (e.hours or 0))
                e.temporaryStartClock = now - math.max(0, e.hours or 0)
                e.temporaryEndClock = now + remaining
            end

            local startClock = e.temporaryStartClock or (e.temporaryEndClock - (e.limit or 8))
            e.temporaryStartClock = startClock
            e.hours = math.max(0, math.min(e.limit or 8, now - startClock))

            if now >= e.temporaryEndClock - 0.000001 then
                self:removeTemporaryEmployee(e)
            end
        end
    end
end

function M:findFree(farmId, role)
    for _, e in ipairs(self.staff) do
        self:ensureDevelopment(e)
        if e.farmId == farmId and e.job == nil and not self:isTraining(e) and not self:isSick(e)
            and (self:isTemporaryEmployee(e) or e.hours < e.limit)
            and not self:isEmployeeInMaintenance(e)
            and (role == nil or e.role == role) then return e end
    end
end

function M:hasEmployeeWithRole(farmId, role)
    for _, e in ipairs(self.staff or {}) do
        self:ensureDevelopment(e)
        if e.farmId == farmId and e.role == role then return true end
    end
    return false
end

function M:addWorkHours(e, hours)
    if e == nil or hours == nil or hours <= 0 then return end
    e.hours = math.min(e.limit, e.hours + hours)
    if e.hours >= e.limit and not self:isTemporaryEmployee(e) then
        self:notifyProblem(e.name .. ": Monatskontingent erreicht.")
    end
end

function M:hire(contractIndex, farmIdOverride)
    local c = self.contracts[contractIndex]
    local farmId = tonumber(farmIdOverride) or self:farmId()
    if not self.enabled or c == nil or g_farmManager:getFarmById(farmId) == nil then return end
    local rosterId=self:getFreeRosterId(farmId)
    if rosterId==nil then self:notify("Kein weiterer Mitarbeiter verfügbar."); return end
    local id=self.nextId
    self.nextId=id+1
    local person=self.roster[rosterId]
    local e = {id=id, rosterId=rosterId, name=person.name, farmId=farmId, contract=contractIndex,
        salary=c.salary, limit=c.hours, hours=0, hired=self.month, leave=-1,
        age=person.age, ageMonths=0, role="none", training={}}
    self:ensureDevelopment(e)
    if c.temporary then
        g_currentMission:addMoney(-c.salary, farmId, MoneyType.AI, true)
        local now = self:trainingClock()
        if now ~= nil then
            e.temporaryStartClock = now
            e.temporaryEndClock = now + c.hours
        end
    end
    table.insert(self.staff, e)
    if c.temporary then
        self:notify(string.format("%s als Leiharbeiter angefordert: %d Spielstunden Einsatzzeit.", e.name, c.hours))
    else
        self:notify(e.name .. " eingestellt: " .. c.name)
    end
    return e
end

function M:giveNotice(e)
    if e.leave >= 0 then return end
    e.leave = self.month + 3
end

function M:periodChanged()
    if not self.enabled then return end
    local day = g_currentMission.environment.currentDay
    if day == self.lastPeriodDay then return end
    self.lastPeriodDay = day
    self.month = self.month + 1
    for i = #self.staff, 1, -1 do
        local e = self.staff[i]
        self:ensureDevelopment(e)
        if g_farmManager:getFarmById(e.farmId) ~= nil and not self:isTemporaryEmployee(e) then
            g_currentMission:addMoney(-e.salary, e.farmId, MoneyType.AI, true)
        end
        if not self:isTemporaryEmployee(e) then e.hours = 0 end
        e.ageMonths = e.ageMonths + 1
        if e.ageMonths >= 12 then
            e.ageMonths = e.ageMonths - 12
            e.age = e.age + 1
        end
        self:checkRetirementWarning(e)
        local retired = e.age >= self.retirementAge
        if retired then
            if e.job ~= nil then g_currentMission.aiSystem:stopJob(e.job, AIMessageSuccessFinishedJob.new()) end
            self:cancelMaintenanceForEmployee(e.id)
            table.remove(self.staff, i)
            self:notify(string.format("%s ist mit %d Jahren in Rente gegangen.", e.name, self.retirementAge))
        elseif e.leave >= 0 and self.month >= e.leave then
            if e.job ~= nil then g_currentMission.aiSystem:stopJob(e.job, AIMessageSuccessFinishedJob.new()) end
            self:cancelMaintenanceForEmployee(e.id)
            table.remove(self.staff, i)
            self:notify(e.name .. ": Arbeitsverhaeltnis beendet.")
        end
    end
    self:rollMonthlyIllnesses()
end

function M:filename(directory)
    directory = directory or g_currentMission.missionInfo.savegameDirectory
    if directory == nil then return nil end
    return directory .. "/employees.xml"
end

function M:save(directory)
    if not self.enabled or self.isServer == false then return end
    self:updateTrainingClock()
    self:updateIllnessClock()
    local filename = self:filename(directory)
    if filename == nil then return end
    local xml = createXMLFile("employees", filename, "employees")
    if xml == nil or xml == 0 then return end
    setXMLInt(xml, "employees#version", 16)
    setXMLInt(xml, "employees#month", self.month)
    setXMLInt(xml, "employees#nextId", self.nextId)
    setXMLInt(xml, "employees#lastPeriodDay", self.lastPeriodDay)
    setXMLInt(xml, "employees#lastAnimalCheck08Day", self.lastAnimalCheck08Day or -1)
    setXMLInt(xml, "employees#lastAnimalCheck17Day", self.lastAnimalCheck17Day or -1)
    local scheduleIndex = 0
    local scheduleFarmIds = {}
    for farmId in pairs(self.lastAnimalCheck08ByFarm or {}) do scheduleFarmIds[farmId] = true end
    for farmId in pairs(self.lastAnimalCheck17ByFarm or {}) do scheduleFarmIds[farmId] = true end
    for farmId in pairs(scheduleFarmIds) do
        local key = string.format("employees.animalSchedule(%d)", scheduleIndex)
        setXMLInt(xml, key .. "#farmId", tonumber(farmId) or 0)
        setXMLInt(xml, key .. "#last08", (self.lastAnimalCheck08ByFarm or {})[farmId] or -1)
        setXMLInt(xml, key .. "#last17", (self.lastAnimalCheck17ByFarm or {})[farmId] or -1)
        scheduleIndex = scheduleIndex + 1
    end
    for i, c in ipairs(self.contracts) do
        local key = string.format("employees.contract(%d)", i-1)
        setXMLFloat(xml, key .. "#salary", c.salary)
        setXMLFloat(xml, key .. "#hours", c.hours)
    end
    local records={}
    for _,e in ipairs(self.staff) do table.insert(records,e) end
    for _,e in ipairs(self.legacyStaff or {}) do table.insert(records,e) end
    for i, e in ipairs(records) do
        self:ensureDevelopment(e)
        local key = string.format("employees.employee(%d)", i-1)
        setXMLString(xml, key .. "#name", e.name)
        setXMLString(xml, key .. "#role", e.role)
        setXMLInt(xml, key .. "#retirementWarningSent", e.retirementWarningSent and 1 or 0)
        setXMLInt(xml, key .. "#legacyInactive", i > #self.staff and 1 or 0)
        if self:isTraining(e) then
            setXMLString(xml, key .. "#activeTraining", e.activeTraining)
            setXMLInt(xml, key .. "#trainingTarget", e.trainingTarget)
            setXMLFloat(xml, key .. "#trainingRemaining", e.trainingRemaining)
        end
        if self:isSick(e) then
            setXMLString(xml, key .. "#illnessKey", e.illnessKey)
            setXMLFloat(xml, key .. "#illnessRemaining", e.illnessRemaining)
        end
        for _, field in ipairs({"id", "farmId", "contract", "hired", "leave", "age", "ageMonths", "rosterId"}) do
            if e[field] ~= nil then setXMLInt(xml, key .. "#" .. field, e[field]) end
        end
        for _, field in ipairs({"salary", "limit", "hours"}) do setXMLFloat(xml, key .. "#" .. field, e[field]) end
        if self:isTemporaryEmployee(e) then
            if e.temporaryStartClock ~= nil then setXMLFloat(xml, key .. "#temporaryStartClock", e.temporaryStartClock) end
            if e.temporaryEndClock ~= nil then setXMLFloat(xml, key .. "#temporaryEndClock", e.temporaryEndClock) end
        end
        for _, training in ipairs(self.trainingTypes) do
            setXMLInt(xml, key .. "#training_" .. training.key, e.training[training.key] or 0)
        end
    end
    local maintenanceIndex = 0
    for _, task in pairs(self.maintenanceTasks or {}) do
        if task.vehicleId ~= nil and task.employeeId ~= nil and task.endClock ~= nil then
            local key = string.format("employees.maintenance(%d)", maintenanceIndex)
            setXMLString(xml, key .. "#vehicleId", task.vehicleId)
            if task.rootVehicleId ~= nil then setXMLString(xml, key .. "#rootVehicleId", task.rootVehicleId) end
            setXMLInt(xml, key .. "#employeeId", task.employeeId)
            setXMLFloat(xml, key .. "#endClock", task.endClock)
            if task.vehicleName ~= nil then setXMLString(xml, key .. "#vehicleName", task.vehicleName) end
            maintenanceIndex = maintenanceIndex + 1
        end
    end
    saveXMLFile(xml)
    delete(xml)
end

function M:loadState()
    local filename = self:filename()
    if filename == nil or not fileExists(filename) then return end
    local xml = loadXMLFile("employees", filename)
    if xml == nil or xml == 0 then return end
    local version = getXMLInt(xml, "employees#version") or 1
    self.month = getXMLInt(xml, "employees#month") or 0
    self.nextId = getXMLInt(xml, "employees#nextId") or 1
    self.lastPeriodDay = getXMLInt(xml, "employees#lastPeriodDay") or self.lastPeriodDay
    self.lastAnimalCheck08Day = getXMLInt(xml, "employees#lastAnimalCheck08Day") or self.lastAnimalCheck08Day or -1
    self.lastAnimalCheck17Day = getXMLInt(xml, "employees#lastAnimalCheck17Day") or self.lastAnimalCheck17Day or -1
    self.lastAnimalCheck08ByFarm = {}
    self.lastAnimalCheck17ByFarm = {}
    local scheduleIndex = 0
    while hasXMLProperty(xml, string.format("employees.animalSchedule(%d)", scheduleIndex)) do
        local key = string.format("employees.animalSchedule(%d)", scheduleIndex)
        local farmId = getXMLInt(xml, key .. "#farmId")
        if farmId ~= nil then
            self.lastAnimalCheck08ByFarm[farmId] = getXMLInt(xml, key .. "#last08") or -1
            self.lastAnimalCheck17ByFarm[farmId] = getXMLInt(xml, key .. "#last17") or -1
        end
        scheduleIndex = scheduleIndex + 1
    end
    for i, c in ipairs(self.contracts) do
        local key = string.format("employees.contract(%d)", i-1)
        c.salary = math.max(0, getXMLFloat(xml, key .. "#salary") or c.salary)
        c.hours = math.max(1, getXMLFloat(xml, key .. "#hours") or c.hours)
    end
    local retiredIndex = 0
    while hasXMLProperty(xml, string.format("employees.retired(%d)", retiredIndex)) do
        retiredIndex = retiredIndex + 1
    end
    self.retiredRoster = {}
    local i = 0
    while hasXMLProperty(xml, string.format("employees.employee(%d)", i)) do
        local key = string.format("employees.employee(%d)", i)
        local e = {name=getXMLString(xml, key .. "#name"), role=getXMLString(xml, key .. "#role"), training={}}
        e.retirementWarningSent = getXMLInt(xml, key .. "#retirementWarningSent") == 1
        for _, field in ipairs({"id", "farmId", "contract", "hired", "leave", "age", "ageMonths", "rosterId"}) do
            e[field] = getXMLInt(xml, key .. "#" .. field)
        end
        for _, field in ipairs({"salary", "limit", "hours"}) do e[field] = getXMLFloat(xml, key .. "#" .. field) end
        for _, training in ipairs(self.trainingTypes) do
            e.training[training.key] = getXMLInt(xml, key .. "#training_" .. training.key) or 0
        end
        if e.id ~= nil and e.name ~= nil and self.contracts[e.contract] ~= nil and e.farmId ~= nil then
            local c = self.contracts[e.contract]
            e.hired = e.hired or self.month
            e.leave = e.leave or -1
            e.salary = math.max(0, e.salary or c.salary)
            e.limit = math.max(1, e.limit or c.hours)
            e.hours = math.max(0, e.hours or 0)
            if c.temporary then
                e.temporaryStartClock = getXMLFloat(xml, key .. "#temporaryStartClock")
                e.temporaryEndClock = getXMLFloat(xml, key .. "#temporaryEndClock")
            end
            self:ensureDevelopment(e)
            local illnessKey = getXMLString(xml, key .. "#illnessKey")
            local illnessRemaining = getXMLFloat(xml, key .. "#illnessRemaining")
            if illnessKey ~= nil and illnessRemaining ~= nil and illnessRemaining > 0 then
                for _, illness in ipairs(self.illnessTypes) do
                    if illness.key == illnessKey then
                        e.illnessKey = illnessKey
                        e.illnessRemaining = illnessRemaining
                        break
                    end
                end
            end
            local active = getXMLString(xml, key .. "#activeTraining")
            local target = getXMLInt(xml, key .. "#trainingTarget")
            local remaining = getXMLFloat(xml, key .. "#trainingRemaining")
            for _,training in ipairs(self.trainingTypes) do
                if active == training.key and target == e.training[active] + 1 and target <= training.maxLevel
                    and remaining ~= nil and remaining > 0 and remaining < math.huge then
                    e.activeTraining, e.trainingTarget = active, target
                    e.trainingRemaining = math.min(remaining, self.trainingHours[target])
                end
            end
            if version < 15 then
                e.age, e.ageMonths = self:defaultAgeForId(e.rosterId or e.id)
            end
            if getXMLInt(xml,key .. "#legacyInactive")==1 then
                self.legacyStaff=self.legacyStaff or {}
                table.insert(self.legacyStaff,e)
            else table.insert(self.staff,e) end
            self.nextId = math.max(self.nextId, e.id + 1)
        end
        i = i + 1
    end
    local maintenanceIndex = 0
    while hasXMLProperty(xml, string.format("employees.maintenance(%d)", maintenanceIndex)) do
        local key = string.format("employees.maintenance(%d)", maintenanceIndex)
        local vehicleId = getXMLString(xml, key .. "#vehicleId")
        local employeeId = getXMLInt(xml, key .. "#employeeId")
        local endClock = getXMLFloat(xml, key .. "#endClock")
        if vehicleId ~= nil and employeeId ~= nil and endClock ~= nil then
            self.maintenanceTasks[vehicleId] = {
                vehicleId = vehicleId,
                rootVehicleId = getXMLString(xml, key .. "#rootVehicleId"),
                employeeId = employeeId,
                endClock = endClock,
                vehicleName = getXMLString(xml, key .. "#vehicleName") or "Fahrzeug"
            }
        end
        maintenanceIndex = maintenanceIndex + 1
    end
    delete(xml)
    self:assignRoster()
end

function M:loadMap()
    self.aiHelperDisplayNames = {}
    self.pendingSelection = nil
    self.centerNotice = nil
    self.autoServiceElapsed = 0
    self.maintenanceTasks = {}
    self.lastAnimalCheck08Day = -1
    self.lastAnimalCheck17Day = -1
    self.lastAnimalCheck08ByFarm = {}
    self.lastAnimalCheck17ByFarm = {}
    self.lastMissingMachineWorkerNotice = nil
    self.lastMachineHoursNotice = nil
    self.lastMachineNoMoneyNotice = nil
    self.staff, self.month, self.nextId = {}, 0, 1
    self.legacyStaff = {}
    self.retiredRoster = {}
    self.isServer = g_currentMission:getIsServer() == true
    self.isMultiplayer = (g_currentMission.missionDynamicInfo or {}).isMultiplayer == true
    self.enabled = true
    self.networkReady = self.isServer or not self.isMultiplayer
    self.networkDirty = false
    self.networkSyncElapsed = 0
    self.networkStateRequestElapsed = 0
    self.lastPeriodDay = g_currentMission.environment.currentDay
    self.contracts = {{name="Geringfuegig",salary=600,hours=40},{name="Teilzeit",salary=1600,hours=80},{name="Vollzeit",salary=3200,hours=160},{name="Leiharbeiter",salary=120,hours=8,temporary=true}}

    if self.isServer then
        self:loadState()
        self.retirementLoadCheckPending = true
        self.lastTrainingClock = self:trainingClock()
        self.lastIllnessClock = self:trainingClock()
        g_messageCenter:subscribe(MessageType.PERIOD_CHANGED, self.periodChanged, self)
    else
        self.retirementLoadCheckPending = false
        self.lastTrainingClock = nil
        self.lastIllnessClock = nil
    end
end

function M:getJobRole(job)
    if job == nil or AIJobType == nil then return nil end
    local typeIndex = job.jobTypeIndex
    if typeIndex == AIJobType.FIELDWORK then return "fieldwork" end
    if typeIndex == AIJobType.GOTO or typeIndex == AIJobType.CONVEYOR
        or typeIndex == AIJobType.DELIVER or typeIndex == AIJobType.LOAD_AND_DELIVER then
        return "transport"
    end
    return nil
end

function M:getEmployeeById(id)
    id = tonumber(id)
    if id == nil then return nil end
    for _, e in ipairs(self.staff or {}) do
        if e.id == id then return e end
    end
    return nil
end

function M:getMonthsUntilRetirement(e)
    if e == nil then return nil end
    self:ensureDevelopment(e)
    return (self.retirementAge - e.age) * 12 - e.ageMonths
end

function M:checkRetirementWarning(e)
    if e == nil or e.retirementWarningSent then return end
    local months = self:getMonthsUntilRetirement(e)
    if months ~= nil and months > 0 and months <= 3 then
        e.retirementWarningSent = true
        self:notify(string.format("%s geht in %d Spielmonat%s in Rente.", e.name, months, months == 1 and "" or "en"))
    end
end

function M:processLoadedRetirements()
    if not self.retirementLoadCheckPending then return end
    self.retirementLoadCheckPending = false
    for i = #(self.staff or {}), 1, -1 do
        local e = self.staff[i]
        self:ensureDevelopment(e)
        if e.age >= self.retirementAge then
            if e.job ~= nil then g_currentMission.aiSystem:stopJob(e.job, AIMessageSuccessFinishedJob.new()) end
            self:cancelMaintenanceForEmployee(e.id)
            table.remove(self.staff, i)
            self:notify(string.format("%s ist mit %d Jahren in Rente gegangen.", e.name, self.retirementAge))
        else
            self:checkRetirementWarning(e)
        end
    end
end

function M:getMaintenanceTaskForEmployee(employeeOrId)
    local id = type(employeeOrId) == "table" and employeeOrId.id or tonumber(employeeOrId)
    if id == nil then return nil end
    for _, task in pairs(self.maintenanceTasks or {}) do
        if task.employeeId == id then return task end
    end
    return nil
end

function M:isEmployeeInMaintenance(e)
    return e ~= nil and self:getMaintenanceTaskForEmployee(e.id) ~= nil
end

function M:getVehicleRoot(vehicle)
    if vehicle == nil then return nil end
    if vehicle.rootVehicle ~= nil then return vehicle.rootVehicle end
    if vehicle.findRootVehicle ~= nil then
        local ok, root = pcall(vehicle.findRootVehicle, vehicle)
        if ok and root ~= nil then return root end
    end
    return vehicle
end

function M:getVehicleUniqueId(vehicle)
    if vehicle == nil or vehicle.getUniqueId == nil then return nil end
    local ok, id = pcall(vehicle.getUniqueId, vehicle)
    if ok then return id end
    return nil
end

function M:getVehicleByUniqueId(uniqueId)
    if uniqueId == nil or uniqueId == "" then return nil end
    local system = g_currentMission and g_currentMission.vehicleSystem
    if system ~= nil and system.getVehicleByUniqueId ~= nil then
        return system:getVehicleByUniqueId(uniqueId)
    end
    return nil
end

function M:isVehicleInMaintenance(vehicle)
    if vehicle == nil then return false end
    if vehicle.fsEmployeesMaintenance ~= nil then return true end
    local root = self:getVehicleRoot(vehicle)
    if root ~= nil and root.fsEmployeesMaintenance ~= nil then return true end
    local id = self:getVehicleUniqueId(vehicle)
    local rootId = self:getVehicleUniqueId(root)
    for _, task in pairs(self.maintenanceTasks or {}) do
        if (id ~= nil and task.vehicleId == id) or (rootId ~= nil and (task.rootVehicleId == rootId or task.vehicleId == rootId)) then
            return true
        end
    end
    return false
end

function M:containsArrayValue(values, wanted)
    if values == nil then return false end
    for _, value in ipairs(values) do
        if value == wanted then return true end
    end
    return false
end

function M:lockMaintenanceVehicle(task, vehicle)
    if task == nil or vehicle == nil or vehicle.isDeleted then return false end
    if task.locked then return true end
    local mission = g_currentMission
    local system = mission and mission.vehicleSystem
    local root = self:getVehicleRoot(vehicle) or vehicle

    task.vehicle = vehicle
    task.rootVehicle = root
    task.vehicleId = task.vehicleId or self:getVehicleUniqueId(vehicle)
    task.rootVehicleId = task.rootVehicleId or self:getVehicleUniqueId(root)
    task.vehicleName = task.vehicleName or (vehicle.getName ~= nil and vehicle:getName() or "Fahrzeug")

    vehicle.fsEmployeesMaintenance = task
    root.fsEmployeesMaintenance = task

    if root.getIsEnterable ~= nil then
        task.originalGetIsEnterable = root.getIsEnterable
        local original = root.getIsEnterable
        root.getIsEnterable = function(v, ...)
            if v.fsEmployeesMaintenance ~= nil then return false end
            return original(v, ...)
        end
    end
    if root.getIsTabbable ~= nil then
        task.originalGetIsTabbable = root.getIsTabbable
        local original = root.getIsTabbable
        root.getIsTabbable = function(v, ...)
            if v.fsEmployeesMaintenance ~= nil then return false end
            return original(v, ...)
        end
    end
    if root.interact ~= nil then
        task.originalInteract = root.interact
        local original = root.interact
        root.interact = function(v, ...)
            if v.fsEmployeesMaintenance ~= nil then
                M:notifyProblem((task.vehicleName or "Fahrzeug") .. " ist aktuell in Wartung.")
                return
            end
            return original(v, ...)
        end
    end
    if vehicle.isAttachAllowed ~= nil then
        task.originalIsAttachAllowed = vehicle.isAttachAllowed
        local original = vehicle.isAttachAllowed
        vehicle.isAttachAllowed = function(v, ...)
            if v.fsEmployeesMaintenance ~= nil then return false, "Gerät ist in Wartung." end
            return original(v, ...)
        end
    end

    if system ~= nil then
        task.wasEnterable = self:containsArrayValue(system.enterables, root)
        task.wasInteractive = system.interactiveVehicles ~= nil and system.interactiveVehicles[root] ~= nil
        if task.wasEnterable and system.removeEnterableVehicle ~= nil then system:removeEnterableVehicle(root) end
    end
    task.locked = true
    return true
end

function M:unlockMaintenanceVehicle(task)
    if task == nil then return end
    local mission = g_currentMission
    local system = mission and mission.vehicleSystem
    local vehicle = task.vehicle or self:getVehicleByUniqueId(task.vehicleId)
    local root = task.rootVehicle or self:getVehicleByUniqueId(task.rootVehicleId) or self:getVehicleRoot(vehicle)

    if root ~= nil and not root.isDeleted then
        if task.originalGetIsEnterable ~= nil then root.getIsEnterable = task.originalGetIsEnterable end
        if task.originalGetIsTabbable ~= nil then root.getIsTabbable = task.originalGetIsTabbable end
        if task.originalInteract ~= nil then root.interact = task.originalInteract end
        if system ~= nil then
            if task.wasEnterable and not self:containsArrayValue(system.enterables, root) and system.addEnterableVehicle ~= nil then
                system:addEnterableVehicle(root)
            end
            if task.wasInteractive and system.interactiveVehicles ~= nil and system.interactiveVehicles[root] == nil
                and system.addInteractiveVehicle ~= nil then
                system:addInteractiveVehicle(root)
            end
        end
        if root.fsEmployeesMaintenance == task then root.fsEmployeesMaintenance = nil end
    end
    if vehicle ~= nil and not vehicle.isDeleted then
        if task.originalIsAttachAllowed ~= nil then vehicle.isAttachAllowed = task.originalIsAttachAllowed end
        if vehicle.fsEmployeesMaintenance == task then vehicle.fsEmployeesMaintenance = nil end
    end

    task.vehicle, task.rootVehicle = nil, nil
    task.originalGetIsEnterable, task.originalGetIsTabbable, task.originalInteract, task.originalIsAttachAllowed = nil, nil, nil, nil
    task.wasEnterable, task.wasInteractive, task.locked = nil, nil, false
end

function M:cancelMaintenanceForEmployee(employeeOrId)
    local id = type(employeeOrId) == "table" and employeeOrId.id or tonumber(employeeOrId)
    if id == nil then return end
    for key, task in pairs(self.maintenanceTasks or {}) do
        if task.employeeId == id then
            self:unlockMaintenanceVehicle(task)
            self.maintenanceTasks[key] = nil
        end
    end
end

function M:calculateMaintenanceEndClock(startClock, workHours)
    if startClock == nil then return nil end
    local day = math.floor(startClock / 24)
    local hour = startClock - day * 24
    local remaining = math.max(0, tonumber(workHours) or 0)

    if hour < self.machineWorkStartHour then hour = self.machineWorkStartHour end
    if hour >= self.machineWorkEndHour then
        day = day + 1
        hour = self.machineWorkStartHour
    end

    while remaining > 0.000001 do
        local available = self.machineWorkEndHour - hour
        if remaining <= available then
            hour = hour + remaining
            remaining = 0
        else
            remaining = remaining - available
            day = day + 1
            hour = self.machineWorkStartHour
        end
    end
    return day * 24 + hour
end

function M:startMaintenance(worker, vehicle)
    if worker == nil or vehicle == nil or self:isSick(worker) or self:isEmployeeInMaintenance(worker) or self:isVehicleInMaintenance(vehicle) then return false end
    local now = self:trainingClock()
    if now == nil or not self:isMachineWorkTime() then return false end
    local workHours = self:getServiceWorkHours(worker, "machinery", self.machineServiceHours)
    if worker.limit - worker.hours + 0.000001 < workHours then
        local env = g_currentMission and g_currentMission.environment
        local day = env and env.currentDay or 0
        local key = string.format("%s:%s:%s", day, worker.id or 0, self:getVehicleUniqueId(vehicle) or tostring(vehicle))
        if self.lastMachineHoursNotice ~= key then
            self.lastMachineHoursNotice = key
            self:notifyProblem(worker.name .. ": Nicht genügend Arbeitsstunden für die Wartung verfügbar.")
        end
        return false
    end

    local root = self:getVehicleRoot(vehicle) or vehicle
    local vehicleId = self:getVehicleUniqueId(vehicle)
    local rootId = self:getVehicleUniqueId(root)
    if vehicleId == nil then return false end
    local task = {
        vehicleId = vehicleId,
        rootVehicleId = rootId,
        employeeId = worker.id,
        vehicleName = vehicle.getName ~= nil and vehicle:getName() or "Fahrzeug",
        endClock = self:calculateMaintenanceEndClock(now, workHours)
    }
    self.maintenanceTasks[vehicleId] = task
    if not self:lockMaintenanceVehicle(task, vehicle) then
        self.maintenanceTasks[vehicleId] = nil
        return false
    end
    self:addWorkHours(worker, workHours)
    self:markNetworkDirty()
    return true
end

function M:updateMaintenanceTasks()
    local now = self:trainingClock()
    if now == nil then return end
    for key, task in pairs(self.maintenanceTasks or {}) do
        local vehicle = task.vehicle or self:getVehicleByUniqueId(task.vehicleId)
        local worker = self:getEmployeeById(task.employeeId)
        if vehicle == nil or vehicle.isDeleted or worker == nil then
            self:unlockMaintenanceVehicle(task)
            self.maintenanceTasks[key] = nil
            self:markNetworkDirty()
        else
            if not task.locked then self:lockMaintenanceVehicle(task, vehicle) end
            if task.endClock ~= nil and now + 0.000001 >= task.endClock then
                local price = vehicle.getRepairPrice ~= nil and math.max(0, vehicle:getRepairPrice() or 0) or 0
                local farm = g_farmManager:getFarmById(worker.farmId)
                if vehicle.repairVehicle == nil then
                    self:notifyProblem("Maschinentechnik: " .. (task.vehicleName or "Fahrzeug") .. " konnte nicht repariert werden.")
                    self:unlockMaintenanceVehicle(task)
                    self.maintenanceTasks[key] = nil
                    self:markNetworkDirty()
                elseif farm ~= nil and farm:getBalance() >= price then
                    vehicle:repairVehicle()
                    self:unlockMaintenanceVehicle(task)
                    self.maintenanceTasks[key] = nil
                    self:markNetworkDirty()
                else
                    local env = g_currentMission and g_currentMission.environment
                    local day = env and env.currentDay or 0
                    if task.lastNoMoneyNoticeDay ~= day then
                        task.lastNoMoneyNoticeDay = day
                        self:notifyProblem(string.format("Maschinentechnik: %s ist in Wartung, aber %.0f € Reparaturkosten sind nicht verfügbar.", task.vehicleName or "Fahrzeug", price))
                    end
                end
            end
        end
    end
end

function M:getActiveAutoTask(e)
    local maintenance = self:getMaintenanceTaskForEmployee(e)
    if maintenance ~= nil then
        return "Wartung · " .. (maintenance.vehicleName or "Fahrzeug")
    end
    if e == nil or e.autoTask == nil then return nil end
    if e.autoTaskUntil ~= nil and g_time ~= nil and g_time > e.autoTaskUntil then
        e.autoTask, e.autoTaskUntil = nil, nil
        return nil
    end
    return e.autoTask
end

function M:setAutoTask(e, text)
    if e == nil then return end
    e.autoTask = text
    e.autoTaskUntil = (g_time or 0) + self.autoServiceIntervalMs
end

function M:getPlaceableName(placeable)
    if placeable ~= nil and placeable.getName ~= nil then
        local name = placeable:getName()
        if name ~= nil and name ~= "" then return name end
    end
    return "Tierstall"
end

function M:getGameHour()
    local env = g_currentMission and g_currentMission.environment
    if env == nil or env.dayTime == nil then return nil end
    return env.dayTime / 3600000
end

function M:getFillTypeLabel(fillTypeIndex)
    if fillTypeIndex == nil or g_fillTypeManager == nil then return "Unbekannt" end
    if g_fillTypeManager.getFillTypeTitleByIndex ~= nil then
        local title = g_fillTypeManager:getFillTypeTitleByIndex(fillTypeIndex)
        if title ~= nil and title ~= "" then return title end
    end
    if g_fillTypeManager.getFillTypeNameByIndex ~= nil then
        local name = g_fillTypeManager:getFillTypeNameByIndex(fillTypeIndex)
        if name ~= nil and name ~= "" then return name end
    end
    return tostring(fillTypeIndex)
end

function M:hasFarmAccessToObject(farmId, object)
    if object == nil then return false end

    local ownerFarmId = nil
    if object.getOwnerFarmId ~= nil then
        local ok, value = pcall(object.getOwnerFarmId, object)
        if ok then ownerFarmId = tonumber(value) end
    end
    if ownerFarmId ~= nil and ownerFarmId == farmId then return true end

    local mission = g_currentMission
    local accessHandler = mission and mission.accessHandler
    if accessHandler ~= nil and accessHandler.canFarmAccess ~= nil then
        local ok, allowed = pcall(accessHandler.canFarmAccess, accessHandler, farmId, object, true)
        if ok then return allowed == true end
    end

    return false
end

function M:getObjectStorageXMLFilename(abstractObject)
    if abstractObject == nil then return nil end
    if abstractObject.getXMLFilename ~= nil then
        local ok, filename = pcall(abstractObject.getXMLFilename, abstractObject)
        if ok and filename ~= nil and filename ~= "" then return tostring(filename) end
    end

    local function findFilename(data, depth, visited)
        if type(data) ~= "table" or depth > 4 or visited[data] then return nil end
        visited[data] = true
        local filename = data.xmlFilename or data.configFileName or data.filename
        if filename ~= nil and filename ~= "" then return tostring(filename) end
        local nestedKeys = {
            "attributes", "vehicleAttributes", "palletAttributes", "objectAttributes",
            "baleAttributes", "vehicleData", "objectData", "palletData", "fillData",
            "fillLevelData", "data", "savegameData", "state", "fillUnit", "fillUnits", "fillUnitData"
        }
        for _, key in ipairs(nestedKeys) do
            local value = data[key]
            if type(value) == "table" then
                filename = findFilename(value, depth + 1, visited)
                if filename ~= nil then return filename end
            end
        end
        return nil
    end

    return findFilename(abstractObject, 0, {})
end

function M:getBigBagVehicleFillData(vehicle, wantedFillType)
    if vehicle == nil or vehicle.isDeleted or vehicle.spec_bigBag == nil
        or vehicle.getFillUnitFillLevel == nil or vehicle.getFillUnitFillType == nil then
        return nil, 0, nil
    end

    local preferredIndex = vehicle.spec_bigBag.fillUnitIndex
    if preferredIndex ~= nil then
        local okType, fillType = pcall(vehicle.getFillUnitFillType, vehicle, preferredIndex)
        local okLevel, fillLevel = pcall(vehicle.getFillUnitFillLevel, vehicle, preferredIndex)
        if okType and okLevel and fillType ~= nil and (wantedFillType == nil or fillType == wantedFillType) then
            return fillType, math.max(0, tonumber(fillLevel) or 0), preferredIndex
        end
    end

    if vehicle.getFillUnits ~= nil then
        local okUnits, fillUnits = pcall(vehicle.getFillUnits, vehicle)
        if okUnits and type(fillUnits) == "table" then
            for fillUnitIndex, _ in pairs(fillUnits) do
                local okType, fillType = pcall(vehicle.getFillUnitFillType, vehicle, fillUnitIndex)
                local okLevel, fillLevel = pcall(vehicle.getFillUnitFillLevel, vehicle, fillUnitIndex)
                if okType and okLevel and fillType ~= nil and (wantedFillType == nil or fillType == wantedFillType)
                    and (tonumber(fillLevel) or 0) > 0.001 then
                    return fillType, math.max(0, tonumber(fillLevel) or 0), fillUnitIndex
                end
            end
        end
    end

    return nil, 0, nil
end

function M:getObjectStorageBaleData(abstractObject)
    if abstractObject == nil then return nil, 0, nil end

    local function normalizeFillType(fillType)
        if type(fillType) == "string" and g_fillTypeManager ~= nil then
            fillType = g_fillTypeManager:getFillTypeIndexByName(fillType)
        end
        return fillType
    end

    local function getFarmId(object)
        if object == nil then return nil end
        if object.getOwnerFarmId ~= nil then
            local ok, value = pcall(object.getOwnerFarmId, object)
            if ok and tonumber(value) ~= nil then return tonumber(value) end
        end
        return tonumber(object.farmId or object.ownerFarmId)
    end

    local function readDataTable(data, depth, visited, inheritedFarmId)
        if type(data) ~= "table" or depth > 5 or visited[data] then return nil, 0, inheritedFarmId end
        visited[data] = true

        local farmId = tonumber(data.farmId or data.ownerFarmId) or inheritedFarmId
        local fillType = normalizeFillType(data.fillType or data.fillTypeIndex or data.fillTypeName or data.fillUnitFillType)
        local fillLevel = tonumber(data.fillLevel or data.fillUnitFillLevel or data.amount)
        if fillType ~= nil and fillLevel ~= nil then
            return fillType, math.max(0, fillLevel), farmId
        end

        local nestedKeys = {
            "attributes", "vehicleAttributes", "palletAttributes", "objectAttributes",
            "baleAttributes", "vehicleData", "objectData", "palletData", "fillData",
            "fillLevelData", "data", "savegameData", "state", "fillUnit", "fillUnits", "fillUnitData"
        }
        for _, key in ipairs(nestedKeys) do
            local value = data[key]
            if type(value) == "table" then
                local ft, fl, nestedFarmId = readDataTable(value, depth + 1, visited, farmId)
                if ft ~= nil then return ft, fl, nestedFarmId end
                for _, nested in pairs(value) do
                    if type(nested) == "table" then
                        ft, fl, nestedFarmId = readDataTable(nested, depth + 1, visited, farmId)
                        if ft ~= nil then return ft, fl, nestedFarmId end
                    end
                end
            end
        end
        return nil, 0, farmId
    end

    if abstractObject.getFillType ~= nil and abstractObject.getFillLevel ~= nil then
        local okType, fillType = pcall(abstractObject.getFillType, abstractObject)
        local okLevel, fillLevel = pcall(abstractObject.getFillLevel, abstractObject)
        fillType = okType and normalizeFillType(fillType) or nil
        fillLevel = okLevel and tonumber(fillLevel) or nil
        if fillType ~= nil and fillLevel ~= nil then
            return fillType, math.max(0, fillLevel), getFarmId(abstractObject)
        end
    end

    if abstractObject.getFillUnitFillType ~= nil and abstractObject.getFillUnitFillLevel ~= nil then
        local indices = {}
        if abstractObject.getFillUnits ~= nil then
            local okUnits, fillUnits = pcall(abstractObject.getFillUnits, abstractObject)
            if okUnits and type(fillUnits) == "table" then
                for index, _ in pairs(fillUnits) do table.insert(indices, index) end
            end
        end
        if #indices == 0 then
            for index=1,8 do table.insert(indices, index) end
        end
        for _, index in ipairs(indices) do
            local okType, valueType = pcall(abstractObject.getFillUnitFillType, abstractObject, index)
            local okLevel, valueLevel = pcall(abstractObject.getFillUnitFillLevel, abstractObject, index)
            valueType = okType and normalizeFillType(valueType) or nil
            valueLevel = okLevel and tonumber(valueLevel) or nil
            if valueType ~= nil and valueLevel ~= nil and valueLevel > 0.001 then
                return valueType, math.max(0, valueLevel), getFarmId(abstractObject)
            end
        end
    end

    local fillType, fillLevel, farmId = readDataTable(abstractObject, 0, {}, getFarmId(abstractObject))
    if fillType ~= nil then return fillType, fillLevel, farmId end

    local realObject = nil
    if abstractObject.getRealObject ~= nil then
        local ok, value = pcall(abstractObject.getRealObject, abstractObject)
        if ok then realObject = value end
    end
    if realObject ~= nil then
        if realObject.spec_bigBag ~= nil then
            local realFillType, realFillLevel = self:getBigBagVehicleFillData(realObject, nil)
            if realFillType ~= nil then
                return realFillType, realFillLevel, getFarmId(realObject)
            end
        end
        if realObject.getFillType ~= nil and realObject.getFillLevel ~= nil then
            local okType, realFillType = pcall(realObject.getFillType, realObject)
            local okLevel, realFillLevel = pcall(realObject.getFillLevel, realObject)
            realFillType = okType and normalizeFillType(realFillType) or nil
            realFillLevel = okLevel and tonumber(realFillLevel) or nil
            if realFillType ~= nil and realFillLevel ~= nil then
                return realFillType, math.max(0, realFillLevel), getFarmId(realObject)
            end
        end
    end

    return nil, 0, getFarmId(abstractObject)
end

function M:isObjectStorageBale(abstractObject, fillTypeIndex)
    if abstractObject == nil then return false end
    if abstractObject.REFERENCE_CLASS_NAME ~= nil and abstractObject.REFERENCE_CLASS_NAME ~= "Bale" then
        return false
    end
    local fillType, fillLevel = self:getObjectStorageBaleData(abstractObject)
    if fillType == nil or fillLevel <= 0.001 then return false end
    if fillTypeIndex ~= nil and fillType ~= fillTypeIndex then return false end

    if g_fillTypeManager ~= nil and g_fillTypeManager.getFillTypeByIndex ~= nil then
        local desc = g_fillTypeManager:getFillTypeByIndex(fillType)
        if desc ~= nil and desc.isBaleType ~= nil and desc.isBaleType ~= true then
            return false
        end
    end
    return true
end

function M:isObjectStorageBigBag(abstractObject, fillTypeIndex)
    if abstractObject == nil then return false end

    local function hasBigBagFlag(data, depth, visited)
        if type(data) ~= "table" or depth > 4 or visited[data] then return false end
        visited[data] = true
        if data.isBigBag == true then return true end
        local nestedKeys = {
            "attributes", "vehicleAttributes", "palletAttributes", "objectAttributes",
            "baleAttributes", "data", "savegameData"
        }
        for _, key in ipairs(nestedKeys) do
            if hasBigBagFlag(data[key], depth + 1, visited) then return true end
        end
        return false
    end

    local isBigBag = hasBigBagFlag(abstractObject, 0, {})
    if not isBigBag then
        local filename = self:getObjectStorageXMLFilename(abstractObject)
        if filename ~= nil and string.find(string.lower(filename), "bigbag", 1, true) ~= nil then
            isBigBag = true
        end
    end

    if not isBigBag and abstractObject.getRealObject ~= nil then
        local ok, realObject = pcall(abstractObject.getRealObject, abstractObject)
        if ok and realObject ~= nil and realObject.spec_bigBag ~= nil then isBigBag = true end
    end
    if not isBigBag then return false end

    local fillType, fillLevel = self:getObjectStorageBaleData(abstractObject)
    if fillType == nil or fillLevel <= 0.001 then return false end
    if fillTypeIndex ~= nil and fillType ~= fillTypeIndex then return false end
    return true
end

function M:setObjectStorageBaleLevel(abstractObject, level)
    if abstractObject == nil then return false end
    level = math.max(0, tonumber(level) or 0)

    local changed = false
    if abstractObject.setFillLevel ~= nil then
        local ok = pcall(abstractObject.setFillLevel, abstractObject, level)
        if ok then changed = true end
    end

    local visited = {}
    local function updateData(data, depth)
        if type(data) ~= "table" or depth > 5 or visited[data] then return end
        visited[data] = true

        local hasFillType = data.fillType ~= nil or data.fillTypeIndex ~= nil
            or data.fillTypeName ~= nil or data.fillUnitFillType ~= nil
        if hasFillType then
            if data.fillLevel ~= nil then data.fillLevel = level; changed = true end
            if data.fillUnitFillLevel ~= nil then data.fillUnitFillLevel = level; changed = true end
            if data.amount ~= nil and data.fillLevel == nil and data.fillUnitFillLevel == nil then
                data.amount = level
                changed = true
            end
        end

        local nestedKeys = {
            "attributes", "vehicleAttributes", "palletAttributes", "objectAttributes",
            "baleAttributes", "vehicleData", "objectData", "palletData", "fillData",
            "fillLevelData", "data", "savegameData", "state", "fillUnit", "fillUnits", "fillUnitData"
        }
        for _, key in ipairs(nestedKeys) do
            local value = data[key]
            if type(value) == "table" then
                updateData(value, depth + 1)
                for _, nested in pairs(value) do
                    if type(nested) == "table" then updateData(nested, depth + 1) end
                end
            end
        end
    end
    updateData(abstractObject, 0)

    local realObject = nil
    if abstractObject.getRealObject ~= nil then
        local ok, value = pcall(abstractObject.getRealObject, abstractObject)
        if ok then realObject = value end
    end
    if realObject ~= nil then
        if realObject.spec_bigBag ~= nil and realObject.getFillUnitFillLevel ~= nil and realObject.addFillUnitFillLevel ~= nil then
            local fillType, oldLevel, fillUnitIndex = self:getBigBagVehicleFillData(realObject, nil)
            if fillType ~= nil and fillUnitIndex ~= nil then
                local farmId = 0
                if realObject.getOwnerFarmId ~= nil then
                    local okFarm, ownerFarmId = pcall(realObject.getOwnerFarmId, realObject)
                    if okFarm then farmId = tonumber(ownerFarmId) or 0 end
                end
                local toolType = ToolType ~= nil and ToolType.UNDEFINED or nil
                local ok = pcall(realObject.addFillUnitFillLevel, realObject, farmId, fillUnitIndex,
                    level - oldLevel, fillType, toolType, nil)
                if ok then changed = true end
            end
        elseif realObject.setFillLevel ~= nil then
            local ok = pcall(realObject.setFillLevel, realObject, level)
            if ok then changed = true end
        end
    end

    return changed
end

function M:markObjectStorageDirty(placeable)
    if placeable == nil then return end
    if placeable.setObjectStorageObjectInfosDirty ~= nil then
        placeable:setObjectStorageObjectInfosDirty()
    elseif placeable.updateObjectStorageObjectInfos ~= nil then
        placeable:updateObjectStorageObjectInfos()
    end
end

function M:removeEmptyObjectStorageBale(placeable, abstractObject)
    local spec = placeable and placeable.spec_objectStorage
    if spec == nil or spec.storedObjects == nil or abstractObject == nil then return false end
    for i=#spec.storedObjects,1,-1 do
        if spec.storedObjects[i] == abstractObject then
            if abstractObject.delete ~= nil then pcall(abstractObject.delete, abstractObject) end
            table.remove(spec.storedObjects, i)
            spec.numStoredObjects = #spec.storedObjects
            self:markObjectStorageDirty(placeable)
            return true
        end
    end
    return false
end

function M:getFarmStorageSources(farmId, fillTypeIndex)
    local result, seen = {}, {}
    local mission = g_currentMission
    local placeables = mission and mission.placeableSystem and mission.placeableSystem.placeables or nil

    if placeables ~= nil then
        for _, placeable in pairs(placeables) do
            if placeable ~= nil and not placeable.isDeleted then
                local placeableAccess = self:hasFarmAccessToObject(farmId, placeable)

                if placeableAccess and placeable.spec_silo ~= nil
                    and placeable.spec_bunkerSilo == nil and placeable.spec_multiBunkerSilo == nil then
                    local spec = placeable.spec_silo
                    local station = spec.loadingStation
                    local storages = station ~= nil and station.sourceStorages or spec.storages
                    if storages ~= nil then
                        for _, storage in pairs(storages) do
                            if storage ~= nil and not seen[storage] and storage.getFillLevel ~= nil and storage.setFillLevel ~= nil then
                                local hasAccess = true
                                if station ~= nil and station.hasFarmAccessToStorage ~= nil then
                                    hasAccess = station:hasFarmAccessToStorage(farmId, storage)
                                end
                                if hasAccess then
                                    local level = math.max(0, storage:getFillLevel(fillTypeIndex) or 0)
                                    if level > 0.001 then
                                        seen[storage] = true
                                        table.insert(result, {kind="storage", storage=storage, level=level, placeable=placeable})
                                    end
                                end
                            end
                        end
                    end
                end

                local extensionSpec = placeable.spec_siloExtension
                local extensionStorage = extensionSpec ~= nil and extensionSpec.storage or nil
                if placeableAccess and extensionStorage ~= nil and not seen[extensionStorage]
                    and extensionStorage.getFillLevel ~= nil and extensionStorage.setFillLevel ~= nil then
                    local supported = true
                    if extensionStorage.getIsFillTypeSupported ~= nil then
                        local okSupported, value = pcall(extensionStorage.getIsFillTypeSupported, extensionStorage, fillTypeIndex)
                        if okSupported then supported = value == true end
                    end
                    if supported then
                        local level = math.max(0, extensionStorage:getFillLevel(fillTypeIndex) or 0)
                        if level > 0.001 then
                            seen[extensionStorage] = true
                            table.insert(result, {kind="storage", storage=extensionStorage, level=level, placeable=placeable})
                        end
                    end
                end

                local objectSpec = placeable.spec_objectStorage
                if objectSpec ~= nil and objectSpec.storedObjects ~= nil then
                    for _, abstractObject in ipairs(objectSpec.storedObjects) do
                        local objectFillType, objectLevel, objectFarmId = self:getObjectStorageBaleData(abstractObject)
                        if objectFillType == fillTypeIndex and objectLevel > 0.001 then
                            local objectAccess = objectFarmId == farmId
                                or ((objectFarmId == nil or objectFarmId == 0) and placeableAccess)
                            if objectAccess then
                                local isBigBag = self:isObjectStorageBigBag(abstractObject, fillTypeIndex)
                                local isBale = not isBigBag and self:isObjectStorageBale(abstractObject, fillTypeIndex)
                                local supportsPallets = objectSpec.supportsPallets ~= false
                                local supportsBales = objectSpec.supportsBales == true

                                if isBigBag or isBale or supportsPallets then
                                    local kind = "palletStorage"
                                    if isBigBag then
                                        kind = "bigBagStorage"
                                    elseif isBale and supportsBales then
                                        kind = "baleStorage"
                                    elseif isBale and not supportsPallets then
                                        kind = "baleStorage"
                                    end

                                    table.insert(result, {
                                        kind=kind,
                                        placeable=placeable,
                                        object=abstractObject,
                                        level=objectLevel
                                    })
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    local vehicles = mission and mission.vehicleSystem and mission.vehicleSystem.vehicles or nil
    if vehicles ~= nil then
        for _, vehicle in pairs(vehicles) do
            if vehicle ~= nil and not vehicle.isDeleted and vehicle.spec_bigBag ~= nil and not seen[vehicle]
                and self:hasFarmAccessToObject(farmId, vehicle) then
                local objectFillType, objectLevel, fillUnitIndex = self:getBigBagVehicleFillData(vehicle, fillTypeIndex)
                if objectFillType == fillTypeIndex and objectLevel > 0.001 and fillUnitIndex ~= nil then
                    seen[vehicle] = true
                    table.insert(result, {
                        kind="bigBagVehicle",
                        vehicle=vehicle,
                        fillUnitIndex=fillUnitIndex,
                        level=objectLevel
                    })
                end
            end
        end
    end

    return result
end

function M:getFarmStorageAmount(farmId, fillTypeIndex)
    local total = 0
    for _, source in ipairs(self:getFarmStorageSources(farmId, fillTypeIndex)) do
        total = total + source.level
    end
    return total
end

function M:takeFromFarmStorage(farmId, fillTypeIndex, requested)
    local remaining = math.max(0, requested or 0)
    local removed, reservations = 0, {}
    if remaining <= 0.001 then return 0, reservations end

    for _, source in ipairs(self:getFarmStorageSources(farmId, fillTypeIndex)) do
        local oldLevel = 0
        if source.kind == "storage" then
            oldLevel = math.max(0, source.storage:getFillLevel(fillTypeIndex) or 0)
        elseif source.kind == "baleStorage" or source.kind == "bigBagStorage" or source.kind == "palletStorage" then
            local _, level = self:getObjectStorageBaleData(source.object)
            oldLevel = math.max(0, level or 0)
        elseif source.kind == "bigBagVehicle" and source.vehicle ~= nil and not source.vehicle.isDeleted then
            oldLevel = math.max(0, source.vehicle:getFillUnitFillLevel(source.fillUnitIndex) or 0)
        end

        local moved = math.min(oldLevel, remaining)
        if moved > 0.001 then
            if source.kind == "storage" then
                source.storage:setFillLevel(oldLevel - moved, fillTypeIndex, nil)
                table.insert(reservations, {kind="storage", storage=source.storage, amount=moved})
            elseif source.kind == "baleStorage" or source.kind == "bigBagStorage" or source.kind == "palletStorage" then
                if self:setObjectStorageBaleLevel(source.object, oldLevel - moved) then
                    local _, afterLevel = self:getObjectStorageBaleData(source.object)
                    afterLevel = math.max(0, tonumber(afterLevel) or oldLevel)
                    moved = math.max(0, math.min(moved, oldLevel - afterLevel))
                    if moved > 0.001 then
                        self:markObjectStorageDirty(source.placeable)
                        table.insert(reservations, {
                            kind=source.kind,
                            placeable=source.placeable,
                            object=source.object,
                            amount=moved
                        })
                    end
                else
                    moved = 0
                end
            elseif source.kind == "bigBagVehicle" and source.vehicle ~= nil and not source.vehicle.isDeleted
                and source.vehicle.addFillUnitFillLevel ~= nil then
                local toolType = ToolType ~= nil and ToolType.UNDEFINED or nil
                local before = math.max(0, source.vehicle:getFillUnitFillLevel(source.fillUnitIndex) or 0)
                pcall(source.vehicle.addFillUnitFillLevel, source.vehicle, farmId, source.fillUnitIndex, -moved, fillTypeIndex, toolType, nil)
                local after = math.max(0, source.vehicle:getFillUnitFillLevel(source.fillUnitIndex) or 0)
                moved = math.max(0, math.min(moved, before - after))
                if moved > 0.001 then
                    table.insert(reservations, {
                        kind="bigBagVehicle",
                        vehicle=source.vehicle,
                        fillUnitIndex=source.fillUnitIndex,
                        farmId=farmId,
                        amount=moved
                    })
                end
            else
                moved = 0
            end

            if moved > 0.001 then
                removed = removed + moved
                remaining = remaining - moved
                if remaining <= 0.001 then break end
            end
        end
    end
    return removed, reservations
end

function M:returnToFarmStorage(fillTypeIndex, reservations, amount)
    local remaining = math.max(0, amount or 0)
    if remaining <= 0.001 then return end
    for i=#reservations,1,-1 do
        local reservation = reservations[i]
        local moved = math.min(reservation.amount or 0, remaining)
        if moved > 0.001 then
            if reservation.kind == "storage" then
                local oldLevel = math.max(0, reservation.storage:getFillLevel(fillTypeIndex) or 0)
                reservation.storage:setFillLevel(oldLevel + moved, fillTypeIndex, nil)
            elseif reservation.kind == "baleStorage" or reservation.kind == "bigBagStorage" or reservation.kind == "palletStorage" then
                local _, oldLevel = self:getObjectStorageBaleData(reservation.object)
                if self:setObjectStorageBaleLevel(reservation.object, math.max(0, oldLevel or 0) + moved) then
                    self:markObjectStorageDirty(reservation.placeable)
                end
            elseif reservation.kind == "bigBagVehicle" and reservation.vehicle ~= nil and not reservation.vehicle.isDeleted
                and reservation.vehicle.addFillUnitFillLevel ~= nil then
                local toolType = ToolType ~= nil and ToolType.UNDEFINED or nil
                pcall(reservation.vehicle.addFillUnitFillLevel, reservation.vehicle, reservation.farmId or 0,
                    reservation.fillUnitIndex, moved, fillTypeIndex, toolType, nil)
            end
            reservation.amount = math.max(0, (reservation.amount or 0) - moved)
            remaining = remaining - moved
            if remaining <= 0.001 then break end
        end
    end
end

function M:finalizeFarmStorageReservations(reservations)
    local checked = {}
    for _, reservation in ipairs(reservations or {}) do
        if (reservation.kind == "baleStorage" or reservation.kind == "bigBagStorage" or reservation.kind == "palletStorage")
            and reservation.object ~= nil and not checked[reservation.object] then
            checked[reservation.object] = true
            local _, level = self:getObjectStorageBaleData(reservation.object)
            if (level or 0) <= 0.001 then
                self:removeEmptyObjectStorageBale(reservation.placeable, reservation.object)
            else
                self:markObjectStorageDirty(reservation.placeable)
            end
        elseif reservation.kind == "bigBagVehicle" and reservation.vehicle ~= nil
            and not checked[reservation.vehicle] then
            checked[reservation.vehicle] = true
            local vehicle = reservation.vehicle
            if not vehicle.isDeleted and vehicle.getFillUnitFillLevel ~= nil then
                local level = math.max(0, vehicle:getFillUnitFillLevel(reservation.fillUnitIndex) or 0)
                if level <= 0.001 and vehicle.delete ~= nil then
                    pcall(vehicle.delete, vehicle)
                end
            end
        end
    end
end

function M:getReservationOriginText(reservations)
    local bulk, bales, bigBags, pallets = false, false, false, false
    for _, reservation in ipairs(reservations or {}) do
        if (reservation.amount or 0) > 0.001 then
            if reservation.kind == "baleStorage" then
                bales = true
            elseif reservation.kind == "bigBagStorage" or reservation.kind == "bigBagVehicle" then
                bigBags = true
            elseif reservation.kind == "palletStorage" then
                pallets = true
            else
                bulk = true
            end
        end
    end
    local parts = {}
    if bulk then table.insert(parts, "Hoflager/Silo") end
    if bales then table.insert(parts, "Ballenlager") end
    if bigBags then table.insert(parts, "BigBag-Bestand") end
    if pallets then table.insert(parts, "Palettenlager") end
    return #parts > 0 and table.concat(parts, " + ") or "Hoflager/Silo"
end

function M:getSpecialPetFeedFillType(placeable)
    if placeable == nil or g_fillTypeManager == nil then return nil, nil end
    local filename = tostring(placeable.configFileName or placeable.xmlFilename or ""):lower()
    local name = ""
    if placeable.getName ~= nil then
        local ok, value = pcall(placeable.getName, placeable)
        if ok and value ~= nil then name = tostring(value):lower() end
    end

    local fillTypeName, label = nil, nil
    if string.find(filename, "/animalhusbandry/doghouse/", 1, true) ~= nil
        or string.find(filename, "doghouse", 1, true) ~= nil
        or string.find(name, "hund", 1, true) ~= nil then
        fillTypeName, label = "DOGFOOD", "Hundefutter"
    elseif string.find(filename, "/animalhusbandry/catzone/", 1, true) ~= nil
        or string.find(filename, "catzone", 1, true) ~= nil
        or string.find(name, "katze", 1, true) ~= nil then
        fillTypeName, label = "CATFOOD", "Katzenfutter"
    end

    if fillTypeName == nil then return nil, nil end
    return g_fillTypeManager:getFillTypeIndexByName(fillTypeName), label
end

function M:isPigletFeedFillType(fillTypeIndex)
    if fillTypeIndex == nil or g_fillTypeManager == nil then return false end

    local pigletFeedIndex = nil
    if g_fillTypeManager.getFillTypeIndexByName ~= nil then
        pigletFeedIndex = g_fillTypeManager:getFillTypeIndexByName("PIGLETFEED")
        if pigletFeedIndex == nil then
            pigletFeedIndex = g_fillTypeManager:getFillTypeIndexByName("pigletFeed")
        end
    end
    if pigletFeedIndex ~= nil and pigletFeedIndex == fillTypeIndex then return true end

    local function normalize(value)
        if value == nil then return "" end
        return string.lower(tostring(value)):gsub("[^%w]", "")
    end

    local fillTypeName = nil
    if g_fillTypeManager.getFillTypeNameByIndex ~= nil then
        fillTypeName = g_fillTypeManager:getFillTypeNameByIndex(fillTypeIndex)
    end
    local normalizedName = normalize(fillTypeName)
    if normalizedName == "pigletfeed" or normalizedName == "ferkelfutter" then return true end

    local title = nil
    if g_fillTypeManager.getFillTypeTitleByIndex ~= nil then
        title = g_fillTypeManager:getFillTypeTitleByIndex(fillTypeIndex)
    end
    local normalizedTitle = normalize(title)
    return normalizedTitle == "pigletfeed" or normalizedTitle == "ferkelfutter"
end

function M:getHusbandryClusters(placeable)
    if placeable == nil then return nil end

    if placeable.getClusters ~= nil then
        local ok, clusters = pcall(placeable.getClusters, placeable)
        if ok and type(clusters) == "table" then return clusters end
    end

    local animalSpec = placeable.spec_husbandryAnimals
    if animalSpec ~= nil and animalSpec.clusterSystem ~= nil
        and animalSpec.clusterSystem.getClusters ~= nil then
        local ok, clusters = pcall(animalSpec.clusterSystem.getClusters, animalSpec.clusterSystem)
        if ok and type(clusters) == "table" then return clusters end
    end

    return nil
end

function M:shouldSkipPigletFeed(placeable, fillTypeIndex)
    if not self:isPigletFeedFillType(fillTypeIndex) then return false end

    local clusters = self:getHusbandryClusters(placeable)
    if clusters == nil then return false end

    local maxAge = tonumber(self.pigletFeedMaxAgeMonths) or 6
    local sawAnimal = false
    local sawKnownAge = false

    for _, cluster in pairs(clusters) do
        if cluster ~= nil then
            local amount = nil
            if cluster.getNumAnimals ~= nil then
                local ok, value = pcall(cluster.getNumAnimals, cluster)
                if ok then amount = tonumber(value) end
            end
            if amount == nil and type(cluster) == "table" then
                amount = tonumber(cluster.numAnimals or cluster.numAnimalsInCluster or cluster.count)
            end

            if amount ~= nil and amount > 0 then
                sawAnimal = true

                local age = nil
                if cluster.getAge ~= nil then
                    local ok, value = pcall(cluster.getAge, cluster)
                    if ok then age = tonumber(value) end
                end
                if age == nil and type(cluster) == "table" then
                    age = tonumber(cluster.age)
                end

                if age == nil then return false end

                sawKnownAge = true
                if age < maxAge then
                    return false
                end
            end
        end
    end

    return sawAnimal and sawKnownAge
end

function M:getFoodFillCandidates(placeable, farmId)
    local spec = placeable and placeable.spec_husbandryFood
    if spec == nil then return {} end
    local animalFoodSystem = g_currentMission and g_currentMission.animalFoodSystem
    local animalFood = animalFoodSystem ~= nil and animalFoodSystem.getAnimalFood ~= nil
        and animalFoodSystem:getAnimalFood(spec.animalTypeIndex) or nil
    local groups = {}
    if animalFood ~= nil and animalFood.groups ~= nil then
        for _, group in pairs(animalFood.groups) do table.insert(groups, group) end
        table.sort(groups, function(a,b)
            return (tonumber(a.productionWeight) or 0) > (tonumber(b.productionWeight) or 0)
        end)
    end
    local candidates, seen = {}, {}
    for _, group in ipairs(groups) do
        local groupCandidates = {}
        for _, fillTypeIndex in pairs(group.fillTypes or {}) do
            if not seen[fillTypeIndex] and (spec.supportedFillTypes == nil or spec.supportedFillTypes[fillTypeIndex] ~= nil) then
                seen[fillTypeIndex] = true
                if not self:shouldSkipPigletFeed(placeable, fillTypeIndex) then
                    local available = self:getFarmStorageAmount(farmId, fillTypeIndex)
                    table.insert(groupCandidates, {
                        fillType=fillTypeIndex,
                        productionWeight=tonumber(group.productionWeight) or 0,
                        available=available
                    })
                end
            end
        end
        table.sort(groupCandidates, function(a,b) return a.available > b.available end)
        for _, candidate in ipairs(groupCandidates) do
            if candidate.available > 0.001 then table.insert(candidates, candidate) end
        end
    end
    for fillTypeIndex,_ in pairs(spec.supportedFillTypes or {}) do
        if not seen[fillTypeIndex] then
            seen[fillTypeIndex] = true
            if not self:shouldSkipPigletFeed(placeable, fillTypeIndex) then
                local available = self:getFarmStorageAmount(farmId, fillTypeIndex)
                if available > 0.001 then
                    table.insert(candidates, {fillType=fillTypeIndex, productionWeight=0, available=available})
                end
            end
        end
    end

    local petFillType = self:getSpecialPetFeedFillType(placeable)
    if petFillType ~= nil and not seen[petFillType] then
        local available = self:getFarmStorageAmount(farmId, petFillType)
        if available > 0.001 then
            table.insert(candidates, {fillType=petFillType, productionWeight=0, available=available})
        end
    end
    return candidates
end

function M:percentText(current, capacity)
    if capacity == nil or capacity <= 0 then return "-" end
    return string.format("%d%%", math.floor(math.max(0, math.min(1, current / capacity)) * 100 + 0.5))
end

function M:canAnimalWorkerContinue(worker)
    return worker ~= nil and (self:isTemporaryEmployee(worker) or worker.hours < worker.limit)
end

function M:getHusbandryAnimalCount(placeable)
    if placeable == nil then return 0 end

    if placeable.getNumOfAnimals ~= nil then
        local ok, value = pcall(placeable.getNumOfAnimals, placeable)
        if ok and tonumber(value) ~= nil then
            return math.max(0, tonumber(value) or 0)
        end
    end

    local clusters = nil
    if placeable.getClusters ~= nil then
        local ok, value = pcall(placeable.getClusters, placeable)
        if ok and type(value) == "table" then clusters = value end
    end
    local animalSpec = placeable.spec_husbandryAnimals
    if clusters == nil and animalSpec ~= nil and animalSpec.clusterSystem ~= nil
        and animalSpec.clusterSystem.getClusters ~= nil then
        local ok, value = pcall(animalSpec.clusterSystem.getClusters, animalSpec.clusterSystem)
        if ok and type(value) == "table" then clusters = value end
    end

    local total = 0
    for _, cluster in pairs(clusters or {}) do
        local amount = nil
        if cluster ~= nil and cluster.getNumAnimals ~= nil then
            local ok, value = pcall(cluster.getNumAnimals, cluster)
            if ok then amount = tonumber(value) end
        end
        if amount == nil and type(cluster) == "table" then
            amount = tonumber(cluster.numAnimals or cluster.numAnimalsInCluster or cluster.count)
        end
        total = total + math.max(0, amount or 0)
    end
    return total
end

function M:getOccupiedHusbandries(farmId)
    local occupied, ownedCount = {}, 0
    local mission = g_currentMission
    local placeables = mission and mission.placeableSystem and mission.placeableSystem.placeables or nil
    if placeables == nil then return occupied, ownedCount end

    for _, placeable in pairs(placeables) do
        if placeable ~= nil and not placeable.isDeleted and placeable.spec_husbandry ~= nil
            and placeable.getOwnerFarmId ~= nil then
            local okOwner, ownerFarmId = pcall(placeable.getOwnerFarmId, placeable)
            if okOwner and ownerFarmId == farmId then
                ownedCount = ownedCount + 1
                local numAnimals = self:getHusbandryAnimalCount(placeable)
                if numAnimals > 0 then
                    table.insert(occupied, {placeable=placeable, numAnimals=numAnimals})
                end
            end
        end
    end
    return occupied, ownedCount
end

function M:getFillDemand(placeable, fillTypeIndex)
    if placeable == nil or fillTypeIndex == nil or placeable.getHusbandryCapacity == nil
        or placeable.getHusbandryFillLevel == nil then return nil end
    local capacity = math.max(0, placeable:getHusbandryCapacity(fillTypeIndex) or 0)
    if capacity <= 0.001 then return nil end
    local current = math.max(0, placeable:getHusbandryFillLevel(fillTypeIndex) or 0)
    local ratio = current / capacity
    if ratio >= self.animalServiceThreshold then return nil end
    return {
        capacity=capacity,
        current=current,
        demand=math.max(0, capacity * self.animalServiceTarget - current)
    }
end

function M:buildFairRequests(entries, totalAmount)
    local requests = {}
    totalAmount = math.max(0, tonumber(totalAmount) or 0)
    if totalAmount <= 0.001 or entries == nil or #entries == 0 then return requests end

    local totalDemand = 0
    local minRatio = self.animalServiceTarget
    for _, entry in ipairs(entries) do
        local capacity = math.max(0, tonumber(entry.capacity) or 0)
        local current = math.max(0, tonumber(entry.current) or 0)
        local demand = math.max(0, tonumber(entry.demand) or 0)
        if capacity > 0.001 and demand > 0.001 then
            totalDemand = totalDemand + demand
            minRatio = math.min(minRatio, current / capacity)
        end
    end

    if totalDemand <= 0.001 then return requests end
    if totalAmount >= totalDemand - 0.001 then
        for _, entry in ipairs(entries) do requests[entry] = math.max(0, entry.demand or 0) end
        return requests
    end

    local low, high = minRatio, self.animalServiceTarget
    for _=1,36 do
        local middle = (low + high) * 0.5
        local needed = 0
        for _, entry in ipairs(entries) do
            local capacity = math.max(0, entry.capacity or 0)
            if capacity > 0.001 then
                local current = math.max(0, entry.current or 0)
                needed = needed + math.max(0, math.min(entry.demand or 0, middle * capacity - current))
            end
        end
        if needed <= totalAmount then low = middle else high = middle end
    end

    local used = 0
    for _, entry in ipairs(entries) do
        local capacity = math.max(0, entry.capacity or 0)
        local current = math.max(0, entry.current or 0)
        local amount = math.max(0, math.min(entry.demand or 0, low * capacity - current))
        requests[entry] = amount
        used = used + amount
    end

    local leftover = math.max(0, totalAmount - used)
    if leftover > 0.001 then
        for _, entry in ipairs(entries) do
            if leftover <= 0.001 then break end
            local currentRequest = requests[entry] or 0
            local room = math.max(0, (entry.demand or 0) - currentRequest)
            local extra = math.min(room, leftover)
            requests[entry] = currentRequest + extra
            leftover = leftover - extra
        end
    end
    return requests
end

function M:serviceFoodFair(husbandries, farmId, worker)
    local entries, fillMeta = {}, {}

    for _, item in ipairs(husbandries or {}) do
        local placeable = item.placeable or item
        local spec = placeable and placeable.spec_husbandryFood
        if spec ~= nil and placeable.getTotalFood ~= nil and placeable.getFoodCapacity ~= nil
            and placeable.addFood ~= nil then
            local capacity = math.max(0, placeable:getFoodCapacity() or 0)
            local current = math.max(0, placeable:getTotalFood() or 0)
            if capacity > 0.001 and current / capacity < self.animalServiceThreshold then
                local entry = {
                    placeable=placeable,
                    name=self:getPlaceableName(placeable),
                    capacity=capacity,
                    current=current,
                    demand=math.max(0, capacity * self.animalServiceTarget - current),
                    candidateMap={},
                    added=0,
                    sawCandidate=false
                }
                for _, candidate in ipairs(self:getFoodFillCandidates(placeable, farmId)) do
                    if candidate.fillType ~= nil then
                        entry.candidateMap[candidate.fillType] = true
                        entry.sawCandidate = true
                        local meta = fillMeta[candidate.fillType]
                        if meta == nil then
                            meta = {fillType=candidate.fillType, productionWeight=tonumber(candidate.productionWeight) or 0}
                            fillMeta[candidate.fillType] = meta
                        else
                            meta.productionWeight = math.max(meta.productionWeight, tonumber(candidate.productionWeight) or 0)
                        end
                    end
                end
                table.insert(entries, entry)
            end
        end
    end

    local fillTypes = {}
    for _, meta in pairs(fillMeta) do table.insert(fillTypes, meta) end
    table.sort(fillTypes, function(a,b)
        if a.productionWeight ~= b.productionWeight then return a.productionWeight > b.productionWeight end
        return (tonumber(a.fillType) or 0) < (tonumber(b.fillType) or 0)
    end)

    for _, meta in ipairs(fillTypes) do
        local available = self:getFarmStorageAmount(farmId, meta.fillType)
        if available > 0.001 then
            local eligible, totalDemand = {}, 0
            for _, entry in ipairs(entries) do
                entry.current = math.max(0, entry.placeable:getTotalFood() or entry.current)
                entry.demand = math.max(0, entry.capacity * self.animalServiceTarget - entry.current)
                if entry.demand > 0.001 and entry.candidateMap[meta.fillType] then
                    totalDemand = totalDemand + entry.demand
                    table.insert(eligible, entry)
                end
            end

            local distributable = math.min(available, totalDemand)
            local requests = self:buildFairRequests(eligible, distributable)
            for _, entry in ipairs(eligible) do
                local requested = requests[entry] or 0
                if requested > 0.001 then
                    local removed, reservations = self:takeFromFarmStorage(farmId, meta.fillType, requested)
                    if removed > 0.001 then
                        local added = entry.placeable:addFood(farmId, removed, meta.fillType, nil, nil, nil) or 0
                        added = math.max(0, math.min(removed, added))
                        if removed - added > 0.001 then
                            self:returnToFarmStorage(meta.fillType, reservations, removed - added)
                        end
                        self:finalizeFarmStorageReservations(reservations)
                        entry.added = entry.added + added
                    end
                end
            end
        end
    end

    for _, entry in ipairs(entries) do
        local after = math.max(0, entry.placeable:getTotalFood() or entry.current)
        local remaining = math.max(0, entry.capacity * self.animalServiceTarget - after)
        if entry.added > 0.001 then
            if self:canAnimalWorkerContinue(worker) then
                self:addWorkHours(worker, self:getServiceWorkHours(worker, "animals", self.animalServiceHours))
            end
            self:setAutoTask(worker, "Tierhaltung · " .. entry.name .. " · Futter")
        end
        if remaining > 0.001 then
            if not entry.sawCandidate then
                self:notifyProblem(string.format("Tierhaltung: %s – kein passendes Futter im Hoflager/Silo/Ballen-/Paletten-/BigBag-Lager.", entry.name))
            elseif entry.added <= 0.001 then
                self:notifyProblem(string.format("Tierhaltung: %s – vorhandenes Futter konnte nicht übernommen werden.", entry.name))
            else
                self:notifyProblem(string.format("Tierhaltung: %s – Futter wurde fair verteilt, reicht aber nicht bis zum Zielstand.", entry.name))
            end
        end
    end

    return #entries > 0
end

function M:serviceStoredFillEntriesFair(entries, farmId, worker)
    local groups = {}
    for _, entry in ipairs(entries or {}) do
        if entry.fillType ~= nil and entry.demand ~= nil and entry.demand > 0.001 then
            local group = groups[entry.fillType]
            if group == nil then group = {}; groups[entry.fillType] = group end
            table.insert(group, entry)
        end
    end

    for fillTypeIndex, group in pairs(groups) do
        local available = self:getFarmStorageAmount(farmId, fillTypeIndex)
        local totalDemand = 0
        for _, entry in ipairs(group) do totalDemand = totalDemand + math.max(0, entry.demand or 0) end
        local distributable = math.min(available, totalDemand)
        local requests = self:buildFairRequests(group, distributable)

        for _, entry in ipairs(group) do
            entry.availableSeen = available
            local requested = requests[entry] or 0
            if requested > 0.001 then
                local removed, reservations = self:takeFromFarmStorage(farmId, fillTypeIndex, requested)
                if removed > 0.001 then
                    local added = entry.placeable:addHusbandryFillLevelFromTool(farmId, removed, fillTypeIndex, nil, nil, nil) or 0
                    added = math.max(0, math.min(removed, added))
                    if removed - added > 0.001 then
                        self:returnToFarmStorage(fillTypeIndex, reservations, removed - added)
                    end
                    self:finalizeFarmStorageReservations(reservations)
                    entry.added = (entry.added or 0) + added
                end
            end
        end
    end

    for _, entry in ipairs(entries or {}) do
        local after = entry.placeable:getHusbandryFillLevel(entry.fillType) or entry.current or 0
        local remaining = math.max(0, entry.capacity * self.animalServiceTarget - after)
        local added = entry.added or 0
        if added > 0.001 then
            if self:canAnimalWorkerContinue(worker) then
                self:addWorkHours(worker, self:getServiceWorkHours(worker, "animals", self.animalServiceHours))
            end
            self:setAutoTask(worker, "Tierhaltung · " .. entry.name .. " · " .. entry.label)
        end
        if remaining > 0.001 then
            if (entry.availableSeen or 0) <= 0.001 then
                self:notifyProblem(string.format("Tierhaltung: %s – kein %s im Hoflager/Silo/Ballen-/Paletten-/BigBag-Lager.", entry.name, entry.label))
            elseif added <= 0.001 then
                self:notifyProblem(string.format("Tierhaltung: %s – %s konnte nicht aufgefüllt werden; Lagerbestand blieb erhalten.", entry.name, entry.label))
            else
                self:notifyProblem(string.format("Tierhaltung: %s – %s wurde fair verteilt, reicht aber nicht bis zum Zielstand.", entry.name, entry.label))
            end
        end
    end
end

function M:buildPetFeedEntries(husbandries)
    local entries = {}
    for _, item in ipairs(husbandries or {}) do
        local placeable = item.placeable or item
        local normalFood = placeable.spec_husbandryFood ~= nil and placeable.getTotalFood ~= nil
            and placeable.getFoodCapacity ~= nil and placeable.addFood ~= nil
        if not normalFood and placeable.addHusbandryFillLevelFromTool ~= nil then
            local fillTypeIndex, label = self:getSpecialPetFeedFillType(placeable)
            if fillTypeIndex ~= nil then
                local demand = self:getFillDemand(placeable, fillTypeIndex)
                if demand ~= nil then
                    demand.placeable = placeable
                    demand.fillType = fillTypeIndex
                    demand.label = label or "Tierfutter"
                    demand.name = self:getPlaceableName(placeable)
                    table.insert(entries, demand)
                end
            end
        end
    end
    return entries
end

function M:isHusbandryBeddingFillTypeConfigured(placeable, fillTypeIndex)
    if placeable == nil or fillTypeIndex == nil or placeable.getHusbandryCapacity == nil then return false end

    local okCapacity, capacity = pcall(placeable.getHusbandryCapacity, placeable, fillTypeIndex)
    if not okCapacity or math.max(0, tonumber(capacity) or 0) <= 0.001 then return false end

    if placeable.getHusbandryIsFillTypeSupported ~= nil then
        local okSupported, supported = pcall(placeable.getHusbandryIsFillTypeSupported, placeable, fillTypeIndex)
        if okSupported and supported ~= true then return false end
    end
    return true
end

function M:getHusbandryBeddingFillType(placeable)
    if placeable == nil then return nil end

    local straw = placeable.spec_husbandryStraw
    local strawFillType = FillType ~= nil and FillType.STRAW or nil
    local woodShavingsFillType = nil
    if g_fillTypeManager ~= nil and g_fillTypeManager.getFillTypeIndexByName ~= nil then
        woodShavingsFillType = g_fillTypeManager:getFillTypeIndexByName("WOODSHAVINGS")
    end

    local filename = tostring(placeable.configFileName or placeable.xmlFilename or ""):lower()
    local isHofBergmannHorseBox = (string.find(filename, "fs25_hofbergmann", 1, true) ~= nil
            or string.find(filename, "horsestableboxes/horsebox", 1, true) ~= nil)
        and string.find(filename, "horse", 1, true) ~= nil
        and (string.find(filename, "box", 1, true) ~= nil or string.find(filename, "stable", 1, true) ~= nil)
    local hasWoodShavings = woodShavingsFillType ~= nil
        and self:isHusbandryBeddingFillTypeConfigured(placeable, woodShavingsFillType)
    if isHofBergmannHorseBox and hasWoodShavings then return woodShavingsFillType end

    local configuredInput = straw ~= nil and straw.inputFillType or nil
    if configuredInput ~= nil and self:isHusbandryBeddingFillTypeConfigured(placeable, configuredInput) then
        return configuredInput
    end

    for key, spec in pairs(placeable) do
        if type(key) == "string" and type(spec) == "table" and string.sub(key, 1, 5) == "spec_" then
            local lowerKey = string.lower(key)
            if string.find(lowerKey, "straw", 1, true) ~= nil
                or string.find(lowerKey, "bedding", 1, true) ~= nil
                or string.find(lowerKey, "litter", 1, true) ~= nil
                or string.find(lowerKey, "shaving", 1, true) ~= nil then
                local candidate = spec.inputFillType or spec.beddingFillType or spec.litterFillType
                    or spec.strawFillType or spec.fillType
                if candidate ~= nil and self:isHusbandryBeddingFillTypeConfigured(placeable, candidate) then
                    return candidate
                end
            end
        end
    end

    local hasStraw = strawFillType ~= nil and self:isHusbandryBeddingFillTypeConfigured(placeable, strawFillType)

    if hasWoodShavings and not hasStraw then return woodShavingsFillType end
    if hasStraw then return strawFillType end
    if hasWoodShavings then return woodShavingsFillType end
    return nil
end

function M:buildStrawEntries(husbandries)
    local entries = {}
    for _, item in ipairs(husbandries or {}) do
        local placeable = item.placeable or item
        if placeable ~= nil and placeable.addHusbandryFillLevelFromTool ~= nil
            and placeable.getHusbandryCapacity ~= nil and placeable.getHusbandryFillLevel ~= nil then
            local fillTypeIndex = self:getHusbandryBeddingFillType(placeable)
            local demand = self:getFillDemand(placeable, fillTypeIndex)
            if demand ~= nil then
                demand.placeable = placeable
                demand.fillType = fillTypeIndex
                demand.label = "Einstreu (" .. self:getFillTypeLabel(fillTypeIndex) .. ")"
                demand.name = self:getPlaceableName(placeable)
                table.insert(entries, demand)
            end
        end
    end
    return entries
end

function M:serviceFreeWater(placeable, farmId, worker)
    local water = placeable and placeable.spec_husbandryWater
    if water == nil or water.fillType == nil or placeable.getHusbandryCapacity == nil
        or placeable.getHusbandryFillLevel == nil or placeable.addHusbandryFillLevelFromTool == nil then
        return false, false
    end

    if water.automaticWaterSupply then
        local supported = false
        if placeable.getHusbandryIsFillTypeSupported ~= nil then
            local ok, value = pcall(placeable.getHusbandryIsFillTypeSupported, placeable, water.fillType)
            if ok then supported = value == true end
        end
        if supported then water.automaticWaterSupply = false end
    end

    if water.automaticWaterSupply then return true, false end

    local capacity = math.max(0, placeable:getHusbandryCapacity(water.fillType) or 0)
    local current = math.max(0, placeable:getHusbandryFillLevel(water.fillType) or 0)
    if capacity <= 0.001 then return false, false end
    if current / capacity >= self.animalServiceThreshold then return true, false end

    local requested = math.max(0, capacity * self.animalServiceTarget - current)
    if requested <= 0.001 then return true, false end
    local added = placeable:addHusbandryFillLevelFromTool(farmId, requested, water.fillType, nil, nil, nil) or 0
    added = math.max(0, math.min(requested, added))
    local name = self:getPlaceableName(placeable)
    if added > 0.001 then
        if self:canAnimalWorkerContinue(worker) then
            self:addWorkHours(worker, self:getServiceWorkHours(worker, "animals", self.animalServiceHours))
        end
        self:setAutoTask(worker, "Tierhaltung · " .. name .. " · Wasser")
        return true, true
    end

    self:notifyProblem(string.format("Tierhaltung: %s – Wasser konnte nicht direkt in die Tränke gefüllt werden.", name))
    return true, false
end

function M:getPlaceableWorldPosition(placeable)
    if placeable == nil or getWorldTranslation == nil then return nil, nil, nil end
    local node = placeable.rootNode
    if node == nil and placeable.components ~= nil and placeable.components[1] ~= nil then
        node = placeable.components[1].node
    end
    if node == nil then return nil, nil, nil end
    local ok, x, y, z = pcall(getWorldTranslation, node)
    if ok then return x, y, z end
    return nil, nil, nil
end

function M:getNearestManureHeaps(sourcePlaceable, farmId, fillTypeIndex)
    local result = {}
    local mission = g_currentMission
    local placeables = mission and mission.placeableSystem and mission.placeableSystem.placeables or nil
    if placeables == nil then return result end
    local sx, sy, sz = self:getPlaceableWorldPosition(sourcePlaceable)

    for _, placeable in pairs(placeables) do
        local spec = placeable and placeable.spec_manureHeap
        local storage = spec ~= nil and spec.manureHeap or nil
        if placeable ~= nil and placeable ~= sourcePlaceable and not placeable.isDeleted
            and storage ~= nil and placeable.spec_husbandry == nil
            and self:hasFarmAccessToObject(farmId, placeable)
            and storage.getFillLevel ~= nil and storage.setFillLevel ~= nil then
            local supported = true
            if storage.getIsFillTypeSupported ~= nil then
                local ok, value = pcall(storage.getIsFillTypeSupported, storage, fillTypeIndex)
                if ok then supported = value == true end
            end
            if supported then
                local free = math.huge
                if storage.getFreeCapacity ~= nil then
                    local ok, value = pcall(storage.getFreeCapacity, storage, fillTypeIndex)
                    if ok and tonumber(value) ~= nil then free = math.max(0, tonumber(value) or 0) end
                end
                if free > 0.001 then
                    local px, py, pz = self:getPlaceableWorldPosition(placeable)
                    local distanceSq = math.huge
                    if sx ~= nil and px ~= nil then
                        local dx, dy, dz = px - sx, (py or 0) - (sy or 0), pz - sz
                        distanceSq = dx*dx + dy*dy + dz*dz
                    end
                    table.insert(result, {placeable=placeable, storage=storage, free=free, distanceSq=distanceSq})
                end
            end
        end
    end

    table.sort(result, function(a,b) return a.distanceSq < b.distanceSq end)
    return result
end

function M:addToManureHeap(candidate, fillTypeIndex, amount)
    if candidate == nil or candidate.storage == nil or amount <= 0.001 then return 0 end
    local storage = candidate.storage
    local oldLevel = math.max(0, storage:getFillLevel(fillTypeIndex) or 0)
    local requested = math.min(amount, candidate.free or amount)
    storage:setFillLevel(oldLevel + requested, fillTypeIndex, nil)
    local newLevel = math.max(0, storage:getFillLevel(fillTypeIndex) or oldLevel)
    local added = math.max(0, math.min(requested, newLevel - oldLevel))
    candidate.free = math.max(0, (candidate.free or 0) - added)
    return added
end

function M:serviceManureTransfer(placeable, farmId, worker)
    if placeable == nil then return false, false end
    local fillTypeIndex = nil
    if placeable.spec_husbandryStraw ~= nil then
        fillTypeIndex = placeable.spec_husbandryStraw.outputFillType
    end
    if fillTypeIndex == nil and FillType ~= nil then fillTypeIndex = FillType.MANURE end
    if fillTypeIndex == nil then return false, false end

    local heaps = self:getNearestManureHeaps(placeable, farmId, fillTypeIndex)
    if #heaps == 0 then return false, false end

    local movedTotal = 0

    if placeable.getHusbandryFillLevel ~= nil and placeable.removeHusbandryFillLevel ~= nil then
        local available = math.max(0, placeable:getHusbandryFillLevel(fillTypeIndex) or 0)
        for _, heap in ipairs(heaps) do
            if available <= 0.001 then break end
            local wanted = math.min(available, heap.free or available)
            if wanted > 0.001 then
                local remaining = placeable:removeHusbandryFillLevel(farmId, wanted, fillTypeIndex) or wanted
                remaining = math.max(0, math.min(wanted, remaining))
                local removed = math.max(0, wanted - remaining)
                if removed > 0.001 then
                    local added = self:addToManureHeap(heap, fillTypeIndex, removed)
                    if removed - added > 0.001 and placeable.addHusbandryFillLevelFromTool ~= nil then
                        placeable:addHusbandryFillLevelFromTool(farmId, removed - added, fillTypeIndex, nil, nil, nil)
                    end
                    movedTotal = movedTotal + added
                    available = math.max(0, available - added)
                end
            end
        end
    end

    local localSpec = placeable.spec_manureHeap
    local localStorage = localSpec ~= nil and localSpec.manureHeap or nil
    if localStorage ~= nil and localStorage.getFillLevel ~= nil and localStorage.setFillLevel ~= nil then
        local available = math.max(0, localStorage:getFillLevel(fillTypeIndex) or 0)
        for _, heap in ipairs(heaps) do
            if available <= 0.001 then break end
            local wanted = math.min(available, heap.free or available)
            if wanted > 0.001 then
                local before = math.max(0, localStorage:getFillLevel(fillTypeIndex) or 0)
                local removed = math.min(before, wanted)
                localStorage:setFillLevel(before - removed, fillTypeIndex, nil)
                local afterRemove = math.max(0, localStorage:getFillLevel(fillTypeIndex) or before)
                removed = math.max(0, before - afterRemove)
                if removed > 0.001 then
                    local added = self:addToManureHeap(heap, fillTypeIndex, removed)
                    if removed - added > 0.001 then
                        local current = math.max(0, localStorage:getFillLevel(fillTypeIndex) or 0)
                        localStorage:setFillLevel(current + (removed - added), fillTypeIndex, nil)
                    end
                    movedTotal = movedTotal + added
                    available = math.max(0, available - added)
                end
            end
        end
    end

    if movedTotal > 0.001 then
        if self:canAnimalWorkerContinue(worker) then
            self:addWorkHours(worker, self:getServiceWorkHours(worker, "animals", self.animalServiceHours))
        end
        self:setAutoTask(worker, "Tierhaltung · " .. self:getPlaceableName(placeable) .. " · Mist")
        return true, true
    end
    return true, false
end

function M:serviceFood(placeable, farmId, worker)
    local spec = placeable.spec_husbandryFood
    if spec == nil or placeable.getTotalFood == nil or placeable.getFoodCapacity == nil or placeable.addFood == nil then return false, false end
    local capacity = placeable:getFoodCapacity() or 0
    local current = placeable:getTotalFood() or 0
    if capacity <= 0 then return false, false end
    local beforeRatio = current / capacity
    if beforeRatio >= self.animalServiceThreshold then return true, false end

    local stallName = self:getPlaceableName(placeable)
    local candidates = self:getFoodFillCandidates(placeable, farmId)
    if #candidates == 0 then
        self:notifyProblem(string.format("Tierhaltung: %s – kein Futter im Hoflager/Silo/Ballen-/Paletten-/BigBag-Lager.", stallName))
        return true, false
    end

    local totalAdded = 0
    for _, candidate in ipairs(candidates) do
        current = placeable:getTotalFood() or current
        local requested = math.max(0, capacity * self.animalServiceTarget - current)
        if requested <= 0.001 then break end
        local removed, reservations = self:takeFromFarmStorage(farmId, candidate.fillType, requested)
        if removed > 0.001 then
            local added = placeable:addFood(farmId, removed, candidate.fillType, nil, nil, nil) or 0
            added = math.max(0, math.min(removed, added))
            if removed - added > 0.001 then self:returnToFarmStorage(candidate.fillType, reservations, removed - added) end
            self:finalizeFarmStorageReservations(reservations)
            if added > 0.001 then
                totalAdded = totalAdded + added
            end
        end
    end

    local after = placeable:getTotalFood() or current
    if totalAdded > 0.001 then
        self:addWorkHours(worker, self:getServiceWorkHours(worker, "animals", self.animalServiceHours))
        self:setAutoTask(worker, "Tierhaltung · " .. stallName .. " · Futter")
        if after / capacity < self.animalServiceTarget - 0.001 then
            self:notifyProblem(string.format("Tierhaltung: %s – Futter im Lager aufgebraucht; Stall konnte nicht vollständig versorgt werden.", stallName))
        end
        return true, true
    end

    self:notifyProblem(string.format("Tierhaltung: %s – vorhandenes Futter konnte nicht übernommen werden.", stallName))
    return true, false
end

function M:serviceHusbandryFill(placeable, farmId, worker, fillTypeIndex, label)
    if fillTypeIndex == nil or placeable.getHusbandryCapacity == nil or placeable.getHusbandryFillLevel == nil
        or placeable.addHusbandryFillLevelFromTool == nil then return false, false end
    local capacity = placeable:getHusbandryCapacity(fillTypeIndex) or 0
    local current = placeable:getHusbandryFillLevel(fillTypeIndex) or 0
    if capacity <= 0 then return false, false end
    if current / capacity >= self.animalServiceThreshold then return true, false end

    local stallName = self:getPlaceableName(placeable)
    local requested = math.max(0, capacity * self.animalServiceTarget - current)
    local available = self:getFarmStorageAmount(farmId, fillTypeIndex)
    if available <= 0.001 then
        self:notifyProblem(string.format("Tierhaltung: %s – kein %s im Hoflager/Silo/Ballen-/Paletten-/BigBag-Lager.", stallName, label))
        return true, false
    end

    local removed, reservations = self:takeFromFarmStorage(farmId, fillTypeIndex, math.min(requested, available))
    if removed <= 0.001 then return true, false end
    local added = placeable:addHusbandryFillLevelFromTool(farmId, removed, fillTypeIndex, nil, nil, nil) or 0
    added = math.max(0, math.min(removed, added))
    if added <= 0.001 then
        self:returnToFarmStorage(fillTypeIndex, reservations, removed)
        self:finalizeFarmStorageReservations(reservations)
        self:notifyProblem(string.format("Tierhaltung: %s – %s konnte nicht aufgefüllt werden; Lagerbestand blieb erhalten.", stallName, label))
        return true, false
    end
    if removed - added > 0.001 then self:returnToFarmStorage(fillTypeIndex, reservations, removed - added) end
    self:finalizeFarmStorageReservations(reservations)

    local after = placeable:getHusbandryFillLevel(fillTypeIndex) or (current + added)
    self:addWorkHours(worker, self:getServiceWorkHours(worker, "animals", self.animalServiceHours))
    self:setAutoTask(worker, "Tierhaltung · " .. stallName .. " · " .. label)
    if after / capacity < self.animalServiceTarget - 0.001 then
        self:notifyProblem(string.format("Tierhaltung: %s – %s im Lager aufgebraucht; Stall konnte nicht vollständig versorgt werden.", stallName, label))
    end
    return true, true
end

function M:getHusbandryStatusText(placeable)
    local parts = {}
    if placeable.spec_husbandryFood ~= nil and placeable.getFoodCapacity ~= nil and placeable.getTotalFood ~= nil then
        local capacity = placeable:getFoodCapacity() or 0
        if capacity > 0 then table.insert(parts, "Futter " .. self:percentText(placeable:getTotalFood() or 0, capacity)) end
    end
    local water = placeable.spec_husbandryWater
    if water ~= nil then
        if water.automaticWaterSupply then
            table.insert(parts, "Wasser automatisch")
        elseif placeable.getHusbandryCapacity ~= nil and placeable.getHusbandryFillLevel ~= nil then
            local capacity = placeable:getHusbandryCapacity(water.fillType) or 0
            if capacity > 0 then table.insert(parts, "Wasser " .. self:percentText(placeable:getHusbandryFillLevel(water.fillType) or 0, capacity)) end
        end
    end
    if placeable.getHusbandryCapacity ~= nil and placeable.getHusbandryFillLevel ~= nil then
        local beddingFillType = self:getHusbandryBeddingFillType(placeable)
        if beddingFillType ~= nil then
            local capacity = placeable:getHusbandryCapacity(beddingFillType) or 0
            if capacity > 0 then
                table.insert(parts, self:getFillTypeLabel(beddingFillType) .. " "
                    .. self:percentText(placeable:getHusbandryFillLevel(beddingFillType) or 0, capacity))
            end
        end
    end
    return table.concat(parts, ", ")
end

function M:serviceAnimals(worker, scheduledHour)
    if worker == nil or not self:canAnimalWorkerContinue(worker) then return false end

    self:notify(string.format("Tierhaltung: Kontrolle um %02d:00 Uhr.", scheduledHour or 0))
    local husbandries, ownedCount = self:getOccupiedHusbandries(worker.farmId)
    if ownedCount <= 0 then
        self:notifyProblem("Tierhaltung: Keine eigenen Tierställe oder Weiden gefunden.")
        return false
    end
    if #husbandries == 0 then
        self:notifyProblem("Tierhaltung: Keine belegten Tierställe oder Weiden gefunden – leere Haltungen werden übersprungen.")
        return true
    end

    self:serviceFoodFair(husbandries, worker.farmId, worker)

    if self:canAnimalWorkerContinue(worker) then
        local petEntries = self:buildPetFeedEntries(husbandries)
        self:serviceStoredFillEntriesFair(petEntries, worker.farmId, worker)
    end

    for _, item in ipairs(husbandries) do
        if not self:canAnimalWorkerContinue(worker) then break end
        self:serviceFreeWater(item.placeable, worker.farmId, worker)
    end

    if self:canAnimalWorkerContinue(worker) then
        local strawEntries = self:buildStrawEntries(husbandries)
        self:serviceStoredFillEntriesFair(strawEntries, worker.farmId, worker)
    end

    for _, item in ipairs(husbandries) do
        if not self:canAnimalWorkerContinue(worker) then break end
        self:serviceManureTransfer(item.placeable, worker.farmId, worker)
    end

    if not self:canAnimalWorkerContinue(worker) then
        self:notifyProblem("Tierhaltung: Kontrolle beendet – Monatskontingent des Tierpflegers erreicht.")
    end
    return true
end

function M:isMachineWorkTime()
    local hour = self:getGameHour()
    if hour == nil then return false end
    return hour >= self.machineWorkStartHour and hour < self.machineWorkEndHour
end

function M:getMachineRepairCandidate(farmId)
    local mission = g_currentMission
    local vehicles = mission and mission.vehicleSystem and mission.vehicleSystem.vehicles or nil
    if vehicles == nil then return nil, nil end
    local best, bestDamage = nil, self.machineRepairThreshold
    for _, vehicle in pairs(vehicles) do
        if vehicle ~= nil and not vehicle.isDeleted and vehicle.getOwnerFarmId ~= nil and vehicle:getOwnerFarmId() == farmId
            and vehicle.getDamageAmount ~= nil and vehicle.getRepairPrice ~= nil and vehicle.repairVehicle ~= nil
            and not self:isVehicleInMaintenance(vehicle) then
            local root = self:getVehicleRoot(vehicle) or vehicle
            local activeAI = (vehicle.getIsAIActive ~= nil and vehicle:getIsAIActive())
                or (root ~= vehicle and root.getIsAIActive ~= nil and root:getIsAIActive())
            local controlled = mission.controlledVehicle == vehicle or mission.controlledVehicle == root
            local moving = (vehicle.getLastSpeed ~= nil and math.abs(vehicle:getLastSpeed() or 0) > 0.5)
                or (root ~= vehicle and root.getLastSpeed ~= nil and math.abs(root:getLastSpeed() or 0) > 0.5)
            local damage = vehicle:getDamageAmount() or 0
            if not activeAI and not controlled and not moving and damage >= bestDamage then
                best, bestDamage = vehicle, damage
            end
        end
    end
    return best, bestDamage
end

function M:notifyMissingMachineWorker(farmId)
    local vehicle = self:getMachineRepairCandidate(farmId)
    if vehicle == nil then return end
    local env = g_currentMission and g_currentMission.environment
    local day = env and env.currentDay or 0
    local key = tostring(day) .. ":" .. tostring(vehicle)
    if self.lastMissingMachineWorkerNotice ~= key then
        self.lastMissingMachineWorkerNotice = key
        local name = vehicle.getName ~= nil and vehicle:getName() or "Fahrzeug"
        self:notifyProblem(string.format("Maschinentechnik: %s benötigt Reparatur – kein verfügbarer Maschinentechniker.", name))
    end
end

function M:serviceMachinery(worker)
    if worker == nil or (not self:isTemporaryEmployee(worker) and worker.hours >= worker.limit) or not self:isMachineWorkTime() then return false end
    local best, bestDamage = self:getMachineRepairCandidate(worker.farmId)
    if best == nil then return false end
    local price = math.max(0, best:getRepairPrice() or 0)
    local farm = g_farmManager:getFarmById(worker.farmId)
    local name = best.getName ~= nil and best:getName() or "Fahrzeug"
    if farm == nil or farm:getBalance() < price then
        local day = g_currentMission.environment and g_currentMission.environment.currentDay or 0
        local key = tostring(day) .. ":" .. tostring(best)
        if self.lastMachineNoMoneyNotice ~= key then
            self.lastMachineNoMoneyNotice = key
            self:notifyProblem(string.format("Maschinentechnik: %s benötigt Reparatur, aber %.0f € Reparaturkosten sind nicht verfügbar.", name, price))
        end
        return false
    end
    return self:startMaintenance(worker, best)
end

function M:getManagedFarmIds()
    local ids, seen = {}, {}
    for _, e in ipairs(self.staff or {}) do
        local farmId = tonumber(e.farmId)
        if farmId ~= nil and farmId > 0 and not seen[farmId] and g_farmManager:getFarmById(farmId) ~= nil then
            seen[farmId] = true
            table.insert(ids, farmId)
        end
    end
    if #ids == 0 and not self.isMultiplayer then
        local farmId = self:farmId()
        if farmId ~= nil and farmId > 0 and g_farmManager:getFarmById(farmId) ~= nil then
            table.insert(ids, farmId)
        end
    end
    table.sort(ids)
    return ids
end

function M:runScheduledAnimalCheck(hour, farmIdOverride)
    local farmId = tonumber(farmIdOverride) or self:farmId()
    local worker = self:findFree(farmId, "animals")
    if worker == nil then
        self:notifyProblem(string.format("Tierhaltung: Kontrolle um %02d:00 Uhr ausgefallen – kein verfügbarer Tierpfleger.", hour))
        return false
    end
    return self:serviceAnimals(worker, hour)
end

function M:updateAnimalSchedule()
    local env = g_currentMission and g_currentMission.environment
    local hour = self:getGameHour()
    if env == nil or env.currentDay == nil or hour == nil then return end
    local day = env.currentDay
    self.lastAnimalCheck08ByFarm = self.lastAnimalCheck08ByFarm or {}
    self.lastAnimalCheck17ByFarm = self.lastAnimalCheck17ByFarm or {}

    for _, farmId in ipairs(self:getManagedFarmIds()) do
        if self:hasEmployeeWithRole(farmId, "animals") then
            local last08 = self.lastAnimalCheck08ByFarm[farmId]
            local last17 = self.lastAnimalCheck17ByFarm[farmId]
            if last08 == nil then
                last08 = (not self.isMultiplayer and farmId == self:farmId()) and (self.lastAnimalCheck08Day or -1) or -1
            end
            if last17 == nil then
                last17 = (not self.isMultiplayer and farmId == self:farmId()) and (self.lastAnimalCheck17Day or -1) or -1
            end

            if hour >= 17 and last17 ~= day then
                self.lastAnimalCheck08ByFarm[farmId] = day
                self.lastAnimalCheck17ByFarm[farmId] = day
                self:runScheduledAnimalCheck(17, farmId)
                self:markNetworkDirty()
            elseif hour >= 8 and last08 ~= day then
                self.lastAnimalCheck08ByFarm[farmId] = day
                self:runScheduledAnimalCheck(8, farmId)
                self:markNetworkDirty()
            end
        end
    end

    if not self.isMultiplayer then
        local farmId = self:farmId()
        self.lastAnimalCheck08Day = self.lastAnimalCheck08ByFarm[farmId] or self.lastAnimalCheck08Day
        self.lastAnimalCheck17Day = self.lastAnimalCheck17ByFarm[farmId] or self.lastAnimalCheck17Day
    end
end

function M:updateAutoServices(dt)
    self:updateAnimalSchedule()
    self:updateMaintenanceTasks()
    self.autoServiceElapsed = (self.autoServiceElapsed or 0) + (dt or 0)
    if self.autoServiceElapsed < self.autoServiceIntervalMs then return end
    self.autoServiceElapsed = 0
    if not self:isMachineWorkTime() then return end

    for _, farmId in ipairs(self:getManagedFarmIds()) do
        if self:hasEmployeeWithRole(farmId, "machinery") then
            local machineWorker = self:findFree(farmId, "machinery")
            if machineWorker ~= nil then
                if self:serviceMachinery(machineWorker) then self:markNetworkDirty() end
            else
                self:notifyMissingMachineWorker(farmId)
            end
        end
    end
end

function M:applyEmployeeJobSpeed(job, employee, vehicle, role)
    if job == nil or employee == nil or vehicle == nil or role == nil then return end
    if role ~= "fieldwork" and role ~= "transport" then return end

    local factor = self:getTrainingSpeedFactor(employee, role)
    job.employeeSpeedFactor = factor
    job.employeeSpeedVehicle = vehicle

    if vehicle.fsEmployeesSpeedJob ~= nil and vehicle.fsEmployeesSpeedJob ~= job then return end
    vehicle.fsEmployeesSpeedJob = job

    if vehicle.getSpeedLimit ~= nil then
        job.employeeOriginalGetSpeedLimit = vehicle.getSpeedLimit
        local originalGetSpeedLimit = vehicle.getSpeedLimit
        vehicle.getSpeedLimit = function(v, onlyIfWorking, ...)
            local limit, check = originalGetSpeedLimit(v, onlyIfWorking, ...)
            if v.fsEmployeesSpeedJob == job and limit ~= nil and limit < math.huge then
                limit = limit * factor
            end
            return limit, check
        end
    end

    if vehicle.getCruiseControlMaxSpeed ~= nil then
        job.employeeOriginalGetCruiseControlMaxSpeed = vehicle.getCruiseControlMaxSpeed
        local originalGetCruiseControlMaxSpeed = vehicle.getCruiseControlMaxSpeed
        vehicle.getCruiseControlMaxSpeed = function(v, ...)
            local speed = originalGetCruiseControlMaxSpeed(v, ...)
            if v.fsEmployeesSpeedJob == job and speed ~= nil and speed < math.huge then
                return speed * factor
            end
            return speed
        end
    end
end

function M:restoreEmployeeJobSpeed(job)
    if job == nil then return end
    local vehicle = job.employeeSpeedVehicle
    if vehicle ~= nil and not vehicle.isDeleted and vehicle.fsEmployeesSpeedJob == job then
        if job.employeeOriginalGetSpeedLimit ~= nil then vehicle.getSpeedLimit = job.employeeOriginalGetSpeedLimit end
        if job.employeeOriginalGetCruiseControlMaxSpeed ~= nil then vehicle.getCruiseControlMaxSpeed = job.employeeOriginalGetCruiseControlMaxSpeed end
        vehicle.fsEmployeesSpeedJob = nil
    end
    job.employeeSpeedVehicle = nil
    job.employeeOriginalGetSpeedLimit = nil
    job.employeeOriginalGetCruiseControlMaxSpeed = nil
end

function M:update(dt)
    if not self.enabled then return end

    self:updateCenterNotice(dt)
    if self.isServer then
        self:processLoadedRetirements()
        self:updateTrainingClock()
        self:updateIllnessClock()
        self:updateAutoServices(dt)
        self:processTemporaryEmployees()

        if self.isMultiplayer then
            self.networkSyncElapsed = (self.networkSyncElapsed or 0) + (dt or 0)
            if self.networkSyncElapsed >= 2000 then
                self.networkSyncElapsed = 0
                if self.broadcastNetworkState ~= nil then
                    self.networkDirty = true
                    self:broadcastNetworkState(false)
                end
            end
        end
    elseif self.isMultiplayer and not self.networkReady then
        self.networkStateRequestElapsed = (self.networkStateRequestElapsed or 0) + (dt or 0)
        if self.networkStateRequestElapsed >= 1500 then
            self.networkStateRequestElapsed = 0
            if self.requestNetworkState ~= nil then self:requestNetworkState() end
        end
    end

    if EmployeesMenu ~= nil then EmployeesMenu:ensurePage() end
end

function M:deleteMap()
    self.aiHelperDisplayNames = {}
    self.pendingSelection = nil
    self.centerNotice = nil
    for _, task in pairs(self.maintenanceTasks or {}) do self:unlockMaintenanceVehicle(task) end
    self.maintenanceTasks = {}
    self.enabled = false
    g_messageCenter:unsubscribeAll(self)
    self.staff = {}
end

AISystem.startJob = Utils.overwrittenFunction(AISystem.startJob, function(system, superFunc, job, farmId)
    if not M.enabled then return superFunc(system, job, farmId) end
    if M.pendingSelection ~= nil then return end
    local requiredRole = M:getJobRole(job)
    local vehicle=job.vehicleParameter and job.vehicleParameter:getVehicle() or nil
    if M:isVehicleInMaintenance(vehicle) then
        local name=vehicle ~= nil and vehicle.getName ~= nil and vehicle:getName() or "Fahrzeug"
        M:notifyProblem(name .. " ist aktuell in Wartung und kann nicht eingesetzt werden.")
        return
    end
    local candidates, options = {}, {}
    for _,e in ipairs(M.staff) do
        M:ensureDevelopment(e)
        if e.farmId==farmId and e.job==nil and not M:isTraining(e) and not M:isSick(e) and not M:isEmployeeInMaintenance(e) and e.hours<e.limit
            and e.role ~= "none" and (requiredRole==nil or e.role==requiredRole) then
            table.insert(candidates,e)
            table.insert(options,string.format("%s | %s | %.1f h frei",e.name,M:getRoleLabel(e.role),e.limit-e.hours))
        end
    end
    if #candidates==0 then
        local roleText = requiredRole and (" für " .. M:getRoleLabel(requiredRole)) or ""
        M:notify("Kein Mitarbeiter" .. roleText .. " verfügbar. Aufgabengebiet, Fortbildungen und Stundenkontingent prüfen.")
        return
    end

    if M.isMultiplayer then
        table.sort(candidates, function(a,b)
            local ah = (a.hours or 0) / math.max(1, a.limit or 1)
            local bh = (b.hours or 0) / math.max(1, b.limit or 1)
            if math.abs(ah-bh) > 0.000001 then return ah < bh end
            return (a.id or 0) < (b.id or 0)
        end)
        local e = candidates[1]
        e.job, job.employee, job.employeeManaged = job, e, true
        local helperName = M:getEmployeeHelperName(e)
        if helperName ~= nil and g_helperManager ~= nil and g_helperManager.getHelperByName ~= nil then
            local helper = g_helperManager:getHelperByName(helperName)
            if helper ~= nil then job.helperIndex = helper.index end
        end
        M:applyEmployeeJobSpeed(job, e, vehicle, requiredRole)
        superFunc(system, job, farmId)
        if M.markNetworkDirty ~= nil then M:markNetworkDirty() end
        if M.broadcastNetworkState ~= nil then M:broadcastNetworkState(true) end
        return
    end

    if OptionDialog==nil then M:notify("Mitarbeiterauswahl konnte nicht geoeffnet werden."); return end
    local mission=g_currentMission
    local request={job=job}
    M.pendingSelection=request
    OptionDialog.show(function(index)
        if M.pendingSelection~=request then return end
        M.pendingSelection=nil
        if not M.enabled or g_currentMission~=mission then return end
        local e=candidates[tonumber(index)]
        if e==nil then return end
        local exists=false
        for _,current in ipairs(M.staff) do if current==e then exists=true; break end end
        if not exists or e.farmId~=farmId or e.job~=nil or M:isTraining(e) or M:isSick(e) or M:isEmployeeInMaintenance(e) or e.hours>=e.limit
            or e.role == "none" or (requiredRole~=nil and e.role~=requiredRole) then
            M:notify("Dieser Mitarbeiter ist inzwischen nicht mehr verfuegbar."); return
        end
        if job.isRunning then return end
        if M:isVehicleInMaintenance(vehicle) then
            M:notifyProblem((vehicle ~= nil and vehicle.getName ~= nil and vehicle:getName() or "Fahrzeug") .. " ist inzwischen in Wartung.")
            return
        end
        if vehicle~=nil and (vehicle.isDeleted or (vehicle.getIsAIActive and vehicle:getIsAIActive())) then return end
        local valid,message=job:validate(farmId)
        if not valid then M:notify(message or "Der Auftrag kann nicht mehr gestartet werden."); return end
        e.job,job.employee,job.employeeManaged=job,e,true
        M:applyEmployeeJobSpeed(job, e, vehicle, requiredRole)
        superFunc(system,job,farmId)
    end,"Mitarbeiter auswählen","Welcher Angestellte soll diese Arbeit übernehmen?",options)
end)

AIJob.start = Utils.overwrittenFunction(AIJob.start, function(job, superFunc, farmId)
    if M.enabled and (M:isTraining(job.employee) or M:isSick(job.employee)) then return end

    if M.enabled and job.employeeManaged and job.employee ~= nil and g_helperManager ~= nil then
        local helperName = M:getEmployeeHelperName(job.employee)
        local helper = helperName ~= nil and g_helperManager:getHelperByName(helperName) or nil
        if helper ~= nil then
            job.helperIndex = helper.index
            job.startedFarmId = farmId
            job.isRunning = true
            if job.isServer then
                job.currentTaskIndex = 0
            end

            M.aiHelperDisplayNames = M.aiHelperDisplayNames or {}
            M.aiHelperDisplayNames[tostring(helper.name)] = job.employee.name
            job.fsEmployeesHelperKey = tostring(helper.name)
            return
        end
    end

    local result = superFunc(job, farmId)

    if M.enabled and job.employeeManaged and job.employee ~= nil and job.helperIndex ~= nil
        and g_helperManager ~= nil and g_helperManager.getHelperByIndex ~= nil then
        local helper = g_helperManager:getHelperByIndex(job.helperIndex)
        if helper ~= nil and helper.name ~= nil then
            M.aiHelperDisplayNames = M.aiHelperDisplayNames or {}
            M.aiHelperDisplayNames[tostring(helper.name)] = job.employee.name
            job.fsEmployeesHelperKey = tostring(helper.name)
        end
    end

    return result
end)

AIJob.updateCost = Utils.overwrittenFunction(AIJob.updateCost, function(job, superFunc, dt)
    if not M.enabled or not job.employeeManaged then return superFunc(job, dt) end
    if job.employee == nil or not job.isRunning then return end
    local e = job.employee
    if M:isTemporaryEmployee(e) then return end
    local scale = g_currentMission:getEffectiveTimeScale()
    e.hours = math.min(e.limit, e.hours + math.max(0, dt * scale) / 3600000)
    if e.hours >= e.limit then
        g_currentMission.aiSystem:stopJob(job, AIMessageSuccessFinishedJob.new())
        M:notifyProblem(e.name .. ": Monatskontingent erreicht.")
    end
end)

AISystem.stopJobInternal = Utils.overwrittenFunction(AISystem.stopJobInternal, function(system, superFunc, job, message)
    M:restoreEmployeeJobSpeed(job)

    if job ~= nil and job.fsEmployeesHelperKey ~= nil and M.aiHelperDisplayNames ~= nil then
        M.aiHelperDisplayNames[job.fsEmployeesHelperKey] = nil
        job.fsEmployeesHelperKey = nil
    end

    local result = superFunc(system, job, message)
    if job.employee ~= nil then
        if job.employee.job == job then job.employee.job = nil end
        job.employee = nil
        if M.markNetworkDirty ~= nil then M:markNetworkDirty() end
    end
    return result
end)

for _, name in ipairs({"getTitle", "getHelperName"}) do
    AIJob[name] = Utils.overwrittenFunction(AIJob[name], function(job, superFunc, ...)
        if M.enabled and job.employee ~= nil then return job.employee.name end
        return superFunc(job, ...)
    end)
end

if Vehicle ~= nil and Vehicle.showInfo ~= nil then
    Vehicle.showInfo = Utils.appendedFunction(Vehicle.showInfo, function(vehicle, box)
        if not M.enabled or vehicle == nil or box == nil or box.addLine == nil then return end
        local remainingText = M:getMaintenanceRemainingText(vehicle)
        if remainingText ~= nil then
            box:addLine("Reparatur", remainingText)
        end
    end)
end

if FSBaseMission ~= nil and FSBaseMission.addIngameNotification ~= nil then
    FSBaseMission.addIngameNotification = Utils.overwrittenFunction(FSBaseMission.addIngameNotification, function(mission, superFunc, notificationType, text, ...)
        if M.enabled and type(text) == "string" and M.aiHelperDisplayNames ~= nil then
            for helperKey, employeeName in pairs(M.aiHelperDisplayNames) do
                if helperKey ~= nil and employeeName ~= nil then
                    local escapedKey = tostring(helperKey):gsub("([^%w])", "%%%1")
                    local pattern = "(KI%-Helfer%s+)" .. escapedKey .. "(%s+)"
                    local replaced, count = text:gsub(pattern, "%1" .. tostring(employeeName) .. "%2", 1)
                    if count > 0 then
                        text = replaced
                        break
                    end
                end
            end
        end
        return superFunc(mission, notificationType, text, ...)
    end)
end

FSBaseMission.saveSavegame = Utils.appendedFunction(FSBaseMission.saveSavegame, function(mission)
    if mission:getIsServer() then M:save(mission.missionInfo.savegameDirectory) end
end)
addModEventListener(M)
