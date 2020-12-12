class "HVTServer"

local HVTEngine = require("Engine")

function HVTServer:__init()
    -- Create a new instance of our HVT Engine
    self.m_Engine = HVTEngine()
end

function HVTServer:__gc()
    -- TODO: Do any cleanup we may need
end

local g_HVTServer = HVTServer()