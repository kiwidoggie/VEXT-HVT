--[[
    HVTEngine

    High Value Target game mode engine class

    All of the functionality of the HVT game mode should run through this engine class

    This ensures proper execution and also tracking of the gamestate

    Created On: December 12, 2020

    12/12/2020 (kiwidog): Initial Creation
]]--

class "HVTEngine"

-- Include shared objects
require ("__shared/GameStates")
require ("__shared/Options")

-- Include our team manager class
local HVTTeamManager = require("TeamManager")

--[[
    Initializes the HVT Engine
]]--
function HVTEngine:__init()
    -- Events
    self.m_PlayerLeftEvent = Events:Subscribe("Player:Left", self, self.OnPlayerLeft)
    self.m_PlayerKilledEvent = Events:Subscribe("Player:Killed", self, self.OnPlayerKilled)
    self.m_PlayerCreatedEvent = Events:Subscribe("Player:Created", self, self.OnPlayerCreated)
    self.m_UpdateEvent = Events:Subscribe("Engine:Update", self, self.OnEngineUpdate)
    self.m_PlayerChatEvent = Events:Subscribe("Player:Chat", self, self.OnPlayerChat)

    -- Hooks
    self.m_OnSoldierDamageHook = Hooks:Install("Soldier:Damage", 1, self, self.OnSoldierDamage)
    
    -- Team management
    self.m_TeamManager = HVTTeamManager()

    -- Game state
    self.m_GameState = GameStates.GS_None
    self.m_GameStateTick = 0.0
    self.m_GameStateMaxTick = Options.Server_GameStateUpdateMaxTime

    -- Warmup update timers
    self.m_WarmupUpdateTick = 0.0
    self.m_WarmupUpdateTickMax = Options.Server_GameStateUpdateMaxTime

    -- Warmup delay timers
    self.m_WarmupDelayTick= 0.0
    self.m_WarmupDelayTickMax = Options.HVT_MaxWarmupTime
    
    -- Hvt Update Timers
    self.m_HvtUpdateTick = 0.0
    self.m_HvtUpdateTickMax = Options.Server_HvtUpdateMaxTime

    -- Running update timers
    self.m_RunningUpdateTick = 0.0
    self.m_RunningUpdateTickMax = Options.HVT_MaxRunTime

    -- Game over update timers
    self.m_GameOverTick = 0.0
    self.m_GameOverTickMax = Options.HVT_MaxGameOverTime

    -- Enable debug logging which will slow down shit
    self.m_Debug = true
end
--[[
    This is called when the HVTEngine is being garbage collected

    We need to make sure that we...

    Unsubscribe from all events
    Unregister from all hooks
    Cleanup any custom data modifications made to non-cloned objects
]]--
function HVTEngine:__gc()
    -- Unsubscribe from all events
    self.m_PlayerLeftEvent:Unsubscribe()
    self.m_PlayerKilledEvent:Unsubscribe()
    self.m_PlayerCreatedEvent:Unsubscribe()
    self.m_UpdateEvent:Unsubscribe()

    -- Uninstall all hooks
    self.m_OnSoldierDamageHook:Uninstall()

end

--[[
    Handles the player left event

    Updating engine components should be done in this order:

    1. Team management
    2. Round management
    3. Gamestate management
]]--
function HVTEngine:OnPlayerLeft(p_Player)
    -- Validate player
    if p_Player == nil then
        return
    end

    -- Send the event to the team manager
    self.m_TeamManager:OnPlayerLeft(p_Player)
end

--[[
    Handles the player killed event
]]-- 
function HVTEngine:OnPlayerKilled(p_Player, p_Inflictor, p_Position, p_Weapon, p_IsRoadKill, p_IsHeadShot, p_WasVictimInReviveState, p_Info)
    if p_Player == nil then
        return
    end

    if p_Inflictor == nil then
        return
    end

    -- Send the player killed event to the team manager
    self.m_TeamManager:OnPlayerKilled(p_Player, p_Inflictor, p_Position, p_Weapon, p_IsRoadKill, p_IsHeadShot, p_WasVictimInReviveState, p_Info)
end

--[[
    Handles when a new player is created (once per game?)

    TODO: Determine if the assumption that this is only fired once when the player joins the game holds true
]]--
function HVTEngine:OnPlayerCreated(p_Player)
    -- Validate player
    if p_Player == nil then
        return
    end

    self.m_TeamManager:OnPlayerCreated(p_Player)
end

function HVTEngine:OnEngineUpdate(p_DeltaTime, p_SimulationDeltaTime)
    -- HVT Update information to all clients
    self.m_HvtUpdateTick = self.m_HvtUpdateTick + p_DeltaTime
    if self.m_HvtUpdateTick >= self.m_HvtUpdateTickMax then
        self.m_HvtUpdateTick = 0.0

        -- Call the HVT Update to send the info to all players
        self:OnHvtUpdate()
    end

    -- Update all of the game state information
    self.m_GameStateTick = self.m_GameStateTick + p_DeltaTime
    if self.m_GameStateTick >= self.m_GameStateMaxTick then
        self.m_GameStateMaxTick = 0.0

        -- Call the game state update logic
        self:OnGameStateUpdate(p_DeltaTime)
    end
