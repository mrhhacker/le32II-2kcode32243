local function createActivityMissionBypassModule(moduleContext)
    KSRuntimePlayerFeatureState = KSRuntimePlayerFeatureState or {}
    KSRuntimePlayerFeatureState.largeObjects = KSRuntimePlayerFeatureState.largeObjects or {}
    KSRuntimePlayerFeatureState.dumpedObjectsPID = KSRuntimePlayerFeatureState.dumpedObjectsPID or {}

    local function runActivityMissionBypass(playerFeature, activityId, activityName)
        if playerFeature == nil or activityId == nil then
            return false
        end

        local targetPlayerId = playerFeature:GetPlayerIndex()
        if type(targetPlayerId) ~= "number"
            or targetPlayerId == GTA.GetLocalPlayerId()
            or not (isDev or isSupporter or isAdmin) then
            return false
        end

        local targetPlayer = Players.GetById(targetPlayerId)
        local targetGamerInfo = targetPlayer and targetPlayer:GetGamerInfo() or nil
        if targetGamerInfo == nil then
            return false
        end

        if blacklistRIDList[targetGamerInfo.RockstarId] and not isDev then
            blacklistSound()
            SendToDiscord("nogger", ("%s(%s) tried use a Bypass on a Blacklisted Player (%s)!"):format(
                tostring(Players.GetName(GTA.GetLocalPlayerId()) or "Unknown"),
                tostring(Cherax.GetUID() or 0),
                tostring(Players.GetName(targetPlayerId) or "Unknown")
            ))
            return false
        end

        invitePlayerOntoMission(targetPlayerId, activityId)
        launchMission(targetPlayerId)

        local targetTags = tostring(Players.GetTags(targetPlayerId) or "")
        local isTargetFriend = string.find(targetTags, "[F]", 1, true) ~= nil
        local activityLabel = tostring(activityName or activityId)
        local targetPlayerName = tostring(Players.GetName(targetPlayerId) or "Unknown")
        SendToDiscord("lol", ("%s used Activity Bypass: %s against %s with UID %s, isSupporter: %s, is Target Friend?: %s"):format(
            tostring(PLAYER.GET_PLAYER_NAME(GTA.GetLocalPlayerId()) or "Unknown"),
            activityLabel,
            targetPlayerName,
            tostring(Cherax.GetUID() or 0),
            tostring(isSupporter),
            tostring(isTargetFriend)
        ))
        return true
    end

    local activityMissionBypassRunner = { variant = "donator", feature = "activity_bypass", slug = "activity_bypass" }

    function activityMissionBypassRunner.run(runContext)
        if type(runContext) ~= "table" or not runContext then
            runContext = {}
        end
        return runActivityMissionBypass(runContext.feature, runContext.activityId, runContext.activityName)
    end

    return activityMissionBypassRunner
end

return createActivityMissionBypassModule
