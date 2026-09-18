-- ============================================================
-- FS25_EmployeesMenu.lua
-- by Marcus (Cobra Modding)
-- 
--
-- Version 1.0.0.0
--
--
-- Keine Änderung am Skript ohne meine Erlaubnis
-- ============================================================

if TabbedMenuFrameElement == nil or Class == nil then
    EmployeesMenu = {ensurePage=function() end}
    return
end

EmployeesFrame = {}
local EmployeesFrame_mt = Class(EmployeesFrame, TabbedMenuFrameElement)
local PAGE_SIZE = 8
local TAB_NAMES = {"Geringfügig", "Teilzeit", "Vollzeit", "Leiharbeiter"}
local DISPLAY_CONTRACT_ORDER = {4, 1, 2, 3}
local GREEN = {0.62, 0.86, 0.0, 1}
local DARK = {0.16, 0.16, 0.16, 1}
local DISABLED = {0.09, 0.09, 0.09, 1}
local PANEL = {0.018, 0.019, 0.017, 1}
local SLIDER_TRACK = {0.032, 0.032, 0.032, 1}
local SLIDER_HANDLE = {0.34, 0.38, 0.31, 1}
local ROW_NORMAL = {0.035, 0.040, 0.037, 1}
local ROW_HOVER = {0.075, 0.085, 0.074, 1}
local ROW_SELECTED = {0.62, 0.86, 0.0, 1}
local ROW_PRESSED = {0.48, 0.68, 0.0, 1}
local STATUS_BUSY = {0.95, 0.58, 0.05, 1}
local STATUS_IDLE = {0.62, 0.86, 0.0, 1}
local STATUS_NEUTRAL = {0.45, 0.48, 0.45, 1}

function EmployeesFrame.new()
    local self = TabbedMenuFrameElement.new(nil, EmployeesFrame_mt)
    self.name = "EmployeesFrame"
    self.offset, self.contractTab = 0, DISPLAY_CONTRACT_ORDER[1]
    return self
end

function EmployeesFrame:setPortrait(element, employee)
    element:setVisible(employee~=nil)
    if employee==nil then return end
    local index=employee.rosterId or ((employee.id-1)%Employees.maxEmployees+1)
    if element.employeePortraitIndex~=index then
        element:setImageFilename(Employees.directory .. string.format("gui/person%02d.dds",index))
        element:setImageUVs(nil,0,0,0,1,1,0,1,1)
        element.employeePortraitIndex=index
    end
end

function EmployeesFrame:getButtonBackground(button)
    if button == nil then return nil end
    return button:getDescendantByName("background")
end

function EmployeesFrame:setBackgroundColor(background, color)
    if background == nil or color == nil then return end
    background:setVisible(true)
    background:setImageColor(nil, color[1], color[2], color[3], color[4])
end

function EmployeesFrame:setTexture(element, filename)
    element:setImageFilename(Employees.directory .. "gui/" .. filename .. ".dds")
    element:setImageUVs(nil,0,0,0,1,1,0,1,1)
    element:setImageColor(nil,1,1,1,1)
end

function EmployeesFrame:setButtonColors(button,color,enabled)
    GuiOverlay.setColor(button.overlay,color[1],color[2],color[3],color[4])
    button.overlay.colorFocused={color[1],color[2],color[3],color[4]}
    button.overlay.colorSelected=button.overlay.colorFocused
    button.overlay.colorHighlighted={math.min(1,color[1]*1.08),math.min(1,color[2]*1.08),color[3],color[4]}
    button.overlay.colorPressed={color[1]*0.85,color[2]*0.85,color[3]*0.85,color[4]}
    button.overlay.colorDisabled={DISABLED[1],DISABLED[2],DISABLED[3],DISABLED[4]}
end

function EmployeesFrame:configureEmployeeRowButton(button)
    if button == nil then return end
    button:setImageFilename(Employees.directory .. "gui/action.dds")
    button:setImageUVs({0,0,0,1,1,0,1,1})
    button.hotspot=nil
    GuiOverlay.setColor(button.overlay,ROW_NORMAL[1],ROW_NORMAL[2],ROW_NORMAL[3],ROW_NORMAL[4])
    button.overlay.colorFocused={ROW_HOVER[1],ROW_HOVER[2],ROW_HOVER[3],ROW_HOVER[4]}
    button.overlay.colorHighlighted={ROW_HOVER[1],ROW_HOVER[2],ROW_HOVER[3],ROW_HOVER[4]}
    button.overlay.colorSelected={ROW_SELECTED[1],ROW_SELECTED[2],ROW_SELECTED[3],ROW_SELECTED[4]}
    button.overlay.colorPressed={ROW_PRESSED[1],ROW_PRESSED[2],ROW_PRESSED[3],ROW_PRESSED[4]}
    button.overlay.colorDisabled={DISABLED[1],DISABLED[2],DISABLED[3],DISABLED[4]}
