class "HVTTeamManager"

function HVTTeamManager:__init(p_Engine)
    -- Reference to the main engine
    self.m_Engine = p_Engine

    -- These should be changable if needed
    self.m_DefenceTeam = TeamId.Team1
    self.m_AttackTeam = TeamId.Team2

    -- The squad that has been selected as HVT for this game mode
    self.m_SelectedHVTSquadId = TeamId.SquadNone
    self.m_SelectedHVTPlayerId = -1

    -- Configurable options
    
end

function HVTTeamManager:__gc()
    -- TODO: Cleanup anything that needs to be
end

function HVTTeamManager:OnPlayerLeft(p_Player)
    -- Validate player
    if p_Player == nil then
        return
    end
    
    -- Get the player id
    local s_LeavingPlayerId = p_Player.id

    -- TODO: If the leaving player was the HVT, end the game
    if s_LeavingPlayerId == self.m_SelectedHVTPlayerId then
        -- TODO: Reset the game mode, give loss to the defense
        return
    end

    -- If the person that is leaving was in the same squad
    if p_Player.squadId == self.m_SelectedHVTSquadId then
        -- If the player was alive, allow a substitute to join the HVT squad
        if p_Player.alive then
            -- Find a victim player
            local s_VictimPlayerId = self:FindVictimToMoveToHVT()

            -- Make sure we have a valid player id
            if s_VictimPlayerId ~= -1 then                
                local s_VictimPlayer = PlayerManager:GetPlayerbyId(s_VictimPlayerId)
                if s_VictimPlayer ~= nil then

                    -- Assign the victim player to the new squad
                    s_VictimPlayer.squadId = self.m_SelectedHVTSquadId

                    -- Notify the player
                    ChatManager:Yell("Promoted to HVT Squad!", 0.5, s_VictimPlayer)
                    
                    -- Teleport the player to the HVT

                    -- Get the victim soldier
                    local s_Soldier = s_VictimPlayer.soldier

                    -- Validate the soldier
                    if s_Soldier ~= nil then
                        -- Get the hvt player
                        local s_HvtPlayer = PlayerManager:GetplayerById(self.m_SelectedHVTPlayerId)
                        
                        -- Validate hvt player
                        if s_HvtPlayer ~= nil then
                            -- Get the hvt soldier
                            local s_HvtSoldier = s_HvtPlayer.soldier

                            -- Validate the hvt soldier
                            if s_HvtSoldier ~= nil then
                                -- Get the HVT world transform
                                local s_Transform = s_HvtSoldier.worldTransform

                                -- Inform the player of the teleport
                                ChatManager:Yell("Teleported to HVT!", 0.5, s_VictimPlayer)
                                
                                -- Teleport our victim to the HVT
                                s_Soldier:SetPosition(s_Transform.trans)
                            end
                        end
                    end
                end
            end
        end
    end  

end

function HVTTeamManager:OnPlayerKilled(p_Player, p_Inflictor, p_Position, p_Weapon, p_IsRoadKill, p_IsHeadShot, p_WasVictimInReviveState, p_Info)
    if p_Player == nil then
        return
    end

    -- Check if the player killed was the HVT
    if p_Player.id == self.m_SelectedHVTPlayerId then
        -- Send notification to the losing team
        ChatManager:Yell("HVT has been killed, YOU LOSE!", self.m_DefenceTeam)
        
        -- Send notification to the winning team
        ChatManager:Yell("HVT has been executed, YOU WIN!", self.m_AttackTeam)
        
        if p_Inflictor ~= nil then
            -- Announce to the entire server
            ChatManager:SendMessage(p_Inflictor.name .. " executed the HVT with a " .. p_Weapon .. "!")
        end
    
        -- TODO: End the game
    end

    -- If someone on the defense dies, switch their team to the attackers
    if p_Player.teamId == self.m_DefenceTeam then
        -- Change the player team to attacker
        p_Player.teamId = self.m_AttackTeam

        -- Clear out previous squad assignment
        p_Player.squadId = SquadId.SquadNone

        -- Find a target squad
        local s_TargetSquad = self:FindOpenSquad(self.m_AttackTeam)
        
        -- If no open squad has been found, create new squad
        if s_TargetSquad == SquadId.SquadNone then
            p_Player:SetSquadLeader(true, false)
        else
            -- Otherwise we assign the target squad
            p_Player.squadId = s_TargetSquad
        end
    else
        -- If someone dies on the attacker team prevent them from respawning
        p_Player.isAllowedToSpawn = false
    end
end

