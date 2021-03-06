class "HVTClient"

require ("__shared/GameStates")

function HVTClient:__init()
    -- Client net-events
    self.m_GameStateChangedEvent = NetEvents:Subscribe("HVT:GameStateChanged", self, self.OnGameStateChanged)
    self.m_HvtInfoChangedEvent = NetEvents:Subscribe("HVT:HvtInfoChanged", self, self.OnHvtInfoChanged)
    
    -- Client events
    self.m_UiDrawHudEvent = Events:Subscribe("UI:DrawHud", self, self.OnUiDrawHud)

    -- Server authoratative HVT information
    self.m_HvtHealth = 0.0
    self.m_HvtArmor = 0.0
    self.m_HvtLastPosition = Vec3(0, 0, 0)
    self.m_HvtPlayerId = -1

    -- Server authoratative game state
    self.m_GameState = GameStates.GS_None

    -- Debug information
    self.m_Debug = false
end

function HVTClient:__gc()
    -- Clean up our net-events
    self.m_GameStateChangedEvent:Unsubscribe()
    self.m_HvtInfoChangedEvent:Unsubscribe()

    -- Clean up our events
    self.m_UiDrawHudEvent:Unsubscribe()
end

--[[
    NetEvent callback for when the game state changes
]]--
function HVTClient:OnGameStateChanged(p_GameState)
    if self.m_Debug then
        print("Game State changed to: " .. p_GameState)
    end

    -- Update our game state
    self.m_GameState = p_GameState
end

--[[
    NetEvent callback from the server to update the HVT information
]]--
function HVTClient:OnHvtInfoChanged(p_PlayerId, p_PlayerHealth)
    -- Debug information
    if self.m_Debug then
        print("OnHvtInfoChanged PlayerId: " .. p_PlayerId)
    end

    -- This may be sent if there's no game going on, this means ignore
    if p_PlayerId == -1 then
        self.m_HvtHealth = 0.0
        self.m_HvtArmor = 0.0
        self.m_HvtLastPosition = Vec3(0, 0, 0)
        self.m_HvtPlayerId = -1
        return
    end

    -- Attempt to get the HVT player by ID
    local s_Player = PlayerManager:GetPlayerById(p_PlayerId)
    if s_Player == nil then
        if self.m_Debug then
            print("Could not get player info for player id: " .. p_PlayerId)
        end

        -- Bail out
        return
    end

    -- Get the players name
    local s_PlayerName = s_Player.name

    -- Check if the HVT is alive
    if not s_Player.alive then
        print("HVT (" .. s_PlayerName .. ") is already dead, why are we getting an update?")
        return
    end

    -- Get the players soldier
    local s_Soldier = s_Player.soldier
    if s_Soldier == nil then
        -- Debug print
        if self.m_Debug then
            print("Could not get soldier for (" .. s_PlayerName .. ") player id: " .. p_PlayerId)
        end

        -- Stop execution
        return
    end

    -- Get the HVT player information
    local s_Transform = s_Soldier.worldTransform
    local s_Health = s_Soldier.health
    local s_Armor = 0.0

    -- Armor is calculated based on how much over 100.0 health they have
    if s_Health > 100.0 then
        s_Armor = s_Health - 100.0
    end

    -- Update our variable for other stuff to use it
    self.m_HvtHealth = s_Health
    self.m_HvtArmor = s_Armor
    self.m_HvtLastPosition = s_Transform.trans
    self.m_HvtPlayerId = p_PlayerId
end

--[[
    Callback for the ui draw event

    This is where we put all of our drawing logic about the HVT
]]--
function HVTClient:OnUiDrawHud()
    -- Draw some debugging information
    local s_DebugColor = Vec4(0, 1, 0, 1)

    if self.m_Debug then
        DebugRenderer:DrawText2D(10, 10, "GameState: " .. self.m_GameState, s_DebugColor, 1.0)
        DebugRenderer:DrawText2D(10, 20, "HVT: " .. self.m_HvtPlayerId .. " Armor: " .. self.m_HvtArmor, s_DebugColor, 1.0)
        DebugRenderer:DrawText2D(10, 30, "Pos: " .. self.m_HvtLastPosition.x .. ", " .. self.m_HvtLastPosition.y .. ", " .. self.m_HvtLastPosition.z, s_DebugColor, 1.0)
    end
    
    -- Check to make sure we have a valid player id
    if self.m_HvtPlayerId < 0 then
        return
    end

    -- Get the local player
    local s_LocalPlayer = PlayerManager:GetLocalPlayer()
    if s_LocalPlayer ~= nil then
        -- Check to see if the local player is the HVT
        if self.m_HvtPlayerId == s_LocalPlayer.id then
            -- We do not want to draw the label for the player who is the HVT
            return
        end
    end

    -- Calculate the colors
    local s_Green = (self.m_HvtArmor / 100.0)
    local s_Red = 1.0 - s_Green
    if s_Red < 0.0 then
        s_Red = 0.0
    end
    local s_Color = Vec4(s_Red, s_Green, 0.0, 0.65)

    -- Get the screen position based on the last hvt position
    local s_ScreenPosition = ClientUtils:WorldToScreen(self.m_HvtLastPosition)

    -- CHeck to see if the screen position that we got back is valid
    if s_ScreenPosition == nil then
        return
    end

    -- Draw our always visible text
    DebugRenderer:DrawText2D(s_ScreenPosition.x, s_ScreenPosition.y, "HVT", s_Color, 0.90)
    --DebugRenderer:DrawText2D(s_ScreenPosition.x, s_ScreenPosition.y, "HVT", s_Color, 0.90)

end

local g_HVTClient = HVTClient()