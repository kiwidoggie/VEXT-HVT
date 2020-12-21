class "LoadoutManager"

function LoadoutManager:__init(p_Engine)

    -- Save engine reference
    self.m_Engine = p_Engine

    -- Unlocks (SoldierWeaponUnlockAsset)
    self.m_WeaponUnlocks = { }

    -- Customizations VeniceSoldierCustomizationAsset
    self.m_SoldierAssets = { }

    -- Appearance UnlockAsset
    self.m_AppearanceAssets = { }

    -- HVT Group and Appearance
    self.m_ApperanceNames = {
        "Persistence/Unlocks/Soldiers/Visual/MP/RU/MP_RU_Recon_Appearance_Green",
        "Persistence/Unlocks/Soldiers/Visual/MP/RU/MP_RU_Recon_Appearance_Para",
        "Persistence/Unlocks/Soldiers/Visual/MP/RU/MP_RU_Support_Appearance01",
        "Persistence/Unlocks/Soldiers/Visual/MP/US/MP_US_Engi_Appearance01"
    }
    
    self.m_HVTAppearanceName = "Persistence/Unlocks/Soldiers/Visual/MP/RU/MP_RU_Recon_Appearance_Green"
    self.m_HVTGroupAppearanceName = "Persistence/Unlocks/Soldiers/Visual/MP/RU/MP_RU_Recon_Appearance_Para"
    self.m_HVTSoldierName = "Gameplay/Kits/RURecon"

    -- Regular attacker appearance
    self.m_AttackAppearanceName = "Persistence/Unlocks/Soldiers/Visual/MP/RU/MP_RU_Support_Appearance01"
    self.m_AttackSoldierName = "Gameplay/Kits/RUSupport"

    -- Defence appearance
    self.m_DefenceAppearanceName = "Persistence/Unlocks/Soldiers/Visual/MP/US/MP_US_Engi_Appearance01"
    self.m_DefenceSoldierName = "Gameplay/Kits/USEngineer"    
end

function LoadoutManager:OnInstanceLoaded(p_Instance)
    -- Validate the instance
    if p_Instance == nil then
        return
    end

    -- Weapon unlocks
    if p_Instance:Is("SoldierWeaponUnlockAsset") then
        local s_SoldierWeaponUnlockAsset = SoldierWeaponUnlockAsset(p_Instance)

        if self.m_Engine:IsDebug() then
            print("Weapon Unlock: " .. s_SoldierWeaponUnlockAsset.name)
        end

        table.insert(self.m_WeaponUnlocks, s_SoldierWeaponUnlockAsset)
    end

    -- Customization unlocks
    if p_Instance:Is("VeniceSoldierCustomizationAsset") then
        local s_VeniceSoldierCustomizationAsset = VeniceSoldierCustomizationAsset(p_Instance)

        if self.m_Engine:IsDebug() then
            print("Customization: " .. s_VeniceSoldierCustomizationAsset.name)
        end

        table.insert(self.m_SoldierAssets, s_VeniceSoldierCustomizationAsset)
    end

    -- Appearance unlocks
    if p_Instance:Is("UnlockAsset") then
        local s_UnlockAsset = UnlockAsset(p_Instance)

        -- Iterate through all names that we want
        for _, l_Name in pairs(self.m_ApperanceNames) do

            -- Check to see if this unlock asset matches the name we want
            if l_Name == s_UnlockAsset.name then
                table.insert(self.m_AppearanceAssets, s_UnlockAsset)
                print("adding appearance: " .. s_UnlockAsset.name)
            end
        end
    end

end

function LoadoutManager:GetWeaponUnlockByName(p_Name)
    for _, l_Unlock in pairs(self.m_WeaponUnlocks) do
        if l_Unlock == nil then
            goto __loadout_get_unlock_by_name__
        end

        local s_UnlockName = l_Unlock.name
        if p_Name == s_UnlockName then
            return l_Unlock
        end

        ::__loadout_get_unlock_by_name__::
    end

    return nil
end

function LoadoutManager:GetCustomizationByName(p_Name)
    for _, l_Customization in pairs(self.m_SoldierAssets) do
        if l_Customization == nil then
            goto __loadout_get_custom_by_name__
        end

        local s_CustomizationName = l_Customization.name
        if p_Name == s_CustomizationName then
            return l_Customization
        end

        ::__loadout_get_custom_by_name__::
    end

    return nil
end

function LoadoutManager:GetAppearanceByName(p_Name)
    for _, l_Appearance in pairs(self.m_AppearanceAssets) do
        if l_Appearance == nil then
            goto __loadout_get_appear_by_name__
        end

        local l_AppearanceName = l_Appearance.name
        if p_Name == l_AppearanceName then
            return l_Appearance
        end

        ::__loadout_get_appear_by_name__::
    end

    return nil