end

function EmployeesFrame:getEmployeeStatusColor(employee)
    if employee==nil then return STATUS_NEUTRAL end
    if Employees:isTraining(employee) or Employees:isEmployeeInMaintenance(employee) or Employees:isEmployeeInJob(employee) then
        return STATUS_BUSY
    end
    if employee.role=="none" then return STATUS_NEUTRAL end
    return STATUS_IDLE
end

function EmployeesFrame:configureAlwaysFilledButton(button, color, filename)
    if button == nil then return end
    button:setImageFilename(Employees.directory .. "gui/" .. (filename or "action") .. ".dds")
    button:setImageUVs({0,0,0,1,1,0,1,1})
    self:setButtonColors(button,color,true)
end

function EmployeesFrame:setActionButtonState(button, enabled, color)
    if button == nil then return end
    button:setDisabled(not enabled)
    local c=enabled and (color or GREEN) or DISABLED
    self:setButtonColors(button,c,enabled)
    if enabled then button:setTextColor(0.035,0.045,0.015,1)
    else button:setTextColor(0.46,0.46,0.46,1) end
end

function EmployeesFrame:updateTabVisuals()
    for i,dot in ipairs(self.categoryDots or {}) do
        self:setBackgroundColor(dot, self.contractTab==DISPLAY_CONTRACT_ORDER[i] and GREEN or DARK)
    end
    for i,tab in ipairs(self.subCategoryTabs or {}) do
        local active=self.contractTab==DISPLAY_CONTRACT_ORDER[i]
        local bg=self:getButtonBackground(tab)
        if bg then
            bg:setVisible(active)
            if active then self:setBackgroundColor(bg,GREEN) end
        end
        if active then
            tab:setTextColor(0.035,0.045,0.015,1)
        else
            tab:setTextColor(0.92,0.92,0.88,1)
        end
    end
end

function EmployeesFrame:initialize()
    EmployeesFrame:superClass().initialize(self)
    self:setMenuButtonInfo({{inputAction=InputAction.MENU_BACK}})

    for i,tab in ipairs(self.subCategoryTabs or {}) do
        local index=DISPLAY_CONTRACT_ORDER[i]
        local selected=function() return self.contractTab==index end
        tab.getIsSelected=selected
        local bg=self:getButtonBackground(tab)
        if bg then bg.getIsSelected=selected end
    end

    if self.sidePanel then
        self.sidePanel:setImageFilename(Employees.directory .. "gui/pixel.dds")
        self.sidePanel:setImageColor(nil,PANEL[1],PANEL[2],PANEL[3],PANEL[4])
    end
    if self.profilePanelBg then
        self.profilePanelBg:setImageFilename(Employees.directory .. "gui/pixel.dds")
        self.profilePanelBg:setImageColor(nil,0.014,0.017,0.015,0.97)
    end
    self:setTexture(self.trainingPanelBg,"trainingPanel")
    self:setTexture(self.noticePanelBg,"noticePanel")
    self:setTexture(self.hirePanelBg,"pixel")
    self:setBackgroundColor(self.hirePanelBg,PANEL)
    for i,card in ipairs(self.trainingCards) do
        self:setTexture(card,"courseCard")
        self:setTexture(self.trainingIcons[i],Employees.trainingTypes[i].key)
    end
    self:configureAlwaysFilledButton(self.previousTabButton,{1,1,1,1},"arrowLeft")
    self:configureAlwaysFilledButton(self.nextTabButton,{1,1,1,1},"arrowRight")
    self:setTexture(self.panelTab,"panelTab")
    for _,dot in ipairs(self.categoryDots) do self:setTexture(dot,"circle") end
    if self.overviewPanelBg then
        self.overviewPanelBg:setImageFilename(Employees.directory .. "gui/pixel.dds")
        self.overviewPanelBg:setImageColor(nil,PANEL[1],PANEL[2],PANEL[3],PANEL[4])
    end
    for _,bg in ipairs(self.overviewContractCards or {}) do
        bg:setImageFilename(Employees.directory .. "gui/pixel.dds")
        bg:setImageColor(nil,0.035,0.037,0.034,1)
    end
    for i,bg in ipairs(self.overviewRowBackgrounds or {}) do
        bg:setImageFilename(Employees.directory .. "gui/pixel.dds")
        local shade=i%2==1 and 0.045 or 0.025
        bg:setImageColor(nil,shade,shade,shade,1)
    end
    for _,button in ipairs(self.trainingButtons) do self:configureAlwaysFilledButton(button,GREEN) end
    if self.pageSlider then
        local sliderTexture = Employees.directory .. "gui/pixel.dds"
        self.pageSlider.overlay = GuiOverlay.createOverlay(self.pageSlider.overlay, sliderTexture)
        self.pageSlider.sliderOverlay = GuiOverlay.createOverlay(self.pageSlider.sliderOverlay, sliderTexture)
        GuiOverlay.setColor(self.pageSlider.overlay, SLIDER_TRACK[1], SLIDER_TRACK[2], SLIDER_TRACK[3], SLIDER_TRACK[4])
        GuiOverlay.setColor(self.pageSlider.sliderOverlay, SLIDER_HANDLE[1], SLIDER_HANDLE[2], SLIDER_HANDLE[3], SLIDER_HANDLE[4])
    end
    for i,button in ipairs(self.employeeRows or {}) do
        self:configureEmployeeRowButton(button)
        local rowButton=button
        rowButton.getIsSelected=function()
            return rowButton.employeeId~=nil and rowButton.employeeId==self.selectedId
        end
    end
    for _,bg in ipairs(self.rowBackgrounds or {}) do
        self:setTexture(bg,"pixel")
        self:setBackgroundColor(bg,ROW_SELECTED)
    end
    for _,dot in ipairs(self.rowStatusDots or {}) do self:setTexture(dot,"circle") end
    for _,tip in ipairs(self.rowTips or {}) do self:setTexture(tip,"rowTip") end
    for i,bg in ipairs(self.detailBackgrounds or {}) do
        bg:setImageFilename(Employees.directory .. "gui/pixel.dds")
        local shade=i%2==1 and 0.045 or 0.025
        bg:setImageColor(nil,shade,shade,shade,1)
    end

    for _,button in ipairs({self.noticeButton,self.hireButton,self.roleButton}) do
        self:configureAlwaysFilledButton(button,GREEN)
    end
    self:configureAlwaysFilledButton(self.cancelButton,DARK)
    self:configureAlwaysFilledButton(self.overviewButton,DARK)
    if self.cancelButton then self.cancelButton:setTextColor(0.95,0.95,0.95,1) end
    if self.overviewButton then self.overviewButton:setTextColor(0.95,0.95,0.95,1) end
    self:updateTabVisuals()
