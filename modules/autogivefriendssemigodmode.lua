local function createAutoGiveFriendsSemiGodmodeModule(moduleContext)
    KSRuntimeFeatureState = KSRuntimeFeatureState or {}
    KSRuntimeFeatureState.largeObjects = KSRuntimeFeatureState.largeObjects or {}
    KSRuntimeFeatureState.dumpedObjectsPID = KSRuntimeFeatureState.dumpedObjectsPID or {}
    KSRuntimeFeatureState.windmills = KSRuntimeFeatureState.windmills or yeetwindmills or {}
    yeetwindmills = KSRuntimeFeatureState.windmills

    local function runAutoGiveFriendsSemiGodmode(autoGiveFeature)
        while autoGiveFeature:IsToggled() do
            for _, playerId in pairs(Players.Get()) do
                if IsPlayerFriend(playerId) then
                    local semiGodmodeFeature = FeatureMgr.GetFeature(Utils.Joaat("RemoteSemiGodMode"), playerId)
                    if semiGodmodeFeature:GetBoolValue() == true then
                        return
                    end
                    notify(("Giving semi-godmode to friend: %s"):format(Players.GetName(playerId)))
                    semiGodmodeFeature:SetBoolValue(true):OnClick()
                end
            end
            Script.Yield(1000)
        end
    end

    local autoGiveFriendsSemiGodmodeRunner = { variant = "donator", feature = "AutoGiveFriendsSemiGodmode", slug = "autogivefriendssemigodmode" }

    function autoGiveFriendsSemiGodmodeRunner.run(runContext)
        if type(runContext) ~= "table" or not runContext then
            runContext = {}
        end
        return runAutoGiveFriendsSemiGodmode(runContext.feature)
    end

    return autoGiveFriendsSemiGodmodeRunner
end

return createAutoGiveFriendsSemiGodmodeModule
