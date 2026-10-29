local function createPlayerZeroCrashWrapperModule(moduleContext)
    KSRuntimePlayerFeatureState = KSRuntimePlayerFeatureState or {}
    KSRuntimePlayerFeatureState.largeObjects = KSRuntimePlayerFeatureState.largeObjects or {}
    KSRuntimePlayerFeatureState.dumpedObjectsPID = KSRuntimePlayerFeatureState.dumpedObjectsPID or {}

    local function runPlayerZeroCrashWrapper()
        playerZeroCrash()
    end

    local playerZeroCrashWrapperRunner = { variant = "donator", feature = "zeroCrash", slug = "zerocrash" }

    function playerZeroCrashWrapperRunner.run(runContext)
        if type(runContext) ~= "table" or not runContext then
            runContext = {}
        end
        return runPlayerZeroCrashWrapper()
    end

    return playerZeroCrashWrapperRunner
end

return createPlayerZeroCrashWrapperModule