end

function LoadoutManager:SpawnPlayer(p_Player, p_SoldierBlueprint, p_Transform, p_IsHvt, p_IsHvtSquad)
    -- Validate the player
    if p_Player == nil then
        if self.m_Engine:IsDebug() then
            print("err: invalid player.")
        end

        return
    end

    -- Validate the blueprint
    if p_SoldierBlueprint == nil then
        if self.m_Engine:IsDebug() then
            print("err: invalid soldier blueprint.")
        end

        return
    end

    -- Check if the player is alive
    if p_Player.alive then
        if self.m_Engine:IsDebug() then
            print("warn: skipping spawning player (" .. p_Player.name .. ") because they are alive.")
        end
        return
    end

    -- Get and validate the knife unlock
    local s_KnifeUnlock = self:GetWeaponUnlockByName("Weapons/Knife/U_Knife")
    if s_KnifeUnlock == nil then
        print("err: knife unlock not found.")
        return
    end

    -- Get the M416 with acog and silencer
    local s_M416Unlock = self:GetWeaponUnlockByName("Weapons/M416/U_M416")
    if s_M416Unlock == nil then
        print("err: m416 unlock not found.")
        return
    end

    local s_M416AcogUnlock = self:GetWeaponUnlockByName("Weapons/M416/U_M416_ACOG")
    if s_M416AcogUnlock == nil then
        print("err: m416 acog unlock not found.")
        return
    end

    local s_M416SilencerUnlock = self:GetWeaponUnlockByName("Weapons/M416/U_M416_Silencer")
    if s_M416SilencerUnlock == nil then
        print("err: m416 silencer unlock not found.")
        return
    end

    local s_G17Silenced = self:GetWeaponUnlockByName("Weapons/Glock17/U_Glock17_Silenced")
    if s_G17Silenced == nil then
        print("err: g17 silenced unlock not found.")
        return
    end

    -- Set the weapon slots
    p_Player:SelectWeapon(WeaponSlot.WeaponSlot_0, s_M416Unlock, { s_M416AcogUnlock, s_M416SilencerUnlock } )
    p_Player:SelectWeapon(WeaponSlot.WeaponSlot_1, s_G17Silenced, { } )

    -- Set our knife slot
    p_Player:SelectWeapon(WeaponSlot.WeaponSlot_5, s_KnifeUnlock, {})
    p_Player:SelectWeapon(WeaponSlot.WeaponSlot_7, s_KnifeUnlock, {})

    -- Get the asset and appearance
    local s_Appearance = nil
    local s_SoldierAsset = nil

    -- The attackers only get one skin, because they are all grunts
    if p_Player.teamId == Options.HVT_AttackTeam then
        s_Appearance = self:GetAppearanceByName(self.m_DefenceAppearanceName)
        s_SoldierAsset = self:GetCustomizationByName(self.m_DefenceSoldierName)
    elseif p_Player.teamId == Options.HVT_DefenceTeam then
        -- If we are in the HVT squad then set our customization accordingly
        if p_IsHvtSquad then
            s_Appearance = self:GetAppearanceByName(self.m_HVTGroupAppearanceName)
            s_SoldierAsset = self:GetCustomizationByName(self.m_HVTSoldierName)

            -- If the player is the HVT then set the special cammo
            if p_IsHvt then
                s_Appearance = self:GetAppearanceByName(self.m_HVTAppearanceName)
                s_SoldierAsset = self:GetCustomizationByName(self.m_HVTSoldierName)
            end
        else
            -- If they are on the general attacker team, but not in HVT squad
            s_Appearance = self:GetAppearanceByName(self.m_AttackAppearanceName)
            s_SoldierAsset = self:GetCustomizationByName(self.m_AttackSoldierName)
        end
    end

    -- Validate the appearance
    if s_Appearance == nil then
        print("err: invalid appearance.")
        return
    end

    -- Validate the soldier asset
    if s_SoldierAsset == nil then
        print("err: invalid soldier asset.")
        return
    end

    -- Set the unlocks
    p_Player:SelectUnlockAssets(s_SoldierAsset, { s_Appearance } )

    -- Create soldier
    local s_Soldier = p_Player:CreateSoldier(p_SoldierBlueprint, p_Transform)
    if s_Soldier == nil then
        print("err: failed to create player soldier.")
        return
    end

    -- Spawn the soldier
    p_Player:SpawnSoldierAt(s_Soldier, p_Transform, CharacterPoseType.CharacterPoseType_Stand)
end

return LoadoutManager