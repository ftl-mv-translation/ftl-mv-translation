-- Utility functions
local Children
do
    local function nodeIter(Parent, Child)
        if Child == "Start" then return Parent:first_node() end
        return Child:next_sibling()
    end
    Children = function(Parent)
        if not Parent then error("Invalid node to Children iterator!", 2) end
        return nodeIter, Parent, "Start"
    end
end
local function parse_xml_bool(s)
    return s == "true" or s == "True" or s == "TRUE"
end
local function node_get_bool_default(node, default)
    if not node then return default end
    local ret = node:value()
    if not ret then return default end
    return parse_xml_bool(ret)
end
local function node_get_number_default(node, default)
    if not node then return default end
    local ret = tonumber(node:value())
    if not ret then return default end
    return ret
end

-- Data init
local hullAnims = {}
hullAnims[0] = {}
hullAnims[1] = {}

-- Data upkeep
local function cleanStaleAnims(shipId)
    for key, value in pairs(hullAnims[shipId]) do
        hullAnims[shipId][key] = nil
    end
end
script.on_internal_event(Defines.InternalEvents.ON_TICK, function()
    if not Hyperspace.ships.player then cleanStaleAnims(0) end
    if not Hyperspace.ships.enemy  then cleanStaleAnims(1) end
end)
script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function(ship)
    local hullAnimSet = hullAnims[ship.iShipId]
    
    -- Keep stored hull anims up to date with loaded ships
    if hullAnimSet["layout"] ~= ship.myBlueprint.layoutFile then
        -- Reset anims associated with this ship ID and open its layout file
        cleanStaleAnims(ship.iShipId)
        hullAnimSet["layout"] = ship.myBlueprint.layoutFile
        local doc = RapidXML.xml_document("data/"..hullAnimSet["layout"]..".xml")
        local hullAnimsNode = doc:first_node("FTL") or doc
        hullAnimsNode = hullAnimsNode:first_node("mv-hullAnims")
        
        -- Parse hullAnim tags in layout file
        if hullAnimsNode then
            local randomFrame = not node_get_bool_default(hullAnimsNode:first_attribute("sync"), true)
            for hullAnim in Children(hullAnimsNode) do
                local anim = Hyperspace.Global.GetInstance():GetAnimationControl():GetAnimation(hullAnim:value())
                if randomFrame then
                    anim:SetCurrentFrame(Hyperspace.random32()%anim.info.numFrames)
                end
                anim.tracker.loop = true
                anim:Start(false)
                anim.position.x = -anim.info.frameWidth/2
                anim.position.y = -anim.info.frameHeight/2
                
                local x = node_get_number_default(hullAnim:first_attribute("x"), 0)
                local y = node_get_number_default(hullAnim:first_attribute("y"), 0)
                local rotate = math.floor(math.max(0, math.min(3, node_get_number_default(hullAnim:first_attribute("rotate"), 0))))
                if rotate%1 == 0 then
                    x = x + -anim.position.x
                    y = y + -anim.position.y
                else
                    x = x + -anim.position.y
                    y = y + -anim.position.x
                end
                
                local xscale = 1
                local yscale = 1
                if node_get_bool_default(hullAnim:first_attribute("xflip"), false) then xscale = -1 end
                if node_get_bool_default(hullAnim:first_attribute("yflip"), false) then yscale = -1 end
                
                table.insert(hullAnimSet, {anim = anim, x = x, y = y, rotate = rotate, xscale = xscale, yscale = yscale})
            end
        end
        doc:clear()
    end
    
    -- Update all active hull anims
    for i, hullAnim in ipairs(hullAnimSet) do
        hullAnim.anim:Update()
    end
end)

-- Render all active hull anims
script.on_render_event(Defines.RenderEvents.SHIP_ENGINES, function() end, function(ship, enginesVisible, alpha)
    local hullAnimSet = hullAnims[ship.iShipId]
    if #hullAnimSet > 0 and hullAnimSet["layout"] == Hyperspace.ships(ship.iShipId).myBlueprint.layoutFile then
        local shipGraph = Hyperspace.ShipGraph.GetShipInfo(ship.iShipId)
        local x = ship.shipImage.x + shipGraph.shipBox.x
        local y = ship.shipImage.y + shipGraph.shipBox.y
        for i, hullAnim in ipairs(hullAnimSet) do
            Graphics.CSurface.GL_PushMatrix()
            Graphics.CSurface.GL_Translate(x + hullAnim.x, y + hullAnim.y)
            Graphics.CSurface.GL_Rotate(90*hullAnim.rotate, 0, 0)
            Graphics.CSurface.GL_Scale(hullAnim.xscale, hullAnim.yscale, 1)
            hullAnim.anim:OnRender(1, Graphics.GL_Color(1, 1, 1, alpha), false)
            Graphics.CSurface.GL_PopMatrix()
        end
    end
end)
