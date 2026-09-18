-- ============================================================
-- FS25_EmployeesNetwork.lua
-- by Marcus (Cobra Modding)
--
-- Version 1.0.0.0
--
-- Multiplayer state/action synchronization for FS25_Employees
-- ============================================================

EmployeesNetwork = EmployeesNetwork or {}
local N = EmployeesNetwork
local M = Employees

local function splitString(value, separator)
    local result = {}
    value = tostring(value or "")
    local startPos = 1
    while true do
        local pos = string.find(value, separator, startPos, true)
        if pos == nil then
            table.insert(result, string.sub(value, startPos))
            break
        end
        table.insert(result, string.sub(value, startPos, pos - 1))
        startPos = pos + #separator
    end
    return result
end

local function escapeField(value)
    local text = tostring(value == nil and "" or value)
    text = text:gsub("%%", "%%25")
    text = text:gsub("\r", "%%0D")
    text = text:gsub("\n", "%%0A")
    text = text:gsub("\t", "%%09")
    return text
end

local function unescapeField(value)
    local text = tostring(value or "")
    text = text:gsub("%%0D", "\r")
    text = text:gsub("%%0A", "\n")
    text = text:gsub("%%09", "\t")
    text = text:gsub("%%25", "%%")
    return text
end

local function numberField(value, fallback)
    local n = tonumber(value)
    if n == nil then return fallback end
    return n
end

local function boolField(value)
    return value == true and "1" or "0"
end

local function formatNumber(value)
    if value == nil then return "" end
    return string.format("%.6f", tonumber(value) or 0)
end

local function makeRecord(values)
    local escaped = {}
    for i, value in ipairs(values) do
        escaped[i] = escapeField(value)
    end
    return table.concat(escaped, "\t")
end

function M:isEmployeeInJob(e)
    if e == nil then return false end
    if e.job ~= nil then return true end
    return not self.isServer and (tonumber(e.networkJobId) or -1) >= 0
end

function M:serializeNetworkState()
    local records = {}
    table.insert(records, makeRecord({
        "H",
        self.modVersion or "1.0.0.0",
        self.month or 0,
        self.nextId or 1,
        self.lastPeriodDay or -1,
        self.lastAnimalCheck08Day or -1,
        self.lastAnimalCheck17Day or -1
    }))

    for i, c in ipairs(self.contracts or {}) do
        table.insert(records, makeRecord({"C", i, formatNumber(c.salary), formatNumber(c.hours)}))
    end

    for _, e in ipairs(self.staff or {}) do
        self:ensureDevelopment(e)
        local jobId = -1
        if e.job ~= nil and e.job.jobId ~= nil then
            jobId = tonumber(e.job.jobId) or -1
        end
        table.insert(records, makeRecord({
            "E",
            e.id or 0,
            e.rosterId or 0,
            e.name or "",
            e.farmId or 0,
            e.contract or 1,
            formatNumber(e.salary),
            formatNumber(e.limit),
            formatNumber(e.hours),
            e.hired or 0,
            e.leave or -1,
            e.age or 18,
            e.ageMonths or 0,
            e.role or "none",
            (e.training and e.training.fieldwork) or 0,
            (e.training and e.training.transport) or 0,
            (e.training and e.training.animals) or 0,
            (e.training and e.training.machinery) or 0,
            e.activeTraining or "",
            e.trainingTarget or 0,
            formatNumber(e.trainingRemaining),
            e.illnessKey or "",
            formatNumber(e.illnessRemaining),
            formatNumber(e.temporaryStartClock),
            formatNumber(e.temporaryEndClock),
            boolField(e.retirementWarningSent),
            jobId
        }))
    end

    for _, task in pairs(self.maintenanceTasks or {}) do
        if task.vehicleId ~= nil and task.employeeId ~= nil then
            table.insert(records, makeRecord({
                "M",
                task.vehicleId,
                task.rootVehicleId or "",
                task.employeeId,
                formatNumber(task.endClock),
                task.vehicleName or "Fahrzeug"
            }))
        end
    end

    return table.concat(records, "\n")
end

