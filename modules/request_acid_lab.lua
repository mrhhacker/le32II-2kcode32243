local function createRequestAcidLabModule(moduleContext)
    KSRuntimeFeatureState = KSRuntimeFeatureState or {}
    KSRuntimeFeatureState.largeObjects = KSRuntimeFeatureState.largeObjects or {}
    KSRuntimeFeatureState.dumpedObjectsPID = KSRuntimeFeatureState.dumpedObjectsPID or {}
    KSRuntimeFeatureState.windmills = KSRuntimeFeatureState.windmills or yeetwindmills or {}
    yeetwindmills = KSRuntimeFeatureState.windmills

    local function runRequestAcidLab()
        if ScriptGlobal.GetInt(MPGlobalsAmbience.bLaunchVehicleDropAcidLab) == 1 then
            return
        end

        if ScriptGlobal.GetInt(MPGlobalsAmbience.bLaunchVehicleDropSubmarine) == 1
            or ScriptGlobal.GetInt(MPGlobalsAmbience.bLaunchVehicleDropAvenger) == 1
            or ScriptGlobal.GetInt(MPGlobalsAmbience.bLaunchVehicleDropHackerTruck) == 1
            or ScriptGlobal.GetInt(MPGlobalsAmbience.bLaunchVehicleDropTruck) == 1 then
            notify("You already have a service vehicle requested")
        end
        ScriptGlobal.SetInt(MPGlobalsAmbience.bLaunchVehicleDropAcidLab, 1)
    end

    local requestAcidLabRunner = { variant = "donator", feature = "Request Acid Lab", slug = "request_acid_lab" }

    function requestAcidLabRunner.run(runContext)
        if type(runContext) ~= "table" or not runContext then
            runContext = {}
        end
        return runRequestAcidLab(runContext.feature)
    end

    return requestAcidLabRunner
end

return createRequestAcidLabModule
