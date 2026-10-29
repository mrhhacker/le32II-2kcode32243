local function createSavePlayerNoteModule(moduleContext)
    KSRuntimePlayerFeatureState = KSRuntimePlayerFeatureState or {}
    KSRuntimePlayerFeatureState.largeObjects = KSRuntimePlayerFeatureState.largeObjects or {}
    KSRuntimePlayerFeatureState.dumpedObjectsPID = KSRuntimePlayerFeatureState.dumpedObjectsPID or {}

    local function runSavePlayerNote()
        local selectedPlayerId = Utils.GetSelectedPlayer()
        if not selectedPlayerId then
            notify("No Player Selected!")
            return
        end

        local selectedPlayerPed = Players.GetCPed(selectedPlayerId)
        if not selectedPlayerPed then
            notify("Invalid player!")
            return
        end

        local noteRockstarId = getLocalRockstarId()
        if not noteRockstarId then
            notify("Failed to get Rockstar ID!")
            return
        end

        local playerNoteFeature = FeatureMgr.GetFeature(Utils.Joaat("PlayerNote"), selectedPlayerId)
        if not playerNoteFeature then
            notify("Player Note Feature not found!")
            return
        end

        local noteText = playerNoteFeature:GetStringValue()
        local playerName = Players.GetName(selectedPlayerId) or SOCIALCLUB.SC_ACCOUNT_INFO_GET_NICKNAME() or "Unknown"
        local lastSeenTimestamp = os.time()
        local notesFilePath = FileMgr.GetMenuRootPath() .. "\\Lua\\K-Script\\PlayerNotes.json"
        local notesByRockstarId = {}
        if FileMgr.DoesFileExist(notesFilePath) then
            local existingNotesJson = FileMgr.ReadFileContent(notesFilePath)
            if existingNotesJson and existingNotesJson ~= "" then
                local decodedNotes = json.decode(existingNotesJson)
                if type(decodedNotes) == "table" then
                    notesByRockstarId = decodedNotes
                end
            end
        end

        notesByRockstarId[tostring(noteRockstarId)] = {
            rockstar_id = noteRockstarId,
            player_name = playerName,
            note = noteText,
            GameVersion = isGameVersionEnhanced and "Enhanced" or "Legacy",
            last_seen = lastSeenTimestamp
        }

        local encodedNotesJson = nil
        local encodedSuccessfully = pcall(function()
            encodedNotesJson = json.encode(notesByRockstarId, { indent = true })
        end)
        if not encodedSuccessfully then
            notify("Failed to JSON encode DefaultConfig.json!")
            return
        end

        FileMgr.WriteFileContent(notesFilePath, encodedNotesJson)
        notify(("Saved note for %s"):format(playerName))
    end

    local savePlayerNoteRunner = { variant = "donator", feature = "SavePlayerNote", slug = "saveplayernote" }

    function savePlayerNoteRunner.run(runContext)
        if type(runContext) ~= "table" or not runContext then
            runContext = {}
        end
        return runSavePlayerNote(runContext.feature)
    end

    return savePlayerNoteRunner
end

return createSavePlayerNoteModule
