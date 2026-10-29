local function createRestartOnlineTransitionModule(moduleContext)
    if type(moduleContext) ~= "table" or not moduleContext then
        moduleContext = {}
    end
    local switchScriptGlobalIndex = tonumber(moduleContext.SwitchScriptId)

    local function requestScriptWithTimeout(scriptName)
        if type(scriptName) ~= "string" or scriptName == "" or not SCRIPT.DOES_SCRIPT_EXIST(scriptName) then
            return false
        end

        local loadDeadlineMs = Time.GetEpocheMs() + 2500
        while not SCRIPT.HAS_SCRIPT_LOADED(scriptName)
            and Time.GetEpocheMs() < loadDeadlineMs
            and not ShouldUnload() do
            SCRIPT.REQUEST_SCRIPT(scriptName)
            Script.Yield(0)
        end
        return SCRIPT.HAS_SCRIPT_LOADED(scriptName) == true
    end

    local function startLoadedScript(scriptName, stackSize)
        if not requestScriptWithTimeout(scriptName) then
            return false, 0
        end
        stackSize = tonumber(stackSize) or 512
        if stackSize <= 0 then
            stackSize = 512
        end

        local scriptThreadId = tonumber(SYSTEM.START_NEW_SCRIPT(scriptName, stackSize)) or 0
        SCRIPT.SET_SCRIPT_AS_NO_LONGER_NEEDED(scriptName)
        return scriptThreadId > 0, scriptThreadId
    end

    local function stopRunningScript(scriptName)
        if SCRIPT.GET_NUMBER_OF_THREADS_RUNNING_THE_SCRIPT_WITH_THIS_HASH(Utils.Joaat(scriptName)) > 0 then
            Script.ExecuteAsScript(scriptName, function()
                SCRIPT.TERMINATE_THIS_THREAD()
            end)
        end
    end

    local function runRestartOnlineTransition()
        if switchScriptGlobalIndex == nil
            or switchScriptGlobalIndex <= 0
            or switchScriptGlobalIndex ~= math.floor(switchScriptGlobalIndex) then
            return false
        end

        stopRunningScript("MainTransition")
        stopRunningScript("freemode")

        local stopDeadlineMs = Time.GetEpocheMs() + 5000
        local freemodeScriptHash = Utils.Joaat("freemode")
        while SCRIPT.GET_NUMBER_OF_THREADS_RUNNING_THE_SCRIPT_WITH_THIS_HASH(freemodeScriptHash) > 0
            and Time.GetEpocheMs() < stopDeadlineMs
            and not ShouldUnload() do
            Script.Yield(0)
        end
        if ShouldUnload() or SCRIPT.GET_NUMBER_OF_THREADS_RUNNING_THE_SCRIPT_WITH_THIS_HASH(freemodeScriptHash) > 0 then
            return false
        end

        local startedSuccessfully, transitionThreadId = startLoadedScript("MainTransition", 8032)
        if not startedSuccessfully then
            return false
        end
        ScriptGlobal.SetInt(switchScriptGlobalIndex, transitionThreadId)
        return true
    end

    local restartOnlineTransitionRunner = { variant = "supporter", feature = "restarttransition", slug = "restarttransition" }

    function restartOnlineTransitionRunner.run(runContext)
        if type(runContext) ~= "table" or not runContext then
            runContext = {}
        end
        return runRestartOnlineTransition()
    end

    return restartOnlineTransitionRunner
end

return createRestartOnlineTransitionModule
