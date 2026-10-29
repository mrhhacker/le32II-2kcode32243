local function createDeleteSpawnedWindmillsModule(moduleContext)
    KSRuntimeFeatureState = KSRuntimeFeatureState or {}
    KSRuntimeFeatureState.largeObjects = KSRuntimeFeatureState.largeObjects or {}
    KSRuntimeFeatureState.dumpedObjectsPID = KSRuntimeFeatureState.dumpedObjectsPID or {}
    KSRuntimeFeatureState.windmills = KSRuntimeFeatureState.windmills or yeetwindmills or {}
    yeetwindmills = KSRuntimeFeatureState.windmills

    local function runDeleteSpawnedWindmills()
        local deletedWindmillCount = 0
        for windmillIndex = #yeetwindmills, 1, -1 do
            local windmillEntity = yeetwindmills[windmillIndex]
            if windmillEntity ~= nil and windmillEntity ~= 0 then
                DeleteEnt(windmillEntity)
                deletedWindmillCount = deletedWindmillCount + 1
            end
            yeetwindmills[windmillIndex] = nil
            Script.Yield(0)
        end
        KSRuntimeFeatureState.windmills = yeetwindmills
        notify(string.format("Deleted %d spawned windmill%s.", deletedWindmillCount, deletedWindmillCount == 1 and "" or "s"))
        return deletedWindmillCount
    end

    local deleteSpawnedWindmillsRunner = { variant = "donator", feature = "DeleteAllSpawnedWindmills", slug = "deleteallspawnedwindmills" }

    function deleteSpawnedWindmillsRunner.run(runContext)
        if type(runContext) ~= "table" or not runContext then
            runContext = {}
        end
        return runDeleteSpawnedWindmills(runContext.feature)
    end

    return deleteSpawnedWindmillsRunner
end

return createDeleteSpawnedWindmillsModule