function M:syncClientJobLinks()
    if self.isServer or g_currentMission == nil or g_currentMission.aiSystem == nil then return end

    self.aiHelperDisplayNames = {}
    for _, job in ipairs(g_currentMission.aiSystem.activeJobs or {}) do
        if job.fsEmployeesNetworkManaged then
            if job.employee ~= nil and job.employee.job == job then
                job.employee.job = nil
            end
            job.employee = nil
            job.employeeManaged = nil
            job.fsEmployeesNetworkManaged = nil
        end
    end

    for _, e in ipairs(self.staff or {}) do
        e.job = nil
        local jobId = tonumber(e.networkJobId)
        if jobId ~= nil and jobId >= 0 and g_currentMission.aiSystem.getJobById ~= nil then
            local job = g_currentMission.aiSystem:getJobById(jobId)
            if job ~= nil then
                e.job = job
                job.employee = e
                job.employeeManaged = true
                job.fsEmployeesNetworkManaged = true
                if job.helperIndex ~= nil and g_helperManager ~= nil and g_helperManager.getHelperByIndex ~= nil then
                    local helper = g_helperManager:getHelperByIndex(job.helperIndex)
                    if helper ~= nil and helper.name ~= nil then
                        self.aiHelperDisplayNames[tostring(helper.name)] = e.name
                        job.fsEmployeesHelperKey = tostring(helper.name)
                    end
                end
            end
        end
    end
end

function M:applyNetworkMaintenance(newTasks)
    local oldTasks = self.maintenanceTasks or {}

    for key, oldTask in pairs(oldTasks) do
        if newTasks[key] == nil then
            self:unlockMaintenanceVehicle(oldTask)
        end
    end

    local merged = {}
    for key, incoming in pairs(newTasks) do
        local task = oldTasks[key]
        if task ~= nil then
            task.rootVehicleId = incoming.rootVehicleId
            task.employeeId = incoming.employeeId
            task.endClock = incoming.endClock
            task.vehicleName = incoming.vehicleName
        else
            task = incoming
        end
        merged[key] = task
        if not task.locked then
            local vehicle = self:getVehicleByUniqueId(task.vehicleId)
            if vehicle ~= nil and not vehicle.isDeleted then
                self:lockMaintenanceVehicle(task, vehicle)
            end
        end
    end
    self.maintenanceTasks = merged
end

