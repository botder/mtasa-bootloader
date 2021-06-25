--------------------------------------------------------------------------------
-- Access control and session management
--------------------------------------------------------------------------------
function onToggleConfigurationPanel(enabled)
    if enabled then
        openBootloaderWindow()
        requestBootloaderResourceDataList()
    else
        closeBootloaderWindow()
    end
end
addEvent("Bootloader.toggleConfigurationPanel", true)
addEventHandler("Bootloader.toggleConfigurationPanel", resourceRoot, onToggleConfigurationPanel, false)

--------------------------------------------------------------------------------
-- Data stream events
--------------------------------------------------------------------------------
function requestBootloaderResourceDataList()
    preBootloaderResourceDataListRequest()
    triggerServerEvent("BootloaderClient.requestResourceDataList", resourceRoot)
end

function handleBootloaderResourceDataListBatch(resourceDataBatch)
    processBootloaderResourceDataBatch(resourceDataBatch)
end
addEvent("Bootloader.resourceDataListBatch", true)
addEventHandler("Bootloader.resourceDataListBatch", resourceRoot, handleBootloaderResourceDataListBatch, false)

function handleBootloaderResourceDataListComplete()
    completeBootloaderResourceDataBatch()
end
addEvent("Bootloader.resourceDataListComplete", true)
addEventHandler("Bootloader.resourceDataListComplete", resourceRoot, handleBootloaderResourceDataListComplete, false)

function requestBootloaderResourceToggle(resourceName, enabled)
    triggerServerEvent("BootloaderClient.toggleBootloaderResource", resourceRoot, resourceName, enabled)
end

function handleBootloaderResourceDataResponse(resourceName, isEnabled, isRunning)
    processBootloaderResourceData(resourceName, isEnabled, isRunning)
end
addEvent("Bootloader.resourceDataResponse", true)
addEventHandler("Bootloader.resourceDataResponse", resourceRoot, handleBootloaderResourceDataResponse, false)

--------------------------------------------------------------------------------
-- Graphical User Interface
--------------------------------------------------------------------------------
local gui = {}
local minimumWindowWidth = 400
local minimumWindowHeight = 400
local windowTitle = "Bootloader Configuration"

function openBootloaderWindow()
    if gui.window ~= nil then
        return
    end

    gui.width = 600
    gui.height = 600
    gui.rows = {}
    gui.checkboxes = {}
    gui.resources = {}

    local innerWidth = gui.width - 20
    local screenWidth, screenHeight = guiGetScreenSize()
    local posX = (screenWidth - gui.width) / 2
    local posY = (screenHeight - gui.height) / 2
    gui.window = guiCreateWindow(posX, posY, gui.width, gui.height, windowTitle, false)
    addEventHandler("onClientGUISize", gui.window, onBootloaderWindowResize, false)

    local function createHeader(x, y, text)
        local label = guiCreateLabel(x, y, 100, 15, text, false, gui.window)
        guiLabelSetColor(label, 160, 160, 192)
        return label
    end

    gui.headers = {}
    gui.headers[1] = createHeader(20, 25, "State")
    gui.headers[2] = createHeader(75, 25, "Name")
    gui.headers[3] = createHeader(210, 25, "Description")

    local function createBackgroundBorder(x, y, width, height)
        local image = guiCreateStaticImage(x, y, width, height, "dot.bmp", false, gui.window)
        guiStaticImageSetColor(image, 160, 160, 190, 255)
        guiSetEnabled(image, false)
        guiForceSetAlpha(image, 1.0)
        return image
    end

    gui.background = guiCreateStaticImage(10, 42, innerWidth, gui.height - 84, "dot.bmp", false, gui.window)
    guiStaticImageSetVerticalBackground(gui.background, 40, 40, 70, 200, 0, 0, 0, 200)
    guiSetEnabled(gui.background, false)
    guiForceSetAlpha(gui.background, 1.0)
    
    gui.backgroundborder_top = createBackgroundBorder(10, 42, innerWidth, 1)
    gui.backgroundborder_bottom = createBackgroundBorder(10, gui.height - 42, innerWidth, 1)
    gui.backgroundborder_left = createBackgroundBorder(10, 42, 1, gui.height - 84)
    gui.backgroundborder_right = createBackgroundBorder(10 + innerWidth, 42, 1, gui.height - 84)

    local bottomY = gui.height - 35

    gui.filters = {}
    gui.filter_label = guiCreateLabel(10, bottomY + 5, 30, 25, "Filter:", false, gui.window)
    gui.filter_edit = guiCreateEdit(50, bottomY, gui.width - 260, 25, "", false, gui.window)
    gui.filter_help = guiCreateLabel(10, 5, gui.width - 260, 25, "Type: #script | State: ~on, ~off | Enabled: @on, @off", false, gui.filter_edit)
    guiLabelSetColor(gui.filter_help, 60, 60, 60)
    guiSetEnabled(gui.filter_help, false)
    addEventHandler("onClientGUIChanged", gui.filter_edit, onBootloaderFilterChanged, false)

    gui.refresh = guiCreateButton(gui.width - 200, bottomY, 90, 25, "Refresh", false, gui.window)
    addEventHandler("onClientGUIClick", gui.refresh, onBootloaderRefreshButtonClick, false)

    gui.close = guiCreateButton(gui.width - 100, bottomY, 90, 25, "Close", false, gui.window)
    addEventHandler("onClientGUIClick", gui.close, onBootloaderCloseButtonClick, false)

    showCursor(true)
    guiSetInputEnabled(true)
