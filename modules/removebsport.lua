local function createResetBadSportStatModule(moduleContext)
    KSRuntimeFeatureState = KSRuntimeFeatureState or {}
    KSRuntimeFeatureState.largeObjects = KSRuntimeFeatureState.largeObjects or {}
    KSRuntimeFeatureState.dumpedObjectsPID = KSRuntimeFeatureState.dumpedObjectsPID or {}
    KSRuntimeFeatureState.windmills = KSRuntimeFeatureState.windmills or yeetwindmills or {}
    yeetwindmills = KSRuntimeFeatureState.windmills

    local function runResetBadSportStat()
        Stats.SetFloat(MISC.GET_HASH_KEY("MPPLY_OVERALL_BADSPORT"), 0.0)
    end

    local resetBadSportStatRunner = { variant = "donator", feature = "removebsport", slug = "removebsport" }

    function resetBadSportStatRunner.run(runContext)
        if type(runContext) ~= "table" or not runContext then
            runContext = {}
        end
        return runResetBadSportStat(runContext.feature)
    end

    return resetBadSportStatRunner
end

return createResetBadSportStatModule
