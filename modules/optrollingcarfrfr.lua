local function createAggressiveRcCarModule(moduleContext)
    KSRuntimePlayerFeatureState = KSRuntimePlayerFeatureState or {}
    KSRuntimePlayerFeatureState.largeObjects = KSRuntimePlayerFeatureState.largeObjects or {}
    KSRuntimePlayerFeatureState.dumpedObjectsPID = KSRuntimePlayerFeatureState.dumpedObjectsPID or {}

    local function runAggressiveRcCar(feature)
        if not Utils.GetSelectedPlayer() then
            notify("No player selected!")
            return
        end
        local targetPed = PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(Utils.GetSelectedPlayer())
        local targetPosition = V3.New(ENTITY.GET_ENTITY_COORDS(targetPed, true))
        local rcCarModelHash = Utils.Joaat("rcbandito")
        STREAMING.REQUEST_MODEL(rcCarModelHash)
        while not STREAMING.HAS_MODEL_LOADED(rcCarModelHash) do
            Script.Yield(0)
        end

        local rcCar = GTA.SpawnVehicle(rcCarModelHash,
            targetPosition.x + math.random(-3, 3), targetPosition.y + math.random(-3, 3),
            targetPosition.z + 1.0, 100, true, true)
        if not ENTITY.DOES_ENTITY_EXIST(rcCar) then
            notify("Failed to spawn RC car!")
            return
        end
        ENTITY.SET_ENTITY_INVINCIBLE(rcCar, true)
        VEHICLE.SET_VEHICLE_ENGINE_ON(rcCar, true, true, false)
        ENTITY.SET_ENTITY_AS_MISSION_ENTITY(rcCar, true, true)

        local driverPed = GTA.CreateRandomPed(targetPosition.x, targetPosition.y, targetPosition.z)
        if ENTITY.DOES_ENTITY_EXIST(driverPed) then
            ENTITY.SET_ENTITY_INVINCIBLE(driverPed, true)
            PED.SET_PED_INTO_VEHICLE(driverPed, rcCar, -1)
            PED.SET_PED_COMBAT_ATTRIBUTES(driverPed, 5, true)
            PED.SET_PED_COMBAT_ATTRIBUTES(driverPed, 46, true)
            PED.SET_PED_KEEP_TASK(driverPed, true)
            PED.SET_BLOCKING_OF_NON_TEMPORARY_EVENTS(driverPed, true)
            TASK.SET_DRIVE_TASK_DRIVING_STYLE(driverPed, 524859)
            PED.SET_DRIVER_ABILITY(driverPed, 1.0)
            PED.SET_DRIVER_AGGRESSIVENESS(driverPed, 1.0)

            local function assignPursuitTask()
                TASK.TASK_VEHICLE_MISSION_PED_TARGET(driverPed, rcCar, targetPed, 6, 100.0, 786469, 5.0, 5.0, true)
            end
            assignPursuitTask()
            local function maintainPursuit()
                while ENTITY.DOES_ENTITY_EXIST(rcCar)
                    and ENTITY.DOES_ENTITY_EXIST(driverPed)
                    and ENTITY.DOES_ENTITY_EXIST(targetPed) do
                    assignPursuitTask()
                    Script.Yield(1000)
                end
            end
            Script.QueueJob(maintainPursuit)
            notify("Aggressive RC Car deployed!")
        else
            notify("Failed to create driver!")
            DeleteEnt(rcCar)
        end
        STREAMING.SET_MODEL_AS_NO_LONGER_NEEDED(rcCarModelHash)
    end

    local aggressiveRcCarRunner = { variant = "donator", feature = "OPTrollingCarfrfr", slug = "optrollingcarfrfr" }

    function aggressiveRcCarRunner.run(runContext)
        if type(runContext) ~= "table" or not runContext then
            runContext = {}
        end
        return runAggressiveRcCar(runContext.feature)
    end

    return aggressiveRcCarRunner
end

return createAggressiveRcCarModule