function HVTTeamManager:OnPlayerCreated(p_Player)
end

--[[
    Returns the selected HVT squad

    Or if not selected SquadId.SquadNone
]]--
function HVTTeamManager:GetSelectedHVTSquadId()
    return self.m_SelectedHVTSquadId
end

function HVTTeamManager:GetSelectedHVTPlayerId()
    return self.m_SelectedHVTPlayerId
end

function HVTTeamManager:GetAttackTeam()
    return self.m_AttackTeam
end

function HVTTeamManager:GetDefenceTeam()
    return self.m_DefenceTeam
end

--[[
    Checks to see if there are enough players on each team to start the HVT game mode

    Returns true or false
]]--
function HVTTeamManager:HasEnoughPlayers()
    -- Get each of the teams player counts
    local s_DefencePlayerCount = TeamSquadManager:GetTeamPlayerCount(self.m_DefenceTeam)
    local s_AttackPlayerCount = TeamSquadManager:GetTeamPlayerCount(self.m_AttackTeam)

    -- Check that the defence has more players than the minimum
    if s_DefencePlayerCount < Options.HVT_MinTeamPlayerCount then
        return false
    end

    -- Check that the attack has more players than the minimum
    if s_AttackPlayerCount < Options.HVT_MinTeamPlayerCount then
        return false
    end

    -- All conditions check out OK
    return true
end

