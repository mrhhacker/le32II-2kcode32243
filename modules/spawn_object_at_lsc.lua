local function createSpawnWindmillsAtSelectedLocationsModule(moduleContext)
    KSRuntimeFeatureState = KSRuntimeFeatureState or {}
    KSRuntimeFeatureState.largeObjects = KSRuntimeFeatureState.largeObjects or {}
    KSRuntimeFeatureState.dumpedObjectsPID = KSRuntimeFeatureState.dumpedObjectsPID or {}
    KSRuntimeFeatureState.windmills = KSRuntimeFeatureState.windmills or yeetwindmills or {}
    yeetwindmills = KSRuntimeFeatureState.windmills

    if type(moduleContext) ~= "table" or not moduleContext then
        moduleContext = {}
    end
    local spawnObjectsAtLocations = moduleContext.SpawnObjectAtLSC

    local function runSpawnWindmillsAtSelectedLocations()
        if not (isDev or isAdmin or isSupporter) then
            notify("This feature is for Supporters")
            return
        end

        local spawnedSuccessfully, spawnedWindmillCount, selectedLocationCount = spawnObjectsAtLocations()
        if spawnedSuccessfully then
            notify(string.format("Spawned %d windmills.", spawnedWindmillCount))
        elseif selectedLocationCount == 0 then
            notify("No windmill locations are enabled.")
        else
            notify(string.format("Windmill spawning failed at %d selected locations.", selectedLocationCount))
        end
        return spawnedSuccessfully
    end

    local spawnWindmillsAtSelectedLocationsRunner = { variant = "donator", feature = "SPAWN_OBJECT_AT_LSC", slug = "spawn_object_at_lsc" }

    function spawnWindmillsAtSelectedLocationsRunner.run(runContext)
        if type(runContext) ~= "table" or not runContext then
            runContext = {}
        end
        return runSpawnWindmillsAtSelectedLocations(runContext.feature)
    end

    return spawnWindmillsAtSelectedLocationsRunner
end

return createSpawnWindmillsAtSelectedLocationsModule
