local function createPlayerNoteFieldModule(moduleContext)
    KSRuntimePlayerFeatureState = KSRuntimePlayerFeatureState or {}
    KSRuntimePlayerFeatureState.largeObjects = KSRuntimePlayerFeatureState.largeObjects or {}
    KSRuntimePlayerFeatureState.dumpedObjectsPID = KSRuntimePlayerFeatureState.dumpedObjectsPID or {}

    local function runPlayerNoteField(playerNoteFeature)
    end

    local playerNoteFieldRunner = { variant = "donator", feature = "PlayerNote", slug = "playernote" }

    function playerNoteFieldRunner.run(runContext)
        if type(runContext) ~= "table" or not runContext then
            runContext = {}
        end
        return runPlayerNoteField(runContext.feature)
    end

    return playerNoteFieldRunner
end

return createPlayerNoteFieldModule
