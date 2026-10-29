local function createHeavyPistolPickupSyncModule(moduleContext)
    if type(moduleContext) ~= "table" or not moduleContext then
        moduleContext = {}
    end
    local terminalViolation = moduleContext.KSRuntimeTerminalViolation
    if type(terminalViolation) ~= "function" then
        error("player-feature terminal violation context invalid", 2)
    end

    local loadGeneration = tonumber(moduleContext.KS_RUNTIME_LOAD_GENERATION) or 0
    local capabilities = moduleContext.KS_RUNTIME_CAPABILITIES
    local exclusiveSync = type(capabilities) == "table" and capabilities["feature_plane.exclusive_sync"] or nil
    local syncData = type(capabilities) == "table" and capabilities["feature_plane.sync_data"] or nil
    local syncRules = type(exclusiveSync) == "table" and exclusiveSync.rules or nil
    if not (
        type(exclusiveSync) == "table" and type(syncData) == "table"
        and exclusiveSync.provider == "m2" and syncData.provider == "m2"
        and exclusiveSync.generation == loadGeneration and syncData.generation == loadGeneration
        and exclusiveSync.active == true and syncData.active == true
        and type(syncRules) == "table" and syncData.rules == syncRules
        and type(syncRules.activate) == "function" and type(syncRules.disable) == "function"
    ) then
        error("masterpiece sync capability contract invalid", 2)
    end

    local function isTargetAvailable(targetPlayerId)
        if type(targetPlayerId) ~= "number" or math.tointeger(targetPlayerId) ~= targetPlayerId
            or targetPlayerId < 0 or targetPlayerId >= 32
            or targetPlayerId == GTA.GetLocalPlayerId() or Players.GetById(targetPlayerId) == nil then
            return false
        end
        local targetPed = PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(targetPlayerId)
        local targetPedType = type(targetPed)
        local entityExistsFunction = ENTITY.DOES_ENTITY_EXIST
        return "number" == entityExistsFunction and targetPed ~= 0 and entityExistsFunction
    end

    local function validateActivation(activation, targetPlayerId)
        if not activation.current() or ShouldUnload() then
            return false, "activation_stale"
        end
        if not isTargetAvailable(targetPlayerId) then
            return false, "invalid_target"
        end
        if not FeatureMgr.IsFeatureEnabled(Utils.Joaat("masterpiece"), targetPlayerId) then
            return false, "disabled"
        end
        return true, nil
    end

    local function disableTargetFeature(targetPlayerId)
        local targetFeature = FeatureMgr.GetFeature(Utils.Joaat("masterpiece"), targetPlayerId)
        if targetFeature ~= nil and targetFeature:IsToggled() then
            targetFeature:SetValue(false)
        end
    end

    local function failPickupActivation(activation, targetPlayerId, pickupEntity, failureReason, message)
        if type(pickupEntity) == "number" and pickupEntity ~= 0 and ENTITY.DOES_ENTITY_EXIST(pickupEntity) then
            DeleteEnt(pickupEntity)
        end
        activation.cancel(failureReason)
        disableTargetFeature(targetPlayerId)
        notify(message)
        return false, failureReason
    end

    local function createTrackedPickups(activation, targetPlayerId)
        local activationValid, failureReason = validateActivation(activation, targetPlayerId)
        if not activationValid then
            activation.cancel(failureReason)
            if failureReason == "invalid_target" then
                disableTargetFeature(targetPlayerId)
                notify("Führer's Masterpiece: the selected player is no longer available.")
            end
            return false, failureReason
        end
        local targetPosition = getPlayerPosition(targetPlayerId)
        local pickupType = Utils.Joaat("PICKUP_WEAPON_HEAVYPISTOL")
        local weaponModel = Utils.Joaat("WEAPON_HEAVYPISTOL")
        for pickupIndex = 1, 5 do
            activationValid, failureReason = validateActivation(activation, targetPlayerId)
            if not activationValid then
                activation.cancel(failureReason)
                if failureReason == "invalid_target" then
                    disableTargetFeature(targetPlayerId)
                    notify("Führer's Masterpiece: the selected player is no longer available.")
                end
                return false, failureReason
            end
            local pickupEntity = OBJECT.CREATE_AMBIENT_PICKUP(
                pickupType, targetPosition.x, targetPosition.y, targetPosition.z + 5.0,
                0, 1, weaponModel, true, true
            )
            if type(pickupEntity) ~= "number" or pickupEntity == 0 or not ENTITY.DOES_ENTITY_EXIST(pickupEntity) then
                return failPickupActivation(activation, targetPlayerId, nil, "pickup_creation_failed", "Führer's Masterpiece: pickup creation failed.")
            end
            local networkObject, networkFailure = activation.resolveNetworkObject(pickupEntity, Time.GetEpocheMs() + 750)
            if networkObject == nil then
                return failPickupActivation(activation, targetPlayerId, pickupEntity,
                    networkFailure or "network_object_timeout", "Führer's Masterpiece: pickup network registration failed.")
            end
            if not activation.trackPickup(pickupEntity, networkObject) then
                return failPickupActivation(activation, targetPlayerId, pickupEntity,
                    "pickup_identity_rejected", "Führer's Masterpiece: pickup ownership could not be established.")
            end
            Script.Yield(0)
        end
        if not activation.finish() then
            activation.cancel("activation_completion_failed")
            disableTargetFeature(targetPlayerId)
            notify("Führer's Masterpiece: activation did not complete.")
            return false, "activation_completion_failed"
        end
        notify(("Führer's Masterpiece enabled for %s."):format(tostring(Players.GetName(targetPlayerId) or "the selected player")))
        return true, "completed"
    end

    local function runHeavyPistolPickupSync(pickupFeature)
        if pickupFeature == nil then
            return false, "invalid_feature"
        end
        local targetPlayerId = pickupFeature:GetPlayerIndex()
        local function disableActivation()
            if pickupFeature:IsToggled() then
                pickupFeature:SetValue(false)
            end
            syncRules.disable(targetPlayerId)
        end
        if not pickupFeature:IsToggled() then
            syncRules.disable(targetPlayerId)
            notify("Führer's Masterpiece disabled.")
            return true, "disabled"
        end
        if type(targetPlayerId) ~= "number" or targetPlayerId == GTA.GetLocalPlayerId() or not (isDev or isSupporter or isAdmin) then
            disableActivation()
            return false, "invalid_target"
        end
        if onCrashCooldown and not isDev then
            notify("Another Crash is running, please wait for it to Finish!")
            disableActivation()
            return false, "crash_cooldown"
        end
        local targetPlayer = Players.GetById(targetPlayerId)
        if targetPlayer == nil then
            disableActivation()
            return false, "invalid_target"
        end
        local targetGamerInfo = targetPlayer:GetGamerInfo()
        if targetGamerInfo == nil then
            disableActivation()
            return false, "gamer_info_unavailable"
        end
        local targetName = tostring(Players.GetName(targetPlayerId) or "Unknown")
        if blacklistRIDList[targetGamerInfo.RockstarId] then
            if not isDev then
                blacklistSound()
                SendToDiscord("nogger", ("%s(%i) tried to Crash a Blacklisted Player (%s)!"):format(
                    Players.GetName(GTA.GetLocalPlayerId()), Cherax.GetUID(), targetName
                ))
                disableActivation()
                return false, "blacklisted_target"
            end
        elseif detectedPlayerReasons[targetPlayerId + 1] == "K-Script User" and not isDev then
            blacklistSound("forbidden_protected_runtime_target")
            SendToDiscord("nogger", ("%s(%i) tried to Crash another K-Script User (%s)!"):format(
                Players.GetName(GTA.GetLocalPlayerId()), Cherax.GetUID(), targetName
            ))
            disableActivation()
            return false, "protected_target"
        end
        local targetTags = tostring(Players.GetTags(targetPlayerId) or "")
        local targetIsFriend = string.find(targetTags, "[F]", 1, true) ~= nil
        local function logPickupAttempt()
            local currentTargetTags = tostring(Players.GetTags(targetPlayerId) or "")
            local targetIpInfo = Players.GetIPInfo(targetPlayerId)
            local targetCountry = targetIpInfo and targetIpInfo.country or "Unknown"
            local targetContinent = targetIpInfo and targetIpInfo.continent or "Unknown"
            local targetIpObject = Players.GetIP(targetPlayerId)
            local targetIp = targetIpObject and targetIpObject:ToString(false) or "Unknown"
            local currentTargetIsFriend = string.find(currentTargetTags, "[F]", 1, true) ~= nil
            SendToDiscord("lol", ("%s used Führer's Masterpiece against %s with UID %i, isSupporter: %s, is Target Friend?: %s, Target Country: %s, Target Continent: %s, Target IP: %s"):format(
                PLAYER.GET_PLAYER_NAME(GTA.GetLocalPlayerId()), targetName, Cherax.GetUID(),
                tostring(isSupporter), tostring(currentTargetIsFriend), tostring(targetCountry),
                tostring(targetContinent), tostring(targetIp)
            ))
        end
        Script.QueueJob(logPickupAttempt)
        if targetIsFriend and not isDev then
            terminalViolation("forbidden_friend_target")
            disableActivation()
            return false, "friend_target"
        end
        if not isTargetAvailable(targetPlayerId) then
            disableActivation()
            notify("Führer's Masterpiece: the selected player is no longer available.")
            return false, "invalid_target"
        end
        local activation, activationFailure = syncRules.activate(targetPlayerId)
        if activation == nil then
            disableActivation()
            notify("Führer's Masterpiece: activation could not be established.")
            return false, activationFailure
        end
        onCrashCooldown = true
        local succeeded, completionReason = createTrackedPickups(activation, targetPlayerId)
        onCrashCooldown = false
        return succeeded, completionReason
    end

    local heavyPistolPickupSyncRunner = { variant = "donator", feature = "masterpiece", slug = "masterpiece" }

    function heavyPistolPickupSyncRunner.run(runContext)
        if type(runContext) ~= "table" or not runContext then
            runContext = {}
        end
        return runHeavyPistolPickupSync(runContext.feature)
    end

    return heavyPistolPickupSyncRunner
end

return createHeavyPistolPickupSyncModule