end

function closeBootloaderWindow()
    destroyElement(gui.window)
    guiSetInputEnabled(false)
    showCursor(false)
    gui = {}
end

function onBootloaderWindowResize()
    gui.width, gui.height = guiGetSize(source, false)

    if gui.width < minimumWindowWidth or gui.height < minimumWindowWidth then
        gui.width = math.max(minimumWindowWidth, gui.width)
        gui.height = math.max(minimumWindowWidth, gui.height)
        return guiSetSize(source, gui.width, gui.height, false)
    end

    if gui.scrollpane then
        guiSetSize(gui.scrollpane, gui.width - 35, gui.height - 100, false)
    end

    local innerWidth = gui.width - 20

    guiSetSize(gui.background, innerWidth, gui.height - 84, false)

    guiSetSize(gui.backgroundborder_top, innerWidth, 1, false)
    guiSetSize(gui.backgroundborder_bottom, innerWidth, 1, false)
    guiSetSize(gui.backgroundborder_left, 1, gui.height - 84, false)
    guiSetSize(gui.backgroundborder_right, 1, gui.height - 84, false)

    guiSetPosition(gui.backgroundborder_bottom, 10, gui.height - 42, false)
    guiSetPosition(gui.backgroundborder_right, 10 + innerWidth, 42, false)

    local bottomY = gui.height - 35

    guiSetSize(gui.filter_edit, gui.width - 260, 25, false)

    guiSetPosition(gui.filter_label, 10, bottomY + 5, false)
    guiSetPosition(gui.filter_edit, 50, bottomY, false)
    guiSetPosition(gui.refresh, gui.width - 200, bottomY, false)
    guiSetPosition(gui.close, gui.width - 100, bottomY, false)
end

function onBootloaderFilterChanged()
    local filter = guiGetText(gui.filter_edit) or ""
    local filters = split(utf8.fold(filter), " ")
    local length = 0
    gui.filters = {}

    if filters then
        for i = 1, #filters do
            local filter = {
                text = utf8.trim(filters[i]),
                negation = false,
            }

            if utf8.sub(filter.text, 1, 1) == "!" then
                filter.negation = true
                filter.text = utf8.sub(filter.text, 2)
            end

            if filter.text ~= "" then
                length = length + 1
                gui.filters[length] = filter
            end
        end
    end

    guiSetVisible(gui.filter_help, filter == "")
    updateBootloaderScrollpaneLayout()
end

function onBootloaderCloseButtonClick()
    closeBootloaderWindow()
    triggerServerEvent("BootloaderClient.closePanel", resourceRoot)
end

function onBootloaderRefreshButtonClick()
    requestBootloaderResourceDataList()
end

function onBootloaderScrollpaneClick()
    if getElementType(source) == "gui-checkbox" then
        local row = gui.checkboxes[source]

        if row ~= nil then
            local selected = guiCheckBoxGetSelected(source)
            guiSetEnabled(source, false)
            requestBootloaderResourceToggle(row.data.name, selected)
        end
    end
end

local spinnersText = {
    "⢎⡰", "⢎⡡", "⢎⡑", "⢎⠱", "⠎⡱", "⢊⡱", "⢌⡱", "⢆⡱",
}

local spinnersLength = #spinnersText

function updateBootloaderWindowSpinner()
    gui.spinner = ((gui.spinner + 1) % spinnersLength) + 1
    guiSetText(gui.window, ("%s - Loading %s"):format(windowTitle, spinnersText[gui.spinner]))
end

