local function createYachtParachuteModelCrashModule(moduleContext)

    local function findRemotePlayer(localPlayerId)
        local selectedPlayerId = tonumber(Utils.GetSelectedPlayer())
        if selectedPlayerId ~= nil and selectedPlayerId ~= localPlayerId
            and Players.GetById(selectedPlayerId) ~= nil then
            return selectedPlayerId
        end
        for playerId = 0, 31 do
            if playerId ~= localPlayerId and Players.GetById(playerId) ~= nil then
                return playerId
            end
        end
        return nil
    end

    local function findBlacklistedPlayer(localPlayerId)
        if isDev then
            return nil
        end
        for playerId = 0, 31 do
            if playerId ~= localPlayerId then
                local player = Players.GetById(playerId)
                if player ~= nil then
                    local gamerInfo = player:GetGamerInfo()
                    if gamerInfo ~= nil and blacklistRIDList[gamerInfo.RockstarId] then
                        return playerId
                    end
                end
            end
        end
        return nil
    end

    local function runYachtParachuteModelCrash(feature)
        local localPlayerId = PLAYER.PLAYER_ID()
        local targetPlayerId = findRemotePlayer(localPlayerId)
        if targetPlayerId == nil then
            notify("1945 Reloaded Crash requires an active remote player.")
            return false, "no_remote_player"
        end
        local protectedPlayerId = findBlacklistedPlayer(localPlayerId)
        if protectedPlayerId ~= nil then
            blacklistSound()
            SendToDiscord("nogger", ("%s(%i) tried to Crash a Blacklisted Player (%s) with 1945 Reloaded Crash!"):format(
                PLAYER.GET_PLAYER_NAME(localPlayerId), Cherax.GetUID(), Players.GetName(protectedPlayerId)
            ))
            return false, "blacklisted_player_in_session"
        end
        local localPlayerPed = PLAYER.PLAYER_PED_ID()
        local targetPed = PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(targetPlayerId)
        if localPlayerPed == 0 or targetPed == 0 then
            return false, "ped_unavailable"
        end
        SendToDiscord("lol", ("%s used 1945 Reloaded Crash against Session with UID %i, isSupporter: %s"):format(
            PLAYER.GET_PLAYER_NAME(localPlayerId), Cherax.GetUID(), tostring(isSupporter)
        ))

        local originalPosition = V3.New(ENTITY.GET_ENTITY_COORDS(localPlayerPed, false))
        local targetPosition = V3.New(ENTITY.GET_ENTITY_COORDS(targetPed, false))
        local yachtModelHash = Utils.Joaat("apa_mp_apa_yacht")
        local parachuteModelHash = Utils.Joaat("p_parachute1_mp_dec")
        STREAMING.REQUEST_MODEL(parachuteModelHash)
        while not STREAMING.HAS_MODEL_LOADED(parachuteModelHash) do
            Script.Yield(10)
        end
        ENTITY.SET_ENTITY_COORDS_NO_OFFSET(localPlayerPed, targetPosition.x, targetPosition.y, targetPosition.z + 300.0, false, false, false)
        Script.Yield(500)
        WEAPON.GIVE_DELAYED_WEAPON_TO_PED(localPlayerPed, Utils.Joaat("GADGET_PARACHUTE"), 100, false)
        PLAYER.SET_PLAYER_PARACHUTE_MODEL_OVERRIDE(localPlayerId, yachtModelHash)
        Script.Yield(50)
        TASK.CLEAR_PED_TASKS_IMMEDIATELY(localPlayerPed)
        TASK.TASK_PARACHUTE(localPlayerPed, true)
        repeat
            Script.Yield(10)
        until PED.GET_PED_PARACHUTE_STATE(localPlayerPed) == 0
        TASK.TASK_PARACHUTE(localPlayerPed, true)
        Script.Yield(1000)
        TASK.CLEAR_PED_TASKS_IMMEDIATELY(localPlayerPed)
        ENTITY.SET_ENTITY_COORDS_NO_OFFSET(localPlayerPed, originalPosition.x, originalPosition.y, originalPosition.z, false, false, false)
        PLAYER.CLEAR_PLAYER_PARACHUTE_MODEL_OVERRIDE(localPlayerId)
        PLAYER.CLEAR_PLAYER_PARACHUTE_VARIATION_OVERRIDE(localPlayerId)
        PLAYER.SET_PLAYER_RESERVE_PARACHUTE_MODEL_OVERRIDE(localPlayerId, parachuteModelHash)
        STREAMING.SET_MODEL_AS_NO_LONGER_NEEDED(parachuteModelHash)
        return true, "completed"
    end

    local yachtParachuteModelCrashRunner = { variant = "donator", feature = "YachtParachuteCrash", slug = "yachtparachutecrash" }

    function yachtParachuteModelCrashRunner.run(runContext)
        if type(runContext) ~= "table" or not runContext then
            runContext = {}
        end
        return runYachtParachuteModelCrash(runContext.feature)
    end

    return yachtParachuteModelCrashRunner
end

return createYachtParachuteModelCrashModule
