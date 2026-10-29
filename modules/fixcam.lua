local function createResetScriptedCameraModule(moduleContext)
    KSRuntimeFeatureState = KSRuntimeFeatureState or {}
    KSRuntimeFeatureState.largeObjects = KSRuntimeFeatureState.largeObjects or {}
    KSRuntimeFeatureState.dumpedObjectsPID = KSRuntimeFeatureState.dumpedObjectsPID or {}
    KSRuntimeFeatureState.windmills = KSRuntimeFeatureState.windmills or yeetwindmills or {}
    yeetwindmills = KSRuntimeFeatureState.windmills

    local crashCamera = KSRuntimeFeatureState.crash_cam or 0

    local function runResetScriptedCamera()
        CAM.RENDER_SCRIPT_CAMS(0, 0, 0, 0, 0, 0)
        CAM.SET_CAM_ACTIVE(crashCamera, false)
        STREAMING.CLEAR_FOCUS()
        CAM.DESTROY_ALL_CAMS(0)
    end

    local resetScriptedCameraRunner = { variant = "donator", feature = "fixcam", slug = "fixcam" }

    function resetScriptedCameraRunner.run(runContext)
        if type(runContext) ~= "table" or not runContext then
            runContext = {}
        end
        return runResetScriptedCamera(runContext.feature)
    end

    return resetScriptedCameraRunner
end

return createResetScriptedCameraModule
