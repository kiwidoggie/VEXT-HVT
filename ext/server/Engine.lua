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
require ("__shared/Utils")

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
    self.m_PartitionLoadedEvent = Events:Subscribe("Partition:Loaded", self, self.OnPartitionLoaded)

    -- Hooks
    self.m_OnSoldierDamageHook = Hooks:Install("Soldier:Damage", 1, self, self.OnSoldierDamage)
    self.m_OnPlayerSelectTeamHook = Hooks:Install("Player:SelectTeam", 1, self, self.OnPlayerSelectTeam)
    self.m_OnPlayerFindBestSquad = Hooks:Install("Player:FindBestSquad", 1, self, self.OnPlayerFindBestSquad)

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

    -- Team management
    self.m_TeamManager = HVTTeamManager(self)

    -- Spawn points
    self.m_SpawnPoints = { }

    -- MpSoldier
    self.m_MpSoldier = nil

    -- Unlocks
    self.m_Unlocks = { }
    self.m_AttackerVeniceSoldierCustomizations = { }
    self.m_DefenceVeniceSoldierCustomizations = { }
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
    -- Validate the player
    if p_Player == nil then
        return
    end

    -- Validate the inflictor that gave the damage
    if p_Inflictor == nil then
        return
    end

    -- Send the player killed event to the team manager
    self.m_TeamManager:OnPlayerKilled(p_Player, p_Inflictor, p_Position, p_Weapon, p_IsRoadKill, p_IsHeadShot, p_WasVictimInReviveState, p_Info)
end

--[[
    Handles when a new player is created (once per game?)

    TODO: Determine if the assumption that this is only fired once when the player joins the game holds true

    NOTE: This holds true for bots as well
]]--
function HVTEngine:OnPlayerCreated(p_Player)
    -- Validate player
    if p_Player == nil then
        return
    end

    -- Forward this event to the team manager
    self.m_TeamManager:OnPlayerCreated(p_Player)
end

--[[
    Event callback for the frostbite engine update

]]--
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

--[[
    Callback for when a player sends a chat message
]]--
function HVTEngine:OnPlayerChat(p_Player, p_RecipientMask, p_Message)
    -- Enable overriding game state based on chat
    if self.m_Debug then
        if p_Message == "!warmup" then
            self:ChangeState(GameStates.GS_Warmup)
        end
    end

end

function HVTEngine:ParseWorldPartData(p_WorldPartData)
    if p_WorldPartData == nil then
        return
    end

    -- Make sure we only have the TDM_Logic instance
    if not string.match(s_WorldPartData.name, "TDM_Logic") then
        return
    end

    -- Get the objects
    local s_WorldPartDataObjects = s_WorldPartData.objects

    -- Iterate through all of the WorldPartData objects
    for _, l_ObjectInstance in pairs(s_WorldPartDataObjects) do
        -- Ensure that we only get AlternateSpawnEntityData
        if l_ObjectInstance:Is("AlternateSpawnEntityData") then
            local s_AlternateSpawnEntityData = AlternateSpawnEntityData(l_ObjectInstance)

            -- Get the transform
            local s_Transform = s_AlternateSpawnEntityData.transform

            -- Add the LinearTransform to a list for later
            table.insert(self.m_SpawnPoints, s_Transform)

            if self.m_Debug then
                print("Found Spawn Point At: (" .. s_Transform.trans.x .. ", " .. s_Transform.trans.y .. ", " .. s_Transform.trans.z .. ")")
            end
        end
    end
end

function HVTEngine:ParseSoldierBlueprint(p_SoldierBlueprint)
    -- Validate the soldier blueprint
    if p_SoldierBlueprint == nil then
        return
    end

    -- Check the soldier blueprint name
    if p_SoldierBlueprint.name == "Characters/Soldiers/MpSoldier" then
        if self.m_Debug then
            print("MpSoldier Blueprint: " .. s_SoldierBlueprint.instanceGuid:ToString("N"))
        end

        -- Assign our mp soldier
        self.m_MpSoldier = p_SoldierBlueprint
    end
end

function HVTEngine:OnPartitionLoaded(p_Partition)
    -- Validate the partition
    if p_Partition == nil then
        return
    end

    -- Iterate all of instances
    local s_Instances = p_Partition.instances
    for _, l_Instance in pairs(s_Instances) do
        if l_Instance == nil then
            goto __instance_cont__
        end

        -- Check to make sure that the instance is a WorldPartData
        if l_Instance:Is("WorldPartData") then
            local s_WorldPartData = WorldPartData(l_Instance)
            
            self:ParseWorldPartData(s_WorldPartData)
        end

        -- Get the mp soldier blueprint
        if l_Instance:Is("SoldierBlueprint") then
            local s_SoldierBlueprint = SoldierBlueprint(l_Instance)

            self:ParseSoldierBlueprint(s_SoldierBlueprint)
        end

        -- Get the weapon unlocks
        if l_Instance:Is("SoldierWeaponUnlockAsset") then
            local s_WeaponUnlockAsset = SoldierWeaponUnlockAsset(l_Instance)

            if self.m_Debug then
                print("Unlock: " .. s_WeaponUnlockAsset.name)
            end

            table.insert(self.m_Unlocks, s_WeaponUnlockAsset)
        end

        -- Unlock assets for each team
        if l_Instance:Is("VeniceSoldierCustomizationAsset") then
            local s_CustomizationAsset = VeniceSoldierCustomizationAsset(l_Instance)

            -- Get the asset name
            local s_AssetName = s_CustomizationAsset.name

            -- Check to see which team this is from
            local s_IsUs = Utils.contains(s_AssetName, "/US")
            local s_IsRu = Utils.contains(s_AssetName, "/RU")

            if s_IsUs and s_IsRu then
                print("Unlock cannot be us and ru...")
            end

            if not s_IsUs and not s_IsRu then
                print("Unlock can not be neither US or RU.")
            end

            -- Add to the list
            if s_IsUs then
                table.insert(self.m_AttackerVeniceSoldierCustomizations, s_CustomizationAsset)
            elseif s_IsRu then
                table.insert(self.m_DefenceVeniceSoldierCustomizations, s_CustomizationAsset)
            end
        end
        

        ::__instance_cont__::
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