function M:applyNetworkState(payload)
    if self.isServer or type(payload) ~= "string" or payload == "" then return end

    local existing = {}
    for _, e in ipairs(self.staff or {}) do
        if e.id ~= nil then existing[e.id] = e end
    end

    local parsedStaff = {}
    local parsedMaintenance = {}
    local headerSeen = false

    for _, line in ipairs(splitString(payload, "\n")) do
        if line ~= "" then
            local raw = splitString(line, "\t")
            local fields = {}
            for i, value in ipairs(raw) do fields[i] = unescapeField(value) end
            local kind = fields[1]

            if kind == "H" then
                headerSeen = true
                self.month = math.floor(numberField(fields[3], self.month or 0))
                self.nextId = math.floor(numberField(fields[4], self.nextId or 1))
                self.lastPeriodDay = math.floor(numberField(fields[5], self.lastPeriodDay or -1))
                self.lastAnimalCheck08Day = math.floor(numberField(fields[6], self.lastAnimalCheck08Day or -1))
                self.lastAnimalCheck17Day = math.floor(numberField(fields[7], self.lastAnimalCheck17Day or -1))
            elseif kind == "C" then
                local index = math.floor(numberField(fields[2], 0))
                local c = self.contracts and self.contracts[index] or nil
                if c ~= nil then
                    c.salary = math.max(0, numberField(fields[3], c.salary))
                    c.hours = math.max(1, numberField(fields[4], c.hours))
                end
            elseif kind == "E" then
                local id = math.floor(numberField(fields[2], 0))
                if id > 0 then
                    local e = existing[id] or {id=id, training={}}
                    e.id = id
                    e.rosterId = math.floor(numberField(fields[3], e.rosterId or 0))
                    e.name = fields[4] ~= "" and fields[4] or e.name or ("Mitarbeiter " .. tostring(id))
                    e.farmId = math.floor(numberField(fields[5], e.farmId or 0))
                    e.contract = math.floor(numberField(fields[6], e.contract or 1))
                    e.salary = math.max(0, numberField(fields[7], e.salary or 0))
                    e.limit = math.max(1, numberField(fields[8], e.limit or 1))
                    e.hours = math.max(0, numberField(fields[9], e.hours or 0))
                    e.hired = math.floor(numberField(fields[10], e.hired or 0))
                    e.leave = math.floor(numberField(fields[11], e.leave or -1))
                    e.age = math.max(17, math.floor(numberField(fields[12], e.age or 18)))
                    e.ageMonths = math.max(0, math.min(11, math.floor(numberField(fields[13], e.ageMonths or 0))))
                    e.role = fields[14] ~= "" and fields[14] or "none"
                    e.training = e.training or {}
                    e.training.fieldwork = math.floor(numberField(fields[15], 0))
                    e.training.transport = math.floor(numberField(fields[16], 0))
                    e.training.animals = math.floor(numberField(fields[17], 0))
                    e.training.machinery = math.floor(numberField(fields[18], 0))
                    e.activeTraining = fields[19] ~= "" and fields[19] or nil
                    e.trainingTarget = numberField(fields[20], 0)
                    if e.trainingTarget <= 0 then e.trainingTarget = nil end
                    e.trainingRemaining = numberField(fields[21], nil)
                    if e.activeTraining == nil then e.trainingRemaining = nil end
                    e.illnessKey = fields[22] ~= "" and fields[22] or nil
                    e.illnessRemaining = numberField(fields[23], nil)
                    if e.illnessKey == nil then e.illnessRemaining = nil end
                    e.temporaryStartClock = numberField(fields[24], nil)
                    e.temporaryEndClock = numberField(fields[25], nil)
                    e.retirementWarningSent = fields[26] == "1"
                    e.networkJobId = math.floor(numberField(fields[27], -1))
                    self:ensureDevelopment(e)
                    table.insert(parsedStaff, e)
                end
            elseif kind == "M" then
                local vehicleId = fields[2]
                if vehicleId ~= nil and vehicleId ~= "" then
                    parsedMaintenance[vehicleId] = {
                        vehicleId = vehicleId,
                        rootVehicleId = fields[3] ~= "" and fields[3] or nil,
                        employeeId = math.floor(numberField(fields[4], 0)),
                        endClock = numberField(fields[5], nil),
                        vehicleName = fields[6] ~= "" and fields[6] or "Fahrzeug"
                    }
                end
            end
        end
    end

    if not headerSeen then return end
    self.staff = parsedStaff
    self.legacyStaff = {}
    self.networkReady = true
    self.networkStateRequestElapsed = 0
    self:applyNetworkMaintenance(parsedMaintenance)
    self:syncClientJobLinks()
end

function M:getConnectionFarmId(connection)
    if connection == nil or g_currentMission == nil then return nil end
    local player = nil
    if g_currentMission.getPlayerByConnection ~= nil then
        player = g_currentMission:getPlayerByConnection(connection)
    end
    if player == nil and g_currentMission.userManager ~= nil and g_currentMission.playerSystem ~= nil then
        local userId = g_currentMission.userManager:getUserIdByConnection(connection)
        if userId ~= nil then player = g_currentMission.playerSystem:getPlayerByUserId(userId) end
    end
    return player ~= nil and player.farmId or nil
end

function M:sendNetworkMessage(connection, text, isProblem)
    if connection ~= nil and EmployeesMessageEvent ~= nil then
        connection:sendEvent(EmployeesMessageEvent.new(text or "", isProblem == true))
    elseif text ~= nil and text ~= "" then
        if isProblem then self:notifyProblem(text) else self:notify(text) end
    end
end

function M:sendNetworkState(connection)
    if not self.isServer or EmployeesStateEvent == nil then return end
    local event = EmployeesStateEvent.new(self:serializeNetworkState())
    if connection ~= nil then
        connection:sendEvent(event)
    elseif g_server ~= nil then
        g_server:broadcastEvent(event, true)
    end
end

function M:broadcastNetworkState(force)
    if not self.isServer or not self.isMultiplayer or g_server == nil then return end
    if force or self.networkDirty then
        self.networkDirty = false
        self:sendNetworkState(nil)
    end
end

function M:markNetworkDirty()
    if self.isServer and self.isMultiplayer then self.networkDirty = true end
end

function M:requestNetworkState()
    if self.isServer or not self.isMultiplayer or g_client == nil or EmployeesRequestStateEvent == nil then return end
    local connection = g_client:getServerConnection()
    if connection ~= nil then
        connection:sendEvent(EmployeesRequestStateEvent.new())
    end
