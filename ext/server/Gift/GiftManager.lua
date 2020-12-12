class "HVTGiftManager"

function HVTGiftManager:__init()
    self.m_PlayerCooldowns = { }

    self.m_GiftCooldown = 10.0
end

function HVTGiftManager:__gc()
end

return HVTGiftManager