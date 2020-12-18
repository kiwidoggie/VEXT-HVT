Options = {
    -- Minimum players on each team required before the game starts
    HVT_MinTeamPlayerCount = 1,

    -- Maximum number of players in the HVT squad (including the HVT)
    HVT_MaxHVTSquadPlayerCount = 4,

    -- The starting health for all HVT squad members
    HVT_HVTSquadStartingHealth = 175.0,

    -- Maximum time to stay in the selection phase
    HVT_MaxSelectionTime = 10.0,

    -- Maximum time to stay in the running phase before giving the win to HVT
    HVT_MaxRunTime = 300.0,

    -- Maximum time to stay in the game over time
    HVT_MaxGameOverTime = 5.0,

    -- Maximum time to wait after all players are ready and the game starting
    HVT_MaxWarmupTime = 5.0,

    -- Squad size in the HVT game mode
    HVT_SquadSize = 5,

    -- Server update rates

    -- Max interval to send updates to players updates about hvt
    Server_HvtUpdateMaxTime = 2.25,

    -- Max interval to run the warmup update logic
    Server_WarmupUpdateMaxTime = 0.50,

    -- Time in seconds that the server runs it's gameplay logic
    Server_GameStateUpdateMaxTime = 0.25,
}