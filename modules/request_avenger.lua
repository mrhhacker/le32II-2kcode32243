local function createRequestAvengerModule(moduleContext)
    KSRuntimeFeatureState = KSRuntimeFeatureState or {}
    KSRuntimeFeatureState.largeObjects = KSRuntimeFeatureState.largeObjects or {}
    KSRuntimeFeatureState.dumpedObjectsPID = KSRuntimeFeatureState.dumpedObjectsPID or {}
    KSRuntimeFeatureState.windmills = KSRuntimeFeatureState.windmills or yeetwindmills or {}
    yeetwindmills = KSRuntimeFeatureState.windmills

    local function runRequestAvenger()
        if ScriptGlobal.GetInt(MPGlobalsAmbience.bLaunchVehicleDropAvenger) == 1 then
            return
        end

        if ScriptGlobal.GetInt(MPGlobalsAmbience.bLaunchVehicleDropSubmarine) == 1
            or ScriptGlobal.GetInt(MPGlobalsAmbience.bLaunchVehicleDropHackerTruck) == 1
            or ScriptGlobal.GetInt(MPGlobalsAmbience.bLaunchVehicleDropTruck) == 1
            or ScriptGlobal.GetInt(MPGlobalsAmbience.bLaunchVehicleDropAcidLab) == 1 then
            notify("You already have a service vehicle requested")
        end
        ScriptGlobal.SetInt(MPGlobalsAmbience.bLaunchVehicleDropAvenger, 1)
    end

    local requestAvengerRunner = { variant = "donator", feature = "Request Avenger", slug = "request_avenger" }

    function requestAvengerRunner.run(runContext)
        if type(runContext) ~= "table" or not runContext then
            runContext = {}
        end
        return runRequestAvenger(runContext.feature)
    end

    return requestAvengerRunner
end

return createRequestAvengerModule
