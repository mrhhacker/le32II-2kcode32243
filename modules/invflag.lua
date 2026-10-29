local function createTranquilizerDamageEventModule(moduleContext)
    if type(moduleContext) ~= "table" or not moduleContext then
        moduleContext = {}
    end
    local triggerWeaponDamageEvent = moduleContext.CWeaponDamageEventTrigger
    local prepareSensitiveFeature = moduleContext.KSPrepareBlameKillSensitiveFeature or KSPrepareBlameKillSensitiveFeature

    KSRuntimePlayerFeatureState = KSRuntimePlayerFeatureState or {}
    KSRuntimePlayerFeatureState.largeObjects = KSRuntimePlayerFeatureState.largeObjects or {}
    KSRuntimePlayerFeatureState.dumpedObjectsPID = KSRuntimePlayerFeatureState.dumpedObjectsPID or {}

    local suppressImpactAudioFlag = 4096
    local ignoreRemoteDistanceCheckFlag = 524288

    local function runTranquilizerDamageEvent(playerFeature)
        local targetPlayerId = playerFeature:GetPlayerIndex()
        if targetPlayerId == nil then
            return
        end
        local targetPlayer = Players.GetById(targetPlayerId)
        if not targetPlayer then
            return
        end
        local targetGamerInfo = targetPlayer:GetGamerInfo()
        if targetPlayerId == GTA.GetLocalPlayerId() then
            return
        end
        if blacklistRIDList[targetGamerInfo.RockstarId] then
            if not isDev then
                blacklistSound()
                SendToDiscord("nogger", ("%s(%i) tried to Crash a Blacklisted Player (%s)! @everyone"):format(
                    Players.GetName(GTA.GetLocalPlayerId()), Cherax.GetUID(),
                    Players.GetName(Utils.GetSelectedPlayer())
                ))
                return
            end
        end

        local localX, localY, localZ = ENTITY.GET_ENTITY_COORDS(PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(GTA.GetLocalPlayerId()))
        local targetX, targetY, targetZ = ENTITY.GET_ENTITY_COORDS(PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(targetPlayerId))
        local distanceToTarget = SYSTEM.VDIST(localX, localY, localZ, targetX, targetY, targetZ)
        if distanceToTarget < 65.0 then
            notify("You must teleport away for this to work")
            return
        end
        local targetPedPointer = Players.GetCPed(targetPlayerId)
        if not targetPedPointer or targetPedPointer == 0 then
            notify("Failed to get CPed")
            return
        end
        local targetPedAddress = targetPedPointer:GetAddress()
        if not targetPedAddress or targetPedAddress == 0 then
            notify("Failed to get CPed #2")
            return
        end
        local localPedPointer = GTA.GetLocalPed()
        if not localPedPointer then
            notify("Failed to get Local Ped")
            return
        end
        local localPedAddress = localPedPointer:GetAddress()
        if not localPedAddress or localPedAddress == 0 then
            notify("Failed to get Local Ped #2")
            return
        end
        if PLAYER.IS_PLAYER_DEAD(targetPlayerId) then
            return
        end
        if type(prepareSensitiveFeature) ~= "function" or prepareSensitiveFeature("invflag", 750, targetPlayerId) ~= true then
            notify("Infinite George Floyd Moment could not prepare its target sync.")
            return false
        end

        local damageFlags = suppressImpactAudioFlag | ignoreRemoteDistanceCheckFlag
        Memory.LuaCallCFunction(
            triggerWeaponDamageEvent, localPedAddress, targetPedAddress, targetPedAddress + 144,
            0, 1, Utils.sJoaat("weapon_tranquilizer"), 0.0, 0, 0, damageFlags,
            0, 0, 0, 0, 0, 0, 0, V3.New()
        )
    end

    local tranquilizerDamageEventRunner = { variant = "donator", feature = "invflag", slug = "invflag" }

    function tranquilizerDamageEventRunner.run(runContext)
        if type(runContext) ~= "table" or not runContext then
            runContext = {}
        end
        return runTranquilizerDamageEvent(runContext.feature)
    end

    return tranquilizerDamageEventRunner
end

return createTranquilizerDamageEventModule
