local function createLobbyWeaponDamageEventModule(moduleContext)
    if type(moduleContext) ~= "table" or not moduleContext then
        moduleContext = {}
    end
    local weaponDamageEventTrigger = moduleContext.CWeaponDamageEventTrigger
    local damageEventFlags = 528384

    local function runLobbyWeaponDamageEvent()
        if type(weaponDamageEventTrigger) ~= "number" or weaponDamageEventTrigger == 0 then
            return false
        end
        local localPlayerId = GTA.GetLocalPlayerId()
        local localPedObject = Players.GetCPed(localPlayerId)
        if not localPedObject or localPedObject == 0 then
            return false
        end
        local localPedAddress = localPedObject:GetAddress()
        if not localPedAddress or localPedAddress == 0 then
            return false
        end
        if type(KSPrepareBlameKillSensitiveFeature) == "function" then
            KSPrepareBlameKillSensitiveFeature("lobbycorrupt", 2500)
        end
        for targetPlayerId = 0, 31 do
            if ShouldUnload() then
                return false
            end
            if targetPlayerId ~= localPlayerId and Players.GetById(targetPlayerId) ~= nil then
                local localPed = PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(localPlayerId)
                local targetPed = PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(targetPlayerId)
                local localX, localY, localZ = ENTITY.GET_ENTITY_COORDS(localPed)
                local targetX, targetY, targetZ = ENTITY.GET_ENTITY_COORDS(targetPed)
                if SYSTEM.VDIST(localX, localY, localZ, targetX, targetY, targetZ) < 65.0 then
                    notify("You must teleport away for this to work")
                else
                    local targetPedObject = Players.GetCPed(targetPlayerId)
                    if targetPedObject and targetPedObject ~= 0 then
                        local targetPedAddress = targetPedObject:GetAddress()
                        if targetPedAddress and targetPedAddress ~= 0 and not PLAYER.IS_PLAYER_DEAD(targetPlayerId) then
                            Memory.LuaCallCFunction(
                                weaponDamageEventTrigger, localPedAddress, targetPedAddress,
                                targetPedAddress + 144, 0, 1, Utils.sJoaat("weapon_tranquilizer"),
                                0.0, 0, 0, damageEventFlags, 0, 0, 0, 0, 0, 0, 0, V3.New()
                            )
                            Script.Yield(50)
                        end
                    end
                end
            end
        end
        return true
    end

    local lobbyWeaponDamageEventRunner = { variant = "supporter", feature = "lobbycorrupt", slug = "lobbycorrupt" }

    function lobbyWeaponDamageEventRunner.run(runContext)
        if type(runContext) ~= "table" or not runContext then
            runContext = {}
        end
        return runLobbyWeaponDamageEvent()
    end

    return lobbyWeaponDamageEventRunner
end

return createLobbyWeaponDamageEventModule
