local function createScriptHostEventCrashModule(moduleContext)
    KSRuntimePlayerFeatureState = KSRuntimePlayerFeatureState or {}
    KSRuntimePlayerFeatureState.largeObjects = KSRuntimePlayerFeatureState.largeObjects or {}
    KSRuntimePlayerFeatureState.dumpedObjectsPID = KSRuntimePlayerFeatureState.dumpedObjectsPID or {}

    local function runScriptHostEventCrash(playerFeature)
        local targetPlayerId = Utils.GetSelectedPlayer()
        local targetPlayer = Players.GetById(targetPlayerId)
        if not targetPlayer then
            return
        end
        local targetGamerInfo = targetPlayer:GetGamerInfo()
        if targetPlayerId == GTA.GetLocalPlayerId() or targetPlayerId == nil then
            return
        end
        if blacklistRIDList[targetGamerInfo.RockstarId] then
            if not isDev then
                blacklistSound()
                SendToDiscord("nogger", ("%s(%i) tried to Crash a Blacklisted Player (%s)! @everyone"):format(
                    Players.GetName(GTA.GetLocalPlayerId()), Cherax.GetUID(),
                    Players.GetName(targetPlayerId)
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

        local function logFeatureUse()
            local targetTags = Players.GetTags(targetPlayerId)
            local isTargetFriend = string.find(targetTags, "[F]", 1, true) ~= nil
            SendToDiscord("lol", ("%s used Yeet Em Crash against %s with UID %i, isSupporter: %s, is Target Friend?: %s"):format(
                PLAYER.GET_PLAYER_NAME(GTA.GetLocalPlayerId()),
                Players.GetName(targetPlayerId), Cherax.GetUID(),
                tostring(isSupporter), tostring(isTargetFriend)
            ))
        end
        log = logFeatureUse
        Script.QueueJob(log)
        onCrashCooldown = true
        GTA.GiveScriptHost(Utils.GetSelectedPlayer(), Utils.Joaat("freemode"))
        Script.Yield(500)

        local eventId = 323285304
        local maximumSignedInteger = 2147483647
        GTA.TriggerScriptEvent(
            1 << Utils.GetSelectedPlayer(), eventId, GTA.GetLocalPlayerId(),
            1 << Utils.GetSelectedPlayer(), maximumSignedInteger, maximumSignedInteger,
            maximumSignedInteger, maximumSignedInteger, 956849991, 0
        )
        notify("Done!")
        onCrashCooldown = false
    end

    local scriptHostEventCrashRunner = { variant = "donator", feature = "lexisSkid", slug = "lexisskid" }

    function scriptHostEventCrashRunner.run(runContext)
        if type(runContext) ~= "table" or not runContext then
            runContext = {}
        end
        return runScriptHostEventCrash(runContext.feature)
    end

    return scriptHostEventCrashRunner
end

return createScriptHostEventCrashModule