end

function EmployeesFrame:onFrameOpen()
    EmployeesFrame:superClass().onFrameOpen(self)
    self.confirmId=nil
    self.overviewMode=false
    self.employeeFrameOpen=true
    self.refreshElapsed=0
    self:refresh()
end

function EmployeesFrame:onFrameClose()
    self.employeeFrameOpen=false
    self.confirmId=nil
    EmployeesFrame:superClass().onFrameClose(self)
end

function EmployeesFrame:update(dt)
    EmployeesFrame:superClass().update(self,dt)
    if not self.employeeFrameOpen then return end
    self.refreshElapsed=(self.refreshElapsed or 0)+dt
    if self.refreshElapsed>=1000 then
        self.refreshElapsed=0
        self:refresh()
    end
end

function EmployeesFrame:getEmployeeRowAtMousePosition(posX,posY)
    for i=1,PAGE_SIZE do
        local row=self.employeeRows and self.employeeRows[i] or nil
        if row~=nil and row:getIsVisible() then
            local size=row.absSize or row.size
            if size~=nil and GuiUtils.checkOverlayOverlap(posX,posY,row.absPosition[1],row.absPosition[2],size[1],size[2],nil) then
                return i
            end
        end
    end
    return nil
end

function EmployeesFrame:isMouseOverEmployeeList(posX,posY)
    local first=self.employeeRows and self.employeeRows[1] or nil
    local last=self.employeeRows and self.employeeRows[PAGE_SIZE] or nil
    if first==nil or last==nil then return false end
    local firstSize=first.absSize or first.size
    local lastSize=last.absSize or last.size
    if firstSize==nil or lastSize==nil then return false end

    local minX=first.absPosition[1]
    local maxX=first.absPosition[1]+firstSize[1]
    local minY=last.absPosition[2]
    local maxY=first.absPosition[2]+firstSize[2]
    if minY>maxY then minY,maxY=maxY,minY end

    if self.pageSlider~=nil then
        local sliderSize=self.pageSlider.absSize or self.pageSlider.size
        if sliderSize~=nil then
            maxX=math.max(maxX,self.pageSlider.absPosition[1]+sliderSize[1])
        end
    end
    return posX>=minX and posX<=maxX and posY>=minY and posY<=maxY
