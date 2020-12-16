class "HVTServer"

require ("__shared/Options")

local HVTEngine = require("Engine")

function HVTServer:__init()
    -- Create a new instance of our HVT Engine
    self.m_Engine = HVTEngine()

    -- Register for level loaded to set the rcon variables
    self.m_LevelLoadedEvent = Events:Subscribe("Level:Loaded", self, self.OnLevelLoaded)
end

function HVTServer:__gc()
    -- TODO: Do any cleanup we may need
    self.m_LevelLoadedEvent:Unsubscribe()
end

--[[
    Callback for the level loaded event

    This is used so we can set all of the RCON variables for this game mode manually
    so we don't have to rely on an admin to do it
]]-- 
function HVTServer:OnLevelLoaded(p_LevelName, p_GameMode, p_Round, p_RoundsPerMap)
    print("Loading: " .. p_LevelName .. " GameMode: " .. p_GameMode)

    -- Set the rcon variables for this game type
    self:SetupVariables()
end

--[[
    Sets up the needed server configuration via rcon
]]--
function HVTServer:SetupVariables()
    -- Hold a dictionary of all of the variables we want to change
    local s_VariablePair = {
        ["vars.friendlyFire"] = "true",
        ["vars.soldierHealth"] = "100",
        ["vars.regenerateHealth"] = "false",
        ["vars.onlySquadLeaderSpawn"] = "true",
        ["vars.3dSpotting"] = "false",
        ["vars.miniMap"] = "false",
        ["vars.autoBalance"] = "false",
        ["vars.teamKillCountForKick"] = "20",
        ["vars.teamKillValueForKick"] = "10",
        ["vars.teamKillValueIncrease"] = "1",
        ["vars.teamKillValueDecreasePerSecond"] = "1",
        ["vars.idleTimeout"] = "300",
        ["vars.3pCam"] = "false",
        ["vars.roundStartPlayerCount"] = "0",
        ["vars.roundRestartPlayerCount"] = "0",
        ["vars.hud"] = "false",
        ["vu.SquadSize"] = tostring(Options.HVT_SquadSize)
    }

    -- Iterate through all of the commands and set their values via rcon
    for l_Command, l_Value in pairs(s_VariablePair) do
        local s_Result = RCON:SendCommand(l_Command, { l_Value })

        if #s_Result >= 1 then
            if s_Result[1] ~= "OK" then
                print("command: " .. l_Command .. " returned: " .. s_Result[1])
            end
        end
    end

    print("RCON Variables Setup")
end

local g_HVTServer = HVTServer()