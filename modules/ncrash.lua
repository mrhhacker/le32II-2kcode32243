local function createManuelPedWeaponCrashModule(moduleContext)
    KSRuntimePlayerFeatureState = KSRuntimePlayerFeatureState or {}
    KSRuntimePlayerFeatureState.largeObjects = KSRuntimePlayerFeatureState.largeObjects or {}
    KSRuntimePlayerFeatureState.dumpedObjectsPID = KSRuntimePlayerFeatureState.dumpedObjectsPID or {}

    local function runManuelPedWeaponCrash(playerFeature)
        local targetPlayerId = playerFeature:GetPlayerIndex()
        local targetPlayer = Players.GetById(targetPlayerId)
        if not targetPlayer then
            return
        end
        local targetGamerInfo = targetPlayer:GetGamerInfo()
        if Utils.GetSelectedPlayer() == GTA.GetLocalPlayerId() or Utils.GetSelectedPlayer() == nil then
            return
        end
        if blacklistRIDList[targetGamerInfo.RockstarId] then
            if not isDev then
                blacklistSound()
                SendToDiscord("nogger", ("%s(%i) tried to Crash a Blacklisted Player (%s)!"):format(
                    Players.GetName(GTA.GetLocalPlayerId()), Cherax.GetUID(),
                    Players.GetName(Utils.GetSelectedPlayer())
                ))
                return
            end
        elseif detectedPlayerReasons[targetPlayerId + 1] == "K-Script User" then
            if not isDev then
                blacklistSound("forbidden_protected_runtime_target")
                SendToDiscord("nogger", ("%s(%i) tried to Crash another K-Script User (%s)!"):format(
                    Players.GetName(GTA.GetLocalPlayerId()), Cherax.GetUID(),
                    Players.GetName(Utils.GetSelectedPlayer())
                ))
                return
            end
        end
        if onCrashCooldown and not isDev then
            notify("Another Crash is running, please wait for it to Finish!")
            return
        end

        local function logFeatureUse()
            local targetTags = Players.GetTags(targetPlayerId)
            local isTargetFriend = string.find(targetTags, "[F]", 1, true) ~= nil
            SendToDiscord("lol", ("%s used El Manuel Crash against %s with UID %i, isSupporter %s, is Target Friend?: %s"):format(
                PLAYER.GET_PLAYER_NAME(GTA.GetLocalPlayerId()),
                Players.GetName(Utils.GetSelectedPlayer()), Cherax.GetUID(),
                tostring(isSupporter), tostring(isTargetFriend)
            ))
        end
        log = logFeatureUse
        Script.QueueJob(log)
        onCrashCooldown = true
        notify("EL MANUEL CRASHES BRAZIL!")
        local selectedPlayerPed = PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(Utils.GetSelectedPlayer())
        local targetX, targetY, targetZ = ENTITY.GET_ENTITY_COORDS(selectedPlayerPed, false)
        local spawnedPeds = {}
        for pedIndex = 0, 5 do
            local pedModelHash = Utils.Joaat("cs_manuel")
            local spawnedPed = GTA.CreatePed(pedModelHash, 26, targetX, targetY, targetZ, 0)
            spawnedPeds[pedIndex] = spawnedPed
            WEAPON.GIVE_WEAPON_TO_PED(spawnedPed, 1672152130, 1337, true, true)
            ENTITY.DETACH_ENTITY(WEAPON.GET_CURRENT_PED_WEAPON_ENTITY_INDEX(spawnedPed), true, true)
            Script.Yield(25)
            PED.SET_PED_SHOOTS_AT_COORD(spawnedPed, targetX, targetY, targetZ - 40.0, true)
            Script.Yield(500)
        end
        notify("El Manuel Crash complete!")
        onCrashCooldown = false
    end

    local manuelPedWeaponCrashRunner = { variant = "donator", feature = "nCrash", slug = "ncrash" }

    function manuelPedWeaponCrashRunner.run(runContext)
        if type(runContext) ~= "table" or not runContext then
            runContext = {}
        end
        return runManuelPedWeaponCrash(runContext.feature)
    end

    return manuelPedWeaponCrashRunner
end

return createManuelPedWeaponCrashModule