function preBootloaderResourceDataListRequest()
    if gui.window == nil then
        return
    end

    clearBootloaderScrollpane()

    gui.spinner = 0
    updateBootloaderWindowSpinner()
end

function processBootloaderResourceDataBatch(resourceDataBatch)
    if gui.window == nil then
        return
    end

    if gui.scrollpane == nil then
        createBootloaderScrollpane()
    end

    createBootloaderResourceRows(resourceDataBatch)
    sortBootloaderResourceRows()
    updateBootloaderScrollpaneLayout()

    updateBootloaderWindowSpinner()
end

function completeBootloaderResourceDataBatch()
    if gui.window == nil then
        return
    end

    gui.spinner = nil
    guiSetText(gui.window, windowTitle)
end

function createBootloaderScrollpane()
    gui.scrollpane = guiCreateScrollPane(20, 50, gui.width - 35, gui.height - 100, false, gui.window)
    gui.scrollpadding = guiCreateLabel(0, 0, 1, 1, "", false, gui.scrollpane)
    addEventHandler("onClientGUIClick", gui.scrollpane, onBootloaderScrollpaneClick)
    guiSetProperty(gui.scrollpane, "VertStepSize", 0.05)
    guiForceSetAlpha(gui.scrollpane, 1.0)
end

function clearBootloaderScrollpane()
    if gui.scrollpane then
        destroyElement(gui.scrollpane)
        gui.scrollpane = nil
        gui.rows = {}
        gui.checkboxes = {}
        gui.resources = {}
    end
end

function generateResourceDataFilter(data)
    return utf8.fold(table.concat({
        data.name,
        "#"..(data.type or "none"),
        (data.running and "~on" or "~off"),
        (data.enabled and "@on" or "@off"),
    }, " "))
end

function createBootloaderResourceRows(resourceDataBatch)
    local rowsLength = #gui.rows

    for i = 1, #resourceDataBatch do
        local data = resourceDataBatch[i]
        
        -- Trim string values
        for key, value in pairs(data) do
            if type(value) == "string" then
                value = utf8.trim(value)

                if value == "" then
                    data[key] = false
                else
                    data[key] = value
                end
            end
        end

        -- Create table data for row
        local row = {
            data = data,
            filter = generateResourceDataFilter(data),
            sortableValue = utf8.fold(data.name),
            widths = {},
            gui = {},
        }

        -- Create row gui
        row.gui.status = guiCreateStaticImage(0, 0, 20, 20, "status.png", false, gui.scrollpane)
        guiSetEnabled(row.gui.status, false)

        if data.running then
            guiStaticImageSetColor(row.gui.status, 100, 255, 100, 255)
        else
            guiStaticImageSetColor(row.gui.status, 100, 100, 100, 255)
        end

        row.gui.checkbox = guiCreateCheckBox(0, 0, 0, 20, "", data.enabled, false, gui.scrollpane)
        
        row.gui.name = guiCreateLabel(0, 0, 0, 20, data.name, false, gui.scrollpane)
        guiSetEnabled(row.gui.name, false)

        row.gui.description = guiCreateLabel(0, 0, 0, 20, data.description or "-", false, gui.scrollpane)
        guiSetEnabled(row.gui.description, false)

        -- Calculate column widths
        row.widths.name = guiLabelGetTextExtent(row.gui.name)
        guiSetSize(row.gui.name, row.widths.name, 20, false)

        row.widths.description = guiLabelGetTextExtent(row.gui.description)
        guiSetSize(row.gui.description, row.widths.description, 20, false)

        -- Store row references
        gui.rows[i + rowsLength] = row
        gui.checkboxes[row.gui.checkbox] = row
        gui.resources[data.name] = row
    end
end

function sortBootloaderResourceRows()
    table.sort(gui.rows, function (rowA, rowB)
        return rowA.sortableValue < rowB.sortableValue
    end)
end

