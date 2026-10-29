local function createRequestTerrorbyteModule(moduleContext)
    KSRuntimeFeatureState = KSRuntimeFeatureState or {}
    KSRuntimeFeatureState.largeObjects = KSRuntimeFeatureState.largeObjects or {}
    KSRuntimeFeatureState.dumpedObjectsPID = KSRuntimeFeatureState.dumpedObjectsPID or {}
    KSRuntimeFeatureState.windmills = KSRuntimeFeatureState.windmills or yeetwindmills or {}
    yeetwindmills = KSRuntimeFeatureState.windmills

    local function runRequestTerrorbyte()
        if ScriptGlobal.GetInt(MPGlobalsAmbience.bLaunchVehicleDropHackerTruck) == 1 then
            return
        end

        if ScriptGlobal.GetInt(MPGlobalsAmbience.bLaunchVehicleDropSubmarine) == 1
            or ScriptGlobal.GetInt(MPGlobalsAmbience.bLaunchVehicleDropAvenger) == 1
            or ScriptGlobal.GetInt(MPGlobalsAmbience.bLaunchVehicleDropTruck) == 1
            or ScriptGlobal.GetInt(MPGlobalsAmbience.bLaunchVehicleDropAcidLab) == 1 then
            notify("You already have a service vehicle requested")
        end
        ScriptGlobal.SetInt(MPGlobalsAmbience.bLaunchVehicleDropHackerTruck, 1)
    end

    local requestTerrorbyteRunner = { variant = "donator", feature = "Request Terrobyte", slug = "request_terrobyte" }

    function requestTerrorbyteRunner.run(runContext)
        if type(runContext) ~= "table" or not runContext then
            runContext = {}
        end
        return runRequestTerrorbyte(runContext.feature)
    end

    return requestTerrorbyteRunner
end

return createRequestTerrorbyteModule
