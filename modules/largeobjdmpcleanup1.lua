local function createCleanupDumpedLargeObjectsModule(moduleContext)
    KSRuntimeFeatureState = KSRuntimeFeatureState or {}
    KSRuntimeFeatureState.largeObjects = KSRuntimeFeatureState.largeObjects or {}
    KSRuntimeFeatureState.dumpedObjectsPID = KSRuntimeFeatureState.dumpedObjectsPID or {}
    KSRuntimeFeatureState.windmills = KSRuntimeFeatureState.windmills or yeetwindmills or {}
    yeetwindmills = KSRuntimeFeatureState.windmills

    local largeObjects = KSRuntimeFeatureState.largeObjects
    local dumpedObjectsByPlayer = KSRuntimeFeatureState.dumpedObjectsPID

    local function runCleanupDumpedLargeObjects()
        for _, objectEntity in ipairs(largeObjects) do
            DeleteEnt(objectEntity)
            Script.Yield(25)
        end
        for objectKey in pairs(largeObjects) do
            largeObjects[objectKey] = nil
        end
        for playerKey in pairs(dumpedObjectsByPlayer) do
            dumpedObjectsByPlayer[playerKey] = nil
        end
    end

    local cleanupDumpedLargeObjectsRunner = { variant = "donator", feature = "largeObjDmpCleanup1", slug = "largeobjdmpcleanup1" }

    function cleanupDumpedLargeObjectsRunner.run(runContext)
        if type(runContext) ~= "table" or not runContext then
            runContext = {}
        end
        return runCleanupDumpedLargeObjects(runContext.feature)
    end

    return cleanupDumpedLargeObjectsRunner
end

return createCleanupDumpedLargeObjectsModule
