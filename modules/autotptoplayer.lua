local function createAutoTeleportToPlayerModule(moduleContext)
    KSRuntimePlayerFeatureState = KSRuntimePlayerFeatureState or {}
    KSRuntimePlayerFeatureState.largeObjects = KSRuntimePlayerFeatureState.largeObjects or {}
    KSRuntimePlayerFeatureState.dumpedObjectsPID = KSRuntimePlayerFeatureState.dumpedObjectsPID or {}

    local function runAutoTeleportToPlayer(teleportFeature)
        while teleportFeature:IsToggled() do
            local targetPosition = V3.New(ENTITY.GET_ENTITY_COORDS(
                PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(teleportFeature:GetPlayerIndex())
            ))
            local localPlayerPed = GTA.PointerToHandle(GTA.GetLocalPed())
            ENTITY.SET_ENTITY_COORDS(localPlayerPed, targetPosition.x, targetPosition.y, targetPosition.z, false, false, false)
            Script.Yield(50)
        end
    end

    local autoTeleportToPlayerRunner = { variant = "donator", feature = "AutoTPToPlayer", slug = "autotptoplayer" }

    function autoTeleportToPlayerRunner.run(runContext)
        if type(runContext) ~= "table" or not runContext then
            runContext = {}
        end
        return runAutoTeleportToPlayer(runContext.feature)
    end

    return autoTeleportToPlayerRunner
end

return createAutoTeleportToPlayerModule