function updateBootloaderScrollpaneLayout()
    local visible_length = 0

    local column_width = {
        [1] = 55,
        [2] = 100,
        [3] = 200,
    }

    for i = 1, #gui.rows do
        local row = gui.rows[i]
        row.visible = true

        if gui.filters[1] then
            for i = 1, #gui.filters do
                local filter = gui.filters[i]
                local matched = (utf8.find(row.filter, filter.text, 1, true) ~= nil)

                if filter.negation then
                    matched = not matched
                end

                row.visible = matched

                if not row.visible then
                    break
                end
            end
        end

        if row.visible then
            visible_length = visible_length + 1

            local r, g, b = 255, 255, 100

            if (visible_length % 2) == 0 then
                r, g, b = 255, 255, 170
            end

            row.rgb = { r, g, b }

            if not row.data.running then
                r = r * 0.5
                g = g * 0.5
                b = b * 0.5
            end

            guiLabelSetColor(row.gui.name, r, g, b)
            guiLabelSetColor(row.gui.description, r, g, b)

            column_width[2] = math.max(column_width[2], row.widths.name)
            column_width[3] = math.max(column_width[3], row.widths.description)

            -- Apply the real width to the labels
            guiSetSize(row.gui.name, row.widths.name, 20, false)
            guiSetSize(row.gui.description, row.widths.description, 20, false)

            guiSetSize(row.gui.status, 20, 20, false)
        else
            -- Reset the size of the labels because the scrollbars inside the scrollpane
            -- include invisible items in the scrollbar-visibility calculation
            guiSetSize(row.gui.name, 0, 0, false)
            guiSetSize(row.gui.description, 0, 0, false)
        end

        for name, element in pairs(row.gui) do
            guiSetVisible(element, row.visible)

            if not row.visible then
                guiSetPosition(element, 0, 0, false)
            end
        end
    end

    local column_position = {}
    column_position[1] = 0
    column_position[2] = column_position[1] + column_width[1]
    column_position[3] = 10 + column_position[2] + column_width[2]

    for i = 1, 3 do
        local header = gui.headers[i]
        local px, py = guiGetPosition(header, false)
        guiSetPosition(header, column_position[i] + 20, py, false)
    end

    if visible_length == 0 then
        guiSetPosition(gui.scrollpadding, 0, 0, false)
        return
    end

    local y = 0

    for i = 1, #gui.rows do
        local row = gui.rows[i]

        if row.visible then
            guiSetPosition(row.gui.status, 0, y, false)
            guiSetPosition(row.gui.checkbox, 30, y, false)
            guiSetPosition(row.gui.name, column_position[2], y, false)
            guiSetPosition(row.gui.description, column_position[3], y, false)

            guiSetSize(row.gui.checkbox, column_width[2] + 25, 20, false)

            y = y + 20
        end
    end

    local paddingX = 25 + column_position[3] + column_width[3]
    local paddingY = y + 20
    guiSetPosition(gui.scrollpadding, paddingX, paddingY, false)
end

function processBootloaderResourceData(resourceName, isEnabled, isRunning)
    if gui.window == nil then
        return
    end

    local row = gui.resources[resourceName]

    if row == nil then
        return
    end

    updateBootloaderResourceRow(row, isEnabled, isRunning)
end

function updateBootloaderResourceRow(row, isEnabled, isRunning)
    row.data.enabled = isEnabled
    row.data.running = isRunning
    row.filter = generateResourceDataFilter(row.data)
    guiCheckBoxSetSelected(row.gui.checkbox, isEnabled)
    guiSetEnabled(row.gui.checkbox, true)

    local r, g, b = unpack(row.rgb)

    if isRunning then
        guiStaticImageSetColor(row.gui.status, 100, 255, 100, 255)
    else
        guiStaticImageSetColor(row.gui.status, 100, 100, 100, 255)

        r = r * 0.5
        g = g * 0.5
        b = b * 0.5
    end

    guiLabelSetColor(row.gui.name, r, g, b)
    guiLabelSetColor(row.gui.description, r, g, b)
end

--------------------------------------------------------------------------------
-- Utility and extension functions
--------------------------------------------------------------------------------
function utf8.trim(self)
    assert(type(self) == "string", "expected string at argument 1, got ".. type(self))
    local from = utf8.match(self, "^%s*()")
    return from > utf8.len(self) and "" or utf8.match(self, ".*%S", from)
end

function guiStaticImageSetColor(guiElement, r, g, b, a)
    local c = ("%02X%02X%02X%02X"):format(a, r, g, b)
    local value = ("tl:%s tr:%s bl:%s br:%s"):format(c, c, c, c)
    guiSetProperty(guiElement, "ImageColours", value)
end

function guiStaticImageSetVerticalBackground(guiElement, r1, g1, b1, a1, r2, g2, b2, a2)
    local c1 = ("%02X%02X%02X%02X"):format(a1, r1, g1, b1)
    local c2 = ("%02X%02X%02X%02X"):format(a2, r2, g2, b2)
    local value = ("tl:%s tr:%s bl:%s br:%s"):format(c1, c1, c2, c2)
    guiSetProperty(guiElement, "ImageColours", value)
end

function guiForceSetAlpha(element, alpha)
    guiSetProperty(element, "InheritsAlpha", "False")
    guiSetAlpha(element, alpha)
end
