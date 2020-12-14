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
require ("__shared/EndGameReason")

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
    self.m_OnPlayerSelectTeamHook = Hooks:Install("Player:SelectTeam", 1, self, self.OnPlayerSelectTeam)
    self.m_OnPlayerFindBestSquad = Hooks:Install("Player:FindBestSquad", 1, self, self.OnPlayerFindBestSquad)

    -- Team management
    self.m_TeamManager = HVTTeamManager(self)

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
    self.m_PlayerChatEvent:Unsubscribe()

    -- Uninstall all hooks
    self.m_OnSoldierDamageHook:Uninstall()
    self.m_OnPlayerFindBestSquad:Uninstall()
    self.m_OnPlayerSelectTeamHook:Uninstall()
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
            self.m_WarmupUpdateTick = 0.0

            -- TODO: Run the warmup game logic
            -- 1. Wait for correct amount of players
            -- 2. When the condition is met calculate who will be HVT
            -- and who will be in that squad
            -- 3. Force kill and respawn everyone, promoting the HVT to squad leader
            -- as well as swapping all of the character models for this squad
            -- giving the HVT the health boost
            if self.m_TeamManager:HasEnoughPlayers() then

                -- Force all lone wolves into a squad
                self.m_TeamManager:ForceLoneWolvesIntoSquads()

                -- Fix the teams and squads
                self.m_TeamManager:Balance()

                -- Select the HVT
                self.m_TeamManager:SetupHVT()


                -- Kill all players
                -- NOTE: I don't think below is needed because all players are killed/spawning disabled in TeamManager:Balance()
                --[[
                    local s_Players = PlayerManager:GetPlayers()
                for _, l_Player in ipairs(s_Players) do
                    if l_Player == nil then
                        goto __kill_everyone_cont__
                    end

                    if not l_Player.alive then
                        goto __kill_everyone_cont__
                    end

                    local l_Soldier = l_Player.soldier
                    if l_Soldier == nil then
                        goto __kill_everyone_cont__
                    end

                    l_Soldier:Kill()
                    ::__kill_everyone_cont__::
                end
                ]]--


                -- Spawn everyone

                -- Update the gamestate
                self:ChangeState(GameStates.GS_Running)
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
        -- If this is the first tick of gameover, send the stats to users
        if self.m_GameOverTick == 0.0 then
            ChatManager:Yell("Game Over")
        end

        -- Update the game over game state, this just waits a period of time before swithcing back to warmup
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

--[[
    Finds the best new team for a player
]]
function HVTEngine:OnPlayerSelectTeam(p_Hook, p_Player, p_Team)
    p_Team = self.m_TeamManager:FindTeamForNewPlayer()
    if self.m_Debug then
        print("player (" .. p_Player.name .. ") assigned to team: " .. p_Team)
    end
end

--[[
    Finds the best squad for a player
]]--
function HVTEngine:OnPlayerFindBestSquad(p_Hook, p_Player)
    local s_SquadId = self.m_TeamManager:FindOpenSquad(p_Player.teamId)
    if s_SquadId == SquadId.SquadNone then
        s_SquadId = self.m_TeamManager:FindEmptySquad(p_Player.teamId)
    end

    return s_SquadId
end

function HVTEngine:ChangeState(p_GameState)
    if p_GameState < GameStates.GS_None then
        return
    end

    if p_GameState > GameStates.GS_COUNT then
        return
    end

    if self.m_Debug then
        print("Transition from GS: " .. self.m_GameState .. " to " .. p_GameState)
    end

    -- Transfer over to warmup game state
    self.m_GameState = p_GameState

    -- Broadcast the game state change to all connected clients
    NetEvents:Broadcast("HVT:GameStateChanged", self.m_GameState)
end

--[[
    Handle ending the game for whatever reason
]]--
function HVTEngine:EndGame(p_EndGameReason, p_HvtPlayerId)
    -- Validate the end game reason
    if p_EndGameReason < EndGameReason.EGR_None or p_EndGameReason >= EndGameReason.EGR_COUNT then
        if self.m_Debug then
            print("invalid end game reason.")
        end

        return
    end

    -- If there isn't a valid hvt player then just return back to warmup
    if p_HvtPlayerId == -1 then
        if self.m_Debug then
            print("end game called with invalid hvt player id.")
        end

        self:ChangeState(GameStates.GS_Warmup)
        return
    end

    -- Get the HVT player
    local s_HvtPlayer = PlayerManager:GetPlayerById(p_HvtPlayerId)

    -- Validate the HVT player
    if s_HvtPlayer == nil then
        if self.m_Debug then
            print("Could not get the provided hvt player by id.")
        end

        self:ChangeState(GameStates.GS_Warmup)
        return
    end
    
    -- This was admin or mod aborted, just reset everything back to normal
    if p_EndGameReason == EndGameReason.EGR_None then
        ChatManager:SendMessage("End Game Abort called.")
    elseif p_EndGameReason == EndGameReason.EGR_HVTSurvived then
        ChatManager:Yell("YOU WIN! " .. s_HvtPlayer.name .. " survived with " .. tostring(s_HvtPlayer.kills) .. " kills!", 2.0, self.m_TeamManager:GetDefenceTeam())
        ChatManager:Yell("YOU LOSE! " .. s_HvtPlayer.name .. " survived with " .. tostring(s_HvtPlayer.kills) .. " kills!", 2.0, self.m_TeamManager:GetAttackTeam())
    elseif p_EndGameReason == EndGameReason.EGR_HVTKilled then
        ChatManager:Yell("YOU WIN! " .. s_HvtPlayer.name .. " survived with " .. tostring(s_HvtPlayer.kills) .. " kills!", 2.0, self.m_TeamManager:GetAttackTeam())
        ChatManager:Yell("YOU LOSE! " .. s_HvtPlayer.name .. " survived with " .. tostring(s_HvtPlayer.kills) .. " kills!", 2.0, self.m_TeamManager:GetDefenceTeam())
    end

    -- Prepare the gameover to re-transition into the warmup
    self:ChangeState(GameStates.GS_Warmup)
end

return HVTEngine