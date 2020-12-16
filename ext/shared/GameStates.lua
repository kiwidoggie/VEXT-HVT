GameStates = {
    -- There is no game state logic running
    GS_None = 0,

    -- Warmup where we wait for the proper amount of players
    GS_Warmup = 1,

    -- Unused currently, we just jump from Warmup->Running once everything is set up
    GS_Selection = 2,

    -- The game is currently running, waiting for HVT to die or time to expire
    GS_Running = 3,

    -- This is just a buffer time before we re-enter the warmup state
    GS_GameOver = 4,

    -- Total count of game states
    GS_COUNT = 5,
}