end

function M:sendActionRequest(action, employeeId, value)
    if self.isServer or not self.isMultiplayer or g_client == nil or EmployeesActionEvent == nil then return false end
    local connection = g_client:getServerConnection()
    if connection == nil then return false end
    connection:sendEvent(EmployeesActionEvent.new(action, employeeId or 0, value or ""))
    return true
end

function M:handleNetworkAction(connection, action, employeeId, value)
    if not self.isServer then return end
    local farmId = self:getConnectionFarmId(connection)
    if farmId == nil or farmId == FarmManager.SPECTATOR_FARM_ID or g_farmManager:getFarmById(farmId) == nil then
        self:sendNetworkMessage(connection, "Mitarbeiterverwaltung: Keine gültige Farmzuordnung.", true)
        return
    end

    local ok, message = false, "Aktion konnte nicht ausgeführt werden."
    if action == "hire" then
        local contractIndex = math.floor(numberField(value, 0))
        local e = self:hire(contractIndex, farmId)
        ok = e ~= nil
        if ok then
            message = e.name .. (self:isTemporaryEmployee(e) and " als Leiharbeiter angefordert." or " eingestellt.")
        else
            message = "Mitarbeiter konnte nicht eingestellt werden."
        end
    else
        local e = self:getEmployeeById(employeeId)
        if e == nil or e.farmId ~= farmId then
            self:sendNetworkMessage(connection, "Mitarbeiter gehört nicht zu deiner Farm oder existiert nicht mehr.", true)
            return
        end

        if action == "role" then
            ok = self:setRole(e, value)
            message = ok and (e.name .. ": Aufgabengebiet " .. self:getRoleLabel(value) .. " zugewiesen.")
                or "Aufgabengebiet kann aktuell nicht geändert werden."
        elseif action == "train" then
            ok = self:train(e, value)
            message = ok and (e.name .. ": Weiterbildung gestartet.") or "Weiterbildung konnte nicht gestartet werden."
        elseif action == "notice" then
            if not self:isTemporaryEmployee(e) then
                self:giveNotice(e)
                ok = true
                message = e.name .. ": Kündigung vorgemerkt."
            else
                message = "Leiharbeiter enden automatisch und können nicht gekündigt werden."
            end
        elseif action == "cancelNotice" then
            if not self:isTemporaryEmployee(e) and e.leave >= 0 then
                e.leave = -1
                ok = true
                message = e.name .. ": Kündigung zurückgenommen."
            else
                message = "Es gibt keine Kündigung zum Zurücknehmen."
            end
        end
    end

    if ok then
        self:markNetworkDirty()
        self:broadcastNetworkState(true)
    end
    self:sendNetworkMessage(connection, message, not ok)
end

function M:requestHire(contractIndex)
    if self.isServer then
        local e = self:hire(contractIndex, self:farmId())
        if e ~= nil then self:markNetworkDirty(); self:broadcastNetworkState(true) end
        return e
    end
    self:sendActionRequest("hire", 0, tostring(contractIndex))
    return nil
end

function M:requestSetRole(employeeId, role)
    if self.isServer then
        local e = self:getEmployeeById(employeeId)
        if e ~= nil and e.farmId == self:farmId() and self:setRole(e, role) then
            self:notify(e.name .. ": Aufgabengebiet " .. self:getRoleLabel(role) .. " zugewiesen.")
            self:markNetworkDirty(); self:broadcastNetworkState(true)
            return true
        end
        return false
    end
    return self:sendActionRequest("role", employeeId, role)
end

function M:requestTraining(employeeId, key)
    if self.isServer then
        local e = self:getEmployeeById(employeeId)
        local ok = e ~= nil and e.farmId == self:farmId() and self:train(e, key)
        if ok then self:markNetworkDirty(); self:broadcastNetworkState(true) end
        return ok
    end
    return self:sendActionRequest("train", employeeId, key)
end