--[[
    Finds a full squad, if there are multiple randomly select between them

    p_AcceptPartial - If a full squad is not found, find a partially filled squad

    Returns SquadId, SquadId.SquadNone on no full squads found
]]--
function HVTTeamManager:FindFullSquad(p_TeamId, p_AcceptPartial)
    -- Validate our team id
    if p_TeamId <= TeamId.TeamNeutral or p_TeamId >= TeamId.TeamIdCount then
        return SquadId.SquadNone
    end

    -- Hold an array of all of the SquadId's that are filled, we want to prioritize them first
    local s_FullSquads = { }

    -- Fix the squads for the attackers
    for l_SquadId = SquadId.SquadNone, SquadId.SquadIdCount do
        local l_SquadMemberCount = TeamSquadManager:GetSquadPlayerCount(p_TeamId, l_SquadId)
        if l_SquadMemberCount == Options.HVT_SquadSize then
            table.insert(s_FullSquads, l_SquadId)
        elseif l_SquadMemberCount > 0 and p_AcceptPartial and l_SquadMemberCount < Options.HVT_SquadSize then
            table.insert(s_FullSquads, l_SquadId)
        end
    end

    -- If we found no suitable squads than return none
    if #s_FullSquads == 0 then
        return SquadId.SquadNone
    end

    -- Select at random one of the squad id's that we got
    local s_RandomSquadIndex = MathUtils:GetRandomInt(1, #s_FullSquads)

    -- Return that SquadId we got
    return s_FullSquads[s_RandomSquadIndex]
end

function HVTTeamManager:FindEmptySquad(p_TeamId)
    -- Validate our team id
    if p_TeamId <= TeamId.TeamNeutral or p_TeamId >= TeamId.TeamIdCount then
        return SquadId.SquadNone
    end

    -- Iterate through all squads finding a empty squad
    for l_SquadId = SquadId.SquadNone, SquadId.SquadIdCount do
        local l_SquadMemberCount = TeamSquadManager:GetSquadPlayerCount(p_TeamId, l_SquadId)
        if l_SquadMemberCount == 0 then
            return l_SquadId
        end
    end

    -- We didn't find any empty squads
    return SquadId.SquadNone
end

function HVTTeamManager:FindTeamForNewPlayer()
    -- Get the amount of defence people left
    local s_DefenceCount = PlayerManager:GetPlayersByTeam(self.m_DefenceTeam)
    
    -- If there is already 1 person, default to attacker team
    if s_DefenceCount > 1 then
        return self.m_AttackTeam
    else
        return self.m_DefenceTeam
    end
end

--[[
    Finds the first open squad

    p_TeamId - TeamId of the team to check

    Returns SquadId, or SquadId.SquadNone if no open squads are found
]]--
function HVTTeamManager:FindOpenSquad(p_TeamId)
    -- Validate the team id
    if p_TeamId <= TeamId.TeamNeutral or p_TeamId >= TeamId.TeamIdCount then
        return SquadId.SquadNone
    end

    -- Return the first squad that satisfies the condition of not full and not empty
    for l_SquadId = SquadId.SquadNone, SquadId.SquadIdCount do
        local l_SquadMemberCount = TeamSquadManager:GetSquadPlayerCount(p_TeamId, l_SquadId)
        if l_SquadMemberCount > 0 and l_SquadMemberCount < Options.HVT_SquadSize then
            return l_SquadId
        end
    end

    return SquadId.SquadNone
end

--[[
    Forces all players not in a squad into a squad
]]--
function HVTTeamManager:ForceLoneWolvesIntoSquads()
    -- Iterate through all of the players
    local s_Players = PlayerManager:GetPlayers()
    for l_Index, l_Player in ipairs(s_Players) do
        -- Validate the player
        if l_Player == nil then
            goto __force_lone_wolves_cont__
        end

        -- If the player is not in a squad force it
        if l_Player.squadId == SquadId.SquadNone then
            local l_TargetSquadId = self:FindOpenSquad(l_Player.teamId)
            
            -- If an open squad was not found, create a new squad for this player
            if l_TargetSquadId == SquadId.SquadNone then
                l_Player.squadId = l_TargetSquadId
                l_Player:SetSquadLeader(true, false)
            else
                -- Change the players squad id
                l_Player.squadId = l_TargetSquadId
            end
        end

        ::__force_lone_wolves_cont__::
    end
end

--[[
    This sets up the HVT teams

    This will go through and find a full squad to select from if there is one
    if not it will look for a partial squad.

    If neither of these conditions are met, then something was screwed up.
    Were all players forced into squads before hand?
    Are there more than 1 player per team?

    These are assumptions that should not be broken
]]
function HVTTeamManager:SetupHVT()
    -- Reset these since there's nothing found
    self.m_SelectedHVTSquadId = SquadId.SquadNone
    self.m_SelectedHVTPlayerId = -1

    -- Attempt to find a full squad
    local s_SquadId = self:FindFullSquad(self.m_DefenceTeam, false)

    -- If a full squad is not found, attempt to find a partial squad
    if s_SquadId == SquadId.SquadNone then
        if self.m_Debug then
            print("could not find a full squad, looking for partial squad.")
        end

        s_SquadId = self:FindFullSquad(self.m_DefenceTeam, true)
    end

    -- If no squads are found this should not happen, but bail out for now
    if s_SquadId == SquadId.SquadNone then
        if self.m_Debug then
            print("Could not find any suitable squad on the defense for HVT. bug?")
        end

        return
    end

    -- Get all of the players in the selected squad
    local s_Players = PlayerManager:GetPlayersBySquad(self.m_DefenceTeam, s_SquadId)
    
    -- Randomly select one of the players inside of the squad to be the HVT
    local s_PlayerIndex = MathUtils:GetRandomInt(1, #s_Players)

    -- Get the player
    local s_Player = s_Players[s_PlayerIndex]

    -- Validate the player
    if s_Player == nil then
        if self.m_Debug then
            print("could not get a valid player.")
        end

        return
    end

    -- Get the player id
    local s_PlayerId = s_Player.id

    -- Debug logging
    if self.m_Debug then
        print("found player (" .. s_Player.name .. " : " .. s_PlayerId .. ") to be the HVT.")
    end

    -- Set our selected hvt squad id and player id
    self.m_SelectedHVTSquadId = s_SquadId
    self.m_SelectedHVTPlayerId = s_PlayerId

    -- Give all players the ability to spawn again
    local s_AllPlayers = PlayerManager:GetPlayers()
    for _, l_Player in ipairs(s_AllPlayers) do
        -- Validate player
        if l_Player == nil then
            goto __setup_hvt_enable_spawn__
        end

        l_Player.isAllowedToSpawn = true

        ::__setup_hvt_enable_spawn__::
    end

    ChatManager:SendMessage(s_Player.name .. " is the HVT!")
end

--[[
    Finds a player to move to the HVT squad

    This ensures that only people from defense are picked
    Then finds a lone-wolf, if none is found then
    try and find a half-filled squad, if none is found
    then return -1

    Returns player id, or -1 on no player found
]]--
function HVTTeamManager:FindVictimToMoveToHVT()
    -- First see if there's anyone on the defense team not in a squad
    local s_TeamPlayers = PlayerManager:GetPlayersByTeam(self.m_DefenceTeam)
    for l_Index, l_Player in ipairs(s_TeamPlayers) do
        if l_Player == nil then
            goto __find_victim_to_hvt_no_squad__
        end

        -- Make sure the player is currently alive
        if not l_Player.alive then
            goto __find_victim_to_hvt_no_squad__
        end

        -- If there is a player with no squad then force them to move to not
        -- break up existing squads
        if l_Player.squadId == SquadId.SquadNone then
            return l_Player.id
        end

        ::__find_victim_to_hvt_no_squad__::
    end

    -- Find a half-filled squad
    local s_VictimSquad = self:FindOpenSquad(self.m_DefenceTeam)
    if s_VictimSquad == SquadId.SquadNone then
        return -1
    end

    -- Get all players in the squad
    local s_SquadPlayers = PlayerManager:GetPlayersBySquad(self.m_DefenceTeam, s_VictimSquad)
    if #s_SquadPlayers == 0 then
        return -1
    end

    local s_VictimPlayerId = -1

    -- Yoink the first alive player
    for l_Index, l_Player in ipairs(s_SquadPlayers) do
        -- Validate player
        if l_Player == nil then
            goto __find_victim_to_hvt_alive_player__
        end

        -- Check if the player is alive
        if not l_Player.alive then
            goto __find_victim_to_hvt_alive_player__
        end

        -- return the player id
        s_VictimPlayerId = l_Player.id
        break

        ::__find_victim_to_hvt_alive_player__::
    end

    return s_VictimPlayerId
end

function HVTTeamManager:Balance()
    -- We are starting with players from all different squads/team arrangements

    -- Start with the player count, if we can split down the middle it's easiest, otherwise we give the attackers +1

    -- First we will iterate all players and kill them if they are alive, and disable the ability to spawn
    local s_Players = PlayerManager:GetPlayers()
    for l_Index, l_Player in ipairs(s_Players) do
        -- Validate the player
        if l_Player == nil then
            goto __smart_balance_kill_cont__
        end

        -- Disable players ability to spawn
        l_Player.isAllowedToSpawn = false

        -- If the player is already dead skip killing them
        if not l_Player.alive then
            goto __smart_balance_kill_cont__
        end

        -- Get the soldier
        local l_Soldier = l_Player.soldier
        if l_Soldier == nil then
            goto __smart_balance_kill_cont__
        end

        -- Kill the soldier
        l_Soldier:Kill()

        ::__smart_balance_kill_cont__::
    end

    local s_PlayerCount = #s_Players
    if s_PlayerCount < 2 then
        if self.m_Debug then
            print("not enough players to start.")
        end
        return
    end

    local s_StopCount = #s_Players / 2

    -- Randomize teams
    for l_Index, l_Player in ipairs(s_Players) do
        if l_Player == nil then
            goto __smart_balance_randomize_cont__
        end

        if l_Index < s_StopCount then
            l_Player.teamId = self.m_AttackTeam
        else
            l_Player.teamId = self.m_DefenceTeam
        end
        
        ::__smart_balance_randomize_cont__::
    end

    -- Assign squads for attackers
    local s_AttackPlayers = PlayerManager:GetPlayersByTeam(self.m_AttackTeam)
    local s_CurrentSquadCount = 0
    local s_CurrentSquad = SquadId.Squad1

    for _, l_Player in pairs(s_AttackPlayers) do
        if l_Player == nil then
            goto __smart_balance_squad_cont__
        end

        l_Player.squadId = s_CurrentSquad

        -- If this is the first person in the squad, set leader
        if s_CurrentSquadCount == 0 then
            l_Player:SetSquadLeader(true, false)
        end

        s_CurrentSquadCount = s_CurrentSquadCount + 1

        if s_CurrentSquadCount >= Options.HVT_SquadSize then
            s_CurrentSquadCount = 0
            s_CurrentSquad = s_CurrentSquad + 1
        end
        ::__smart_balance_squad_cont__::
    end

    -- Assign squads for defence
    local s_DefencePlayers = PlayerManager:GetPlayersByTeam(self.m_DefenceTeam)
    s_CurrentSquadCount = 0
    s_CurrentSquad = SquadId.Squad1

    for _, l_Player in pairs(s_DefencePlayers) do
        if l_Player == nil then
            goto __smart_balance_squad_def_cont__
        end

        -- Update the players squad id
        l_Player.squadId = s_CurrentSquad

        -- If this is the first person in the squad, set leader
        if s_CurrentSquadCount == 0 then
            l_Player:SetSquadLeader(true, false)
        end

        -- Increase to the next squad
        s_CurrentSquadCount = s_CurrentSquadCount + 1

        --
        if s_CurrentSquadCount >= Options.HVT_SquadSize then
            s_CurrentSquadCount = 0
            s_CurrentSquad = s_CurrentSquad + 1
        end

        ::__smart_balance_squad_def_cont__::
    end
end

return HVTTeamManager
