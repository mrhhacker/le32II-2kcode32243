local function createSendSessionPlayersToOnlineIntroModule(moduleContext)
    KSRuntimeFeatureState = KSRuntimeFeatureState or {}
    KSRuntimeFeatureState.largeObjects = KSRuntimeFeatureState.largeObjects or {}
    KSRuntimeFeatureState.dumpedObjectsPID = KSRuntimeFeatureState.dumpedObjectsPID or {}
    KSRuntimeFeatureState.windmills = KSRuntimeFeatureState.windmills or yeetwindmills or {}
    yeetwindmills = KSRuntimeFeatureState.windmills

    local function runSendSessionPlayersToOnlineIntro()
        for playerId = 0, 31 do
            local sessionPlayer = Players.GetById(playerId)
            if sessionPlayer ~= nil and playerId ~= GTA.GetLocalPlayerId() then
                local playerTags = Players.GetTags(playerId)
                if not playerTags:find("%[M%]") and not playerTags:find("%[F%]") then
                    Logger.Log(eLogColor.GREEN, "K-Script", ("Sending %s into Online Intro..."):format(Players.GetName(playerId)))
                    FeatureMgr.GetFeature(Utils.Joaat("GTAO Intro"), playerId):TriggerCallback()
                    Script.Yield(500)
                end
            end
        end
    end

    local sendSessionPlayersToOnlineIntroRunner = { variant = "donator", feature = "introall", slug = "introall" }

    function sendSessionPlayersToOnlineIntroRunner.run(runContext)
        if type(runContext) ~= "table" or not runContext then
            runContext = {}
        end
        return runSendSessionPlayersToOnlineIntro(runContext.feature)
    end

    return sendSessionPlayersToOnlineIntroRunner
end

return createSendSessionPlayersToOnlineIntroModule