function M:requestNotice(employeeId, cancel)
    if self.isServer then
        local e = self:getEmployeeById(employeeId)
        if e == nil or e.farmId ~= self:farmId() or self:isTemporaryEmployee(e) then return false end
        if cancel then
            if e.leave < 0 then return false end
            e.leave = -1
            self:notify(e.name .. ": Kündigung zurückgenommen.")
        else
            if e.leave >= 0 then return false end
            self:giveNotice(e)
            self:notify(e.name .. ": Kündigung vorgemerkt.")
        end
        self:markNetworkDirty(); self:broadcastNetworkState(true)
        return true
    end
    return self:sendActionRequest(cancel and "cancelNotice" or "notice", employeeId, "")
end

EmployeesStateEvent = {}
local EmployeesStateEvent_mt = Class(EmployeesStateEvent, Event)
InitEventClass(EmployeesStateEvent, "EmployeesStateEvent")

function EmployeesStateEvent.emptyNew()
    return Event.new(EmployeesStateEvent_mt)
end

function EmployeesStateEvent.new(payload)
    local self = EmployeesStateEvent.emptyNew()
    self.payload = payload or ""
    return self
end

function EmployeesStateEvent:readStream(streamId, connection)
    self.payload = streamReadString(streamId)
    self:run(connection)
end

function EmployeesStateEvent:writeStream(streamId, connection)
    streamWriteString(streamId, self.payload or "")
end

function EmployeesStateEvent:run(connection)
    if connection:getIsServer() then
        M:applyNetworkState(self.payload)
    end
end

EmployeesRequestStateEvent = {}
local EmployeesRequestStateEvent_mt = Class(EmployeesRequestStateEvent, Event)
InitEventClass(EmployeesRequestStateEvent, "EmployeesRequestStateEvent")

function EmployeesRequestStateEvent.emptyNew()
    return Event.new(EmployeesRequestStateEvent_mt)
end

function EmployeesRequestStateEvent.new()
    return EmployeesRequestStateEvent.emptyNew()
end

function EmployeesRequestStateEvent:readStream(streamId, connection)
    self:run(connection)
end

function EmployeesRequestStateEvent:writeStream(streamId, connection)
end

function EmployeesRequestStateEvent:run(connection)
    if not connection:getIsServer() then
        M:sendNetworkState(connection)
    end
end

EmployeesActionEvent = {}
local EmployeesActionEvent_mt = Class(EmployeesActionEvent, Event)
InitEventClass(EmployeesActionEvent, "EmployeesActionEvent")

function EmployeesActionEvent.emptyNew()
    return Event.new(EmployeesActionEvent_mt)
end

function EmployeesActionEvent.new(action, employeeId, value)
    local self = EmployeesActionEvent.emptyNew()
    self.action = action or ""
    self.employeeId = tonumber(employeeId) or 0
    self.value = value or ""
    return self
end

function EmployeesActionEvent:readStream(streamId, connection)
    self.action = streamReadString(streamId)
    self.employeeId = tonumber(streamReadString(streamId)) or 0
    self.value = streamReadString(streamId)
    self:run(connection)
end

function EmployeesActionEvent:writeStream(streamId, connection)
    streamWriteString(streamId, self.action or "")
    streamWriteString(streamId, tostring(self.employeeId or 0))
    streamWriteString(streamId, self.value or "")
end

function EmployeesActionEvent:run(connection)
    if not connection:getIsServer() then
        M:handleNetworkAction(connection, self.action, self.employeeId, self.value)
    end
end

EmployeesMessageEvent = {}
local EmployeesMessageEvent_mt = Class(EmployeesMessageEvent, Event)
InitEventClass(EmployeesMessageEvent, "EmployeesMessageEvent")

function EmployeesMessageEvent.emptyNew()
    return Event.new(EmployeesMessageEvent_mt)
end

function EmployeesMessageEvent.new(message, isProblem)
    local self = EmployeesMessageEvent.emptyNew()
    self.message = message or ""
    self.isProblem = isProblem == true
    return self
end

function EmployeesMessageEvent:readStream(streamId, connection)
    self.message = streamReadString(streamId)
    self.isProblem = streamReadBool(streamId)
    self:run(connection)
end

function EmployeesMessageEvent:writeStream(streamId, connection)
    streamWriteString(streamId, self.message or "")
    streamWriteBool(streamId, self.isProblem == true)
end

function EmployeesMessageEvent:run(connection)
    if connection:getIsServer() and self.message ~= "" then
        if self.isProblem then M:notifyProblem(self.message) else M:notify(self.message) end
    end
end
