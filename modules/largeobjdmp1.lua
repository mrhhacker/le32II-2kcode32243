local function createDropLargeArenaObjectsModule(moduleContext)
    KSRuntimePlayerFeatureState = KSRuntimePlayerFeatureState or {}
    KSRuntimePlayerFeatureState.largeObjects = KSRuntimePlayerFeatureState.largeObjects or {}
    KSRuntimePlayerFeatureState.dumpedObjectsPID = KSRuntimePlayerFeatureState.dumpedObjectsPID or {}
    local largeObjects = KSRuntimePlayerFeatureState.largeObjects
    local playersWithDumpedObjects = KSRuntimePlayerFeatureState.dumpedObjectsPID

    local function runDropLargeArenaObjects(feature)
        local targetPlayerId = feature:GetPlayerIndex()
        local targetPosition = V3.New(ENTITY.GET_ENTITY_COORDS(PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(targetPlayerId), false))
        local gateModelNames = {
            "ar_prop_ar_neon_gate8x_03a",
            "ar_prop_ar_neon_gate8x_04a",
            "ar_prop_ar_neon_gate8x_05a",
        }
        for _, gateModelName in ipairs(gateModelNames) do
            request_model(Utils.Joaat(gateModelName))
        end

        for spawnIndex = 1, 20 do
            local gateModelName = gateModelNames[math.random(#gateModelNames)]
            local gateObject = GTA.CreateObject(gateModelName, targetPosition.x, targetPosition.y, targetPosition.z + math.random(25, 45), true, true)
            if ENTITY.DOES_ENTITY_EXIST(gateObject) then
                OBJECT.SET_ACTIVATE_OBJECT_PHYSICS_AS_SOON_AS_IT_IS_UNFROZEN(gateObject, true)
                PHYSICS.ACTIVATE_PHYSICS(gateObject)
                table.insert(largeObjects, gateObject)
                Script.Yield(5)
            end
            Script.Yield(15)
        end

        for _, gateObject in ipairs(largeObjects) do
            local function repositionGateWhileControlled()
                while NETWORK.NETWORK_HAS_CONTROL_OF_ENTITY(gateObject) do
                    if not NETWORK.NETWORK_HAS_CONTROL_OF_ENTITY(gateObject) then
                        request_control(gateObject)
                    end
                    ENTITY.SET_ENTITY_COORDS_NO_OFFSET(gateObject, targetPosition.x, targetPosition.y, targetPosition.z + 125, false, false, false)
                    Script.Yield(15)
                end
            end
            Script.QueueJob(repositionGateWhileControlled)
        end
        playersWithDumpedObjects[targetPlayerId] = true
    end

    local dropLargeArenaObjectsRunner = { variant = "donator", feature = "largeObjDmp1", slug = "largeobjdmp1" }

    function dropLargeArenaObjectsRunner.run(runContext)
        if type(runContext) ~= "table" or not runContext then
            runContext = {}
        end
        return runDropLargeArenaObjects(runContext.feature)
    end

    return dropLargeArenaObjectsRunner
end

return createDropLargeArenaObjectsModule
