class "HVTTeamManager"

function HVTTeamManager:__init()
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

    -- TODO: If the leaving player was a HVT Squad Member
    -- determine if another player is alive + not in the squad and move them to the squad
    -- player should be notified and teleported to the HVT

    -- TODO: If the leaving player was the HVT, end the game

end

function HVTTeamManager:OnPlayerKilled(p_Player, p_Inflictor, p_Position, p_Weapon, p_IsRoadKill, p_IsHeadShot, p_WasVictimInReviveState, p_Info)
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

return HVTTeamManager
