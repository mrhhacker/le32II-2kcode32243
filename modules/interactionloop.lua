local function createActivityInviteLaunchLoopModule(moduleContext)
    KSRuntimePlayerFeatureState = KSRuntimePlayerFeatureState or {}
    KSRuntimePlayerFeatureState.largeObjects = KSRuntimePlayerFeatureState.largeObjects or {}
    KSRuntimePlayerFeatureState.dumpedObjectsPID = KSRuntimePlayerFeatureState.dumpedObjectsPID or {}

    local function runActivityInviteLaunchLoop(feature)
        local targetPlayerId = feature:GetPlayerIndex()
        local playerTags = Players.GetTags(targetPlayerId)
        local isTargetFriend = string.find(playerTags, "[F]", 1, true) ~= nil
        local activityName = activities[16]
        SendToDiscord("lol", ("%s used Activity Bypass Loop: %s against %s with UID %i, isSupporter %s, is Target Friend?: %s"):format(
            PLAYER.GET_PLAYER_NAME(GTA.GetLocalPlayerId()), activityName,
            Players.GetName(Utils.GetSelectedPlayer()), Cherax.GetUID(), tostring(isSupporter), tostring(isTargetFriend)
        ))

        while feature:IsToggled() and not ShouldUnload() do
            local targetPlayer = Players.GetById(targetPlayerId)
            if not targetPlayer then
                break
            end
            local targetGamerInfo = targetPlayer:GetGamerInfo()
            if Utils.GetSelectedPlayer() == GTA.GetLocalPlayerId() or not (isDev or isSupporter or isAdmin) then
                return
            end
            if blacklistRIDList[targetGamerInfo.RockstarId] and not isDev then
                blacklistSound()
                SendToDiscord("nogger", ("%s(%i) tried use a Bypass on a Blacklisted Player (%s)!"):format(
                    Players.GetName(GTA.GetLocalPlayerId()), Cherax.GetUID(), Players.GetName(Utils.GetSelectedPlayer())
                ))
                return
            end

            local currentTargetPlayerId = feature:GetPlayerIndex()
            invitePlayerOntoMission(currentTargetPlayerId, 16)
            launchMission(currentTargetPlayerId)
            Script.Yield(100)
        end
    end

    local activityInviteLaunchLoopRunner = { variant = "donator", feature = "interactionLoop", slug = "interactionloop" }

    function activityInviteLaunchLoopRunner.run(runContext)
        if type(runContext) ~= "table" or not runContext then
            runContext = {}
        end
        return runActivityInviteLaunchLoop(runContext.feature)
    end

    return activityInviteLaunchLoopRunner
end

return createActivityInviteLaunchLoopModule
