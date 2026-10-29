local function createClearBlockedEntityCacheModule(moduleContext)
    KSRuntimeFeatureState = KSRuntimeFeatureState or {}
    KSRuntimeFeatureState.largeObjects = KSRuntimeFeatureState.largeObjects or {}
    KSRuntimeFeatureState.dumpedObjectsPID = KSRuntimeFeatureState.dumpedObjectsPID or {}
    KSRuntimeFeatureState.windmills = KSRuntimeFeatureState.windmills or yeetwindmills or {}
    yeetwindmills = KSRuntimeFeatureState.windmills

    local function runClearBlockedEntityCache()
        clearBlockedCache()
    end

    local clearBlockedEntityCacheRunner = { variant = "donator", feature = "clearcacheEnts1", slug = "clearcacheents1" }

    function clearBlockedEntityCacheRunner.run(runContext)
        if type(runContext) ~= "table" or not runContext then
            runContext = {}
        end
        return runClearBlockedEntityCache(runContext.feature)
    end

    return clearBlockedEntityCacheRunner
end

return createClearBlockedEntityCacheModule
