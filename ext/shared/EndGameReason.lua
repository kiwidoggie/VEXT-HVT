EndGameReason = {
    -- This is only used when an admin ends the game, or it's done via code
    EGR_None = 0,
    
    -- The game ended because the HVT has died
    EGR_HVTKilled = 1,

    -- The game ended because the HVT survived the bounty
    EGR_HVTSurvived = 2,

    -- Total end game reason count
    EGR_COUNT = 3
}