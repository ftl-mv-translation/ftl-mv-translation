local check_paused = mods.multiverse.check_paused

mods.multiverse.icons = mods.multiverse.icons or {}
mods.multiverse.iconsUninstalled = mods.multiverse.iconsUninstalled or {}

local scrollShift = 0 -- Tracking the scroll position
local iconOnRow = 11 -- How many icons shown at a time
local baseOffset = {
    x = 115,
    y = 5
}
local iconSize = {
    x = 24,
    y = 14
}

local iconsAdded = {}

-- Load the icons from the XML file
do
    local doc = RapidXML.xml_document("data/events_addon_icon.xml")
    local addonNode = (doc:first_node("FTL") or doc):first_node("event")

    while addonNode do
        local iconName = string.sub(addonNode:first_attribute("name"):value(), 7, string.len(addonNode:first_attribute("name"):value()))
        if not iconsAdded[iconName] then
            iconsAdded[iconName] = true
            local iconUninstalled = string.find(iconName, "_DISABLED") ~= nil
            local iconHoverText = addonNode:first_node("hover-text") and addonNode:first_node("hover-text"):value() or "No hover text found.\nClick to see more info."

            local iconData = {
                name = iconName,
                image = Hyperspace.Resources:CreateImagePrimitiveString("addons/"..string.lower(iconName).."_on.png", 0, 0, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false),
                imageHover = Hyperspace.Resources:CreateImagePrimitiveString("addons/"..string.lower(iconName).."_select2.png", 0, 0, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false),
                event = "ADDON_"..iconName,
                hover = false,
                hoverText = iconHoverText
            }

            if iconUninstalled then
                table.insert(mods.multiverse.iconsUninstalled, iconData)
            else
                table.insert(mods.multiverse.icons, iconData)
            end
        end
        addonNode = addonNode:next_sibling("event")
    end

    doc:clear()
end

-- Render individual icons
local function render_icon(iconData, iconCounter)
    -- Only render icons within the current window
    if iconCounter < scrollShift or iconCounter >= scrollShift + iconOnRow then return end

    local displayPosition = iconCounter - scrollShift
    local xOffset = baseOffset.x + (displayPosition*iconSize.x)
    local yOffset = baseOffset.y
    local mousePos = Hyperspace.Mouse.position

    if math.abs(mousePos.x - xOffset - 12) < 12 and math.abs(mousePos.y - yOffset - 7) < 7 then
        iconData.hover = true
        Hyperspace.Mouse.tooltip = iconData.hoverText
    else
        iconData.hover = false
    end

    Graphics.CSurface.GL_PushMatrix()
    Graphics.CSurface.GL_Translate(xOffset, yOffset, 0)

    if iconData.hover then
        Graphics.CSurface.GL_RenderPrimitive(iconData.imageHover)
    else
        Graphics.CSurface.GL_RenderPrimitive(iconData.image)
    end

    Graphics.CSurface.GL_PopMatrix()
end

-- Render all icons
script.on_render_event(Defines.RenderEvents.SHIP_STATUS, function()
    if Hyperspace.App.world.bStartedGame then
        local renderedAddons = {}
        local iconCounter = 0

        for _, iconData in ipairs(mods.multiverse.icons) do
            renderedAddons[iconData.name.."_DISABLED"] = true
            render_icon(iconData, iconCounter)
            iconCounter = iconCounter + 1
        end

        for _, iconData in ipairs(mods.multiverse.iconsUninstalled) do
            if not renderedAddons[iconData.name] then
                render_icon(iconData, iconCounter)
                iconCounter = iconCounter + 1
            end
        end
    end
end, function() end)

-- Show info for an addon on click
script.on_internal_event(Defines.InternalEvents.ON_MOUSE_L_BUTTON_DOWN, function(x, y)
    if Hyperspace.App.world.bStartedGame and not check_paused() then
        for _, iconData in ipairs(mods.multiverse.icons) do
            if iconData.hover then
                local worldManager = Hyperspace.App.world
                Hyperspace.CustomEventsParser.GetInstance():LoadEvent(worldManager, iconData.event, false, -1)
            end
        end
        for _, iconData in ipairs(mods.multiverse.iconsUninstalled) do
            if iconData.hover then
                local worldManager = Hyperspace.App.world
                Hyperspace.CustomEventsParser.GetInstance():LoadEvent(worldManager, iconData.event, false, -1)
            end
        end
    end
end)

-- Scroll through addons icons horizontally
script.on_internal_event(Defines.InternalEvents.ON_MOUSE_SCROLL, function(direction)
    if Hyperspace.App.world.bStartedGame then
        local mousePos = Hyperspace.Mouse.position
        if mousePos.x > baseOffset.x and mousePos.x < baseOffset.x + iconOnRow*iconSize.x and mousePos.y > baseOffset.y and mousePos.y < baseOffset.y + iconSize.y then

            local enabledIcons = {}
            local iconCount = 0
            for _, iconData in ipairs(mods.multiverse.icons) do
                if iconData.hover then iconData.hover = false end
                enabledIcons[iconData.name.."_DISABLED"] = true
                iconCount = iconCount + 1
            end

            for _, iconData in ipairs(mods.multiverse.iconsUninstalled) do
                if iconData.hover then iconData.hover = false end
                if not enabledIcons[iconData.name] then
                    iconCount = iconCount + 1
                end
            end

            if direction == -1 then
                scrollShift = scrollShift - 1
            elseif direction == 1 then
                scrollShift = scrollShift + 1
            end

            -- Limit scrolling
            if scrollShift < 0 then
                scrollShift = 0
            end
            if scrollShift > iconCount - iconOnRow then
                scrollShift = math.max(0, iconCount - iconOnRow)
            end
        end
    end
end)