--[[
    This function gets called periodicaly in order to update the current HVT game state
    
    This will handle any of the "logic" of each of the game states
]]
function HVTEngine:OnGameStateUpdate(p_DeltaTime)
    if self.m_GameState == GameStates.GS_None then
        return
    elseif self.m_GameState == GameStates.GS_Warmup then
        self.m_WarmupUpdateTick = self.m_WarmupUpdateTick + p_DeltaTime
        if self.m_WarmupUpdateTick >= self.m_WarmupUpdateTickMax then
            self.m_WarmupUpdateTick = 0.0

            -- Run the warmup game logic
            -- 1. Wait for correct amount of players
            -- 2. When the condition is met calculate who will be HVT
            -- and who will be in that squad
            -- 3. Force kill and respawn everyone, promoting the HVT to squad leader
            -- as well as swapping all of the character models for this squad
            -- giving the HVT the health boost
            if self.m_TeamManager:HasEnoughPlayers() then
                -- Reset the team manager
                self.m_TeamManager:Reset()

                -- Force all lone wolves into a squad
                self.m_TeamManager:ForceLoneWolvesIntoSquads()

                -- Fix the teams and squads
                self.m_TeamManager:Balance()

                -- Select the HVT
                self.m_TeamManager:SetupHVT()

                -- TODO: Spawn everyone
                if #self.m_SpawnPoints == 0 then
                    print("there was an error, there are no spawn points.")
                end

                -- TODO: Give the HVT more health

                -- Get the HVT player ID
                local s_HvtPlayerId = self.m_TeamManager:GetSelectedHVTPlayerId()
                if s_HvtPlayerId == -1 then
                    print("there was an error getting the hvt.")
                    return
                end

                -- Get the HVT player
                local s_HvtPlayer = PlayerManager:GetPlayerById(s_HvtPlayerId)
                if s_HvtPlayer == nil then
                    print("there was an error getting the hvt player.")
                    return
                end

                -- Get the HVT soldier
                local s_HvtSoldier = s_HvtPlayer.soldier
                if s_HvtSoldier == nil then
                    print("could not increase the hvt health.")
                    return
                end

                -- Update the HVT health by +50, then again in the loop for the whole squad, this will give the HVT +75
                s_HvtSoldier.health = s_HvtSoldier.health + 50.0

                -- Give the HVT squad +25 health
                local s_SquadPlayers = PlayerManager:GetPlayersBySquad(self.m_TeamManager:GetDefenceTeam(), s_HvtPlayer.squadId)
                for _, l_SquadPlayer in pairs(s_SquadPlayers) do
                    if l_SquadPlayer == nil then
                        goto __squad_player_health_cont__
                    end

                    -- Get the squad soldier
                    local s_SquadSoldier = l_SquadPlayer.soldier
                    if s_SquadSoldier == nil then
                        goto __squad_player_health_cont__
                    end

                    -- Give soldiers a bump of health
                    s_SquadSoldier.health = s_SquadSoldier.health + 25.0
                    ::__squad_player_health_cont__::
                end

                -- Update the gamestate
                self:ChangeState(GameStates.GS_Running)
            end
        end
    elseif self.m_GameState == GameStates.GS_Running then
        -- Running game state
        self.m_RunningUpdateTick = self.m_RunningUpdateTick + p_DeltaTime
        if self.m_RunningUpdateTick >= self.m_RunningUpdateTickMax then
            self.m_RunningUpdateTick = 0.0

            -- We have reached end of time, HVT wins
            self:EndGame(EndGameReason.EGR_HVTSurvived, self.m_TeamManager:GetSelectedHVTPlayerId())
        end

        -- TODO: Check to see if all attacking players are dead, if they are end the game

    elseif self.m_GameState == GameStates.GS_GameOver then
        -- If this is the first tick of gameover, send the stats to users
        if self.m_GameOverTick == 0.0 then
            ChatManager:Yell("Game Over", 3.0)
        end

        -- Update the game over game state, this just waits a period of time before swithcing back to warmup
        self.m_GameOverTick = self.m_GameOverTick + p_DeltaTime
        if self.m_GameOverTick >= self.m_GameOverTickMax then
            self.m_GameOverTick = 0.0

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

--[[
    Helper function in order to change game states

    This will validate the destination game state as well as do some debug logging if enabled
]]--
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

        self:ChangeState(GameStates.GS_GameOver)
        return
    end

    -- Get the HVT player
    local s_HvtPlayer = PlayerManager:GetPlayerById(p_HvtPlayerId)

    -- Validate the HVT player
    if s_HvtPlayer == nil then
        if self.m_Debug then
            print("Could not get the provided hvt player by id.")
        end

        self:ChangeState(GameStates.GS_GameOver)
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

    -- Reset the team manager
    self.m_TeamManager:Reset()

    -- Prepare the gameover to re-transition into the warmup
    self:ChangeState(GameStates.GS_GameOver)
end

--[[
    Helper function to determine if the HVTEngine is running in debug mode or not

    Returns boolean, true if debug mode is enabled, false otherwise
]]
function HVTEngine:IsDebug()
    return self.m_Debug
end

return HVTEngine