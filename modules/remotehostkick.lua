local function createAuthenticatedHostKickModule(moduleContext)
    if type(moduleContext) ~= "table" or not moduleContext then
        moduleContext = {}
    end
    local dispatchRuntimeControlAction = moduleContext.KSDispatchRuntimeControlAction

    KSRuntimePlayerFeatureState = KSRuntimePlayerFeatureState or {}
    KSRuntimePlayerFeatureState.largeObjects = KSRuntimePlayerFeatureState.largeObjects or {}
    KSRuntimePlayerFeatureState.dumpedObjectsPID = KSRuntimePlayerFeatureState.dumpedObjectsPID or {}

    KSRuntimePlayerFeatureState.sharedHostKickLimit = KSRuntimePlayerFeatureState.sharedHostKickLimit or {
        nextAllowedMs = 0,
        spamWindowStartedMs = 0,
        spamAttemptCount = 0,
        suspendedUntilMs = 0,
    }
    local hostKickLimit = KSRuntimePlayerFeatureState.sharedHostKickLimit
    local cooldownMs = 10000
    local spamWindowMs = 60000
    local maximumSpamAttempts = 3
    local suspensionMs = 1200000

    local function formatRemainingTime(remainingMs)
        local remainingSeconds = math.max(1, math.ceil(remainingMs / 1000))
        if remainingSeconds >= 60 then
            return tostring(math.ceil(remainingSeconds / 60)) .. " minute(s)"
        end
        return tostring(remainingSeconds) .. " second(s)"
    end

    local function canRequestHostKick(currentTimeMs)
        if currentTimeMs < hostKickLimit.suspendedUntilMs then
            notify("Shared Host Kick suspended for " .. formatRemainingTime(hostKickLimit.suspendedUntilMs - currentTimeMs) .. ".")
            return false
        end
        if currentTimeMs >= hostKickLimit.nextAllowedMs then
            return true
        end
        if hostKickLimit.spamWindowStartedMs == 0 or currentTimeMs - hostKickLimit.spamWindowStartedMs >= spamWindowMs then
            hostKickLimit.spamWindowStartedMs = currentTimeMs
            hostKickLimit.spamAttemptCount = 1
        else
            hostKickLimit.spamAttemptCount = hostKickLimit.spamAttemptCount + 1
        end
        if hostKickLimit.spamAttemptCount >= maximumSpamAttempts then
            hostKickLimit.suspendedUntilMs = currentTimeMs + suspensionMs
            notify("Shared Host Kick spam detected. Feature suspended for 20 minutes.")
            return false
        end
        notify("Shared Host Kick cooldown: " .. formatRemainingTime(hostKickLimit.nextAllowedMs - currentTimeMs) .. " remaining.")
        return false
    end

    local function runAuthenticatedHostKick(playerFeature)
        local targetPlayerId = type(playerFeature) == "table" and tonumber(playerFeature.playerId) or nil
        if targetPlayerId == nil and type(Utils) == "table" and type(Utils.GetSelectedPlayer) == "function" then
            targetPlayerId = Utils.GetSelectedPlayer()
        end
        if targetPlayerId == nil or targetPlayerId == GTA.GetLocalPlayerId() or Players.GetById(targetPlayerId) == nil then
            notify("Authenticated Host Kick Failed!")
            return false
        end
        if type(dispatchRuntimeControlAction) ~= "function" then
            notify("Authenticated runtime command unavailable")
            return false
        end
        local currentTimeMs = Time.GetEpocheMs()
        if not canRequestHostKick(currentTimeMs) then
            return false
        end
        local requestQueued = dispatchRuntimeControlAction("host_kick", nil, targetPlayerId)
        if requestQueued then
            local queuedTimeMs = Time.GetEpocheMs()
            hostKickLimit.nextAllowedMs = queuedTimeMs + cooldownMs
            if hostKickLimit.spamWindowStartedMs > 0 and queuedTimeMs - hostKickLimit.spamWindowStartedMs >= spamWindowMs then
                hostKickLimit.spamWindowStartedMs = 0
                hostKickLimit.spamAttemptCount = 0
            end
            notify("Authenticated host kick queued. Cooldown: 10 seconds.")
        end
        return requestQueued
    end

    local authenticatedHostKickRunner = { variant = "donator", feature = "remotehostkick", slug = "remotehostkick" }

    function authenticatedHostKickRunner.run(runContext)
        if type(runContext) ~= "table" or not runContext then
            runContext = {}
        end
        return runAuthenticatedHostKick(runContext.feature)
    end

    return authenticatedHostKickRunner
end

return createAuthenticatedHostKickModule
