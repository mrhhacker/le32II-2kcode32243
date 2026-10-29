local function createRequestKosatkaModule(moduleContext)
    KSRuntimeFeatureState = KSRuntimeFeatureState or {}
    KSRuntimeFeatureState.largeObjects = KSRuntimeFeatureState.largeObjects or {}
    KSRuntimeFeatureState.dumpedObjectsPID = KSRuntimeFeatureState.dumpedObjectsPID or {}
    KSRuntimeFeatureState.windmills = KSRuntimeFeatureState.windmills or yeetwindmills or {}
    yeetwindmills = KSRuntimeFeatureState.windmills

    local function runRequestKosatka()
        if ScriptGlobal.GetInt(MPGlobalsAmbience.bLaunchVehicleDropSubmarine) == 1 then
            return
        end

        if ScriptGlobal.GetInt(MPGlobalsAmbience.bLaunchVehicleDropAvenger) == 1
            or ScriptGlobal.GetInt(MPGlobalsAmbience.bLaunchVehicleDropHackerTruck) == 1
            or ScriptGlobal.GetInt(MPGlobalsAmbience.bLaunchVehicleDropTruck) == 1
            or ScriptGlobal.GetInt(MPGlobalsAmbience.bLaunchVehicleDropAcidLab) == 1 then
            notify("You already have a service vehicle requested")
        end
        ScriptGlobal.SetInt(MPGlobalsAmbience.bLaunchVehicleDropSubmarine, 1)
    end

    local requestKosatkaRunner = { variant = "donator", feature = "Request Kosatka", slug = "request_kosatka" }

    function requestKosatkaRunner.run(runContext)
        if type(runContext) ~= "table" or not runContext then
            runContext = {}
        end
        return runRequestKosatka(runContext.feature)
    end

    return requestKosatkaRunner
end

return createRequestKosatkaModule
