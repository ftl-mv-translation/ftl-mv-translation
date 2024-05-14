--[[
////////////////////
XML PARSING HELPERS
////////////////////
]]--

-- Iterator for children of an xml node
do
    local function nodeIter(parent, child)
        if child == "Start" then return parent:first_node() end
        return child:next_sibling()
    end
    mods.multiverse.node_child_iter = function(parent)
        if not parent then error("Invalid node to node_child_iter iterator!", 2) end
        return nodeIter, parent, "Start"
    end
end
local node_child_iter = mods.multiverse.node_child_iter

-- Same parsing for xml bools as FTL uses
function mods.multiverse.parse_xml_bool(s)
    return s == "true" or s == "True" or s == "TRUE"
end
local parse_xml_bool = mods.multiverse.parse_xml_bool

-- Try to get the boolean value of a node, return a default value on failure
function mods.multiverse.node_get_bool_default(node, default)
    if not node then return default end
    local ret = node:value()
    if not ret then return default end
    return parse_xml_bool(ret)
end
local node_get_bool_default = mods.multiverse.node_get_bool_default

-- Try to get the number value of a node, return a default value on failure
function mods.multiverse.node_get_number_default(node, default)
    if not node then return default end
    local ret = tonumber(node:value())
    if not ret then return default end
    return ret
end
local node_get_number_default = mods.multiverse.node_get_number_default

--[[
////////////////////
OTHER HELPER FUNCS
////////////////////
]]--

local string_replace = mods.multiverse.string_replace
local table_to_list_string = mods.multiverse.table_to_list_string

-- Table to convert damage XML into code and desc string
local damageNameLookup = {
    damage = {
        name = "iDamage",
        text = "stat_damage_normal"
    },
    sp = {
        name = "iShieldPiercing",
        text = "stat_damage_sp"
    },
    fireChance = {
        name = "fireChance",
        text = "stat_damage_fire",
        toStrFunc = function(value)
            return tostring(math.floor(10*value)).."%"
        end
    },
    breachChance = {
        name = "breachChance",
        text = "stat_damage_breach",
        toStrFunc = function(value)
            return tostring(math.floor(10*value)).."%"
        end
    },
    stunChance = {
        name = "stunChance",
        text = "stat_damage_stun_chance",
        toStrFunc = function(value)
            return tostring(math.floor(10*value)).."%"
        end
    },
    ion = {
        name = "iIonDamage",
        text = "stat_damage_ion"
    },
    sysDamage = {
        name = "iSystemDamage",
        text = "stat_damage_sys"
    },
    persDamage = {
        name = "iPersDamage",
        text = "stat_damage_pers",
        toStrFunc = function(value)
            return math.floor(15*value)
        end
    },
    stun = {
        name = "iStun",
        text = "stat_damage_stun"
    },
    hullBust = {
        name = "bHullBuster",
        text = "stat_damage_hullbust"
    },
    lockdown = {
        name = "bLockdown",
        text = "stat_damage_lockdown"
    }
}

-- Construct a Hyperspace.Damage instance using the children of a node
function mods.multiverse.parse_damage_from_children(node)
    local damage = Hyperspace.Damage()
    for damageType in node_child_iter(node) do
        local damageName = damageType:name()
        damageName = damageNameLookup[damageName] and damageNameLookup[damageName].name
        local damageValue = damageType:value()
        if damageName and damageValue then
            damage[damageName] = tonumber(damageValue) or parse_xml_bool(damageValue)
        end
    end
    return damage
end

-- Convert a Hyperspace.Damage instance instance to a string
do
    local function sort_stats(a, b)
        if string.byte(a) > 57 and string.byte(b) <= 57 then return false end
        if string.byte(b) > 57 and string.byte(a) <= 57 then return true end
        if #a == #b then
            return string.byte(a) < string.byte(b)
        end
        return #a < #b
    end
    mods.multiverse.damage_to_string = function(damage)
        local stringTbl = {}
        for _, stat in pairs(damageNameLookup) do
            local value = damage[stat.name]
            if type(value) == "boolean" then
                if value then table.insert(stringTbl, Hyperspace.Text:GetText(stat.text)) end
            else
                if value > 0 then
                    value = stat.toStrFunc and stat.toStrFunc(value) or tostring(math.floor(value))
                    local txt = string_replace(Hyperspace.Text:GetText(stat.text), "\\1", value)
                    table.insert(stringTbl, txt)
                end
            end
        end
        table.sort(stringTbl, sort_stats)
        return table_to_list_string(stringTbl)
    end
end

--[[
////////////////////
WEAPON AND DRONE TAGS
////////////////////
]]--

-- Create tables of parsers to process custom tags
mods.multiverse.weaponTagParsers = {}
mods.multiverse.droneTagParsers = {}