end

function EmployeesFrame:scrollEmployeeList(delta)
    local maxOffset=math.max(0,#(self.rows or {})-PAGE_SIZE)
    local nextOffset=math.max(0,math.min(maxOffset,(self.offset or 0)+delta))
    if nextOffset==(self.offset or 0) then return false end
    self.offset=nextOffset
    self.confirmId=nil
    self:refresh()
    return true
end

function EmployeesFrame:mouseEvent(posX,posY,isDown,isUp,button,eventUsed)
    if self.employeeFrameOpen and not self.overviewMode and isDown and self:isMouseOverEmployeeList(posX,posY) then
        if Input.isMouseButtonPressed(Input.MOUSE_BUTTON_WHEEL_UP) then
            if self:scrollEmployeeList(-1) then return true end
        elseif Input.isMouseButtonPressed(Input.MOUSE_BUTTON_WHEEL_DOWN) then
            if self:scrollEmployeeList(1) then return true end
        end
    end

    local used=EmployeesFrame:superClass().mouseEvent(self,posX,posY,isDown,isUp,button,eventUsed)

    if self.employeeFrameOpen and not self.overviewMode and not used and button==Input.MOUSE_BUTTON_LEFT then
        local rowIndex=self:getEmployeeRowAtMousePosition(posX,posY)
        if isDown and rowIndex~=nil then
            self.employeeRowMouseDown=rowIndex
            return true
        elseif isUp then
            local pressed=self.employeeRowMouseDown
            self.employeeRowMouseDown=nil
            if pressed~=nil and rowIndex==pressed then
                self:selectVisibleRow(pressed)
                return true
            end
        end
    elseif isUp and button==Input.MOUSE_BUTTON_LEFT then
        self.employeeRowMouseDown=nil
    end

    return used
end

function EmployeesFrame:setContractTab(index)
    if index<1 or index>4 or index==self.contractTab then return end
    self.contractTab=index
    self.offset, self.selectedId, self.confirmId=0,nil,nil
    self:refresh()
end

function EmployeesFrame:onTabMinor() self:setContractTab(1) end
function EmployeesFrame:onTabPart() self:setContractTab(2) end
function EmployeesFrame:onTabFull() self:setContractTab(3) end
function EmployeesFrame:onTabTemp() self:setContractTab(4) end
function EmployeesFrame:getDisplayContractPosition()
    for i, contractIndex in ipairs(DISPLAY_CONTRACT_ORDER) do
        if contractIndex == self.contractTab then return i end
    end
    return 1
end
function EmployeesFrame:onPreviousTab()
    local pos=self:getDisplayContractPosition()-1
    if pos<1 then pos=#DISPLAY_CONTRACT_ORDER end
    self:setContractTab(DISPLAY_CONTRACT_ORDER[pos])
end
function EmployeesFrame:onNextTab()
    local pos=self:getDisplayContractPosition()+1
    if pos>#DISPLAY_CONTRACT_ORDER then pos=1 end
    self:setContractTab(DISPLAY_CONTRACT_ORDER[pos])
end

function EmployeesFrame:getEmployeeStatusText(e)
    if e==nil then return "-" end
    local status=Employees:isEmployeeInJob(e) and "Im Einsatz" or "Verfügbar"
    local autoTask=Employees:getActiveAutoTask(e)
    if autoTask~=nil then status=autoTask end
    if e.hours>=e.limit and not Employees:isEmployeeInMaintenance(e) then status="Stundenkontingent erreicht" end
    if Employees:isTraining(e) then status="Fortbildung · " .. Employees:trainingTimeText(e) end
    if e.role=="none" and not Employees:isEmployeeInJob(e) and not Employees:isTraining(e) and not Employees:isEmployeeInMaintenance(e) then
        status="Aufgabengebiet zuweisen"
    end
    local illnessStatus=Employees:getIllnessStatusText(e)
    if illnessStatus~=nil then status=illnessStatus end
    return status
end

function EmployeesFrame:setOverviewVisible(visible)
    self.overviewMode=visible==true
    if self.detailContent then self.detailContent:setVisible(not self.overviewMode) end
    if self.trainingPanelBg then self.trainingPanelBg:setVisible(not self.overviewMode) end
    if self.noticePanelBg then self.noticePanelBg:setVisible(not self.overviewMode) end
    if self.overviewPanel then self.overviewPanel:setVisible(self.overviewMode) end
    if self.overviewButton then
        self.overviewButton:setText(self.overviewMode and "Mitarbeiteransicht" or "Personalübersicht")
    end
end

function EmployeesFrame:refreshOverview()
    if not self.overviewMode then return end
    local farmId=Employees:farmId()
    local rows=Employees:getSortedStaff(farmId)
    local contracts,roles,contractRoles=Employees:getStaffOverviewCounts(farmId)
    local function people(n) return n==1 and "Person" or "Personen" end
    self.overviewMinorCount:setText(string.format("Geringfügig: %d %s",contracts[1] or 0,people(contracts[1] or 0)))
    self.overviewPartCount:setText(string.format("Teilzeit: %d %s",contracts[2] or 0,people(contracts[2] or 0)))
    self.overviewFullCount:setText(string.format("Vollzeit: %d %s",contracts[3] or 0,people(contracts[3] or 0)))
    if self.overviewTempCount then self.overviewTempCount:setText(string.format("Leiharbeiter: %d %s",contracts[4] or 0,people(contracts[4] or 0))) end

    local function roleSummary(index)
        local r=(contractRoles and contractRoles[index]) or {}
        return string.format("Feldarbeit: %d\nTransport: %d\nTierhaltung: %d\nMaschinentechnik: %d\nNicht zugewiesen: %d",
            r.fieldwork or 0,r.transport or 0,r.animals or 0,r.machinery or 0,r.none or 0)
    end
    if self.overviewMinorRoles then self.overviewMinorRoles:setText(roleSummary(1)) end
    if self.overviewPartRoles then self.overviewPartRoles:setText(roleSummary(2)) end
    if self.overviewFullRoles then self.overviewFullRoles:setText(roleSummary(3)) end
    if self.overviewTempRoles then self.overviewTempRoles:setText(roleSummary(4)) end

    for i=1,#(self.overviewRowBackgrounds or {}) do
        local e=i<=Employees.maxEmployees and rows[i] or nil
        local visible=e~=nil
        self.overviewRowBackgrounds[i]:setVisible(visible)
        self.overviewContracts[i]:setVisible(visible)
        self.overviewNames[i]:setVisible(visible)
        self.overviewRoles[i]:setVisible(visible)
        self.overviewStatuses[i]:setVisible(visible)
        if visible then
            self.overviewContracts[i]:setText(TAB_NAMES[e.contract] or "-")
            self.overviewNames[i]:setText(e.name or "-")
            self.overviewRoles[i]:setText(Employees:getRoleLabel(e.role))
            self.overviewStatuses[i]:setText(self:getEmployeeStatusText(e))
        end
    end
end

function EmployeesFrame:onOverview()
    self:setOverviewVisible(not self.overviewMode)
    self:refresh()
end

function EmployeesFrame:refresh()
    Employees:updateTrainingClock()
    self.rows={}
    local total,count=0,0
    for _,e in ipairs(Employees.staff or {}) do
        if e.farmId==Employees:farmId() then
            count=count+1
            Employees:ensureDevelopment(e)
            if e.contract==self.contractTab then table.insert(self.rows,e); total=total+e.salary end
        end
    end
    self.offset=math.min(self.offset or 0,math.max(0,#self.rows-PAGE_SIZE))
    local currentContract=Employees.contracts[self.contractTab]
    if currentContract ~= nil and currentContract.temporary then
        self.summary:setText(string.format("%d Leiharbeiter  ·  %s / Einsatz",#self.rows,g_i18n:formatMoney(currentContract.salary,0,true,true)))
    else
        self.summary:setText(string.format("%d Mitarbeiter  ·  %s / Monat",#self.rows,g_i18n:formatMoney(total,0,true,true)))
    end
    local selected
    for _,e in ipairs(self.rows) do if e.id==self.selectedId then selected=e end end
    if selected==nil then selected=self.rows[self.offset+1]; self.selectedId=selected and selected.id or nil end
    self.selected=selected
    self:setPortrait(self.portrait,selected)
    self.categoryTitle:setText(TAB_NAMES[self.contractTab])
    self:updateTabVisuals()

    for i=1,PAGE_SIZE do
        local e=self.rows[self.offset+i]
        local button=self.employeeRows[i]
        local accent=self.rowBackgrounds and self.rowBackgrounds[i] or nil
        local roleText=self.rowRoles and self.rowRoles[i] or nil
        local statusDot=self.rowStatusDots and self.rowStatusDots[i] or nil
        local visible=e~=nil
        button:setVisible(visible)
        if accent then accent:setVisible(visible and e.id==self.selectedId) end
        self:setPortrait(self.rowPortraits[i],e)
        self.rowMeta[i]:setVisible(visible)
        if roleText then roleText:setVisible(visible) end
        if statusDot then statusDot:setVisible(visible) end
        button:setDisabled(not visible)
        self.rowTips[i]:setVisible(visible and e.id==self.selectedId)
        button.employeeId=e and e.id or nil
        if e then
            local active=e.id==self.selectedId
            button:setText(e.name)
            if roleText then
                roleText:setText(Employees:getRoleLabel(e.role))
                roleText:setTextColor(active and 0.08 or 0.72,active and 0.10 or 0.74,active and 0.02 or 0.72,1)
            end
            self.rowMeta[i]:setText(string.format("%s  ·  %.1f h frei  ·  %d Jahre",g_i18n:formatMoney(e.salary,0,true,true),math.max(0,e.limit-e.hours),e.age))
            if Employees:isTraining(e) then self.rowMeta[i]:setText("Fortbildung · " .. Employees:trainingTimeText(e)) end
            local illnessStatus=Employees:getIllnessStatusText(e)
            if illnessStatus~=nil then self.rowMeta[i]:setText(illnessStatus) end
            self.rowMeta[i]:setTextColor(active and 0.08 or 0.65,active and 0.10 or 0.8,active and 0.02 or 0.3,1)
            button:setTextColor(active and 0.08 or 0.94,active and 0.10 or 0.94,active and 0.02 or 0.92,1)
            if statusDot then self:setBackgroundColor(statusDot,self:getEmployeeStatusColor(e)) end
        end
    end

    self.emptyText:setVisible(#self.rows==0)
    if self.pageSlider then
        local maxStart=math.max(1,#self.rows-PAGE_SIZE+1)
        local currentStart=self.offset+1
        self.updatingPageSlider=true
        self.pageSlider:setMinValue(1)
        self.pageSlider:setMaxValue(maxStart,currentStart)
        self.pageSlider:setSliderSize(math.min(PAGE_SIZE,math.max(1,#self.rows)),math.max(PAGE_SIZE,#self.rows))
        self.pageSlider.needsSlider=maxStart>1
        self.pageSlider:setSliderVisible(maxStart>1)
        self.pageSlider:setDisabled(maxStart<=1)
        self.pageSlider:setValue(currentStart,true,true)
        self.updatingPageSlider=false
    end
    self:setActionButtonState(self.noticeButton,selected~=nil and not Employees:isTemporaryEmployee(selected))
    self.cancelButton:setVisible(self.confirmId~=nil)
    if self.confirmId~=nil then
        self:setActionButtonState(self.cancelButton,true,DARK)
        self.cancelButton:setTextColor(0.95,0.95,0.95,1)
    end

    local c=Employees.contracts[self.contractTab]
    if c.temporary then
        self.contractInfo:setText(string.format("%s / Einsatz  ·  max. %d Spielstunden",g_i18n:formatMoney(c.salary,0,true,true),c.hours))
        self.hireButton:setText("Leiharbeiter anfordern")
    else
        self.contractInfo:setText(string.format("%s / Monat  ·  %d Spielstunden",g_i18n:formatMoney(c.salary,0,true,true),c.hours))
        self.hireButton:setText("Mitarbeiter einstellen")
    end
    self:setActionButtonState(self.hireButton,Employees:getFreeRosterId(Employees:farmId())~=nil)
    self.detailName:setText(selected and selected.name or "Kein Mitarbeiter ausgewählt")

    local values={"-","-","-","-","-","-","-"}
    local selectedContract=selected and Employees.contracts[selected.contract] or nil
    if self.detailLabels and self.detailLabels[2] then self.detailLabels[2]:setText(selectedContract and selectedContract.temporary and "Einsatzkosten" or "Monatsgehalt") end
    if selected then
        local status=self:getEmployeeStatusText(selected)
        local payText=g_i18n:formatMoney(selected.salary,0,true,true)
        local contractText=selected.leave<0 and "Ungekündigt" or string.format("Austritt in %d Monatswechseln",selected.leave-Employees.month)
        if selectedContract ~= nil and selectedContract.temporary then
            payText=payText .. " / Einsatz"
            contractText="Automatisch bis 8 Arbeitsstunden"
        end
        values={TAB_NAMES[selected.contract],payText,
            string.format("%.1f / %d Spielstunden",selected.hours,selected.limit),status,
            string.format("%d Jahre",selected.age),contractText,
            Employees:getRoleLabel(selected.role)}
    end
    for i,value in ipairs(values) do self.detailValues[i]:setText(value) end

    local roleEnabled=selected~=nil and not Employees:isEmployeeInJob(selected) and not Employees:isTraining(selected) and not Employees:isEmployeeInMaintenance(selected)
    self:setActionButtonState(self.roleButton,roleEnabled)
    if self.roleButton then
        self.roleButton:setText(selected and (selected.role=="none" and "Aufgabengebiet zuweisen" or "Aufgabengebiet ändern") or "Aufgabengebiet")
    end

    for i,training in ipairs(Employees.trainingTypes) do
        local level=Employees:getTrainingLevel(selected,training.key)
        local offer,_,nextLevel,cost=Employees:getTrainingOffer(selected,training.key)
        local enabled=selected~=nil and Employees:canTrain(selected,training.key)
        self.trainingProgress[i]:setText(string.format("%d / %d",level,training.maxLevel))
        self.trainingButtons[i]:setText(offer and "WEITERBILDUNG STARTEN" or "ABGESCHLOSSEN")
        self:setActionButtonState(self.trainingButtons[i],enabled)
        local hint="Mitarbeiter auswählen."
        if selected then
            if Employees:isTraining(selected) then
                if selected.activeTraining==training.key then
                    hint=string.format("Stufe %d läuft · Noch %s",selected.trainingTarget,Employees:trainingTimeText(selected))
                    self.trainingButtons[i]:setText("IN FORTBILDUNG")
                else
                    hint="Mitarbeiter ist auf Fortbildung · Noch " .. Employees:trainingTimeText(selected)
                    self.trainingButtons[i]:setText("NICHT VERFÜGBAR")
                end
            elseif Employees:isTemporaryEmployee(selected) then
                hint="Für Leiharbeiter nicht verfügbar."
                self.trainingButtons[i]:setText("NICHT VERFÜGBAR")
            elseif Employees:isEmployeeInMaintenance(selected) then hint="Während einer Wartung nicht verfügbar."
            elseif not offer then hint="Maximale Stufe erreicht."
            elseif Employees:isEmployeeInJob(selected) then hint="Während eines Einsatzes nicht verfügbar."
            else hint=string.format("Stufe %d · %d Spielstunden · %s",nextLevel,Employees.trainingHours[nextLevel],g_i18n:formatMoney(cost,0,true,true)) .. (enabled and "" or " · Zu wenig Geld") end
        end
        self.trainingHints[i]:setText(hint)
        if not selected then self.trainingButtons[i]:setText("Weiterbilden") end
    end

    if selected and Employees:isTemporaryEmployee(selected) then
        self.noticeButton:setText("Endet automatisch nach 8 Stunden")
    else
        self.noticeButton:setText(selected and selected.leave>=0 and "Kündigung zurücknehmen" or (self.confirmId and "Kündigung bestätigen" or "Kündigung aussprechen"))
    end
    if self.noticeHint then self.noticeHint:setVisible(false) end
    self:setOverviewVisible(self.overviewMode)
    self:refreshOverview()
end


function EmployeesFrame:onRole()
    local selected=self.selected
    if selected==nil or Employees:isEmployeeInJob(selected) or Employees:isTraining(selected) or Employees:isEmployeeInMaintenance(selected) or OptionDialog==nil then return end
    local employeeId=selected.id
    local options={}
    for _,role in ipairs(Employees.roles) do
        if role.key ~= "none" then
            table.insert(options,role.label)
        end
    end
    OptionDialog.show(function(index)
        local e=nil
        for _,current in ipairs(Employees.staff or {}) do if current.id==employeeId then e=current; break end end
        local availableRoles={}
        for _,roleInfo in ipairs(Employees.roles) do
            if roleInfo.key ~= "none" then
                table.insert(availableRoles, roleInfo)
            end
        end
        local role=availableRoles[tonumber(index)]
        if e==nil or role==nil then return end
        if not Employees:requestSetRole(e.id,role.key) then
            Employees:notify("Aufgabengebiet kann während Einsatz oder Fortbildung nicht geändert werden.")
        end
        self:refresh()
    end,"Aufgabengebiet zuweisen","Welche Aufgabe soll dieser Mitarbeiter übernehmen?",options)
end

function EmployeesFrame:onTrain(key)
    if self.selected == nil then return end
    self.confirmId=nil
    Employees:requestTraining(self.selected.id,key)
    self:refresh()
end

function EmployeesFrame:onTrain1() self:onTrain("fieldwork") end
function EmployeesFrame:onTrain2() self:onTrain("transport") end
function EmployeesFrame:onTrain3() self:onTrain("animals") end
function EmployeesFrame:onTrain4() self:onTrain("machinery") end
function EmployeesFrame:onHire()
    self.overviewMode=false
    local e=Employees:requestHire(self.contractTab)
    self.confirmId=nil
    if e then self.selectedId=e.id end
    self:refresh()
    if e then
        for i,row in ipairs(self.rows) do if row.id==e.id then self.offset=math.max(0,i-PAGE_SIZE) end end
        self:refresh()
    end
end

function EmployeesFrame:selectVisibleRow(index)
    local e=self.rows[self.offset+index]
    self.overviewMode=false
    if e==nil then return end
    self.selectedId=e.id
    self.confirmId=nil
    self:refresh()
end

function EmployeesFrame:onSelectEmployee1() self:selectVisibleRow(1) end
function EmployeesFrame:onSelectEmployee2() self:selectVisibleRow(2) end
function EmployeesFrame:onSelectEmployee3() self:selectVisibleRow(3) end
function EmployeesFrame:onSelectEmployee4() self:selectVisibleRow(4) end
function EmployeesFrame:onSelectEmployee5() self:selectVisibleRow(5) end
function EmployeesFrame:onSelectEmployee6() self:selectVisibleRow(6) end
function EmployeesFrame:onSelectEmployee7() self:selectVisibleRow(7) end
function EmployeesFrame:onSelectEmployee8() self:selectVisibleRow(8) end

function EmployeesFrame:onPageSliderChanged(value)
    if self.updatingPageSlider then return end
    local maxOffset=math.max(0,#(self.rows or {})-PAGE_SIZE)
    local newOffset=math.min(maxOffset,math.max(0,math.floor((tonumber(value) or 1)+0.5)-1))
    if newOffset~=self.offset then
        self.offset=newOffset
        self.selectedId=nil
        self.confirmId=nil
        self:refresh()
    end
end

function EmployeesFrame:onCancelNotice() self.confirmId=nil; self:refresh() end
function EmployeesFrame:onNotice()
    self:refresh()
    local e=self.selected
    if not e or Employees:isTemporaryEmployee(e) then return end
    if e.leave>=0 then
        Employees:requestNotice(e.id,true)
        self.confirmId=nil
    elseif self.confirmId==e.id then
        Employees:requestNotice(e.id,false)
        self.confirmId=nil
    else
        self.confirmId=e.id
    end
    self:refresh()
end

EmployeesMenu = {modDirectory=g_currentModDirectory}

function EmployeesMenu:ensurePage()
    if g_gui == nil or g_gui.screenControllers == nil or InGameMenu == nil then return end
    local menu = g_gui.screenControllers[InGameMenu]
    if menu == nil or menu.pageFrames == nil or #menu.pageFrames == 0 then return end
    if menu.pageEmployees ~= nil then return end
    if menu.registerPage == nil or menu.addPageTab == nil or menu.pagingElement == nil then return end
    g_gui:loadProfiles(self.modDirectory .. "gui/guiProfiles.xml")
    g_gui:loadGui(self.modDirectory .. "gui/EmployeesFrame.xml", "EmployeesFrame", EmployeesFrame.new(), true)
    local xml = loadXMLFile("EmployeesFrameRefXML", self.modDirectory .. "gui/EmployeesFrameRef.xml")
    if xml == nil or xml == 0 then return end
    menu.controlIDs.pageEmployees = nil
    g_gui:loadGuiRec(xml, "FrameReferences", menu.pagingElement, menu)
    for _, element in ipairs(menu.pagingElement.elements) do
        if element.id == "pageEmployees" then
            menu.pageEmployees = element
            menu.controlIDs.pageEmployees = true
            break
        end
    end
    menu.pagingElement:updatePageMapping()
    delete(xml)
    if menu.pageEmployees == nil then Logging.error("[Employees] ESC frame reference missing"); return end
    local frame = g_gui:resolveFrameReference(menu.pageEmployees)
    if frame == nil or frame.elements == nil or frame.elements[1] == nil then
        Logging.error("[Employees] ESC frame could not be resolved"); return
    end
    frame.elements[1].title = "Mitarbeiter"
    menu.pageEmployees = frame
    menu.pagingElement:removePageByElement(frame)
    local position = #menu.pageFrames+1
    for i,page in ipairs(menu.pageFrames) do if page==menu.pageStatistics then position=i; break end end
    local _,actualPosition = menu:registerPage(frame, position, function() return Employees.enabled == true end)
    menu:addPageTab(frame, self.modDirectory .. "gui/employeesTab.dds", {0,0,0,1,1,0,1,1}, nil)
    menu.pagingElement:addPage("PAGEEMPLOYEES", frame, "Mitarbeiter", actualPosition)
    frame:onGuiSetupFinished()
    frame:initialize()
    menu.pagingElement:updateAbsolutePosition()
    menu.pagingElement:updatePageMapping()
    if menu.rebuildTabList ~= nil then menu:rebuildTabList() end
    print(string.format("[Employees] ESC menu page added (%s)", Employees.modVersion or "1.0.0.0"))
end
