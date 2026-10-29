local function createInvalidClaimNotificationLoopModule(moduleContext)
    KSRuntimePlayerFeatureState = KSRuntimePlayerFeatureState or {}
    KSRuntimePlayerFeatureState.largeObjects = KSRuntimePlayerFeatureState.largeObjects or {}
    KSRuntimePlayerFeatureState.dumpedObjectsPID = KSRuntimePlayerFeatureState.dumpedObjectsPID or {}

    local function runInvalidClaimNotificationLoop(notificationFeature)
        while notificationFeature:IsToggled() do
            local recipientMask = 1 << notificationFeature:GetPlayerIndex()
            GTA.TriggerScriptEvent(
                recipientMask,
                SCRIPT_EVENT.SCRIPT_EVENT_TICKER_MESSAGE,
                GTA.GetLocalPlayerId(),
                16777216, -994541138, 1, 0, 0, 0, 0, 0, 0, 2096820586, 0, 0, 0
            )
            Script.Yield(10)
        end
    end

    local invalidClaimNotificationLoopRunner = { variant = "donator", feature = "Invalid claim notification", slug = "invalid_claim_notification" }

    function invalidClaimNotificationLoopRunner.run(runContext)
        if type(runContext) ~= "table" or not runContext then
            runContext = {}
        end
        return runInvalidClaimNotificationLoop(runContext.feature)
    end

    return invalidClaimNotificationLoopRunner
end

return createInvalidClaimNotificationLoopModule