end

function HVTEngine:OnPlayerChat(p_Player, p_RecipientMask, p_Message)
    -- Enable overriding game state based on chat
    if self.m_Debug then
        if p_Message == "!warmup" then
            self:ChangeState(GameStates.GS_Warmup)
        end
    end

end

--[[
    Helper function which sends all clients the current hvt player id information

    This should only be called from a HVT update tick
]]-- 
function HVTEngine:OnHvtUpdate()
    -- Get the current selected HVT
    local s_HvtPlayerId = self.m_TeamManager:GetSelectedHVTPlayerId()

    -- Iterate througha ll of the players sending them an update
    local s_Players = PlayerManager:GetPlayers()
    for l_Index, l_Player in ipairs(s_Players) do
        if l_Player == nil then
            -- Debug logging
            if self.m_Debug then
                print("Could not update player at index (" .. l_Index .. ")")
            end

            goto __hvt_update_cont__
        end

        -- Send the HVT update event to the player
        NetEvents:SendTo("HVT:HvtInfoChanged", l_Player, s_HvtPlayerId)

        ::__hvt_update_cont__::
    end
end

function HVTEngine:OnGameStateUpdate(p_DeltaTime)
    if self.m_GameState == GameStates.GS_None then
        return
    elseif self.m_GameState == GameStates.GS_Warmup then
        self.m_WarmupUpdateTick = self.m_WarmupUpdateTick + p_DeltaTime
        if self.m_WarmupUpdateTick >= self.m_WarmupUpdateTickMax then
            -- TODO: Run the warmup game logic
            -- 1. Wait for correct amount of players
            -- 2. When the condition is met calculate who will be HVT
            -- and who will be in that squad
            -- 3. Force kill and respawn everyone, promoting the HVT to squad leader
            -- as well as swapping all of the character models for this squad
            -- giving the HVT the health boost
            if self.m_TeamManager:HasEnoughPlayers() then
                -- TODO: Select the HVT
                -- TODO: Select their squad
                -- TODO: Shift teams
                -- Kill all players
                -- Spawn everyone
            end
        end
    elseif self.m_GameState == GameStates.GS_Running then
        -- TODO: Implement running game state
        self.m_RunningUpdateTick = self.m_RunningUpdateTick + p_DeltaTime
        if self.m_RunningUpdateTick >= self.m_RunningUpdateTickMax then
            -- We have reached end of time, HVT wins

            -- Transfer over to the game over state
            self:ChangeState(GameStates.GS_GameOver)
        end

    elseif self.m_GameState == GameStates.GS_GameOver then
        -- TODO: Update the game over game state
        self.m_GameOverTick = self.m_GameOverTick + p_DeltaTime
        if self.m_GameOverTick >= self.m_GameOverTickMax then

            -- Transfer over to warmup game state
            self:ChangeState(GameStates.GS_Warmup)
        end
    end
end

--[[
    Hook for player damage

    We do things like disable damage in warmup here (similar to FN/COD)
]]-- 
function HVTEngine:OnSoldierDamage(p_Hook, p_Soldier, p_Info, p_GiverInfo)
    if p_Soldier == nil then
        return
    end

    if p_Info == nil then
        return
    end

    -- If we are in warmup disable damage
    if self.m_GameState == GameStates.GS_Warmup or self.m_GameState == GameStates.GS_None then
        if p_GiverInfo.giver == nil or p_GiverInfo.damageType == DamageType.Suicide then
            return
        end

        p_Info.damage = 0.0
        p_Hook:Pass(p_Soldier, p_Info, p_GiverInfo)
    end
end

function HVTEngine:StartNewGame()
end

function HVTEngine:UpdatePlayerGameState(p_Player)
    if p_Player == nil then
        print("Attempted to update invalid player's gamestate.")
        return
    end

    --[[

        We need to detemrine what game data we need to sync to the client every second

        1. HVT Location
        2. HVT Armor Level
        3. Current GameState
        4. Gift Cooldown Time
        5. Current Gift
        6. Defender Count
        7. Attacker Count
    ]]--
end

function HVTEngine:UpdatePlayerHVTInfo(p_Player)
    if p_Player == nil then
        return
    end

end

function HVTEngine:ChangeState(p_GameState)
    if p_GameState < GameStates.GS_None then
        return
    end

    if p_GameState > GameStates.GS_COUNT then
        return
    end

    -- Transfer over to warmup game state
    self.m_GameState = p_GameState

    -- Broadcast the game state change to all connected clients
    NetEvents:Broadcast("HVT:GameStateChanged", self.m_GameState)
    
end

return HVTEngine