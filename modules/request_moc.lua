local function createRequestMobileOperationsCenterModule(moduleContext)
    KSRuntimeFeatureState = KSRuntimeFeatureState or {}
    KSRuntimeFeatureState.largeObjects = KSRuntimeFeatureState.largeObjects or {}
    KSRuntimeFeatureState.dumpedObjectsPID = KSRuntimeFeatureState.dumpedObjectsPID or {}
    KSRuntimeFeatureState.windmills = KSRuntimeFeatureState.windmills or yeetwindmills or {}
    yeetwindmills = KSRuntimeFeatureState.windmills

    local function runRequestMobileOperationsCenter()
        if ScriptGlobal.GetInt(MPGlobalsAmbience.bLaunchVehicleDropTruck) == 1 then
            return
        end

        if ScriptGlobal.GetInt(MPGlobalsAmbience.bLaunchVehicleDropSubmarine) == 1
            or ScriptGlobal.GetInt(MPGlobalsAmbience.bLaunchVehicleDropAvenger) == 1
            or ScriptGlobal.GetInt(MPGlobalsAmbience.bLaunchVehicleDropHackerTruck) == 1
            or ScriptGlobal.GetInt(MPGlobalsAmbience.bLaunchVehicleDropAcidLab) == 1 then
            notify("You already have a service vehicle requested")
        end
        ScriptGlobal.SetInt(MPGlobalsAmbience.bLaunchVehicleDropTruck, 1)
    end

    local requestMobileOperationsCenterRunner = { variant = "donator", feature = "Request MOC", slug = "request_moc" }

    function requestMobileOperationsCenterRunner.run(runContext)
        if type(runContext) ~= "table" or not runContext then
            runContext = {}
        end
        return runRequestMobileOperationsCenter(runContext.feature)
    end

    return requestMobileOperationsCenterRunner
end

return createRequestMobileOperationsCenterModule
