local loaderAdapter, isTableOrUserdata, yieldClampedMs, backendBaseUrl, sessionHeaderToken, runtimeSessionContext, getBackendRequestSpec, getRequestTimeoutSeconds, validateRequestAuth, validateResponseFields, getMonotonicSeconds, waitForCurlFinished, loaderLoadGeneration, isRuntimeGenerationCurrent, startupProgressState, recordUnloadReason, logStartupMessage, logStartupFeatureStage, setStartupPhase, setStartupModuleId, failStartup, markStartupReady, requestScriptUnload
do
    function U_QJL1k9vSdRf1pmOVBvVi8HBwOyT42vYBWXmD(encodedBlob)
        local function maskToByte(unmaskedNumber)
            return (unmaskedNumber or 0) & 255
        end

        local function readUint32LE(byteOffset)
            local lowByte, midLowByte, midHighByte, highByte = encodedBlob:byte(byteOffset, byteOffset + 3)
            return maskToByte(lowByte) | maskToByte(midLowByte) << 8 | maskToByte(midHighByte) << 16 | maskToByte(highByte) << 24
        end

        local decodedChars = {}
        local cipherMode = maskToByte(encodedBlob:byte(1))
        local keySeed = readUint32LE(2)
        local keyMultiplier = maskToByte(encodedBlob:byte(6))
        local keyOffset = maskToByte(encodedBlob:byte(7))
        local mixOffset = maskToByte(encodedBlob:byte(8))
        local expectedLength = readUint32LE(9)
        for blobIndex = 13, #encodedBlob do
            local payloadIndex = blobIndex - 12
            local primaryKeyByte = maskToByte(keySeed + payloadIndex * keyMultiplier + keyOffset)
            local secondaryKeyByte = maskToByte((keySeed >> payloadIndex % 4 * 8) + payloadIndex * 13 + mixOffset)
            local encodedByte = encodedBlob:byte(blobIndex)
            local decodedByte
            if cipherMode == 0 then
                decodedByte = maskToByte(encodedByte ~ primaryKeyByte ~ secondaryKeyByte)
            elseif cipherMode == 1 then
                decodedByte = maskToByte((encodedByte ~ secondaryKeyByte) - primaryKeyByte)
            elseif cipherMode == 2 then
                decodedByte = maskToByte(encodedByte + secondaryKeyByte ~ primaryKeyByte)
            else
                decodedByte = maskToByte((encodedByte ~ primaryKeyByte) - secondaryKeyByte)
            end
            decodedChars[#decodedChars + 1] = string.char(decodedByte)
        end
        if expectedLength and #decodedChars ~= expectedLength then
            return ""
        end
        return table.concat(decodedChars)
    end

    loaderAdapter = __ks_bridge_v3

    function isTableOrUserdata(candidate)
        local candidateType = type(candidate)
        return candidateType == "table" or candidateType == "userdata"
    end

    function yieldClampedMs(requestedMs, fallbackMs)
        local delayMs = tonumber(requestedMs)
        if delayMs == nil or delayMs ~= delayMs then
            delayMs = tonumber(fallbackMs) or 0
        end
        local clampedMs = math.max(0, math.min(delayMs, 2147483647))
        return Script.Yield(math.tointeger(math.ceil(clampedMs)))
    end

    function KSBridgeOnPolicyUpdate(policyUpdate)
    end

    KSStaffNotificationState = { queue = {}, seen = {}, seenOrder = {}, handler = nil, acknowledging = false, errorText = nil }

    function KSStaffNotificationValid(notification)
        if type(notification) ~= "table" then
            return false
        end
        local allowedFields = {
            v = true,
            notification_id = true,
            type = true,
            message = true,
            sender_label = true,
            created_at_ms = true,
            expires_at_ms = true,
            requires_acknowledgement = true,
        }
        local fieldCount = 0
        for fieldName in pairs(notification) do
            if not allowedFields[fieldName] then
                return false
            end
            fieldCount = fieldCount + 1
        end
        if fieldCount ~= 8 or notification.v ~= 1 or type(notification.notification_id) ~= "string" or #notification.notification_id ~= 32 or not notification.notification_id:match("^[0-9a-f]+$") or notification.type ~= "MESSAGE" and notification.type ~= "WARNING" or type(notification.message) ~= "string" or #notification.message < 1 or #notification.message > 4000 or notification.message:find("[%z\x01-\x08\x0b\x0c\x0e-\x1f\x7f]") or notification.sender_label ~= "K-Script Staff" or type(notification.created_at_ms) ~= "number" or math.type(notification.created_at_ms) ~= "integer" or type(notification.expires_at_ms) ~= "number" or math.type(notification.expires_at_ms) ~= "integer" or notification.created_at_ms <= 0 or notification.expires_at_ms <= notification.created_at_ms or notification.expires_at_ms - notification.created_at_ms > 7862400000 or type(notification.requires_acknowledgement) ~= "boolean" or notification.requires_acknowledgement ~= (notification.type == "WARNING") then
            return false
        end
        return utf8.len(notification.message) ~= nil
    end

    KSStaffNotificationSoundPaths = {}

    function KSStaffNotificationLittleEndian(numberToEncode, byteCount)
        local byteChars = {}
        numberToEncode = math.floor(tonumber(numberToEncode) or 0)
        for byteIndex = 1, byteCount do
            byteChars[byteIndex] = string.char(numberToEncode % 256)
            numberToEncode = math.floor(numberToEncode / 256)
        end
        return table.concat(byteChars)
    end

    function KSStaffNotificationBuildTone(notificationType)
        local sampleRate = 22050
        local isWarning = notificationType == "WARNING"
        local toneDurationSeconds = isWarning and 0.46 or 0.28
        local amplitude = isWarning and 0.22 or 0.16
        local sampleChunks = {}
        local oscillatorPhase = 0
        for sampleIndex = 0, math.floor(sampleRate * toneDurationSeconds) - 1 do
            local sampleTime = sampleIndex / sampleRate
            local frequencyHz = nil
            local volumeGate = 1.0
            if isWarning then
                if sampleTime < 0.16 then
                    frequencyHz = 520
                elseif sampleTime < 0.22 then
                    frequencyHz = 520
                    volumeGate = 0
                else
                    frequencyHz = 350
                end
            elseif not (sampleTime < 0.12) or not 720 then
                frequencyHz = 960
            end
            oscillatorPhase = oscillatorPhase + 2 * math.pi * frequencyHz / sampleRate
            local fadeIn = math.min(1.0, sampleTime / 0.012)
            local fadeOut = math.min(1.0, (toneDurationSeconds - sampleTime) / 0.055)
            local volumeEnvelope = math.max(0, math.min(fadeIn, fadeOut))
            local pcmSample = math.floor(math.sin(oscillatorPhase) * amplitude * volumeGate * volumeEnvelope * 32767)
            if pcmSample < 0 then
                pcmSample = pcmSample + 65536
            end
            sampleChunks[#sampleChunks + 1] = KSStaffNotificationLittleEndian(pcmSample, 2)
        end
        local pcmBytes = table.concat(sampleChunks)
        return "RIFF" .. KSStaffNotificationLittleEndian(36 + #pcmBytes, 4) .. "WAVE" .. "fmt " .. KSStaffNotificationLittleEndian(16, 4) .. KSStaffNotificationLittleEndian(1, 2) .. KSStaffNotificationLittleEndian(1, 2) .. KSStaffNotificationLittleEndian(sampleRate, 4) .. KSStaffNotificationLittleEndian(sampleRate * 2, 4) .. KSStaffNotificationLittleEndian(2, 2) .. KSStaffNotificationLittleEndian(16, 2) .. "data" .. KSStaffNotificationLittleEndian(#pcmBytes, 4) .. pcmBytes
    end

    function KSStaffNotificationEnsureSound(notificationType)
        local soundKind = notificationType == "WARNING" and "WARNING" or "MESSAGE"
        if KSStaffNotificationSoundPaths[soundKind] ~= nil then
            return KSStaffNotificationSoundPaths[soundKind]
        end
        if not isTableOrUserdata(FileMgr) or type(FileMgr.GetMenuRootPath) ~= "function" or type(FileMgr.CreateDir) ~= "function" or type(FileMgr.DoesFileExist) ~= "function" or not isTableOrUserdata(io) or type(io.open) ~= "function" then
            return nil
        end
        local soundsDir = FileMgr.GetMenuRootPath() .. "\\Lua\\K-Script\\sounds\\"
        local soundFilePath = soundsDir .. (soundKind == "WARNING" and "staff-warning-v1.wav" or "staff-message-v1.wav")
        FileMgr.CreateDir(soundsDir)
        if not FileMgr.DoesFileExist(soundFilePath) then
            local wavFile = io.open(soundFilePath, "wb")
            if not wavFile then
                return nil
            end
            wavFile:write(KSStaffNotificationBuildTone(soundKind))
            wavFile:close()
        end
        KSStaffNotificationSoundPaths[soundKind] = soundFilePath
        return soundFilePath
    end

    function KSStaffNotificationPlaySound(notificationType)
        if not isTableOrUserdata(Utils) or type(Utils.PlaySound) ~= "function" then
            return false
        end
        local soundPath = KSStaffNotificationEnsureSound(notificationType)
        if soundPath == nil then
            return false
        end
        local playOk, playResult = pcall(Utils.PlaySound, soundPath, false)
        return playOk and playResult ~= false
    end

    function KSStaffNotificationReleaseInput()
        if type(KScriptTosReleaseMouseCursor) == "function" then
            KScriptTosReleaseMouseCursor()
        end
    end

    function KSStaffNotificationCaptureInput()
        if type(KScriptTosCaptureMouseCursor) == "function" then
            KScriptTosCaptureMouseCursor()
            return
        end
        if type(ImGui.SetMouseCursor) == "function" then
            ImGui.SetMouseCursor(ImGuiMouseCursor.Arrow)
        end
        ImGui.CaptureMouseFromApp(true)
        HUD.DISABLE_FRONTEND_THIS_FRAME()
        PAD.DISABLE_ALL_CONTROL_ACTIONS(0)
        PAD.DISABLE_ALL_CONTROL_ACTIONS(1)
    end

    function KSStaffNotificationDrawMouseCursor()
        if type(KScriptTosDrawMouseCursor) == "function" then
            KScriptTosDrawMouseCursor(1.0)
            return
        end
        local mouseX, mouseY = ImGui.GetMousePos()
        ImGui.AddLine(mouseX - 1, mouseY - 1, mouseX - 1, mouseY + 20, 0, 0, 0, 235, 3)
        ImGui.AddLine(mouseX - 1, mouseY - 1, mouseX + 14, mouseY + 11, 0, 0, 0, 235, 3)
        ImGui.AddLine(mouseX + 14, mouseY + 11, mouseX + 8, mouseY + 12, 0, 0, 0, 235, 3)
        ImGui.AddLine(mouseX + 8, mouseY + 12, mouseX + 12, mouseY + 20, 0, 0, 0, 235, 3)
        ImGui.AddLine(mouseX + 12, mouseY + 20, mouseX + 8, mouseY + 22, 0, 0, 0, 235, 3)
        ImGui.AddLine(mouseX + 8, mouseY + 22, mouseX + 4, mouseY + 14, 0, 0, 0, 235, 3)
        ImGui.AddLine(mouseX + 4, mouseY + 14, mouseX - 1, mouseY + 20, 0, 0, 0, 235, 3)
        ImGui.AddLine(mouseX, mouseY, mouseX, mouseY + 18, 245, 247, 250, 255, 1.6)
        ImGui.AddLine(mouseX, mouseY, mouseX + 12, mouseY + 10, 245, 247, 250, 255, 1.6)
        ImGui.AddLine(mouseX + 12, mouseY + 10, mouseX + 6, mouseY + 11, 245, 247, 250, 255, 1.6)
        ImGui.AddLine(mouseX + 6, mouseY + 11, mouseX + 10, mouseY + 19, 245, 247, 250, 255, 1.6)
        ImGui.AddLine(mouseX + 10, mouseY + 19, mouseX + 8, mouseY + 20, 245, 247, 250, 255, 1.6)
        ImGui.AddLine(mouseX + 8, mouseY + 20, mouseX + 4, mouseY + 12, 245, 247, 250, 255, 1.6)
        ImGui.AddLine(mouseX + 4, mouseY + 12, mouseX, mouseY + 18, 245, 247, 250, 255, 1.6)
        ImGui.AddLine(mouseX + 1, mouseY + 2, mouseX + 10, mouseY + 10, 225, 43, 52, 105, 2.6)
    end

    function KSStaffNotificationPopStyleColor(styleColorCount)
        for _ = 1, styleColorCount do
            ImGui.PopStyleColor()
        end
    end

    function KSStaffNotificationDrawLogo(logoLeft, logoTop, logoSize, accentRed, accentGreen, accentBlue)
        local logoCenterX = logoLeft + logoSize * 0.5
        local logoCenterY = logoTop + logoSize * 0.5
        local logoRadius = logoSize * 0.5
        local logoTexture = nil
        if toastTexture ~= nil and type(ImGui.AddImage) == "function" and type(packColor) == "function" then
            local getTextureOk, currentTexture = pcall(function()
                return toastTexture:GetCurrent()
            end)
            if getTextureOk then
                logoTexture = currentTexture
            end
        end
        if logoTexture ~= nil then
            ImGui.AddRectFilled(logoLeft, logoTop, logoLeft + logoSize, logoTop + logoSize, 18, 20, 26, 255, 13)
            ImGui.AddImage(logoTexture, logoLeft + 5, logoTop + 5, logoLeft + logoSize - 5, logoTop + logoSize - 5, 0, 0, 1, 1, packColor(255, 255, 255, 255))
            if type(ImGui.AddRect) == "function" then
                ImGui.AddRect(logoLeft, logoTop, logoLeft + logoSize, logoTop + logoSize, accentRed, accentGreen, accentBlue, 220, 13, 0, 2)
            end
            return
        end
        if type(ImGui.AddCircleFilled) == "function" then
            ImGui.AddCircleFilled(logoCenterX, logoCenterY, logoRadius, 29, 13, 17, 255, 48)
            ImGui.AddCircleFilled(logoCenterX, logoCenterY, logoRadius - 4, 18, 20, 26, 255, 48)
        else
            ImGui.AddRectFilled(logoLeft, logoTop, logoLeft + logoSize, logoTop + logoSize, 18, 20, 26, 255, 12)
        end
        if type(ImGui.AddCircle) == "function" then
            ImGui.AddCircle(logoCenterX, logoCenterY, logoRadius - 1, accentRed, accentGreen, accentBlue, 235, 48, 2)
        end
        local letterStemX = logoLeft + logoSize * 0.35
        local letterTopY = logoTop + logoSize * 0.24
        local letterMidY = logoTop + logoSize * 0.51
        local letterBottomY = logoTop + logoSize * 0.78
        local letterArmEndX = logoLeft + logoSize * 0.68
        ImGui.AddLine(letterStemX, letterTopY, letterStemX, letterBottomY, 248, 249, 252, 255, 4)
        ImGui.AddLine(letterStemX + 2, letterMidY, letterArmEndX, letterTopY, 248, 249, 252, 255, 4)
        ImGui.AddLine(letterStemX + 3, letterMidY, letterArmEndX, letterBottomY, accentRed, accentGreen, accentBlue, 255, 4)
    end

    function KSStaffNotificationStop()
        local registeredHandler = KSStaffNotificationState.handler
        KSStaffNotificationState.handler = nil
        if registeredHandler ~= nil then
            pcall(EventMgr.RemoveHandler, registeredHandler)
        end
        pcall(KSStaffNotificationReleaseInput)
    end

    function KSStaffNotificationDismissCurrent()
        if #KSStaffNotificationState.queue > 0 then
            table.remove(KSStaffNotificationState.queue, 1)
        end
        KSStaffNotificationState.acknowledging = false
        KSStaffNotificationState.errorText = nil
        if #KSStaffNotificationState.queue == 0 then
            KSStaffNotificationStop()
        end
    end

    function KSStaffNotificationWrap(messageText, maxLineWidth)
        local wrappedLines = {}
        local currentLine = ""

        local function flushCurrentLine()
            wrappedLines[#wrappedLines + 1] = currentLine
            currentLine = ""
        end

        for _, codepoint in utf8.codes(messageText) do
            local character = utf8.char(codepoint)
            if character == "\n" then
                flushCurrentLine()
            else
                local candidateLine = currentLine .. character
                local candidateWidth = ImGui.CalcTextSize(candidateLine)
                if currentLine ~= "" then
                    if type(candidateWidth) == "number" and maxLineWidth < candidateWidth then
                        flushCurrentLine()
                        currentLine = character
                    end
                else
                    currentLine = candidateLine
                end
            end
        end
        if currentLine ~= "" or #wrappedLines == 0 then
            flushCurrentLine()
        end
        return wrappedLines
    end

    function KSStaffNotificationAcknowledge(notification)
        if KSStaffNotificationState.acknowledging then
            return
        end
        KSStaffNotificationState.acknowledging = true
        KSStaffNotificationState.errorText = nil
        local queueJobOk, queueJobResult = pcall(Script.QueueJob, function()
            local requestOk, ackResponse = pcall(function()
                return loaderAdapter.request("staff.notification.ack", { notification_id = notification.notification_id }, 5000)
            end)
            local currentNotification = KSStaffNotificationState.queue[1]
            if currentNotification == nil or currentNotification.notification_id ~= notification.notification_id then
                return
            end
            KSStaffNotificationState.acknowledging = false
            if requestOk then
                if ackResponse == "ok" then
                    KSStaffNotificationDismissCurrent()
                end
            else
                KSStaffNotificationState.errorText = "Acknowledgement failed. Check the Loader connection and try again."
            end
        end)
        if not queueJobOk or queueJobResult == false then
            KSStaffNotificationState.acknowledging = false
            KSStaffNotificationState.errorText = "Acknowledgement could not start. Please try again."
        end
    end

    function KSStaffNotificationDraw()
        local activeNotification = KSStaffNotificationState.queue[1]
        if activeNotification == nil then
            KSStaffNotificationStop()
            return
        end
        KSStaffNotificationCaptureInput()
        local displayWidth, displayHeight = ImGui.GetDisplaySize()
        if type(displayWidth) ~= "number" or type(displayHeight) ~= "number" or displayWidth < 560 or displayHeight < 400 then
            return
        end
        local windowFlags = ImGuiWindowFlags.NoCollapse | ImGuiWindowFlags.NoResize | ImGuiWindowFlags.NoMove | ImGuiWindowFlags.NoSavedSettings | ImGuiWindowFlags.NoTitleBar | ImGuiWindowFlags.NoBackground | ImGuiWindowFlags.NoScrollbar
        ImGui.SetNextWindowPos(0, 0, ImGuiCond.Always)
        ImGui.SetNextWindowSize(displayWidth, displayHeight, ImGuiCond.Always)
        ImGui.SetNextWindowFocus()
        if ImGui.Begin("##KScriptStaffNotification", true, windowFlags) then
            local windowPosX, windowPosY = ImGui.GetWindowPos()
            local cardWidth = math.min(780, displayWidth - 40)
            local cardHeight = math.min(460, displayHeight - 40)
            local cardLeft = (displayWidth - cardWidth) * 0.5
            local cardTop = (displayHeight - cardHeight) * 0.5
            local accentRed = 221
            local accentGreen = 46
            local accentBlue = 56
            local accentSoftRed = 102
            local accentSoftGreen = 23
            local accentSoftBlue = 29
            local badgeText = "STAFF MESSAGE"
            local headlineText = "NEW COMMUNICATION"
            local subtitleText = "A verified message from the K-Script staff team."
            if activeNotification.type == "WARNING" then
                accentB = 48
                accentGreen = 142
                accentRed = 244
                accentSoftB = 17
                accentSoftGreen = 55
                accentSoftRed = 105
                badgeText = "STAFF WARNING"
                headlineText = "ACTION REQUIRED"
                subtitleText = "Review the notice below and acknowledge it before continuing."
            end
            local headerHeight = 88
            local footerTop = cardTop + cardHeight - 76
            local contentLeft = cardLeft + 28
            local contentRight = cardLeft + cardWidth - 28
            local messageBoxLeft = contentLeft
            local messageBoxTop = cardTop + headerHeight + 70
            local messageBoxWidth = contentRight - contentLeft
            local messageFontScale = 1.1
            local messageLineHeight = 22
            local linesPerPage = math.max(1, math.floor((footerTop - messageBoxTop - 72) / messageLineHeight))
            local textWrapWidth = math.floor((messageBoxWidth - 52) / messageFontScale)
            ImGui.AddRectFilled(0, 0, displayWidth, displayHeight, 3, 4, 7, 205, 0)
            ImGui.AddRectFilled(cardLeft + 10, cardTop + 12, cardLeft + cardWidth + 10, cardTop + cardHeight + 12, 0, 0, 0, 125, 16)
            ImGui.AddRectFilled(cardLeft, cardTop, cardLeft + cardWidth, cardTop + cardHeight, 11, 13, 18, 255, 14)
            if type(ImGui.AddRect) == "function" then
                ImGui.AddRect(cardLeft, cardTop, cardLeft + cardWidth, cardTop + cardHeight, 65, 69, 80, 210, 14, 0, 1)
            end
            ImGui.AddRectFilled(cardLeft, cardTop, cardLeft + cardWidth, cardTop + 3, accentRed, accentGreen, accentBlue, 255, 2)
            ImGui.AddRectFilled(cardLeft + 1, cardTop + 3, cardLeft + cardWidth - 1, cardTop + headerHeight, 17, 19, 25, 252, 12)
            ImGui.AddRectFilled(cardLeft + 1, cardTop + headerHeight - 10, cardLeft + cardWidth - 1, cardTop + headerHeight, 17, 19, 25, 252, 0)
            KSStaffNotificationDrawLogo(contentLeft, cardTop + 17, 54, accentRed, accentGreen, accentBlue)
            ImGui.AddText(contentLeft + 72, cardTop + 38, "K-SCRIPT", 248, 249, 252, 255)
            local badgeLeft = contentRight - math.max(154, (ImGui.CalcTextSize(badgeText) or 0) + 30)
            ImGui.AddRectFilled(badgeLeft, cardTop + 27, contentRight, cardTop + 61, accentSoftRed, accentSoftGreen, accentSoftBlue, 250, 9)
            if type(ImGui.AddRect) == "function" then
                ImGui.AddRect(badgeLeft, cardTop + 27, contentRight, cardTop + 61, accentRed, accentGreen, accentBlue, 180, 9, 0, 1)
            end
            if type(ImGui.AddCircleFilled) == "function" then
                ImGui.AddCircleFilled(badgeLeft + 15, cardTop + 44, 4, accentRed, accentGreen, accentBlue, 255, 16)
            else
                ImGui.AddRectFilled(badgeLeft + 11, cardTop + 40, badgeLeft + 19, cardTop + 48, accentRed, accentGreen, accentBlue, 255, 4)
            end
            ImGui.AddText(badgeLeft + 27, cardTop + 37, badgeText, 251, 244, 242, 255)
            ImGui.AddText(contentLeft, cardTop + headerHeight + 20, headlineText, accentRed, accentGreen, accentBlue, 255)
            ImGui.AddText(contentLeft, cardTop + headerHeight + 43, subtitleText, 188, 193, 202, 245)
            if activeNotification.wrapWidth ~= textWrapWidth or type(activeNotification.lines) ~= "table" then
                activeNotification.lines = KSStaffNotificationWrap(activeNotification.message, textWrapWidth)
                activeNotification.wrapWidth = textWrapWidth
            end
            local messageLines = activeNotification.lines
            local pageCount = math.max(1, math.ceil(#messageLines / linesPerPage))
            activeNotification.page = math.max(1, math.min(tonumber(activeNotification.page) or 1, pageCount))
            local firstLineIndex = (activeNotification.page - 1) * linesPerPage + 1
            local lastLineIndex = math.min(#messageLines, firstLineIndex + linesPerPage - 1)
            ImGui.AddRectFilled(messageBoxLeft, messageBoxTop, messageBoxLeft + messageBoxWidth, footerTop - 16, 23, 27, 35, 255, 10)
            ImGui.AddRectFilled(messageBoxLeft, messageBoxTop, messageBoxLeft + 6, footerTop - 16, accentRed, accentGreen, accentBlue, 235, 5)
            ImGui.AddRectFilled(messageBoxLeft + 6, messageBoxTop, messageBoxLeft + messageBoxWidth, messageBoxTop + 2, accentRed, accentGreen, accentBlue, 100, 2)
            if type(ImGui.AddRect) == "function" then
                ImGui.AddRect(messageBoxLeft, messageBoxTop, messageBoxLeft + messageBoxWidth, footerTop - 16, 68, 74, 88, 215, 10, 0, 1)
            end
            ImGui.AddText(messageBoxLeft + 22, messageBoxTop + 15, activeNotification.sender_label:upper(), accentRed, accentGreen, accentBlue, 255)
            local lineY = messageBoxTop + 47
            if type(ImGui.SetWindowFontScale) == "function" then
                ImGui.SetWindowFontScale(messageFontScale)
            end
            for lineIndex = firstLineIndex, lastLineIndex do
                ImGui.AddText(messageBoxLeft + 23, lineY + 1, messageLines[lineIndex], 0, 0, 0, 210)
                ImGui.AddText(messageBoxLeft + 22, lineY, messageLines[lineIndex], 250, 251, 253, 255)
                lineY = lineY + messageLineHeight
            end
            if type(ImGui.SetWindowFontScale) == "function" then
                ImGui.SetWindowFontScale(1.0)
            end
            ImGui.AddRectFilled(cardLeft + 1, footerTop, cardLeft + cardWidth - 1, cardTop + cardHeight - 1, 15, 17, 22, 252, 12)
            ImGui.AddRectFilled(cardLeft + 1, footerTop, cardLeft + cardWidth - 1, footerTop + 10, 15, 17, 22, 252, 0)
            if type(ImGui.AddCircleFilled) == "function" then
                ImGui.AddCircleFilled(contentLeft + 4, footerTop + 28, 4, 73, 203, 122, 255, 16)
            else
                ImGui.AddRectFilled(contentLeft, footerTop + 24, contentLeft + 8, footerTop + 32, 73, 203, 122, 255, 4)
            end
            ImGui.AddText(contentLeft + 16, footerTop + 20, "VERIFIED CHANNEL", 139, 201, 162, 245)
            local pageIndicatorText = ("%02d / %02d"):format(activeNotification.page, pageCount)
            ImGui.AddText(contentLeft, footerTop + 43, pageIndicatorText, 107, 114, 127, 235)
            if KSStaffNotificationState.errorText ~= nil then
                ImGui.AddText(contentLeft + 154, footerTop + 43, KSStaffNotificationState.errorText, 244, 99, 105, 255)
            elseif KSStaffNotificationState.acknowledging then
                ImGui.AddText(contentLeft + 154, footerTop + 43, "Recording acknowledgement...", 241, 185, 92, 255)
            end
            local buttonRowY = footerTop + 21
            if activeNotification.page > 1 then
                ImGui.SetCursorPosX(cardLeft - windowPosX + cardWidth - 314)
                ImGui.SetCursorPosY(buttonRowY - windowPosY)
                if ImGui.Button("Back##KSStaffNotification", 92, 36) then
                    activeNotification.page = activeNotification.page - 1
                end
            end
            if pageCount > activeNotification.page then
                ImGui.SetCursorPosX(cardLeft - windowPosX + cardWidth - 138)
                ImGui.SetCursorPosY(buttonRowY - windowPosY)
                if ImGui.Button("Next##KSStaffNotification", 110, 36) then
                    activeNotification.page = activeNotification.page + 1
                end
            elseif activeNotification.type == "WARNING" then
                ImGui.PushStyleColor(ImGuiCol.Text, 1.0, 0.98, 0.96, 1.0)
                ImGui.PushStyleColor(ImGuiCol.Button, accentRed / 255, accentGreen / 255, accentBlue / 255, 0.94)
                ImGui.PushStyleColor(ImGuiCol.ButtonHovered, math.min(1.0, (accentRed + 18) / 255), math.min(1.0, (accentGreen + 18) / 255), math.min(1.0, (accentBlue + 18) / 255), 1.0)
                ImGui.PushStyleColor(ImGuiCol.ButtonActive, math.max(0.0, (accentRed - 24) / 255), math.max(0.0, (accentGreen - 24) / 255), math.max(0.0, (accentBlue - 24) / 255), 1.0)
                ImGui.SetCursorPosX(cardLeft - windowPosX + cardWidth - 224)
                ImGui.SetCursorPosY(buttonRowY - windowPosY)
                local wasUnderstandClicked = false
                if KSStaffNotificationState.acknowledging then
                    if type(ImGui.BeginDisabled) == "function" then
                        ImGui.BeginDisabled()
                    end
                    ImGui.Button("Recording...##KSStaffNotification", 196, 36)
                    if type(ImGui.EndDisabled) == "function" then
                        ImGui.EndDisabled()
                    end
                else
                    wasUnderstandClicked = ImGui.Button("I Understand##KSStaffNotification", 196, 36)
                end
                KSStaffNotificationPopStyleColor(4)
                if wasUnderstandClicked then
                    KSStaffNotificationAcknowledge(activeNotification)
                end
            else
                ImGui.PushStyleColor(ImGuiCol.Text, 1.0, 0.98, 0.98, 1.0)
                ImGui.PushStyleColor(ImGuiCol.Button, 0.7, 0.1, 0.14, 0.96)
                ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.86, 0.13, 0.18, 1.0)
                ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.56, 0.07, 0.1, 1.0)
                ImGui.SetCursorPosX(cardLeft - windowPosX + cardWidth - 160)
                ImGui.SetCursorPosY(buttonRowY - windowPosY)
                local wasCloseClicked = ImGui.Button("Close##KSStaffNotification", 132, 36)
                KSStaffNotificationPopStyleColor(4)
                if wasCloseClicked then
                    KSStaffNotificationDismissCurrent()
                end
            end
            KSStaffNotificationDrawMouseCursor()
        end
        ImGui.End()
    end

    function KSStaffNotificationInstall()
        if KSStaffNotificationState.handler ~= nil then
            return true
        end
        local presentHandler = EventMgr.RegisterHandler(eLuaEvent.ON_PRESENT, KSStaffNotificationDraw)
        KSStaffNotificationState.handler = presentHandler
        return presentHandler ~= nil and presentHandler ~= false
    end

    function KSBridgeOnStaffNotification(notificationPayload)
        if not KSStaffNotificationValid(notificationPayload) then
            return false
        end
        local notificationId = notificationPayload.notification_id
        if KSStaffNotificationState.seen[notificationId] then
            return true
        end
        if #KSStaffNotificationState.queue >= 16 then
            return false
        end
        KSStaffNotificationState.seen[notificationId] = true
        KSStaffNotificationState.seenOrder[#KSStaffNotificationState.seenOrder + 1] = notificationId
        if #KSStaffNotificationState.seenOrder > 64 then
            local evictedNotificationId = table.remove(KSStaffNotificationState.seenOrder, 1)
            KSStaffNotificationState.seen[evictedNotificationId] = nil
        end
        KSStaffNotificationState.queue[#KSStaffNotificationState.queue + 1] = {
            notification_id = notificationId,
            type = notificationPayload.type,
            message = notificationPayload.message,
            sender_label = notificationPayload.sender_label,
            page = 1,
        }
        if not KSStaffNotificationInstall() then
            table.remove(KSStaffNotificationState.queue)
            KSStaffNotificationState.seen[notificationId] = nil
            table.remove(KSStaffNotificationState.seenOrder)
            return false
        end
        pcall(KSStaffNotificationPlaySound, notificationPayload.type)
        return true
    end

    function KSStaffNotificationClearForUnload()
        KSStaffNotificationState.queue = {}
        KSStaffNotificationState.seen = {}
        KSStaffNotificationState.seenOrder = {}
        KSStaffNotificationState.acknowledging = false
        KSStaffNotificationState.errorText = nil
        KSStaffNotificationStop()
    end

    function KSBridgeOnOnlineUsersRefresh(refreshEvent)
        if type(KSOnlineUsersV3State) ~= "table" then
            return false
        end
        local currentLoadGeneration = tonumber(loaderAdapter and loaderAdapter.load_generation)
        if currentLoadGeneration == nil or tonumber(KSOnlineUsersV3State.loopGeneration) ~= currentLoadGeneration then
            return false
        end
        KSOnlineUsersV3State.nextAtMs = 0
        return true
    end

    function KSBridgeOnSessionExpiring(sessionExpiryInfo)
        local remainingMinutesBucket = type(sessionExpiryInfo) == "table" and tonumber(sessionExpiryInfo.remaining_minutes_bucket) or nil
        if remainingMinutesBucket and remainingMinutesBucket <= 5 and isTableOrUserdata(GUI) and type(GUI.AddToast) == "function" then
            GUI.AddToast("K-Script", "Your Loader session will expire soon.", 8000, eToastPos.TOP_RIGHT)
        end
    end

    KS_RUNTIME_CONTROL_HANDLER = nil

    function KSBridgeOnRuntimeControl(controlRequest)
        if type(KS_RUNTIME_CONTROL_HANDLER) ~= "function" then
            return "rejected_session"
        end
        local handlerOk, controlResult = pcall(KS_RUNTIME_CONTROL_HANDLER, controlRequest)
        if not handlerOk or type(controlResult) ~= "string" then
            return "execution_failed"
        end
        return controlResult
    end

    function KSBridgeOnUnload(unloadInfo)
        if type(KSStaffNotificationClearForUnload) == "function" then
            pcall(KSStaffNotificationClearForUnload)
        end
        if (type(unloadInfo) == "table" and unloadInfo.reason or nil) == "loader_update_required" and isTableOrUserdata(GUI) and type(GUI.AddToast) == "function" then
            pcall(GUI.AddToast, "K-Script", "K-Script was unloaded due to a Loader update.", 10000, eToastPos.TOP_RIGHT)
        end
        if type(KSFeatureActionFlushForUnload) == "function" then
            pcall(KSFeatureActionFlushForUnload)
        end
        isUnloading = true
        local unloadStatus = "ok"
        if type(KSModules) == "table" and type(KSModules.unloadAll) == "function" then
            KSModules.unloadAll("loader_unload")
        end
        return unloadStatus
    end

    if type(loaderAdapter) ~= "table" or loaderAdapter.version ~= 3 or loaderAdapter.contract ~= "ks-loader-adapter-v3" or type(loaderAdapter.request) ~= "function" then
        if isTableOrUserdata(GUI) and type(GUI.AddToast) == "function" then
            GUI.AddToast("K-Script", "Please update the Loader before loading K-Script.", 10000, eToastPos.TOP_RIGHT)
        end
        SetShouldUnload()
        return
    end
    local unusedStartupClockStart = os.clock()
    detectedPlayerNames = {}
    detectedPlayerReasons = {}
    sentHostShareEventPlayers = {}
    clearingCache = false
    maintransitionActive = false
    modderDisplay = true
    gameInfoDisplay = true
    hostIndex = GTA.GetLocalPlayerId()
    scriptHostIndex = GTA.GetLocalPlayerId()
    hostName = "Not Found"
    scriptHostName = "Not Found"
    numConnectedPlayers = 0
    __a24 = nil
    __a25 = nil
    backendBaseUrl = tostring(__a19 or API_BASE or "bridge://loader"):gsub("/+$", "")
    sessionHeaderToken = ""
    runtimeSessionContext = nil
    initRun = true
    apiAuthInProgress = false
    apiAuthLastError = nil
    isUnloading = false
    storedSCName = ""
    detectedCountry = "Unknown"
    spoofedPid = {}
    NiggerVeh = {}
    lastPTFXEventTimes = {}
    lastWorldStateEventTimes = {}
    lastSoundEventTimes = {}
    maxNetEventsPerSecond = 10
    maxSoundNetEventsPerSecond = 5
    blacklistDuration = 60
    netEventblacklist = {}
    worldStateEventblacklist = {}
    AdmanUIDs = {}
    moderatorUIDs = {}
    supporterUIDs = {}
    bannedUIDs = {}
    DevUID = -1
    isSupporter = false
    isDev = false
    isAdmin = false
    isModerator = false
    cachedUID = Cherax.GetUID()
    areWeHost = false
    hostShareActive = false
    hostSharePID = nil
    onCrashCooldown = false
    crashedplayercount = 0
    crashedsessioncount = 0
    playercount = 0
    onlineUsers = {}
    isInPool = false
    notifyEnabled = false
    adminRIDList = {}
    blacklistRIDList = {}
    isGameVersionEnhanced = false
    webhookRequestCompleted = false
    menuRootPath = FileMgr.GetMenuRootPath() .. "\\Lua\\K-Script"
    K_SCRIPT_TOS_ACCEPTANCE_PATH = menuRootPath .. "\\K-Script_Terms_Accepted.txt"
    KS_CLIENT_BUILD = "15.69"
    KSCRIPT_PAYLOAD_SALTS = {}
    KSCRIPT_PAYLOAD_OFFSET = 0
    KSCRIPT_PAYLOAD_RANGE = 0
    KSCRIPT_PAYLOAD_SEED = 0
    KS_BACKEND_REQUEST_SPECS = KS_BACKEND_REQUEST_SPECS or {
        startupSnapshot = { command = "startup.snapshot", timeoutMs = 15000, expected = { "snapshot" } },
        startupConfig = { command = "config.get", timeoutMs = 15000, expected = { "o", "c" } },
        runtimeModule = { command = "module.get", timeoutMs = 35000, expected = { "source_b64", "sha256" } },
        runtimeModuleBatch = { command = "module.batch.get", timeoutMs = 30000, expected = { "modules" } },
        permissions = { command = "permissions.get", timeoutMs = 15000, expected = { "o", "p" } },
        playerStatusBatch = { command = "players.status.getBatch", timeoutMs = 10000, expected = { "player_statuses" } },
        blacklistActionResult = { command = "blacklist.actionResult", timeoutMs = 10000, expected = { "accepted", "result" } },
        onlineUsers = { command = "users.online.get", timeoutMs = 10000, expected = { "users" } },
        lookup = { command = "lookup.ip", timeoutMs = 10000, expected = { "country", "country_code" } },
    }
    KS_STARTUP_SNAPSHOT = nil
    KS_STARTUP_SNAPSHOT_CONFIGS = KS_STARTUP_SNAPSHOT_CONFIGS or {}
    KS_STARTUP_PERMISSION_SNAPSHOT = nil

    function getBackendRequestSpec(requestSpecName)
        return KS_BACKEND_REQUEST_SPECS[tostring(requestSpecName or "")] or {}
    end

    function getRequestTimeoutSeconds(requestSpecName, fallbackTimeoutSeconds)
        local resolvedTimeoutMs = tonumber(getBackendRequestSpec(requestSpecName).timeoutMs) or (tonumber(fallbackTimeoutSeconds) or 30) * 1000
        return math.max(1, resolvedTimeoutMs / 1000)
    end

    local function isNonEmptyString(candidateText)
        return tostring(candidateText or "") ~= ""
    end

    function validateRequestAuth(requestSpecName, authContext)
        if loaderAdapter then
            return true
        end
        local requiredAuthKinds = tostring(getBackendRequestSpec(requestSpecName).auth or "")
        if not authContext then
            authContext = {}
        end
        if requiredAuthKinds:find("api", 1, true) and not isNonEmptyString(authContext.apiKey) then
            return false, "missing_api_key"
        end
        if requiredAuthKinds:find("script", 1, true) and not isNonEmptyString(authContext.scriptToken) then
            return false, "missing_script_token"
        end
        if requiredAuthKinds:find("session", 1, true) and not isNonEmptyString(authContext.sessionId) then
            return false, "missing_session"
        end
        return true, nil
    end

    function validateResponseFields(requestSpecName, responsePayload, requiredFields)
        if type(responsePayload) ~= "table" then
            return false, "response_not_table"
        end
        if not requiredFields then
            requiredFields = getBackendRequestSpec(requestSpecName).expected or {}
        end
        for _, fieldName in ipairs(requiredFields) do
            if responsePayload[fieldName] == nil then
                return false, "missing_" .. tostring(fieldName)
            end
        end
        return true, nil
    end

    local readRawClockSeconds = nil
    if isTableOrUserdata(ImGui) and type(ImGui.GetTime) == "function" then
        local imguiTimeProbe = ImGui.GetTime()
        if type(imguiTimeProbe) == "number" and imguiTimeProbe >= 0 then
            function readRawClockSeconds()
                local imguiSeconds = ImGui.GetTime()
                if type(imguiSeconds) == "number" and imguiSeconds >= 0 then
                    return imguiSeconds
                end
                return nil
            end
        end
    end
    if not readRawClockSeconds then
        function readRawClockSeconds()
            return type(os) == "table" and type(os.time) == "function" and os.time() or nil
        end
    end
    local lastMonotonicSeconds = 0

    function getMonotonicSeconds()
        local nowSeconds = readRawClockSeconds()
        if (type(nowSeconds) ~= "number" or nowSeconds < 0) and (type(os) ~= "table" or type(os.time) ~= "function" or not os.time()) then
            nowSeconds = lastMonotonicSeconds
        end
        if nowSeconds < lastMonotonicSeconds then
            nowSeconds = lastMonotonicSeconds
        end
        lastMonotonicSeconds = nowSeconds
        return nowSeconds
    end

    function waitForCurlFinished(requestSpecName, curlHandle, yieldIntervalMs)
        local deadlineSeconds = getMonotonicSeconds() + getRequestTimeoutSeconds(requestSpecName, 30)
        while not curlHandle:GetFinished() do
            if ShouldUnload and ShouldUnload() then
                return false, "unloading"
            end
            if deadlineSeconds <= getMonotonicSeconds() then
                return false, "timeout"
            end
            yieldClampedMs(yieldIntervalMs, 10)
        end
        return true, nil
    end

    local STARTUP_PHASE_INFO = {
        preparing = { label = "Preparing K-Script", progress = 0.08 },
        session = { label = "Checking session", progress = 0.14 },
        core = { label = "Loading core", progress = 0.3 },
        configuration = { label = "Applying configuration", progress = 0.36 },
        runtime = { label = "Preparing runtime", progress = 0.52 },
        modules = { label = "Starting modules", progress = 0.72 },
        finalizing = { label = "Finalizing", progress = 0.94 },
    }
    loaderLoadGeneration = tonumber(loaderAdapter.load_generation) or 1

    function isRuntimeGenerationCurrent()
        return not ShouldUnload()
    end

    startupProgressState = {
        generation = loaderLoadGeneration,
        active = true,
        status = "running",
        phase = "preparing",
        label = "Preparing K-Script",
        hint = "This may take a moment.",
        targetProgress = 0.08,
        displayProgress = 0.04,
        moduleId = nil,
        handler = nil,
        lastDrawAt = nil,
        renderedOnce = false,
        terminalAt = nil,
        unloadAt = nil,
        unloadRequested = false,
        startupWindowClosed = false,
        errorCode = "KS-260",
    }
    local originalSetShouldUnload = SetShouldUnload
    local lastUnloadReason = "unknown"
    local VALID_UNLOAD_REASONS = {
        startup_exception = true,
        render_hang_guard = true,
        config_failed = true,
        permissions_failed = true,
        module_failed = true,
        module_capability_failed = true,
        discord_ipc_failed = true,
        ui_registration_failed = true,
        user_unload = true,
        policy_unload = true,
        unknown = true,
    }

    function recordUnloadReason(unloadReason)
        unloadReason = tostring(unloadReason or "unknown")
        if not VALID_UNLOAD_REASONS[unloadReason] then
            unloadReason = "unknown"
        end
        lastUnloadReason = unloadReason
        if type(loaderAdapter.set_unload_reason) == "function" then
            loaderAdapter.set_unload_reason(unloadReason)
        end
        return unloadReason
    end

    local startupLogState = { phases = {}, featurePhases = {}, terminal = false }
    local STARTUP_PHASE_LOG_MESSAGES = {
        preparing = "Initialization started.",
        session = "Checking session.",
        core = "Loading core components.",
        configuration = "Applying configuration.",
        runtime = "Preparing runtime.",
        modules = "Starting features.",
        finalizing = "Finalizing initialization.",
    }
    local FEATURE_STAGE_LOG_MESSAGES = { feature_ready = "Features ready." }

    function logStartupMessage(logColor, logMessage)
        if not isTableOrUserdata(Logger) or type(Logger.Log) ~= "function" then
            return
        end
        pcall(Logger.Log, logColor, "K-Script Startup", logMessage)
    end

    local function logStartupPhaseOnce(phaseName)
        if startupLogState.terminal or not isRuntimeGenerationCurrent() then
            return
        end
        local phaseMessage = STARTUP_PHASE_LOG_MESSAGES[phaseName]
        if not phaseMessage or startupLogState.phases[phaseName] then
            return
        end
        startupLogState.phases[phaseName] = true
        logStartupMessage(eLogColor.YELLOW, phaseMessage)
    end

    function logStartupFeatureStage(featureStage)
        if startupLogState.terminal or not isRuntimeGenerationCurrent() then
            return
        end
        local stageMessage = FEATURE_STAGE_LOG_MESSAGES[featureStage]
        if not stageMessage or startupLogState.featurePhases[featureStage] then
            return
        end
        startupLogState.featurePhases[featureStage] = true
        logStartupMessage(eLogColor.YELLOW, stageMessage)
    end

    local function logStartupStopped()
        if startupLogState.terminal or not isRuntimeGenerationCurrent() then
            return
        end
        startupLogState.terminal = true
        logStartupMessage(eLogColor.RED, "Initialization stopped. Restart the Loader and try again.")
    end

    local function logStartupReady()
        if startupLogState.terminal or not isRuntimeGenerationCurrent() then
            return
        end
        startupLogState.terminal = true
        logStartupMessage(eLogColor.GREEN, "Initialization ready.")
    end

    local function clampNumber(inputNumber, lowerBound, upperBound)
        inputNumber = tonumber(inputNumber) or lowerBound
        if lowerBound > inputNumber then
            return lowerBound
        end
        if upperBound < inputNumber then
            return upperBound
        end
        return inputNumber
    end

    local function getStartupOverlayTime()
        if isTableOrUserdata(ImGui) and type(ImGui.GetTime) == "function" then
            local overlaySeconds = ImGui.GetTime()
            if type(overlaySeconds) == "number" and overlaySeconds >= 0 then
                return overlaySeconds
            end
        end
        return type(os) == "table" and type(os.clock) == "function" and os.clock() or 0
    end

    function setStartupPhase(requestedPhase, progressOverride)
        if not isRuntimeGenerationCurrent() or startupProgressState.status ~= "running" then
            return
        end
        local phaseName = tostring(requestedPhase or "preparing")
        local phaseInfo = STARTUP_PHASE_INFO[phaseName] or STARTUP_PHASE_INFO.preparing
        local requestedProgress = clampNumber(progressOverride or phaseInfo.progress, 0.04, 0.98)
        if requestedProgress + 0.001 < startupProgressState.targetProgress then
            return
        end
        startupProgressState.phase = phaseName
        startupProgressState.label = phaseInfo.label
        local newTargetProgress = math.max(startupProgressState.targetProgress, requestedProgress)
        startupProgressState.targetProgress = newTargetProgress
        logStartupPhaseOnce(phaseName)
    end

    function setStartupModuleId(rawModuleId)
        local moduleIdText = tostring(rawModuleId or "")
        startupProgressState.moduleId = moduleIdText
    end

    function failStartup(requestedErrorCode)
        if not isRuntimeGenerationCurrent() then
            return
        end
        if startupProgressState.status == "ready" then
            return
        end
        if startupProgressState.status == "failed" then
            return
        end
        local normalizedErrorCode = tostring(requestedErrorCode or "KS-260")
        if not normalizedErrorCode:match("^KS%-%d%d%d$") then
            normalizedErrorCode = "KS-260"
        end
        logStartupStopped()
        startupProgressState.status = "failed"
        startupProgressState.label = "Something went wrong"
        startupProgressState.hint = "Please restart the loader and try again."
        startupProgressState.errorCode = normalizedErrorCode
        startupProgressState.targetProgress = startupProgressState.displayProgress
        local failedAtSeconds = getStartupOverlayTime()
        startupProgressState.terminalAt = failedAtSeconds
        startupProgressState.unloadAt = failedAtSeconds + 10.0
        startupProgressState.unloadRequested = false
    end

    function markStartupReady()
        if startupProgressState.status == "ready" then
            return
        end
        if not isRuntimeGenerationCurrent() or startupProgressState.status ~= "running" then
            return
        end
        logStartupReady()
        startupProgressState.status = "ready"
        startupProgressState.phase = "ready"
        startupProgressState.label = "Ready"
        startupProgressState.hint = "K-Script is ready."
        startupProgressState.targetProgress = 1.0
        startupProgressState.displayProgress = 1.0
        local readyAtSeconds = getStartupOverlayTime()
        startupProgressState.terminalAt = readyAtSeconds
    end

    local function syncStartupProgressFromRequests()
        if not isRuntimeGenerationCurrent() then
            return
        end
        if startupProgressState.status ~= "running" then
            return
        end
        if type(ShouldUnload) == "function" and ShouldUnload() then
            failStartup("KS-260")
            return
        end
        local startupConfigState = type(KSStartupConfigState) == "table" and KSStartupConfigState or nil
        local configRequest = startupConfigState and startupConfigState.request or nil
        local fatalRequestStates = { fatal_failed = true, retry_exhausted = true, timeout_failed = true }
        if type(configRequest) == "table" then
            local configRequestState = tostring(configRequest.state or "")
            local configStateProgressOffsets = {
                queued = 0.0,
                dispatching = 0.02,
                in_flight = 0.04,
                response_processing = 0.055,
                response_received = 0.07,
                parsing = 0.085,
                validating = 0.1,
                retry_wait = 0.015,
            }
            if fatalRequestStates[configRequestState] then
                failStartup("KS-260")
                return
            end
            local configProgressOffset = configStateProgressOffsets[configRequestState]
            if configProgressOffset then
                if tostring(configRequest.stage or "") == "bootstrap" then
                    setStartupPhase("session", 0.14 + configProgressOffset)
                else
                    setStartupPhase("configuration", 0.36 + configProgressOffset)
                end
            end
        elseif startupConfigState then
            if fatalRequestStates[tostring(startupConfigState.state or "")] then
                failStartup("KS-260")
                return
            end
        end
        local startupModuleId = startupProgressState.moduleId
        local moduleLoadState = startupModuleId ~= nil and startupModuleId ~= "" and type(KSModules) == "table" and type(KSModules.states) == "table" and tostring(KSModules.states[startupModuleId] or "") or ""
        local moduleStateProgress = {
            queued = 0.73,
            dispatching = 0.75,
            in_flight = 0.78,
            response_processing = 0.81,
            response_received = 0.82,
            parsing = 0.84,
            validating = 0.86,
            executing = 0.89,
            success = 0.91,
            retry_wait = 0.76,
        }
        if fatalRequestStates[moduleLoadState] then
            failStartup("KS-260")
        elseif moduleStateProgress[moduleLoadState] then
            setStartupPhase("modules", moduleStateProgress[moduleLoadState])
        end
    end

    local function removeStartupOverlayHandler()
        local overlayHandler = startupProgressState.handler
        startupProgressState.handler = nil
        if overlayHandler then
            EventMgr.RemoveHandler(overlayHandler)
        end
    end

    local function closeStartupOverlay()
        if startupProgressState.startupWindowClosed then
            return
        end
        startupProgressState.startupWindowClosed = true
        startupProgressState.active = false
        removeStartupOverlayHandler()
    end

    local function scaleOverlayAlpha(baseAlpha, fadeFactor)
        return math.floor(clampNumber((tonumber(baseAlpha) or 0) * (tonumber(fadeFactor) or 1), 0, 255) + 0.5)
    end

    local function drawStartupOverlay()
        if not startupProgressState.active then
            return
        end
        if not isRuntimeGenerationCurrent() then
            closeStartupOverlay()
            return
        end
        startupProgressState.renderedOnce = true
        syncStartupProgressFromRequests()
        local overlayTime = getStartupOverlayTime()
        if startupProgressState.status == "failed" and not startupProgressState.unloadRequested and overlayTime >= (startupProgressState.unloadAt or overlayTime) then
            startupProgressState.unloadRequested = true
            originalSetShouldUnload()
            closeStartupOverlay()
            return
        end
        local frameDelta = clampNumber(overlayTime - (startupProgressState.lastDrawAt or overlayTime), 0, 0.1)
        startupProgressState.lastDrawAt = overlayTime
        if startupProgressState.status == "running" then
            local progressLerpFactor = math.min(1.0, frameDelta * 4.8)
            startupProgressState.displayProgress = startupProgressState.displayProgress + (startupProgressState.targetProgress - startupProgressState.displayProgress) * progressLerpFactor
        end
        local overlayFade = 1.0
        if startupProgressState.status == "ready" then
            local secondsSinceReady = math.max(0, overlayTime - (startupProgressState.terminalAt or overlayTime))
            if secondsSinceReady > 0.7 then
                overlayFade = 1.0 - clampNumber((secondsSinceReady - 0.7) / 0.55, 0, 1)
                if overlayFade <= 0 then
                    closeStartupOverlay()
                    return
                end
            end
        end
        local displayWidth, displayHeight = ImGui.GetDisplaySize()
        if type(displayWidth) ~= "number" or type(displayHeight) ~= "number" or displayWidth <= 0 or displayHeight <= 0 then
            return
        end
        local panelWidth = math.min(430, displayWidth - 32)
        if panelWidth < 240 then
            panelWidth = math.max(180, displayWidth - 12)
        end
        local panelHeight = 136
        local panelX = (displayWidth - panelWidth) * 0.5
        local panelY = math.max(28, displayHeight * 0.105)
        local panelCornerRadius = 10
        ImGui.AddRectFilled(panelX + 5, panelY + 7, panelX + panelWidth + 5, panelY + panelHeight + 7, 0, 0, 0, scaleOverlayAlpha(105, overlayFade), panelCornerRadius)
        ImGui.AddRectFilled(panelX, panelY, panelX + panelWidth, panelY + panelHeight, 14, 16, 21, scaleOverlayAlpha(248, overlayFade), panelCornerRadius)
        ImGui.AddRectFilled(panelX + 1, panelY + 1, panelX + panelWidth - 1, panelY + 35, 24, 25, 31, scaleOverlayAlpha(252, overlayFade), panelCornerRadius)
        ImGui.AddRectFilled(panelX + 1, panelY + 34, panelX + panelWidth * 0.6, panelY + 36, 225, 53, 45, scaleOverlayAlpha(235, overlayFade), 1)
        ImGui.AddRectFilled(panelX + panelWidth * 0.6, panelY + 34, panelX + panelWidth - 1, panelY + 36, 238, 115, 38, scaleOverlayAlpha(220, overlayFade), 1)
        if type(ImGui.AddRect) == "function" then
            ImGui.AddRect(panelX, panelY, panelX + panelWidth, panelY + panelHeight, 82, 85, 96, scaleOverlayAlpha(150, overlayFade), panelCornerRadius, 0, 1)
        end
        ImGui.AddText(panelX + 16, panelY + 10, "K-Script", 247, 247, 250, scaleOverlayAlpha(255, overlayFade))
        ImGui.AddText(panelX + 16, panelY + 47, startupProgressState.label, 226, 229, 236, scaleOverlayAlpha(250, overlayFade))
        local hintText = startupProgressState.hint
        if startupProgressState.status == "failed" then
            local secondsUntilUnload = math.max(0, math.ceil((startupProgressState.unloadAt or overlayTime) - overlayTime))
            hintText = ("Closing in %ds. Restart the loader. Code: %s"):format(secondsUntilUnload, startupProgressState.errorCode)
        end
        ImGui.AddText(panelX + 16, panelY + 68, hintText, 145, 150, 164, scaleOverlayAlpha(235, overlayFade))
        local clampedProgress = clampNumber(startupProgressState.displayProgress, 0, 1)
        local barX = panelX + 16
        local barY = panelY + 96
        local barWidth = panelWidth - 32
        local barHeight = 10
        local barFillWidth = barWidth * clampedProgress
        ImGui.AddRectFilled(barX, barY, barX + barWidth, barY + barHeight, 39, 41, 49, scaleOverlayAlpha(250, overlayFade), 5)
        local fillRed = 225
        local fillGreen = 53
        local fillBlue = 45
        if startupProgressState.status == "ready" then
            fillB = 126
            fillGreen = 205
            fillRed = 72
        elseif startupProgressState.status == "failed" then
            fillB = 55
            fillGreen = 55
            fillRed = 210
        end
        if barFillWidth > 0.5 then
            ImGui.AddRectFilled(barX, barY, barX + barFillWidth, barY + barHeight, fillRed, fillGreen, fillBlue, scaleOverlayAlpha(255, overlayFade), 5)
        end
        if startupProgressState.status == "running" and barFillWidth > 18 then
            local shimmerStartX = math.max(barX, barX + overlayTime * 105 % (barFillWidth + 36) - 36)
            local shimmerEndX = math.min(barX + barFillWidth, shimmerStartX + 32)
            if shimmerStartX < shimmerEndX then
                ImGui.AddRectFilled(shimmerStartX, barY + 2, shimmerEndX, barY + barHeight - 2, 255, 159, 92, scaleOverlayAlpha(115, overlayFade), 4)
            end
        end
        local percentLabel = string.format("%d%%", math.floor(clampedProgress * 100 + 0.5))
        local percentLabelWidth = select(1, ImGui.CalcTextSize(percentLabel)) or 0
        ImGui.AddText(panelX + panelWidth - 16 - percentLabelWidth, panelY + 113, percentLabel, 177, 181, 192, scaleOverlayAlpha(245, overlayFade))
        if type(ImGui.AddCircleFilled) == "function" then
            local pulseIntensity = startupProgressState.status == "running" and 0.72 + 0.28 * math.sin(overlayTime * 4.5) or 1.0
            ImGui.AddCircleFilled(panelX + panelWidth - 23, panelY + 18, 4, fillRed, fillGreen, fillBlue, scaleOverlayAlpha(230 * pulseIntensity, overlayFade), 12)
        end
    end

    function requestScriptUnload(unloadReason)
        if recordUnloadReason(unloadReason) == "user_unload" then
            closeStartupOverlay()
            if type(originalSetShouldUnload) == "function" then
                return originalSetShouldUnload()
            end
            return
        end
        if startupProgressState.active and startupProgressState.handler ~= nil and (startupProgressState.status == "running" or startupProgressState.status == "failed") then
            failStartup("KS-260")
            return
        end
        if type(originalSetShouldUnload) == "function" then
            return originalSetShouldUnload()
        end
    end

    ;(function()
        if startupProgressState.handler ~= nil then
            return true
        end
        local overlayHandlerId = EventMgr.RegisterHandler(eLuaEvent.ON_PRESENT, drawStartupOverlay)
        startupProgressState.handler = overlayHandlerId
        return overlayHandlerId ~= false and overlayHandlerId ~= nil
    end)()
    setStartupPhase("preparing")

    function BuildKScriptPayload(rockstarId, eventSalt)
        if type(KSCRIPT_PAYLOAD_SALTS) ~= "table" or tonumber(KSCRIPT_PAYLOAD_RANGE or 0) <= 0 then
            if type(Logger) == "table" and type(Logger.Log) == "function" then
                Logger.Log(eLogColor.RED, "K-Script Startup", "event payload config missing")
            end
            requestScriptUnload()
            return 0
        end
        rockstarId = math.floor(tonumber(rockstarId) or 0)
        eventSalt = math.floor(tonumber(eventSalt) or 0)
        return math.floor(KSCRIPT_PAYLOAD_OFFSET + (rockstarId * 97 + rockstarId % 104729 * 8191 + rockstarId % 8191 * 65537 + (eventSalt * 31337 + eventSalt % 65521 * 127) + KSCRIPT_PAYLOAD_SEED) % KSCRIPT_PAYLOAD_RANGE)
    end

    function GetLocalKScriptPayload(eventSalt)
        return BuildKScriptPayload(getLocalRockstarId(), eventSalt)
    end

    K_SCRIPT_TOS_TEXT = 'K-Script Rules & Regulations\r\n\r\nGeneral Script & Feature Rules\r\n\r\nProhibited Assistance & Leaking\r\nNo Assisting Banned Users: Do not provide any support, feature details, crash info, or Discord updates to banned users.\r\n\r\nNo Assisting Chinese Users: Assisting Chinese users with anything regarding features, crashes, Discord info, or related script matters is prohibited. China is and remains banned from using K-Script\r\n\r\nDo Not Assist Other Menus: Helping other menu developers patch, analyze, or bypass K-Script features is strictly prohibited.\r\n\r\nResponsible Crash Usage & Testing\r\nUse Crash Features Responsibly: Crash features are available for use, but repeatedly targeting the same players is prohibited, as this leads to our methods being discovered and patched.\r\n\r\nNo Live Feature Testing: Do not test crashes, trolling features, or any other functionality on users of other menus just to see if they work.\r\n\r\nCrash Usage Is Monitored: Crash usage is actively logged and monitored. Additional automated protections are continuously being implemented to catch abusers.\r\n\r\nUser Detection Rules\r\nNo Player Targeting: Targeting or harassing of any K-Script/Cherax users based on K-Script\'s user detection system is strictly prohibited.\r\n\r\nNo Protecting "Lexis" Users: Abusing the K-Script user detection system to shield or protect Lexis users is forbidden.\r\n\r\nAgreement: By using K-Script and its supporter features, you automatically agree to follow these rules. Admin enforcement is final.\r\n'
    K_SCRIPT_TOS_CARDS = {
        {
            title = "01  General Assistance Rules",
            body = {
                "Do not assist banned users with support, feature details, crash information, or Discord updates.",
                "Do not help other menu developers patch, analyze, or bypass K-Script features.",
            },
        },
        {
            title = "02  Crash Usage & Testing",
            body = {
                "Use crash features responsibly. Repeatedly targeting the same players is prohibited.",
                "Do not test crashes, trolling, or script functionality on other-menu users just to see if they work.",
            },
        },
        {
            title = "03  User Detection Conduct",
            body = {
                "Do not target or harass K-Script/Cherax users based on the detection system.",
                "Do not abuse detection data to shield or protect Lexis users more specificly abusing the K-Script User identification System.",
            },
        },
        {
            title = "04  Agreement",
            body = { "Using K-Script means you agree to these rules. Admin enforcement is final." },
        },
    }
    kScriptTosAccepted = FileMgr.DoesFileExist(K_SCRIPT_TOS_ACCEPTANCE_PATH)
    kScriptTosPromptStartedAt = nil
    kScriptTosWriteError = nil
    kScriptTosDeclined = false
    kScriptTosGateActive = false
    K_SCRIPT_TOS_WAIT_SECONDS = 20.0
    K_SCRIPT_TOS_OPEN_DURATION = 1.08
    K_SCRIPT_TOS_CLOSE_DURATION = 0.42
    kScriptTosClosing = false
    kScriptTosCloseStartedAt = nil
    kScriptTosCloseAction = nil

    function HasAcceptedTermsOfService()
        local fileExistsFunction = FileMgr.DoesFileExist
        return fileExistsFunction == true or fileExistsFunction
    end

    function AcceptTermsOfService()
        FileMgr.CreateDir(menuRootPath)
        local tosWriteResult = FileMgr.WriteFileContent(K_SCRIPT_TOS_ACCEPTANCE_PATH, K_SCRIPT_TOS_TEXT .. "\nAccepted: true\n")
        if tosWriteResult == false then
            kScriptTosWriteError = ("Failed to save acceptance file: %s"):format(tostring(tosWriteResult))
            return false
        end
        kScriptTosAccepted = true
        kScriptTosWriteError = nil
        KScriptTosReleaseMouseCursor()
        return true
    end

    function DeclineTermsOfService()
        kScriptTosDeclined = true
        KScriptTosReleaseMouseCursor()
        requestScriptUnload("user_unload")
    end

    function WaitForTermsOfServiceAcceptance()
        if HasAcceptedTermsOfService() then
            return true
        end
        kScriptTosGateActive = true
        kScriptTosPromptStartedAt = nil
        kScriptTosClosing = false
        kScriptTosCloseStartedAt = nil
        kScriptTosCloseAction = nil
        while not HasAcceptedTermsOfService() and not ShouldUnload() do
            Script.Yield(50)
        end
        kScriptTosGateActive = false
        KScriptTosReleaseMouseCursor()
        return HasAcceptedTermsOfService() and not ShouldUnload()
    end

    function KScriptTosClamp(clampValue, minValue, maxValue)
        if clampValue < minValue then
            return minValue
        end
        if maxValue < clampValue then
            return maxValue
        end
        return clampValue
    end

    function KScriptTosEaseInCubic(animationProgress)
        animationProgress = KScriptTosClamp(animationProgress, 0.0, 1.0)
        return animationProgress * animationProgress * animationProgress
    end

    function KScriptTosEaseSmoothStep(animationProgress)
        animationProgress = KScriptTosClamp(animationProgress, 0.0, 1.0)
        return animationProgress * animationProgress * animationProgress * (animationProgress * (animationProgress * 6.0 - 15.0) + 10.0)
    end

    function KScriptTosEaseOutBack(animationProgress)
        animationProgress = KScriptTosClamp(animationProgress, 0.0, 1.0)
        local overshootAmount = 1.70158
        return 1.0 + (overshootAmount + 1.0) * ((animationProgress - 1.0) * (animationProgress - 1.0) * (animationProgress - 1.0)) + overshootAmount * ((animationProgress - 1.0) * (animationProgress - 1.0))
    end

    function KScriptTosAlpha(baseAlpha, fadeFactor)
        return math.floor(KScriptTosClamp(baseAlpha * fadeFactor, 0, 255))
    end

    function KScriptTosStartClose(closeAction)
        if kScriptTosClosing then
            return
        end
        kScriptTosClosing = true
        kScriptTosCloseAction = closeAction
        kScriptTosCloseStartedAt = ImGui.GetTime()
    end

    local shouldReleaseTosMouseCapture = false

    function KScriptTosReleaseMouseCursor()
        shouldReleaseTosMouseCapture = true
    end

    function KScriptTosCaptureMouseCursor()
        shouldReleaseTosMouseCapture = false
        ImGui.SetMouseCursor(ImGuiMouseCursor.Arrow)
        ImGui.CaptureMouseFromApp(true)
        HUD.DISABLE_FRONTEND_THIS_FRAME()
        PAD.DISABLE_ALL_CONTROL_ACTIONS(0)
        PAD.DISABLE_ALL_CONTROL_ACTIONS(1)
    end

    KS_TOS_MOUSE_RELEASE_HANDLER = EventMgr.RegisterHandler(eLuaEvent.ON_PRESENT, function()
        if shouldReleaseTosMouseCapture then
            shouldReleaseTosMouseCapture = false
            ImGui.CaptureMouseFromApp(false)
        end
        return true
    end)

    function KScriptTosPopStyleColor(styleColorCount)
        for _ = 1, styleColorCount do
            ImGui.PopStyleColor()
        end
    end

    function KScriptTosDrawMouseCursor(fadeFactor)
        local mouseX, mouseY = ImGui.GetMousePos()
        local outlineAlpha = KScriptTosAlpha(235, fadeFactor)
        local fillAlpha = KScriptTosAlpha(250, fadeFactor)
        local accentAlpha = KScriptTosAlpha(90, fadeFactor)
        ImGui.AddLine(mouseX - 1, mouseY - 1, mouseX - 1, mouseY + 20, 0, 0, 0, outlineAlpha, 3)
        ImGui.AddLine(mouseX - 1, mouseY - 1, mouseX + 14, mouseY + 11, 0, 0, 0, outlineAlpha, 3)
        ImGui.AddLine(mouseX + 14, mouseY + 11, mouseX + 8, mouseY + 12, 0, 0, 0, outlineAlpha, 3)
        ImGui.AddLine(mouseX + 8, mouseY + 12, mouseX + 12, mouseY + 20, 0, 0, 0, outlineAlpha, 3)
        ImGui.AddLine(mouseX + 12, mouseY + 20, mouseX + 8, mouseY + 22, 0, 0, 0, outlineAlpha, 3)
        ImGui.AddLine(mouseX + 8, mouseY + 22, mouseX + 4, mouseY + 14, 0, 0, 0, outlineAlpha, 3)
        ImGui.AddLine(mouseX + 4, mouseY + 14, mouseX - 1, mouseY + 20, 0, 0, 0, outlineAlpha, 3)
        ImGui.AddLine(mouseX, mouseY, mouseX, mouseY + 18, 236, 255, 244, fillAlpha, 1.6)
        ImGui.AddLine(mouseX, mouseY, mouseX + 12, mouseY + 10, 236, 255, 244, fillAlpha, 1.6)
        ImGui.AddLine(mouseX + 12, mouseY + 10, mouseX + 6, mouseY + 11, 236, 255, 244, fillAlpha, 1.6)
        ImGui.AddLine(mouseX + 6, mouseY + 11, mouseX + 10, mouseY + 19, 236, 255, 244, fillAlpha, 1.6)
        ImGui.AddLine(mouseX + 10, mouseY + 19, mouseX + 8, mouseY + 20, 236, 255, 244, fillAlpha, 1.6)
        ImGui.AddLine(mouseX + 8, mouseY + 20, mouseX + 4, mouseY + 12, 236, 255, 244, fillAlpha, 1.6)
        ImGui.AddLine(mouseX + 4, mouseY + 12, mouseX, mouseY + 18, 236, 255, 244, fillAlpha, 1.6)
        ImGui.AddLine(mouseX + 1, mouseY + 2, mouseX + 10, mouseY + 10, 84, 190, 120, accentAlpha, 2.6)
    end

    function KScriptTosGetTerminalUser()
        local nickname = SOCIALCLUB.SC_ACCOUNT_INFO_GET_NICKNAME()
        if type(nickname) ~= "string" or nickname == "" or nickname == "UNKNOWN" then
            nickname = "user"
        end
        local terminalUserName = tostring(nickname):gsub("%s+", "_")
        return terminalUserName
    end

    function KScriptTosDrawTypingCursor(textX, textY, typedText, fadeFactor)
        local textWidth, textHeight = ImGui.CalcTextSize(typedText or "")
        if not textWidth then
            textWidth = 0
        end
        if not textHeight then
            textHeight = 14
        end
        local lineHeight = ImGui.GetTextLineHeight() or textHeight
        local blinkPhase = (math.sin(ImGui.GetTime() * 8.0) + 1.0) * 0.5
        local cursorWidth = math.max(8, lineHeight * 0.48)
        local cursorHeight = math.max(14, lineHeight * 0.92)
        local cursorX = textX + textWidth + 4
        local cursorY = textY + math.max((lineHeight - cursorHeight) * 0.5, 0)
        local cursorAlpha = KScriptTosAlpha(120 + blinkPhase * 120, fadeFactor)
        ImGui.AddRectFilled(cursorX, cursorY, cursorX + cursorWidth, cursorY + cursorHeight, 255, 48, 62, cursorAlpha, 1)
        ImGui.AddRectFilled(cursorX + 2, cursorY + 2, cursorX + cursorWidth - 2, cursorY + cursorHeight - 2, 255, 155, 162, KScriptTosAlpha(42 + blinkPhase * 46, fadeFactor), 1)
    end

    function KScriptTosDrawWrappedText(textX, cursorY, maxLineWidth, paragraphText, textRed, textGreen, textBlue, textAlpha, opacity, lineHeight)
        paragraphText = tostring(paragraphText or "")
        if not lineHeight then
            lineHeight = 16
        end
        local currentLine = ""

        local function drawLine(lineText)
            ImGui.AddText(textX, cursorY, lineText, textRed, textGreen, textBlue, KScriptTosAlpha(textAlpha, opacity))
            cursorY = cursorY + lineHeight
        end

        for word in paragraphText:gmatch("%S+") do
            local candidateLine = currentLine == "" and word or currentLine .. " " .. word
            if maxLineWidth >= (ImGui.CalcTextSize(candidateLine) or 0) then
                currentLine = candidateLine
            else
                if currentLine ~= "" then
                    drawLine(currentLine)
                end
                currentLine = word
            end
        end
        if currentLine ~= "" then
            drawLine(currentLine)
        end
        return cursorY
    end

    function KScriptTosCountWrappedLines(maxLineWidth, paragraphText)
        paragraphText = tostring(paragraphText or "")
        if paragraphText == "" then
            return 1
        end
        local currentLine = ""
        local lineCount = 0
        for word in paragraphText:gmatch("%S+") do
            local candidateLine = currentLine == "" and word or currentLine .. " " .. word
            if maxLineWidth >= (ImGui.CalcTextSize(candidateLine) or 0) or currentLine == "" then
                currentLine = candidateLine
            else
                lineCount = lineCount + 1
                currentLine = word
            end
        end
        if currentLine ~= "" then
            lineCount = lineCount + 1
        end
        return math.max(lineCount, 1)
    end

    function KScriptTosEllipsize(inputText, maxWidth)
        local displayText = tostring(inputText or "")
        if maxWidth >= (ImGui.CalcTextSize(displayText) or 0) then
            return displayText
        end
        for prefixLength = #displayText, 1, -1 do
            local ellipsizedText = displayText:sub(1, prefixLength) .. ".."
            if maxWidth >= (ImGui.CalcTextSize(ellipsizedText) or 0) then
                return ellipsizedText
            end
        end
        return ".."
    end

    function KScriptTosBuildTerminalPreviewLines(username)
        local promptUser = tostring(username or "user")
        local promptPrefix = promptUser .. "@K-Script:$ "
        return {
            { text = promptPrefix .. "whoami", kind = "cmd", speed = 115, pause = 0.18 },
            { text = promptUser, kind = "out", speed = 180, pause = 0.18 },
            { text = promptPrefix .. "kscriptctl session --verify", kind = "cmd", speed = 125, pause = 0.16 },
            { text = "[ ok ] identity token verified", kind = "ok", speed = 170, pause = 0.12 },
            { text = promptPrefix .. "mount /rules --tos", kind = "cmd", speed = 125, pause = 0.16 },
            { text = "[ ok ] ruleset mounted read-only", kind = "ok", speed = 170, pause = 0.12 },
            { text = "[ wait ] decision gate armed", kind = "warn", speed = 160, pause = 0.1 },
        }
    end

    function KScriptTosGetTerminalPreviewWidth(username)
        local widestLineWidth = 0
        for _, previewLine in ipairs(KScriptTosBuildTerminalPreviewLines(username)) do
            local lineWidth = ImGui.CalcTextSize(previewLine.text) or 0
            widestLineWidth = math.max(widestLineWidth, lineWidth)
        end
        return math.max(260, math.ceil(widestLineWidth + 38))
    end

    function KScriptTosTerminalPreviewColor(lineKind)
        if lineKind == "cmd" then
            return 88, 255, 166, 245
        end
        if lineKind == "ok" then
            return 130, 235, 165, 238
        end
        if lineKind == "warn" then
            return 245, 198, 104, 238
        end
        return 214, 219, 225, 230
    end

    function KScriptTosDrawTerminalPreview(originX, originY, panelWidth, panelHeight, username, elapsedTime, opacity)
        ImGui.AddRectFilled(originX, originY, originX + panelWidth, originY + panelHeight, 4, 5, 7, KScriptTosAlpha(244, opacity), 8)
        ImGui.AddRectFilled(originX, originY, originX + panelWidth, originY + 28, 23, 24, 27, KScriptTosAlpha(250, opacity), 8)
        ImGui.AddRectFilled(originX, originY + 22, originX + panelWidth, originY + 28, 23, 24, 27, KScriptTosAlpha(250, opacity), 0)
        ImGui.AddRectFilled(originX + 11, originY + 10, originX + 19, originY + 18, 255, 92, 92, KScriptTosAlpha(240, opacity), 4)
        ImGui.AddRectFilled(originX + 27, originY + 10, originX + 35, originY + 18, 255, 199, 86, KScriptTosAlpha(230, opacity), 4)
        ImGui.AddRectFilled(originX + 43, originY + 10, originX + 51, originY + 18, 96, 224, 130, KScriptTosAlpha(225, opacity), 4)
        local previewLines = KScriptTosBuildTerminalPreviewLines(username)
        local remainingTime = math.max(0, elapsedTime - 0.18)
        local lineY = originY + 44
        local lineX = originX + 16
        local maxTextWidth = panelWidth - 30
        local scanBarX = originX + 12 + elapsedTime * 84 % math.max(panelWidth - 24, 1)
        ImGui.AddRectFilled(scanBarX, originY + 29, math.min(scanBarX + 54, originX + panelWidth - 12), originY + 31, 84, 190, 120, KScriptTosAlpha(38, opacity), 2)
        for _, previewLine in ipairs(previewLines) do
            local lineText = previewLine.text
            local charsPerSecond = previewLine.speed or 150
            local lineDuration = #lineText / charsPerSecond + (previewLine.pause or 0.12)
            local isTyping = false
            local visibleCharCount
            if remainingTime >= lineDuration then
                visibleCharCount = #lineText
                remainingTime = remainingTime - lineDuration
            else
                visibleCharCount = math.min(#lineText, math.max(math.floor(remainingTime * charsPerSecond), 0))
                isTyping = true
                remainingTime = -1
            end
            if visibleCharCount > 0 then
                local visibleText = KScriptTosEllipsize(lineText:sub(1, visibleCharCount), maxTextWidth)
                local lineRed, lineGreen, lineBlue, lineAlpha = KScriptTosTerminalPreviewColor(previewLine.kind)
                ImGui.AddText(lineX, lineY, visibleText, lineRed, lineGreen, lineBlue, KScriptTosAlpha(lineAlpha, opacity))
            end
            if isTyping then
                local textBeforeCursor = KScriptTosEllipsize(lineText:sub(1, visibleCharCount), maxTextWidth - 10)
                KScriptTosDrawTypingCursor(lineX, lineY, textBeforeCursor, opacity)
                break
            end
            lineY = lineY + 17
        end
    end

    function KScriptTosDrawTermCard(cardX, cardY, cardWidth, cardTitle, bodyParagraphs, opacity, revealProgress)
        local lineHeight = 13
        local bodyHeight = 0
        if not revealProgress then
            revealProgress = 1.0
        end
        local cardOpacity = opacity * KScriptTosClamp(revealProgress, 0.0, 1.0)
        local animatedX = cardX + (1.0 - KScriptTosClamp(revealProgress, 0.0, 1.0)) * 18
        local animatedY = cardY + (1.0 - revealProgress) * 22
        for _, paragraphToMeasure in ipairs(bodyParagraphs) do
            bodyHeight = bodyHeight + KScriptTosCountWrappedLines(cardWidth - 30, paragraphToMeasure) * lineHeight + 3
        end
        local cardHeight = 43 + bodyHeight
        local titleY = animatedY + 10
        local bodyY = titleY + 20
        ImGui.AddRectFilled(animatedX, animatedY + 6, animatedX + cardWidth, animatedY + cardHeight + 6, 0, 0, 0, KScriptTosAlpha(45, cardOpacity), 8)
        ImGui.AddRectFilled(animatedX, animatedY, animatedX + cardWidth, animatedY + cardHeight, 18, 20, 24, KScriptTosAlpha(238, cardOpacity), 8)
        ImGui.AddRectFilled(animatedX, animatedY, animatedX + 5, animatedY + cardHeight, 84, 190, 120, KScriptTosAlpha(220, cardOpacity), 5)
        ImGui.AddText(animatedX + 15, titleY, cardTitle, 244, 246, 248, KScriptTosAlpha(248, cardOpacity))
        for _, paragraphToDraw in ipairs(bodyParagraphs) do
            bodyY = KScriptTosDrawWrappedText(animatedX + 15, bodyY, cardWidth - 30, paragraphToDraw, 185, 190, 196, 226, cardOpacity, lineHeight) + 3
        end
        return cardHeight
    end

    function renderTermsOfServicePrompt()
        if not kScriptTosGateActive or HasAcceptedTermsOfService() or ShouldUnload() then
            return false
        end
        KScriptTosCaptureMouseCursor()
        if kScriptTosPromptStartedAt == nil then
            kScriptTosPromptStartedAt = ImGui.GetTime()
            kScriptTosClosing = false
            kScriptTosCloseStartedAt = nil
            kScriptTosCloseAction = nil
        end
        local currentTime = ImGui.GetTime()
        if kScriptTosClosing and kScriptTosCloseStartedAt ~= nil and currentTime - kScriptTosCloseStartedAt >= K_SCRIPT_TOS_CLOSE_DURATION then
            if kScriptTosCloseAction == "accept" then
                if AcceptTermsOfService() then
                    return true
                end
                kScriptTosClosing = false
                kScriptTosCloseStartedAt = nil
                kScriptTosCloseAction = nil
                kScriptTosPromptStartedAt = currentTime - K_SCRIPT_TOS_WAIT_SECONDS
            else
                DeclineTermsOfService()
                return true
            end
        end
        local promptElapsed = currentTime - kScriptTosPromptStartedAt
        local unlockProgress = math.min(promptElapsed / K_SCRIPT_TOS_WAIT_SECONDS, 1.0)
        local unlockSecondsLeft = math.max(K_SCRIPT_TOS_WAIT_SECONDS - promptElapsed, 0.0)
        local isDecisionUnlocked = unlockProgress >= 1.0 and kScriptTosClosing
        local terminalUserName = KScriptTosGetTerminalUser()
        local windowScaleProgress = KScriptTosEaseOutBack(promptElapsed / K_SCRIPT_TOS_OPEN_DURATION)
        local fadeProgress = KScriptTosEaseSmoothStep(promptElapsed / 0.62)
        if kScriptTosClosing and kScriptTosCloseStartedAt ~= nil then
            fadeProgress = 1.0 - KScriptTosEaseInCubic((currentTime - kScriptTosCloseStartedAt) / K_SCRIPT_TOS_CLOSE_DURATION)
            windowScaleProgress = fadeProgress
        end
        local uiAlpha = KScriptTosClamp(fadeProgress, 0.02, 1.0)
        local popScale = KScriptTosClamp(windowScaleProgress, 0.02, 1.04)
        local displayWidth, displayHeight = ImGui.GetDisplaySize()
        local panelPadding = 24
        local columnGap = 18
        local terminalPreviewWidth = KScriptTosGetTerminalPreviewWidth(terminalUserName)
        local sessionColumnWidth = terminalPreviewWidth + 28
        local userBadgeWidth = math.max(236, (ImGui.CalcTextSize(terminalUserName .. "@K-Script") or 0) + 26)
        local preferredDialogWidth = math.max(displayWidth * 0.39, sessionColumnWidth + columnGap + 560 + panelPadding * 2, userBadgeWidth + 430)
        local maxDialogWidth = math.max(840, displayWidth - 80)
        local dialogWidth = math.min(math.max(preferredDialogWidth, 840), maxDialogWidth) * (0.84 + 0.16 * popScale)
        local dialogHeight = math.min(math.max(displayHeight * 0.54, 550), 625) * (0.7 + 0.3 * popScale)
        local dialogX = (displayWidth - dialogWidth) * 0.5
        local dialogY = (displayHeight - dialogHeight) * 0.5 + (1.0 - popScale) * 26
        ImGui.SetNextWindowPos(0, 0, ImGuiCond.Always)
        ImGui.SetNextWindowSize(displayWidth, displayHeight, ImGuiCond.Always)
        ImGui.SetNextWindowFocus()
        if ImGui.Begin("##KScriptTermsModernAgreement", true, ImGuiWindowFlags.NoCollapse | ImGuiWindowFlags.NoResize | ImGuiWindowFlags.NoMove | ImGuiWindowFlags.NoSavedSettings | ImGuiWindowFlags.NoTitleBar | ImGuiWindowFlags.NoBackground | ImGuiWindowFlags.NoScrollbar) then
            local windowPosX, windowPosY = ImGui.GetWindowPos()
            local panelLeft = dialogX
            local panelTop = dialogY
            local panelWidth = dialogWidth
            local panelHeight = dialogHeight
            local headerHeight = 74
            local footerHeight = 72
            local accentRed = 84
            local accentGreen = 190
            local accentBlue = 120
            ImGui.AddRectFilled(0, 0, displayWidth, displayHeight, 0, 0, 0, KScriptTosAlpha(105, uiAlpha), 0)
            ImGui.AddRectFilled(panelLeft - 10, panelTop - 10, panelLeft + panelWidth + 10, panelTop + panelHeight + 10, 0, 0, 0, KScriptTosAlpha(95, uiAlpha), 16)
            ImGui.AddRectFilled(panelLeft, panelTop, panelLeft + panelWidth, panelTop + panelHeight, 12, 14, 18, KScriptTosAlpha(248, uiAlpha), 12)
            ImGui.AddRectFilled(panelLeft + 1, panelTop + 1, panelLeft + panelWidth - 1, panelTop + headerHeight, 20, 22, 28, KScriptTosAlpha(248, uiAlpha), 12)
            ImGui.AddRectFilled(panelLeft + 1, panelTop + headerHeight - 10, panelLeft + panelWidth - 1, panelTop + headerHeight, 20, 22, 28, KScriptTosAlpha(248, uiAlpha), 0)
            ImGui.AddLine(panelLeft + 22, panelTop + headerHeight, panelLeft + panelWidth - 22, panelTop + headerHeight, accentRed, accentGreen, accentBlue, KScriptTosAlpha(165, uiAlpha), 2)
            local shimmerWidth = 130
            local shimmerStartX = panelLeft + promptElapsed * 260 % math.max(panelWidth + shimmerWidth, 1)
            local shimmerEndX = math.min(shimmerStartX + shimmerWidth, panelLeft + panelWidth)
            if shimmerStartX < panelLeft + panelWidth then
                ImGui.AddRectFilled(shimmerStartX, panelTop, shimmerEndX, panelTop + 2, 126, 255, 178, KScriptTosAlpha(75, uiAlpha), 1)
            end
            ImGui.AddText(panelLeft + panelPadding, panelTop + 20, "K-Script Terms", 248, 250, 252, KScriptTosAlpha(255, uiAlpha))
            ImGui.AddText(panelLeft + panelPadding, panelTop + 43, "Review required before the authenticated splash continues", 164, 170, 178, KScriptTosAlpha(238, uiAlpha))
            local headerBadgeWidth = userBadgeWidth
            ImGui.AddRectFilled(panelLeft + panelWidth - headerBadgeWidth - panelPadding, panelTop + 22, panelLeft + panelWidth - panelPadding, panelTop + 52, 30, 33, 39, KScriptTosAlpha(236, uiAlpha), 7)
            ImGui.AddText(panelLeft + panelWidth - headerBadgeWidth - panelPadding + 13, panelTop + 30, terminalUserName .. "@K-Script", 156, 255, 190, KScriptTosAlpha(238, uiAlpha))
            local contentTop = panelTop + headerHeight + 18
            local sessionColumnX = panelLeft + panelPadding
            local sessionColumnY = contentTop
            local rulesColumnX = sessionColumnX + sessionColumnWidth + columnGap
            local rulesColumnWidth = panelWidth - panelPadding - rulesColumnX + panelLeft
            ImGui.AddRectFilled(sessionColumnX, sessionColumnY, sessionColumnX + sessionColumnWidth, sessionColumnY + (panelTop + panelHeight - footerHeight - 14 - contentTop), 17, 19, 24, KScriptTosAlpha(238, uiAlpha), 10)
            ImGui.AddText(sessionColumnX + 16, sessionColumnY + 18, "Session Check", 238, 241, 245, KScriptTosAlpha(245, uiAlpha))
            ImGui.AddText(sessionColumnX + 16, sessionColumnY + 40, "Terminal preview", 136, 143, 153, KScriptTosAlpha(224, uiAlpha))
            local terminalPreviewHeight = 184
            KScriptTosDrawTerminalPreview(sessionColumnX + 14, sessionColumnY + 72, terminalPreviewWidth, terminalPreviewHeight, terminalUserName, promptElapsed, uiAlpha)
            local unlockSectionY = sessionColumnY + 72 + terminalPreviewHeight + 32
            ImGui.AddText(sessionColumnX + 16, unlockSectionY, "Decision unlock", 220, 224, 229, KScriptTosAlpha(235, uiAlpha))
            ImGui.AddRectFilled(sessionColumnX + 16, unlockSectionY + 24, sessionColumnX + sessionColumnWidth - 16, unlockSectionY + 31, 35, 38, 44, KScriptTosAlpha(245, uiAlpha), 4)
            ImGui.AddRectFilled(sessionColumnX + 16, unlockSectionY + 24, sessionColumnX + 16 + (sessionColumnWidth - 32) * unlockProgress, unlockSectionY + 31, accentRed, accentGreen, accentBlue, KScriptTosAlpha(245, uiAlpha), 4)
            if isDecisionUnlocked then
                ImGui.AddText(sessionColumnX + 16, unlockSectionY + 45, "Ready for your decision", 156, 255, 190, KScriptTosAlpha(235, uiAlpha))
            else
                ImGui.AddText(sessionColumnX + 16, unlockSectionY + 45, ("Unlocks in %.1fs"):format(unlockSecondsLeft), 170, 176, 184, KScriptTosAlpha(225, uiAlpha))
            end
            ImGui.AddText(rulesColumnX, contentTop, "Rules Summary", 244, 246, 248, KScriptTosAlpha(250, uiAlpha))
            ImGui.AddText(rulesColumnX, contentTop + 22, "These are the active K-Script usage terms.", 148, 154, 164, KScriptTosAlpha(228, uiAlpha))
            local cardX = rulesColumnX
            local nextCardY = contentTop + 44
            local cardWidth = rulesColumnWidth
            local cardRevealDelay = 0.42

            local function getCardRevealProgress(cardIndex)
                return KScriptTosEaseOutBack((promptElapsed - cardRevealDelay - (cardIndex - 1) * 0.13) / 0.46)
            end

            for termCardIndex, termCard in ipairs(K_SCRIPT_TOS_CARDS) do
                nextCardY = nextCardY + KScriptTosDrawTermCard(cardX, nextCardY, cardWidth, termCard.title, termCard.body, uiAlpha, getCardRevealProgress(termCardIndex))
                if termCardIndex < #K_SCRIPT_TOS_CARDS then
                    nextCardY = nextCardY + 8
                end
            end
            local footerTop = panelTop + panelHeight - footerHeight
            ImGui.AddRectFilled(panelLeft + 1, footerTop, panelLeft + panelWidth - 1, panelTop + panelHeight - 1, 16, 18, 23, KScriptTosAlpha(248, uiAlpha), 12)
            ImGui.AddRectFilled(panelLeft + 1, footerTop, panelLeft + panelWidth - 1, footerTop + 8, 16, 18, 23, KScriptTosAlpha(248, uiAlpha), 0)
            local footerMessage = "Read the summary before choosing."
            if isDecisionUnlocked then
                footerMessage = "Choose how to continue. Accept stores the terms file in your K-Script folder."
            elseif kScriptTosClosing then
                footerMessage = "Closing..."
            end
            if kScriptTosWriteError ~= nil then
                footerMessage = kScriptTosWriteError
            end
            ImGui.PushStyleVar(ImGuiStyleVar.Alpha, uiAlpha)
            local acceptButtonWidth = 188
            local declineButtonWidth = 90
            local buttonHeight = 34
            local buttonGroupWidth = acceptButtonWidth + declineButtonWidth + 10 + 24
            local buttonGroupX = panelLeft + panelWidth - panelPadding - buttonGroupWidth
            local buttonGroupY = footerTop + 13
            local fittedFooterMessage = KScriptTosEllipsize(footerMessage, buttonGroupX - panelLeft - panelPadding * 2 - 12)
            ImGui.AddText(panelLeft + panelPadding, footerTop + 20, fittedFooterMessage, 196, 202, 210, KScriptTosAlpha(236, uiAlpha))
            ImGui.AddRectFilled(buttonGroupX, buttonGroupY, buttonGroupX + buttonGroupWidth, buttonGroupY + (buttonHeight + 12), 22, 25, 30, KScriptTosAlpha(242, uiAlpha), 9)
            ImGui.AddRectFilled(buttonGroupX, buttonGroupY, buttonGroupX + buttonGroupWidth, buttonGroupY + 3, accentRed, accentGreen, accentBlue, KScriptTosAlpha(isDecisionUnlocked and 230 or 90, uiAlpha), 3)
            ImGui.SetCursorPosX(buttonGroupX - windowPosX + 12)
            ImGui.SetCursorPosY(buttonGroupY - windowPosY + 6)
            ImGui.PushStyleColor(ImGuiCol.Text, 0.96, 1.0, 0.97, 1.0)
            ImGui.PushStyleColor(ImGuiCol.Button, 0.08, 0.5, 0.24, 0.98)
            ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.1, 0.68, 0.32, 1.0)
            ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.06, 0.8, 0.36, 1.0)
            if not isDecisionUnlocked then
                ImGui.BeginDisabled()
            end
            if ImGui.Button("ACCEPT TERMS", acceptButtonWidth, buttonHeight) then
                KScriptTosStartClose("accept")
            end
            ImGui.SameLine()
            KScriptTosPopStyleColor(4)
            ImGui.PushStyleColor(ImGuiCol.Text, 1.0, 0.96, 0.96, 1.0)
            ImGui.PushStyleColor(ImGuiCol.Button, 0.54, 0.09, 0.11, 0.98)
            ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.76, 0.1, 0.14, 1.0)
            ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.95, 0.06, 0.1, 1.0)
            if ImGui.Button("DECLINE", declineButtonWidth, buttonHeight) then
                KScriptTosStartClose("decline")
            end
            if not isDecisionUnlocked then
                ImGui.EndDisabled()
            end
            KScriptTosPopStyleColor(4)
            ImGui.PopStyleVar()
            KScriptTosDrawMouseCursor(uiAlpha)
        end
        ImGui.End()
        return true
    end

    yeetwindmills = {}
    externalTamperDetected = false
    discordID = nil
    discordRpcIdentityReady = false
    closespawnHandler = nil
    objHandler = nil
    pedHandler = nil
    taskPatchHandler = nil
    windowPositionSet = false
    infowindowPositionSet = false
    globalNumEvents = 0
    StoredPos = { GameInfoDisplay = nil, ModderDisplay = nil }
    voiceChatters = {}
    if not (function()
        if type(_ENV) ~= "table" then
            return false
        end
        for _, forbiddenGlobalName in ipairs({
            "debug",
            "package",
            "require",
            "loadfile",
            "rawequal",
            "getmetatable",
            "print",
            "error",
            "_G",
            "_ENV",
        }) do
            if _ENV[forbiddenGlobalName] ~= nil then
                return false
            end
        end
        if type(assert) ~= "function" then
            return false
        end
        if type(pcall) ~= "function" then
            return false
        end
        if type(xpcall) ~= "function" then
            return false
        end
        if type(tostring) ~= "function" then
            return false
        end
        if type(type) ~= "function" then
            return false
        end
        if type(math) ~= "table" then
            return false
        end
        if type(string) ~= "table" then
            return false
        end
        if type(table) ~= "table" then
            return false
        end
        if type(coroutine) ~= "table" then
            return false
        end
        if type(os) ~= "table" then
            return false
        end
        if os.execute ~= nil then
            return false
        end
        if os.remove ~= nil then
            return false
        end
        if os.rename ~= nil then
            return false
        end
        if os.getenv ~= nil then
            return false
        end
        if os.setlocale ~= nil then
            return false
        end
        if type(io) ~= "table" then
            return false
        end
        if type(io.open) ~= "function" then
            return false
        end
        if io.popen ~= nil then
            return false
        end
        if io.tmpfile ~= nil then
            return false
        end
        if type(json) ~= "table" then
            return false
        end
        if type(json.encode) ~= "function" then
            return false
        end
        if type(json.decode) ~= "function" then
            return false
        end
        if type(collectgarbage) ~= "function" then
            return false
        end
        if __ks_bridge_v3 ~= loaderAdapter or __ks_bridge_v3.version ~= 3 or type(__ks_bridge_v3.request) ~= "function" then
            return false
        end
        if type(load) ~= "function" then
            return false
        end
        if type(dofile) ~= "function" then
            return false
        end
        return true
    end)() then
        os.exit(69)
        requestScriptUnload()
    end
    KS_MODULE_LOAD = load
    KS_MODULE_ENV = _ENV
end
local blake2sDigest, bytesToHex, registeredFeatures, throttledYieldCallCount, yieldScriptPeriodically, buildFeatureActionLogId
do
    local function blake2sXorUint32(leftWord, rightWord)
        return (leftWord ~ rightWord) & 4294967295
    end

    local function blake2sShiftRight(inputWord, shiftBits)
        return inputWord >> shiftBits & 4294967295
    end

    local function blake2sRotateRight(wordToRotate, rotateBits)
        return (wordToRotate >> rotateBits | wordToRotate << 32 - rotateBits) & 4294967295
    end

    local BLAKE2S_IV = { 1779033703, 3144134277, 1013904242, 2773480762, 1359893119, 2600822924, 528734635, 1541459225 }
    local BLAKE2S_SIGMA = {
        { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15 },
        { 14, 10, 4, 8, 9, 15, 13, 6, 1, 12, 0, 2, 11, 7, 5, 3 },
        { 11, 8, 12, 0, 5, 2, 15, 13, 10, 14, 3, 6, 7, 1, 9, 4 },
        { 7, 9, 3, 1, 13, 12, 11, 14, 2, 6, 5, 10, 4, 0, 15, 8 },
        { 9, 0, 5, 7, 2, 4, 10, 15, 14, 1, 11, 12, 6, 8, 3, 13 },
        { 2, 12, 6, 10, 0, 11, 8, 3, 4, 13, 7, 5, 15, 14, 1, 9 },
        { 12, 5, 1, 15, 14, 13, 4, 10, 0, 7, 6, 3, 9, 2, 8, 11 },
        { 13, 11, 7, 14, 12, 1, 3, 9, 5, 0, 15, 4, 8, 6, 2, 10 },
        { 6, 15, 14, 9, 11, 3, 0, 8, 12, 2, 13, 7, 1, 4, 10, 5 },
        { 10, 2, 8, 4, 7, 6, 1, 5, 15, 11, 9, 14, 3, 12, 13, 0 },
    }

    local function blake2sMixG(stateWordA, stateWordB, stateWordC, stateWordD, messageWordX, messageWordY)
        stateWordA = stateWordA + stateWordB + messageWordX & 4294967295
        stateWordD = blake2sRotateRight(blake2sXorUint32(stateWordD, stateWordA), 16)
        stateWordC = stateWordC + stateWordD & 4294967295
        stateWordB = blake2sRotateRight(blake2sXorUint32(stateWordB, stateWordC), 12)
        stateWordA = stateWordA + stateWordB + messageWordY & 4294967295
        stateWordD = blake2sRotateRight(blake2sXorUint32(stateWordD, stateWordA), 8)
        stateWordC = stateWordC + stateWordD & 4294967295
        return stateWordA, blake2sRotateRight(blake2sXorUint32(stateWordB, stateWordC), 7), stateWordC, stateWordD
    end

    local blake2sMessageWords = {}
    for messageWordIndex = 1, 16 do
        blake2sMessageWords[messageWordIndex] = 0
    end

    local function blake2sCompress(hashState, blockInput, byteCounter, isFinalBlock)
        local blockBytes = blockInput
        for wordIndex = 1, 16 do
            local byteOffset = (wordIndex - 1) * 4
            blake2sMessageWords[wordIndex] = (blockBytes:byte(byteOffset + 1) or 0) + ((blockBytes:byte(byteOffset + 2) or 0) << 8) + ((blockBytes:byte(byteOffset + 3) or 0) << 16) + ((blockBytes:byte(byteOffset + 4) or 0) << 24)
        end
        local workingVector = {}
        for stateIndex = 1, 8 do
            workingVector[stateIndex] = hashState[stateIndex]
        end
        for ivSlotIndex = 9, 16 do
            workingVector[ivSlotIndex] = BLAKE2S_IV[ivSlotIndex - 8]
        end
        workingVector[13] = blake2sXorUint32(workingVector[13], byteCounter & 4294967295)
        workingVector[14] = blake2sXorUint32(workingVector[14], blake2sShiftRight(byteCounter, 32))
        if isFinalBlock then
            workingVector[15] = blake2sXorUint32(workingVector[15], 4294967295)
        end
        for roundIndex = 1, 10 do
            local roundSigma = BLAKE2S_SIGMA[roundIndex]
            local firstColumnA, firstColumnB, firstColumnC, firstColumnD = blake2sMixG(workingVector[1], workingVector[5], workingVector[9], workingVector[13], blake2sMessageWords[roundSigma[1] + 1], blake2sMessageWords[roundSigma[2] + 1])
            workingVector[13] = firstColumnD
            workingVector[9] = firstColumnC
            workingVector[5] = firstColumnB
            workingVector[1] = firstColumnA
            local secondColumnA, secondColumnB, secondColumnC, secondColumnD = blake2sMixG(workingVector[2], workingVector[6], workingVector[10], workingVector[14], blake2sMessageWords[roundSigma[3] + 1], blake2sMessageWords[roundSigma[4] + 1])
            workingVector[14] = secondColumnD
            workingVector[10] = secondColumnC
            workingVector[6] = secondColumnB
            workingVector[2] = secondColumnA
            local thirdColumnA, thirdColumnB, thirdColumnC, thirdColumnD = blake2sMixG(workingVector[3], workingVector[7], workingVector[11], workingVector[15], blake2sMessageWords[roundSigma[5] + 1], blake2sMessageWords[roundSigma[6] + 1])
            workingVector[15] = thirdColumnD
            workingVector[11] = thirdColumnC
            workingVector[7] = thirdColumnB
            workingVector[3] = thirdColumnA
            local fourthColumnA, fourthColumnB, fourthColumnC, fourthColumnD = blake2sMixG(workingVector[4], workingVector[8], workingVector[12], workingVector[16], blake2sMessageWords[roundSigma[7] + 1], blake2sMessageWords[roundSigma[8] + 1])
            workingVector[16] = fourthColumnD
            workingVector[12] = fourthColumnC
            workingVector[8] = fourthColumnB
            workingVector[4] = fourthColumnA
            local firstDiagonalA, firstDiagonalB, firstDiagonalC, firstDiagonalD = blake2sMixG(workingVector[1], workingVector[6], workingVector[11], workingVector[16], blake2sMessageWords[roundSigma[9] + 1], blake2sMessageWords[roundSigma[10] + 1])
            workingVector[16] = firstDiagonalD
            workingVector[11] = firstDiagonalC
            workingVector[6] = firstDiagonalB
            workingVector[1] = firstDiagonalA
            local secondDiagonalA, secondDiagonalB, secondDiagonalC, secondDiagonalD = blake2sMixG(workingVector[2], workingVector[7], workingVector[12], workingVector[13], blake2sMessageWords[roundSigma[11] + 1], blake2sMessageWords[roundSigma[12] + 1])
            workingVector[13] = secondDiagonalD
            workingVector[12] = secondDiagonalC
            workingVector[7] = secondDiagonalB
            workingVector[2] = secondDiagonalA
            local thirdDiagonalA, thirdDiagonalB, thirdDiagonalC, thirdDiagonalD = blake2sMixG(workingVector[3], workingVector[8], workingVector[9], workingVector[14], blake2sMessageWords[roundSigma[13] + 1], blake2sMessageWords[roundSigma[14] + 1])
            workingVector[14] = thirdDiagonalD
            workingVector[9] = thirdDiagonalC
            workingVector[8] = thirdDiagonalB
            workingVector[3] = thirdDiagonalA
            local fourthDiagonalA, fourthDiagonalB, fourthDiagonalC, fourthDiagonalD = blake2sMixG(workingVector[4], workingVector[5], workingVector[10], workingVector[15], blake2sMessageWords[roundSigma[15] + 1], blake2sMessageWords[roundSigma[16] + 1])
            workingVector[15] = fourthDiagonalD
            workingVector[10] = fourthDiagonalC
            workingVector[5] = fourthDiagonalB
            workingVector[4] = fourthDiagonalA
        end
        for hashWordIndex = 1, 8 do
            hashState[hashWordIndex] = blake2sXorUint32(hashState[hashWordIndex], workingVector[hashWordIndex] ~ workingVector[hashWordIndex + 8])
        end
    end

    function blake2sDigest(inputMessage, digestLength)
        if not digestLength then
            digestLength = 32
        end
        local hashState = {}
        for ivIndex = 1, 8 do
            hashState[ivIndex] = BLAKE2S_IV[ivIndex]
        end
        hashState[1] = hashState[1] ~ 16842752 ~ digestLength
        local messageLength = #inputMessage
        local blockStart = 1
        local bytesCompressed = 0
        while messageLength - blockStart + 1 > 64 do
            local blockChunk = inputMessage:sub(blockStart, blockStart + 63)
            bytesCompressed = bytesCompressed + 64
            blake2sCompress(hashState, blockChunk, bytesCompressed, false)
            blockStart = blockStart + 64
        end
        local lastBlockBytes = inputMessage:sub(blockStart)
        blake2sCompress(hashState, lastBlockBytes, bytesCompressed + #lastBlockBytes, true)
        local digestBytes = {}
        for digestByteIndex = 1, digestLength do
            local stateWordIndex = math.ceil(digestByteIndex / 4)
            digestBytes[digestByteIndex] = string.char(hashState[stateWordIndex] >> (digestByteIndex - 1) % 4 * 8 & 255)
        end
        return table.concat(digestBytes)
    end

    function bytesToHex(rawBytes)
        local hexString = rawBytes:gsub(".", function(byteChar)
            return string.format("%02x", string.byte(byteChar))
        end)
        return hexString
    end

    registeredFeatures = "1"
    throttledYieldCallCount = "7c2f91e4a0b6d835"
    yieldScriptPeriodically = "05b8e13fc4d729a6"
    buildFeatureActionLogId = 300000
end
local replayCacheOrLogSkipSet, RSA_MODULUS_HEX, RSA_PUBLIC_EXPONENT_HEX, RSA_MONTGOMERY_R2_HEX, truncateToUint32, yieldIfTimeSliceElapsed, resetYieldSliceClock, computeSha256, computeHmacSha256, generateRandomHex, base64Decode
do
    replayCacheOrLogSkipSet = {}
    RSA_MODULUS_HEX = "89c121a8b233fa6921028a4bcc5a216676471c5b33c9251bb9e0702b927908d5d089017dfa03a2ed0e169a0b18b29353a44ec39a35acc0bddbe1032d00aae42bba7e1643963b10da0d69acf9f3f1d58d37f2f0a03479c3330d56b24771ca1c86d6112d0f6600d518647f9f96622f900b5fc004618b78d742b515dcfb4d45bcba276837816f1eabd491099809e9ea6dd726699d9176f020d9cf6c846c56a10266394a51f29d52792e85cc1cc7d27e000ad270bd38ce581899685d6e68a34bceb746823892bc845059a010a9f15ecd6ae046b66b0faf5332eabbe523d9e2bc14d0f2dddf7f57cbfd32e3608277dcaac263ec04363e02f71835a632a6ba9f7da9fb"
    RSA_PUBLIC_EXPONENT_HEX = "010001"
    RSA_MONTGOMERY_R2_HEX = "74c3bc0e6f005be5f4656e0391cbe3e9495f00204cd444f4287872a90263544ac4269943364236b000ede588a6cf5e35bf5a1d8da80e8ff5e463fa6047ef6f5d6215d8a3faf453ea66b62a4c1f85a953f66386005261256fdd121a848bdca60fc6488b1cb7419ea55e7cc6ce31094a0d3f8ff42895bf986ad3678870020de2ed8c2ea546df7382bc14c79850121914b497cebc045b75174666f20d07dc38dde6cc9c0d587ef2b8bcebaf0169d2633dbf7c117a9990ddf929499a731258c0b4fce50d48daf85717fd0f931df888d56e01756214685c194d26b38b8e55128f85edc9e11d89d27a9ca6964da48275442f8a5e1bc7fcc815968a30633a1864a632da"

    function truncateToUint32(wideInteger)
        return wideInteger & 4294967295
    end

    local function sha256RotateRight(rotateWord, rotateBitCount)
        return truncateToUint32(rotateWord >> rotateBitCount | rotateWord << 32 - rotateBitCount)
    end

    local function sha256ShiftRight(shiftWord, shiftBitCount)
        return truncateToUint32(shiftWord >> shiftBitCount)
    end

    local sha256RoundConstants = {
        1116352408,
        1899447441,
        3049323471,
        3921009573,
        961987163,
        1508970993,
        2453635748,
        2870763221,
        3624381080,
        310598401,
        607225278,
        1426881987,
        1925078388,
        2162078206,
        2614888103,
        3248222580,
        3835390401,
        4022224774,
        264347078,
        604807628,
        770255983,
        1249150122,
        1555081692,
        1996064986,
        2554220882,
        2821834349,
        2952996808,
        3210313671,
        3336571891,
        3584528711,
        113926993,
        338241895,
        666307205,
        773529912,
        1294757372,
        1396182291,
        1695183700,
        1986661051,
        2177026350,
        2456956037,
        2730485921,
        2820302411,
        3259730800,
        3345764771,
        3516065817,
        3600352804,
        4094571909,
        275423344,
        430227734,
        506948616,
        659060556,
        883997877,
        958139571,
        1322822218,
        1537002063,
        1747873779,
        1955562222,
        2024104815,
        2227730452,
        2361852424,
        2428436474,
        2756734187,
        3204031479,
        3329325298,
    }

    function yieldIfTimeSliceElapsed()
        if not isTableOrUserdata(Script) or type(Script.Yield) ~= "function" then
            return
        end
        local currentClock = os.clock()
        local lastSliceClock = tonumber(sha256RoundConstants.__slice_clock)
        if not lastSliceClock then
            sha256RoundConstants.__slice_clock = currentClock
            return
        end
        if currentClock - lastSliceClock < 0.012 then
            return
        end
        sha256RoundConstants.__slice_clock = currentClock
        Script.Yield(0)
        local resumedClock = os.clock()
        sha256RoundConstants.__slice_clock = resumedClock
    end

    function resetYieldSliceClock()
        if type(os) == "table" and type(os.clock) == "function" then
            local sliceStartClock = os.clock()
            sha256RoundConstants.__slice_clock = sliceStartClock
        end
    end

    function computeSha256(messageBytes)
        resetYieldSliceClock()
        messageBytes = tostring(messageBytes or "")
        local hashStateA = 1779033703
        local hashStateB = 3144134277
        local hashStateC = 1013904242
        local hashStateD = 2773480762
        local hashStateE = 1359893119
        local hashStateF = 2600822924
        local hashStateG = 528734635
        local hashStateH = 1541459225
        local messageBitLength = #messageBytes * 8
        messageBytes = messageBytes .. "\x80"
        messageBytes = messageBytes .. string.rep("\x00", (56 - #messageBytes % 64) % 64)
        local bitLengthHigh = math.floor(messageBitLength / 4294967296)
        local bitLengthLow = messageBitLength % 4294967296
        messageBytes = messageBytes .. string.char(bitLengthHigh >> 24 & 255, bitLengthHigh >> 16 & 255, bitLengthHigh >> 8 & 255, bitLengthHigh & 255, bitLengthLow >> 24 & 255, bitLengthLow >> 16 & 255, bitLengthLow >> 8 & 255, bitLengthLow & 255)

        local function packUint32BigEndian(stateWord)
            return string.char(stateWord >> 24 & 255, stateWord >> 16 & 255, stateWord >> 8 & 255, stateWord & 255)
        end

        local messageSchedule = {}
        for blockOffset = 1, #messageBytes, 64 do
            for wordIndex = 0, 15 do
                local firstByte, secondByte, thirdByte, fourthByte = messageBytes:byte(blockOffset + wordIndex * 4, blockOffset + wordIndex * 4 + 3)
                messageSchedule[wordIndex] = truncateToUint32(firstByte << 24 | secondByte << 16 | thirdByte << 8 | fourthByte)
            end
            for scheduleIndex = 16, 63 do
                local wordFifteenBack = messageSchedule[scheduleIndex - 15]
                local smallSigmaZero = truncateToUint32(sha256RotateRight(wordFifteenBack, 7) ~ sha256RotateRight(wordFifteenBack, 18) ~ sha256ShiftRight(wordFifteenBack, 3))
                local wordTwoBack = messageSchedule[scheduleIndex - 2]
                local smallSigmaOne = truncateToUint32(sha256RotateRight(wordTwoBack, 17) ~ sha256RotateRight(wordTwoBack, 19) ~ sha256ShiftRight(wordTwoBack, 10))
                messageSchedule[scheduleIndex] = truncateToUint32(messageSchedule[scheduleIndex - 16] + smallSigmaZero + messageSchedule[scheduleIndex - 7] + smallSigmaOne)
            end
            local workingA = hashStateA
            local workingB = hashStateB
            local workingC = hashStateC
            local workingD = hashStateD
            local workingE = hashStateE
            local workingF = hashStateF
            local workingG = hashStateG
            local workingH = hashStateH
            for roundIndex = 0, 63 do
                local bigSigmaOne = truncateToUint32(sha256RotateRight(workingE, 6) ~ sha256RotateRight(workingE, 11) ~ sha256RotateRight(workingE, 25))
                local choiceBits = truncateToUint32(workingE & workingF ~ ~workingE & workingG)
                local roundTermOne = truncateToUint32(workingH + bigSigmaOne + choiceBits + sha256RoundConstants[roundIndex + 1] + messageSchedule[roundIndex])
                local bigSigmaZero = truncateToUint32(sha256RotateRight(workingA, 2) ~ sha256RotateRight(workingA, 13) ~ sha256RotateRight(workingA, 22))
                local majorityBits = truncateToUint32(workingA & workingB ~ workingA & workingC ~ workingB & workingC)
                local roundTermTwo = truncateToUint32(bigSigmaZero + majorityBits)
                workingH = workingG
                workingG = workingF
                workingF = workingE
                workingE = truncateToUint32(workingD + roundTermOne)
                workingD = workingC
                workingC = workingB
                workingB = workingA
                workingA = truncateToUint32(roundTermOne + roundTermTwo)
            end
            hashStateA = truncateToUint32(hashStateA + workingA)
            hashStateB = truncateToUint32(hashStateB + workingB)
            hashStateC = truncateToUint32(hashStateC + workingC)
            hashStateD = truncateToUint32(hashStateD + workingD)
            hashStateE = truncateToUint32(hashStateE + workingE)
            hashStateF = truncateToUint32(hashStateF + workingF)
            hashStateG = truncateToUint32(hashStateG + workingG)
            hashStateH = truncateToUint32(hashStateH + workingH)
            if blockOffset & 2047 == 1 then
                yieldIfTimeSliceElapsed()
            end
        end
        return packUint32BigEndian(hashStateA) .. packUint32BigEndian(hashStateB) .. packUint32BigEndian(hashStateC) .. packUint32BigEndian(hashStateD) .. packUint32BigEndian(hashStateE) .. packUint32BigEndian(hashStateF) .. packUint32BigEndian(hashStateG) .. packUint32BigEndian(hashStateH)
    end

    function computeHmacSha256(hmacKey, hmacMessage)
        hmacKey = tostring(hmacKey or "")
        hmacMessage = tostring(hmacMessage or "")
        local hmacBlockSize = 64
        if hmacBlockSize < #hmacKey then
            hmacKey = computeSha256(hmacKey)
        end
        if hmacBlockSize > #hmacKey then
            hmacKey = hmacKey .. string.rep("\x00", hmacBlockSize - #hmacKey)
        end
        local outerKeyPad = {}
        local innerKeyPad = {}
        for keyByteIndex = 1, hmacBlockSize do
            local keyByte = hmacKey:byte(keyByteIndex)
            outerKeyPad[keyByteIndex] = string.char((keyByte ~ 92) & 255)
            innerKeyPad[keyByteIndex] = string.char((keyByte ~ 54) & 255)
        end
        return computeSha256(table.concat(outerKeyPad) .. computeSha256(table.concat(innerKeyPad) .. hmacMessage))
    end

    local randomHexCallCounter = 0

    function generateRandomHex(byteCount)
        byteCount = tonumber(byteCount) or 16
        randomHexCallCounter = randomHexCallCounter + 1
        local cheraxUid = ""
        if isTableOrUserdata(Cherax) and type(Cherax.GetUID) == "function" then
            cheraxUid = tostring(Cherax.GetUID() or "")
        end
        local entropySeed = table.concat({
            tostring(math.random(0, 2147483647)),
            tostring(math.random(0, 2147483647)),
            tostring(os.time()),
            tostring(os.clock()),
            tostring({}),
            tostring(function() end),
            tostring(randomHexCallCounter),
            cheraxUid,
        }, "|")
        local randomHex = bytesToHex(computeSha256(entropySeed))
        while #randomHex < byteCount * 2 do
            entropySeed = entropySeed .. "|" .. randomHex .. "|" .. tostring(os.clock())
            randomHex = randomHex .. bytesToHex(computeSha256(entropySeed))
        end
        return randomHex:sub(1, byteCount * 2)
    end

    local base64DecodeLookup = {}
    local BASE64_DECODE_ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    for alphabetIndex = 1, #BASE64_DECODE_ALPHABET do
        local alphabetChar = BASE64_DECODE_ALPHABET.sub(BASE64_DECODE_ALPHABET, alphabetIndex, alphabetIndex)
        base64DecodeLookup[alphabetChar] = alphabetIndex - 1
        local alphabetByte = BASE64_DECODE_ALPHABET.byte(BASE64_DECODE_ALPHABET, alphabetIndex)
        base64DecodeLookup[alphabetByte] = alphabetIndex - 1
    end

    function base64Decode(encodedText)
        resetYieldSliceClock()
        encodedText = tostring(encodedText or ""):gsub("%s+", "")
        if encodedText == "" then
            return ""
        end
        local decodedChunks = {}
        for quadOffset = 1, #encodedText, 4 do
            if quadOffset & 4095 == 1 then
                yieldIfTimeSliceElapsed()
            end
            local firstCharCode, secondCharCode, thirdCharCode, fourthCharCode = encodedText:byte(quadOffset, quadOffset + 3)
            local firstSextet = base64DecodeLookup[firstCharCode]
            local secondSextet = base64DecodeLookup[secondCharCode]
            if firstSextet == nil or secondSextet == nil then
                return nil
            end
            local firstDecodedByte = (firstSextet << 2 | secondSextet >> 4) & 255
            if thirdCharCode == nil or thirdCharCode == 61 then
                if thirdCharCode == 61 and fourthCharCode ~= nil and fourthCharCode ~= 61 then
                    return nil
                end
                decodedChunks[#decodedChunks + 1] = string.char(firstDecodedByte)
                break
            end
            local thirdSextet = base64DecodeLookup[thirdCharCode]
            if thirdSextet == nil then
                return nil
            end
            local secondDecodedByte = ((secondSextet & 15) << 4 | thirdSextet >> 2) & 255
            if fourthCharCode == nil or fourthCharCode == 61 then
                decodedChunks[#decodedChunks + 1] = string.char(firstDecodedByte, secondDecodedByte)
                break
            end
            local fourthSextet = base64DecodeLookup[fourthCharCode]
            if fourthSextet == nil then
                return nil
            end
            decodedChunks[#decodedChunks + 1] = string.char(firstDecodedByte, secondDecodedByte, ((thirdSextet & 3) << 6 | fourthSextet) & 255)
        end
        return table.concat(decodedChunks)
    end
end
local logFeatureInteraction
do
    local BASE64_ENCODE_ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

    local function base64Encode(inputBytes)
        resetYieldSliceClock()
        inputBytes = tostring(inputBytes or "")
        if inputBytes == "" then
            return ""
        end
        local encodedChars = {}
        for byteOffset = 1, #inputBytes, 3 do
            if byteOffset % 3072 == 1 then
                yieldIfTimeSliceElapsed()
            end
            local firstByte, secondByte, thirdByte = inputBytes:byte(byteOffset, byteOffset + 2)
            local remainingBytes = #inputBytes - byteOffset + 1
            if not secondByte then
                secondByte = 0
            end
            if not thirdByte then
                thirdByte = 0
            end
            local packedTriple = firstByte << 16 | secondByte << 8 | thirdByte
            encodedChars[#encodedChars + 1] = BASE64_ENCODE_ALPHABET:sub((packedTriple >> 18 & 63) + 1, (packedTriple >> 18 & 63) + 1)
            encodedChars[#encodedChars + 1] = BASE64_ENCODE_ALPHABET:sub((packedTriple >> 12 & 63) + 1, (packedTriple >> 12 & 63) + 1)
            if remainingBytes == 1 then
                encodedChars[#encodedChars + 1] = "="
                encodedChars[#encodedChars + 1] = "="
            elseif remainingBytes == 2 then
                encodedChars[#encodedChars + 1] = BASE64_ENCODE_ALPHABET:sub((packedTriple >> 6 & 63) + 1, (packedTriple >> 6 & 63) + 1)
                encodedChars[#encodedChars + 1] = "="
            else
                encodedChars[#encodedChars + 1] = BASE64_ENCODE_ALPHABET:sub((packedTriple >> 6 & 63) + 1, (packedTriple >> 6 & 63) + 1)
                encodedChars[#encodedChars + 1] = BASE64_ENCODE_ALPHABET:sub((packedTriple & 63) + 1, (packedTriple & 63) + 1)
            end
        end
        return table.concat(encodedChars)
    end

    local function hexDecodeToBytes(hexText)
        resetYieldSliceClock()
        hexText = tostring(hexText or "")
        if #hexText % 2 ~= 0 or hexText:find("[^0-9a-fA-F]") then
            return nil
        end
        local decodedBytes = {}
        for hexOffset = 1, #hexText, 2 do
            if hexOffset & 255 == 1 then
                yieldIfTimeSliceElapsed()
            end
            decodedBytes[#decodedBytes + 1] = string.char(tonumber(hexText:sub(hexOffset, hexOffset + 1), 16))
        end
        return table.concat(decodedBytes)
    end

    local function generateRandomBytes(byteCount)
        return hexDecodeToBytes(generateRandomHex(byteCount))
    end

    local function encodeBytesAsHex(rawBytes)
        return bytesToHex(rawBytes)
    end

    local function wrapUint32(unmaskedNumber)
        return truncateToUint32(unmaskedNumber)
    end

    local function uint32FromBytesLE(lowByte, midLowByte, midHighByte, highByte)
        return wrapUint32(lowByte | midLowByte << 8 | midHighByte << 16 | highByte << 24)
    end

    local CHACHA_SIGMA_FIRST = 1634760805
    local CHACHA_SIGMA_SECOND = 857760878
    local CHACHA_SIGMA_THIRD = 2036477234
    local CHACHA_SIGMA_FOURTH = 1797285236

    local function chachaQuarterRound(chachaState, wordIndexA, wordIndexB, wordIndexC, wordIndexD)
        chachaState[wordIndexA] = wrapUint32(chachaState[wordIndexA] + chachaState[wordIndexB])
        chachaState[wordIndexD] = wrapUint32((chachaState[wordIndexD] ~ chachaState[wordIndexA]) << 16 | (chachaState[wordIndexD] ~ chachaState[wordIndexA]) >> 16)
        chachaState[wordIndexC] = wrapUint32(chachaState[wordIndexC] + chachaState[wordIndexD])
        chachaState[wordIndexB] = wrapUint32((chachaState[wordIndexB] ~ chachaState[wordIndexC]) << 12 | (chachaState[wordIndexB] ~ chachaState[wordIndexC]) >> 20)
        chachaState[wordIndexA] = wrapUint32(chachaState[wordIndexA] + chachaState[wordIndexB])
        chachaState[wordIndexD] = wrapUint32((chachaState[wordIndexD] ~ chachaState[wordIndexA]) << 8 | (chachaState[wordIndexD] ~ chachaState[wordIndexA]) >> 24)
        chachaState[wordIndexC] = wrapUint32(chachaState[wordIndexC] + chachaState[wordIndexD])
        chachaState[wordIndexB] = wrapUint32((chachaState[wordIndexB] ~ chachaState[wordIndexC]) << 7 | (chachaState[wordIndexB] ~ chachaState[wordIndexC]) >> 25)
    end

    local function chacha20Block(keyWords, nonceWords, blockCounter)
        local initialSigmaFirst = CHACHA_SIGMA_FIRST
        local initialSigmaSecond = CHACHA_SIGMA_SECOND
        local initialSigmaThird = CHACHA_SIGMA_THIRD
        local initialSigmaFourth = CHACHA_SIGMA_FOURTH
        local keyWordFirst = keyWords[1]
        local keyWordSecond = keyWords[2]
        local keyWordThird = keyWords[3]
        local keyWordFourth = keyWords[4]
        local keyWordFifth = keyWords[5]
        local keyWordSixth = keyWords[6]
        local keyWordSeventh = keyWords[7]
        local keyWordEighth = keyWords[8]
        local counterWord = wrapUint32(blockCounter)
        local nonceWordFirst = nonceWords[1]
        local nonceWordSecond = nonceWords[2]
        local nonceWordThird = nonceWords[3]
        local workingState = {
            initialSigmaFirst,
            initialSigmaSecond,
            initialSigmaThird,
            initialSigmaFourth,
            keyWordFirst,
            keyWordSecond,
            keyWordThird,
            keyWordFourth,
            keyWordFifth,
            keyWordSixth,
            keyWordSeventh,
            keyWordEighth,
            counterWord,
            nonceWordFirst,
            nonceWordSecond,
            nonceWordThird,
        }
        for _ = 1, 10 do
            chachaQuarterRound(workingState, 1, 5, 9, 13)
            chachaQuarterRound(workingState, 2, 6, 10, 14)
            chachaQuarterRound(workingState, 3, 7, 11, 15)
            chachaQuarterRound(workingState, 4, 8, 12, 16)
            chachaQuarterRound(workingState, 1, 6, 11, 16)
            chachaQuarterRound(workingState, 2, 7, 12, 13)
            chachaQuarterRound(workingState, 3, 8, 9, 14)
            chachaQuarterRound(workingState, 4, 5, 10, 15)
        end
        return wrapUint32(workingState[1] + initialSigmaFirst), wrapUint32(workingState[2] + initialSigmaSecond), wrapUint32(workingState[3] + initialSigmaThird), wrapUint32(workingState[4] + initialSigmaFourth), wrapUint32(workingState[5] + keyWordFirst), wrapUint32(workingState[6] + keyWordSecond), wrapUint32(workingState[7] + keyWordThird), wrapUint32(workingState[8] + keyWordFourth), wrapUint32(workingState[9] + keyWordFifth), wrapUint32(workingState[10] + keyWordSixth), wrapUint32(workingState[11] + keyWordSeventh), wrapUint32(workingState[12] + keyWordEighth), wrapUint32(workingState[13] + counterWord), wrapUint32(workingState[14] + nonceWordFirst), wrapUint32(workingState[15] + nonceWordSecond), wrapUint32(workingState[16] + nonceWordThird)
    end

    local function xorKeystreamWordInto(outputChunks, outputIndex, sourceBytes, inputPos, inputLength, keystreamWord)
        local firstInputByte = sourceBytes:byte(inputPos)
        if not firstInputByte then
            return outputIndex, inputPos
        end
        if inputLength >= inputPos + 3 then
            local secondInputByte, thirdInputByte, fourthInputByte = sourceBytes:byte(inputPos + 1, inputPos + 3)
            outputChunks[outputIndex] = string.char((firstInputByte ~ keystreamWord & 255) & 255, (secondInputByte ~ keystreamWord >> 8 & 255) & 255, (thirdInputByte ~ keystreamWord >> 16 & 255) & 255, (fourthInputByte ~ keystreamWord >> 24 & 255) & 255)
            return outputIndex + 1, inputPos + 4
        end
        local remainingCount = inputLength - inputPos + 1
        if remainingCount == 1 then
            outputChunks[outputIndex] = string.char((firstInputByte ~ keystreamWord & 255) & 255)
        elseif remainingCount == 2 then
            local pairSecondByte = sourceBytes:byte(inputPos + 1)
            outputChunks[outputIndex] = string.char((firstInputByte ~ keystreamWord & 255) & 255, (pairSecondByte ~ keystreamWord >> 8 & 255) & 255)
        else
            local tripleSecondByte, tripleThirdByte = sourceBytes:byte(inputPos + 1, inputPos + 2)
            outputChunks[outputIndex] = string.char((firstInputByte ~ keystreamWord & 255) & 255, (tripleSecondByte ~ keystreamWord >> 8 & 255) & 255, (tripleThirdByte ~ keystreamWord >> 16 & 255) & 255)
        end
        return outputIndex + 1, inputLength + 1
    end

    local function chacha20Crypt(keyBytes, nonceBytes, initialCounter, inputBytes)
        resetYieldSliceClock()
        local blockCounter = math.tointeger(initialCounter)
        if not blockCounter then
            return nil
        end
        local keyWords = {}
        for keyWordIndex = 0, 7 do
            local keyByteOffset = keyWordIndex * 4
            local firstKeyByte, secondKeyByte, thirdKeyByte, fourthKeyByte = keyBytes:byte(1 + keyByteOffset, 4 + keyByteOffset)
            keyWords[keyWordIndex + 1] = uint32FromBytesLE(firstKeyByte, secondKeyByte, thirdKeyByte, fourthKeyByte)
        end
        local nonceWords = {
            uint32FromBytesLE(nonceBytes:byte(1, 4)),
            uint32FromBytesLE(nonceBytes:byte(5, 8)),
            uint32FromBytesLE(nonceBytes:byte(9, 12)),
        }
        local outputChunks = {}
        local nextOutputSlot = 1
        local nextInputPos = 1
        local inputLength = #inputBytes
        while nextInputPos <= inputLength do
            if nextInputPos & 2047 == 1 then
                yieldIfTimeSliceElapsed()
            end
            local firstKeystreamWord, secondKeystreamWord, thirdKeystreamWord, fourthKeystreamWord, fifthKeystreamWord, sixthKeystreamWord, seventhKeystreamWord, eighthKeystreamWord, ninthKeystreamWord, tenthKeystreamWord, eleventhKeystreamWord, twelfthKeystreamWord, thirteenthKeystreamWord, fourteenthKeystreamWord, fifteenthKeystreamWord, sixteenthKeystreamWord = chacha20Block(keyWords, nonceWords, blockCounter)
            blockCounter = wrapUint32(blockCounter + 1)
            local outputSlotAfterFirstWord, inputPosAfterFirstWord = xorKeystreamWordInto(outputChunks, nextOutputSlot, inputBytes, nextInputPos, inputLength, firstKeystreamWord)
            local outputSlotAfterSecondWord, inputPosAfterSecondWord = xorKeystreamWordInto(outputChunks, outputSlotAfterFirstWord, inputBytes, inputPosAfterFirstWord, inputLength, secondKeystreamWord)
            local outputSlotAfterThirdWord, inputPosAfterThirdWord = xorKeystreamWordInto(outputChunks, outputSlotAfterSecondWord, inputBytes, inputPosAfterSecondWord, inputLength, thirdKeystreamWord)
            local outputSlotAfterFourthWord, inputPosAfterFourthWord = xorKeystreamWordInto(outputChunks, outputSlotAfterThirdWord, inputBytes, inputPosAfterThirdWord, inputLength, fourthKeystreamWord)
            local outputSlotAfterFifthWord, inputPosAfterFifthWord = xorKeystreamWordInto(outputChunks, outputSlotAfterFourthWord, inputBytes, inputPosAfterFourthWord, inputLength, fifthKeystreamWord)
            local outputSlotAfterSixthWord, inputPosAfterSixthWord = xorKeystreamWordInto(outputChunks, outputSlotAfterFifthWord, inputBytes, inputPosAfterFifthWord, inputLength, sixthKeystreamWord)
            local outputSlotAfterSeventhWord, inputPosAfterSeventhWord = xorKeystreamWordInto(outputChunks, outputSlotAfterSixthWord, inputBytes, inputPosAfterSixthWord, inputLength, seventhKeystreamWord)
            local outputSlotAfterEighthWord, inputPosAfterEighthWord = xorKeystreamWordInto(outputChunks, outputSlotAfterSeventhWord, inputBytes, inputPosAfterSeventhWord, inputLength, eighthKeystreamWord)
            local outputSlotAfterNinthWord, inputPosAfterNinthWord = xorKeystreamWordInto(outputChunks, outputSlotAfterEighthWord, inputBytes, inputPosAfterEighthWord, inputLength, ninthKeystreamWord)
            local outputSlotAfterTenthWord, inputPosAfterTenthWord = xorKeystreamWordInto(outputChunks, outputSlotAfterNinthWord, inputBytes, inputPosAfterNinthWord, inputLength, tenthKeystreamWord)
            local outputSlotAfterEleventhWord, inputPosAfterEleventhWord = xorKeystreamWordInto(outputChunks, outputSlotAfterTenthWord, inputBytes, inputPosAfterTenthWord, inputLength, eleventhKeystreamWord)
            local outputSlotAfterTwelfthWord, inputPosAfterTwelfthWord = xorKeystreamWordInto(outputChunks, outputSlotAfterEleventhWord, inputBytes, inputPosAfterEleventhWord, inputLength, twelfthKeystreamWord)
            local outputSlotAfterThirteenthWord, inputPosAfterThirteenthWord = xorKeystreamWordInto(outputChunks, outputSlotAfterTwelfthWord, inputBytes, inputPosAfterTwelfthWord, inputLength, thirteenthKeystreamWord)
            local outputSlotAfterFourteenthWord, inputPosAfterFourteenthWord = xorKeystreamWordInto(outputChunks, outputSlotAfterThirteenthWord, inputBytes, inputPosAfterThirteenthWord, inputLength, fourteenthKeystreamWord)
            local outputSlotAfterFifteenthWord, inputPosAfterFifteenthWord = xorKeystreamWordInto(outputChunks, outputSlotAfterFourteenthWord, inputBytes, inputPosAfterFourteenthWord, inputLength, fifteenthKeystreamWord)
            nextOutputSlot, nextInputPos = xorKeystreamWordInto(outputChunks, outputSlotAfterFifteenthWord, inputBytes, inputPosAfterFifteenthWord, inputLength, sixteenthKeystreamWord)
        end
        return table.concat(outputChunks)
    end

    local function newFieldElement(initialLimbs)
        local fieldElement = {}
        for limbIndex = 1, 16 do
            fieldElement[limbIndex] = 0
        end
        if initialLimbs then
            for initialLimbIndex = 1, #initialLimbs do
                fieldElement[initialLimbIndex] = initialLimbs[initialLimbIndex]
            end
        end
        return fieldElement
    end

    local X25519_A24 = newFieldElement({ 56129, 1 })
    local X25519_BASEPOINT = string.char(9) .. string.rep("\x00", 31)

    local function carryFieldElement(fieldElement)
        local carry = 1
        for limbIndex = 1, 16 do
            local biasedLimb = fieldElement[limbIndex] + carry + 65535
            carry = math.floor(biasedLimb / 65536)
            fieldElement[limbIndex] = biasedLimb - carry * 65536
        end
        fieldElement[1] = fieldElement[1] + carry - 1 + 37 * (carry - 1)
    end

    local function conditionalSwapFieldElements(firstElement, secondElement, swapBit)
        local swapMask = ~(swapBit - 1)
        for limbIndex = 1, 16 do
            local maskedDifference = swapMask & (firstElement[limbIndex] ~ secondElement[limbIndex])
            firstElement[limbIndex] = firstElement[limbIndex] ~ maskedDifference
            secondElement[limbIndex] = secondElement[limbIndex] ~ maskedDifference
        end
    end

    local function unpackFieldElement(packedBytes)
        local unpackedElement = newFieldElement()
        for limbIndex = 1, 16 do
            unpackedElement[limbIndex] = (packedBytes:byte(2 * limbIndex - 1) or 0) | (packedBytes:byte(2 * limbIndex) or 0) << 8
        end
        unpackedElement[16] = unpackedElement[16] & 32767
        return unpackedElement
    end

    local function packFieldElement(inputElement)
        local elementMinusPrime = newFieldElement()
        local normalizedElement = newFieldElement()
        for copyLimbIndex = 1, 16 do
            normalizedElement[copyLimbIndex] = inputElement[copyLimbIndex]
        end
        carryFieldElement(normalizedElement)
        carryFieldElement(normalizedElement)
        carryFieldElement(normalizedElement)
        for _ = 1, 2 do
            elementMinusPrime[1] = normalizedElement[1] - 65517
            for borrowLimbIndex = 2, 15 do
                elementMinusPrime[borrowLimbIndex] = normalizedElement[borrowLimbIndex] - 65535 - (elementMinusPrime[borrowLimbIndex - 1] >> 16 & 1)
                elementMinusPrime[borrowLimbIndex - 1] = elementMinusPrime[borrowLimbIndex - 1] & 65535
            end
            elementMinusPrime[16] = normalizedElement[16] - 32767 - (elementMinusPrime[15] >> 16 & 1)
            local topLimbWithBorrow = elementMinusPrime[16]
            elementMinusPrime[15] = elementMinusPrime[15] & 65535
            conditionalSwapFieldElements(normalizedElement, elementMinusPrime, 1 - (topLimbWithBorrow >> 16 & 1))
        end
        local packedByteChars = {}
        for outputLimbIndex = 1, 16 do
            packedByteChars[#packedByteChars + 1] = string.char(normalizedElement[outputLimbIndex] & 255)
            packedByteChars[#packedByteChars + 1] = string.char(normalizedElement[outputLimbIndex] >> 8 & 255)
        end
        return table.concat(packedByteChars)
    end

    local function addFieldElements(sumOut, leftAddend, rightAddend)
        for limbIndex = 1, 16 do
            sumOut[limbIndex] = leftAddend[limbIndex] + rightAddend[limbIndex]
        end
    end

    local function subtractFieldElements(differenceOut, minuendElement, subtrahendElement)
        for limbIndex = 1, 16 do
            differenceOut[limbIndex] = minuendElement[limbIndex] - subtrahendElement[limbIndex]
        end
    end

    local function multiplyFieldElements(productOut, multiplicandElement, multiplierElement)
        local wideProductLimbs = {}
        for productSlotIndex = 1, 31 do
            wideProductLimbs[productSlotIndex] = 0
        end
        for multiplicandLimbIndex = 1, 16 do
            for multiplierLimbIndex = 1, 16 do
                wideProductLimbs[multiplicandLimbIndex + multiplierLimbIndex - 1] = wideProductLimbs[multiplicandLimbIndex + multiplierLimbIndex - 1] + multiplicandElement[multiplicandLimbIndex] * multiplierElement[multiplierLimbIndex]
            end
        end
        for foldLimbIndex = 1, 15 do
            wideProductLimbs[foldLimbIndex] = wideProductLimbs[foldLimbIndex] + 38 * wideProductLimbs[foldLimbIndex + 16]
        end
        for outputLimbIndex = 1, 16 do
            productOut[outputLimbIndex] = wideProductLimbs[outputLimbIndex]
        end
        carryFieldElement(productOut)
        carryFieldElement(productOut)
    end

    local function squareFieldElement(squareOut, elementToSquare)
        multiplyFieldElements(squareOut, elementToSquare, elementToSquare)
    end

    local function yieldDuringCurveMath()
        if isTableOrUserdata(Script) and type(Script.Yield) == "function" then
            Script.Yield(16)
        end
    end

    local function invertFieldElement(inverseOut, elementToInvert)
        local powerAccumulator = newFieldElement()
        for copyLimbIndex = 1, 16 do
            powerAccumulator[copyLimbIndex] = elementToInvert[copyLimbIndex]
        end
        for exponentBitIndex = 253, 0, -1 do
            squareFieldElement(powerAccumulator, powerAccumulator)
            if exponentBitIndex ~= 2 and exponentBitIndex ~= 4 then
                multiplyFieldElements(powerAccumulator, powerAccumulator, elementToInvert)
            end
            if exponentBitIndex & 7 == 0 then
                yieldDuringCurveMath()
            end
        end
        for outputLimbIndex = 1, 16 do
            inverseOut[outputLimbIndex] = powerAccumulator[outputLimbIndex]
        end
    end

    local function x25519ScalarMult(secretScalar, inputPoint)
        if type(secretScalar) ~= "string" or #secretScalar ~= 32 or type(inputPoint) ~= "string" or #inputPoint ~= 32 then
            return nil
        end
        local clampedScalar = {}
        for scalarByteIndex = 1, 32 do
            clampedScalar[scalarByteIndex] = secretScalar:byte(scalarByteIndex) or 0
        end
        clampedScalar[32] = clampedScalar[32] & 127 | 64
        clampedScalar[1] = clampedScalar[1] & 248
        local inputPointU = unpackFieldElement(inputPoint)
        local ladderX2 = newFieldElement()
        local ladderX3 = newFieldElement()
        local ladderZ2 = newFieldElement()
        local ladderZ3 = newFieldElement()
        local ladderSum = newFieldElement()
        local ladderDiffSquared = newFieldElement()
        for limbIndex = 1, 16 do
            ladderX3[limbIndex] = inputPointU[limbIndex]
            ladderX2[limbIndex] = 0
            ladderZ2[limbIndex] = 0
            ladderZ3[limbIndex] = 0
        end
        ladderX2[1] = 1
        ladderZ3[1] = 1
        for scalarBitIndex = 254, 0, -1 do
            local currentScalarBit = clampedScalar[(scalarBitIndex >> 3) + 1] >> (scalarBitIndex & 7) & 1
            conditionalSwapFieldElements(ladderX2, ladderX3, currentScalarBit)
            conditionalSwapFieldElements(ladderZ2, ladderZ3, currentScalarBit)
            addFieldElements(ladderSum, ladderX2, ladderZ2)
            subtractFieldElements(ladderX2, ladderX2, ladderZ2)
            addFieldElements(ladderZ2, ladderX3, ladderZ3)
            subtractFieldElements(ladderX3, ladderX3, ladderZ3)
            squareFieldElement(ladderZ3, ladderSum)
            squareFieldElement(ladderDiffSquared, ladderX2)
            multiplyFieldElements(ladderX2, ladderZ2, ladderX2)
            multiplyFieldElements(ladderZ2, ladderX3, ladderSum)
            addFieldElements(ladderSum, ladderX2, ladderZ2)
            subtractFieldElements(ladderX2, ladderX2, ladderZ2)
            squareFieldElement(ladderX3, ladderX2)
            subtractFieldElements(ladderZ2, ladderZ3, ladderDiffSquared)
            multiplyFieldElements(ladderX2, ladderZ2, X25519_A24)
            addFieldElements(ladderX2, ladderX2, ladderZ3)
            multiplyFieldElements(ladderZ2, ladderZ2, ladderX2)
            multiplyFieldElements(ladderX2, ladderZ3, ladderDiffSquared)
            multiplyFieldElements(ladderZ3, ladderX3, inputPointU)
            squareFieldElement(ladderX3, ladderSum)
            conditionalSwapFieldElements(ladderX2, ladderX3, currentScalarBit)
            conditionalSwapFieldElements(ladderZ2, ladderZ3, currentScalarBit)
            if scalarBitIndex & 7 == 0 then
                yieldDuringCurveMath()
            end
        end
        local invertedZ2 = newFieldElement()
        for copyLimbIndex = 1, 16 do
            invertedZ2[copyLimbIndex] = ladderZ2[copyLimbIndex]
        end
        invertFieldElement(invertedZ2, invertedZ2)
        multiplyFieldElements(ladderX2, ladderX2, invertedZ2)
        return packFieldElement(ladderX2)
    end

    local function isAllZeroBytes(byteString)
        if type(byteString) ~= "string" then
            return false
        end
        for byteIndex = 1, #byteString do
            if byteString:byte(byteIndex) ~= 0 then
                return false
            end
        end
        return true
    end

    local TRANSPORT_PROTOCOL_LABEL = "ks-api-transport-v1"
    local authTransportState = { pending = nil, active = nil }

    local function deriveTransportKey(sharedSecret, keyPurpose, apiKey, clientPublicHex, serverPublicHex)
        return computeHmacSha256(sharedSecret, table.concat({
            TRANSPORT_PROTOCOL_LABEL,
            tostring(keyPurpose or ""),
            tostring(apiKey or ""),
            tostring(clientPublicHex or ""):lower(),
            tostring(serverPublicHex or ""):lower(),
        }, "|"))
    end

    local function buildTransportMacMessage(directionTag, httpMethod, requestPath, nonceBase64, blockCounter, ciphertextBase64)
        return table.concat({
            TRANSPORT_PROTOCOL_LABEL,
            tostring(directionTag or ""),
            tostring(httpMethod or "GET"):upper(),
            tostring(requestPath or "/"),
            tostring(nonceBase64 or ""),
            tostring(blockCounter or ""),
            tostring(ciphertextBase64 or ""),
        }, "\n")
    end

    local function getActiveTransportForApiKey(apiKey)
        local activeTransport = authTransportState.active
        if type(activeTransport) ~= "table" or tostring(activeTransport.apiKey or "") ~= tostring(apiKey or "") then
            return nil
        end
        return activeTransport
    end

    function KS_ClearAuthTransport(clearReason)
        authTransportState.pending = nil
        authTransportState.active = nil
    end

    function KS_PrepareAuthTransport()
        local prepareStartedMs = ks_now_ms()
        local entropySeed = table.concat({
            "f7a6d4918c23b05e",
            generateRandomHex(32),
            tostring(os.time()),
            tostring(os.clock()),
            tostring({}),
            tostring(function() end),
            tostring(isTableOrUserdata(Cherax) and Cherax.GetUID and Cherax.GetUID() or ""),
        }, "|")
        local clientPrivateKey = computeSha256(entropySeed)
        local clientPublicKey = x25519ScalarMult(clientPrivateKey, X25519_BASEPOINT)
        if not clientPublicKey or #clientPublicKey ~= 32 or isAllZeroBytes(clientPublicKey) then
            return nil
        end
        local pendingTransport = { privateKey = clientPrivateKey, publicHex = encodeBytesAsHex(clientPublicKey) }
        authTransportState.pending = pendingTransport
        return pendingTransport.publicHex, pendingTransport
    end

    function KS_CompleteAuthTransport(serverHandshake, apiKey, preparedTransport)
        local completeStartedMs = ks_now_ms()
        local pendingTransport = type(preparedTransport) == "table" and preparedTransport or authTransportState.pending
        local serverPublicHex = type(serverHandshake) == "table" and tostring(serverHandshake.x or ""):lower() or ""
        if type(pendingTransport) ~= "table" or #serverPublicHex ~= 64 or serverPublicHex:find("[^0-9a-f]") then
            if authTransportState.pending == pendingTransport then
                authTransportState.pending = nil
            end
            return false
        end
        local serverPublicKey = hexDecodeToBytes(serverPublicHex)
        local sharedSecret = serverPublicKey and x25519ScalarMult(pendingTransport.privateKey, serverPublicKey) or nil
        if not sharedSecret or #sharedSecret ~= 32 or isAllZeroBytes(sharedSecret) then
            if authTransportState.pending == pendingTransport then
                authTransportState.pending = nil
            end
            return false
        end
        local activeTransport = {
            apiKey = tostring(apiKey or ""),
            clientPubHex = pendingTransport.publicHex,
            serverPubHex = serverPublicHex,
            requestKey = deriveTransportKey(sharedSecret, "rq:enc", apiKey, pendingTransport.publicHex, serverPublicHex),
            requestMacKey = deriveTransportKey(sharedSecret, "rq:mac", apiKey, pendingTransport.publicHex, serverPublicHex),
            responseKey = deriveTransportKey(sharedSecret, "rs:enc", apiKey, pendingTransport.publicHex, serverPublicHex),
            responseMacKey = deriveTransportKey(sharedSecret, "rs:mac", apiKey, pendingTransport.publicHex, serverPublicHex),
        }
        authTransportState.active = activeTransport
        if authTransportState.pending == pendingTransport then
            authTransportState.pending = nil
        end
        return true
    end

    local function encryptTransportRequestBody(requestBody, httpMethod, signingPath, apiKey)
        local encryptStartMs = ks_now_ms()
        local activeTransport = getActiveTransportForApiKey(apiKey)
        if not activeTransport or tostring(requestBody or "") == "" then
            return nil
        end
        local nonceBytes = generateRandomBytes(12)
        if not nonceBytes or #nonceBytes ~= 12 then
            return nil, "nonce"
        end
        local cipherCounter = math.random(1, 2147483647)
        local ciphertext = chacha20Crypt(activeTransport.requestKey, nonceBytes, cipherCounter, tostring(requestBody or ""))
        if not ciphertext then
            return nil, "cipher"
        end
        local nonceBase64 = base64Encode(nonceBytes)
        local ciphertextBase64 = base64Encode(ciphertext)
        local requestMacHex = encodeBytesAsHex(computeHmacSha256(activeTransport.requestMacKey, buildTransportMacMessage("rq", httpMethod, signingPath, nonceBase64, cipherCounter, ciphertextBase64)))
        local envelopeJson = json.encode({
            ["0"] = 3,
            ["1"] = nonceBase64,
            ["2"] = cipherCounter,
            ["3"] = ciphertextBase64,
            ["4"] = requestMacHex,
        })
        return envelopeJson
    end

    local function constantTimeHexEquals(leftHex, rightHex)
        leftHex = tostring(leftHex or ""):lower()
        rightHex = tostring(rightHex or ""):lower()
        if #leftHex ~= #rightHex then
            return false
        end
        local diffAccumulator = 0
        for byteIndex = 1, #leftHex do
            diffAccumulator = diffAccumulator | (leftHex:byte(byteIndex) ~ rightHex:byte(byteIndex)) & 255
        end
        return diffAccumulator == 0
    end

    local function decryptTransportResponseBody(responseBody, httpMethod, signingPath, apiKey)
        local decryptStartMs = ks_now_ms()
        local activeTransport = getActiveTransportForApiKey(apiKey)
        if not activeTransport or type(responseBody) ~= "string" or responseBody == "" then
            return responseBody, nil
        end
        local decodedEnvelope = nil
        if not pcall(function()
            decodedEnvelope = json.decode(responseBody)
        end) or type(decodedEnvelope) ~= "table" or tonumber(decodedEnvelope["0"] or 0) ~= 3 then
            return responseBody, nil
        end
        local nonceBase64 = tostring(decodedEnvelope["1"] or "")
        local cipherCounter = tonumber(decodedEnvelope["2"])
        local ciphertextBase64 = tostring(decodedEnvelope["3"] or "")
        local receivedMacHex = tostring(decodedEnvelope["4"] or ""):lower()
        if not cipherCounter or cipherCounter < 1 or cipherCounter > 2147483647 or not receivedMacHex:match("^[0-9a-f]+$") or #receivedMacHex ~= 64 then
            return nil, "transport shape"
        end
        local expectedMacHex = encodeBytesAsHex(computeHmacSha256(activeTransport.responseMacKey, buildTransportMacMessage("rs", httpMethod, signingPath, nonceBase64, cipherCounter, ciphertextBase64)))
        if not constantTimeHexEquals(receivedMacHex, expectedMacHex) then
            return nil, "transport mac"
        end
        local nonceBytes = base64Decode(nonceBase64)
        local ciphertext = base64Decode(ciphertextBase64)
        if not nonceBytes or #nonceBytes ~= 12 or not ciphertext then
            return nil, "transport decode"
        end
        local plaintextBody = chacha20Crypt(activeTransport.responseKey, nonceBytes, cipherCounter, ciphertext)
        if not plaintextBody then
            return nil, "transport cipher"
        end
        return plaintextBody, nil
    end

    local function extractBackendRequestPath(requestUrl)
        local urlText = tostring(requestUrl or "")
        local requestPath = urlText:match("^https?://[^/]+(/.*)$") or urlText
        if requestPath == "" then
            requestPath = "/"
        end
        local fragmentStart = requestPath:find("#", 1, true)
        if fragmentStart then
            requestPath = requestPath:sub(1, fragmentStart - 1)
        end
        if requestPath == "/k-script" then
            return "/"
        end
        if requestPath:sub(1, 10) == "/k-script/" then
            return requestPath:sub(10)
        end
        return requestPath
    end

    local function isSignableBackendPath(requestUrl)
        local backendPath = extractBackendRequestPath(requestUrl)
        if backendPath == "" or backendPath == "/" then
            return false
        end
        if backendPath == "/retired" then
            return true
        end
        if backendPath == "/retired" or backendPath:sub(1, 5) == "/retired/" then
            return false
        end
        return backendPath:sub(1, 1) == "/"
    end

    local function buildRequestSignaturePayload(httpMethod, requestPath, timestampMs, nonceHex, bodyHashHex)
        return table.concat({
            throttledYieldCallCount,
            tostring(httpMethod or "GET"):upper(),
            tostring(requestPath or "/"),
            tostring(timestampMs or ""),
            tostring(nonceHex or ""),
            tostring(bodyHashHex or ""),
        }, "\n")
    end

    local function buildResponseSignaturePayload(httpMethod, requestPath, responseContextField, timestampMs, responseNonce, bodyBase64)
        return table.concat({
            yieldScriptPeriodically,
            tostring(httpMethod or "GET"):upper(),
            tostring(requestPath or "/"),
            tostring(responseContextField or ""),
            tostring(timestampMs or ""),
            tostring(responseNonce or ""),
            tostring(bodyBase64 or ""),
        }, "\n")
    end

    local UID_HASH_SALT = "6f2e3b91a4c8075d"
    local UID_HASH_PREFIX_LENGTH = 24

    local function hashSaltedUid(rawUid)
        local numericUid = tonumber(rawUid)
        local uidText = numericUid and tostring(math.floor(numericUid)) or tostring(rawUid)
        return bytesToHex(computeSha256(UID_HASH_SALT .. "|" .. uidText))
    end

    local function encodeBase36(numberToEncode)
        local parsedNumber = tonumber(numberToEncode)
        if not parsedNumber or parsedNumber <= 0 then
            return ""
        end
        local remainingQuotient = math.floor(parsedNumber)
        local base36Alphabet = "0123456789abcdefghijklmnopqrstuvwxyz"
        local base36Text = ""
        repeat
            local alphabetIndex = remainingQuotient % 36 + 1
            base36Text = base36Alphabet:sub(alphabetIndex, alphabetIndex) .. base36Text
            remainingQuotient = math.floor(remainingQuotient / 36)
        until remainingQuotient <= 0
        return base36Text
    end

    function ks_uid_user_agent(uidOverride)
        local resolvedUid = uidOverride
        if resolvedUid == nil and isTableOrUserdata(Cherax) and type(Cherax.GetUID) == "function" then
            resolvedUid = Cherax.GetUID()
        end
        local numericUid = tonumber(resolvedUid)
        if not numericUid or numericUid <= 0 then
            return "0.0"
        end
        local uidText = tostring(math.floor(numericUid))
        local uidBase36 = encodeBase36(uidText)
        local uidHashPrefix = hashSaltedUid(uidText):sub(1, UID_HASH_PREFIX_LENGTH)
        if uidBase36 == "" or uidHashPrefix == "" then
            return "0.0"
        end
        return uidBase36 .. "." .. uidHashPrefix
    end

    local BIGINT_LIMB_BASE = 65536
    local SHA256_DIGEST_INFO_PREFIX_HEX = "3031300d060960864801650304020105000420"
    local rsaMontgomeryContextCache = nil

    local function hexToByteString(hexText)
        hexText = tostring(hexText or "")
        if #hexText % 2 ~= 0 or hexText:find("[^0-9a-fA-F]") then
            return nil
        end
        local byteChars = {}
        for hexOffset = 1, #hexText, 2 do
            byteChars[#byteChars + 1] = string.char(tonumber(hexText:sub(hexOffset, hexOffset + 1), 16))
        end
        return table.concat(byteChars)
    end

    local function bigIntTrimHighZeroLimbs(limbs)
        while #limbs > 1 and limbs[#limbs] == 0 do
            limbs[#limbs] = nil
        end
        if #limbs == 0 then
            limbs[1] = 0
        end
        return limbs
    end

    local function bigIntMultiplySmallInPlace(limbs, multiplier)
        local carry = 0
        for limbIndex = 1, #limbs do
            local limbProduct = limbs[limbIndex] * multiplier + carry
            limbs[limbIndex] = limbProduct % BIGINT_LIMB_BASE
            carry = math.floor(limbProduct / BIGINT_LIMB_BASE)
        end
        while carry > 0 do
            limbs[#limbs + 1] = carry % BIGINT_LIMB_BASE
            carry = math.floor(carry / BIGINT_LIMB_BASE)
        end
        return bigIntTrimHighZeroLimbs(limbs)
    end

    local function bigIntAddSmallInPlace(limbs, addend)
        local limbIndex = 1
        local carry = addend
        while carry > 0 do
            local limbSum = (limbs[limbIndex] or 0) + carry
            limbs[limbIndex] = limbSum % BIGINT_LIMB_BASE
            carry = math.floor(limbSum / BIGINT_LIMB_BASE)
            limbIndex = limbIndex + 1
        end
        return bigIntTrimHighZeroLimbs(limbs)
    end

    local function bigIntFromHex(hexText)
        hexText = tostring(hexText or "")
        if hexText == "" or hexText:find("[^0-9a-fA-F]") then
            return nil
        end
        local parsedBigInt = { 0 }
        for digitIndex = 1, #hexText do
            local digitValue = tonumber(hexText:sub(digitIndex, digitIndex), 16)
            if digitValue == nil then
                return nil
            end
            bigIntMultiplySmallInPlace(parsedBigInt, 16)
            bigIntAddSmallInPlace(parsedBigInt, digitValue)
        end
        return bigIntTrimHighZeroLimbs(parsedBigInt)
    end

    local function bigIntCompare(leftBigInt, rightBigInt)
        leftBigInt = bigIntTrimHighZeroLimbs(leftBigInt)
        rightBigInt = bigIntTrimHighZeroLimbs(rightBigInt)
        if #leftBigInt ~= #rightBigInt then
            return #leftBigInt > #rightBigInt and 1 or -1
        end
        for limbIndex = #leftBigInt, 1, -1 do
            if leftBigInt[limbIndex] ~= rightBigInt[limbIndex] then
                return leftBigInt[limbIndex] > rightBigInt[limbIndex] and 1 or -1
            end
        end
        return 0
    end

    local function bigIntSubtractInPlace(minuend, subtrahend)
        local borrow = 0
        for limbIndex = 1, #minuend do
            local limbDifference = minuend[limbIndex] - (subtrahend[limbIndex] or 0) - borrow
            if limbDifference < 0 then
                minuend[limbIndex] = limbDifference + BIGINT_LIMB_BASE
                borrow = 1
            else
                minuend[limbIndex] = limbDifference
                borrow = 0
            end
        end
        return bigIntTrimHighZeroLimbs(minuend)
    end

    local function bigIntMultiplyLimbs(leftFactor, rightFactor, limbCount)
        local productLimbs = {}
        for leftLimbIndex = 1, limbCount do
            local leftLimb = leftFactor[leftLimbIndex] or 0
            if leftLimb ~= 0 then
                local carry = 0
                for rightLimbIndex = 1, limbCount do
                    local productIndex = leftLimbIndex + rightLimbIndex - 1
                    local limbSum = (productLimbs[productIndex] or 0) + leftLimb * (rightFactor[rightLimbIndex] or 0) + carry
                    productLimbs[productIndex] = limbSum % BIGINT_LIMB_BASE
                    carry = math.floor(limbSum / BIGINT_LIMB_BASE)
                end
                local carryIndex = leftLimbIndex + limbCount
                while carry > 0 do
                    local carryLimbSum = (productLimbs[carryIndex] or 0) + carry
                    productLimbs[carryIndex] = carryLimbSum % BIGINT_LIMB_BASE
                    carry = math.floor(carryLimbSum / BIGINT_LIMB_BASE)
                    carryIndex = carryIndex + 1
                end
            end
            if leftLimbIndex & 15 == 0 then
                yieldDuringCurveMath()
            end
        end
        return productLimbs
    end

    local function computeMontgomeryLimbInverse(modulusLowLimb)
        local bezoutCoefficient = 0
        local nextBezoutCoefficient = 1
        local remainder = BIGINT_LIMB_BASE
        local nextRemainder = modulusLowLimb % BIGINT_LIMB_BASE
        while nextRemainder ~= 0 do
            local quotient = math.floor(remainder / nextRemainder)
            nt = bezoutCoefficient - quotient * nextBezoutCoefficient
            bezoutCoefficient = nextBezoutCoefficient
            nr = remainder - quotient * nextRemainder
            remainder = nextRemainder
        end
        if bezoutCoefficient < 0 then
            bezoutCoefficient = bezoutCoefficient + BIGINT_LIMB_BASE
        end
        return (BIGINT_LIMB_BASE - bezoutCoefficient) % BIGINT_LIMB_BASE
    end

    local function montgomeryReduce(productLimbs, montgomeryContext)
        local modulusLimbs = montgomeryContext.n
        local limbCount = montgomeryContext.k
        local negatedModulusInverse = montgomeryContext.ni
        for limbIndex = 1, limbCount do
            local reductionFactor = (productLimbs[limbIndex] or 0) * negatedModulusInverse % BIGINT_LIMB_BASE
            local carry = 0
            for modulusLimbIndex = 1, limbCount do
                local productIndex = limbIndex + modulusLimbIndex - 1
                local limbSum = (productLimbs[productIndex] or 0) + reductionFactor * (modulusLimbs[modulusLimbIndex] or 0) + carry
                productLimbs[productIndex] = limbSum % BIGINT_LIMB_BASE
                carry = math.floor(limbSum / BIGINT_LIMB_BASE)
            end
            local carryIndex = limbIndex + limbCount
            while carry > 0 do
                local carryLimbSum = (productLimbs[carryIndex] or 0) + carry
                productLimbs[carryIndex] = carryLimbSum % BIGINT_LIMB_BASE
                carry = math.floor(carryLimbSum / BIGINT_LIMB_BASE)
                carryIndex = carryIndex + 1
            end
            if limbIndex & 15 == 0 then
                yieldDuringCurveMath()
            end
        end
        local reducedLimbs = {}
        for reducedLimbIndex = 1, limbCount do
            reducedLimbs[reducedLimbIndex] = productLimbs[reducedLimbIndex + limbCount] or 0
        end
        bigIntTrimHighZeroLimbs(reducedLimbs)
        while bigIntCompare(reducedLimbs, modulusLimbs) >= 0 do
            bigIntSubtractInPlace(reducedLimbs, modulusLimbs)
        end
        return reducedLimbs
    end

    local function montgomeryMultiply(leftFactor, rightFactor, montgomeryContext)
        return montgomeryReduce(bigIntMultiplyLimbs(leftFactor, rightFactor, montgomeryContext.k), montgomeryContext)
    end

    local function getRsaMontgomeryContext()
        if rsaMontgomeryContextCache then
            return rsaMontgomeryContextCache
        end
        local modulusLimbs = bigIntFromHex(RSA_MODULUS_HEX)
        local rSquaredLimbs = bigIntFromHex(RSA_MONTGOMERY_R2_HEX)
        if not modulusLimbs or not rSquaredLimbs or modulusLimbs[1] % 2 == 0 then
            return nil
        end
        local limbCount = math.floor(#RSA_MODULUS_HEX / 4)
        for modulusPadIndex = #modulusLimbs + 1, limbCount do
            modulusLimbs[modulusPadIndex] = 0
        end
        for rSquaredPadIndex = #rSquaredLimbs + 1, limbCount do
            rSquaredLimbs[rSquaredPadIndex] = 0
        end
        rsaMontgomeryContextCache = {
            n = modulusLimbs,
            k = limbCount,
            ni = computeMontgomeryLimbInverse(modulusLimbs[1]),
            r2 = rSquaredLimbs,
            one = { 1 },
        }
        return rsaMontgomeryContextCache
    end

    local function bigIntToByteString(bigIntLimbs, byteLength)
        local byteChars = {}
        local bytePosition = byteLength
        for limbIndex = 1, math.ceil(byteLength / 2) do
            local limbValue = bigIntLimbs[limbIndex] or 0
            byteChars[bytePosition] = string.char(limbValue % 256)
            bytePosition = bytePosition - 1
            if bytePosition >= 1 then
                byteChars[bytePosition] = string.char(math.floor(limbValue / 256) % 256)
                bytePosition = bytePosition - 1
            end
        end
        while bytePosition >= 1 do
            byteChars[bytePosition] = string.char(0)
            bytePosition = bytePosition - 1
        end
        return table.concat(byteChars)
    end

    local function verifyRsaPkcs1Signature(signedMessage, signatureHex)
        signatureHex = tostring(signatureHex or ""):lower()
        if RSA_PUBLIC_EXPONENT_HEX ~= "010001" or #RSA_MODULUS_HEX < 512 or #RSA_MODULUS_HEX % 2 ~= 0 then
            return false
        end
        if #signatureHex ~= #RSA_MODULUS_HEX or signatureHex:find("[^0-9a-f]") then
            return false
        end
        local montgomeryContext = getRsaMontgomeryContext()
        local signatureBigInt = bigIntFromHex(signatureHex)
        if not montgomeryContext or not signatureBigInt or bigIntCompare(signatureBigInt, montgomeryContext.n) >= 0 then
            return false
        end
        local signatureMontgomery = montgomeryMultiply(signatureBigInt, montgomeryContext.r2, montgomeryContext)
        local squaredPower = signatureMontgomery
        for _ = 1, 16 do
            squaredPower = montgomeryMultiply(squaredPower, squaredPower, montgomeryContext)
        end
        local exponentiatedSignature = montgomeryMultiply(squaredPower, signatureMontgomery, montgomeryContext)
        local decryptedBigInt = montgomeryMultiply(exponentiatedSignature, montgomeryContext.one, montgomeryContext)
        local decryptedBlock = bigIntToByteString(decryptedBigInt, montgomeryContext.k * 2)
        if not decryptedBlock or #decryptedBlock < 32 or decryptedBlock:byte(1) ~= 0 or decryptedBlock:byte(2) ~= 1 then
            return false
        end
        local paddingIndex = 3
        while paddingIndex <= #decryptedBlock and decryptedBlock:byte(paddingIndex) == 255 do
            paddingIndex = paddingIndex + 1
        end
        if paddingIndex < 11 or paddingIndex > #decryptedBlock or decryptedBlock:byte(paddingIndex) ~= 0 then
            return false
        end
        return hexToByteString(SHA256_DIGEST_INFO_PREFIX_HEX .. bytesToHex(computeSha256(signedMessage))) ~= nil
    end

    local function verifySignedResponseEnvelope(rawResponseBody, requestMethod, expectedPath, signingKey)
        local startTimeMs = ks_now_ms()
        local upperMethod = tostring(requestMethod or "GET"):upper()
        local keyFingerprint = ks_key_fingerprint(signingKey)
        local responseLength = ks_bytes_len(rawResponseBody)

        local function failVerification(failureReason, failureDetail)
            return nil, failureReason
        end

        if type(json) ~= "table" or type(json.decode) ~= "function" then
            return failVerification("json decoder unavailable")
        end
        local signedEnvelope = nil
        local decodeOk = pcall(function()
            signedEnvelope = json.decode(tostring(rawResponseBody or ""))
        end)
        if not decodeOk or type(signedEnvelope) ~= "table" or tostring(signedEnvelope["0"] or "") ~= "1" then
            return failVerification("missing signed envelope", ("decode_ok=%s shape=%s marker=%s"):format(tostring(decodeOk), type(signedEnvelope), type(signedEnvelope) == "table" and tostring(signedEnvelope["0"] or "-") or "-"))
        end
        local envelopeVersion = tostring(signedEnvelope["1"] or "")
        local signatureMode = tostring(signedEnvelope["2"] or "")
        local timestampText = tostring(signedEnvelope["3"] or "")
        local responseNonce = tostring(signedEnvelope["4"] or "")
        local responsePath = tostring(signedEnvelope["5"] or "")
        local responseStatus = tostring(signedEnvelope["6"] or "")
        local encodedPayload = tostring(signedEnvelope["7"] or "")
        local responseSignature = tostring(signedEnvelope["8"] or ""):lower()
        if envelopeVersion ~= registeredFeatures then
            return failVerification("version mismatch", ("version=%s expected=%s"):format(envelopeVersion, tostring(registeredFeatures)))
        end
        if signatureMode ~= "0" and signatureMode ~= "1" then
            return failVerification("signed response invalid", nil)
        end
        if responsePath ~= tostring(expectedPath or "") then
            return failVerification("signed response invalid", nil)
        end
        if responseNonce == "" or encodedPayload == "" or responseStatus == "" then
            return failVerification("signed response invalid", nil)
        end
        local nowMs = math.floor(os.time() * 1000)
        local responseTimestampMs = tonumber(timestampText)
        if not responseTimestampMs or math.abs(nowMs - responseTimestampMs) > buildFeatureActionLogId then
            return failVerification("timestamp skew", ("ts=%s now=%s skew_ms=%s allowed_ms=%s"):format(timestampText, tostring(nowMs), responseTimestampMs and tostring(math.abs(nowMs - responseTimestampMs)) or "invalid", tostring(buildFeatureActionLogId)))
        end
        for cachedReplayKey, replayExpiryMs in pairs(replayCacheOrLogSkipSet) do
            if nowMs >= replayExpiryMs then
                replayCacheOrLogSkipSet[cachedReplayKey] = nil
            end
        end
        local replayKey = responsePath .. "|" .. responseNonce
        if replayCacheOrLogSkipSet[replayKey] then
            return failVerification("signed response invalid", nil)
        end
        local signaturePayload = buildResponseSignaturePayload(requestMethod, responsePath, responseStatus, timestampText, responseNonce, encodedPayload)
        if signatureMode == "1" then
            if not verifyRsaPkcs1Signature(signaturePayload, responseSignature) then
                return failVerification("signed response invalid", nil)
            end
        else
            if not responseSignature:match("^[0-9a-f]+$") or #responseSignature ~= 64 then
                return failVerification("signed response invalid", nil)
            end
            local expectedHmacHex = bytesToHex(computeHmacSha256(signingKey, signaturePayload))
            if not constantTimeHexEquals(responseSignature, expectedHmacHex) then
                return failVerification("signed response invalid", nil)
            end
        end
        local decodedPayload = base64Decode(encodedPayload)
        if decodedPayload == nil then
            return failVerification("signed response invalid", nil)
        end
        replayCacheOrLogSkipSet[replayKey] = nowMs + buildFeatureActionLogId
        return decodedPayload, nil
    end

    local function isApiKeyExpiredResponse(responseText)
        return tostring(responseText or ""):lower():find("api key expired", 1, true) ~= nil
    end

    local function addSignedRequestHeaders(curlHandle, requestMethod, requestUrl, requestBody, signingKey)
        local startTimeMs = ks_now_ms()
        if not curlHandle or type(curlHandle.AddHeader) ~= "function" then
            return false
        end
        if type(signingKey) ~= "string" or signingKey == "" or signingKey == "0" then
            return false
        end
        if not isSignableBackendPath(requestUrl) then
            return false
        end
        local requestPath = extractBackendRequestPath(requestUrl)
        local timestampMs = tostring(math.floor(os.time() * 1000))
        local requestNonce = generateRandomHex(16)
        local bodyHashHex = bytesToHex(computeSha256(tostring(requestBody or "")))
        local signaturePayload = buildRequestSignaturePayload(requestMethod, requestPath, timestampMs, requestNonce, bodyHashHex)
        local signatureHex = bytesToHex(computeHmacSha256(signingKey, signaturePayload))
        curlHandle:AddHeader("X-C-10: " .. registeredFeatures)
        curlHandle:AddHeader("X-C-11: " .. timestampMs)
        curlHandle:AddHeader("X-C-12: " .. requestNonce)
        curlHandle:AddHeader("X-C-13: " .. bodyHashHex)
        curlHandle:AddHeader("X-C-14: " .. signatureHex)
        if type(sessionHeaderToken) == "string" and sessionHeaderToken ~= "" and sessionHeaderToken ~= "0" then
            curlHandle:AddHeader("X-C-22: " .. sessionHeaderToken)
        end
        return true
    end

    local function parseHttpHeaderLine(headerLine)
        local headerName, headerValue = tostring(headerLine or ""):match("^%s*([^:]+)%s*:%s*(.-)%s*$")
        if not headerName then
            return nil, nil
        end
        return headerName:lower(), headerValue
    end

    __m0 = {
        s = computeSha256,
        h = computeHmacSha256,
        b = base64Decode,
        e = base64Encode,
        c = constantTimeHexEquals,
    }
    ;(function()
        if not isTableOrUserdata(Curl) or type(Curl.Easy) ~= "function" or Curl.__c10 then
            return
        end
        local originalCurlEasy = Curl.Easy

        function Curl.Easy(...)
            local innerCurlHandle = originalCurlEasy(...)
            local requestState = {
                url = "",
                method = "GET",
                body = "",
                headers = {},
                signed = false,
                signingKey = nil,
                signingPath = nil,
                encrypted = false,
                responseChecked = false,
                responseBody = nil,
            }

            local function findHeaderValue(wantedHeaderName)
                wantedHeaderName = tostring(wantedHeaderName or ""):lower()
                for _, rawHeader in ipairs(requestState.headers) do
                    local parsedHeaderName, parsedHeaderValue = parseHttpHeaderLine(rawHeader)
                    if parsedHeaderName == wantedHeaderName then
                        return parsedHeaderValue
                    end
                end
                return nil
            end

            local function resolveSigningKey()
                local apiKeyHeaderValue = findHeaderValue("X-C-21")
                if apiKeyHeaderValue and apiKeyHeaderValue ~= "" then
                    return apiKeyHeaderValue
                end
                local scriptTokenHeaderValue = findHeaderValue("X-C-20")
                if scriptTokenHeaderValue and scriptTokenHeaderValue ~= "" then
                    return scriptTokenHeaderValue
                end
                return nil
            end

            local function signPendingRequest()
                if requestState.signed then
                    return
                end
                if not isSignableBackendPath(requestState.url) then
                    return
                end
                local signingKey = resolveSigningKey()
                if not signingKey or signingKey == "0" then
                    return
                end
                local signStartMs = ks_now_ms()
                if not addSignedRequestHeaders(innerCurlHandle, requestState.method, requestState.url, requestState.body, signingKey) then
                    return
                end
                requestState.signed = true
                requestState.signingKey = signingKey
                local requestPath = extractBackendRequestPath(requestState.url)
                requestState.signingPath = requestPath
                local encryptedBody, encryptError = encryptTransportRequestBody(requestState.body, requestState.method, requestState.signingPath, signingKey)
                if encryptedBody then
                    innerCurlHandle:Setopt(eCurlOption.CURLOPT_POSTFIELDS, encryptedBody)
                    innerCurlHandle:AddHeader("X-C-30: 1")
                    requestState.encrypted = true
                elseif encryptError then
                    requestScriptUnload()
                end
            end

            local proxyHandle = {}
            setmetatable(proxyHandle, {
                __index = function(proxySelf, memberName)
                    local innerMember = innerCurlHandle[memberName]
                    if type(innerMember) ~= "function" then
                        return innerMember
                    end
                    return function(callerSelf, ...)
                        if memberName == "Setopt" then
                            local optionId, optionValue = ...
                            if eCurlOption then
                                if optionId == eCurlOption.CURLOPT_URL then
                                    local urlText = tostring(optionValue or "")
                                    requestState.url = urlText
                                end
                            elseif eCurlOption then
                                if optionId == eCurlOption.CURLOPT_POSTFIELDS then
                                    local bodyText = tostring(optionValue or "")
                                    requestState.body = bodyText
                                end
                            elseif eCurlOption then
                                if optionId == eCurlOption.CURLOPT_POST and tonumber(optionValue) == 1 then
                                    requestState.method = "POST"
                                end
                            end
                            return innerMember(innerCurlHandle, ...)
                        elseif memberName == "AddHeader" then
                            local addedHeaderLine = tostring((...) or "")
                            requestState.headers[#requestState.headers + 1] = addedHeaderLine
                            return innerMember(innerCurlHandle, ...)
                        elseif memberName == "Perform" then
                            requestState.responseChecked = false
                            requestState.responseBody = nil
                            signPendingRequest()
                            return innerMember(innerCurlHandle, ...)
                        elseif memberName == "GetResponse" then
                            local curlCode, rawResponse = innerMember(innerCurlHandle, ...)
                            if requestState.responseChecked then
                                return curlCode, requestState.responseBody
                            end
                            requestState.responseChecked = true
                            requestState.responseBody = rawResponse
                            if requestState.signed and curlCode == eCurlCode.CURLE_OK and type(rawResponse) == "string" and rawResponse ~= "" then
                                local verifyInput = rawResponse
                                local decryptedBody, decryptError = decryptTransportResponseBody(rawResponse, requestState.method, requestState.signingPath, requestState.signingKey)
                                if decryptedBody ~= nil then
                                    verifyInput = decryptedBody
                                    requestState.responseBody = decryptedBody
                                elseif decryptError then
                                    requestScriptUnload()
                                end
                                if not ShouldUnload() then
                                    local verifiedPayload, verifyError = verifySignedResponseEnvelope(verifyInput, requestState.method, requestState.signingPath, requestState.signingKey)
                                    if verifiedPayload ~= nil then
                                        requestState.responseBody = verifiedPayload
                                    elseif not isApiKeyExpiredResponse(verifyInput) then
                                        requestScriptUnload()
                                    end
                                end
                            end
                            return curlCode, requestState.responseBody
                        end
                        return innerMember(innerCurlHandle, ...)
                    end
                end,
            })
            return proxyHandle
        end

        Curl.__c10 = true
    end)()
    registeredFeatures = {}
    throttledYieldCallCount = "hashAndName"
    yieldScriptPeriodically = {}
    registeredFeatures[throttledYieldCallCount] = yieldScriptPeriodically
    throttledYieldCallCount = 0

    function yieldScriptPeriodically(shouldForceYield)
        throttledYieldCallCount = throttledYieldCallCount + 1
        if not shouldForceYield and throttledYieldCallCount % 24 ~= 0 then
            return
        end
        if isTableOrUserdata(Script) and type(Script.Yield) == "function" and not ShouldUnload() then
            Script.Yield(16)
        end
    end

    function buildFeatureActionLogId(featureHash, featureName)
        local normalizedFeatureName = tostring(featureName or "feature"):lower():gsub("[^a-z0-9]+", "_"):gsub("^_+", ""):gsub("_+$", "")
        if normalizedFeatureName == "" then
            normalizedFeatureName = "feature"
        end
        local truncatedFeatureName = normalizedFeatureName:sub(1, 40)
        local featureHashDigits = tostring(featureHash or "0"):gsub("[^0-9]", "")
        if featureHashDigits == "" then
            featureHashDigits = "0"
        end
        return ("main_%s_%s"):format(truncatedFeatureName, featureHashDigits):sub(1, 63)
    end

    replayCacheOrLogSkipSet = {}
    local vehicleFlyModeFeatureHash = Utils.Joaat("vehicleflymode")
    replayCacheOrLogSkipSet[vehicleFlyModeFeatureHash] = true
    local crashAllkFeatureHash = Utils.Joaat("crashAllk")
    replayCacheOrLogSkipSet[crashAllkFeatureHash] = true

    function logFeatureInteraction(featureHash, featureName, featureType, invokedFeature)
        if executingSettingsLoad or type(LogFeatureAction) ~= "function" or replayCacheOrLogSkipSet[featureHash] then
            return
        end
        local actionName = nil
        local actionDetails = nil
        if featureType == eFeatureType.Toggle then
            local isToggledOn = isTableOrUserdata(invokedFeature)
            if isToggledOn then
                local toggleStateAccessor = invokedFeature.IsToggled
                isToggledOn = toggleStateAccessor == "function" and toggleStateAccessor
            end
            if not isToggledOn or not "feature_toggle_enabled" then
                actionName = "feature_toggle_disabled"
            end
            actionDetails = { state = isToggledOn and "enabled" or "disabled", target_scope = "local", result = "executed" }
        elseif featureType == eFeatureType.Button then
            actionName = "feature_button_pressed"
            actionDetails = { target_scope = "local", result = "executed" }
        elseif featureType == eFeatureType.Combo then
            actionName = "feature_option_changed"
            actionDetails = { option_kind = "dropdown", new_category = "updated", result = "executed" }
        elseif featureType ~= eFeatureType.SliderInt and featureType ~= eFeatureType.SliderFloat then
            if featureType == eFeatureType.InputInt then
                actionName = "feature_option_changed"
                actionDetails = { option_kind = "numeric", new_category = "updated", result = "executed" }
            end
        else
            actionName = "feature_option_changed"
            actionDetails = { option_kind = "slider", new_category = "updated", result = "executed" }
        end
        if not actionName then
            return
        end
        actionDetails.feature_id = buildFeatureActionLogId(featureHash, featureName)
        actionDetails.feature_name = featureName
        actionDetails.module_id = "main"
        actionDetails.source = "main_payload"
        pcall(LogFeatureAction, actionName, actionDetails)
    end
end
local isHexStringOfLength, clearRuntimeSession, reportRuntimeIntegrityEvent, reportRuntimeProgressPhase, failRuntimeBridgeInit, queueRuntimeReadySignal, featurePlaneCapabilities
do
    function FeatAdd(featureHash, featureName, ...)
        local addFeatureArgs = table.pack(...)
        local featureType = addFeatureArgs[1]
        local originalCallback = addFeatureArgs[3]
        if addFeatureArgs[2] == nil then
            addFeatureArgs[2] = ""
        end

        addFeatureArgs[3] = function(invokedFeature, ...)
            local callbackResults = nil
            if type(originalCallback) == "function" then
                callbackResults = table.pack(originalCallback(invokedFeature, ...))
            end
            logFeatureInteraction(featureHash, featureName, featureType, invokedFeature)
            if callbackResults then
                return table.unpack(callbackResults, 1, callbackResults.n)
            end
        end

        local addedFeature = FeatureMgr.AddFeature(featureHash, featureName, table.unpack(addFeatureArgs, 1, math.max(addFeatureArgs.n, 3)))
        table.insert(registeredFeatures, addedFeature)
        registeredFeatures.hashAndName[featureHash] = featureName
        FeatureMgr.GetFeature(featureHash):SetSaveable(false):SetSearchable(false)
        yieldScriptPeriodically(false)
        return addedFeature
    end

    function PlayerFeatAdd(featureHash, featureName, ...)
        local playerFeatureType = ...
        local addedPlayerFeature = FeatureMgr.AddPlayerFeature(featureHash, featureName, playerFeatureType)
        table.insert(registeredFeatures, addedPlayerFeature)
        registeredFeatures.hashAndName[featureHash] = featureName
        yieldScriptPeriodically(false)
        return addedPlayerFeature
    end

    function StructInstance(structLayout, baseOffset)
        local resolvedStruct = {}
        for fieldName, fieldLayout in pairs(structLayout) do
            if type(fieldLayout) == "number" then
                resolvedStruct[fieldName] = fieldLayout + baseOffset
            elseif type(fieldLayout) == "table" then
                resolvedStruct[fieldName] = Globals.StructInstance(fieldLayout, baseOffset)
            end
        end
        return resolvedStruct
    end

    function formatTime(unixTimestamp)
        if not unixTimestamp then
            return "Unknown"
        end
        return os.date("%d/%m/%Y %H:%M:%S", unixTimestamp)
    end

    activities = {}

    function FuckTheNiggersGame(shouldDelayAbort)
        if not shouldDelayAbort then
            shouldDelayAbort = false
        end
        if shouldDelayAbort then
            Script.Yield(2000)
        end
        if type(KSRuntimeAbort) == "function" then
            return KSRuntimeAbort("fatal_helper", true)
        end
        requestScriptUnload()
        return false
    end

    function KSRuntimeCheckpoint(checkpointName)
        checkpointName = tostring(checkpointName or "unknown"):gsub("[^%w_%-]", "_")
        if checkpointName == "" then
            checkpointName = "unknown"
        end
        __ks_payload_checkpoint = checkpointName:sub(1, 80)
        return __ks_payload_checkpoint
    end

    function KSRuntimeAbort(abortReason, isHardAbort)
        abortReason = KSRuntimeCheckpoint(abortReason or "runtime_abort")
        __ks_payload_abort_hard = isHardAbort == true
        assert(false, "__KS_RUNTIME_ABORT__ " .. abortReason)
        return false
    end

    local TERMINAL_VIOLATION_REASONS = {
        forbidden_friend_target = true,
        forbidden_blacklisted_target = true,
        forbidden_protected_runtime_target = true,
        runtime_identity_mismatch = true,
        local_runtime_blacklist_match = true,
        external_runtime_asset_tamper = true,
        runtime_response_integrity_violation = true,
        forbidden_feature_authority = true,
    }

    function KSRuntimeTerminalViolation(violationReason)
        violationReason = tostring(violationReason or "")
        if not TERMINAL_VIOLATION_REASONS[violationReason] then
            return false
        end
        if loaderAdapter and type(loaderAdapter.terminal_violation) == "function" then
            loaderAdapter.terminal_violation(violationReason)
        end
        requestScriptUnload()
        return false
    end

    local downloadedAssetPaths = {}

    function DownloadAndSaveLuaAssets(assetUrl, assetFileName, shouldUnloadOnFailure)
        shouldUnloadOnFailure = shouldUnloadOnFailure ~= false
        local curlRequest = Curl.Easy()
        curlRequest:Setopt(eCurlOption.CURLOPT_URL, assetUrl)
        curlRequest:Setopt(eCurlOption.CURLOPT_USERAGENT, ks_uid_user_agent())
        local performOk, performError = pcall(function()
            curlRequest:Perform()
        end)
        if not performOk then
            Logger.LogError("K-Script: dependency request failed.")
            if shouldUnloadOnFailure then
                requestScriptUnload()
            end
            return false
        end
        while not curlRequest:GetFinished() do
            if ShouldUnload() then
                return false
            end
            Script.Yield(10)
        end
        local curlCode, responseBody = curlRequest:GetResponse()
        if curlCode == eCurlCode.CURLE_OK then
            local kScriptDirectory = FileMgr.GetMenuRootPath() .. "\\Lua\\K-Script\\"
            FileMgr.CreateDir(kScriptDirectory)
            local assetFilePath = kScriptDirectory .. assetFileName
            local fileExtension = string.lower(assetFileName:match("%.([^%.]+)$") or "")
            if fileExtension == "png" or fileExtension == "wav" then
                local assetFileHandle = io.open(assetFilePath, "wb")
                if not assetFileHandle then
                    Logger.LogError("K-Script: dependency write failed.")
                    return false
                end
                assetFileHandle:write(responseBody)
                assetFileHandle:close()
            elseif not FileMgr.WriteFileContent(assetFilePath, responseBody) then
                Logger.LogError("Error saving dependencies!")
                if shouldUnloadOnFailure then
                    requestScriptUnload()
                end
                return false
            end
            downloadedAssetPaths[assetFilePath] = true
            return true
        else
            Logger.LogError("K-Script: dependency download failed.")
            if shouldUnloadOnFailure then
                requestScriptUnload()
            end
            return false
        end
    end

    function QueueKScriptTextureAsset(textureUrl, textureFileName)
        local textureFilePath = (FileMgr.GetMenuRootPath() .. "\\Lua\\K-Script\\") .. textureFileName
        texturePath = textureFilePath

        local function tryLoadTexture()
            if not FileMgr.DoesFileExist(textureFilePath) then
                return false
            end
            if type(Texture) ~= "table" or type(Texture.LoadTexture) ~= "function" or type(Texture.GetTexture) ~= "function" then
                return false
            end
            toastImageId = Texture.LoadTexture(texturePath)
            toastTexture = Texture.GetTexture(toastImageId)
            return toastTexture ~= nil
        end

        if tryLoadTexture() then
            return true
        end
        if isTableOrUserdata(Script) and type(Script.QueueJob) == "function" then
            Script.QueueJob(function()
                if ShouldUnload() then
                    return
                end
                DownloadAndSaveLuaAssets(textureUrl, textureFileName, false)
                if ShouldUnload() then
                    return
                end
                tryLoadTexture()
            end)
            return false
        end
        DownloadAndSaveLuaAssets(textureUrl, textureFileName, false)
        return tryLoadTexture()
    end

    natives = FileMgr.GetMenuRootPath() .. "\\Lua\\K-Script\\nativedb.lua"
    ksNativeDbLoaded = false
    if not FileMgr.DoesFileExist(natives) and not DownloadAndSaveLuaAssets("https://kyuubii.dev/cherax/lua/lib/natives.lua", "nativedb.lua") then
        requestScriptUnload()
        return
    end
    local dependencyBlake2sHashByPath = { [natives] = "4482c0634cd60fdad63acbb181552e6e27ef8d48ae0357eb8960130b054a9063" }

    local function verifyDependencyFileHash(dependencyFilePath)
        local expectedHash = dependencyBlake2sHashByPath[dependencyFilePath]
        if not expectedHash then
            Logger.LogError("K-Script: dependency integrity unavailable.")
            requestScriptUnload()
            return false
        end
        local dependencyFileHandle = io.open(dependencyFilePath, "rb")
        local fileContents = dependencyFileHandle and dependencyFileHandle:read("*a") or nil
        if dependencyFileHandle then
            dependencyFileHandle:close()
        end
        if not fileContents or #fileContents == 0 then
            Logger.LogError("K-Script: dependency read failed.")
            requestScriptUnload()
            return false
        end
        if bytesToHex(blake2sDigest(fileContents)) ~= expectedHash then
            if not downloadedAssetPaths[dependencyFilePath] then
                externalTamperDetected = true
                GUI.AddToast("K-Script", "Detected external File Tampering, unloading...", 20000, eToastPos.TOP_RIGHT)
            else
                Logger.LogError("K-Script: dependency integrity check failed.")
                GUI.AddToast("K-Script", "Asset Downloader detected File corruption, please Reload the Script!\nIf the issue persist use a VPN!", 20000, eToastPos.TOP_RIGHT)
            end
            FileMgr.DeleteFile(dependencyFilePath)
            KSRuntimeTerminalViolation("external_runtime_asset_tamper")
            return false
        end
        return true
    end

    for dependencyPath in pairs({ [natives] = false }) do
        if not verifyDependencyFileHash(dependencyPath) then
            return
        end
    end
    if not externalTamperDetected then
        dofile(natives)
        ksNativeDbLoaded = isTableOrUserdata(Natives) and type(Natives.InvokeString) == "function"
    end

    local function sendHttpRequestWithTimeout(httpMethod, requestUrl, requestBody, requestHeaders)
        local deadlineSeconds = getMonotonicSeconds() + getRequestTimeoutSeconds("challengeCreate", 30)
        local curlRequest = Curl.Easy()
        curlRequest:Setopt(eCurlOption.CURLOPT_URL, requestUrl)
        curlRequest:Setopt(eCurlOption.CURLOPT_USERAGENT, ks_uid_user_agent())
        curlRequest:DisableErrorLog()
        if requestHeaders then
            for headerName, headerValue in pairs(requestHeaders) do
                curlRequest:AddHeader(tostring(headerName) .. ": " .. tostring(headerValue))
            end
        end
        if httpMethod == "POST" then
            curlRequest:Setopt(eCurlOption.CURLOPT_POST, 1)
            curlRequest:Setopt(eCurlOption.CURLOPT_POSTFIELDS, requestBody or "{}")
        end
        curlRequest:Perform()
        while not curlRequest:GetFinished() do
            if ShouldUnload() then
                return nil
            end
            if deadlineSeconds <= getMonotonicSeconds() then
                return nil, "timeout"
            end
            Script.Yield(5)
        end
        local curlCode, responseBody = curlRequest:GetResponse()
        if curlCode ~= eCurlCode.CURLE_OK then
            return nil, "curl_" .. tostring(curlCode)
        end
        return responseBody, nil
    end

    function isHexStringOfLength(hexCandidate, expectedLength)
        hexCandidate = tostring(hexCandidate or "")
        if #hexCandidate ~= expectedLength then
            return false
        end
        return hexCandidate:match("^[0-9a-fA-F]+$") ~= nil
    end

    local unusedReportTransportOverride = nil

    function clearRuntimeSession()
        local previousSessionContext = runtimeSessionContext
        runtimeSessionContext = nil
        sessionHeaderToken = ""
        if previousSessionContext and type(previousSessionContext.w) == "function" then
            pcall(previousSessionContext.w)
        end
        collectgarbage("collect")
        collectgarbage("collect")
    end

    local isReportingRuntimeEvent = false

    function reportRuntimeIntegrityEvent(eventReason, isIntegrityViolation)
        if loaderAdapter then
            if isReportingRuntimeEvent then
                return
            end
            isReportingRuntimeEvent = true
            loaderAdapter.signal(isIntegrityViolation == true and "runtime_integrity" or "unexpected_state", { source = "lua_runtime" })
            isReportingRuntimeEvent = false
            return
        end
        if isReportingRuntimeEvent then
            return
        end
        isReportingRuntimeEvent = true
        local reportSession = runtimeSessionContext
        local transportOverride = unusedReportTransportOverride
        local sendReportRequest = transportOverride and transportOverride.hr or sendHttpRequestWithTimeout
        local encodeReportJson
        if transportOverride then
            encodeReportJson = transportOverride.je
            if encodeReportJson then
                goto jsonEncoderResolved
            end
        end
        if type(json) == "table" then
            encodeReportJson = json.encode
            if encodeReportJson then
                goto jsonEncoderResolved
            end
        end
        encodeReportJson = nil
        ::jsonEncoderResolved::
        local scriptToken = tostring(__a25 or "")
        if validateRequestAuth("runtimeReport", { scriptToken = scriptToken }) and reportSession and type(sendReportRequest) == "function" and type(encodeReportJson) == "function" and scriptToken ~= "" and scriptToken ~= "0" and isHexStringOfLength(reportSession.s, 32) then
            local encodeOk, reportBody = pcall(encodeReportJson, {
                s = reportSession.s,
                r = tostring(eventReason or "unknown"),
                p = "runtime",
                h = isIntegrityViolation == true,
            })
            if encodeOk and type(reportBody) == "string" then
                local requestHeaders = { ["Content-Type"] = "application/json", ["X-C-20"] = scriptToken }
                if sessionHeaderToken ~= "" then
                    requestHeaders["X-C-22"] = sessionHeaderToken
                end
                pcall(sendReportRequest, "POST", tostring(reportSession.a or apiBase or API_BASE or "") .. "/retired", reportBody, requestHeaders)
            end
        end
        isReportingRuntimeEvent = false
    end

    local runtimeReadyHandshake = { generation = loaderLoadGeneration, state = "pending" }
    local lastRuntimeProgressSequence = 0
    local reportedRuntimeProgressPhases = {}

    function reportRuntimeProgressPhase(progressPhase)
        if reportedRuntimeProgressPhases[progressPhase] then
            return true
        end
        if not loaderAdapter or type(loaderAdapter.request) ~= "function" or ShouldUnload() then
            return false
        end
        local nextSequence = lastRuntimeProgressSequence + 1
        if loaderAdapter.request("runtime.progress", { phase = progressPhase, sequence = nextSequence }, 5000) ~= "ok" then
            return false
        end
        lastRuntimeProgressSequence = nextSequence
        reportedRuntimeProgressPhases[progressPhase] = true
        return true
    end

    function failRuntimeBridgeInit()
        if runtimeReadyHandshake.state == "failed" then
            return false
        end
        runtimeReadyHandshake.state = "failed"
        recordUnloadReason("ui_registration_failed")
        if isTableOrUserdata(GUI) and type(GUI.AddToast) == "function" then
            GUI.AddToast("K-Script", "Runtime bridge initialization failed. Please restart the Loader.", 10000, type(eToastPos) == "table" and eToastPos.TOP_RIGHT or nil)
        end
        requestScriptUnload("ui_registration_failed")
        return false
    end

    if not reportRuntimeProgressPhase("main_started") then
        failRuntimeBridgeInit()
    end

    function queueRuntimeReadySignal()
        if runtimeReadyHandshake.state == "ready" then
            return true
        end
        if runtimeReadyHandshake.state == "queued" or runtimeReadyHandshake.state == "in_flight" then
            return true
        end
        if runtimeReadyHandshake.state == "failed" or not isRuntimeGenerationCurrent() then
            return false
        end
        runtimeReadyHandshake.state = "queued"
        local handshakeGeneration = runtimeReadyHandshake.generation
        if Script.QueueJob(function()
            if handshakeGeneration ~= startupProgressState.generation or not isRuntimeGenerationCurrent() then
                runtimeReadyHandshake.state = "cancelled"
                return
            end
            runtimeReadyHandshake.state = "in_flight"
            if not reportRuntimeProgressPhase("ui_ready") then
                failRuntimeBridgeInit()
                return
            end
            local readyStatus = loaderAdapter.request("runtime.ready", {
                build = isGameVersionEnhanced and "enhanced" or "legacy",
                capabilities = {
                    "startup.snapshot",
                    "config.get",
                    "permissions.get",
                    "module.get",
                    "module.batch.get",
                    "players.status.getBatch",
                    "blacklist.actionResult",
                    "users.online.get",
                    "feature.action",
                    "discord.accounts.scan",
                    "discord.presence",
                    "runtime.progress",
                    "staff.notification.deliver",
                    "staff.notification.receipt",
                    "staff.notification.ack",
                    "runtime.control.create",
                    "runtime.control.deliver",
                    "runtime.control.result",
                    "runtime.unload",
                },
                ui_ready = true,
                first_render = true,
            }, 5000)
            if handshakeGeneration ~= startupProgressState.generation or not isRuntimeGenerationCurrent() then
                runtimeReadyHandshake.state = "cancelled"
                return
            end
            if readyStatus ~= "ok" then
                failRuntimeBridgeInit()
                return
            end
            runtimeReadyHandshake.state = "ready"
            if type(KSStartOnlineUsersV3Loop) == "function" then
                KSStartOnlineUsersV3Loop()
            end
            markStartupReady()
        end) == false then
            return failRuntimeBridgeInit()
        end
        return true
    end

    KSModules = KSModules or { loaded = {}, loading = {}, lastError = {}, lastHard = {} }
    KSModules.loaded = KSModules.loaded or {}
    KSModules.loading = KSModules.loading or {}
    KSModules.lastError = KSModules.lastError or {}
    KSModules.lastHard = KSModules.lastHard or {}
    KSModules.callbacks = KSModules.callbacks or {}
    KSModules.requests = KSModules.requests or {}
    KSModules.generations = KSModules.generations or {}
    KSModules.states = KSModules.states or {}
    KSModules.owners = KSModules.owners or {}
    KSModules.perf = KSModules.perf or {}
    KSModules.perfSequence = tonumber(KSModules.perfSequence) or 0
    featurePlaneCapabilities = nil
    local runtimeModuleRequestUrl = backendBaseUrl .. "/retired"
    local moduleEnvelopeSignTag = "ks-runtime-module-v1"
    local MODULE_ALIAS_HMAC_TAG = "ks-runtime-module-alias-v1"
    local MODULE_EXPORT_EXPIRY_MARGIN_MS = 10000
    local MODULE_ENVELOPE_REQUIRED_FIELDS = { "v", "a", "g", "x", "h", "n", "s" }
    local ALLOWED_FEATURE_PLANE_CAPABILITIES = {
        ["feature_plane.runtime_context"] = true,
        ["feature_plane.exclusive_sync"] = true,
        ["feature_plane.sync_data"] = true,
    }

    local function recordModulePerfStage(moduleRecord, stageName)
        if type(moduleRecord) ~= "table" then
            return
        end
        KSModules.perf[#KSModules.perf + 1] = {
            trace = tostring(moduleRecord.traceId or ""):sub(1, 96),
            module = tostring(moduleRecord.id or ""):sub(1, 96),
            stage = tostring(stageName or ""):sub(1, 48),
            at = math.floor(getMonotonicSeconds() * 1000),
        }
        if #KSModules.perf > 64 then
            table.remove(KSModules.perf, 1)
        end
    end

    local function getOrCreateModuleOwner(moduleId)
        if type(moduleId) ~= "string" or not moduleId:match("^m%d+_") then
            return nil
        end
        local ownerRecord = KSModules.owners[moduleId]
        local moduleGeneration = tonumber(KSModules.generations[moduleId]) or 0
        if type(ownerRecord) ~= "table" or ownerRecord.generation ~= moduleGeneration then
            ownerRecord = { id = moduleId, generation = moduleGeneration, jobs = 0, active = true }
            KSModules.owners[moduleId] = ownerRecord
        end
        return ownerRecord
    end

    local function releaseModuleOwnerJob(moduleOwner)
        if type(moduleOwner) ~= "table" then
            return
        end
        moduleOwner.jobs = math.max(0, (tonumber(moduleOwner.jobs) or 0) - 1)
        if moduleOwner.finishRequested and moduleOwner.jobs == 0 and moduleOwner.active and KSModules.owners[moduleOwner.id] == moduleOwner and type(KSModules.clear) == "function" then
            KSModules.clear(moduleOwner.id, moduleOwner.finishReason or "feature_done")
        end
    end

    local function resolveGrantedModuleCapabilities(requestedCapabilities)
        if type(requestedCapabilities) ~= "table" then
            return nil
        end
        local grantedCapabilities = {}
        local seenCapabilities = {}
        local capabilityCount = 0
        for capabilityKey in pairs(requestedCapabilities) do
            if type(capabilityKey) ~= "number" or capabilityKey < 1 or math.tointeger(capabilityKey) ~= capabilityKey then
                return nil
            end
            capabilityCount = capabilityCount + 1
        end
        if capabilityCount ~= #requestedCapabilities or capabilityCount > 3 then
            return nil
        end
        for _, capabilityId in ipairs(requestedCapabilities) do
            local capabilityRegistration = type(featurePlaneCapabilities) == "table" and featurePlaneCapabilities[capabilityId] or nil
            if type(capabilityId) ~= "string" or ALLOWED_FEATURE_PLANE_CAPABILITIES[capabilityId] ~= true or seenCapabilities[capabilityId] or type(capabilityRegistration) ~= "table" or capabilityRegistration.provider ~= "m2" or tonumber(capabilityRegistration.generation) ~= tonumber(startupProgressState.generation) or capabilityRegistration.active ~= true then
                return nil
            end
            seenCapabilities[capabilityId] = true
            grantedCapabilities[capabilityId] = capabilityRegistration
        end
        return grantedCapabilities
    end

    local function buildModuleSandboxEnv(moduleId)
        if moduleId == "m2" then
            return KS_MODULE_ENV
        end
        local moduleOwner = getOrCreateModuleOwner(moduleId)
        local baseScriptApi = KS_MODULE_ENV.Script
        local scriptProxy = nil
        if moduleOwner and (type(baseScriptApi) == "table" or type(baseScriptApi) == "userdata") then
            local applyScriptProxyMetatable = setmetatable
            local scriptProxyMeta = {
                __index = function(proxyTable, scriptMemberName)
                    if scriptMemberName == "QueueJob" then
                        return function(jobFunction, ...)
                            if type(jobFunction) ~= "function" or not moduleOwner.active then
                                return false
                            end
                            moduleOwner.jobs = moduleOwner.jobs + 1
                            local isJobReleased = false

                            local function releaseJobOnce()
                                if isJobReleased then
                                    return
                                end
                                isJobReleased = true
                                releaseModuleOwnerJob(moduleOwner)
                            end

                            local ownerGeneration = moduleOwner.generation
                            local queueJobExtraArg = ...
                            local queueJobResult = baseScriptApi.QueueJob(function(...)
                                local releaseGuard = setmetatable({}, { __close = releaseJobOnce })
                                if ShouldUnload() or not moduleOwner.active or moduleOwner.generation ~= ownerGeneration or KSModules.owners[moduleId] ~= moduleOwner then
                                    return
                                end
                                local packedJobResults = table.pack(jobFunction(...))
                                if packedJobResults[1] ~= false then
                                    recordModulePerfStage({
                                        id = moduleId,
                                        traceId = type(KSModules.loaded[moduleId]) == "table" and KSModules.loaded[moduleId].trace or "",
                                    }, "effect_reached")
                                end
                                return table.unpack(packedJobResults, 1, packedJobResults.n)
                            end, queueJobExtraArg)
                            if queueJobResult == false then
                                releaseJobOnce()
                            end
                            return queueJobResult
                        end
                    end
                    if scriptMemberName == "RegisterLooped" then
                        return function()
                            return false
                        end
                    end
                    return baseScriptApi[scriptMemberName]
                end,
            }

            function scriptProxyMeta.__newindex()
                error("runtime module Script write denied", 2)
            end

            scriptProxyMeta.__metatable = "locked"
            scriptProxy = applyScriptProxyMetatable({}, scriptProxyMeta)
        end
        local protectedGlobalNames = {
            KSModules = true,
            KS_RUNTIME_MODULE_CONTEXT = true,
            KS_MODULE_ENV = true,
            KS_MODULE_LOAD = true,
            KS_BRIDGE_V3 = true,
            __ks_bridge_v3 = true,
            Curl = true,
            ApiKeyForRequest = true,
            AddApiKeyHeader = true,
            load = true,
            dofile = true,
        }
        local sandboxEnv = {}
        sandboxEnv._G = sandboxEnv
        local applySandboxMetatable = setmetatable
        local sandboxEnvMeta = {
            __index = function(envTable, globalName)
                if globalName == "Script" and scriptProxy then
                    return scriptProxy
                end
                local blockedLookupResult
                if protectedGlobalNames[globalName] ~= true then
                    if type(globalName) ~= "string" then
                        goto forwardToModuleEnv
                    end
                    if not globalName:match("^__a") and not globalName:match("^__r") and not globalName:match("^__m") and not globalName:match("^__c") and not globalName:match("^__ks") then
                        goto forwardToModuleEnv
                    end
                end
                blockedLookupResult = nil
                do
                    return blockedLookupResult
                end
                ::forwardToModuleEnv::
                return KS_MODULE_ENV[globalName]
            end,
        }

        function sandboxEnvMeta.__newindex(targetEnv, globalName, newGlobalValue)
            if protectedGlobalNames[globalName] == true then
                error("runtime module environment write denied", 2)
            end
            KS_MODULE_ENV[globalName] = newGlobalValue
        end

        sandboxEnvMeta.__metatable = "locked"
        return applySandboxMetatable(sandboxEnv, sandboxEnvMeta)
    end

    local function currentEpochMillis()
        return math.floor(os.time() * 1000)
    end

    local function setModuleLastError(moduleId, errorMessage, isHardError)
        local normalizedModuleId = tostring(moduleId or ""):lower()
        if normalizedModuleId == "" then
            normalizedModuleId = "unknown"
        end
        if errorMessage == nil then
            KSModules.lastError[normalizedModuleId] = nil
            KSModules.lastHard[normalizedModuleId] = nil
            return
        end
        KSModules.lastError[normalizedModuleId] = tostring(errorMessage or "unknown")
        KSModules.lastHard[normalizedModuleId] = isHardError == true
    end

    local function getFreshModuleExports(moduleId)
        local normalizedModuleId = tostring(moduleId or ""):lower()
        if normalizedModuleId == "" then
            return nil
        end
        local loadedModule = KSModules.loaded[normalizedModuleId]
        if loadedModule and type(loadedModule.exports) == "table" and tonumber(loadedModule.x or 0) > currentEpochMillis() + MODULE_EXPORT_EXPIRY_MARGIN_MS then
            setModuleLastError(normalizedModuleId, nil)
            return loadedModule.exports
        end
        return nil
    end

    local function flushModuleCallbacks(moduleId, loadResult, loadError)
        local normalizedModuleId = tostring(moduleId or ""):lower()
        local pendingCallbacks = KSModules.callbacks[normalizedModuleId]
        KSModules.callbacks[normalizedModuleId] = nil
        if type(pendingCallbacks) ~= "table" then
            return
        end
        for _, pendingCallback in ipairs(pendingCallbacks) do
            if type(pendingCallback) == "function" then
                pendingCallback(loadResult, loadError)
            end
        end
    end

    local function hasRuntimeScriptToken()
        return type(__a25) == "string"
    end

    local function formatPlainIntegerString(fieldValue)
        if type(fieldValue) == "number" then
            local formatOk, formattedInteger = pcall(string.format, "%.0f", fieldValue)
            if formatOk and type(formattedInteger) == "string" then
                return formattedInteger
            end
        end
        return tostring(fieldValue or "")
    end

    local function buildModuleEnvelopeSignInput(moduleEnvelope)
        return table.concat({
            moduleEnvelopeSignTag,
            tostring(moduleEnvelope.v or ""),
            tostring(moduleEnvelope.a or ""),
            tostring(moduleEnvelope.g or ""),
            formatPlainIntegerString(moduleEnvelope.x),
            tostring(moduleEnvelope.h or ""),
            tostring(moduleEnvelope.n or ""),
            tostring(moduleEnvelope.z or ""),
        }, "|")
    end

    local function deriveModuleIdAlias(moduleId, scriptToken)
        local normalizedModuleId = tostring(moduleId or ""):lower()
        if normalizedModuleId == "" then
            return normalizedModuleId
        end
        if type(scriptToken) ~= "string" or scriptToken == "" or scriptToken == "0" then
            return normalizedModuleId
        end
        if type(__m0) ~= "table" or type(__m0.h) ~= "function" then
            return normalizedModuleId
        end
        local hmacOk, aliasHmacHex = pcall(function()
            return bytesToHex(__m0.h(scriptToken, ("%s|%s"):format(MODULE_ALIAS_HMAC_TAG, normalizedModuleId))):lower()
        end)
        if hmacOk and type(aliasHmacHex) == "string" and #aliasHmacHex >= 32 then
            return "x" .. aliasHmacHex:sub(1, 32)
        end
        return normalizedModuleId
    end

    local function createModuleHostContext(moduleId, extraContext, runtimeCapabilities)
        local hostContext = { v = 1, id = moduleId, KS_RUNTIME_CAPABILITIES = runtimeCapabilities }

        function hostContext.log(logLevel, logMessage)
        end

        function hostContext.report(integrityEventName, isIntegrityViolation)
            if type(reportRuntimeIntegrityEvent) == "function" then
                reportRuntimeIntegrityEvent(("module_%s"):format(tostring(integrityEventName or "integrity")), isIntegrityViolation == true)
            end
        end

        if moduleId == "m1" then
            function hostContext.bridgeRequest(bridgeAction, bridgePayload, requestedTimeoutMs)
                local payloadTypeName
                if bridgeAction ~= "discord.presence" then
                    payloadTypeName = "discord.accounts.scan"
                    if bridgeAction ~= payloadTypeName then
                        goto checkPayloadType
                    end
                end
                payloadTypeName = type(bridgePayload)
                ::checkPayloadType::
                if payloadTypeName ~= "table" then
                    return "invalid"
                end
                local maxTimeoutMs = bridgeAction == "discord.accounts.scan" and 5000 or 2000
                return loaderAdapter.request(bridgeAction, bridgePayload, math.min(maxTimeoutMs, tonumber(requestedTimeoutMs) or maxTimeoutMs))
            end
        end
        if type(extraContext) == "table" then
            for contextFieldName, contextFieldValue in pairs(extraContext) do
                if hostContext[contextFieldName] == nil then
                    hostContext[contextFieldName] = contextFieldValue
                end
            end
        end
        return hostContext
    end

    function KSModules.clear(moduleId, unloadReason)
        local moduleKey = tostring(moduleId or "")
        local loadedModule = KSModules.loaded[moduleKey]
        local unloadHandler = loadedModule and type(loadedModule.exports) == "table" and loadedModule.exports.unload or nil
        local moduleOwner = KSModules.owners[moduleKey]
        if type(moduleOwner) == "table" then
            moduleOwner.active = false
        end
        KSModules.owners[moduleKey] = nil
        KSModules.loaded[moduleKey] = nil
        KSModules.requests[moduleKey] = nil
        KSModules.generations[moduleKey] = (tonumber(KSModules.generations[moduleKey]) or 0) + 1
        KSModules.states[moduleKey] = "idle"
        KSModules.loading[moduleKey] = nil
        KSModules.callbacks[moduleKey] = nil
        KSModules.lastError[moduleKey] = nil
        KSModules.lastHard[moduleKey] = nil
        if type(unloadHandler) == "function" then
            unloadHandler(unloadReason or "clear")
        end
    end

    function KSModules.finishUse(moduleId, finishReason)
        local moduleKey = tostring(moduleId or "")
        local moduleOwner = KSModules.owners[moduleKey]
        if type(moduleOwner) ~= "table" then
            return KSModules.clear(moduleKey, finishReason or "feature_done")
        end
        moduleOwner.finishRequested = true
        moduleOwner.finishReason = finishReason or "feature_done"
        if (tonumber(moduleOwner.jobs) or 0) == 0 then
            KSModules.clear(moduleKey, moduleOwner.finishReason)
        end
    end

    function KSModules.markUse(moduleId, perfStageName)
        local loadedModule = KSModules.loaded[tostring(moduleId or "")]
        recordModulePerfStage({ id = moduleId, traceId = type(loadedModule) == "table" and loadedModule.trace or "" }, perfStageName)
    end

    function KSModules.unloadAll(unloadReason)
        local loadedModuleIds = {}
        for loadedModuleId in pairs(KSModules.loaded) do
            loadedModuleIds[#loadedModuleIds + 1] = loadedModuleId
        end
        table.sort(loadedModuleIds, function(leftModuleId, rightModuleId)
            local leftUnloadRank
            if leftModuleId == "m1" then
                leftUnloadRank = 4
                if leftUnloadRank then
                    goto computeRightUnloadRank
                end
            end
            if leftModuleId == "m2" then
                leftUnloadRank = 3
                if leftUnloadRank then
                    goto computeRightUnloadRank
                end
            end
            if leftModuleId == "m3" then
                leftUnloadRank = 2
                if leftUnloadRank then
                    goto computeRightUnloadRank
                end
            end
            leftUnloadRank = 1
            ::computeRightUnloadRank::
            local rightUnloadRank
            if rightModuleId == "m1" then
                rightUnloadRank = 4
                if rightUnloadRank then
                    goto compareUnloadRanks
                end
            end
            if rightModuleId == "m2" then
                rightUnloadRank = 3
                if rightUnloadRank then
                    goto compareUnloadRanks
                end
            end
            if rightModuleId == "m3" then
                rightUnloadRank = 2
                if rightUnloadRank then
                    goto compareUnloadRanks
                end
            end
            rightUnloadRank = 1
            ::compareUnloadRanks::
            if leftUnloadRank ~= rightUnloadRank then
                return leftUnloadRank < rightUnloadRank
            end
            return leftModuleId < rightModuleId
        end)
        for _, moduleId in ipairs(loadedModuleIds) do
            if moduleId ~= "m2" and moduleId ~= "m1" then
                pcall(KSModules.clear, moduleId, unloadReason or "unload")
            end
        end
        featurePlaneCapabilities = nil
        if KSModules.loaded.m2 then
            KSModules.clear("m2", unloadReason or "unload")
        end
        if KSModules.loaded.m1 then
            KSModules.clear("m1", unloadReason or "unload")
        end
    end

    local function verifySignedModuleEnvelope(expectedModuleId, envelopeJson, signingKey)
        local envelope = nil
        if not pcall(function()
            envelope = json.decode(tostring(envelopeJson or ""))
        end) or type(envelope) ~= "table" then
            return nil, "decode"
        end
        if tonumber(envelope.v or 0) ~= 1 or tostring(envelope.a or "") ~= tostring(expectedModuleId or "") then
            return nil, "shape"
        end
        local encodedPayload = tostring(envelope.z or "")
        local expectedPayloadHash = tostring(envelope.h or ""):lower()
        local envelopeSignature = tostring(envelope.s or ""):lower()
        if encodedPayload == "" or #expectedPayloadHash ~= 64 or #envelopeSignature ~= 64 then
            return nil, "fields"
        end
        local signInput = buildModuleEnvelopeSignInput(envelope)
        local computedSignature = bytesToHex(__m0.h(signingKey, signInput))
        if not __m0.c(envelopeSignature, computedSignature) then
            return nil, "signature"
        end
        local moduleSource = __m0.b(encodedPayload)
        envelope.z = nil
        if type(moduleSource) ~= "string" or moduleSource == "" then
            return nil, "payload"
        end
        local computedPayloadHash = bytesToHex(__m0.s(moduleSource))
        if not __m0.c(computedPayloadHash, expectedPayloadHash) then
            return nil, "hash"
        end
        return envelope, moduleSource
    end

    local MODULE_MAX_FETCH_ATTEMPTS = 4
    local MODULE_RETRY_BASE_DELAY_SEC = 1.0

    local function isModuleRequestTable(moduleRequest)
        return type(moduleRequest) == "table"
    end

    local function noopInvalidModuleRequest(invalidRequest)
    end

    local moduleFailureReportsSent = 0

    local function reportModuleFailure(moduleRequest, failureState, failureReason, isHardFailure, errorMessage)
        if failureState == "retry_wait" or failureReason == "unloading" or moduleRequest.failureReported or moduleFailureReportsSent >= 4 or not loaderAdapter or loaderAdapter.module_failure_reports ~= true then
            return
        end

        local function sanitizeDiagnosticText(rawText, maxLength)
            local rawTextType = type(rawText)
            if rawText == nil then
                return ""
            end
            if rawTextType ~= "string" and rawTextType ~= "number" and rawTextType ~= "boolean" then
                return "<" .. rawTextType .. " error value>"
            end
            return tostring(rawText):gsub("[%c]", " "):gsub("[\x80-\xff]", function(nonAsciiChar)
                return ("\\x%02X"):format(string.byte(nonAsciiChar))
            end):sub(1, maxLength)
        end

        local failureReport = {
            module_id = moduleRequest.id,
            stage = moduleRequest.diagnosticStage or moduleRequest.state,
            state = failureState,
        }
        local sanitizedReason = sanitizeDiagnosticText(failureReason or failureState, 96):gsub("[^%w_.:-]", "_")
        failureReport.reason = sanitizedReason
        local sanitizedErrorText = sanitizeDiagnosticText(errorMessage, 384)
        failureReport.error_text = sanitizedErrorText
        local artifactGenerationText = sanitizeDiagnosticText(moduleRequest.artifactGeneration, 64)
        failureReport.artifact_generation = artifactGenerationText
        failureReport.request_generation = moduleRequest.generation
        local attemptNumber = math.max(1, moduleRequest.attempt or 1)
        failureReport.attempt = attemptNumber
        failureReport.hard = isHardFailure == true
        local reportLoadGeneration = loaderAdapter.load_generation
        moduleRequest.failureReported = true
        moduleFailureReportsSent = moduleFailureReportsSent + 1
        Script.QueueJob(function()
            pcall(function()
                if loaderAdapter.load_generation ~= reportLoadGeneration then
                    return
                end
                local requestStatus, responsePayload = loaderAdapter.request("module.failure", failureReport, 2500)
                failureReport = nil
                local failureReference = requestStatus == "ok" and type(responsePayload) == "table" and responsePayload.reference or nil
                if type(failureReference) == "string" then
                    if #failureReference == 38 and failureReference:match("^KS%-MF%-[a-f0-9]+$") then
                        Logger.LogError("K-Script: failure reference " .. failureReference)
                    end
                else
                    Logger.LogError("K-Script: diagnostic report unavailable.")
                end
            end)
        end)
    end

    local function reportModuleFailureSafe(moduleRequest, failureState, failureReason, isHardFailure, errorText)
        pcall(reportModuleFailure, moduleRequest, failureState, failureReason, isHardFailure, errorText)
    end

    local function newModuleExceptionGuard(moduleRequest)
        return setmetatable({ req = moduleRequest }, {
            __close = function(exceptionGuard, closeError)
                if closeError ~= nil and isModuleRequestTable(exceptionGuard.req) then
                    reportModuleFailureSafe(exceptionGuard.req, "exception", "lua_error", false, closeError)
                end
            end,
        })
    end

    local function finalizeModuleRequest(moduleRequest, finalState, failureReason, moduleExports, isHardFailure, errorText)
        if not isModuleRequestTable(moduleRequest) then
            return false
        end
        moduleRequest.diagnosticStage = moduleRequest.diagnosticStage or moduleRequest.state
        moduleRequest.state = finalState
        KSModules.states[moduleRequest.id] = finalState
        KSModules.requests[moduleRequest.id] = nil
        if KSModules.loading[moduleRequest.id] == moduleRequest.generation then
            KSModules.loading[moduleRequest.id] = nil
        end
        if finalState ~= "success" then
            reportModuleFailureSafe(moduleRequest, finalState, failureReason, isHardFailure, errorText)
        end
        if finalState == "success" then
            setModuleLastError(moduleRequest.id, nil)
        else
            setModuleLastError(moduleRequest.id, failureReason or finalState, isHardFailure == true)
        end
        if isHardFailure == true and not moduleRequest.cleanupDone and type(reportRuntimeIntegrityEvent) == "function" then
            moduleRequest.cleanupDone = true
            pcall(reportRuntimeIntegrityEvent, ("module_%s_%s"):format(moduleRequest.id, tostring(failureReason or finalState)), true)
        end
        flushModuleCallbacks(moduleRequest.id, moduleExports, failureReason)
        return true
    end

    local function scheduleModuleRetry(moduleRequest, retryReason)
        if not isModuleRequestTable(moduleRequest) then
            return false
        end
        moduleRequest.curl = nil
        moduleRequest.responseBody = nil
        if moduleRequest.attempt >= MODULE_MAX_FETCH_ATTEMPTS then
            return finalizeModuleRequest(moduleRequest, "retry_exhausted", retryReason or "retry_exhausted", nil, false)
        end
        reportModuleFailureSafe(moduleRequest, "retry_wait", retryReason, false)
        moduleRequest.state = "retry_wait"
        KSModules.states[moduleRequest.id] = "retry_wait"
        moduleRequest.nextAttemptAt = getMonotonicSeconds() + MODULE_RETRY_BASE_DELAY_SEC * 2 ^ math.max(0, moduleRequest.attempt - 1)
        return true
    end

    local function dispatchModuleRequest(moduleRequest)
        if not isModuleRequestTable(moduleRequest) then
            return noopInvalidModuleRequest(moduleRequest)
        end
        local exceptionGuard = newModuleExceptionGuard(moduleRequest)
        if ShouldUnload() then
            return finalizeModuleRequest(moduleRequest, "fatal_failed", "unloading", nil, false)
        end
        moduleRequest.diagnosticStage = "dispatch"
        if loaderAdapter then
            moduleRequest.diagnosticStage = "bridge_request"
            recordModulePerfStage(moduleRequest, "bridge_request")
            local gameEdition = isGameVersionEnhanced and "enhanced" or "legacy"
            local bridgeStatus, moduleResponse, bridgeErrorCode
            if moduleRequest.batchReady then
                bridgeErrorCode = moduleRequest.batchCode
                moduleResponse = moduleRequest.batchData
                bridgeStatus = moduleRequest.batchStatus
                moduleRequest.batchCode = nil
                moduleRequest.batchData = nil
                moduleRequest.batchStatus = nil
                moduleRequest.batchReady = nil
            else
                bridgeStatus, moduleResponse, bridgeErrorCode = loaderAdapter.request("module.get", {
                    module_id = moduleRequest.id,
                    build = gameEdition,
                    edition = gameEdition,
                    delivery_trace_id = moduleRequest.traceId,
                }, 35000)
            end
            if not isModuleRequestTable(moduleRequest) then
                return noopInvalidModuleRequest(moduleRequest)
            end
            moduleRequest.diagnosticStage = "bridge_response"
            recordModulePerfStage(moduleRequest, "bridge_response")
            if bridgeStatus == "timeout" or bridgeStatus == "unavailable" then
                return scheduleModuleRetry(moduleRequest, tostring(bridgeErrorCode or "module_temporarily_unavailable"))
            end
            if bridgeStatus ~= "ok" or type(moduleResponse) ~= "table" or type(moduleResponse.source_b64) ~= "string" then
                return finalizeModuleRequest(moduleRequest, bridgeStatus == "denied" and "denied" or "fatal_failed", tostring(bridgeErrorCode or "module_unavailable"), nil, false)
            end
            if tostring(moduleResponse.delivery_trace_id or "") ~= tostring(moduleRequest.traceId or "") then
                return finalizeModuleRequest(moduleRequest, "fatal_failed", "delivery_trace_mismatch", nil, true)
            end
            local nowSeconds = getMonotonicSeconds()
            moduleRequest.deadline = nowSeconds + 60
            moduleRequest.artifactGeneration = moduleResponse.generation
            moduleRequest.diagnosticStage = "capabilities"
            local grantedCapabilities = resolveGrantedModuleCapabilities(moduleResponse.capabilities)
            moduleResponse.capabilities = nil
            if type(grantedCapabilities) ~= "table" then
                return finalizeModuleRequest(moduleRequest, "fatal_failed", "capability_contract", nil, true)
            end
            moduleRequest.diagnosticStage = "payload_decode"
            local moduleSource = __m0.b(moduleResponse.source_b64)
            moduleResponse.source_b64 = nil
            if type(moduleSource) ~= "string" or moduleSource == "" then
                return finalizeModuleRequest(moduleRequest, "fatal_failed", "payload", nil, false)
            end
            moduleRequest.diagnosticStage = "load"
            recordModulePerfStage(moduleRequest, "load")
            local moduleChunk, loadError = KS_MODULE_LOAD(moduleSource, ("@ks:%s:%s"):format(moduleRequest.id, tostring(moduleResponse.generation or "")), "bt", buildModuleSandboxEnv(moduleRequest.id))
            if type(moduleChunk) ~= "function" then
                return finalizeModuleRequest(moduleRequest, "fatal_failed", "load", nil, false, loadError)
            end
            moduleRequest.diagnosticStage = "chunk"
            local chunkRunOk, chunkResult = pcall(moduleChunk)
            if not chunkRunOk then
                return finalizeModuleRequest(moduleRequest, "fatal_failed", "chunk", nil, false, chunkResult)
            end
            local moduleExports = chunkResult
            if type(chunkResult) == "function" then
                moduleRequest.diagnosticStage = "factory_context"
                recordModulePerfStage(moduleRequest, "factory")
                local hostContext = createModuleHostContext(moduleRequest.id, moduleRequest.context, grantedCapabilities)
                if moduleRequest.nativeHostFactory then
                    moduleRequest.diagnosticStage = "native_factory"
                    moduleExports = chunkResult(hostContext)
                else
                    moduleRequest.diagnosticStage = "factory"
                    local factoryOk, factoryResult = pcall(chunkResult, hostContext)
                    if not factoryOk then
                        return finalizeModuleRequest(moduleRequest, "fatal_failed", "factory", nil, false, factoryResult)
                    end
                    moduleExports = factoryResult
                end
            end
            moduleRequest.diagnosticStage = "exports"
            if type(moduleExports) ~= "table" then
                return finalizeModuleRequest(moduleRequest, "fatal_failed", "exports", nil, false, "expected table; received " .. type(moduleExports))
            end
            KSModules.loaded[moduleRequest.id] = {
                exports = moduleExports,
                g = tostring(moduleResponse.generation or ""),
                x = tonumber(moduleResponse.expires_at_ms or 0) or 0,
                h = tostring(moduleResponse.sha256 or ""),
                trace = moduleRequest.traceId,
            }
            return finalizeModuleRequest(moduleRequest, "success", nil, moduleExports, false)
        end
        if not hasRuntimeScriptToken() then
            return scheduleModuleRetry(moduleRequest, "runtime_keys")
        end
        local authRequestName = "RuntimeModule"
        if type(KS_GetAuthRequestName) == "function" then
            local nameLookupOk, resolvedRequestName = pcall(KS_GetAuthRequestName, "RuntimeModule")
            if nameLookupOk and tostring(resolvedRequestName or "") ~= "" then
                authRequestName = tostring(resolvedRequestName)
            end
        end
        local apiKey, apiKeyGeneration = ApiKeyForRequest("RuntimeModule", authRequestName, 30000)
        if not isModuleRequestTable(moduleRequest) then
            return noopInvalidModuleRequest(moduleRequest)
        end
        if not apiKey then
            return scheduleModuleRetry(moduleRequest, "api_key")
        end
        local scriptToken = tostring(__a25 or "")
        local isAuthValid, authError = validateRequestAuth("runtimeModule", { apiKey = apiKey, scriptToken = scriptToken })
        if not isAuthValid then
            return finalizeModuleRequest(moduleRequest, "fatal_failed", tostring(authError or "auth"), nil, true)
        end
        moduleRequest.scriptToken = scriptToken
        local dispatchOk, dispatchedCurl = pcall(function()
            local requestBody = json.encode({
                m = deriveModuleIdAlias(moduleRequest.id, scriptToken),
                b = tostring(KS_CLIENT_BUILD or ""),
                e = isGameVersionEnhanced and 1 or 0,
            })
            local curlHandle = Curl.Easy()
            curlHandle:Setopt(eCurlOption.CURLOPT_URL, runtimeModuleRequestUrl)
            curlHandle:Setopt(eCurlOption.CURLOPT_POST, 1)
            curlHandle:Setopt(eCurlOption.CURLOPT_POSTFIELDS, requestBody)
            local setCurlOption = curlHandle.Setopt
            local userAgentOption = eCurlOption.CURLOPT_USERAGENT
            local userAgent = ks_uid_user_agent()
            setCurlOption(curlHandle, userAgentOption, userAgent)
            curlHandle:AddHeader("Content-Type: application/json")
            AddApiKeyHeader(curlHandle, apiKey)
            curlHandle:AddHeader("X-C-20: " .. scriptToken)
            if type(sessionHeaderToken) == "string" and sessionHeaderToken ~= "" and sessionHeaderToken ~= "0" then
                curlHandle:AddHeader("X-C-22: " .. sessionHeaderToken)
            end
            curlHandle:DisableErrorLog()
            curlHandle:Perform()
            return curlHandle
        end)
        if not isModuleRequestTable(moduleRequest) then
            return noopInvalidModuleRequest(moduleRequest)
        end
        if not dispatchOk then
            return scheduleModuleRetry(moduleRequest, "dispatch")
        end
        moduleRequest.apiKeyGeneration = apiKeyGeneration
        moduleRequest.curl = dispatchedCurl
        moduleRequest.state = "in_flight"
        KSModules.states[moduleRequest.id] = "in_flight"
    end

    local function dispatchModuleRequestBatch(moduleRequests)
        if type(moduleRequests) ~= "table" or #moduleRequests < 2 then
            if type(moduleRequests) == "table" and moduleRequests[1] then
                return dispatchModuleRequest(moduleRequests[1])
            end
            return false
        end
        local moduleIds = {}
        local validRequests = {}
        for _, candidateRequest in ipairs(moduleRequests) do
            if isModuleRequestTable(candidateRequest) then
                moduleIds[#moduleIds + 1] = candidateRequest.id
                validRequests[#validRequests + 1] = candidateRequest
            end
        end
        if #validRequests < 2 then
            for _, unbatchedRequest in ipairs(validRequests) do
                dispatchModuleRequest(unbatchedRequest)
            end
            return true
        end
        local gameEdition = isGameVersionEnhanced and "enhanced" or "legacy"
        local batchTraceId = tostring(validRequests[1].traceId or "") .. "-batch"
        local batchStatus, batchResponse, batchErrorCode = loaderAdapter.request("module.batch.get", {
            module_ids = moduleIds,
            build = gameEdition,
            edition = gameEdition,
            delivery_trace_id = batchTraceId,
        }, 35000)
        local resultsByModuleId = {}
        if batchStatus == "ok" then
            if type(batchResponse) == "table" and tostring(batchResponse.delivery_trace_id or "") == batchTraceId and type(batchResponse.modules) == "table" then
                for _, batchEntry in ipairs(batchResponse.modules) do
                    if type(batchEntry) == "table" and type(batchEntry.module_id) == "string" then
                        resultsByModuleId[batchEntry.module_id] = batchEntry
                    end
                end
            end
        elseif batchStatus == "ok" then
            batchErrorCode = "invalid_batch_response"
            batchStatus = "error"
        end
        for _, batchedRequest in ipairs(validRequests) do
            local moduleResult = resultsByModuleId[batchedRequest.id]
            batchedRequest.batchReady = true
            batchedRequest.batchStatus = moduleResult and tostring(moduleResult.status or "unavailable") or batchStatus
            local resultCode
            if moduleResult then
                local stringifyCode = tostring
                local rawResultCode = batchErrorCode or moduleResult.code
                if not rawResultCode and not batchErrorCode then
                    rawResultCode = "module_unavailable"
                end
                resultCode = stringifyCode(rawResultCode)
                if resultCode then
                    goto storeBatchResult
                end
            end
            resultCode = batchErrorCode
            ::storeBatchResult::
            batchedRequest.batchCode = resultCode
            batchedRequest.batchData = moduleResult
            if type(moduleResult) == "table" then
                moduleResult.delivery_trace_id = batchedRequest.traceId
            end
            dispatchModuleRequest(batchedRequest)
        end
        return true
    end

    local function processRuntimeModuleResponse(moduleRequest)
        if not isModuleRequestTable(moduleRequest) then
            return noopInvalidModuleRequest(moduleRequest)
        end
        local exceptionGuard = newModuleExceptionGuard(moduleRequest)
        local responseCode = moduleRequest.responseCode
        local responseBody = tostring(moduleRequest.responseBody or "")
        moduleRequest.responseBody = nil
        if responseCode ~= eCurlCode.CURLE_OK or responseBody == "" or ResponseHasErrorMarker(responseBody) then
            if IsApiKeyFailureResponse(responseBody) and type(SetApiKeyValue) == "function" then
                pcall(SetApiKeyValue, "0", "RuntimeModule")
            end
            return scheduleModuleRetry(moduleRequest, "fetch")
        end
        moduleRequest.diagnosticStage = "verify_response"
        local moduleEnvelope, modulePayloadOrReason = verifySignedModuleEnvelope(moduleRequest.id, responseBody, moduleRequest.scriptToken)
        if not moduleEnvelope then
            return finalizeModuleRequest(moduleRequest, "fatal_failed", "verify_" .. tostring(modulePayloadOrReason), nil, modulePayloadOrReason == "signature" or modulePayloadOrReason == "hash")
        end
        if not isModuleRequestTable(moduleRequest) then
            return noopInvalidModuleRequest(moduleRequest)
        end
        moduleRequest.state = "validating"
        KSModules.states[moduleRequest.id] = "validating"
        moduleRequest.diagnosticStage = "metadata"
        local hasRequiredEnvelopeFields, envelopeFieldError = validateResponseFields("runtimeModule", moduleEnvelope, MODULE_ENVELOPE_REQUIRED_FIELDS)
        if not hasRequiredEnvelopeFields then
            return finalizeModuleRequest(moduleRequest, "fatal_failed", tostring(envelopeFieldError or "shape"), nil, false)
        end
        if not isModuleRequestTable(moduleRequest) then
            return noopInvalidModuleRequest(moduleRequest)
        end
        moduleRequest.state = "executing"
        KSModules.states[moduleRequest.id] = "executing"
        moduleRequest.artifactGeneration = moduleEnvelope.g
        moduleRequest.diagnosticStage = "load"
        local moduleChunk, chunkLoadError = KS_MODULE_LOAD(modulePayloadOrReason, ("@ks:%s:%s"):format(moduleRequest.id, tostring(moduleEnvelope.g or "")), "bt", buildModuleSandboxEnv(moduleRequest.id))
        if not isModuleRequestTable(moduleRequest) then
            return noopInvalidModuleRequest(moduleRequest)
        end
        if type(moduleChunk) ~= "function" then
            return finalizeModuleRequest(moduleRequest, "fatal_failed", "load", nil, false, chunkLoadError)
        end
        moduleRequest.diagnosticStage = "chunk"
        local chunkRunOk, chunkResult = pcall(moduleChunk)
        if not isModuleRequestTable(moduleRequest) then
            return noopInvalidModuleRequest(moduleRequest)
        end
        if not chunkRunOk then
            return finalizeModuleRequest(moduleRequest, "fatal_failed", "chunk", nil, false, chunkResult)
        end
        local moduleExports = chunkResult
        if type(chunkResult) == "function" then
            moduleRequest.diagnosticStage = "factory_context"
            local moduleHostContext = createModuleHostContext(moduleRequest.id, moduleRequest.context)
            local factoryOk = true
            local factoryResult
            if moduleRequest.nativeHostFactory then
                moduleRequest.diagnosticStage = "native_factory"
                factoryResult = chunkResult(moduleHostContext)
            else
                moduleRequest.diagnosticStage = "factory"
                factoryOk, factoryResult = pcall(chunkResult, moduleHostContext)
            end
            if not isModuleRequestTable(moduleRequest) then
                return noopInvalidModuleRequest(moduleRequest)
            end
            if not factoryOk then
                return finalizeModuleRequest(moduleRequest, "fatal_failed", "factory", nil, false, factoryResult)
            end
            moduleExports = factoryResult
        end
        moduleRequest.diagnosticStage = "exports"
        if type(moduleExports) ~= "table" then
            return finalizeModuleRequest(moduleRequest, "fatal_failed", "exports", nil, false, "expected table; received " .. type(moduleExports))
        end
        if not isModuleRequestTable(moduleRequest) then
            return noopInvalidModuleRequest(moduleRequest)
        end
        KSModules.loaded[moduleRequest.id] = {
            exports = moduleExports,
            g = tostring(moduleEnvelope.g or ""),
            x = tonumber(moduleEnvelope.x or 0) or 0,
            h = tostring(moduleEnvelope.h or ""),
            trace = moduleRequest.traceId,
        }
        return finalizeModuleRequest(moduleRequest, "success", nil, moduleExports, false)
    end

    local function readRuntimeModuleCurlResponse(moduleRequest)
        if not isModuleRequestTable(moduleRequest) then
            return noopInvalidModuleRequest(moduleRequest)
        end
        local curlHandle = moduleRequest.curl
        if not curlHandle then
            return scheduleModuleRetry(moduleRequest, "response_missing")
        end
        local getResponseOk, responseCode, responseBody = pcall(curlHandle.GetResponse, curlHandle)
        moduleRequest.curl = nil
        if not isModuleRequestTable(moduleRequest) then
            return noopInvalidModuleRequest(moduleRequest)
        end
        if not getResponseOk then
            return scheduleModuleRetry(moduleRequest, "response")
        end
        moduleRequest.responseCode = responseCode
        moduleRequest.responseBody = responseBody
        moduleRequest.state = "response_received"
        KSModules.states[moduleRequest.id] = "response_received"
    end

    local function pumpRuntimeModuleRequests()
        local nowSeconds = getMonotonicSeconds()
        local requestsToDispatch = {}
        for moduleId, moduleRequest in pairs(KSModules.requests) do
            if not isModuleRequestTable(moduleRequest) then
            elseif moduleRequest.state == "queued" then
                moduleRequest.attempt = moduleRequest.attempt + 1
                moduleRequest.state = "dispatching"
                KSModules.states[moduleId] = "queued"
                local requestTimeoutSeconds = getRequestTimeoutSeconds("runtimeModule", 30)
                moduleRequest.deadline = nowSeconds + requestTimeoutSeconds
                recordModulePerfStage(moduleRequest, "queued")
                if loaderAdapter then
                    requestsToDispatch[#requestsToDispatch + 1] = moduleRequest
                elseif Script.QueueJob(function()
                    dispatchModuleRequest(moduleRequest)
                end) == false then
                    scheduleModuleRetry(moduleRequest, "queue")
                end
            elseif moduleRequest.state ~= "dispatching" and moduleRequest.state ~= "in_flight" and moduleRequest.state ~= "response_processing" and moduleRequest.state ~= "parsing" and moduleRequest.state ~= "validating" and moduleRequest.state ~= "executing" then
                if moduleRequest.state == "in_flight" then
                    if moduleRequest.curl then
                        local finishedPollOk, isTransferFinished = pcall(moduleRequest.curl.GetFinished, moduleRequest.curl)
                        if not finishedPollOk then
                            finalizeModuleRequest(moduleRequest, "fatal_failed", "callback", nil, false)
                        elseif isTransferFinished then
                            moduleRequest.state = "response_processing"
                            KSModules.states[moduleId] = "response_processing"
                            if Script.QueueJob(function()
                                readRuntimeModuleCurlResponse(moduleRequest)
                            end) == false then
                                scheduleModuleRetry(moduleRequest, "response_queue")
                            end
                        end
                    end
                elseif moduleRequest.state == "response_received" then
                    moduleRequest.state = "parsing"
                    KSModules.states[moduleId] = "parsing"
                    if Script.QueueJob(function()
                        processRuntimeModuleResponse(moduleRequest)
                    end) == false then
                        scheduleModuleRetry(moduleRequest, "parse_queue")
                    end
                elseif moduleRequest.state == "retry_wait" then
                    if nowSeconds >= (moduleRequest.nextAttemptAt or nowSeconds) then
                        moduleRequest.state = "queued"
                        KSModules.states[moduleId] = "queued"
                    end
                end
            elseif nowSeconds >= (moduleRequest.deadline or nowSeconds) then
                finalizeModuleRequest(moduleRequest, "timeout_failed", "timeout", nil, false)
            elseif moduleRequest.state == "in_flight" then
                if moduleRequest.curl then
                    local activePollOk, isActiveTransferFinished = pcall(moduleRequest.curl.GetFinished, moduleRequest.curl)
                    if not activePollOk then
                        finalizeModuleRequest(moduleRequest, "fatal_failed", "callback", nil, false)
                    elseif isActiveTransferFinished then
                        moduleRequest.state = "response_processing"
                        KSModules.states[moduleId] = "response_processing"
                        if Script.QueueJob(function()
                            readRuntimeModuleCurlResponse(moduleRequest)
                        end) == false then
                            scheduleModuleRetry(moduleRequest, "response_queue")
                        end
                    end
                end
            elseif moduleRequest.state == "response_received" then
                moduleRequest.state = "parsing"
                KSModules.states[moduleId] = "parsing"
                if Script.QueueJob(function()
                    processRuntimeModuleResponse(moduleRequest)
                end) == false then
                    scheduleModuleRetry(moduleRequest, "parse_queue")
                end
            elseif moduleRequest.state == "retry_wait" then
                if nowSeconds >= (moduleRequest.nextAttemptAt or nowSeconds) then
                    moduleRequest.state = "queued"
                    KSModules.states[moduleId] = "queued"
                end
            end
        end
        if #requestsToDispatch > 0 and Script.QueueJob(function()
            if #requestsToDispatch > 1 then
                dispatchModuleRequestBatch(requestsToDispatch)
            else
                dispatchModuleRequest(requestsToDispatch[1])
            end
        end) == false then
            for _, batchedRequest in ipairs(requestsToDispatch) do
                scheduleModuleRetry(batchedRequest, "queue")
            end
        end
    end

    function KSModules.ensure(rawModuleId, shouldForceReload, hostContext)
        local moduleId = tostring(rawModuleId or ""):lower()
        if not shouldForceReload then
            local cachedExports = getFreshModuleExports(moduleId)
            if cachedExports then
                return cachedExports
            end
        end
        KSModules.ensureAsync(moduleId, shouldForceReload == true, hostContext)
        return nil
    end

    function KSModules.ensureBlocking(rawModuleId, shouldForceReload, hostContext)
        return KSModules.ensure(rawModuleId, shouldForceReload, hostContext)
    end

    function KSModules.ensureAsync(rawModuleId, shouldForceReload, hostContext, onLoadFinished)
        local moduleId = tostring(rawModuleId or ""):lower()
        if moduleId == "" then
            if type(onLoadFinished) == "function" then
                onLoadFinished(nil, "invalid_id")
            end
            return false
        end
        if shouldForceReload == true then
            local loadedEntry = KSModules.loaded[moduleId]
            if loadedEntry and type(loadedEntry.exports) == "table" and type(loadedEntry.exports.unload) == "function" then
                pcall(loadedEntry.exports.unload, "forced_reload")
            end
            KSModules.loaded[moduleId] = nil
        end
        if not shouldForceReload then
            local cachedExports = getFreshModuleExports(moduleId)
            if cachedExports then
                if type(onLoadFinished) == "function" then
                    onLoadFinished(cachedExports, nil)
                end
                return true
            end
        end
        if shouldForceReload == true then
            if not KSModules.requests[moduleId] and not KSModules.loading[moduleId] then
                if not KSModules.requests[moduleId] and not KSModules.loading[moduleId] then
                    goto queueNewRequest
                end
                if type(onLoadFinished) == "function" then
                    KSModules.callbacks[moduleId] = KSModules.callbacks[moduleId] or {}
                    table.insert(KSModules.callbacks[moduleId], onLoadFinished)
                end
                return true
            end
            KSModules.requests[moduleId] = nil
            KSModules.loading[moduleId] = nil
            KSModules.callbacks[moduleId] = {}
        elseif KSModules.requests[moduleId] or KSModules.loading[moduleId] then
            if type(onLoadFinished) == "function" then
                KSModules.callbacks[moduleId] = KSModules.callbacks[moduleId] or {}
                table.insert(KSModules.callbacks[moduleId], onLoadFinished)
            end
            return true
        end
        ::queueNewRequest::
        if type(onLoadFinished) == "function" then
            KSModules.callbacks[moduleId] = KSModules.callbacks[moduleId] or {}
            table.insert(KSModules.callbacks[moduleId], onLoadFinished)
        end
        local nextGeneration = (tonumber(KSModules.generations[moduleId]) or 0) + 1
        KSModules.generations[moduleId] = nextGeneration
        KSModules.perfSequence = KSModules.perfSequence + 1
        local newRequest = {
            id = moduleId,
            generation = nextGeneration,
            state = "queued",
            attempt = 0,
            force = shouldForceReload == true,
            context = hostContext,
            nativeHostFactory = type(hostContext) == "table",
            traceId = ("m-%s-%s-%s"):format(tostring(loaderAdapter and loaderAdapter.load_generation or 0), tostring(nextGeneration), tostring(KSModules.perfSequence)),
        }
        KSModules.requests[moduleId] = newRequest
        KSModules.loading[moduleId] = nextGeneration
        KSModules.states[moduleId] = "queued"
        recordModulePerfStage(newRequest, "activated")
        setModuleLastError(moduleId, nil)
        return true
    end

    if isTableOrUserdata(Script) and type(Script.RegisterLooped) == "function" then
        Script.RegisterLooped(pumpRuntimeModuleRequests)
    end

    function KSModules.dispatch(moduleId, exportName, ...)
        local moduleExports = getFreshModuleExports(moduleId)
        if not moduleExports then
            KSModules.ensureAsync(moduleId)
            return nil
        end
        local exportedFunction = type(moduleExports) == "table" and moduleExports[exportName] or nil
        if type(exportedFunction) ~= "function" then
            return nil
        end
        local firstArgument = ...
        return exportedFunction(firstArgument)
    end

    KS_RUNTIME_PLAYER_FEATURE_MODULE = "m3"
    KS_RUNTIME_GLOBAL_FEATURE_MODULE = "m4"
end
local featureActionLogState, loadPlayerNotes, resolveAndCacheSocialClubName, runHardwareIdCheck
do
    featureActionLogState = {
        accepting = false,
        pending = 0,
        maxPending = 24,
        recent = {},
        toggleState = {},
        overflowPending = false,
        overflowQueued = false,
    }

    local function slugifyLogIdentifier(rawLabel)
        local normalizedSlug = tostring(rawLabel or ""):lower():gsub("[^a-z0-9_]", "_"):gsub("_+", "_"):gsub("^_+", ""):gsub("_+$", ""):sub(1, 64)
        if normalizedSlug:match("^[a-z][a-z0-9_]+$") then
            return normalizedSlug
        end
        return nil
    end

    local function sanitizeActionLogLabel(labelText)
        if type(labelText) ~= "string" then
            return nil
        end
        local cleanedLabel = labelText:gsub("[%c`]", " "):gsub("%s+", " "):match("^%s*(.-)%s*$")
        if #cleanedLabel < 1 or #cleanedLabel > 120 or cleanedLabel:find("@everyone", 1, true) or cleanedLabel:find("@here", 1, true) then
            return nil
        end
        return cleanedLabel
    end

    local function resolveFeatureDisplayName(featureId, providedName, featureHash)
        local displayName = sanitizeActionLogLabel(providedName)
        if displayName then
            return displayName
        end
        if type(registeredFeatures) == "table" and type(registeredFeatures.hashAndName) == "table" then
            if featureHash ~= nil then
                displayName = sanitizeActionLogLabel(registeredFeatures.hashAndName[featureHash])
            end
            if not displayName and type(Utils) == "table" and type(Utils.Joaat) == "function" then
                local featureIdHash = Utils.Joaat(tostring(featureId or ""))
                displayName = sanitizeActionLogLabel(registeredFeatures.hashAndName[featureIdHash])
            end
        end
        return displayName
    end

    function LogFeatureAction(actionId, actionDetails)
        if not featureActionLogState.accepting or not loaderAdapter or not isRuntimeGenerationCurrent() or ShouldUnload() then
            return false
        end
        actionId = slugifyLogIdentifier(actionId)
        if type(actionDetails) ~= "table" or not actionDetails then
            actionDetails = {}
        end
        local featureId = slugifyLogIdentifier(actionDetails.feature_id)
        local featureName = sanitizeActionLogLabel(actionDetails.feature_name)
        local moduleId = slugifyLogIdentifier(actionDetails.module_id)
        local actionSource = tostring(actionDetails.source or "runtime_module"):lower()
        local wasQueued
        if actionId and featureId and moduleId then
            if actionSource == "main_payload" then
                goto buildActionMetadata
            end
            if actionSource == "runtime_module" then
                goto buildActionMetadata
            end
            if actionSource == "batch_runtime_module" then
                goto buildActionMetadata
            end
        end
        wasQueued = false
        do
            return wasQueued
        end
        ::buildActionMetadata::
        local actionMetadata = {}
        local allowedMetadataKeys = {
            target_scope = true,
            state = true,
            option_kind = true,
            old_category = true,
            new_category = true,
            result = true,
            target_id = true,
            target_label = true,
            target_count = true,
            feature_mode = true,
            action_attempt_id = true,
            legacy_channel = true,
            legacy_action_line = true,
        }
        local metadataFieldCount = 0
        for metadataKey, rawMetadataValue in pairs(actionDetails) do
            if allowedMetadataKeys[metadataKey] then
                local sanitizedMetadataValue
                if metadataKey == "legacy_action_line" then
                    if type(rawMetadataValue) ~= "string" then
                        return false
                    end
                    sanitizedMetadataValue = rawMetadataValue:gsub("[%c`]", " "):gsub("%s+", " "):match("^%s*(.-)%s*$")
                    local isActionLineRejected = #sanitizedMetadataValue
                    if not (isActionLineRejected < 6) then
                        isActionLineRejected = #sanitizedMetadataValue
                        if not (isActionLineRejected > 1500) then
                            isActionLineRejected = sanitizedMetadataValue:find("@everyone", 1, true) or sanitizedMetadataValue:find("@here", 1, true)
                        end
                    end
                    if isActionLineRejected then
                        return false
                    end
                else
                    if metadataKey == "target_id" or metadataKey == "action_attempt_id" then
                        sanitizedMetadataValue = tostring(rawMetadataValue or ""):match("^(%d+)$")
                        if sanitizedMetadataValue and not (#sanitizedMetadataValue > 20) then
                            if not (#sanitizedMetadataValue > 1) then
                                goto storeMetadataField
                            end
                            if sanitizedMetadataValue:sub(1, 1) ~= "0" then
                                goto storeMetadataField
                            end
                        end
                        local isNumericIdValid = false
                        do
                            return isNumericIdValid
                        end
                        goto storeMetadataField
                    end
                    if metadataKey == "target_label" then
                        sanitizedMetadataValue = sanitizeActionLogLabel(rawMetadataValue)
                        if not sanitizedMetadataValue then
                            return false
                        end
                    elseif metadataKey == "target_count" then
                        local parsedTargetCount = tonumber(rawMetadataValue)
                        if not parsedTargetCount or parsedTargetCount < 1 or parsedTargetCount > 32 or parsedTargetCount ~= math.floor(parsedTargetCount) then
                            return false
                        end
                        sanitizedMetadataValue = tostring(parsedTargetCount)
                    else
                        sanitizedMetadataValue = slugifyLogIdentifier(rawMetadataValue)
                        if not sanitizedMetadataValue then
                            return false
                        end
                    end
                end
                ::storeMetadataField::
                metadataFieldCount = metadataFieldCount + 1
                if metadataFieldCount > 12 then
                    return false
                end
                actionMetadata[metadataKey] = sanitizedMetadataValue
            end
        end
        local moduleFeatureKey = moduleId .. ":" .. featureId
        if actionId == "feature_toggle_enabled" or actionId == "feature_toggle_disabled" then
            if featureActionLogState.toggleState[moduleFeatureKey] == actionId then
                return true
            end
            featureActionLogState.toggleState[moduleFeatureKey] = actionId
        end
        if actionId ~= "removal_action_completed" then
            local nowClockSeconds = os.clock()
            local recentActionKey = actionId .. ":" .. moduleFeatureKey .. ":" .. tostring(actionMetadata.target_id or actionMetadata.legacy_action_line or actionMetadata.state or actionMetadata.result or "")
            if nowClockSeconds - (tonumber(featureActionLogState.recent[recentActionKey]) or -100) < 0.5 then
                return true
            end
            featureActionLogState.recent[recentActionKey] = nowClockSeconds
        end
        if featureActionLogState.pending >= featureActionLogState.maxPending then
            featureActionLogState.overflowPending = true
            return false
        end
        local actionRequestPayload = {
            schema_version = 1,
            action_id = actionId,
            feature_id = featureId,
            feature_name = featureName,
            module_id = moduleId,
            source = actionSource,
            edition = isGameVersionEnhanced and "enhanced" or "legacy",
            metadata = actionMetadata,
        }
        local occurredAtSeconds = os.time()
        actionRequestPayload.occurred_at_ms = occurredAtSeconds * 1000
        featureActionLogState.pending = featureActionLogState.pending + 1
        if Script.QueueJob(function()
            pcall(function()
                loaderAdapter.request("feature.action", actionRequestPayload, 5000)
            end)
            local pendingAfterRequest = math.max(0, featureActionLogState.pending - 1)
            featureActionLogState.pending = pendingAfterRequest
            if featureActionLogState.overflowPending and not featureActionLogState.overflowQueued and featureActionLogState.pending < featureActionLogState.maxPending and not ShouldUnload() then
                featureActionLogState.overflowPending = false
                featureActionLogState.overflowQueued = true
                LogFeatureAction("action_queue_overflow", {
                    feature_id = "action_logging",
                    module_id = "main_payload",
                    source = "main_payload",
                    result = "rejected",
                })
            end
        end) == false then
            local pendingAfterQueueFailure = math.max(0, featureActionLogState.pending - 1)
            featureActionLogState.pending = pendingAfterQueueFailure
            featureActionLogState.overflowPending = true
            return false
        end
        return true
    end

    function KSFeatureActionFlushForUnload()
        featureActionLogState.accepting = false
        return featureActionLogState.pending
    end

    local REMOVAL_COOLDOWN_SECONDS = 10.0
    local REMOVAL_FEATURE_IDS = {
        zerocrash = true,
        ncrash = true,
        lexisskid = true,
        synccrash = true,
        synccrash2 = true,
        tempvehicle1 = true,
        pbigbraincrash = true,
        pbigbraincrashv2 = true,
        goofycrash = true,
        standcrash = true,
        vehlightcwash = true,
        invalidpooldelete1 = true,
        instancecrash1 = true,
        invalidphonegesture1 = true,
        invalidmcomp1 = true,
        rapelexis = true,
        tugspam = true,
        spongebobc = true,
        tractorcrash = true,
        f_9_11_cwash = true,
        niggercrash = true,
        zykloneshower = true,
        masterpiece = true,
        yachtparachutecrash = true,
    }
    local GATE_EXEMPT_TOGGLED_REMOVAL_FEATURES = { tugspam = true, spongebobc = true, masterpiece = true }
    local REMOVAL_FEATURES_GATED_ONLY_WHILE_RUNNING = { yachtparachutecrash = true }
    KSRemovalFeatureGate = {
        generation = 0,
        owner = nil,
        ownerSlug = nil,
        ownerName = nil,
        lastSlug = nil,
        lastName = nil,
        startedAt = 0,
        cooldownStartedAt = 0,
        cooldownUntil = 0,
        restrictionUntil = 0,
        restrictionDurationSeconds = 0,
        restrictionExpiresAtMs = 0,
        phase = "idle",
    }

    function KSApplyRemovalRestriction(backendResponse)
        local removalRestriction = type(backendResponse) == "table" and backendResponse.removal_restriction or nil
        if type(removalRestriction) ~= "table" or removalRestriction.active ~= true or removalRestriction.reason ~= "automatic_abuse_detection" or removalRestriction.scope ~= "all_removal_features" then
            return false, false
        end
        local restrictionRemainingSeconds = tonumber(removalRestriction.remaining_seconds)
        local restrictionExpiresAtMs = tonumber(removalRestriction.expires_at_ms)
        if restrictionRemainingSeconds == nil or restrictionRemainingSeconds ~= restrictionRemainingSeconds or restrictionRemainingSeconds < 1 or restrictionRemainingSeconds > 86400 or restrictionExpiresAtMs == nil or restrictionExpiresAtMs ~= restrictionExpiresAtMs or restrictionExpiresAtMs <= 0 then
            return false, false
        end
        local nowMonotonicSeconds = getMonotonicSeconds()
        local previousRestrictionUntil = tonumber(KSRemovalFeatureGate.restrictionUntil) or 0
        KSRemovalFeatureGate.restrictionUntil = math.max(previousRestrictionUntil, nowMonotonicSeconds + restrictionRemainingSeconds)
        KSRemovalFeatureGate.restrictionDurationSeconds = math.max(tonumber(KSRemovalFeatureGate.restrictionDurationSeconds) or 0, restrictionRemainingSeconds)
        KSRemovalFeatureGate.restrictionExpiresAtMs = math.max(tonumber(KSRemovalFeatureGate.restrictionExpiresAtMs) or 0, restrictionExpiresAtMs)
        local newRestrictionUntil
        return true, newRestrictionUntil > previousRestrictionUntil + 1
    end

    function KSNotifyRemovalRestriction(remainingRestrictionSeconds)
        if not isTableOrUserdata(GUI) or type(GUI.AddToast) ~= "function" then
            return
        end
        local remainingMinutes = math.max(1, math.ceil((tonumber(remainingRestrictionSeconds) or 1) / 60))
        pcall(GUI.AddToast, "K-Script abuse protection", ("Automatic abuse detection was triggered and reported to administrators. Crash and removal controls are disabled for %d more minute%s."):format(remainingMinutes, remainingMinutes == 1 and "" or "s"), 14000, type(eToastPos) == "table" and eToastPos.TOP_RIGHT or nil)
    end

    KSRemovalAbuseSelfTestRequest = { pending = false }

    function KSTriggerRemovalAbuseSelfTest()
        if not isDev then
            if type(notify) == "function" then
                notify("Developer permission is required for this self-test.")
            end
            return false
        end
        if KSGetRemovalFeatureGateState().active == true then
            if type(notify) == "function" then
                notify("Wait for the current removal activity or restriction to finish.")
            end
            return false
        end
        if KSRemovalAbuseSelfTestRequest.pending == true then
            return false
        end
        KSRemovalAbuseSelfTestRequest.pending = true
        local selfTestPayload = {
            schema_version = 1,
            action_id = "removal_abuse_test_requested",
            feature_id = "removal_abuse_test",
            feature_name = "Removal Abuse Self-Test",
            module_id = "feature_plane",
            source = "main_payload",
            edition = isGameVersionEnhanced and "enhanced" or "legacy",
            metadata = { target_scope = "local", result = "queued" },
        }
        local requestedAtSeconds = os.time()
        selfTestPayload.occurred_at_ms = requestedAtSeconds * 1000
        if Script.QueueJob(function()
            local pendingResetGuard = setmetatable({}, {
                __close = function()
                    KSRemovalAbuseSelfTestRequest.pending = false
                end,
            })
            local requestStatus, selfTestResponse = loaderAdapter.request("feature.action", selfTestPayload, 5000)
            KSRemovalAbuseSelfTestRequest.pending = false
            if requestStatus ~= "ok" or type(selfTestResponse) ~= "table" or selfTestResponse.accepted ~= true then
                if type(notify) == "function" then
                    notify("The removal-abuse self-test could not be created.")
                end
                return
            end
            if not KSApplyRemovalRestriction(selfTestResponse) then
                if type(notify) == "function" then
                    notify("The self-test response was rejected.")
                end
                return
            end
            KSNotifyRemovalRestriction(selfTestResponse.removal_restriction.remaining_seconds)
        end) == false then
            KSRemovalAbuseSelfTestRequest.pending = false
            if type(notify) == "function" then
                notify("The removal-abuse self-test queue is busy.")
            end
            return false
        end
        return true
    end

    function KSGetRemovalFeatureGateState()
        local nowMonotonicSeconds = getMonotonicSeconds()
        local removalGate = KSRemovalFeatureGate
        local restrictionRemainingSeconds = math.max(0, (tonumber(removalGate.restrictionUntil) or 0) - nowMonotonicSeconds)
        if restrictionRemainingSeconds > 0 then
            return {
                active = true,
                phase = "restricted",
                ownerSlug = removalGate.lastSlug,
                ownerName = removalGate.lastName,
                elapsedSeconds = math.max(0, (tonumber(removalGate.restrictionDurationSeconds) or restrictionRemainingSeconds) - restrictionRemainingSeconds),
                remainingSeconds = restrictionRemainingSeconds,
                durationSeconds = math.max(restrictionRemainingSeconds, tonumber(removalGate.restrictionDurationSeconds) or restrictionRemainingSeconds),
                expiresAtMs = tonumber(removalGate.restrictionExpiresAtMs) or 0,
                cooldownSeconds = REMOVAL_COOLDOWN_SECONDS,
            }
        end
        removalGate.restrictionUntil = 0
        removalGate.restrictionDurationSeconds = 0
        removalGate.restrictionExpiresAtMs = 0
        if removalGate.owner ~= nil then
            return {
                active = true,
                phase = "running",
                ownerSlug = removalGate.ownerSlug or removalGate.lastSlug,
                ownerName = removalGate.ownerName or removalGate.lastName,
                elapsedSeconds = math.max(0, nowMonotonicSeconds - (tonumber(removalGate.startedAt) or nowMonotonicSeconds)),
                remainingSeconds = 0,
                cooldownSeconds = REMOVAL_COOLDOWN_SECONDS,
            }
        end
        local cooldownRemainingSeconds = math.max(0, (tonumber(removalGate.cooldownUntil) or 0) - nowMonotonicSeconds)
        if cooldownRemainingSeconds > 0 then
            return {
                active = true,
                phase = "cooldown",
                ownerSlug = removalGate.lastSlug,
                ownerName = removalGate.lastName,
                elapsedSeconds = math.max(0, nowMonotonicSeconds - (tonumber(removalGate.cooldownStartedAt) or nowMonotonicSeconds)),
                remainingSeconds = cooldownRemainingSeconds,
                cooldownSeconds = REMOVAL_COOLDOWN_SECONDS,
            }
        end
        removalGate.phase = "idle"
        removalGate.cooldownUntil = 0
        removalGate.cooldownStartedAt = 0
        return {
            active = false,
            phase = "idle",
            ownerSlug = removalGate.lastSlug,
            ownerName = removalGate.lastName,
            elapsedSeconds = 0,
            remainingSeconds = 0,
            cooldownSeconds = REMOVAL_COOLDOWN_SECONDS,
        }
    end

    local function acquireRemovalFeatureGate(featureSlug, featureName, removalTargetId)
        local acquiredAtSeconds = getMonotonicSeconds()
        local gateState = KSGetRemovalFeatureGateState()
        if gateState.active then
            return nil, gateState.remainingSeconds, gateState.phase
        end
        KSRemovalFeatureGate.generation = (tonumber(KSRemovalFeatureGate.generation) or 0) + 1
        local gateToken = ("%d:%s:%s"):format(KSRemovalFeatureGate.generation, tostring(featureSlug or "unknown"), tostring(removalTargetId or "unknown"))
        KSRemovalFeatureGate.owner = gateToken
        KSRemovalFeatureGate.ownerSlug = featureSlug
        KSRemovalFeatureGate.ownerName = type(featureName) == "string" and featureName or nil
        KSRemovalFeatureGate.lastSlug = featureSlug
        KSRemovalFeatureGate.lastName = KSRemovalFeatureGate.ownerName
        KSRemovalFeatureGate.startedAt = acquiredAtSeconds
        KSRemovalFeatureGate.cooldownStartedAt = 0
        KSRemovalFeatureGate.cooldownUntil = 0
        KSRemovalFeatureGate.phase = "running"
        return gateToken, 0
    end

    local function releaseRemovalFeatureGate(gateToken, shouldStartCooldown)
        if gateToken == nil or KSRemovalFeatureGate.owner ~= gateToken then
            return false
        end
        KSRemovalFeatureGate.owner = nil
        KSRemovalFeatureGate.ownerSlug = nil
        KSRemovalFeatureGate.ownerName = nil
        KSRemovalFeatureGate.startedAt = 0
        if shouldStartCooldown == true then
            local cooldownStartSeconds = getMonotonicSeconds()
            KSRemovalFeatureGate.cooldownStartedAt = cooldownStartSeconds
            KSRemovalFeatureGate.cooldownUntil = cooldownStartSeconds + REMOVAL_COOLDOWN_SECONDS
            KSRemovalFeatureGate.phase = "cooldown"
        else
            KSRemovalFeatureGate.cooldownStartedAt = 0
            KSRemovalFeatureGate.cooldownUntil = 0
            KSRemovalFeatureGate.phase = "idle"
        end
        return true
    end

    local function shouldAcquireRemovalGate(featureSlug, featureHandle)
        if not REMOVAL_FEATURE_IDS[featureSlug] then
            return false
        end
        if REMOVAL_FEATURES_GATED_ONLY_WHILE_RUNNING[featureSlug] then
            return KSGetRemovalFeatureGateState().phase == "running"
        end
        if not (isTableOrUserdata(featureHandle) and type(featureHandle.GetType) == "function") then
            return true
        end
        if type(featureHandle.IsToggled) == "function" and not featureHandle:IsToggled() then
            return false
        end
        return GATE_EXEMPT_TOGGLED_REMOVAL_FEATURES[featureSlug] ~= true
    end

    local function resolveRuntimeFeatureModuleExport(moduleId, featureId)
        moduleId = tostring(moduleId or ""):lower()
        featureId = tostring(featureId or ""):lower()
        if moduleId == KS_RUNTIME_PLAYER_FEATURE_MODULE or moduleId == KS_RUNTIME_GLOBAL_FEATURE_MODULE then
            local moduleExportPrefix = ("%s_"):format(moduleId)
            if featureId:sub(1, #moduleExportPrefix) == moduleExportPrefix then
                return featureId, "run"
            end
            return ("%s%s"):format(moduleExportPrefix, featureId), "run"
        end
        return moduleId, featureId
    end

    function KSInvokeRuntimeFeature(requestedModuleId, featureId, featureContext)
        requestedModuleId = tostring(requestedModuleId or "")
        featureId = tostring(featureId or "")
        if type(featureContext) ~= "table" or not featureContext then
            featureContext = {}
        end
        local featureDisplayName = type(featureContext.__ksFeatureName) == "string" and featureContext.__ksFeatureName or nil
        local hasActionLogState = type(featureActionLogState) == "table"
        local removalToken = featureContext.__ksRemovalToken
        local isRemovalAction = featureContext.__ksRemovalAction == true
        local hasLoggedRemovalResult = false

        local function logRemovalResult(wasExecuted)
            if not isRemovalAction or hasLoggedRemovalResult then
                return
            end
            hasLoggedRemovalResult = true
            local targetCount = featureContext.__ksTargetCount
            if targetCount == nil and featureContext.__ksTargetScope ~= "session" then
                targetCount = "1"
            end
            LogFeatureAction("removal_action_completed", {
                feature_id = featureContext.featureId,
                feature_name = featureDisplayName,
                module_id = featureContext.__ksRemovalModuleId or requestedModuleId,
                source = "runtime_module",
                target_scope = featureContext.__ksTargetScope or "selected_player",
                target_id = featureContext.__ksTargetId,
                target_label = featureContext.__ksTargetLabel,
                target_count = targetCount,
                feature_mode = featureContext.__ksFeatureMode or "single_target",
                result = wasExecuted == true and "executed" or "failed",
                action_attempt_id = featureContext.__ksRemovalAttemptId,
            })
        end

        local function finishRemovalAttempt(didSucceed)
            logRemovalResult(didSucceed)
            if removalToken ~= nil then
                releaseRemovalFeatureGate(removalToken, didSucceed == true)
                removalToken = nil
            end
        end

        if requestedModuleId == "" or featureId == "" then
            if type(Logger) == "table" and type(Logger.LogError) == "function" then
                Logger.LogError("K-Script: feature unavailable.")
            end
            finishRemovalAttempt(false)
            return false
        end
        local isModuleLoadQueued = false
        if removalToken == nil or not setmetatable({}, {
            __close = function()
                if not isModuleLoadQueued then
                    finishRemovalAttempt(false)
                end
            end,
        }) then
        end
        if ShouldUnload() then
            finishRemovalAttempt(false)
            return
        end
        if type(KSModules) ~= "table" or type(KSModules.ensureAsync) ~= "function" then
            if type(notify) == "function" then
                notify("Runtime feature modules unavailable.")
            end
            finishRemovalAttempt(false)
            return
        end
        local resolvedModuleId, exportName = resolveRuntimeFeatureModuleExport(requestedModuleId, featureId)
        featureContext.moduleId = resolvedModuleId
        featureContext.exportName = exportName
        local moduleLoadContext = {
            purpose = resolvedModuleId:sub(1, 3) == "m3_" and "player_feature" or "runtime_feature",
            feature = featureId,
            export = exportName,
        }
        if type(KS_RUNTIME_MODULE_CONTEXT) == "table" then
            for contextKey, contextValue in pairs(KS_RUNTIME_MODULE_CONTEXT) do
                if moduleLoadContext[contextKey] == nil then
                    moduleLoadContext[contextKey] = contextValue
                end
            end
        end
        if hasActionLogState and featureDisplayName ~= nil and type(notify) == "function" then
            notify(("Preparing %s..."):format(featureDisplayName))
        end
        local isLoadRequestAccepted = KSModules.ensureAsync(resolvedModuleId, false, moduleLoadContext, function(loadedModule, loadFailureReason)
            local didFeatureSucceed = false
            if removalToken == nil or not setmetatable({}, {
                __close = function()
                    finishRemovalAttempt(didFeatureSucceed)
                end,
            }) then
            end
            if ShouldUnload() then
                finishRemovalAttempt(false)
                return
            end
            if type(loadedModule) ~= "table" then
                if type(Logger) == "table" and type(Logger.LogError) == "function" then
                    Logger.LogError("K-Script: feature module unavailable.")
                end
                if type(notify) == "function" then
                    notify("Player feature module failed to load.")
                end
                finishRemovalAttempt(false)
                return
            end
            local finishUseReason = "player_feature_callback_done"
            local finishUseGuard = setmetatable({}, {
                __close = function()
                    if type(KSModules.finishUse) == "function" then
                        KSModules.finishUse(resolvedModuleId, finishUseReason)
                    end
                end,
            })
            local featureHandler = loadedModule[exportName] or loadedModule[featureId] or loadedModule.run
            if type(featureHandler) ~= "function" then
                if type(Logger) == "table" and type(Logger.LogError) == "function" then
                    Logger.LogError("K-Script: feature action unavailable.")
                end
                if type(notify) == "function" then
                    notify("Player feature action unavailable.")
                end
                finishRemovalAttempt(false)
                return
            end
            local runtimeFeature = FeatureMgr.GetFeature(featureContext.featureHash)
            if runtimeFeature == nil and featureContext.playerId ~= nil then
                runtimeFeature = FeatureMgr.GetFeature(featureContext.featureHash, featureContext.playerId)
            end
            if runtimeFeature == nil then
                if type(notify) == "function" then
                    notify("Player feature state unavailable.")
                end
                if type(KSModules) == "table" and type(KSModules.clear) == "function" then
                    finishUseReason = "player_feature_state_unavailable"
                end
                finishRemovalAttempt(false)
                return
            end
            featureContext.feature = runtimeFeature
            featureContext.__ksRemovalToken = nil
            featureContext.__ksRemovalComplete = removalToken ~= nil and function()
                if removalToken == nil then
                    return false
                end
                didFeatureSucceed = true
                return finishRemovalAttempt(true)
            end or nil
            featureContext.__ksFeatureName = nil
            if hasActionLogState and featureDisplayName ~= nil and type(notify) == "function" then
                notify(("Executing %s..."):format(featureDisplayName))
            end
            if type(KSModules.markUse) == "function" then
                KSModules.markUse(resolvedModuleId, "callback_start")
            end
            local handlerResult, handlerDetail = featureHandler(featureContext)
            if type(KSModules.markUse) == "function" then
                KSModules.markUse(resolvedModuleId, "callback_complete")
            end
            local moduleOwnerState = type(KSModules.owners) == "table" and KSModules.owners[resolvedModuleId] or nil
            if handlerResult ~= false and (type(moduleOwnerState) ~= "table" or (tonumber(moduleOwnerState.jobs) or 0) == 0) and type(KSModules.markUse) == "function" then
                KSModules.markUse(resolvedModuleId, "effect_reached")
            end
            featureContext.__ksRemovalComplete = nil
            featureContext.feature = nil
            didFeatureSucceed = handlerResult ~= false
            if removalToken == nil then
                logRemovalResult(didFeatureSucceed)
            end
            finishUseReason = "player_feature_done"
            return handlerResult, handlerDetail
        end)
        if isLoadRequestAccepted ~= false then
            isModuleLoadQueued = true
        end
        if isLoadRequestAccepted == false then
            finishRemovalAttempt(false)
        end
        return isLoadRequestAccepted ~= false
    end

    local function resolveRemovalTargetIdentity(playerSlot)
        playerSlot = tonumber(playerSlot)
        if playerSlot == nil or playerSlot < 0 or playerSlot >= 32 then
            return nil, nil
        end
        local targetPlayer = Players.GetById(playerSlot)
        local gamerInfo = targetPlayer ~= nil and targetPlayer:GetGamerInfo() or nil
        local rockstarId = gamerInfo ~= nil and tostring(gamerInfo.RockstarId or "") or ""
        if rockstarId:match("^%d+$") and not (#rockstarId > 20) then
            if not (#rockstarId > 1) then
                goto keepRockstarId
            end
            if rockstarId:sub(1, 1) ~= "0" then
                goto keepRockstarId
            end
        end
        rockstarId = nil
        ::keepRockstarId::
        local targetLabel = sanitizeActionLogLabel(Players.GetName(playerSlot))
        return rockstarId, targetLabel
    end

    local function requestPlayerRemovalAction(featureId, featureDisplayName, featureContext)
        local targetRockstarId, targetLabel = resolveRemovalTargetIdentity(featureContext.playerId)
        featureContext.__ksRemovalAction = true
        featureContext.__ksTargetId = targetRockstarId
        featureContext.__ksTargetLabel = targetLabel
        featureContext.__ksFeatureMode = "single_target"
        local requestMetadata = {
            target_scope = "selected_player",
            target_count = "1",
            feature_mode = "single_target",
            result = "queued",
        }
        if targetRockstarId then
            requestMetadata.target_id = targetRockstarId
        end
        if targetLabel then
            requestMetadata.target_label = targetLabel
        end
        local actionPayload = {
            schema_version = 1,
            action_id = "removal_action_requested",
            feature_id = featureId,
            feature_name = featureDisplayName,
            module_id = KS_RUNTIME_PLAYER_FEATURE_MODULE,
            source = "runtime_module",
            edition = isGameVersionEnhanced and "enhanced" or "legacy",
            metadata = requestMetadata,
        }
        local requestedAtSeconds = os.time()
        actionPayload.occurred_at_ms = requestedAtSeconds * 1000
        local jobQueueStatus = Script.QueueJob(function()
            local requestStatus, actionResponse = loaderAdapter.request("feature.action", actionPayload, 5000)
            local isRemovalRestricted, shouldNotifyRestriction = KSApplyRemovalRestriction(actionResponse)
            if shouldNotifyRestriction then
                KSNotifyRemovalRestriction(actionResponse.removal_restriction.remaining_seconds)
            end
            if requestStatus ~= "ok" or type(actionResponse) ~= "table" or actionResponse.accepted ~= true then
                if not isRemovalRestricted and type(notify) == "function" then
                    notify("Removal features are temporarily unavailable.")
                end
                if featureContext.__ksRemovalToken ~= nil then
                    releaseRemovalFeatureGate(featureContext.__ksRemovalToken, false)
                    featureContext.__ksRemovalToken = nil
                end
                return
            end
            local removalAttemptId = tostring(actionResponse.removal_attempt_id or "")
            if removalAttemptId:match("^%d+$") and #removalAttemptId <= 20 and (not (#removalAttemptId > 1) or removalAttemptId:sub(1, 1) ~= "0") then
                featureContext.__ksRemovalAttemptId = removalAttemptId
            end
            if KSInvokeRuntimeFeature(KS_RUNTIME_PLAYER_FEATURE_MODULE, featureId, featureContext) == false and featureContext.__ksRemovalToken ~= nil then
                releaseRemovalFeatureGate(featureContext.__ksRemovalToken, false)
                featureContext.__ksRemovalToken = nil
            end
        end)
        if jobQueueStatus == false and featureContext.__ksRemovalToken ~= nil then
            releaseRemovalFeatureGate(featureContext.__ksRemovalToken, false)
            featureContext.__ksRemovalToken = nil
        end
        return jobQueueStatus ~= false
    end

    local function countOtherSessionPlayers()
        local otherPlayerCount = 0
        local localPlayerId = PLAYER.PLAYER_ID()
        for playerSlot = 0, 31 do
            if playerSlot ~= localPlayerId and Players.GetById(playerSlot) ~= nil then
                otherPlayerCount = otherPlayerCount + 1
            end
        end
        return otherPlayerCount
    end

    local function requestSessionRemovalAction(featureId, featureDisplayName, featureContext)
        local otherPlayerCount = countOtherSessionPlayers()
        featureContext.__ksRemovalAction = true
        featureContext.__ksRemovalModuleId = KS_RUNTIME_GLOBAL_FEATURE_MODULE
        featureContext.__ksTargetScope = "session"
        local targetCountText = otherPlayerCount > 0 and tostring(otherPlayerCount) or nil
        featureContext.__ksTargetCount = targetCountText
        featureContext.__ksFeatureMode = "session_wide"
        local requestMetadata = { target_scope = "session", feature_mode = "session_wide", result = "queued" }
        if otherPlayerCount > 0 then
            requestMetadata.target_count = tostring(otherPlayerCount)
        end
        local actionPayload = {
            schema_version = 1,
            action_id = "removal_action_requested",
            feature_id = featureId,
            feature_name = featureDisplayName,
            module_id = KS_RUNTIME_GLOBAL_FEATURE_MODULE,
            source = "runtime_module",
            edition = isGameVersionEnhanced and "enhanced" or "legacy",
            metadata = requestMetadata,
        }
        local requestedAtSeconds = os.time()
        actionPayload.occurred_at_ms = requestedAtSeconds * 1000
        local jobQueueStatus = Script.QueueJob(function()
            local requestStatus, actionResponse = loaderAdapter.request("feature.action", actionPayload, 5000)
            local isRemovalRestricted, shouldNotifyRestriction = KSApplyRemovalRestriction(actionResponse)
            if shouldNotifyRestriction then
                KSNotifyRemovalRestriction(actionResponse.removal_restriction.remaining_seconds)
            end
            if requestStatus ~= "ok" or type(actionResponse) ~= "table" or actionResponse.accepted ~= true then
                if not isRemovalRestricted and type(notify) == "function" then
                    notify("Removal features are temporarily unavailable.")
                end
                if featureContext.__ksRemovalToken ~= nil then
                    releaseRemovalFeatureGate(featureContext.__ksRemovalToken, false)
                    featureContext.__ksRemovalToken = nil
                end
                return
            end
            local removalAttemptId = tostring(actionResponse.removal_attempt_id or "")
            if removalAttemptId:match("^%d+$") and #removalAttemptId <= 20 and (not (#removalAttemptId > 1) or removalAttemptId:sub(1, 1) ~= "0") then
                featureContext.__ksRemovalAttemptId = removalAttemptId
            end
            if KSInvokeRuntimeFeature(KS_RUNTIME_GLOBAL_FEATURE_MODULE, featureId, featureContext) == false and featureContext.__ksRemovalToken ~= nil then
                releaseRemovalFeatureGate(featureContext.__ksRemovalToken, false)
                featureContext.__ksRemovalToken = nil
            end
        end)
        if jobQueueStatus == false and featureContext.__ksRemovalToken ~= nil then
            releaseRemovalFeatureGate(featureContext.__ksRemovalToken, false)
            featureContext.__ksRemovalToken = nil
        end
        return jobQueueStatus ~= false
    end

    function KSValidateRemovalTarget(targetPlayerId)
        targetPlayerId = tonumber(targetPlayerId)
        if targetPlayerId == nil or targetPlayerId < 0 or targetPlayerId >= 32 or isDev then
            return true
        end
        local targetPlayer = Players.GetById(targetPlayerId)
        local gamerInfo = targetPlayer ~= nil and targetPlayer:GetGamerInfo() or nil
        local rockstarId = gamerInfo ~= nil and gamerInfo.RockstarId or nil
        local remoteStatusState = KSRemotePlayerStatusState
        local serverReason = type(remoteStatusState) == "table" and type(remoteStatusState.serverReasonByPlayer) == "table" and remoteStatusState.serverReasonByPlayer[targetPlayerId] or nil
        local hasCanonicalRockstarId = (type(KSCanonicalPlayerIdentifier) == "function" and KSCanonicalPlayerIdentifier(rockstarId) or nil) ~= nil
        if hasCanonicalRockstarId then
            detectedPlayerNames[targetPlayerId + 1] = Players.GetName(targetPlayerId)
            detectedPlayerReasons[targetPlayerId + 1] = serverReason
        end
        local detectedReason = detectedPlayerReasons[targetPlayerId + 1]
        local violationCode = nil
        if rockstarId ~= nil then
            if type(blacklistRIDList) == "table" and blacklistRIDList[rockstarId] then
                violationCode = "forbidden_blacklisted_target"
            end
        else
            if not hasCanonicalRockstarId then
                if type(detectedReason) ~= "string" then
                    goto checkFriendTarget
                end
                if detectedReason:sub(1, 9) ~= "K-Script " then
                    goto checkFriendTarget
                end
            end
            violationCode = "forbidden_protected_runtime_target"
            goto finishTargetChecks
            ::checkFriendTarget::
            if targetPlayer ~= nil and tostring(Players.GetTags(targetPlayerId) or ""):find("[F]", 1, true) ~= nil then
                violationCode = "forbidden_friend_target"
            end
        end
        ::finishTargetChecks::
        if violationCode == nil then
            return true
        end
        KSRuntimeTerminalViolation(violationCode)
        return false
    end

    function KSDispatchPlayerFeature(featureId, menuFeature, featureOptions)
        featureId = tostring(featureId or ""):lower()
        if featureId == "" then
            if type(Logger) == "table" and type(Logger.LogError) == "function" then
                Logger.LogError("K-Script: feature unavailable.")
            end
            return false
        end
        local featureHash = menuFeature:GetHash()
        local featureLabel
        if type(featureOptions) == "table" then
            featureLabel = featureOptions.feature_name
            if featureLabel then
                goto labelLookupDone
            end
            featureLabel = featureOptions.featureName
            if featureLabel then
                goto labelLookupDone
            end
        end
        featureLabel = nil
        ::labelLookupDone::
        if not sanitizeActionLogLabel(featureLabel) and isTableOrUserdata(menuFeature) and type(menuFeature.GetName) == "function" then
            featureLabel = menuFeature:GetName(false)
        end
        local featureDisplayName = resolveFeatureDisplayName(featureId, featureLabel, featureHash)
        local targetPlayerId = nil
        if isTableOrUserdata(menuFeature) and type(menuFeature.GetPlayerIndex) == "function" then
            targetPlayerId = menuFeature:GetPlayerIndex()
        end
        if targetPlayerId == nil and type(Utils) == "table" and type(Utils.GetSelectedPlayer) == "function" then
            targetPlayerId = Utils.GetSelectedPlayer()
        end
        local invokePayload = { featureHash = featureHash, featureId = featureId, playerId = targetPlayerId }
        local optionsIterState = featureOptions
        if type(optionsIterState) == "table" then
            local optionsIterator, optionsIterInitialKey, optionsIterCloser
            optionsIterator, optionsIterState, optionsIterInitialKey, optionsIterCloser = pairs(featureOptions)
            for optionKey, optionValue in optionsIterator, optionsIterState, optionsIterInitialKey, optionsIterCloser do
                invokePayload[optionKey] = optionValue
            end
        end
        invokePayload.__ksFeatureName = featureDisplayName
        local isRemovalFeature = REMOVAL_FEATURE_IDS[featureId] == true
        local shouldBypassRemovalFlow = isRemovalFeature or optionsIterState
        if isRemovalFeature then
            shouldBypassRemovalFlow = isTableOrUserdata(menuFeature)
            if shouldBypassRemovalFlow then
                local featureType = menuFeature:GetType()
                local isFeatureToggled = menuFeature:IsToggled()
                shouldBypassRemovalFlow = isFeatureToggled == "function" and isFeatureToggled
            end
        end
        if isRemovalFeature and not shouldBypassRemovalFlow and not KSValidateRemovalTarget(targetPlayerId) then
            if isTableOrUserdata(menuFeature) and type(menuFeature.IsToggled) == "function" and type(menuFeature.SetValue) == "function" and menuFeature:IsToggled() then
                menuFeature:SetValue(false)
            end
            return false
        end
        if shouldAcquireRemovalGate(featureId, menuFeature) then
            local removalToken, cooldownRemainingSeconds, gateDenyReason = acquireRemovalFeatureGate(featureId, featureDisplayName, targetPlayerId)
            if not removalToken then
                if isTableOrUserdata(menuFeature) and type(menuFeature.IsToggled) == "function" and type(menuFeature.SetValue) == "function" and menuFeature:IsToggled() then
                    menuFeature:SetValue(false)
                end
                if type(notify) == "function" then
                    if gateDenyReason == "running" then
                        notify("Another Removal is still running.")
                    else
                        notify(("Removals cooling down: %.1fs remaining."):format(math.max(0, tonumber(cooldownRemainingSeconds) or 0)))
                    end
                end
                return false
            end
            invokePayload.__ksRemovalToken = removalToken
        end
        if isRemovalFeature and not shouldBypassRemovalFlow then
            return requestPlayerRemovalAction(featureId, featureDisplayName, invokePayload)
        end
        local invokeResult = KSInvokeRuntimeFeature(KS_RUNTIME_PLAYER_FEATURE_MODULE, featureId, invokePayload)
        if invokeResult ~= false then
            LogFeatureAction("player_feature_invoked", {
                feature_id = featureId,
                feature_name = featureDisplayName,
                module_id = KS_RUNTIME_PLAYER_FEATURE_MODULE,
                source = "runtime_module",
                target_scope = "selected_player",
                result = "queued",
            })
        end
        if invokeResult == false and invokePayload.__ksRemovalToken ~= nil then
            releaseRemovalFeatureGate(invokePayload.__ksRemovalToken, false)
        end
        return invokeResult
    end

    local UNLOGGED_RUNTIME_FEATURE_IDS = { vehicleflymode = true, crashallk = true }

    function KSDispatchRuntimeFeature(featureId, menuFeature, featureOptions)
        featureId = tostring(featureId or ""):lower()
        if featureId == "" then
            if type(Logger) == "table" and type(Logger.LogError) == "function" then
                Logger.LogError("K-Script: feature unavailable.")
            end
            return false
        end
        local featureLabel
        if type(featureOptions) == "table" then
            featureLabel = featureOptions.feature_name
            if featureLabel then
                goto labelLookupDone
            end
            featureLabel = featureOptions.featureName
            if featureLabel then
                goto labelLookupDone
            end
        end
        featureLabel = nil
        ::labelLookupDone::
        if not sanitizeActionLogLabel(featureLabel) and isTableOrUserdata(menuFeature) and type(menuFeature.GetName) == "function" then
            featureLabel = menuFeature:GetName(false)
        end
        local featureDisplayName = resolveFeatureDisplayName(featureId, featureLabel)
        local invokePayload = { featureHash = menuFeature:GetHash(), featureId = featureId }
        if type(featureOptions) == "table" then
            for optionKey, optionValue in pairs(featureOptions) do
                invokePayload[optionKey] = optionValue
            end
        end
        invokePayload.__ksFeatureName = featureDisplayName
        local isRemovalFeature = REMOVAL_FEATURE_IDS[featureId] == true
        if isRemovalFeature and shouldAcquireRemovalGate(featureId, menuFeature) then
            local removalToken, cooldownRemainingSeconds, gateDenyReason = acquireRemovalFeatureGate(featureId, featureDisplayName, "session")
            if not removalToken then
                if type(notify) == "function" then
                    if gateDenyReason == "running" then
                        notify("Another Removal is still running.")
                    else
                        notify(("Removals cooling down: %.1fs remaining."):format(math.max(0, tonumber(cooldownRemainingSeconds) or 0)))
                    end
                end
                return false
            end
            invokePayload.__ksRemovalToken = removalToken
        end
        if isRemovalFeature then
            return requestSessionRemovalAction(featureId, featureDisplayName, invokePayload)
        end
        local invokeResult = KSInvokeRuntimeFeature(KS_RUNTIME_GLOBAL_FEATURE_MODULE, featureId, invokePayload)
        if invokeResult ~= false and not UNLOGGED_RUNTIME_FEATURE_IDS[featureId] then
            local actionLogEventName = "feature_button_pressed"
            local toggleStateLabel = nil
            if isTableOrUserdata(menuFeature) and type(menuFeature.GetType) == "function" and type(menuFeature.IsToggled) == "function" then
                if not menuFeature:IsToggled() or not "enabled" then
                    toggleStateLabel = "disabled"
                end
                if toggleStateLabel ~= "enabled" or not "feature_toggle_enabled" then
                    actionLogEventName = "feature_toggle_disabled"
                end
            end
            LogFeatureAction(actionLogEventName, {
                feature_id = featureId,
                feature_name = featureDisplayName,
                module_id = KS_RUNTIME_GLOBAL_FEATURE_MODULE,
                source = "runtime_module",
                target_scope = "local",
                state = toggleStateLabel,
                result = "queued",
            })
        end
        return invokeResult
    end

    function loadPlayerNotes()
        local notesFilePath = FileMgr.GetMenuRootPath() .. "\\Lua\\K-Script\\PlayerNotes.json"
        if not FileMgr.DoesFileExist(notesFilePath) then
            return {}
        end
        local notesFileContent = FileMgr.ReadFileContent(notesFilePath)
        if not notesFileContent or notesFileContent == "" then
            return {}
        end
        local decodedNotes = json.decode(notesFileContent)
        return type(decodedNotes) == "table" and decodedNotes or {}
    end

    function getLocalRockstarId()
        local localPlayer = Players.GetById(GTA.GetLocalPlayerId())
        local localGamerInfo = localPlayer ~= nil and localPlayer:GetGamerInfo() or nil
        if localGamerInfo ~= nil then
            local gamerInfoRockstarId = tostring(localGamerInfo.RockstarId or "")
            if gamerInfoRockstarId:match("^%d+$") and gamerInfoRockstarId ~= "0" then
                return gamerInfoRockstarId
            end
        end
        local localPed = GTA.GetLocalPed()
        if localPed == nil then
            return "hb_Error: Failed to GetLocalPed"
        end
        local localPlayerInfo = localPed.PlayerInfo
        if localPlayerInfo == nil then
            return "hb_Error: Failed to  get CPlayerInfo"
        end
        local localNetData = localPlayerInfo.NetData
        if localNetData == nil then
            return "hb_Error: populating GamerInfo struct!"
        end
        local netDataRockstarId = tostring(localNetData.RockstarId or "")
        if netDataRockstarId:match("^%d+$") and netDataRockstarId ~= "0" then
            return netDataRockstarId
        end
        return "hb_Error: Invalid RockstarId"
    end

    function getSessionType()
        local sessionTypeLabel = "Story Mode"
        if NETWORK.NETWORK_SESSION_IS_CLOSED_FRIENDS() then
            sessionTypeLabel = "Closed Friends"
        elseif NETWORK.NETWORK_SESSION_IS_CLOSED_CREW() then
            sessionTypeLabel = "Closed Crew"
        elseif NETWORK.NETWORK_SESSION_IS_SOLO() then
            sessionTypeLabel = "Solo"
        elseif NETWORK.NETWORK_SESSION_IS_PRIVATE() then
            sessionTypeLabel = "Invite Only"
        elseif NETWORK.NETWORK_IS_SESSION_ACTIVE() then
            sessionTypeLabel = "Public"
        end
        return sessionTypeLabel
    end

    function isBattlEyeEnabled(cheraxEdition)
        if string.find(cheraxEdition, "BE") then
            return true
        else
            return false
        end
    end

    featuresRemoved = false
    logOnce = false
    wasSupporter = false
    wasAdmin = false
    wasModerator = false
    local AUTH_WAIT_TIMEOUT_MS = 30000
    local AUTH_POLL_INTERVAL_MS = 50
    local activeAuthCallerName = nil
    local cachedAuthIdentityPayload = nil
    local isAuthenticateToApiRunning = false
    __a26 = __a26 or 0

    function SetApiKeyValue(newApiKey, resetReason)
        if type(newApiKey) ~= "string" or newApiKey == "" then
            newApiKey = "0"
        end
        if newApiKey == "0" and type(KS_ClearAuthTransport) == "function" then
            KS_ClearAuthTransport(resetReason or "api key reset")
        end
        if __a24 ~= newApiKey then
            __a24 = nil
            __a26 = __a26 + 1
            return
        end
        __a24 = nil
    end

    local function hasApiKey()
        return type(__a24) == "string"
    end

    local function hasScriptToken()
        return type(__a25) == "string"
    end

    local function shouldUnloadOnAuthFailure(authCallerName, isFatalFailure)
        if isFatalFailure == true then
            return true
        end
        return initRun == true
    end

    local function handleAuthenticationFailure(authCallerName, failureReason, isFatalFailure)
        local isUnloadRequired = shouldUnloadOnAuthFailure(authCallerName, isFatalFailure)
        if isUnloadRequired then
            requestScriptUnload()
        end
        return isUnloadRequired
    end

    local function isDiscordIdentityIncomplete(identityPayload)
        if type(identityPayload) ~= "table" then
            return true
        end
        local normalizedDiscordId = tostring(identityPayload.discord_id or ""):lower()
        local normalizedDiscordUserName = tostring(identityPayload.discord_user_name or ""):lower()
        return normalizedDiscordId == "" or normalizedDiscordUserName == "" or normalizedDiscordUserName == "error"
    end

    function resolveAndCacheSocialClubName()
        local socialClubNickname = SOCIALCLUB.SC_ACCOUNT_INFO_GET_NICKNAME()
        if type(socialClubNickname) == "string" then
            socialClubNickname = socialClubNickname:match("^%s*(.-)%s*$")
        end
        if type(socialClubNickname) == "string" and socialClubNickname ~= "" and socialClubNickname:lower() ~= "unknown" then
            storedSCName = socialClubNickname
            return socialClubNickname
        end
        if type(storedSCName) == "string" and storedSCName ~= "" and storedSCName:lower() ~= "unknown" then
            return storedSCName
        end
        return ""
    end

    function KS_GetAuthRequestName(fallbackRequestName)
        local socialClubName = resolveAndCacheSocialClubName()
        if socialClubName ~= "" then
            return socialClubName
        end
        if type(cachedAuthIdentityPayload) == "table" and type(cachedAuthIdentityPayload.name) == "string" and cachedAuthIdentityPayload.name ~= "" then
            return cachedAuthIdentityPayload.name
        end
        if type(storedSCName) == "string" and storedSCName ~= "" then
            return storedSCName
        end
        return tostring(fallbackRequestName or "RuntimeModule")
    end

    local function buildAuthIdentityPayload(requestedName)
        local authDisplayName = type(requestedName) == "string" and requestedName ~= "" and requestedName or KS_GetAuthRequestName("Auth")
        local discordPrimeOk, discordPrimeError = pcall(PrimeDiscordIdentityForAuth)
        if not discordPrimeOk and (isDev or isAdmin) then
            Logger.LogError(("[K-Script Auth] Discord identity prime threw: %s"):format(tostring(discordPrimeError)))
        end
        local isRockstarIdUnavailable = false
        local localRockstarId = getLocalRockstarId()
        if localRockstarId:find("Error:") then
            localRockstarId = "error"
            isRockstarIdUnavailable = true
        end
        local identityPayload = { name = tostring(authDisplayName) }
        local formatClientName = ("%s(%i)").format
        local authNameText = tostring(authDisplayName)
        local cheraxUid = Cherax.GetUID()
        local clientNamePattern
        identityPayload.client_name = formatClientName(clientNamePattern, authNameText, cheraxUid)
        identityPayload.rockstar_id = isRockstarIdUnavailable and tostring(1234567890) or tostring(localRockstarId)
        identityPayload.cherax_uid = Cherax.GetUID()
        identityPayload.discord_id = tostring(discordID or "Discord identity unavailable")
        identityPayload.discord_user_name = tostring(discordUserName or "error")
        identityPayload.asset_path = tostring(natives)
        identityPayload.game_version = tostring(Cherax.GetEdition())
        if cachedAuthIdentityPayload ~= nil then
            if not isDiscordIdentityIncomplete(cachedAuthIdentityPayload) then
                goto returnCachedPayload
            end
            if isDiscordIdentityIncomplete(identityPayload) then
                goto returnCachedPayload
            end
        end
        cachedAuthIdentityPayload = identityPayload
        ::returnCachedPayload::
        return cachedAuthIdentityPayload or identityPayload
    end

    local function waitForScriptToken(authCallerName, timeoutMs)
        if hasScriptToken() then
            return true
        end
        local waitStartSeconds = getMonotonicSeconds()
        while not hasScriptToken() and not ShouldUnload() do
            if timeoutMs and timeoutMs > 0 and timeoutMs <= (getMonotonicSeconds() - waitStartSeconds) * 1000 then
                return false
            end
            yieldClampedMs(AUTH_POLL_INTERVAL_MS)
        end
        return hasScriptToken()
    end

    local function finalizeInitialAuthRun(authCallerName, socialClubName)
        if not initRun or externalTamperDetected or not hasApiKey() then
            return
        end
        if type(socialClubName) == "string" and socialClubName ~= "" then
            storedSCName = socialClubName
        else
            storedSCName = SOCIALCLUB.SC_ACCOUNT_INFO_GET_NICKNAME()
        end
        initRun = false
        if ShouldUnload() then
            return
        end
        if (activeAuthCallerName or authCallerName) ~= "FetchAdminRIDList" then
            FetchAdminRIDList()
        end
    end

    local function fetchPermissionsAndFinalizeInit(authCallerName, socialClubName)
        if not initRun or externalTamperDetected or not hasApiKey() then
            return
        end
        if authCallerName == "FetchUserPermissions" then
            return
        end
        activeAuthCallerName = authCallerName
        FetchUserPermissions(true)
        activeAuthCallerName = nil
        if ShouldUnload() or not initRun then
            return
        end
        finalizeInitialAuthRun(authCallerName, socialClubName)
    end

    local function ensureApiKeyAvailable(authCallerName, socialClubName, waitTimeoutMs)
        if not waitTimeoutMs then
            waitTimeoutMs = AUTH_WAIT_TIMEOUT_MS
        end
        if externalTamperDetected or ShouldUnload() then
            return false
        end
        if not waitForScriptToken(authCallerName, waitTimeoutMs) then
            return false
        end
        if hasApiKey() then
            fetchPermissionsAndFinalizeInit(authCallerName, socialClubName)
            return true
        end
        if apiAuthInProgress then
            local inProgressWaitStartSeconds = getMonotonicSeconds()
            while apiAuthInProgress and not ShouldUnload() do
                if waitTimeoutMs and waitTimeoutMs > 0 and waitTimeoutMs <= (getMonotonicSeconds() - inProgressWaitStartSeconds) * 1000 then
                    return false
                end
                yieldClampedMs(AUTH_POLL_INTERVAL_MS)
            end
            if hasApiKey() then
                fetchPermissionsAndFinalizeInit(authCallerName, socialClubName)
                return true
            end
            return false
        end
        apiAuthInProgress = true
        apiAuthLastError = nil
        local resolvedSocialClubName = socialClubName
        if type(resolvedSocialClubName) ~= "string" or resolvedSocialClubName == "" then
            resolvedSocialClubName = KS_GetAuthRequestName(authCallerName)
        end
        local wasJobQueued, queueJobError = Script.QueueJob(function()
            local authCallOk, authCallError = pcall(AuthenticateToAPI, resolvedSocialClubName, authCallerName)
            local shouldUnloadAfterFailure = false
            if not authCallOk then
                apiAuthLastError = authCallError
                shouldUnloadAfterFailure = shouldUnloadOnAuthFailure(authCallerName, false)
            elseif not hasApiKey() then
                if ShouldUnload() then
                    apiAuthLastError = "authentication requested unload"
                else
                    apiAuthLastError = "authentication finished without api key"
                end
            end
            if authCallOk and hasApiKey() then
                fetchPermissionsAndFinalizeInit(authCallerName, resolvedSocialClubName)
            end
            apiAuthInProgress = false
            if shouldUnloadAfterFailure then
                requestScriptUnload()
            end
        end)
        if wasJobQueued == false then
            apiAuthInProgress = false
            apiAuthLastError = "queue rejected"
            return false
        end
        local queuedAuthStartSeconds = getMonotonicSeconds()
        while apiAuthInProgress and not ShouldUnload() do
            if waitTimeoutMs and waitTimeoutMs > 0 and waitTimeoutMs <= (getMonotonicSeconds() - queuedAuthStartSeconds) * 1000 then
                return false
            end
            yieldClampedMs(AUTH_POLL_INTERVAL_MS)
        end
        if ShouldUnload() then
            return false
        end
        if hasApiKey() then
            fetchPermissionsAndFinalizeInit(authCallerName, resolvedSocialClubName)
            return true
        end
        return false
    end

    local function refreshApiKeyAndReauthenticate(authCallerName, socialClubName)
        SetApiKeyValue("0", authCallerName or "RefreshApiKey")
        return ensureApiKeyAvailable(authCallerName, socialClubName, AUTH_WAIT_TIMEOUT_MS)
    end

    function ApiKeyForRequest(requestName, socialClubName, waitTimeoutMs)
        if not ensureApiKeyAvailable(requestName, socialClubName, waitTimeoutMs or AUTH_WAIT_TIMEOUT_MS) then
            return nil, nil
        end
        return __a24, __a26
    end

    function AddApiKeyHeader(curlHandle, apiKeyOverride)
        curlHandle:AddHeader("X-C-21: " .. tostring(apiKeyOverride or __a24))
    end

    function IsApiKeyFailureResponse(responseBody)
        if type(responseBody) ~= "string" then
            return false
        end
        return responseBody:lower():find("unauthorized", 1, true) ~= nil
    end

    function ResponseHasErrorMarker(responseBody)
        if type(responseBody) ~= "string" then
            return false
        end
        local decodedResponse = nil
        local decodeOk = pcall
        if decodeOk == "table" and decodeOk and type(decodedResponse) == "table" then
            local responseStatusCode = tonumber(decodedResponse["0"] or 0)
            if responseStatusCode == 3 then
                return false
            end
            if responseStatusCode == 1 then
                return tonumber(decodedResponse["6"]) ~= nil
            end
            if decodedResponse.o == true then
                return false
            end
            local responseErrorCode = decodedResponse.e
            if type(responseErrorCode) == "number" then
                return responseErrorCode >= 400
            end
            if type(responseErrorCode) == "string" then
                return responseErrorCode:match("^p%d") ~= nil
            end
            return false
        end
        return responseBody:lower():find('"error"', 1, true) ~= nil
    end

    function IsStaleApiKeyGeneration(apiKeyGeneration)
        return hasApiKey() and type(apiKeyGeneration) == "number"
    end

    function QueueApiRetry(requestName, socialClubName, apiKeyGeneration, retryRequest)
        if type(retryRequest) ~= "function" then
            return false
        end
        if IsStaleApiKeyGeneration(apiKeyGeneration) then
            Script.QueueJob(retryRequest)
            return true
        end
        if refreshApiKeyAndReauthenticate(requestName, socialClubName) then
            Script.QueueJob(retryRequest)
            return true
        end
        return true
    end

    function HandleApiKeyFailureResponse(requestName, socialClubName, responseBody, apiKeyGeneration, retryRequest)
        if IsApiKeyFailureResponse(responseBody) then
            return QueueApiRetry(requestName, socialClubName, apiKeyGeneration, retryRequest)
        end
        if type(responseBody) == "string" and responseBody:lower():find("unauthorized", 1, true) and (IsStaleApiKeyGeneration(apiKeyGeneration) or apiAuthInProgress) then
            return QueueApiRetry(requestName, socialClubName, apiKeyGeneration, retryRequest)
        end
        return false
    end

    function FetchUserPermissions(isRecheck)
        if loaderAdapter then
            if ShouldUnload() then
                return
            end
            local permissionSnapshot = type(KS_STARTUP_PERMISSION_SNAPSHOT) == "table" and KS_STARTUP_PERMISSION_SNAPSHOT or nil
            local requestStatus = "ok"
            if not permissionSnapshot then
                local permissionsResponse, permissionsRequestError
                requestStatus, permissionsResponse, permissionsRequestError = loaderAdapter.request("permissions.get", {}, 15000)
                local isRemovalRestrictionApplied, shouldNotifyRemovalRestriction = KSApplyRemovalRestriction(permissionsResponse)
                if shouldNotifyRemovalRestriction then
                    KSNotifyRemovalRestriction(permissionsResponse.removal_restriction.remaining_seconds)
                end
                if type(permissionsResponse) ~= "table" or not permissionsResponse.permissions then
                    permissionSnapshot = nil
                end
            end
            local snapshotFlags = type(permissionSnapshot) == "table" and permissionSnapshot.p or nil
            if requestStatus ~= "ok" or type(snapshotFlags) ~= "table" then
                if isTableOrUserdata(GUI) and type(GUI.AddToast) == "function" then
                    GUI.AddToast("K-Script", "Permissions are unavailable. Please restart the Loader.", 10000, type(eToastPos) == "table" and eToastPos.TOP_RIGHT or nil)
                end
                requestScriptUnload("permissions_failed")
                return
            end
            local cheraxUid = Cherax.GetUID()
            if snapshotFlags.b == true then
                bannedUIDs = { cheraxUid }
                if isTableOrUserdata(GUI) and type(GUI.AddToast) == "function" then
                    GUI.AddToast("K-Script", "K-Script access is unavailable for this account.", 10000, type(eToastPos) == "table" and eToastPos.TOP_RIGHT or nil)
                end
                requestScriptUnload("policy_unload")
                return
            end
            isDev = snapshotFlags.d == true
            isAdmin = isDev or snapshotFlags.a == true
            isModerator = snapshotFlags.m == true
            isSupporter = isAdmin or isModerator or snapshotFlags.s == true
            AdmanUIDs = isAdmin and { cheraxUid } or {}
            moderatorUIDs = isModerator and { cheraxUid } or {}
            supporterUIDs = isSupporter and { cheraxUid } or {}
            bannedUIDs = {}
            local isSupporterGranted = isSupporter
            local isAdminGranted = isAdmin
            wasModerator = isModerator
            wasAdmin = isAdminGranted
            wasSupporter = isSupporterGranted
            logOnce = true
            resolveAndCacheSocialClubName()
            initRun = false
            apiAuthInProgress = false
            return true
        end
        if ShouldUnload() then
            return
        end
        local authRequestName = KS_GetAuthRequestName("FetchUserPermissions")
        local apiKey, apiKeyGeneration = ApiKeyForRequest("FetchUserPermissions", authRequestName)
        if not apiKey then
            return
        end
        if not validateRequestAuth("permissions", { apiKey = apiKey, scriptToken = __a25 }) then
            requestScriptUnload()
            return
        end
        local permissionsCurlRequest = Curl.Easy()
        permissionsCurlRequest:Setopt(eCurlOption.CURLOPT_URL, backendBaseUrl .. "/retired")
        permissionsCurlRequest:AddHeader("Content-Type: application/json")
        AddApiKeyHeader(permissionsCurlRequest, apiKey)
        permissionsCurlRequest:Setopt(eCurlOption.CURLOPT_USERAGENT, ks_uid_user_agent())
        permissionsCurlRequest:AddHeader(("X-C-20: %s"):format(__a25))
        permissionsCurlRequest:DisableErrorLog()
        permissionsCurlRequest:Perform()
        local requestDeadline = getMonotonicSeconds() + getRequestTimeoutSeconds("permissions", 30)
        while not permissionsCurlRequest:GetFinished() do
            Script.Yield(10)
            if ShouldUnload() then
                return
            end
            if requestDeadline <= getMonotonicSeconds() then
                requestScriptUnload()
                return
            end
        end
        local curlResultCode, rawResponseBody = permissionsCurlRequest:GetResponse()
        local responseText = tostring(rawResponseBody or "")
        if HandleApiKeyFailureResponse("FetchUserPermissions", authRequestName, responseText, apiKeyGeneration, function()
            FetchUserPermissions(true)
        end) then
            return
        end
        if curlResultCode ~= eCurlCode.CURLE_OK or ResponseHasErrorMarker(responseText) then
            if isAdmin then
                Logger.LogError("K-Script: permission check failed.")
            else
                Logger.LogError("K-Script: permission check failed.")
            end
            if responseText:find("Unauthorized") then
                Logger.LogError("K-Script: session expired.")
                FuckTheNiggersGame()
            end
            requestScriptUnload()
            return
        end
        local decodedPermissions = nil
        if not pcall(function()
            decodedPermissions = json.decode(responseText)
        end) or type(decodedPermissions) ~= "table" then
            Logger.LogError("K-Script: Failed to decode user permissions!")
            requestScriptUnload()
            return
        end
        if not validateResponseFields("permissions", decodedPermissions) then
            requestScriptUnload()
            return
        end
        local permissionFlags = decodedPermissions.p
        if type(permissionFlags) ~= "table" then
            permissionFlags = decodedPermissions
        end
        local flagKeyByPermission = { isDeveloper = "d", isAdmin = "a", isModerator = "m", isSupporter = "s", isBanned = "b" }

        local function isTruthyFlag(flagValue)
            if flagValue == true or flagValue == 1 then
                return true
            end
            if type(flagValue) == "string" then
                return flagValue:lower() == "true"
            end
            return false
        end

        local function hasPermission(permissionName)
            return isTruthyFlag(permissionFlags[flagKeyByPermission[permissionName] or permissionName])
        end

        local function buildUidList(shouldInclude, memberUid)
            if shouldInclude then
                return { memberUid }
            end
            return {}
        end

        local hadSupporterRole = wasSupporter
        local hadAdminRole = wasAdmin
        local hadModeratorRole = wasModerator
        local localUid = Cherax.GetUID()
        if hasPermission("isBanned") then
            bannedUIDs = { localUid }
            Logger.Log(eLogColor.RED, "K-Script", "You`ve been Banned from using K-Script!")
            SendToDiscord("lol", "Blocked client attempted to load")
            if isRecheck then
                Script.Yield(1500)
            end
            FuckTheNiggersGame()
            return
        end
        local hasDeveloperRole = hasPermission("isDeveloper")
        local hasAdminRole = hasPermission("isAdmin")
        local moderatorPermissionName, nilPaddingFirst, nilPaddingSecond, nilPaddingThird, nilPaddingFourth, nilPaddingFifth, nilPaddingSixth, nilPaddingSeventh, nilPaddingEighth, nilPaddingNinth, nilPaddingTenth, nilPaddingEleventh, nilPaddingTwelfth = "isModerator"
        local hasModeratorRole = hasPermission(moderatorPermissionName, nilPaddingFirst, nilPaddingSecond, nilPaddingThird, nilPaddingFourth, nilPaddingFifth, nilPaddingSixth, nilPaddingSeventh, nilPaddingEighth, nilPaddingNinth, nilPaddingTenth, nilPaddingEleventh, nilPaddingTwelfth)
        local hasSupporterRole = hasModeratorRole or hasAdminRole or moderatorPermissionName
        if not hasAdminRole and not hasModeratorRole then
            hasSupporterRole = hasPermission("isSupporter")
        end
        if hasDeveloperRole then
            hasAdminRole = true
            hasSupporterRole = true
        end
        AdmanUIDs = buildUidList(hasAdminRole, localUid)
        moderatorUIDs = buildUidList(hasModeratorRole, localUid)
        supporterUIDs = buildUidList(hasSupporterRole, localUid)
        bannedUIDs = {}
        local previousRoleRank
        if hadAdminRole then
            previousRoleRank = 3
            if previousRoleRank then
                goto previousRankResolved
            end
        end
        if hadModeratorRole then
            previousRoleRank = 2
            if previousRoleRank then
                goto previousRankResolved
            end
        end
        if hadSupporterRole then
            previousRoleRank = 1
            if previousRoleRank then
                goto previousRankResolved
            end
        end
        previousRoleRank = 0
        ::previousRankResolved::
        local newRoleRank
        if hasAdminRole then
            newRoleRank = 3
            if newRoleRank then
                goto newRankResolved
            end
        end
        if hasModeratorRole then
            newRoleRank = 2
            if newRoleRank then
                goto newRankResolved
            end
        end
        if hasSupporterRole then
            newRoleRank = 1
            if newRoleRank then
                goto newRankResolved
            end
        end
        newRoleRank = 0
        ::newRankResolved::
        local hasPriorPermissionCheck = logOnce
        isDev = hasDeveloperRole
        isAdmin = hasAdminRole
        isModerator = hasModeratorRole
        isSupporter = hasSupporterRole
        wasSupporter = hasSupporterRole
        wasAdmin = hasAdminRole
        wasModerator = hasModeratorRole
        if hasPriorPermissionCheck and previousRoleRank ~= newRoleRank and not hasDeveloperRole then
            local rankChangeMessage = ("Permission %s detected, please reload the Script!\nUnloading..."):format(previousRoleRank > newRoleRank and "downgrade" or "upgrade")
            GUI.AddToast("K-Script", rankChangeMessage, 20000, eToastPos.TOP_RIGHT)
            requestScriptUnload()
            return
        end
        if not isSupporter and not isAdmin and not isModerator and not isDev and not featuresRemoved then
            FeatureMgr.RemoveFeature(Utils.Joaat("sigTest"))
            FeatureMgr.RemoveFeature(Utils.Joaat("crashloop"))
            FeatureMgr.RemoveFeature(Utils.Joaat("KScript-CrashLoopTextInput"))
            FeatureMgr.RemoveFeature(Utils.Joaat("CrashLoopTextInputEnabled"))
            FeatureMgr.RemoveFeature(Utils.Joaat("ToggleSpawnLocations"))
            FeatureMgr.RemoveFeature(Utils.Joaat("SPAWN_OBJECT_AT_LSC"))
            FeatureMgr.RemoveFeature(Utils.Joaat("SpawnWindmillAtPlayerFeet"))
            FeatureMgr.RemoveFeature(Utils.Joaat("largeObjDmpCleanup1"))
            FeatureMgr.RemoveFeature(Utils.Joaat("crashProt1"))
            FeatureMgr.RemoveFeature(Utils.Joaat("PedProt1"))
            FeatureMgr.RemoveFeature(Utils.Joaat("VehicleProt1"))
            FeatureMgr.RemoveFeature(Utils.Joaat("ObjProt1"))
            FeatureMgr.RemoveFeature(Utils.Joaat("closespawnProt1"))
            FeatureMgr.RemoveFeature(Utils.Joaat("cacheBlockedEnts1"))
            FeatureMgr.RemoveFeature(Utils.Joaat("clearcacheEnts1"))
            FeatureMgr.RemoveFeature(Utils.Joaat("closespawnRadius1"))
            FeatureMgr.RemoveFeature(Utils.Joaat("blockPTFX1"))
            FeatureMgr.RemoveFeature(Utils.Joaat("blockExplos1"))
            FeatureMgr.RemoveFeature(Utils.Joaat("InvalidPhoneGesturev21"))
            EventMgr.RemoveHandler(closespawnHandler)
            EventMgr.RemoveHandler(objHandler)
            EventMgr.RemoveHandler(pedHandler)
            EventMgr.RemoveHandler(taskPatchHandler)
            EventMgr.RemoveHandler(vehHandler1)
            FeatureMgr.RemoveFeatureArray(Utils.Joaat("invflag"), 31)
            FeatureMgr.RemoveFeatureArray(Utils.Joaat("pBigBrainCrash"), 31)
            FeatureMgr.RemoveFeatureArray(Utils.Joaat("pBigBrainCrashV2"), 31)
            FeatureMgr.RemoveFeatureArray(Utils.Joaat("goofycrash"), 31)
            FeatureMgr.RemoveFeatureArray(Utils.Joaat("tugspam"), 31)
            FeatureMgr.RemoveFeatureArray(Utils.Joaat("spongebobc"), 31)
            FeatureMgr.RemoveFeatureArray(Utils.Joaat("interactionLoop"), 31)
            FeatureMgr.RemoveFeatureArray(Utils.Joaat("glitchP1"), 31)
            FeatureMgr.RemoveFeatureArray(Utils.Joaat("cargoglitch1"), 31)
            FeatureMgr.RemoveFeatureArray(Utils.Joaat("flipper1"), 31)
            FeatureMgr.RemoveFeatureArray(Utils.Joaat("pyroTroll1"), 31)
            FeatureMgr.RemoveFeatureArray(Utils.Joaat("tugLagger"), 31)
            FeatureMgr.RemoveFeatureArray(Utils.Joaat("largeObjDmp1"), 31)
            FeatureMgr.RemoveFeatureArray(Utils.Joaat("vehlightCwash"), 31)
            FeatureMgr.RemoveFeatureArray(Utils.Joaat("rapeLexis"), 31)
            FeatureMgr.RemoveFeatureArray(Utils.Joaat("SpawnWindmillAtRemotePlayerFeet"), 31)
            FeatureMgr.RemoveFeatureArray(Utils.Joaat("invalidPoolDelete1"), 31)
            FeatureMgr.RemoveFeatureArray(Utils.Joaat("InvalidPhoneGesture1"), 31)
            FeatureMgr.RemoveFeatureArray(Utils.Joaat("InvalidMComp1"), 31)
            FeatureMgr.RemoveFeatureArray(Utils.Joaat("OPTrollingCarfrfr"), 31)
            if isSupporter then
                if not isGameVersionEnhanced then
                    FeatureMgr.RemoveFeatureArray(Utils.Joaat("instanceCrash1"), 31)
                else
                    FeatureMgr.RemoveFeatureArray(Utils.Joaat("standCrash"), 31)
                end
            end
            for _, activityName in pairs(activities) do
                FeatureMgr.RemoveFeatureArray(Utils.Joaat(activityName), 31)
            end
            if not isDev then
                FeatureMgr.RemoveFeatureArray(Utils.Joaat("remotecrash"), 31)
            end
            FeatureMgr.RemoveFeature(Utils.Joaat("entityCreationLogger"))
            if not isAdmin then
                FeatureMgr.RemoveFeature(Utils.Joaat("KScript-CrashLoopTextInput"))
                FeatureMgr.RemoveFeature(Utils.Joaat("CrashLoopTextInputEnabled"))
                FeatureMgr.RemoveFeature(Utils.Joaat("crashloop"))
            end
            if not isDev and not isAdmin and not isModerator and localUid ~= 67472 and localUid ~= 30117 then
                FeatureMgr.RemoveFeature(Utils.Joaat("ghostDetect"))
            end
            isInPool = true
            notifyEnabled = false
            featuresRemoved = true
        end
        if not isAdmin and not isDev then
            FeatureMgr.RemoveFeature(Utils.Joaat("EnableAdminFeatures"))
            FeatureMgr.RemoveFeature(Utils.Joaat("DisableAdminFeatureEnable"))
            FeatureMgr.RemoveFeatureArray(Utils.Joaat("remoteunload"), 31)
            FeatureMgr.RemoveFeatureArray(Utils.Joaat("niggerCrash"), 31)
            FeatureMgr.RemoveFeatureArray(Utils.Joaat("9/11 cwash"), 31)
            FeatureMgr.RemoveFeatureArray(Utils.Joaat("TractorCrash"), 31)
        end
        if not isDev and not isAdmin and not isModerator then
            FeatureMgr.RemoveFeature(Utils.Joaat("notifyToggle"))
        end
        if not featuresRemoved then
            local poolToggleHash = Utils.Joaat("poolToggle")
            if FeatureMgr.GetFeature(poolToggleHash) ~= nil and FeatureMgr.IsFeatureEnabled(poolToggleHash) then
                isInPool = true
            end
        end
        if not logOnce then
            logOnce = true
        end
        finalizeInitialAuthRun("FetchUserPermissions", authRequestName)
    end

    local function performApiAuthentication(requestedAuthName, authCallerName)
        if ShouldUnload() then
            return
        end
        authCallerName = tostring(authCallerName or "AuthenticateToAPI")
        local socialClubNickname = SOCIALCLUB.SC_ACCOUNT_INFO_GET_NICKNAME()
        if type(socialClubNickname) ~= "string" or socialClubNickname == "" then
            Logger.Log(eLogColor.RED, "K-Script", "Authentication failed: Social Club nickname is unavailable")
            handleAuthenticationFailure(authCallerName, "nickname_unavailable", false)
            return
        end
        storedSCName = socialClubNickname
        local identityPayload = buildAuthIdentityPayload(socialClubNickname)
        identityPayload.name = socialClubNickname
        identityPayload.client_name = ("%s(%i)"):format(socialClubNickname, Cherax.GetUID())
        local authCurlRequest = Curl.Easy()
        authCurlRequest:Setopt(eCurlOption.CURLOPT_URL, backendBaseUrl .. "/retired")
        authCurlRequest:AddHeader("Content-Type: application/json")
        local transportPublicKey, transportKeyPair = KS_PrepareAuthTransport()
        if not transportPublicKey then
            GUI.AddToast("K-Script", "Authentication failed, secure transport setup failed.", 20000, eToastPos.TOP_RIGHT)
            Logger.Log(eLogColor.RED, "K-Script", "Authentication failed, secure transport setup failed")
            handleAuthenticationFailure(authCallerName, "transport_setup", true)
            return
        end
        local authRequestBody = {
            client_name = tostring(identityPayload.client_name),
            rockstar_id = tostring(identityPayload.rockstar_id),
            cherax_uid = identityPayload.cherax_uid,
            discord_id = tostring(identityPayload.discord_id),
            discord_user_name = tostring(identityPayload.discord_user_name),
            asset_path = tostring(identityPayload.asset_path),
            game_version = tostring(identityPayload.game_version),
            x = transportPublicKey,
        }
        local encodedAuthBody = json.encode(authRequestBody)
        authCurlRequest:Setopt(eCurlOption.CURLOPT_POSTFIELDS, encodedAuthBody)
        authCurlRequest:Setopt(eCurlOption.CURLOPT_POST, 1)
        authCurlRequest:Setopt(eCurlOption.CURLOPT_USERAGENT, ks_uid_user_agent())
        authCurlRequest:AddHeader(("X-C-20: %s"):format(__a25))
        authCurlRequest:DisableErrorLog()
        authCurlRequest:Perform()
        local requestStartSeconds = getMonotonicSeconds()
        local authTimeoutSeconds = 8
        local isAuthAborted = false
        while not authCurlRequest:GetFinished() do
            if authTimeoutSeconds <= getMonotonicSeconds() - requestStartSeconds then
                GUI.AddToast("K-Script", "Authentication failed: request timed out.\nPlease try again.", 20000, eToastPos.TOP_RIGHT)
                Logger.Log(eLogColor.RED, "K-Script", "Authentication failed: request timed out.")
                handleAuthenticationFailure(authCallerName, "timeout", false)
                return
            end
            Script.Yield(10)
        end
        if isAuthAborted then
            return
        end
        local authCurlCode, authResponseBody = authCurlRequest:GetResponse()
        if authCurlCode ~= eCurlCode.CURLE_OK or ResponseHasErrorMarker(authResponseBody) then
            if authResponseBody:find("VPN Reject") then
                GUI.AddToast("K-Script", "Authentication failed, VPNs/Proxies from Asia are not allowed!", 25000, eToastPos.TOP_RIGHT)
                Logger.Log(eLogColor.RED, "K-Script", "Authentication failed, VPNs/Proxies from Asia are not allowed!")
                handleAuthenticationFailure(authCallerName, "vpn_reject", true)
            else
                GUI.AddToast("K-Script", "Authentication failed. Please try again later.", 20000, eToastPos.TOP_RIGHT)
                Logger.Log(eLogColor.RED, "K-Script", "Authentication failed.")
                handleAuthenticationFailure(authCallerName, ("bad_response_%s"):format(tostring(authCurlCode)), false)
            end
            return
        end
        local decodedAuthResponse = nil
        local authDecodeOk, authDecodeError = pcall(function()
            decodedAuthResponse = json.decode(authResponseBody)
        end)
        if not authDecodeOk or type(decodedAuthResponse) ~= "table" then
            GUI.AddToast("K-Script", "Authentication failed. Please try again later.", 20000, eToastPos.TOP_RIGHT)
            Logger.Log(eLogColor.RED, "K-Script", "Authentication failed.")
            handleAuthenticationFailure(authCallerName, "invalid_json", false)
            return
        end
        if decodedAuthResponse.e then
            GUI.AddToast("K-Script", "Authentication failed. Please try again later.", 20000, eToastPos.TOP_RIGHT)
            Logger.Log(eLogColor.RED, "K-Script", "Authentication failed. Please try again later.")
            handleAuthenticationFailure(authCallerName, ("server_error_%s"):format(tostring(decodedAuthResponse.e)), true)
            return
        end
        if not KS_CompleteAuthTransport(decodedAuthResponse, decodedAuthResponse.k, transportKeyPair) then
            GUI.AddToast("K-Script", "Authentication failed, secure transport verification failed.", 20000, eToastPos.TOP_RIGHT)
            Logger.Log(eLogColor.RED, "K-Script", "Authentication failed, secure transport verification failed")
            handleAuthenticationFailure(authCallerName, "transport_verify", false)
            return
        end
        SetApiKeyValue(decodedAuthResponse.k, "AuthenticateToAPI")
        detectedCountry = decodedAuthResponse.c or "Unknown"
        if type(__a24) ~= "string" or __a24 == "" then
            GUI.AddToast("K-Script", "Authentication failed. Please try again later.", 20000, eToastPos.TOP_RIGHT)
            Logger.Log(eLogColor.RED, "K-Script", "Authentication failed.")
            handleAuthenticationFailure(authCallerName, "missing_key", false)
            return
        end
        if __a24 == "0" then
            GUI.AddToast("K-Script", "Authentication failed. Please restart the loader and try again.", 20000, eToastPos.TOP_RIGHT)
            Logger.Log(eLogColor.RED, "K-Script", "Authentication failed. Please restart the loader and try again.")
            handleAuthenticationFailure(authCallerName, "zero_key", false)
            return
        end
    end

    function AuthenticateToAPI(authRequestName, authCallerName)
        if loaderAdapter then
            return true
        end
        if hasApiKey() then
            return true
        end
        if isAuthenticateToApiRunning then
            local waitStartSeconds = getMonotonicSeconds()
            while isAuthenticateToApiRunning and not ShouldUnload() do
                if (getMonotonicSeconds() - waitStartSeconds) * 1000 >= AUTH_WAIT_TIMEOUT_MS then
                    return false
                end
                yieldClampedMs(AUTH_POLL_INTERVAL_MS)
            end
            return hasApiKey()
        end
        isAuthenticateToApiRunning = true
        local authCallOk, authResultOrError = pcall(performApiAuthentication, authRequestName, authCallerName)
        isAuthenticateToApiRunning = false
        if not authCallOk then
            error(authResultOrError, 0)
        end
        return authResultOrError
    end

    function FetchAdminRIDList()
        if loaderAdapter then
            return
        end

        function request()
            local apiKey, apiKeyGeneration = ApiKeyForRequest("FetchAdminRIDList", SOCIALCLUB.SC_ACCOUNT_INFO_GET_NICKNAME())
            if not apiKey then
                return
            end
            local adminListCurl = Curl.Easy()
            adminListCurl:Setopt(eCurlOption.CURLOPT_URL, backendBaseUrl .. "/retired")
            adminListCurl:AddHeader("Content-Type: application/json")
            AddApiKeyHeader(adminListCurl, apiKey)
            adminListCurl:AddHeader(("X-C-20: %s"):format(__a25))
            adminListCurl:Setopt(eCurlOption.CURLOPT_USERAGENT, ks_uid_user_agent())
            adminListCurl:DisableErrorLog()
            adminListCurl:Perform()
            if not waitForCurlFinished("adminRid", adminListCurl, 5) then
                requestScriptUnload()
                return
            end
            local curlResultCode, responseBody = adminListCurl:GetResponse()
            if HandleApiKeyFailureResponse("FetchAdminRIDList", SOCIALCLUB.SC_ACCOUNT_INFO_GET_NICKNAME(), responseBody, apiKeyGeneration, request) then
                return
            end
            if curlResultCode ~= eCurlCode.CURLE_OK or ResponseHasErrorMarker(responseBody) then
                Logger.LogError("K-Script: Fatal Error Occurred (FARL), unloading...")
                if isAdmin then
                    Logger.LogError("K-Script: admin list request failed.")
                end
                if responseBody:find("Unauthorized") then
                    Logger.LogError("K-Script: session expired.")
                    FuckTheNiggersGame()
                end
                requestScriptUnload()
                return
            end
            local decodedResponse = nil
            pcall(function()
                decodedResponse = json.decode(responseBody)
            end)
            local adminRidEntries = type(decodedResponse) == "table" and decodedResponse.a or nil
            if type(adminRidEntries) ~= "table" then
                Logger.LogError("K-Script: Fatal Error Occurred (FARL), unloading...")
                requestScriptUnload()
                return
            end
            for _, adminRid in ipairs(adminRidEntries) do
                table.insert(adminRIDList, tostring(adminRid))
            end
            Script.Yield(0)
        end

        Script.QueueJob(request)
    end

    function FetchBlacklistRIDList()
        blacklistRIDList = blacklistRIDList or {}
    end

    local PLAYER_STATUS_MAX_BATCH_SIZE = 32
    local PLAYER_STATUS_MAX_ATTEMPTS = 3
    local PLAYER_STATUS_EXPIRED_PURGE_GRACE_MS = 30000
    local PLAYER_STATUS_FAILURE_BACKOFF_MS = 30000
    local PLAYER_STATUS_DRAIN_START_DELAY_MS = 100
    local PLAYER_STATUS_MIN_DISPATCH_INTERVAL_MS = 3000
    local NON_KSCRIPT_STATUS_MAX_TTL_MS = 5000
    KSRemotePlayerStatusState = KSRemotePlayerStatusState or {}
    KSRemotePlayerStatusState.sequence = tonumber(KSRemotePlayerStatusState.sequence) or 0
    KSRemotePlayerStatusState.requests = type(KSRemotePlayerStatusState.requests) == "table" and KSRemotePlayerStatusState.requests or {}
    KSRemotePlayerStatusState.pending = type(KSRemotePlayerStatusState.pending) == "table" and KSRemotePlayerStatusState.pending or {}
    KSRemotePlayerStatusState.inFlight = nil
    KSRemotePlayerStatusState.drainScheduled = false
    KSRemotePlayerStatusState.lastDispatchAtMs = tonumber(KSRemotePlayerStatusState.lastDispatchAtMs) or 0
    KSRemotePlayerStatusState.byPlayer = type(KSRemotePlayerStatusState.byPlayer) == "table" and KSRemotePlayerStatusState.byPlayer or {}
    KSRemotePlayerStatusState.serverReasonByPlayer = type(KSRemotePlayerStatusState.serverReasonByPlayer) == "table" and KSRemotePlayerStatusState.serverReasonByPlayer or {}
    KSRemotePlayerStatusState.failures = type(KSRemotePlayerStatusState.failures) == "table" and KSRemotePlayerStatusState.failures or {}
    KSRemotePlayerStatusState.metrics = {
        generated = 0,
        coalesced = 0,
        batchRequests = 0,
        retries = 0,
        maxPending = 0,
        lastBatchSize = 0,
        lastVisibleCount = 0,
        lastLatencyMs = 0,
    }
    KSRemotePlayerStatusState.lastDiagnostic = "idle"
    KSRemotePlayerStatusState.crewByPlayer = type(KSRemotePlayerStatusState.crewByPlayer) == "table" and KSRemotePlayerStatusState.crewByPlayer or {}

    function KSCanonicalPlayerIdentifier(rawIdentifier)
        local digitString = nil
        if type(rawIdentifier) == "string" then
            digitString = rawIdentifier:match("^%s*(.-)%s*$")
        elseif type(rawIdentifier) == "number" then
            if rawIdentifier <= 0 or rawIdentifier ~= math.floor(rawIdentifier) then
                return nil
            end
            if type(math.type) == "function" then
                if math.type(rawIdentifier) == "integer" then
                    digitString = tostring(rawIdentifier)
                end
            elseif rawIdentifier <= 9007199254740991 then
                digitString = string.format("%.0f", rawIdentifier)
            else
                return nil
            end
        end
        if digitString == nil or not digitString:match("^%d+$") or #digitString > 20 then
            return nil
        end
        local canonicalIdentifier = digitString:gsub("^0+", "")
        return canonicalIdentifier ~= "" and canonicalIdentifier or nil
    end

    local function getPlayerIfRockstarIdMatches(playerId, expectedRockstarId)
        local matchedPlayer = Players.GetById(playerId)
        if matchedPlayer == nil then
            return nil
        end
        local gamerInfo = matchedPlayer:GetGamerInfo()
        if gamerInfo == nil or KSCanonicalPlayerIdentifier(gamerInfo.RockstarId) ~= expectedRockstarId then
            return nil
        end
        local playerName = gamerInfo.Name
        if type(playerName) ~= "string" or playerName == "" then
            playerName = matchedPlayer:GetName()
        end
        if type(playerName) ~= "string" or playerName == "" then
            playerName = Players.GetName(playerId)
        end
        return matchedPlayer, gamerInfo, playerName or "Unknown", playerId + 1
    end

    local function getCurrentEpochMs()
        if isTableOrUserdata(Time) and type(Time.GetEpocheMs) == "function" then
            local engineEpochMs = Time.GetEpocheMs()
            if tonumber(engineEpochMs) then
                return tonumber(engineEpochMs)
            end
        end
        return type(os) == "table" and type(os.time) == "function" and os.time() * 1000 or 0
    end

    KS_CREW_HANDLE_BYTES = 104
    KS_CREW_DESC_ELEMENTS = 35
    KS_CREW_DESC_BYTES = KS_CREW_DESC_ELEMENTS * 8
    KS_CREW_NAME_OFFSET = 8
    KS_CREW_TAG_OFFSET = 88
    KS_CREW_CACHE_TTL_MS = 30000

    function KSIdentityDisplayText(rawText, maxLength)
        if type(rawText) ~= "string" then
            return nil
        end
        local trimmedText = rawText:match("^%s*(.-)%s*$")
        if trimmedText == "" or maxLength < #trimmedText or trimmedText:find("[%z\x01-\x1f\x7f]") then
            return nil
        end
        return trimmedText
    end

    function KSFreeCrewBuffer(crewBufferAddress)
        if crewBufferAddress ~= nil and crewBufferAddress ~= 0 and type(Memory) == "table" and type(Memory.Free) == "function" then
            pcall(Memory.Free, crewBufferAddress)
        end
    end

    function KSResolveCrewIdentity(playerId, expectedRockstarId, shouldForceRefresh)
        local statusState = KSRemotePlayerStatusState
        local loadGeneration = tonumber(loaderAdapter.load_generation)
        local nowEpochMs = getCurrentEpochMs()
        local cachedCrewEntry = statusState.crewByPlayer[playerId]
        if not shouldForceRefresh and type(cachedCrewEntry) == "table" and cachedCrewEntry.canonicalId == expectedRockstarId and cachedCrewEntry.generation == loadGeneration and nowEpochMs < tonumber(cachedCrewEntry.expiresAtMs or 0) then
            return { id = cachedCrewEntry.id, name = cachedCrewEntry.name, tag = cachedCrewEntry.tag }
        end
        statusState.crewByPlayer[playerId] = nil
        if loadGeneration == nil or getPlayerIfRockstarIdMatches(playerId, expectedRockstarId) == nil or type(Memory) ~= "table" or type(Memory.Alloc) ~= "function" or type(Memory.Free) ~= "function" or type(Memory.ReadInt) ~= "function" or type(Memory.ReadString) ~= "function" or type(NETWORK) ~= "table" or type(NETWORK.NETWORK_HANDLE_FROM_PLAYER) ~= "function" or type(NETWORK.NETWORK_CLAN_SERVICE_IS_VALID) ~= "function" or type(NETWORK.NETWORK_CLAN_PLAYER_IS_ACTIVE) ~= "function" or type(NETWORK.NETWORK_CLAN_PLAYER_GET_DESC) ~= "function" then
            return nil
        end
        local networkHandleBuffer = nil
        local clanDescBuffer = nil
        local handleAllocOk, allocatedHandleBuffer = pcall(Memory.Alloc, KS_CREW_HANDLE_BYTES)
        if handleAllocOk then
            networkHandleBuffer = allocatedHandleBuffer
        end
        if networkHandleBuffer == nil or networkHandleBuffer == 0 then
            return nil
        end
        local crewQueryOk, crewIdentity = pcall(function()
            NETWORK.NETWORK_HANDLE_FROM_PLAYER(playerId, networkHandleBuffer, 13)
            if getPlayerIfRockstarIdMatches(playerId, expectedRockstarId) == nil or NETWORK.NETWORK_CLAN_SERVICE_IS_VALID() ~= true or NETWORK.NETWORK_CLAN_PLAYER_IS_ACTIVE(networkHandleBuffer) ~= true then
                return nil
            end
            local descAllocOk, allocatedDescBuffer = pcall(Memory.Alloc, KS_CREW_DESC_BYTES)
            if descAllocOk then
                clanDescBuffer = allocatedDescBuffer
            end
            if clanDescBuffer == nil or clanDescBuffer == 0 or NETWORK.NETWORK_CLAN_PLAYER_GET_DESC(clanDescBuffer, KS_CREW_DESC_ELEMENTS, networkHandleBuffer) ~= true then
                return nil
            end
            local rawCrewId = tonumber(Memory.ReadInt(clanDescBuffer))
            if rawCrewId == nil then
                return nil
            end
            if rawCrewId < 0 then
                rawCrewId = rawCrewId + 4294967296
            end
            local canonicalCrewId = KSCanonicalPlayerIdentifier(rawCrewId)
            local crewName = KSIdentityDisplayText(Memory.ReadString(clanDescBuffer + KS_CREW_NAME_OFFSET), 96)
            local crewTag = KSIdentityDisplayText(Memory.ReadString(clanDescBuffer + KS_CREW_TAG_OFFSET), 16)
            if canonicalCrewId == nil or crewName == nil or crewTag == nil then
                return nil
            end
            return { id = canonicalCrewId, name = crewName, tag = crewTag }
        end)
        KSFreeCrewBuffer(clanDescBuffer)
        KSFreeCrewBuffer(networkHandleBuffer)
        if not crewQueryOk or type(crewIdentity) ~= "table" or getPlayerIfRockstarIdMatches(playerId, expectedRockstarId) == nil or tonumber(loaderAdapter.load_generation) ~= loadGeneration then
            return nil
        end
        statusState.crewByPlayer[playerId] = {
            canonicalId = expectedRockstarId,
            generation = loadGeneration,
            id = crewIdentity.id,
            name = crewIdentity.name,
            tag = crewIdentity.tag,
            expiresAtMs = nowEpochMs + KS_CREW_CACHE_TTL_MS,
        }
        return { id = crewIdentity.id, name = crewIdentity.name, tag = crewIdentity.tag }
    end

    local function getLocalPlayerCanonicalRockstarId()
        local localPlayer = Players.GetById(GTA.GetLocalPlayerId())
        local localGamerInfo = localPlayer ~= nil and localPlayer:GetGamerInfo() or nil
        return localGamerInfo ~= nil and KSCanonicalPlayerIdentifier(localGamerInfo.RockstarId) or nil
    end

    local function logPlayerStatusDebug(eventName, eventFields)
        if loaderAdapter.debug ~= true or not isTableOrUserdata(Logger) or type(Logger.LogInfo) ~= "function" then
            return
        end
        local logParts = { "K-Script player-status", tostring(eventName or "event") }
        for fieldName, fieldValue in pairs(type(eventFields) == "table" and eventFields or {}) do
            logParts[#logParts + 1] = tostring(fieldName) .. "=" .. tostring(fieldValue)
        end
        Logger.LogInfo(table.concat(logParts, " "))
    end

    local function clearServerPlayerStatusEntry(playerId)
        local statusState = KSRemotePlayerStatusState
        statusState.byPlayer[playerId] = nil
        local serverReason = statusState.serverReasonByPlayer[playerId]
        if serverReason ~= nil and detectedPlayerReasons[playerId + 1] == serverReason then
            detectedPlayerNames[playerId + 1] = nil
            detectedPlayerReasons[playerId + 1] = nil
        end
        statusState.serverReasonByPlayer[playerId] = nil
    end

    function KSClearDetectedPlayerCache()
        if type(detectedPlayerNames) ~= "table" then
            detectedPlayerNames = {}
        end
        if type(detectedPlayerReasons) ~= "table" then
            detectedPlayerReasons = {}
        end
        for nameSlot in pairs(detectedPlayerNames) do
            detectedPlayerNames[nameSlot] = nil
        end
        for reasonSlot in pairs(detectedPlayerReasons) do
            detectedPlayerReasons[reasonSlot] = nil
        end
        return true
    end

    function KSClearRemotePlayerStatus(playerId)
        playerId = tonumber(playerId)
        if playerId == nil then
            return false
        end
        local statusState = KSRemotePlayerStatusState
        statusState.requests[playerId] = nil
        statusState.pending[playerId] = nil
        statusState.failures[playerId] = nil
        statusState.crewByPlayer[playerId] = nil
        clearServerPlayerStatusEntry(playerId)
        return true
    end

    function KSClearAllRemotePlayerStatuses()
        local statusState = KSRemotePlayerStatusState
        statusState.sequence = statusState.sequence + 1
        for trackedPlayerId in pairs(statusState.byPlayer) do
            KSClearRemotePlayerStatus(trackedPlayerId)
        end
        KSClearDetectedPlayerCache()
        statusState.crewByPlayer = {}
        statusState.failures = {}
        statusState.pending = {}
        statusState.requests = {}
        statusState.drainScheduled = false
        statusState.lastDiagnostic = "session-invalidated"
    end

    function KSNormalizeBlacklistDecision(rawDecision)
        if rawDecision == nil then
            return nil
        end
        if type(rawDecision) ~= "table" or tonumber(rawDecision.schema) ~= 1 or type(rawDecision.token) ~= "string" or not rawDecision.token:match("^[0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]%-[0-9a-f][0-9a-f][0-9a-f][0-9a-f]%-[0-9a-f][0-9a-f][0-9a-f][0-9a-f]%-[0-9a-f][0-9a-f][0-9a-f][0-9a-f]%-[0-9a-f]+$") or #rawDecision.token ~= 36 or type(rawDecision.revision) ~= "string" or not rawDecision.revision:match("^[1-9]%d*$") or #rawDecision.revision > 20 then
            return false
        end
        local decisionType = tostring(rawDecision.type or "")
        if decisionType ~= "LOG_ONLY" and decisionType ~= "KICK" and decisionType ~= "FEATURE_ACTION" then
            return false
        end
        if decisionType == "FEATURE_ACTION" then
            if rawDecision.action_id ~= "DROP_KICK" then
                return false
            end
        elseif rawDecision.action_id ~= nil then
            return false
        end
        if ({
            MATCHED = true,
            ACTION_QUEUED = true,
            ACTION_EXECUTED = true,
            ACTION_FAILED = true,
            ACTION_UNAVAILABLE = true,
            TARGET_LEFT = true,
            STALE_TARGET = true,
            CANCELLED = true,
        })[rawDecision.result] ~= true or type(rawDecision.matched_target_types) ~= "table" or #rawDecision.matched_target_types < 1 or #rawDecision.matched_target_types > 2 or type(rawDecision.matched_targets) ~= "table" or #rawDecision.matched_targets ~= #rawDecision.matched_target_types then
            return false
        end
        local seenTargetTypes = {}
        local normalizedTargetTypes = {}
        for _, targetType in ipairs(rawDecision.matched_target_types) do
            local shouldRejectTargetType
            if targetType ~= "ROCKSTAR_ACCOUNT" then
                shouldRejectTargetType = "CREW"
                if targetType ~= shouldRejectTargetType then
                    goto checkTargetTypeRejection
                end
            end
            shouldRejectTargetType = seenTargetTypes[targetType]
            ::checkTargetTypeRejection::
            if shouldRejectTargetType then
                return false
            end
            seenTargetTypes[targetType] = true
            normalizedTargetTypes[#normalizedTargetTypes + 1] = targetType
        end
        local normalizedTargets = {}
        local coveredTargetTypes = {}
        for _, rawTarget in ipairs(rawDecision.matched_targets) do
            local matchedTargetType = type(rawTarget) == "table" and rawTarget.type or nil
            local matchedTargetId = type(rawTarget) == "table" and KSCanonicalPlayerIdentifier(rawTarget.id) or nil
            if matchedTargetId == nil or seenTargetTypes[matchedTargetType] ~= true or coveredTargetTypes[matchedTargetType] then
                return false
            end
            coveredTargetTypes[matchedTargetType] = true
            normalizedTargets[#normalizedTargets + 1] = { type = matchedTargetType, id = matchedTargetId }
        end
        return {
            schema = 1,
            token = rawDecision.token,
            type = decisionType,
            action_id = rawDecision.action_id,
            revision = rawDecision.revision,
            matched_target_types = normalizedTargetTypes,
            matched_targets = normalizedTargets,
            result = rawDecision.result,
        }
    end

    local function validatePlayerStatusBatchResponse(statusEnvelope, batchRequest)
        local playerStatusEntries = type(statusEnvelope) == "table" and statusEnvelope.player_statuses or nil
        if type(statusEnvelope) ~= "table" or tonumber(statusEnvelope.player_status_batch_schema) ~= 1 or tonumber(statusEnvelope.load_generation) ~= batchRequest.loadGeneration or type(playerStatusEntries) ~= "table" or #playerStatusEntries > batchRequest.count or tonumber(statusEnvelope.expires_at_ms or 0) <= getCurrentEpochMs() then
            return nil, "invalid-envelope"
        end
        local validatedEntries = {}
        local seenPlayerIds = {}
        for _, statusEntry in ipairs(playerStatusEntries) do
            local entryPlayerId = type(statusEntry) == "table" and tonumber(statusEntry.player_id) or nil
            local requestedPlayer = entryPlayerId and batchRequest.requested[entryPlayerId] or nil
            local entryKScriptRole = type(statusEntry) == "table" and statusEntry.kscript_role or nil
            local knownModderReason = type(statusEntry) == "table" and statusEntry.known_modder_reason or nil
            local unavailableReason = type(statusEntry) == "table" and statusEntry.unavailable_reason or nil
            local blacklistDecision = false
            if type(statusEntry) == "table" then
                blacklistDecision = KSNormalizeBlacklistDecision(statusEntry.blacklist_decision)
            end
            local isBlacklistDecisionConsistent = true
            if type(blacklistDecision) == "table" and requestedPlayer == nil then
                isBlacklistDecisionConsistent = false
            elseif type(blacklistDecision) == "table" then
                for _, matchedTarget in ipairs(blacklistDecision.matched_targets) do
                    if matchedTarget.type == "ROCKSTAR_ACCOUNT" and matchedTarget.id ~= requestedPlayer.canonicalId then
                        isBlacklistDecisionConsistent = false
                    elseif matchedTarget.type == "CREW" then
                        if type(requestedPlayer.crew) ~= "table" or matchedTarget.id ~= requestedPlayer.crew.id then
                            isBlacklistDecisionConsistent = false
                        end
                    end
                end
            end
            local invalidEntryError, nilReturnSlotThree, nilReturnSlotFour, nilReturnSlotFive, nilReturnSlotSix, nilReturnSlotSeven, nilReturnSlotEight, nilReturnSlotNine, nilEntriesResult
            if requestedPlayer ~= nil and not seenPlayerIds[entryPlayerId] and entryPlayerId == math.floor(entryPlayerId) and statusEntry.canonical_player_id == requestedPlayer.canonicalId and statusEntry.status_source == "backend" and tonumber(statusEntry.status_version) == 1 and type(statusEntry.available) == "boolean" and type(statusEntry.is_kscript_user) == "boolean" and type(statusEntry.is_blacklisted) == "boolean" and type(statusEntry.is_known_modder) == "boolean" then
                local fieldTypeOrLength = type(statusEntry.is_rockstar_admin)
                if fieldTypeOrLength == "boolean" then
                    if entryKScriptRole ~= nil then
                        if type(entryKScriptRole) ~= "string" then
                            goto rejectInvalidEntry
                        end
                        fieldTypeOrLength = #entryKScriptRole
                        if fieldTypeOrLength > 24 then
                            goto rejectInvalidEntry
                        end
                    end
                    if knownModderReason ~= nil then
                        if type(knownModderReason) ~= "string" then
                            goto rejectInvalidEntry
                        end
                        fieldTypeOrLength = #knownModderReason
                        if fieldTypeOrLength > 96 then
                            goto rejectInvalidEntry
                        end
                    end
                    if unavailableReason ~= nil then
                        if type(unavailableReason) ~= "string" then
                            goto rejectInvalidEntry
                        end
                        fieldTypeOrLength = #unavailableReason
                    end
                    if not (fieldTypeOrLength > 64) and blacklistDecision ~= false and isBlacklistDecisionConsistent and (blacklistDecision == nil or statusEntry.is_blacklisted == true) and not (tonumber(statusEntry.fetched_at_ms or 0) <= 0) then
                        goto acceptValidEntry
                    end
                end
            end
            ::rejectInvalidEntry::
            nilEntriesResult = nil
            invalidEntryError, nilReturnSlotThree, nilReturnSlotFour, nilReturnSlotFive, nilReturnSlotSix, nilReturnSlotSeven, nilReturnSlotEight, nilReturnSlotNine = "invalid-entry"
            do
                return nilEntriesResult, invalidEntryError, nilReturnSlotThree, nilReturnSlotFour, nilReturnSlotFive, nilReturnSlotSix, nilReturnSlotSeven, nilReturnSlotEight, nilReturnSlotNine
            end
            ::acceptValidEntry::
            seenPlayerIds[entryPlayerId] = true
            statusEntry.blacklist_decision = blacklistDecision
            validatedEntries[#validatedEntries + 1] = { playerID = entryPlayerId, canonicalId = requestedPlayer.canonicalId, status = statusEntry }
        end
        return validatedEntries, nil
    end

    local function formatKScriptRoleLabel(backendRoleName)
        local roleDisplayLabels = {
            developer = "K-Script Developer",
            admin = "K-Script Admin",
            moderator = "K-Script Moderator",
            donator = "K-Script Donator",
            user = "K-Script User",
        }
        return roleDisplayLabels[tostring(backendRoleName or "user"):lower()] or roleDisplayLabels.user
    end

    function KSReportBlacklistActionResult(decisionToken, actionOutcome, targetPlayerId, rawRockstarId, resultDetail)
        local canonicalRockstarId = KSCanonicalPlayerIdentifier(rawRockstarId)
        targetPlayerId = tonumber(targetPlayerId)
        if type(decisionToken) ~= "string" or #decisionToken ~= 36 or type(actionOutcome) ~= "string" or canonicalRockstarId == nil or targetPlayerId == nil or targetPlayerId ~= math.floor(targetPlayerId) or targetPlayerId < 0 or targetPlayerId >= 32 then
            return false
        end
        local requestStatus, actionResultResponse = loaderAdapter.request("blacklist.actionResult", {
            decision_token = decisionToken,
            result = actionOutcome,
            player_id = targetPlayerId,
            rockstar_id = canonicalRockstarId,
            detail = type(resultDetail) == "string" and resultDetail:sub(1, 160) or nil,
        }, 10000)
        return requestStatus == "ok"
    end

    function KSIsKScriptRoleDetection(detectionLabel)
        return detectionLabel == "K-Script User"
    end

    local function applyRemotePlayerStatusEntry(validatedEntry, responseExpiresAtMs, pendingRequest)
        local remoteStatusState = KSRemotePlayerStatusState
        local statusPlayerId = validatedEntry.playerID
        local entryCanonicalId = validatedEntry.canonicalId
        local playerStatus = validatedEntry.status
        local requestedPlayer = pendingRequest.requested[statusPlayerId]
        if remoteStatusState.requests[statusPlayerId] ~= pendingRequest or tonumber(loaderAdapter.load_generation) ~= pendingRequest.loadGeneration then
            return false, "stale-response"
        end
        if not playerStatus.available then
            return false, "entry-unavailable"
        end
        local matchedPlayer, matchedGamerInfo, playerName, detectedPlayerKey = getPlayerIfRockstarIdMatches(statusPlayerId, entryCanonicalId)
        if detectedPlayerKey == nil then
            return false, "player-reused"
        end
        local previousServerReason = remoteStatusState.serverReasonByPlayer[statusPlayerId]
        local cachedPlayerStatus = remoteStatusState.byPlayer[statusPlayerId]
        local checkKScriptRoleDetection = KSIsKScriptRoleDetection
        local hasPriorKScriptDetection = checkKScriptRoleDetection == "table" and checkKScriptRoleDetection
        local isKScriptUser = playerStatus.is_kscript_user or hasPriorKScriptDetection
        local storedKScriptRole = playerStatus.kscript_role
        if hasPriorKScriptDetection and not playerStatus.is_kscript_user and type(cachedPlayerStatus) == "table" then
            storedKScriptRole = cachedPlayerStatus.kscript_role
        end
        local detectionReason = nil
        if playerStatus.is_kscript_user then
            detectionReason = formatKScriptRoleLabel(playerStatus.kscript_role)
        elseif hasPriorKScriptDetection then
            detectionReason = previousServerReason
        elseif playerStatus.is_rockstar_admin then
            detectionReason = "Rockstar Administrator"
        elseif playerStatus.is_blacklisted then
            detectionReason = "Blacklisted Player"
        elseif playerStatus.is_known_modder then
            if isSupporter or isDev or isAdmin or isModerator then
                detectionReason = "Known Modder (" .. tostring(playerStatus.known_modder_reason or "Unknown"):sub(1, 96) .. ")"
            end
        end
        local existingDetectionReason = detectedPlayerReasons[detectedPlayerKey]
        if detectionReason ~= nil then
            detectedPlayerNames[detectedPlayerKey] = playerName
            detectedPlayerReasons[detectedPlayerKey] = detectionReason
        elseif existingDetectionReason == previousServerReason then
            detectedPlayerNames[detectedPlayerKey] = nil
            detectedPlayerReasons[detectedPlayerKey] = nil
        end
        remoteStatusState.serverReasonByPlayer[statusPlayerId] = detectionReason
        local statusExpiresAtMs = responseExpiresAtMs
        if not isKScriptUser then
            statusExpiresAtMs = math.min(responseExpiresAtMs, getCurrentEpochMs() + NON_KSCRIPT_STATUS_MAX_TTL_MS)
        end
        remoteStatusState.byPlayer[statusPlayerId] = {
            canonical_player_id = entryCanonicalId,
            is_kscript_user = isKScriptUser,
            kscript_role = storedKScriptRole,
            is_blacklisted = playerStatus.is_blacklisted,
            is_known_modder = playerStatus.is_known_modder,
            known_modder_reason = playerStatus.known_modder_reason,
            is_rockstar_admin = playerStatus.is_rockstar_admin,
            fetched_at_ms = playerStatus.fetched_at_ms,
            blacklist_decision = playerStatus.blacklist_decision,
            crew_identity = type(requestedPlayer) == "table" and requestedPlayer.crew or nil,
            expires_at_ms = statusExpiresAtMs,
        }
        remoteStatusState.failures[statusPlayerId] = nil
        if playerStatus.is_blacklisted then
            blacklistRIDList[entryCanonicalId] = true
        end
        remoteStatusState.lastDiagnostic = "applied"
        if detectionReason ~= nil and detectionReason ~= previousServerReason then
            notify(("Detected %s as %s!"):format(playerName, detectionReason))
        end
        return true, "applied"
    end

    local function scheduleRemotePlayerStatusBatchDrain()
        local statusState = KSRemotePlayerStatusState
        if statusState.drainScheduled or statusState.inFlight ~= nil then
            return true
        end
        statusState.drainScheduled = true
        if Script.QueueJob(function()
            yieldClampedMs(PLAYER_STATUS_DRAIN_START_DELAY_MS)
            local drainStartMs = getCurrentEpochMs()
            if statusState.lastDispatchAtMs > 0 and drainStartMs < statusState.lastDispatchAtMs + PLAYER_STATUS_MIN_DISPATCH_INTERVAL_MS then
                Script.Yield(3000)
            end
            statusState.drainScheduled = false
            if statusState.inFlight ~= nil then
                return
            end
            local loadGeneration = tonumber(loaderAdapter.load_generation)
            local pendingPlayerIds = {}
            for pendingPlayerId in pairs(statusState.pending) do
                pendingPlayerIds[#pendingPlayerIds + 1] = pendingPlayerId
            end
            table.sort(pendingPlayerIds)
            local batchPlayerItems = {}
            local requestedEntries = {}
            for _, playerId in ipairs(pendingPlayerIds) do
                if #batchPlayerItems >= PLAYER_STATUS_MAX_BATCH_SIZE then
                    break
                end
                local pendingEntry = statusState.pending[playerId]
                local matchedPlayer = nil
                local observedSocialClubName = nil
                if pendingEntry then
                    local foundPlayer, matchedGamerInfo, resolvedPlayerName = getPlayerIfRockstarIdMatches(playerId, pendingEntry.canonicalId)
                    observedName = resolvedPlayerName
                    matchedPlayer = foundPlayer
                end
                if pendingEntry and matchedPlayer ~= nil then
                    local batchItem = { player_id = playerId, rockstar_id = pendingEntry.canonicalId }
                    if loaderAdapter.player_identity_observations == true then
                        local socialClubDisplayName = KSIdentityDisplayText(observedSocialClubName, 96)
                        if socialClubDisplayName == nil then
                            socialClubDisplayName = "Unknown"
                        end
                        local crewIdentity = KSResolveCrewIdentity(playerId, pendingEntry.canonicalId, false)
                        pendingEntry.crew = crewIdentity
                        batchItem.social_club_name = socialClubDisplayName
                        if crewIdentity ~= nil then
                            batchItem.crew = crewIdentity
                        end
                    end
                    batchPlayerItems[#batchPlayerItems + 1] = batchItem
                    requestedEntries[playerId] = pendingEntry
                    statusState.pending[playerId] = nil
                elseif matchedPlayer == nil then
                    statusState.pending[playerId] = nil
                end
            end
            if #batchPlayerItems == 0 then
                statusState.lastDiagnostic = "batch-empty"
                return
            end
            statusState.sequence = statusState.sequence + 1
            local inFlightBatch = {
                sequence = statusState.sequence,
                loadGeneration = loadGeneration,
                sessionSequence = statusState.sequence,
                requested = requestedEntries,
                count = #batchPlayerItems,
            }
            statusState.inFlight = inFlightBatch
            for requestedPlayerId in pairs(requestedEntries) do
                statusState.requests[requestedPlayerId] = inFlightBatch
            end
            statusState.metrics.batchRequests = statusState.metrics.batchRequests + 1
            statusState.metrics.lastBatchSize = #batchPlayerItems
            local visiblePlayerCount = 0
            if loaderAdapter.debug == true then
                for playerSlot = 0, 31 do
                    if Players.GetById(playerSlot) ~= nil then
                        visiblePlayerCount = visiblePlayerCount + 1
                    end
                end
            end
            statusState.metrics.lastVisibleCount = visiblePlayerCount
            local batchItemCountText = tostring(#batchPlayerItems)
            statusState.lastDiagnostic = "batch-in-flight:" .. batchItemCountText
            local dispatchedAtMs = getCurrentEpochMs()
            statusState.lastDispatchAtMs = dispatchedAtMs
            logPlayerStatusDebug("dispatch", {
                visible = visiblePlayerCount,
                items = #batchPlayerItems,
                outstanding = 1,
                queued = #pendingPlayerIds,
                generation = loadGeneration,
            })
            local requestPayload = {
                players = batchPlayerItems,
                local_rockstar_id = getLocalPlayerCanonicalRockstarId(),
                social_club_name = resolveAndCacheSocialClubName(),
                edition = isGameVersionEnhanced and "enhanced" or "legacy",
            }

            local function handleBatchResponse(responseStatus, responseBody)
                if inFlightBatch.completionClaimed then
                    return
                end
                inFlightBatch.completionClaimed = true
                local latencyMs = math.max(0, getCurrentEpochMs() - dispatchedAtMs)
                statusState.metrics.lastLatencyMs = latencyMs
                local validatedEntries = nil
                local failureReason = "request-failed"
                local isCurrentBatch = statusState.inFlight == inFlightBatch
                if responseStatus == "ok" and isCurrentBatch then
                    validatedEntries, normalizeError = validatePlayerStatusBatchResponse(responseBody, inFlightBatch)
                end
                local appliedByPlayerId = {}
                local appliedCount = 0
                if validatedEntries ~= nil then
                    for _, statusEntry in ipairs(validatedEntries) do
                        local isApplied = applyRemotePlayerStatusEntry(statusEntry, tonumber(responseBody.expires_at_ms), inFlightBatch)
                        appliedByPlayerId[statusEntry.playerID] = isApplied == true
                        if isApplied == true then
                            appliedCount = appliedCount + 1
                        end
                    end
                end
                local retryCount = 0
                local completedAtMs = getCurrentEpochMs()
                for batchPlayerId, requestedEntry in pairs(requestedEntries) do
                    if statusState.requests[batchPlayerId] == inFlightBatch then
                        statusState.requests[batchPlayerId] = nil
                    end
                    local attemptCount = tonumber(requestedEntry.attempt) or 1
                    if not appliedByPlayerId[batchPlayerId] and isCurrentBatch and getPlayerIfRockstarIdMatches(batchPlayerId, requestedEntry.canonicalId) ~= nil then
                        if attemptCount < PLAYER_STATUS_MAX_ATTEMPTS then
                            statusState.pending[batchPlayerId] = { canonicalId = requestedEntry.canonicalId, attempt = attemptCount + 1 }
                            retryCount = retryCount + 1
                            statusState.metrics.retries = statusState.metrics.retries + 1
                        else
                            statusState.failures[batchPlayerId] = {
                                canonicalId = requestedEntry.canonicalId,
                                nextAttemptMs = completedAtMs + PLAYER_STATUS_FAILURE_BACKOFF_MS,
                            }
                        end
                    end
                end
                if statusState.inFlight == inFlightBatch then
                    statusState.inFlight = nil
                end
                local completionDiagnostic
                if isCurrentBatch then
                    if validatedEntries ~= nil then
                        completionDiagnostic = "batch-complete"
                        if completionDiagnostic then
                            goto recordDiagnostic
                        end
                    end
                    completionDiagnostic = tostring(failureReason)
                    if completionDiagnostic then
                        goto recordDiagnostic
                    end
                end
                completionDiagnostic = "stale-response"
                ::recordDiagnostic::
                statusState.lastDiagnostic = completionDiagnostic
                logPlayerStatusDebug("complete", {
                    items = #batchPlayerItems,
                    applied = appliedCount,
                    retries = retryCount,
                    latency_ms = latencyMs,
                    result = statusState.lastDiagnostic,
                })
                if next(statusState.pending) ~= nil then
                    scheduleRemotePlayerStatusBatchDrain()
                end
            end

            if type(loaderAdapter.request_async) == "function" then
                local bridgeRequestId = loaderAdapter.request_async("players.status.getBatch", requestPayload, 10000, handleBatchResponse)
                if bridgeRequestId ~= nil then
                    inFlightBatch.bridgeRequestId = bridgeRequestId
                    return
                end
                handleBatchResponse("unavailable", nil)
                return
            end
            local syncResponseStatus, syncResponseBody = loaderAdapter.request("players.status.getBatch", requestPayload, 10000)
            handleBatchResponse(syncResponseStatus, syncResponseBody)
        end) == false then
            statusState.drainScheduled = false
            statusState.lastDiagnostic = "queue-rejected"
            return false
        end
        return true
    end

    local function requestRemotePlayerStatusLookup(playerId, rockstarId)
        playerId = tonumber(playerId)
        if playerId == nil or playerId < 0 or playerId >= 32 or playerId ~= math.floor(playerId) then
            return false
        end
        local canonicalRockstarId = KSCanonicalPlayerIdentifier(rockstarId)
        if canonicalRockstarId == nil or getPlayerIfRockstarIdMatches(playerId, canonicalRockstarId) == nil then
            return false
        end
        local statusState = KSRemotePlayerStatusState
        statusState.metrics.generated = statusState.metrics.generated + 1
        local cachedStatus = statusState.byPlayer[playerId]
        local nowMs = getCurrentEpochMs()
        if type(cachedStatus) == "table" and cachedStatus.canonical_player_id ~= canonicalRockstarId then
            KSClearRemotePlayerStatus(playerId)
            cachedStatus = nil
        end
        if type(cachedStatus) == "table" and nowMs < tonumber(cachedStatus.expires_at_ms or 0) then
            if cachedStatus.is_kscript_user then
                local roleLabel = formatKScriptRoleLabel(cachedStatus.kscript_role)
                statusState.serverReasonByPlayer[playerId] = roleLabel
                local matchedPlayer, matchedGamerInfo, playerName, detectedPlayerKey = getPlayerIfRockstarIdMatches(playerId, canonicalRockstarId)
                if detectedPlayerKey ~= nil then
                    local previousReason = detectedPlayerReasons[detectedPlayerKey]
                    detectedPlayerNames[detectedPlayerKey] = playerName
                    detectedPlayerReasons[detectedPlayerKey] = roleLabel
                    if previousReason ~= roleLabel then
                        notify(("Detected %s as %s!"):format(playerName, roleLabel))
                    end
                end
            end
            statusState.metrics.coalesced = statusState.metrics.coalesced + 1
            return true
        end
        if type(cachedStatus) == "table" and nowMs > tonumber(cachedStatus.expires_at_ms or 0) + PLAYER_STATUS_EXPIRED_PURGE_GRACE_MS then
            clearServerPlayerStatusEntry(playerId)
        end
        local failureRecord = statusState.failures[playerId]
        if type(failureRecord) == "table" and failureRecord.canonicalId == canonicalRockstarId and nowMs < tonumber(failureRecord.nextAttemptMs or 0) then
            statusState.metrics.coalesced = statusState.metrics.coalesced + 1
            return true
        end
        statusState.failures[playerId] = nil
        if statusState.requests[playerId] ~= nil then
            statusState.metrics.coalesced = statusState.metrics.coalesced + 1
            return true
        end
        local pendingEntry = statusState.pending[playerId]
        if pendingEntry and pendingEntry.canonicalId == canonicalRockstarId then
            statusState.metrics.coalesced = statusState.metrics.coalesced + 1
            return true
        end
        statusState.pending[playerId] = { canonicalId = canonicalRockstarId, attempt = 1 }
        local pendingCount = 0
        for _ in pairs(statusState.pending) do
            pendingCount = pendingCount + 1
        end
        statusState.metrics.maxPending = math.max(statusState.metrics.maxPending, pendingCount)
        statusState.lastDiagnostic = "queued"
        return scheduleRemotePlayerStatusBatchDrain()
    end

    function LookupModderReasonForPlayer(playerId, rockstarId)
        if not loaderAdapter then
            return false
        end
        return requestRemotePlayerStatusLookup(tonumber(playerId), rockstarId)
    end

    function runHardwareIdCheck(hardwareInfoPayload)
        if loaderAdapter then
            return
        end

        function request(hardwareCheckPayload)
            local apiKey, apiKeyGeneration = ApiKeyForRequest("HardwareCheck", SOCIALCLUB.SC_ACCOUNT_INFO_GET_NICKNAME())
            if not apiKey then
                return
            end
            local curlRequest = Curl.Easy()
            curlRequest:Setopt(eCurlOption.CURLOPT_URL, backendBaseUrl .. "/retired")
            curlRequest:AddHeader("Content-Type: application/json")
            AddApiKeyHeader(curlRequest, apiKey)
            curlRequest:AddHeader("User-Agent: " .. ks_uid_user_agent())
            local encodedPayload = json.encode(hardwareCheckPayload)
            curlRequest:Setopt(eCurlOption.CURLOPT_POST, 1)
            curlRequest:Setopt(eCurlOption.CURLOPT_POSTFIELDS, encodedPayload)
            curlRequest:AddHeader(("X-C-20: %s"):format(__a25))
            curlRequest:Setopt(eCurlOption.CURLOPT_USERAGENT, ks_uid_user_agent())
            curlRequest:DisableErrorLog()
            curlRequest:Perform()
            if not waitForCurlFinished("hardware", curlRequest, 5) then
                requestScriptUnload()
                return
            end
            local curlCode, responseBody = curlRequest:GetResponse()
            if HandleApiKeyFailureResponse("HardwareCheck", SOCIALCLUB.SC_ACCOUNT_INFO_GET_NICKNAME(), responseBody, apiKeyGeneration, function()
                request(hardwareCheckPayload)
            end) then
                return
            end
            if curlCode ~= eCurlCode.CURLE_OK or not responseBody then
                if isAdmin then
                    Logger.LogError(("(HardwareCheck) CURL Code: %i"):format(curlCode))
                end
                requestScriptUnload()
                return
            end
            local decodedResponse = nil
            pcall(function()
                decodedResponse = json.decode(responseBody)
            end)
            local hardwareStatus = decodedResponse and decodedResponse.s or nil
            if not hardwareStatus then
                Logger.LogError("K-Script: Invalid HW check response, unloading...")
                requestScriptUnload()
                return
            end
            if hardwareStatus == "a" then
                return
            end
            if hardwareStatus == "b" then
                GUI.AddToast("K-Script Security", "Hardware mismatch detected!\nPlease contact support for a HWID reset! unloading...", 20000, eToastPos.TOP_RIGHT)
                Logger.LogError("K-Script: Hardware mismatch detected.")
                requestScriptUnload()
                return
            end
            if hardwareStatus == "c" then
                GUI.AddToast("K-Script Security", "Hardware mismatch detected!\nPlease contact support for a HWID reset! unloading...", 20000, eToastPos.TOP_RIGHT)
                Logger.LogError("K-Script: Hardware locked.")
                Logger.LogError("Access denied. Contact support.")
                requestScriptUnload()
                return
            end
            if isAdmin or isDev then
                Logger.LogError(("K-Script: Unknown HW check status '%s'"):format(tostring(hardwareStatus)))
            end
            requestScriptUnload()
        end

        Script.QueueJob(request, hardwareInfoPayload)
    end

    attempts = 0

    function SendToDiscord(logChannel, logMessage, senderNickname, senderRockstarId, useLocalIdentity)
        if loaderAdapter then
            local normalizedChannel = tostring(logChannel or ""):lower():gsub("[^a-z0-9]+", "_"):gsub("^_+", ""):gsub("_+$", "")
            if not ({
                lol = true,
                nogger = true,
                china = true,
                eventhook = true,
                blacklist_detected = true,
                admin_detected = true,
                status = true,
                fuckniggers = true,
            })[normalizedChannel] or type(logMessage) ~= "string" then
                return false
            end
            local sanitizedMessage = logMessage:gsub("@everyone", "[everyone]"):gsub("@here", "[here]"):gsub("<@&%d+>", "[role]")
            return LogFeatureAction(normalizedChannel == "lol" and "player_feature_invoked" or "feature_button_pressed", {
                feature_id = normalizedChannel == "lol" and "legacy_player_action" or "legacy_" .. normalizedChannel,
                module_id = "legacy_webhook_bridge",
                source = "runtime_module",
                target_scope = normalizedChannel == "lol" and "selected_player" or "session",
                result = "executed",
                legacy_channel = normalizedChannel,
                legacy_action_line = sanitizedMessage,
            })
        end
        if useLocalIdentity == nil then
            useLocalIdentity = true
        end
        if useLocalIdentity then
            senderNickname = SOCIALCLUB.SC_ACCOUNT_INFO_GET_NICKNAME()
            senderRockstarId = getLocalRockstarId()
        end

        function request(channelName, messageText, nickname, rockstarId)
            local webhookApiKey, apiKeyGeneration = ApiKeyForRequest("SendToDiscord", nickname)
            if not webhookApiKey then
                return
            end
            local webhookCurl = Curl.Easy()
            webhookCurl:Setopt(eCurlOption.CURLOPT_URL, backendBaseUrl .. "/retired")
            webhookCurl:AddHeader("Content-Type: application/json")
            AddApiKeyHeader(webhookCurl, webhookApiKey)
            webhookCurl:AddHeader(("X-C-20: %s"):format(__a25))
            local reportedRockstarId = rockstarId or "unknown_rid"
            if useLocalIdentity and reportedRockstarId:find("Error") then
                reportedRockstarId = "hb_Error"
            end
            local webhookPayload = {
                discord_payload = {
                    content = ("```%s```"):format(messageText),
                    username = "K-Script Log Info",
                    avatar_url = "https://c.wallhere.com/photos/5b/87/2560x1600_px_Grand_Theft_Auto_V_logo-564561.jpg!d",
                },
                client_name = ("%s(%i)"):format(storedSCName or "Unknown", Cherax.GetUID()),
                rockstar_id = tostring(reportedRockstarId),
                cherax_uid = Cherax.GetUID(),
            }
            local payloadJson = json.encode(webhookPayload)
            webhookCurl:Setopt(eCurlOption.CURLOPT_POSTFIELDS, payloadJson)
            webhookCurl:Setopt(eCurlOption.CURLOPT_POST, 1)
            webhookCurl:Setopt(eCurlOption.CURLOPT_USERAGENT, ks_uid_user_agent())
            webhookCurl:DisableErrorLog()
            webhookCurl:Perform()
            if not waitForCurlFinished("webhookProxy", webhookCurl, 10) then
                attempts = attempts + 1
                if attempts <= 3 then
                    Script.QueueJob(request, channelName, messageText, nickname, rockstarId)
                end
                return
            end
            local curlResult, responseBody = webhookCurl:GetResponse()
            if externalTamperDetected then
                Logger.LogError("K-Script: integrity check failed.")
                KSRuntimeTerminalViolation("external_runtime_asset_tamper")
                return
            end
            if HandleApiKeyFailureResponse("SendToDiscord", nickname, responseBody, apiKeyGeneration, function()
                request(channelName, messageText, nickname, rockstarId)
            end) then
                return
            end
            if curlResult ~= eCurlCode.CURLE_OK then
                if isAdmin then
                    Logger.LogError("K-Script: security report failed.")
                end
                if attempts <= 3 then
                    attempts = attempts + 1
                    Script.QueueJob(request, channelName, messageText, nickname, rockstarId)
                    return
                end
                Logger.LogError("K-Script: Fatal Error Occurred (STD), unloading...")
                requestScriptUnload()
                return
            end
            if responseBody:find('%"e%"%s*:%s*%"p1') then
                Logger.LogError("Suspicious Activity detected!")
                KSRuntimeTerminalViolation("runtime_response_integrity_violation")
                return
            elseif ResponseHasErrorMarker(responseBody) then
                if isAdmin then
                    Logger.LogError("K-Script: security report failed.")
                end
                if attempts <= 3 then
                    attempts = attempts + 1
                    Script.QueueJob(request, channelName, messageText, nickname, rockstarId)
                    return
                end
                Logger.LogError("K-Script: Fatal Error #2 Occurred, unloading...")
                if responseBody:find("Unauthorized") then
                    Logger.LogError("K-Script: session expired.")
                    FuckTheNiggersGame()
                    return
                end
                requestScriptUnload()
                return
            end
            attempts = 0
            Script.Yield(0)
            return
        end

        Script.QueueJob(request, logChannel, logMessage, senderNickname, senderRockstarId)
    end

    function notifyUnload(logChannel, logMessage, senderNickname)
        if loaderAdapter then
            return
        end
        local unloadApiKey = ApiKeyForRequest("notifyUnload", senderNickname)
        if not unloadApiKey then
            return
        end
        local unloadCurl = Curl.Easy()
        unloadCurl:Setopt(eCurlOption.CURLOPT_URL, backendBaseUrl .. "/retired")
        unloadCurl:AddHeader("Content-Type: application/json")
        AddApiKeyHeader(unloadCurl, unloadApiKey)
        unloadCurl:AddHeader(("X-C-20: %s"):format(__a25))
        local hasRockstarIdError = false
        local localRockstarId = getLocalRockstarId()
        if localRockstarId:find("Error:") then
            hasRockstarIdError = true
        end
        local unloadPayloadJson = ('{"discord_payload": {"content": "```%s```", "username": "K-Script Log Info", "avatar_url": "https://c.wallhere.com/photos/5b/87/2560x1600_px_Grand_Theft_Auto_V_logo-564561.jpg!d"}, "client_name": "%s(%i)", "rockstar_id": "%s"}'):format(logMessage, senderNickname or "Unknown", Cherax.GetUID(), hasRockstarIdError and 1234567890 or localRockstarId)
        unloadCurl:Setopt(eCurlOption.CURLOPT_POSTFIELDS, unloadPayloadJson)
        unloadCurl:Setopt(eCurlOption.CURLOPT_POST, 1)
        unloadCurl:Setopt(eCurlOption.CURLOPT_USERAGENT, ks_uid_user_agent())
        unloadCurl:DisableErrorLog()
        unloadCurl:Perform()
        while not unloadCurl:GetFinished() do
            if ShouldUnload() then
                return
            end
            Script.Yield(10)
        end
    end

    function intToIp(packedAddress)
        local fourthOctet = packedAddress % 256
        packedAddress = (packedAddress - fourthOctet) / 256
        local thirdOctet = packedAddress % 256
        packedAddress = (packedAddress - thirdOctet) / 256
        local secondOctet = packedAddress % 256
        return string.format("%d.%d.%d.%d", (packedAddress - secondOctet) / 256 % 256, secondOctet, thirdOctet, fourthOctet)
    end

    local discordRpcModuleId = "m1"

    local function getDiscordRpcExports()
        local discordRpcModule = type(KSModules) == "table" and type(KSModules.loaded) == "table" and KSModules.loaded[discordRpcModuleId] or nil
        return type(discordRpcModule) == "table" and discordRpcModule.exports or nil
    end

    function EnableDiscordRPC(...)
        local rpcEnableArgs = table.pack(...)
        if type(KSModules) ~= "table" or type(KSModules.ensureAsync) ~= "function" then
            return false
        end
        return KSModules.ensureAsync(discordRpcModuleId, false, nil, function(rpcExports)
            if type(rpcExports) ~= "table" or type(rpcExports.EnableDiscordRPC) ~= "function" then
                return
            end
            if not pcall(rpcExports.EnableDiscordRPC, table.unpack(rpcEnableArgs, 1, rpcEnableArgs.n)) and type(KSModules.clear) == "function" then
                KSModules.clear(discordRpcModuleId, "rpc enable error")
            end
        end)
    end

    function DisableDiscordRPC(...)
        local rpcExports = getDiscordRpcExports()
        if type(rpcExports) == "table" and type(rpcExports.DisableDiscordRPC) == "function" then
            local disableOk, disableResult = pcall(rpcExports.DisableDiscordRPC, ...)
            if disableOk then
                return disableResult
            end
            if type(KSModules.clear) == "function" then
                KSModules.clear(discordRpcModuleId, "rpc disable error")
            end
        end
        return true
    end

    toasts = {}
    overflowQueue = {}
    nextToastId = 1
    downloadUrlTexture = "https://kyuubii.dev/cherax/lua/kyuubii.png"
    textureName = "kyuubii.png"
    QueueKScriptTextureAsset(downloadUrlTexture, textureName)
    Titlecolor = FeatAdd(Utils.Joaat("TitleColor"), "Title Color", eFeatureType.InputColor4, "Color of the toast title")
    messagecolor = FeatAdd(Utils.Joaat("MessageColor"), "Message Color", eFeatureType.InputColor4, "Color of the toast message")
    local toastTitleColorFeat = Titlecolor
    toastTitleColorFeat.SetColor(toastTitleColorFeat, 255, 255, 255, 255)
    local toastMessageColorFeat = messagecolor
    toastMessageColorFeat.SetColor(toastMessageColorFeat, 255, 255, 255, 255)
    presetToggle = FeatAdd(Utils.Joaat("ToggleOption"), "Use Preset Position", eFeatureType.Toggle, "Use a preset anchor position")
    local presetPositionToggleFeat = presetToggle
    presetPositionToggleFeat.SetBoolValue(presetPositionToggleFeat, true)
    positionOptions = { "Top Center", "Bottom Center", "Left Middle", "Right Middle" }
    toastPosition = FeatAdd(Utils.Joaat("ToastPresetPos"), "Toast Position", eFeatureType.Combo, "Preset anchor position")
    local toastPositionComboForList = toastPosition
    toastPositionComboForList.SetList(toastPositionComboForList, positionOptions)
    local toastPositionComboForIndex = toastPosition
    toastPositionComboForIndex.SetListIndex(toastPositionComboForIndex, 0)
    toastXOffset = FeatAdd(Utils.Joaat("ToastXOffset"), "X Offset", eFeatureType.SliderFloat, "Manual X position")
    toastYOffset = FeatAdd(Utils.Joaat("ToastYOffset"), "Y Offset", eFeatureType.SliderFloat, "Manual Y position")
    local toastXOffsetSliderForMin = toastXOffset
    toastXOffsetSliderForMin.SetMinValue(toastXOffsetSliderForMin, 0.0)
    local toastXOffsetSliderForMax = toastXOffset
    toastXOffsetSliderForMax.SetMaxValue(toastXOffsetSliderForMax, 8192.0)
    local toastYOffsetSliderForMin = toastYOffset
    toastYOffsetSliderForMin.SetMinValue(toastYOffsetSliderForMin, 0.0)
    local toastYOffsetSliderForMax = toastYOffset
    toastYOffsetSliderForMax.SetMaxValue(toastYOffsetSliderForMax, 8192.0)
    fadeOutDuration = FeatAdd(Utils.Joaat("FadeOutDuration"), "Fade Out Duration", eFeatureType.SliderFloat, "How long the fade-out takes")
    local fadeOutDurationSliderForMin = fadeOutDuration
    fadeOutDurationSliderForMin.SetMinValue(fadeOutDurationSliderForMin, 0.1)
    local fadeOutDurationSliderForMax = fadeOutDuration
    fadeOutDurationSliderForMax.SetMaxValue(fadeOutDurationSliderForMax, 5.0)
    local fadeOutDurationSliderForDefault = fadeOutDuration
    fadeOutDurationSliderForDefault.SetFloatValue(fadeOutDurationSliderForDefault, 2.0)
    progressBgColor = FeatAdd(Utils.Joaat("ProgressBarBG"), "Progress Bar Background", eFeatureType.InputColor4, "Progress bar background color")
    progressFgColor = FeatAdd(Utils.Joaat("ProgressBarFG"), "Progress Bar Fill", eFeatureType.InputColor4, "Progress bar fill color")
    local progressBarBgColorFeat = progressBgColor
    progressBarBgColorFeat.SetColor(progressBarBgColorFeat, 0, 0, 0, 255)
end
local progressBarFillColorFeat = progressFgColor
progressBarFillColorFeat.SetColor(progressBarFillColorFeat, 255, 0, 0, 255)
ToastColor = FeatAdd(Utils.Joaat("ToastBG"), "Toast Background", eFeatureType.InputColor4, "Toast background color")
local toastBackgroundColorFeat = ToastColor
toastBackgroundColorFeat.SetColor(toastBackgroundColorFeat, 0, 0, 0, 255)
local toastAnchorGlobalEnv = _ENV
anchorY = nil
toastAnchorGlobalEnv.anchorX = nil
local TOAST_SIZE_SCALE = 0.7

function updateToastAnchors()
    local displayWidth, displayHeight = ImGui.GetDisplaySize()
    if presetToggle:IsToggled() then
        local presetIndex = toastPosition:GetListIndex() or 0
        if presetIndex == 0 then
            anchorX = displayWidth / 2
            anchorY = displayHeight * 0.05
        elseif presetIndex == 1 then
            anchorX = displayWidth / 2
            anchorY = displayHeight * 0.85
        elseif presetIndex == 2 then
            anchorX = displayWidth * 0.1
            anchorY = displayHeight / 2
        elseif presetIndex == 3 then
            anchorX = displayWidth * 0.9
            anchorY = displayHeight / 2
        end
    else
        anchorX = toastXOffset:GetFloatValue()
        anchorY = toastYOffset:GetFloatValue()
    end
end

function formatToastMessage(baseMessage, repeatCount)
    if (repeatCount or 1) > 1 then
        return string.format("%s (%dx)", baseMessage, repeatCount)
    end
    return baseMessage
end

function calcTextWidth(measuredText)
    local textWidth, textHeight = ImGui.CalcTextSize(measuredText or "")
    return textWidth or 0
end

local function clampToastPositionValue(toastCoordinate, lowerBound, upperBound)
    if upperBound < lowerBound then
        return lowerBound
    end
    if toastCoordinate < lowerBound then
        return lowerBound
    end
    if upperBound < toastCoordinate then
        return upperBound
    end
    return toastCoordinate
end

local function calcToastScreenMargin(screenWidth)
    return math.max(screenWidth * 0.025, 18)
end

local function getActiveToastPresetIndex()
    if presetToggle and presetToggle:IsToggled() and toastPosition then
        return toastPosition:GetListIndex() or 0
    end
    return nil
end

function calcToastMaxWidth(screenWidth, screenHeight)
    local screenMargin = calcToastScreenMargin(screenWidth)
    local preferredMaxWidth = math.min(screenWidth * 0.82, 920)
    local availableWidth = screenWidth - screenMargin * 2
    local presetIndex = getActiveToastPresetIndex()
    if anchorX then
        if presetIndex == 2 then
            availableWidth = screenWidth - anchorX - screenMargin
        elseif presetIndex == 3 then
            availableWidth = anchorX - screenMargin
        else
            availableWidth = 2 * math.min(anchorX - screenMargin, screenWidth - anchorX - screenMargin)
        end
    end
    local boundedAvailableWidth = math.max(260, availableWidth)
    return math.max(260, math.min(preferredMaxWidth, boundedAvailableWidth))
end

function wrapToastText(toastText, maxLineWidth)
    toastText = tostring(toastText or "")
    local wrappedLines = {}
    if maxLineWidth <= 0 then
        return wrappedLines
    end

    local function wrapParagraph(paragraph)
        local currentLine = ""
        if paragraph == "" then
            table.insert(wrappedLines, "")
            return
        end
        for word in paragraph:gmatch("%S+") do
            local candidateLine = currentLine == "" and word or currentLine .. " " .. word
            local candidateWidth, candidateHeight = ImGui.CalcTextSize(candidateLine)
            if candidateWidth <= maxLineWidth then
                currentLine = candidateLine
            elseif currentLine ~= "" then
                table.insert(wrappedLines, currentLine)
                currentLine = word
            else
                local wordChunk = ""
                for charIndex = 1, #word do
                    local wordChar = word:sub(charIndex, charIndex)
                    local candidateChunk = wordChunk .. wordChar
                    local chunkWidth, chunkHeight = ImGui.CalcTextSize(candidateChunk)
                    if chunkWidth <= maxLineWidth then
                        wordChunk = candidateChunk
                    else
                        if wordChunk ~= "" then
                            table.insert(wrappedLines, wordChunk)
                        end
                        wordChunk = wordChar
                    end
                end
                currentLine = wordChunk
            end
        end
        if currentLine ~= "" then
            table.insert(wrappedLines, currentLine)
        end
    end

    for rawLine in (toastText:gsub("\r\n", "\n"):gsub("\r", "\n") .. "\n"):gmatch("(.-)\n") do
        wrapParagraph(rawLine)
    end
    if #wrappedLines == 0 then
        table.insert(wrappedLines, "")
    end
    return wrappedLines
end

function calcToastMetrics(toast, screenWidth, screenHeight)
    local titleText = tostring(toast.title or "")
    local messageText = tostring(toast.message or "")
    local singleLineMessage = messageText:gsub("%s+", " ")
    local titleWidth, titleHeight = ImGui.CalcTextSize(titleText)
    local messageWidth, messageHeight = ImGui.CalcTextSize(singleLineMessage)
    if not titleWidth then
        titleWidth = 0
    end
    if not titleHeight then
        titleHeight = 0
    end
    if not messageHeight then
        messageHeight = titleHeight
    end
    if not messageWidth then
        messageWidth = 0
    end
    local paddingX = math.max(screenWidth * 0.015 * TOAST_SIZE_SCALE, 12)
    local paddingY = math.max(screenHeight * 0.01 * TOAST_SIZE_SCALE, 8)
    local titleMessageGap = math.max(screenHeight * 0.004 * TOAST_SIZE_SCALE, 5)
    local lineHeight = math.max(titleHeight, messageHeight, 14)
    local fontSafetyMargin = math.max(lineHeight * 0.35, 8)
    local imageSize = math.max(screenHeight * 0.045 * TOAST_SIZE_SCALE, lineHeight * 2)
    local minToastWidth = math.max(imageSize + paddingX * 3 + 170, 280)
    local maxToastWidth = math.max(minToastWidth, calcToastMaxWidth(screenWidth, screenHeight))
    local widestTextWidth = math.max(titleWidth, messageWidth)
    local toastWidth = math.max(minToastWidth, math.min(imageSize + paddingX + widestTextWidth + paddingX * 2, maxToastWidth))
    local textWrapWidth = math.max(toastWidth - imageSize - paddingX * 3, 1)
    local titleLines = wrapToastText(titleText, textWrapWidth)
    local messageLines = wrapToastText(messageText, textWrapWidth)
    return {
        w = toastWidth,
        h = math.max(paddingY * 2 + (#titleLines * lineHeight + titleMessageGap + #messageLines * lineHeight) + fontSafetyMargin, paddingY * 2 + imageSize, 64),
        imgSize = imageSize,
        padX = paddingX,
        padY = paddingY,
        gapY = titleMessageGap,
        lineH = lineHeight,
        titleH = titleHeight,
        msgH = messageHeight,
        titleLines = titleLines,
        msgLines = messageLines,
        fontSafetyY = fontSafetyMargin,
    }
end

function calcToastWidth(toast, screenWidth, screenHeight)
    return calcToastMetrics(toast, screenWidth, screenHeight).w
end

function getBasePos(screenWidth, screenHeight, toastWidth)
    local screenMargin = calcToastScreenMargin(screenWidth)
    if anchorX and anchorY then
        local toastPresetIndex = getActiveToastPresetIndex()
        if toastPresetIndex == 2 then
            return clampToastPositionValue(anchorX, screenMargin, screenWidth - toastWidth - screenMargin), anchorY
        elseif toastPresetIndex == 3 then
            return clampToastPositionValue(anchorX - toastWidth, screenMargin, screenWidth - toastWidth - screenMargin), anchorY
        end
        return clampToastPositionValue(anchorX - toastWidth / 2, screenMargin, screenWidth - toastWidth - screenMargin), anchorY
    end
    return clampToastPositionValue(toastXOffset:GetFloatValue(), screenMargin, screenWidth - toastWidth - screenMargin), toastYOffset:GetFloatValue()
end

function fitsScreen(toastX, toastY, toastWidth, toastHeight, screenWidth, screenHeight)
    return toastX >= 0 and toastY >= 0
end

function packColor(red, green, blue, alpha)
    alpha = math.floor(math.max(0, math.min(255, alpha)))
    red = math.floor(math.max(0, math.min(255, red)))
    local clampedGreen = math.floor(math.max(0, math.min(255, green)))
    return alpha * 16777216 + math.floor(math.max(0, math.min(255, blue))) * 65536 + clampedGreen * 256 + red
end

local function getToastTimeSeconds()
    if type(Time) == "table" and type(Time.GetEpocheMs) == "function" then
        local convertToNumber = tonumber
        local rawEpochMs = Time.GetEpocheMs()
        local epochMs = convertToNumber(rawEpochMs)
        if epochMs ~= nil then
            return epochMs / 1000.0
        end
    end
    if type(os) == "table" and type(os.clock) == "function" then
        return os.clock()
    end
    return 0
end

function addToast(toastMessage)
    local nowSeconds = getToastTimeSeconds()
    toastMessage = tostring(toastMessage or "")
    local loggedMessage = toastMessage
    local existingToast = nil
    for _, activeToast in ipairs(toasts) do
        if (activeToast.baseMessage or activeToast.message) == toastMessage then
            existingToast = activeToast
            break
        end
    end
    if not existingToast then
        for _, queuedToast in ipairs(overflowQueue) do
            if (queuedToast.baseMessage or queuedToast.message) == toastMessage then
                existingToast = queuedToast
                break
            end
        end
    end
    if existingToast then
        existingToast.baseMessage = existingToast.baseMessage or toastMessage
        existingToast.count = (existingToast.count or 1) + 1
        existingToast.message = formatToastMessage(existingToast.baseMessage, existingToast.count)
        loggedMessage = existingToast.message
        existingToast.alpha = 1.0
        existingToast.progress = 0.0
        existingToast.startTime = nowSeconds
        existingToast.fadeCompleteTime = nil
    else
        table.insert(overflowQueue, {
            id = nextToastId,
            title = "K-Script",
            baseMessage = toastMessage,
            count = 1,
            message = toastMessage,
            startTime = nowSeconds,
            texture = toastTexture,
            alpha = 1.0,
            progress = 0.0,
            fadeCompleteTime = nil,
        })
        nextToastId = nextToastId + 1
    end
    Logger.Log(eLogColor.GREEN, "K-Script", loggedMessage)
end

function drawToasts()
    local nowSeconds = getToastTimeSeconds()
    local displayWidth, displayHeight = ImGui.GetDisplaySize()
    local toastSpacing = displayHeight * 0.012 * TOAST_SIZE_SCALE
    local progressBarHeight = math.max(displayHeight * 0.004 * TOAST_SIZE_SCALE, 2)
    local cornerRounding = displayHeight * 0.012 * TOAST_SIZE_SCALE
    local visibleDurationSeconds = 8.0
    local fadeDurationSeconds = fadeOutDuration:GetFloatValue()
    local postFadeRemoveDelay = 0.15

    local function getStackDirection(baseY, toastHeight)
        if baseY > displayHeight * 0.66 and baseY > displayHeight - baseY - toastHeight then
            return -1
        end
        return 1
    end

    local function calcStackedToastY(firstToastY, slotIndex, stackDirection)
        local stackedY = firstToastY
        for precedingIndex = 1, slotIndex - 1 do
            local precedingToast = toasts[precedingIndex]
            if precedingToast then
                stackedY = stackedY + (calcToastMetrics(precedingToast, displayWidth, displayHeight).h + toastSpacing) * stackDirection
            end
        end
        return stackedY
    end

    local function countFittingToastSlots(stackBaseX, stackBaseY, pendingToastWidth, pendingToastHeight, slotDirection)
        local fittingSlotCount = 0
        local slotIndex = 1
        while true do
            local slotY = calcStackedToastY(stackBaseY, slotIndex, slotDirection)
            if fitsScreen(stackBaseX, slotY, pendingToastWidth, pendingToastHeight, displayWidth, displayHeight) then
                fittingSlotCount = fittingSlotCount + 1
                slotIndex = slotIndex + 1
            else
                break
            end
            if slotIndex > 50 then
                break
            end
        end
        return fittingSlotCount
    end

    local function promoteQueuedToasts()
        while #overflowQueue > 0 do
            local queuedMetrics = calcToastMetrics(overflowQueue[1], displayWidth, displayHeight)
            local queuedWidth = queuedMetrics.w
            local queuedHeight = queuedMetrics.h
            local queuedBaseX, queuedBaseY = getBasePos(displayWidth, displayHeight, queuedWidth)
            local queuedStackDirection = getStackDirection(queuedBaseY, queuedHeight)
            local availableSlotCount = countFittingToastSlots(queuedBaseX, queuedBaseY, queuedWidth, queuedHeight, queuedStackDirection)
            local nextSlotIndex = #toasts + 1
            if availableSlotCount < nextSlotIndex then
                break
            end
            local nextSlotY = calcStackedToastY(queuedBaseY, nextSlotIndex, queuedStackDirection)
            if fitsScreen(queuedBaseX, nextSlotY, queuedWidth, queuedHeight, displayWidth, displayHeight) then
                table.insert(toasts, table.remove(overflowQueue, 1))
            else
                break
            end
        end
    end

    if #toasts == 0 then
        if #overflowQueue == 0 then
            return
        end
        local firstQueuedMetrics = calcToastMetrics(overflowQueue[1], displayWidth, displayHeight)
        local firstQueuedWidth = firstQueuedMetrics.w
        local firstQueuedHeight = firstQueuedMetrics.h
        local firstQueuedX, firstQueuedY = getBasePos(displayWidth, displayHeight, firstQueuedWidth)
        if fitsScreen(firstQueuedX, firstQueuedY, firstQueuedWidth, firstQueuedHeight, displayWidth, displayHeight) then
            table.insert(toasts, table.remove(overflowQueue, 1))
        else
            return
        end
    end
    promoteQueuedToasts()
    local toastBgRed, toastBgGreen, toastBgBlue = ToastColor:GetColor()
    local progressBgRed, progressBgGreen, progressBgBlue = progressBgColor:GetColor()
    local progressFgRed, progressFgGreen, progressFgBlue = progressFgColor:GetColor()
    local titleRed, titleGreen, titleBlue = Titlecolor:GetColor()
    local messageRed, messageGreen, messageBlue = messagecolor:GetColor()
    local firstToastHeight = calcToastMetrics(toasts[1], displayWidth, displayHeight).h
    local firstToastMetrics
    local firstToastBaseX, firstToastBaseY = getBasePos(displayWidth, displayHeight, firstToastMetrics.w)
    local stackDirection = getStackDirection(firstToastBaseY, firstToastHeight)
    local toastIndex = 1
    while toastIndex <= #toasts do
        local toast = toasts[toastIndex]
        local toastMetrics = calcToastMetrics(toast, displayWidth, displayHeight)
        local toastHeight = toastMetrics.h
        local toastAge = nowSeconds - toast.startTime
        toast.progress = math.min(toastAge / visibleDurationSeconds, 1.0)
        local toastWidth = toastMetrics.w
        local toastBaseX, toastBaseY = getBasePos(displayWidth, displayHeight, toastWidth)
        local stackedY = calcStackedToastY(toastBaseY, toastIndex, stackDirection)
        if not fitsScreen(toastBaseX, stackedY, toastWidth, toastHeight, displayWidth, displayHeight) then
            for overflowToastIndex = #toasts, toastIndex, -1 do
                table.insert(overflowQueue, 1, table.remove(toasts, overflowToastIndex))
            end
            break
        end
        local fadeAlpha = 1.0
        local fadeScale = 1.0
        local slideOffsetX = 0.0
        local isRemoved = false
        if toast.progress >= 1.0 then
            local fadeProgress = math.min((toastAge - visibleDurationSeconds) / fadeDurationSeconds, 1.0)
            local easedFade = fadeProgress * fadeProgress * (3.0 - 2.0 * fadeProgress)
            fadeAlpha = 1.0 - easedFade
            fadeScale = 1.0 - easedFade * 0.4
            slideOffsetX = -(toastWidth * 1.1) * easedFade
            if easedFade >= 1.0 then
                if not toast.fadeCompleteTime then
                    toast.fadeCompleteTime = nowSeconds
                elseif postFadeRemoveDelay < nowSeconds - toast.fadeCompleteTime then
                    table.remove(toasts, toastIndex)
                    isRemoved = true
                    promoteQueuedToasts()
                end
            end
        end
        toast.alpha = fadeAlpha
        if not isRemoved then
            local alphaByte = math.floor(fadeAlpha * 255)
            local drawWidth = toastWidth
            local drawHeight = toastHeight * fadeScale
            local iconSize = toastMetrics.imgSize * fadeScale
            local paddingX = toastMetrics.padX * fadeScale
            local titleMessageGap = toastMetrics.gapY * fadeScale
            local lineHeight = toastMetrics.lineH * fadeScale
            local scaledBarHeight = progressBarHeight * fadeScale
            local scaledRounding = cornerRounding * fadeScale
            local drawX = toastBaseX + slideOffsetX
            local drawY = stackedY + (toastHeight - drawHeight) * 0.5
            ImGui.AddRectFilled(drawX, drawY, drawX + drawWidth, drawY + drawHeight, toastBgRed, toastBgGreen, toastBgBlue, alphaByte, scaledRounding)
            ImGui.AddLine(drawX + scaledRounding, drawY + 1, drawX + drawWidth - scaledRounding, drawY + 1, 255, 255, 255, math.floor(alphaByte * 0.08))
            local barInset = scaledRounding
            local barLeft = drawX + barInset
            local barRight = drawX + drawWidth - barInset
            local barTop = drawY + 2 * fadeScale
            local barBottom = barTop + scaledBarHeight
            local barRounding = scaledBarHeight * 0.5
            ImGui.AddRectFilled(barLeft, barTop, barRight, barBottom, progressBgRed, progressBgGreen, progressBgBlue, alphaByte, barRounding)
            local barFillWidth = (barRight - barLeft) * toast.progress
            if barFillWidth >= barRounding * 2 then
                ImGui.AddRectFilled(barLeft, barTop, barLeft + barFillWidth, barBottom, progressFgRed, progressFgGreen, progressFgBlue, alphaByte, barRounding)
            end
            local iconTexture = toast.texture or toastTexture
            if iconTexture then
                local iconTextureHandle = iconTexture:GetCurrent()
                if iconTextureHandle then
                    local iconX = drawX + paddingX
                    local iconY = drawY + (drawHeight - iconSize) * 0.5
                    local iconTint = packColor(255, 255, 255, alphaByte)
                    ImGui.AddImage(iconTextureHandle, iconX, iconY, iconX + iconSize, iconY + iconSize, 0, 0, 1, 1, iconTint)
                end
            end
            local textX = drawX + paddingX + iconSize + paddingX
            local titleLines = toastMetrics.titleLines or { tostring(toast.title or "") }
            local messageLines = toastMetrics.msgLines or { tostring(toast.message or "") }
            local titleTextY = drawY + (drawHeight - (#titleLines * lineHeight + titleMessageGap + #messageLines * lineHeight)) * 0.5 + toastMetrics.fontSafetyY * 0.25 * fadeScale
            for _, titleLine in ipairs(titleLines) do
                ImGui.AddText(textX, titleTextY, titleLine, titleRed, titleGreen, titleBlue, alphaByte)
                titleTextY = titleTextY + lineHeight
            end
            local messageTextY = titleTextY + titleMessageGap
            for _, messageLine in ipairs(messageLines) do
                ImGui.AddText(textX, messageTextY, messageLine, messageRed, messageGreen, messageBlue, alphaByte)
                messageTextY = messageTextY + lineHeight
            end
            if toast.renewing and toast.renewStartTime then
                local flashRampTime = 0.2
                local flashGapTime = 0.3
                local flashTotalTime = flashRampTime * 2 + flashGapTime
                local renewElapsed = nowSeconds - toast.renewStartTime
                if flashTotalTime > renewElapsed then
                    local flashCycleTime = renewElapsed % flashTotalTime
                    local flashIntensity
                    if flashRampTime > flashCycleTime then
                        flashIntensity = 1.0 - (math.cos(flashCycleTime / flashRampTime * math.pi) + 1) / 2
                    elseif flashCycleTime < flashRampTime + flashGapTime then
                        flashIntensity = 0.0
                    else
                        flashIntensity = (math.cos((flashCycleTime - flashRampTime - flashGapTime) / flashRampTime * math.pi) + 1) / 2
                    end
                    ImGui.AddRectFilled(drawX, drawY, drawX + drawWidth, drawY + drawHeight, 255, 255, 255, math.floor(flashIntensity * 60 * fadeAlpha), scaledRounding)
                else
                    toast.renewing = false
                end
            end
            toastIndex = toastIndex + 1
        end
    end
end

function renderToasts()
    updateToastAnchors()
    if #toasts > 0 or #overflowQueue > 0 then
        drawToasts()
    end
end

function notify(toastMessage)
    addToast(toastMessage)
end

local featureTransitionsToggle = FeatAdd(Utils.Joaat("FeatureTransitions"), "Feature Transitions", eFeatureType.Toggle, "Enable smooth feature transitions when switching tabs.", function(transitionsFeature)
    if not transitionsFeature:IsToggled() then
        cursorPos = -1.0
    end
end)
featureTransitionsToggle.Toggle(featureTransitionsToggle)
local transitionPositionSlider = FeatAdd(Utils.Joaat("FeatureTransitionsPosition"), "Position", eFeatureType.SliderInt, "Set the position where the transitions start.")
local transitionPositionSliderLimited = transitionPositionSlider.SetLimitValues(transitionPositionSlider, -500, -10)
transitionPositionSliderLimited.SetIntValue(transitionPositionSliderLimited, -100)
local transitionSpeedSlider = FeatAdd(Utils.Joaat("FeatureTransitionsTransitionSpeed"), "Transition Speed", eFeatureType.SliderFloat, "Set the speed between the transitions.")
local transitionSpeedSliderLimited = transitionSpeedSlider.SetLimitValues(transitionSpeedSlider, 0.025, 0.6)
transitionSpeedSliderLimited.SetFloatValue(transitionSpeedSliderLimited, 0.07)
local fadeContentToggle = FeatAdd(Utils.Joaat("FadeContent"), "Fade Content", eFeatureType.Toggle, "Enable smooth fades when switching tabs.", function(fadeContentFeature)
    if not fadeContentFeature:IsToggled() then
        fadeContentAlpha = 1.0
    end
end)
fadeContentToggle.Toggle(fadeContentToggle, true)
local fadeSpeedSlider = FeatAdd(Utils.Joaat("FadeContentFadeSpeed"), "Fade Speed", eFeatureType.SliderFloat, "Set the fade speed.")
local fadeSpeedSliderLimited = fadeSpeedSlider.SetLimitValues(fadeSpeedSlider, 0.1, 2.0)
fadeSpeedSliderLimited.SetFloatValue(fadeSpeedSliderLimited, 0.75)
local fadeInitialValueSlider = FeatAdd(Utils.Joaat("FadeContentFadeInitialValue"), "Fade Initial Value", eFeatureType.SliderFloat, "Set the value at which the fade gets reset.")
local fadeInitialValueSliderLimited = fadeInitialValueSlider.SetLimitValues(fadeInitialValueSlider, 0.0, 0.99)
fadeInitialValueSliderLimited.SetFloatValue(fadeInitialValueSliderLimited, 0.125)

function tableContainsValue(searchList, searchValue)
    if searchList == nil or searchValue == nil then
        return false
    end
    for _, listEntry in ipairs(searchList) do
        if listEntry == searchValue then
            return true
        end
    end
    return false
end

local onlineUserJoinButtons = {
    Features = {},
    LegacyUsers = { PublicUsers = {}, NonPublicUsers = {} },
    EnhancedUsers = { PublicUsers = {}, NonPublicUsers = {} },
}
UpdateFeatureButtonsFirstRun = true

function UpdateFeatureButtons(onlineUserList)
    local onlineRidByFeatureHash = {}
    local uniqueUsers = {}
    local seenCurrentRids = {}
    for _, listedUser in ipairs(onlineUserList) do
        if not seenCurrentRids[listedUser.current_rid] then
            table.insert(uniqueUsers, listedUser)
            seenCurrentRids[listedUser.current_rid] = true
        end
    end
    onlineUserJoinButtons.RenderTableMap = onlineUserJoinButtons.RenderTableMap or {}

    local function assignFeatureToRenderBucket(movedFeatureHash, targetBucket)
        local previousBucket = onlineUserJoinButtons.RenderTableMap[movedFeatureHash]
        if previousBucket == targetBucket then
            return
        end
        if previousBucket then
            for entryIndex, entryFeatureHash in ipairs(previousBucket) do
                if entryFeatureHash == movedFeatureHash then
                    table.remove(previousBucket, entryIndex)
                    break
                end
            end
        end
        table.insert(targetBucket, movedFeatureHash)
        onlineUserJoinButtons.RenderTableMap[movedFeatureHash] = targetBucket
    end

    for _, onlineUser in ipairs(uniqueUsers) do
        local currentRid = onlineUser.current_rid
        if onlineUser.current_rid ~= getLocalRockstarId() then
            local joinFeatureHash = Utils.Joaat(currentRid)
            local nameSuffixPattern, extraMatchArgOne, extraMatchArgTwo, extraMatchArgThree, legacyPublicUsers, extraMatchArgFour, extraMatchArgFive, extraMatchArgSix, extraMatchArgSeven, extraMatchArgEight, extraMatchArgNine, extraMatchArgTen = "^(.-)%s*%b()$"
            local matchSubject
            local displayName = onlineUser.client_name.match(matchSubject, nameSuffixPattern, extraMatchArgOne, extraMatchArgTwo, extraMatchArgThree, legacyPublicUsers, extraMatchArgFour, extraMatchArgFive, extraMatchArgSix, extraMatchArgSeven, extraMatchArgEight, extraMatchArgNine, extraMatchArgTen) or onlineUser.client_name
            onlineRidByFeatureHash[joinFeatureHash] = currentRid
            if isDev and onlineUser.join_rid ~= onlineUser.current_rid then
                displayName = displayName .. " Alt Join"
            end
            local existingFeature = onlineUserJoinButtons.Features[joinFeatureHash]
            local wasStaleFeatureRemoved = false
            if existingFeature and (existingFeature.SessionType ~= onlineUser.SessionType or existingFeature.GameVersion ~= onlineUser.GameVersion) then
                FeatureMgr.RemoveFeature(joinFeatureHash)
                onlineUserJoinButtons.Features[joinFeatureHash] = nil
                wasStaleFeatureRemoved = true
            end
            local isPublicSession = onlineUser.SessionType == "Public"
            local renderBucket = nil
            if onlineUser.GameVersion == "Legacy" then
                if isPublicSession then
                    legacyPublicUsers = onlineUserJoinButtons.LegacyUsers.PublicUsers
                    renderBucket = legacyPublicUsers or renderBucket
                end
                if not legacyPublicUsers then
                    renderBucket = onlineUserJoinButtons.LegacyUsers.NonPublicUsers
                end
            elseif not isPublicSession or not onlineUserJoinButtons.EnhancedUsers.PublicUsers then
                renderBucket = onlineUserJoinButtons.EnhancedUsers.NonPublicUsers
            end
            if existingFeature and not wasStaleFeatureRemoved then
                existingFeature.SessionType = onlineUser.SessionType or "Unknown"
                assignFeatureToRenderBucket(joinFeatureHash, renderBucket)
            elseif onlineUser.isInPool == 1 or isDev or isAdmin or isModerator then
                local buttonLabel = string.format("Join %s (%s - BE: %s)", displayName, onlineUser.SessionType or "Unknown", onlineUser.be_enabled == 1 and "Yes" or "No")
                FeatAdd(joinFeatureHash, buttonLabel, eFeatureType.Button, "", function(buttonFeature)
                    if isGameVersionEnhanced then
                        local targetGameVersion = onlineUser.GameVersion
                        local legacyVersionName = "Legacy"
                        if targetGameVersion == legacyVersionName then
                            if targetGameVersion == legacyVersionName then
                                notify(("Cannot Join %s due to Game Version mismatch!\nYou must be on %s to join them."):format(displayName, onlineUser.GameVersion))
                                return
                            end
                            goto beginJoinAttempt
                        end
                    end
                    if not isGameVersionEnhanced and onlineUser.GameVersion == "Enhanced" then
                        notify(("Cannot Join %s due to Game Version mismatch!\nYou must be on %s to join them."):format(displayName, onlineUser.GameVersion))
                        return
                    end
                    ::beginJoinAttempt::
                    notify(("Trying to Join K-Script User %s..."):format(displayName))
                    FeatureMgr.GetFeatureByName("Notify On Player Join"):SetValue(false)
                    FeatureMgr.GetFeatureByName("Notify On Player Leave"):SetValue(false)
                    local preJoinX, preJoinY, preJoinZ = ENTITY.GET_ENTITY_COORDS(getPlayerPed())
                    FeatureMgr.GetFeature(Utils.Joaat("SCAPIRID")):SetIntValue(onlineUser.join_rid)
                    for _ = 0, 10 do
                        FeatureMgr.GetFeatureByName("Join Rockstar Id"):TriggerCallback()
                        Script.Yield(0)
                    end
                    FeatureMgr.GetFeature(Utils.Joaat("SCAPIRID")):SetIntValue(12345)
                    local joinDeadlineMs = Time.GetEpocheMs() + 15000
                    while not maintransitionActive and joinDeadlineMs > Time.GetEpocheMs() and not ShouldUnload() do
                        Script.Yield(2000)
                    end
                    if not maintransitionActive and joinDeadlineMs > Time.GetEpocheMs() then
                        notify("K-Script User Join Failed: mainTransition not launched.")
                        return
                    end
                    if joinDeadlineMs > Time.GetEpocheMs() then
                        notify("Joined player successfully!")
                    else
                        notify("Player join timed out.")
                        return
                    end
                    SendToDiscord("status", ("%s(%i) is joining K-Script User %s"):format(SOCIALCLUB.SC_ACCOUNT_INFO_GET_NICKNAME(), Cherax.GetUID(), displayName))
                    FeatureMgr.GetFeatureByName("Notify On Player Join"):SetValue(true)
                    FeatureMgr.GetFeatureByName("Notify On Player Leave"):SetValue(true)
                    while getTransitionState() ~= 66 and not ShouldUnload() do
                        Script.Yield(100)
                    end
                    for _ = 0, 5 do
                        ENTITY.SET_ENTITY_COORDS_NO_OFFSET(getPlayerPed(), preJoinX, preJoinY, preJoinZ, false, false, false)
                    end
                end, true)
                onlineUserJoinButtons.Features[joinFeatureHash] = {
                    rid = currentRid,
                    name = displayName,
                    SessionType = onlineUser.SessionType or "Unknown",
                    GameVersion = onlineUser.GameVersion,
                    inPool = onlineUser.isInPool,
                }
                assignFeatureToRenderBucket(joinFeatureHash, renderBucket)
                if notifyEnabled and not wasStaleFeatureRemoved and not UpdateFeatureButtonsFirstRun and (isAdmin or isModerator) then
                    if displayName == "CMsgJoinRequest" then
                        notify(("K-Script Developer %s came online."):format(displayName))
                    else
                        notify(("K-Script User %s came online. (%s)"):format(displayName, onlineUser.GameVersion))
                    end
                end
            end
        end
        Script.Yield(0)
    end
    UpdateFeatureButtonsFirstRun = false
    for trackedFeatureHash, trackedFeature in pairs(onlineUserJoinButtons.Features) do
        if onlineRidByFeatureHash[trackedFeatureHash] then
            if trackedFeature.inPool then
                goto continueTrackedFeatures
            end
            if isDev then
                goto continueTrackedFeatures
            end
            if isAdmin then
                goto continueTrackedFeatures
            end
            if isModerator then
                goto continueTrackedFeatures
            end
        end
        FeatureMgr.RemoveFeature(trackedFeatureHash)
        if notifyEnabled and (isAdmin or isModerator) then
            if trackedFeature.name == "CMsgJoinRequest" then
                notify(("K-Script Developer %s has gone offline. (%s)"):format(trackedFeature.name, trackedFeature.GameVersion))
            else
                notify(("K-Script User %s has gone offline. (%s)"):format(trackedFeature.name, trackedFeature.GameVersion))
            end
        end
        local assignedBucket = onlineUserJoinButtons.RenderTableMap[trackedFeatureHash]
        if assignedBucket then
            for bucketIndex, bucketFeatureHash in ipairs(assignedBucket) do
                if bucketFeatureHash == trackedFeatureHash then
                    table.remove(assignedBucket, bucketIndex)
                    break
                end
            end
            onlineUserJoinButtons.RenderTableMap[trackedFeatureHash] = nil
        end
        onlineUserJoinButtons.Features[trackedFeatureHash] = nil
        ::continueTrackedFeatures::
    end
end

retryAttempt = 0
KSOnlineUsersV3State = type(KSOnlineUsersV3State) == "table" and KSOnlineUsersV3State or {
    nextAtMs = 0,
    loopRegistered = false,
    loopGeneration = nil,
    jobScheduled = false,
    supported = nil,
}

local function pollOnlineUsersViaLoader()
    if KSOnlineUsersV3State.supported == false then
        return false
    end
    local nowMs = math.floor(getMonotonicSeconds() * 1000)
    if nowMs < (tonumber(KSOnlineUsersV3State.nextAtMs) or 0) then
        return true
    end
    KSOnlineUsersV3State.nextAtMs = nowMs + 60000
    if ShouldUnload() then
        return
    end
    local currentRockstarId = KSCanonicalPlayerIdentifier(getLocalRockstarId())
    if currentRockstarId == nil then
        return
    end
    local joinRockstarId = currentRockstarId
    local primaryRidMaskFeature = FeatureMgr.GetFeature(238683028)
    local isRidMaskEnabled = 872788705
    local secondaryRidMaskFeature = FeatureMgr.GetFeature(isRidMaskEnabled)
    local isPrimaryMaskToggled = false
    if primaryRidMaskFeature then
        isRidMaskEnabled = primaryRidMaskFeature:IsToggled()
        if isRidMaskEnabled then
            isPrimaryMaskToggled = true
        end
    end
    if isPrimaryMaskToggled or secondaryRidMaskFeature then
        if not isPrimaryMaskToggled then
            isRidMaskEnabled = secondaryRidMaskFeature:IsToggled()
        end
        if isRidMaskEnabled then
            for playerSlot = 0, 31 do
                if playerSlot ~= GTA.GetLocalPlayerId() then
                    local sessionPlayer = Players.GetById(playerSlot)
                    local playerGamerInfo = sessionPlayer ~= nil and sessionPlayer:GetGamerInfo() or nil
                    local playerRockstarId = playerGamerInfo ~= nil and KSCanonicalPlayerIdentifier(playerGamerInfo.RockstarId) or nil
                    if playerRockstarId ~= nil then
                        joinRockstarId = playerRockstarId
                        break
                    end
                end
            end
        end
    end
    local sessionTypeKey = ({
        Public = "public",
        ["Invite Only"] = "invite_only",
        ["Closed Friends"] = "closed_friends",
        ["Closed Crew"] = "closed_crew",
        Solo = "solo",
        ["Story Mode"] = "story_mode",
    })[getSessionType()]
    if sessionTypeKey == nil then
        return
    end
    local requestStatus, onlineUsersResponse, requestErrorCode = loaderAdapter.request(getBackendRequestSpec("onlineUsers").command, {
        current_rockstar_id = currentRockstarId,
        join_rockstar_id = joinRockstarId,
        social_club_name = resolveAndCacheSocialClubName(),
        edition = isGameVersionEnhanced and "enhanced" or "legacy",
        session_type = sessionTypeKey,
        in_pool = isInPool == true,
        battleye_enabled = isBattlEyeEnabled(Cherax.GetEdition()) == true,
    }, getBackendRequestSpec("onlineUsers").timeoutMs)
    if requestStatus == "invalid" and requestErrorCode == "INVALID_COMMAND" then
        KSOnlineUsersV3State.supported = false
        return
    end
    if requestStatus ~= "ok" or type(onlineUsersResponse) ~= "table" or tonumber(onlineUsersResponse.online_users_schema) ~= 1 or type(onlineUsersResponse.users) ~= "table" or tonumber(onlineUsersResponse.load_generation) ~= tonumber(loaderAdapter.load_generation) or #onlineUsersResponse.users > 64 then
        return
    end
    KSOnlineUsersV3State.supported = true
    local gameVersionByEdition = { legacy = "Legacy", enhanced = "Enhanced" }
    local sessionTypeByKey = {
        public = "Public",
        invite_only = "Invite Only",
        closed_friends = "Closed Friends",
        closed_crew = "Closed Crew",
        solo = "Solo",
        story_mode = "Story Mode",
    }
    local validatedUsers = {}
    for _, userRecord in ipairs(onlineUsersResponse.users) do
        local userCurrentRid = type(userRecord) == "table" and KSCanonicalPlayerIdentifier(userRecord.current_rockstar_id) or nil
        local userJoinRid = type(userRecord) == "table" and KSCanonicalPlayerIdentifier(userRecord.join_rockstar_id) or nil
        local userGameVersion = type(userRecord) == "table" and gameVersionByEdition[userRecord.edition] or nil
        local userSessionType = type(userRecord) == "table" and sessionTypeByKey[userRecord.session_type] or nil
        if userCurrentRid ~= nil and userJoinRid ~= nil and userGameVersion ~= nil and userSessionType ~= nil and type(userRecord.client_name) == "string" and #userRecord.client_name > 0 and #userRecord.client_name <= 80 and type(userRecord.in_pool) == "boolean" and type(userRecord.battleye_enabled) == "boolean" then
            validatedUsers[#validatedUsers + 1] = {
                client_name = userRecord.client_name,
                current_rid = userCurrentRid,
                isInPool = userRecord.in_pool and 1 or 0,
                GameVersion = userGameVersion,
                SessionType = userSessionType,
                join_rid = userJoinRid,
                be_enabled = userRecord.battleye_enabled and 1 or 0,
            }
        end
    end
    if isSupporter then
        UpdateFeatureButtons(validatedUsers)
    end
    return true
end

function KSStartOnlineUsersV3Loop()
    local loadGeneration = tonumber(loaderAdapter and loaderAdapter.load_generation)
    if loadGeneration == nil then
        return false
    end
    if KSOnlineUsersV3State.loopRegistered == true and KSOnlineUsersV3State.loopGeneration == loadGeneration then
        return true
    end
    if not isTableOrUserdata(Script) or type(Script.RegisterLooped) ~= "function" then
        return false
    end
    local registeredGeneration = loadGeneration
    local loopRegistration = Script.RegisterLooped(function()
        if not ShouldUnload() and not KSOnlineUsersV3State.jobScheduled and tonumber(loaderAdapter and loaderAdapter.load_generation) == registeredGeneration and math.floor(getMonotonicSeconds() * 1000) >= (tonumber(KSOnlineUsersV3State.nextAtMs) or 0) then
            KSOnlineUsersV3State.jobScheduled = true
            local queuedJob = Script.QueueJob(function()
                if not ShouldUnload() and tonumber(loaderAdapter and loaderAdapter.load_generation) == registeredGeneration then
                    pollOnlineUsersViaLoader()
                end
                KSOnlineUsersV3State.jobScheduled = false
            end)
            if queuedJob == false or queuedJob == nil then
                KSOnlineUsersV3State.jobScheduled = false
                KSOnlineUsersV3State.nextAtMs = 0
            end
        end
    end)
    if loopRegistration == false or loopRegistration == nil then
        return false
    end
    KSOnlineUsersV3State.loopRegistered = true
    KSOnlineUsersV3State.loopGeneration = loadGeneration
    KSOnlineUsersV3State.jobScheduled = false
    KSOnlineUsersV3State.nextAtMs = 0
    KSOnlineUsersV3State.supported = nil
    return true
end

function GetOnlineUserInfo()
    if loaderAdapter then
        return pollOnlineUsersViaLoader()
    end

    function request()
        local apiKey, apiKeyGeneration = ApiKeyForRequest("GetOnlineUserInfo", SOCIALCLUB.SC_ACCOUNT_INFO_GET_NICKNAME())
        if not apiKey then
            return
        end
        local onlineInfoCurl = Curl.Easy()
        onlineInfoCurl:Setopt(eCurlOption.CURLOPT_URL, backendBaseUrl .. "/retired")
        onlineInfoCurl:AddHeader("Content-Type: application/json")
        AddApiKeyHeader(onlineInfoCurl, apiKey)

        local function disableRidMaskToggles()
            local primaryRidMaskToggle = FeatureMgr.GetFeature(238683028)
            local secondaryRidMaskToggle = FeatureMgr.GetFeature(872788705)
            if primaryRidMaskToggle and secondaryRidMaskToggle then
                primaryRidMaskToggle:SetBoolValue(false):OnClick()
                secondaryRidMaskToggle:SetBoolValue(false):OnClick()
            end
        end

        local onlineInfoPayload = {
            IsInPool = tostring(isInPool),
            game_version = getGameVersion(isGameVersionEnhanced),
            session_type = getSessionType(),
            rockstar_id = (function()
                local primaryRidMaskFeature = FeatureMgr.GetFeature(238683028)
                local secondaryRidMaskFeature = FeatureMgr.GetFeature(872788705)
                if primaryRidMaskFeature and primaryRidMaskFeature:IsToggled() then
                    if NETWORK.NETWORK_GET_NUM_CONNECTED_PLAYERS() > 1 then
                        for playerId = 0, 31 do
                            if playerId ~= GTA.GetLocalPlayerId() then
                                local remotePlayer = Players.GetById(playerId)
                                if remotePlayer then
                                    local remoteGamerInfo = remotePlayer:GetGamerInfo()
                                    if not remoteGamerInfo then
                                        disableRidMaskToggles()
                                        return getLocalRockstarId()
                                    end
                                    return remoteGamerInfo.RockstarId
                                end
                            end
                        end
                    else
                        disableRidMaskToggles()
                        return getLocalRockstarId()
                    end
                elseif secondaryRidMaskFeature then
                    if secondaryRidMaskFeature:IsToggled() then
                        if NETWORK.NETWORK_GET_NUM_CONNECTED_PLAYERS() > 1 then
                            for otherPlayerId = 0, 31 do
                                if otherPlayerId ~= GTA.GetLocalPlayerId() then
                                    local otherPlayer = Players.GetById(otherPlayerId)
                                    if otherPlayer then
                                        local otherGamerInfo = otherPlayer:GetGamerInfo()
                                        if not otherGamerInfo then
                                            disableRidMaskToggles()
                                            return getLocalRockstarId()
                                        end
                                        return otherGamerInfo.RockstarId
                                    end
                                end
                            end
                        else
                            disableRidMaskToggles()
                            return getLocalRockstarId()
                        end
                    end
                else
                    return getLocalRockstarId()
                end
            end)(),
            be_enabled = tostring(isBattlEyeEnabled(Cherax.GetEdition())),
        }
        local onlineInfoJson = json.encode(onlineInfoPayload)
        onlineInfoCurl:Setopt(eCurlOption.CURLOPT_POSTFIELDS, onlineInfoJson)
        onlineInfoCurl:Setopt(eCurlOption.CURLOPT_POST, 1)
        onlineInfoCurl:Setopt(eCurlOption.CURLOPT_USERAGENT, ks_uid_user_agent())
        onlineInfoCurl:AddHeader(("X-C-20: %s"):format(__a25))
        onlineInfoCurl:DisableErrorLog()
        onlineInfoCurl:Perform()
        while not onlineInfoCurl:GetFinished() do
            Script.Yield(5)
        end
        local curlResultCode, responseBody = onlineInfoCurl:GetResponse()
        if HandleApiKeyFailureResponse("GetOnlineUserInfo", SOCIALCLUB.SC_ACCOUNT_INFO_GET_NICKNAME(), responseBody, apiKeyGeneration, request) then
            return
        end
        if curlResultCode ~= eCurlCode.CURLE_OK then
            Logger.LogError("K-Script: Fatal Error on GOUI Occurred, unloading...")
            if isAdmin then
                Logger.LogError("K-Script: online info request failed.")
            end
            if retryAttempt <= 3 then
                retryAttempt = retryAttempt + 1
                Script.QueueJob(request)
                return
            end
            requestScriptUnload()
            return
        end
        if ResponseHasErrorMarker(responseBody) then
            if responseBody:find("Unauthorized") then
                Logger.LogError("K-Script: session expired.")
                FuckTheNiggersGame()
                return
            end
            if retryAttempt <= 3 then
                retryAttempt = retryAttempt + 1
                Script.QueueJob(request)
                return
            end
            requestScriptUnload()
            return
        end
        if not isSupporter and not isAdmin and not isDev then
            return
        end
        local parsedOnlineUsers = {}
        local decodedResponse = json.decode(responseBody)
        if decodedResponse and decodedResponse.u then
            for _, userEntry in ipairs(decodedResponse.u) do
                table.insert(parsedOnlineUsers, {
                    client_name = userEntry.n,
                    current_rid = userEntry.r,
                    isInPool = tonumber(userEntry.p) or 0,
                    GameVersion = userEntry.g,
                    SessionType = userEntry.s,
                    join_rid = userEntry.j,
                    be_enabled = tonumber(userEntry.b) or 0,
                })
            end
        end
        if #parsedOnlineUsers > 0 and isSupporter then
            UpdateFeatureButtons(parsedOnlineUsers)
        end
        retryAttempt = 0
        Script.Yield(0)
    end

    Script.QueueJob(request)
end

local function buildHardwareInfoPayload()
    return {
        cpu = { name = HW_COMPONENTS.CPU_NAME, cores = HW_COMPONENTS.NUM_CPU_PHYS_CORES },
        gpu = { name = HW_COMPONENTS.GPU_NAME, pnpDeviceId = HW_COMPONENTS.GPU_PNP_DEVICE_ID },
        mobo = { model = HW_COMPONENTS.MOBO_NAME },
        bios = { vendor = HW_COMPONENTS.BIOS_VENDOR, manufacturer = HW_COMPONENTS.BASE_BOARD_MANUFA },
        telemetry = {
            cpuSpeed = HW_COMPONENTS.CPU_SPEED,
            gpuDriverName = HW_COMPONENTS.GPU_DRIVER_NAME,
            gpuDirectXVersion = HW_COMPONENTS.GPU_DIRECTX_VERSION,
            biosVersion = HW_COMPONENTS.BIOS_VERSION,
            windowsVersion = HW_COMPONENTS.WINDOWS_VERSION,
        },
    }
end

local hasRunHeartbeatHardwareCheck = false

function Heartbeat()
    if not hasRunHeartbeatHardwareCheck then
        if isSupporter or isAdmin or isDev then
            runHardwareIdCheck(buildHardwareInfoPayload())
            Script.Yield(1000)
        end
        hasRunHeartbeatHardwareCheck = true
    end
    getLocalRockstarId():find("Error")
    local connectedPlayersLabel = string.format("%i/32", NETWORK.NETWORK_GET_NUM_CONNECTED_PLAYERS())
    FetchBlacklistRIDList()
    Script.QueueJob(FetchUserPermissions, true)
    GetOnlineUserInfo()
    Script.Yield(30000)
end

function getGameVersion(isEnhancedEdition)
    if isEnhancedEdition then
        return "Enhanced"
    else
        return "Legacy"
    end
end

function HasDiscordRpcIdentityReady()
    return discordRpcIdentityReady == true
end

function MarkDiscordRpcIdentityReady()
    if discordID == nil then
        discordID = "Discord identity unavailable"
    end
    if discordUserName == nil then
        discordUserName = "error"
    end
    discordRpcIdentityReady = true
end

function PrimeDiscordIdentityForAuth()
    if HasDiscordRpcIdentityReady() then
        return true
    end
    MarkDiscordRpcIdentityReady()
    return true
end

local function toDisplayStringOrNA(rawFieldValue)
    if rawFieldValue == nil or rawFieldValue == "" then
        return "N/A"
    end
    return tostring(rawFieldValue)
end

local SETTINGS_SCHEMA_VERSION = 1
local MAX_SETTINGS_FEATURE_COUNT = 2048
local MAX_SETTINGS_FILE_BYTES = 524288

local function isNumberNotNaN(numberCandidate)
    return type(numberCandidate) == "number" and numberCandidate == numberCandidate
end

local function sanitizeSettingsDocument(settingsDocument)
    if type(settingsDocument) ~= "table" or type(settingsDocument.features) ~= "table" then
        return false, nil, "invalid_document"
    end
    if settingsDocument.schemaVersion ~= nil and settingsDocument.schemaVersion ~= SETTINGS_SCHEMA_VERSION then
        return false, nil, "unsupported_schema"
    end
    local sanitizedFeatures = {}
    local featureCount = 0
    for featureKey, featureEntry in pairs(settingsDocument.features) do
        featureCount = featureCount + 1
        if featureCount > MAX_SETTINGS_FEATURE_COUNT then
            return false, nil, "feature_count_limit"
        end
        if type(featureEntry) ~= "table" or featureEntry.value == nil then
            return false, nil, "invalid_setting_entry"
        end
        if featureKey == "GameInfoDisplayPosX" or featureKey == "GameInfoDisplayPosY" or featureKey == "ModderDisplayPosX" or featureKey == "ModderDisplayPosY" then
            if not isNumberNotNaN(featureEntry.value) then
                return false, nil, "invalid_position"
            end
            sanitizedFeatures[featureKey] = { value = featureEntry.value }
        else
            local featureHash = tonumber(featureKey)
            if featureHash and isNumberNotNaN(featureHash) then
                local flooredFeatureHash = math.floor(featureHash)
                if featureHash == flooredFeatureHash and registeredFeatures.hashAndName[featureHash] ~= nil then
                    local lookupOk, lookedUpFeature, featureType = pcall(function()
                        local resolvedFeature = FeatureMgr.GetFeature(featureHash)
                        return resolvedFeature, resolvedFeature and resolvedFeature:GetType() or nil
                    end)
                    if not lookupOk then
                        return false, nil, "feature_lookup_failed"
                    end
                    local savedValue = featureEntry.value
                    local isSavedValueValid = false
                    if lookedUpFeature == nil then
                        isSavedValueValid = nil
                    end
                    if featureType == eFeatureType.Toggle then
                        isSavedValueValid = type(savedValue) == "boolean"
                    elseif featureType ~= eFeatureType.Combo and featureType ~= eFeatureType.SliderInt and featureType ~= eFeatureType.InputInt then
                        if featureType == eFeatureType.SliderFloat then
                            isSavedValueValid = isNumberNotNaN(savedValue)
                        elseif featureType == eFeatureType.InputText then
                            isSavedValueValid = savedValue:find("\x00", 1, true) == "string" and isSavedValueValid
                        elseif featureType == eFeatureType.InputColor4 then
                            isSavedValueValid = type(savedValue) == "table"
                            local colorChannelCount = 0
                            if isSavedValueValid then
                                for channelIndex, channelValue in pairs(savedValue) do
                                    colorChannelCount = colorChannelCount + 1
                                    if type(channelIndex) ~= "number" or channelIndex < 1 or channelIndex > 4 or channelIndex ~= math.floor(channelIndex) or not isNumberNotNaN(channelValue) or channelValue < 0 or channelValue > 255 then
                                        isSavedValueValid = false
                                        do
                                            break
                                        end
                                    end
                                end
                                if isSavedValueValid then
                                    isSavedValueValid = colorChannelCount == 4
                                end
                            end
                        elseif lookedUpFeature ~= nil then
                            isSavedValueValid = nil
                        end
                    else
                        isSavedValueValid = isNumberNotNaN(savedValue) and savedValue == math.floor(savedValue)
                    end
                    if isSavedValueValid == false then
                        return false, nil, "invalid_setting_value"
                    end
                    if isSavedValueValid == true then
                        sanitizedFeatures[tostring(featureHash)] = { value = savedValue }
                    end
                end
            end
        end
    end
    return true, sanitizedFeatures
end

executingSettingsLoad = false

function loadDefaultConfig()
    executingSettingsLoad = true
    Script.Yield(1000)
    if ShouldUnload() then
        executingSettingsLoad = false
        return false
    end
    local loadCallOk, loadSucceededOrError, loadErrorCode = pcall(function()
        notify("Loading default config...")
        if type(menuRootPath) ~= "string" or menuRootPath == "" or #menuRootPath > 32000 or menuRootPath:find("\x00", 1, true) then
            return false, "invalid_settings_path"
        end
        local configFilePath = menuRootPath .. "\\" .. "DefaultConfig.json"
        local existsCheckOk, configFileExists = pcall(FileMgr.DoesFileExist, configFilePath)
        if not existsCheckOk then
            return false, "settings_exists_check_failed"
        end
        if not configFileExists then
            notify("No saved config found; using defaults.")
            return true
        end
        local readOk, configFileContent = pcall(FileMgr.ReadFileContent, configFilePath)
        if not readOk or type(configFileContent) ~= "string" then
            return false, "settings_read_failed"
        end
        if configFileContent == "" then
            return false, "settings_empty"
        end
        if #configFileContent > MAX_SETTINGS_FILE_BYTES then
            return false, "settings_size_limit"
        end
        local decodeOk, configDocument = pcall(json.decode, configFileContent)
        if not decodeOk then
            return false, "settings_json_invalid"
        end
        local sanitizeOk, validatedFeatures, sanitizeErrorCode = sanitizeSettingsDocument(configDocument)
        if not sanitizeOk then
            return false, sanitizeErrorCode
        end
        configDocument.features = validatedFeatures
        for featureKey, featureSetting in pairs(configDocument.features) do
            local featureHash = tonumber(featureKey)
            if featureHash and type(featureSetting) == "table" and featureSetting.value ~= nil then
                local targetFeature = FeatureMgr.GetFeature(featureHash)
                if targetFeature and registeredFeatures.hashAndName[featureHash] ~= nil then
                    local featureType = targetFeature:GetType()
                    if featureType == eFeatureType.Combo then
                        targetFeature:SetListIndex(tonumber(featureSetting.value) or 0)
                    elseif featureType == eFeatureType.SliderInt then
                        targetFeature:SetIntValue(tonumber(featureSetting.value) or 0)
                    elseif featureType == eFeatureType.InputInt then
                        targetFeature:SetIntValue(tonumber(featureSetting.value) or 0)
                    elseif featureType == eFeatureType.SliderFloat then
                        targetFeature:SetFloatValue((tonumber(featureSetting.value) or 0.0) + 0.0)
                    elseif featureType == eFeatureType.InputText then
                        targetFeature:SetStringValue(tostring(featureSetting.value))
                    elseif featureType == eFeatureType.InputColor4 then
                        if type(featureSetting.value) == "table" then
                            targetFeature:SetColor(tonumber(featureSetting.value[1]) or 0, tonumber(featureSetting.value[2]) or 0, tonumber(featureSetting.value[3]) or 0, tonumber(featureSetting.value[4]) or 255)
                        end
                    end
                end
            end
        end
        for toggleKey, toggleSetting in pairs(configDocument.features) do
            local toggleHash = tonumber(toggleKey)
            if toggleHash and type(toggleSetting) == "table" and toggleSetting.value ~= nil then
                local toggleFeature = FeatureMgr.GetFeature(toggleHash)
                if toggleFeature and registeredFeatures.hashAndName[toggleHash] ~= nil and toggleFeature:GetType() == eFeatureType.Toggle then
                    local shouldBeToggled = toggleSetting.value == true
                    local toggleOk, toggleError = pcall(function()
                        toggleFeature:SetValue(shouldBeToggled):OnClick()
                    end)
                    if not toggleOk and isDev then
                        notify(("Toggle callback failed %s: %s"):format(tostring(toggleHash), tostring(toggleError)))
                    end
                end
            end
        end
        if configDocument.features.GameInfoDisplayPosX then
            if configDocument.features.GameInfoDisplayPosY then
                local gameInfoPosX = tonumber(configDocument.features.GameInfoDisplayPosX.value)
                local gameInfoPosY = tonumber(configDocument.features.GameInfoDisplayPosY.value)
                if gameInfoPosX and gameInfoPosY and gameInfoPosX == gameInfoPosX and gameInfoPosY == gameInfoPosY then
                    local screenWidth, screenHeight = ImGui.GetDisplaySize()
                    local clampedGameInfoX = math.max(0, math.min(math.max(0, screenWidth - 300), gameInfoPosX))
                    local clampedGameInfoY = math.max(0, math.min(math.max(0, screenHeight - 120), gameInfoPosY))
                    StoredPos.GameInfoDisplay = V2.New(clampedGameInfoX, clampedGameInfoY)
                    infowindowPositionSet = false
                elseif isDev then
                    Logger.Log(eLogColor.RED, "K-Script", "Failed to apply saved layout.")
                end
            end
        elseif isDev then
            Logger.Log(eLogColor.RED, "K-Script", "GameInfoDisplayPosX/Y missing from config.")
        end
        if configDocument.features.ModderDisplayPosX then
            if configDocument.features.ModderDisplayPosY then
                local modderPosX = tonumber(configDocument.features.ModderDisplayPosX.value)
                local modderPosY = tonumber(configDocument.features.ModderDisplayPosY.value)
                if modderPosX and modderPosY and modderPosX == modderPosX and modderPosY == modderPosY then
                    local displayWidth, displayHeight = ImGui.GetDisplaySize()
                    local clampedModderX = math.max(0, math.min(math.max(0, displayWidth - 300), modderPosX))
                    local clampedModderY = math.max(0, math.min(math.max(0, displayHeight - 120), modderPosY))
                    StoredPos.ModderDisplay = V2.New(clampedModderX, clampedModderY)
                    windowPositionSet = false
                elseif isDev then
                    Logger.Log(eLogColor.RED, "K-Script", "Failed to apply saved layout.")
                end
            end
        elseif isDev then
            Logger.Log(eLogColor.RED, "K-Script", "ModderDisplayPosX/Y missing from config.")
        end
        notify("Default config loaded successfully!")
        return true
    end)
    executingSettingsLoad = false
    if not loadCallOk or loadSucceededOrError ~= true then
        local failureReason = loadCallOk and loadErrorCode or loadSucceededOrError
        notify("Default config could not be loaded; using current values.")
        if isDev then
            Logger.LogError(("Load Default config had an error: %s"):format(tostring(failureReason)))
        end
        return false
    end
    return true
end

local hasAttemptedDefaultConfigLoad = false

function loadDefaultConfigOnce()
    if hasAttemptedDefaultConfigLoad then
        return false
    end
    hasAttemptedDefaultConfigLoad = true
    return loadDefaultConfig() == true
end

function bitwise_or(leftOperand, rightOperand)
    local bitwiseResult = 0
    local bitPosition = 0
    while leftOperand > 0 or rightOperand > 0 do
        bitwiseResult = bitwiseResult + (leftOperand % 2 + rightOperand % 2 >= 1 and 1 or 0) * 2 ^ bitPosition
        leftOperand = math.floor(leftOperand / 2)
        rightOperand = math.floor(rightOperand / 2)
        bitPosition = bitPosition + 1
    end
    return bitwiseResult
end

HW_COMPONENTS = {
    CPU_NAME = nil,
    CPU_SPEED = nil,
    NUM_CPU_PHYS_CORES = nil,
    GPU_NAME = nil,
    GPU_DRIVER_NAME = nil,
    GPU_DIRECTX_VERSION = nil,
    GPU_PNP_DEVICE_ID = nil,
    MOBO_NAME = nil,
    BIOS_VERSION = nil,
    BIOS_VENDOR = nil,
    BASE_BOARD_MANUFA = nil,
    WINDOWS_VERSION = nil,
}
local scriptLoadStartClock = os.clock()
if SOCIALCLUB.SC_ACCOUNT_INFO_GET_NICKNAME() == "UNKNOWN" and getLocalRockstarId() == "0" then
    notify("You are not signed into Socialclub, unloading...")
    requestScriptUnload()
    return
end
if cachedUID ~= Cherax.GetUID() then
    SendToDiscord("lol", "Security event detected")
    Logger.Log(eLogColor.RED, "K-Script Security", "Security check failed.")
    KSRuntimeTerminalViolation("runtime_identity_mismatch")
    return
end
if tableContainsValue(blacklistRIDList, getLocalRockstarId()) then
    Logger.Log(eLogColor.RED, "K-Script", "You`ve been Banned from using K-Script!")
    SendToDiscord("lol", "Blocked client attempted to load")
    KSRuntimeTerminalViolation("local_runtime_blacklist_match")
    return
end
local activeStartupConfigPayload = nil
local activeStartupConfigDigest = ""
local STARTUP_CONFIG_SCHEMA_VERSION = 2
local STARTUP_CONFIG_MAX_LIFETIME_MS = 300000
local STARTUP_CONFIG_MAX_CLOCK_SKEW_MS = 300000
KS_STARTUP_STAGE_BOOTSTRAP = "bootstrap"
KS_STARTUP_STAGE_EDITION = "edition"
KS_STARTUP_EDITION_LEGACY = "legacy"
KS_STARTUP_EDITION_ENHANCED = "enhanced"
KS_STARTUP_BUILD_KEYS = { legacy = "l", enhanced = "e" }
KS_STARTUP_GAME_KEYS = { onlineVersion = "a" }
KS_STARTUP_ACTIVITY_KEYS = {
    ["Open Interaction Menu"] = "a",
    ["Disable Passive Mode"] = "b",
    ["GTAO Intro"] = "c",
    ["Tennis Invite"] = "d",
    Golf = "e",
    Flashbang = "f",
    ["Kortz Scoping"] = "h",
    ["Kortz Task"] = "i",
}
KS_STARTUP_EVENT_KEYS = { offset = "a", range = "b", seed = "c", salts = "d" }
KS_STARTUP_EVENT_SALT_KEYS = {
    USER = "a",
    DONATOR = "b",
    DEVELOPER = "c",
    ADMIN = "d",
    MODERATOR = "e",
    UNLOAD = "f",
    CRASH = "g",
    HOST_SHARE = "h",
    DID_UNLOAD = "i",
    TELEPORT = "j",
}
KS_STARTUP_PATTERN_KEYS = {
    GBS = "a",
    GBSE = "b",
    GCIN = "c",
    GCINE = "d",
    GCIS = "e",
    GCISE = "f",
    GVCIN = "g",
    GVCIDXV = "h",
    GVCIVEN = "i",
    GPTBE = "j",
    GBIN = "k",
    GBINE = "l",
    GWV = "m",
    GWVE = "n",
    GNOPCT = "o",
    GNOPCTE = "p",
    GBIV = "q",
    GBIVE = "r",
    GBIVEN = "s",
    GBIVENE = "t",
    GBIMAN = "u",
    GBIMANE = "v",
    CGCET = "w",
    CGCETE = "x",
    CWDET = "y",
    CWDETE = "z",
    RGGLI = "aa",
    RGGLIE = "ab",
    NINT = "ac",
    NINTE = "ad",
    WB = "ae",
    WBE = "af",
    WU = "ag",
    WUE = "ah",
    RRCHP = "ai",
    RRCHPE = "aj",
    GICE = "ak",
    CNS = "al",
    CNSE = "am",
    ASP = "an",
    ANP = "ao",
    ASPE = "ap",
    ANPE = "aq",
    FLE = "ar",
    BKDT = "as",
    BKDTE = "at",
    BKSP = "au",
    BKSPE = "av",
    SCKP = "aw",
    SCKPE = "ax",
    SCSS = "ay",
    SCSSE = "az",
    SCBL = "ba",
    SCBLE = "bb",
    SCRA = "bc",
    SCRAE = "bd",
    SCRB = "be",
    SCRBE = "bf",
    CRWET = "bg",
    CRWETE = "bh",
}
KS_STARTUP_GLOBAL_KEYS = {
    MPGlobalsAmbienceBase = "a",
    GlobalplayerBD = "b",
    GlobalplayerBD_FM = "c",
    GlobalplayerBD_FM_3 = "d",
    SeamlessTransitionState = "e",
    HeadshotCount = "f",
    HeadshotBase = "g",
    SwitchScriptId = "h",
    RemotePlayerWalletBase = "i",
    RemotePlayerWalletStride = "j",
    RemotePlayerTotalBase = "k",
}
KS_STARTUP_STRUCT_KEYS = { MPGlobalsAmbienceStruct = "a" }
KS_STARTUP_STRUCT_FIELD_KEYS = {
    MPGlobalsAmbienceStruct = {
        bLaunchVehicleDropSubmarine = "a",
        bLaunchVehicleDropSubmarineDinghy = "b",
        bLaunchVehicleDropAvenger = "c",
        bLaunchVehicleDropHackerTruck = "d",
        bLaunchVehicleDropTruck = "e",
        bLaunchVehicleDropSupportBike = "f",
        bLaunchVehicleDropAcidLab = "g",
    },
}

local function abortOnStartupConfigFailure(failureMessage)
    recordUnloadReason("config_failed")
    failStartup("KS-260")
    requestScriptUnload("config_failed")
    return false
end

local function getStartupConfigOrAbort(requestedSection)
    if type(activeStartupConfigPayload) ~= "table" then
        abortOnStartupConfigFailure("startup config missing before " .. tostring(requestedSection or "lookup"))
        return nil
    end
    return activeStartupConfigPayload
end

local function isVersionAtLeast(currentVersion, minimumVersion)
    local function parseVersionParts(versionString)
        local versionParts = {}
        for versionDigits in tostring(versionString or ""):gmatch("%d+") do
            versionParts[#versionParts + 1] = tonumber(versionDigits) or 0
        end
        return versionParts
    end

    local currentParts = parseVersionParts(currentVersion)
    local minimumParts = parseVersionParts(minimumVersion)
    if #minimumParts == 0 then
        return true
    end
    if #currentParts == 0 then
        return false
    end
    for partIndex = 1, math.max(#currentParts, #minimumParts) do
        local currentPart = currentParts[partIndex] or 0
        local minimumPart = minimumParts[partIndex] or 0
        if currentPart > minimumPart then
            return true
        end
        if currentPart < minimumPart then
            return false
        end
    end
    return true
end

local function requireStartupConfigKeys(configTable, requiredKeys, sectionLabel)
    if type(configTable) ~= "table" then
        return abortOnStartupConfigFailure("startup config invalid")
    end
    for _, requiredKey in ipairs(requiredKeys) do
        if configTable[requiredKey] == nil then
            return abortOnStartupConfigFailure("startup config invalid")
        end
    end
    return true
end

function ksRequireOnlyKeys(configTable, allowedKeys, sectionLabel)
    if not requireStartupConfigKeys(configTable, allowedKeys, sectionLabel) then
        return false
    end
    local allowedKeySet = {}
    for _, allowedKey in ipairs(allowedKeys) do
        allowedKeySet[allowedKey] = true
    end
    for presentKey in pairs(configTable) do
        if not allowedKeySet[tostring(presentKey)] then
            return abortOnStartupConfigFailure("startup config invalid")
        end
    end
    return true
end

function ksMappedKeys(logicalKeys, keyMap, mapLabel)
    local mappedKeys = {}
    for _, logicalKey in ipairs(logicalKeys) do
        local mappedKey = keyMap and keyMap[logicalKey]
        if type(mappedKey) ~= "string" or mappedKey == "" then
            return nil, abortOnStartupConfigFailure("startup " .. tostring(mapLabel or "value") .. " map missing " .. tostring(logicalKey))
        end
        mappedKeys[#mappedKeys + 1] = mappedKey
    end
    return mappedKeys
end

function ksRequireMappedOnlyKeys(configTable, logicalKeys, keyMap, sectionLabel)
    local mappedKeys = ksMappedKeys(logicalKeys, keyMap, sectionLabel)
    if not mappedKeys then
        return false
    end
    return ksRequireOnlyKeys(configTable, mappedKeys, sectionLabel)
end

function ksIsStartupEdition(editionName)
    return tostring(editionName or ""):lower() == KS_STARTUP_EDITION_LEGACY
end

function ksValidateStartupConfig(configResponse, configPayload, expectedStage, expectedEdition)
    expectedStage = tostring(expectedStage or ""):lower()
    expectedEdition = tostring(expectedEdition or ""):lower()
    local responseVersion = tonumber(configResponse and configResponse.v)
    local payloadVersion = tonumber(configPayload and configPayload.v)
    if responseVersion ~= STARTUP_CONFIG_SCHEMA_VERSION or payloadVersion ~= STARTUP_CONFIG_SCHEMA_VERSION or responseVersion ~= payloadVersion then
        return abortOnStartupConfigFailure("startup config version mismatch")
    end
    local configDigest = tostring(configResponse.h or ""):lower()
    if not isHexStringOfLength(configDigest, 64) then
        return abortOnStartupConfigFailure("startup config digest invalid")
    end
    local issuedAtMs = tonumber(configResponse.t)
    local expiresAtMs = tonumber(configResponse.e)
    local nowMs = math.floor(os.time() * 1000)
    if not issuedAtMs or not expiresAtMs or issuedAtMs >= expiresAtMs or expiresAtMs - issuedAtMs > STARTUP_CONFIG_MAX_LIFETIME_MS then
        return abortOnStartupConfigFailure("startup config expiry invalid")
    end
    if expiresAtMs <= nowMs or math.abs(nowMs - issuedAtMs) > STARTUP_CONFIG_MAX_CLOCK_SKEW_MS then
        return abortOnStartupConfigFailure("startup config stale or clock skewed")
    end
    local configNonce = tostring(configResponse.n or ""):lower()
    if not isHexStringOfLength(configNonce, 32) then
        return abortOnStartupConfigFailure("startup config nonce invalid")
    end
    if tostring(configResponse.u or "") ~= tostring(Cherax.GetUID()) then
        return abortOnStartupConfigFailure("startup config uid mismatch")
    end
    local configSessionId = tostring(configResponse.s or ""):lower()
    if not isHexStringOfLength(configSessionId, 32) then
        return abortOnStartupConfigFailure("startup config session invalid")
    end
    local configStage = tostring(configResponse.a or configPayload.a or ""):lower()
    local configEdition = tostring(configResponse.b or configPayload.b or ""):lower()
    if configStage ~= expectedStage then
        return abortOnStartupConfigFailure("startup config stage mismatch")
    end
    if expectedStage == KS_STARTUP_STAGE_BOOTSTRAP then
        if configEdition ~= "" then
            return abortOnStartupConfigFailure("startup config bootstrap edition invalid")
        end
    elseif expectedStage == KS_STARTUP_STAGE_EDITION then
        if not ksIsStartupEdition(expectedEdition) or configEdition ~= expectedEdition then
            return abortOnStartupConfigFailure("startup config edition mismatch")
        end
    else
        return abortOnStartupConfigFailure("startup config stage invalid")
    end
    if type(configPayload.m) ~= "string" or configPayload.m == "" or not isVersionAtLeast(KS_CLIENT_BUILD, configPayload.m) then
        return abortOnStartupConfigFailure("client build below startup minimum")
    end
    if not requireStartupConfigKeys(configPayload.s, { "l", "e" }, "supported build") then
        return false
    end
    if expectedStage == KS_STARTUP_STAGE_BOOTSTRAP then
        if configPayload.g ~= nil or configPayload.r ~= nil or configPayload.o ~= nil or configPayload.e ~= nil or configPayload.i ~= nil then
            return abortOnStartupConfigFailure("startup bootstrap payload too broad")
        end
        if not ksRequireMappedOnlyKeys(configPayload.p, { "GBS", "GBSE" }, KS_STARTUP_PATTERN_KEYS, "pattern") then
            return false
        end
        return true, configDigest
    end
    if not requireStartupConfigKeys(configPayload.o, { "a" }, "game") then
        return false
    end
    if not requireStartupConfigKeys(configPayload.e, { "a", "b", "c", "d" }, "event payload") then
        return false
    end
    if not ksRequireMappedOnlyKeys(configPayload.e.d, {
        "USER",
        "DONATOR",
        "DEVELOPER",
        "ADMIN",
        "MODERATOR",
        "UNLOAD",
        "CRASH",
        "HOST_SHARE",
        "DID_UNLOAD",
        "TELEPORT",
    }, KS_STARTUP_EVENT_SALT_KEYS, "event payload salt") then
        return false
    end
    local editionPatternNames
    if expectedEdition == KS_STARTUP_EDITION_ENHANCED then
        editionPatternNames = {
            "GCINE",
            "GCISE",
            "GPTBE",
            "GBINE",
            "GWVE",
            "GNOPCTE",
            "GBIVE",
            "GBIVENE",
            "GBIMANE",
            "CGCETE",
            "CWDETE",
            "RGGLIE",
            "NINTE",
            "WBE",
            "WUE",
            "RRCHPE",
            "GICE",
            "CNSE",
            "ASPE",
            "ANPE",
            "FLE",
            "BKDTE",
            "BKSPE",
            "SCKPE",
            "SCSSE",
            "SCBLE",
            "SCRAE",
            "SCRBE",
            "CRWETE",
        }
    else
        editionPatternNames = {
            "GCIN",
            "GCIS",
            "GVCIN",
            "GVCIDXV",
            "GVCIVEN",
            "GBIN",
            "GWV",
            "GNOPCT",
            "GBIV",
            "GBIVEN",
            "GBIMAN",
            "CGCET",
            "CWDET",
            "RGGLI",
            "NINT",
            "WB",
            "WU",
            "RRCHP",
            "CNS",
            "ASP",
            "ANP",
            "BKDT",
            "BKSP",
            "SCKP",
            "SCSS",
            "SCBL",
            "SCRA",
            "SCRB",
            "CRWET",
        }
    end
    if not ksRequireMappedOnlyKeys(configPayload.p, editionPatternNames, KS_STARTUP_PATTERN_KEYS, "pattern") then
        return false
    end
    if not ksRequireMappedOnlyKeys(configPayload.g, {
        "MPGlobalsAmbienceBase",
        "GlobalplayerBD",
        "GlobalplayerBD_FM",
        "GlobalplayerBD_FM_3",
        "SeamlessTransitionState",
        "HeadshotCount",
        "HeadshotBase",
        "SwitchScriptId",
        "RemotePlayerWalletBase",
        "RemotePlayerWalletStride",
        "RemotePlayerTotalBase",
    }, KS_STARTUP_GLOBAL_KEYS, "global") then
        return false
    end
    if not ksRequireMappedOnlyKeys(configPayload.i, {
        "Open Interaction Menu",
        "Disable Passive Mode",
        "GTAO Intro",
        "Tennis Invite",
        "Golf",
        "Flashbang",
        "Kortz Scoping",
        "Kortz Task",
    }, KS_STARTUP_ACTIVITY_KEYS, "activity") then
        return false
    end
    if not ksRequireMappedOnlyKeys(configPayload.r, { "MPGlobalsAmbienceStruct" }, KS_STARTUP_STRUCT_KEYS, "global struct") then
        return false
    end
    if not ksRequireMappedOnlyKeys(configPayload.r[KS_STARTUP_STRUCT_KEYS.MPGlobalsAmbienceStruct], {
        "bLaunchVehicleDropSubmarine",
        "bLaunchVehicleDropSubmarineDinghy",
        "bLaunchVehicleDropAvenger",
        "bLaunchVehicleDropHackerTruck",
        "bLaunchVehicleDropTruck",
        "bLaunchVehicleDropSupportBike",
        "bLaunchVehicleDropAcidLab",
    }, KS_STARTUP_STRUCT_FIELD_KEYS.MPGlobalsAmbienceStruct, "global struct field") then
        return false
    end
    return true, configDigest
end

function ksPattern(patternName)
    local startupConfig = getStartupConfigOrAbort("pattern")
    local patternLookupName = patternName or ""
    local mappedPatternKey = KS_STARTUP_PATTERN_KEYS[tostring(patternLookupName)]
    local configPatterns = startupConfig and startupConfig.p
    local patternSignature = configPatterns or mappedPatternKey or patternLookupName
    if mappedPatternKey and configPatterns then
        patternSignature = configPatterns[mappedPatternKey]
    end
    if type(patternSignature) ~= "string" or patternSignature == "" then
        abortOnStartupConfigFailure("missing startup pattern " .. tostring(patternName or "unknown"))
        return ""
    end
    return patternSignature
end

function ksWipeStartupPatterns(wipeReason)
    local startupPayload = activeStartupConfigPayload
    local storedPatterns = type(startupPayload) == "table" and startupPayload.p or nil
    if type(storedPatterns) ~= "table" then
        return 0
    end
    local wipedCount = 0
    for patternKey in pairs(storedPatterns) do
        storedPatterns[patternKey] = nil
        wipedCount = wipedCount + 1
    end
    startupPayload.p = nil
    return wipedCount
end

function ksDeferStartupPatternWipe(wipeReason, delayMs)
    delayMs = tonumber(delayMs) or 5000
    Script.QueueJob(function()
        yieldClampedMs(delayMs, 5000)
        if ShouldUnload() then
            return
        end
        ksWipeStartupPatterns(wipeReason)
    end)
end

function ksSupportedBuild(buildName)
    local startupConfig = getStartupConfigOrAbort("supported build")
    local buildLookupName = buildName or ""
    local mappedBuildKey = KS_STARTUP_BUILD_KEYS[tostring(buildLookupName)]
    local supportedBuilds = startupConfig and startupConfig.s
    local supportedBuildVersion = supportedBuilds or mappedBuildKey or buildLookupName
    if mappedBuildKey and supportedBuilds then
        supportedBuildVersion = supportedBuilds[mappedBuildKey]
    end
    if type(supportedBuildVersion) ~= "string" or supportedBuildVersion == "" then
        abortOnStartupConfigFailure("missing supported build " .. tostring(buildName or "unknown"))
        return ""
    end
    return supportedBuildVersion
end

function ksGameValue(gameValueName)
    local startupConfig = getStartupConfigOrAbort("game")
    local gameValueLookupName = gameValueName or ""
    local mappedGameKey = KS_STARTUP_GAME_KEYS[tostring(gameValueLookupName)]
    local configGameValues = startupConfig and startupConfig.o
    local gameValue = configGameValues or mappedGameKey or gameValueLookupName
    if mappedGameKey and configGameValues then
        gameValue = configGameValues[mappedGameKey]
    end
    if type(gameValue) ~= "string" or gameValue == "" then
        abortOnStartupConfigFailure("missing startup game value " .. tostring(gameValueName or "unknown"))
        return ""
    end
    return gameValue
end

function ksGlobal(globalName)
    local startupConfig = getStartupConfigOrAbort("global")
    local globalLookupName = globalName or ""
    local mappedGlobalKey = KS_STARTUP_GLOBAL_KEYS[tostring(globalLookupName)]
    local configGlobals = startupConfig and startupConfig.g
    local rawGlobalValue = configGlobals or mappedGlobalKey or globalLookupName
    if mappedGlobalKey and configGlobals then
        rawGlobalValue = configGlobals[mappedGlobalKey]
    end
    local globalIndex = tonumber(rawGlobalValue)
    if not globalIndex then
        abortOnStartupConfigFailure("missing startup global " .. tostring(globalName or "unknown"))
        return 0
    end
    return globalIndex
end

function ksGlobalStruct(structName)
    local configLookupLabel, nilArgSecond, nilArgThird, nilArgFourth, nilStructFallback, nilArgSixth, nilArgSeventh, nilArgEighth, nilArgNinth, nilArgTenth, nilArgEleventh, nilArgTwelfth, nilArgThirteenth, nilArgFourteenth, nilArgFifteenth, nilArgSixteenth, nilArgSeventeenth, nilArgEighteenth, nilArgNineteenth, nilArgTwentieth = "global struct"
    local startupConfig = getStartupConfigOrAbort(configLookupLabel, nilArgSecond, nilArgThird, nilArgFourth, nilStructFallback, nilArgSixth, nilArgSeventh, nilArgEighth, nilArgNinth, nilArgTenth, nilArgEleventh, nilArgTwelfth, nilArgThirteenth, nilArgFourteenth, nilArgFifteenth, nilArgSixteenth, nilArgSeventeenth, nilArgEighteenth, nilArgNineteenth, nilArgTwentieth)
    local structLookupName = tostring(structName or "")
    local mappedStructKey = KS_STARTUP_STRUCT_KEYS[structLookupName]
    local fieldKeyMap = KS_STARTUP_STRUCT_FIELD_KEYS[structLookupName]
    local configStructs = startupConfig and startupConfig.r
    local structFields = configStructs or mappedStructKey or nilStructFallback
    if mappedStructKey and configStructs then
        structFields = configStructs[mappedStructKey]
    end
    if type(structFields) ~= "table" or type(fieldKeyMap) ~= "table" then
        abortOnStartupConfigFailure("missing startup global struct " .. tostring(structName or "unknown"))
        return {}
    end
    local resolvedFieldOffsets = {}
    for fieldName, mappedFieldKey in pairs(fieldKeyMap) do
        local fieldOffset = tonumber(structFields[mappedFieldKey])
        if not fieldOffset then
            abortOnStartupConfigFailure("invalid startup global struct " .. tostring(structName or "unknown") .. "." .. tostring(fieldName))
            return {}
        end
        resolvedFieldOffsets[fieldName] = fieldOffset
    end
    return resolvedFieldOffsets
end

function ksApplyEventPayloadConfig(startupConfigPayload)
    local eventPayloadConfig = type(startupConfigPayload) == "table" and startupConfigPayload.e or nil
    local configuredSalts = type(eventPayloadConfig) == "table" and eventPayloadConfig[KS_STARTUP_EVENT_KEYS.salts] or nil
    if type(eventPayloadConfig) ~= "table" or type(configuredSalts) ~= "table" then
        return abortOnStartupConfigFailure("startup event payload config missing")
    end
    local payloadSalts = {}
    for _, eventName in ipairs({
        "USER",
        "DONATOR",
        "DEVELOPER",
        "ADMIN",
        "MODERATOR",
        "UNLOAD",
        "CRASH",
        "HOST_SHARE",
        "DID_UNLOAD",
        "TELEPORT",
    }) do
        local saltKey = KS_STARTUP_EVENT_SALT_KEYS[eventName]
        local parsedSalt = saltKey and tonumber(configuredSalts[saltKey])
        if not parsedSalt or parsedSalt <= 0 then
            return abortOnStartupConfigFailure("startup config invalid")
        end
        payloadSalts[eventName] = math.floor(parsedSalt)
    end
    local payloadOffset = tonumber(eventPayloadConfig[KS_STARTUP_EVENT_KEYS.offset])
    local payloadRange = tonumber(eventPayloadConfig[KS_STARTUP_EVENT_KEYS.range])
    local payloadSeed = tonumber(eventPayloadConfig[KS_STARTUP_EVENT_KEYS.seed])
    if not (payloadOffset and not (payloadOffset <= 0) and payloadRange and not (payloadRange <= 0) and payloadSeed) or payloadSeed <= 0 then
        return abortOnStartupConfigFailure("invalid startup event payload parameters")
    end
    KSCRIPT_PAYLOAD_SALTS = payloadSalts
    KSCRIPT_PAYLOAD_OFFSET = math.floor(payloadOffset)
    KSCRIPT_PAYLOAD_RANGE = math.floor(payloadRange)
    KSCRIPT_PAYLOAD_SEED = math.floor(payloadSeed)
    return true
end

function ksApplyActivityConfig(startupConfigPayload)
    local activityIdConfig = type(startupConfigPayload) == "table" and startupConfigPayload.i or nil
    if type(activityIdConfig) ~= "table" then
        return abortOnStartupConfigFailure("startup activity config missing")
    end
    local activityNamesById = {}
    for activityName, activityConfigKey in pairs(KS_STARTUP_ACTIVITY_KEYS) do
        local parsedActivityId = tonumber(activityIdConfig[activityConfigKey])
        if not parsedActivityId or parsedActivityId <= 0 or parsedActivityId ~= math.floor(parsedActivityId) then
            return abortOnStartupConfigFailure("invalid startup activity id " .. tostring(activityName))
        end
        local activityId = math.floor(parsedActivityId)
        if activityNamesById[activityId] ~= nil then
            return abortOnStartupConfigFailure("duplicate startup activity id " .. tostring(activityId))
        end
        activityNamesById[activityId] = activityName
    end
    activities = activityNamesById
    return true
end

local STARTUP_CONFIG_MAX_ATTEMPTS = 3
local STARTUP_CONFIG_RETRY_BASE_DELAY = 1.0
KSStartupConfigState = KSStartupConfigState or { generation = 0, state = "idle" }

local function isStartupConfigRequestTable(candidateRequest)
    return type(candidateRequest) == "table"
end

local function ignoreInvalidStartupConfigRequest(invalidRequest)
end

local function invokeStartupConfigCallback(configRequest, isSuccess)
    local completionCallback = configRequest.callback
    configRequest.callback = nil
    if type(completionCallback) ~= "function" then
        return
    end

    local function runCompletionCallback()
        pcall(completionCallback, isSuccess == true, configRequest.state)
    end

    if isTableOrUserdata(Script) and type(Script.QueueJob) == "function" and Script.QueueJob(runCompletionCallback) ~= false then
        return
    end
    runCompletionCallback()
end

local function finishStartupConfigRequest(configRequest, finalState, failureReason, shouldSkipAbort)
    if not isStartupConfigRequestTable(configRequest) then
        return false
    end
    configRequest.state = finalState
    configRequest.curl = nil
    configRequest.responseBody = nil
    KSStartupConfigState.state = finalState
    KSStartupConfigState.last = configRequest
    KSStartupConfigState.request = nil
    if finalState == "success" then
        invokeStartupConfigCallback(configRequest, true)
        return true
    end
    if not shouldSkipAbort and not configRequest.cleanupDone then
        configRequest.cleanupDone = true
        abortOnStartupConfigFailure("startup config " .. tostring(failureReason or finalState))
    end
    invokeStartupConfigCallback(configRequest, false)
    return false
end

local function scheduleStartupConfigRetry(configRequest, failureReason)
    if not isStartupConfigRequestTable(configRequest) then
        return false
    end
    configRequest.curl = nil
    configRequest.responseBody = nil
    if configRequest.attempt >= STARTUP_CONFIG_MAX_ATTEMPTS then
        return finishStartupConfigRequest(configRequest, "retry_exhausted", failureReason or "request failed")
    end
    configRequest.state = "retry_wait"
    KSStartupConfigState.state = "retry_wait"
    configRequest.nextAttemptAt = getMonotonicSeconds() + STARTUP_CONFIG_RETRY_BASE_DELAY * 2 ^ math.max(0, configRequest.attempt - 1)
    return true
end

local function dispatchStartupConfigRequest(configRequest)
    if not isStartupConfigRequestTable(configRequest) then
        return ignoreInvalidStartupConfigRequest(configRequest)
    end
    local snapshotConfig = type(KS_STARTUP_SNAPSHOT_CONFIGS) == "table" and KS_STARTUP_SNAPSHOT_CONFIGS[configRequest.stage] or nil
    if loaderAdapter and type(snapshotConfig) == "table" then
        configRequest.responseCode = eCurlCode.CURLE_OK
        local encodedSnapshotConfig = json.encode(snapshotConfig)
        configRequest.responseBody = encodedSnapshotConfig
        configRequest.state = "response_received"
        KSStartupConfigState.state = "response_received"
        return
    end
    if loaderAdapter then
        local requestedBuild
        if configRequest.edition ~= "" then
            requestedBuild = configRequest.edition
            if requestedBuild then
                goto sendAdapterRequest
            end
        end
        if isGameVersionEnhanced then
            requestedBuild = "enhanced"
            if requestedBuild then
                goto sendAdapterRequest
            end
        end
        requestedBuild = "legacy"
        ::sendAdapterRequest::
        local adapterStatus, adapterResponse, adapterError = loaderAdapter.request("config.get", {
            stage = configRequest.stage,
            build = requestedBuild,
            edition = configRequest.stage == KS_STARTUP_STAGE_EDITION and configRequest.edition or nil,
        }, 15000)
        if not isStartupConfigRequestTable(configRequest) then
            return ignoreInvalidStartupConfigRequest(configRequest)
        end
        if adapterStatus == "timeout" or adapterStatus == "unavailable" then
            return scheduleStartupConfigRetry(configRequest, tostring(adapterError or "config_temporarily_unavailable"))
        end
        if adapterStatus ~= "ok" or type(adapterResponse) ~= "table" or type(adapterResponse.config) ~= "table" then
            return finishStartupConfigRequest(configRequest, "fatal_failed", tostring(adapterError or "config_unavailable"))
        end
        configRequest.responseCode = eCurlCode.CURLE_OK
        local encodedConfig = json.encode(adapterResponse.config)
        configRequest.responseBody = encodedConfig
        configRequest.state = "response_received"
        KSStartupConfigState.state = "response_received"
        return
    end
    local dispatchOk, curlHandle = pcall(function()
        local easyHandle = Curl.Easy()
        easyHandle:Setopt(eCurlOption.CURLOPT_URL, configRequest.endpoint)
        easyHandle:AddHeader("Content-Type: application/json")
        easyHandle:AddHeader(("X-C-20: %s"):format(__a25))
        easyHandle:Setopt(eCurlOption.CURLOPT_USERAGENT, ks_uid_user_agent())
        easyHandle:DisableErrorLog()
        easyHandle:Perform()
        return easyHandle
    end)
    if not isStartupConfigRequestTable(configRequest) then
        return ignoreInvalidStartupConfigRequest(configRequest)
    end
    if not dispatchOk then
        return scheduleStartupConfigRetry(configRequest, "dispatch failed")
    end
    configRequest.curl = curlHandle
    configRequest.state = "in_flight"
    KSStartupConfigState.state = "in_flight"
end

local function collectStartupConfigResponse(configRequest)
    if not isStartupConfigRequestTable(configRequest) then
        return ignoreInvalidStartupConfigRequest(configRequest)
    end
    local curlHandle = configRequest.curl
    if not curlHandle then
        return scheduleStartupConfigRetry(configRequest, "response missing")
    end
    local readResponseOk, curlResultCode, httpResponseBody = pcall(curlHandle.GetResponse, curlHandle)
    configRequest.curl = nil
    if not isStartupConfigRequestTable(configRequest) then
        return ignoreInvalidStartupConfigRequest(configRequest)
    end
    if not readResponseOk then
        return scheduleStartupConfigRetry(configRequest, "response failed")
    end
    configRequest.responseCode = curlResultCode
    configRequest.responseBody = httpResponseBody
    configRequest.state = "response_received"
    KSStartupConfigState.state = "response_received"
end

local function processStartupConfigResponse(configRequest)
    if not isStartupConfigRequestTable(configRequest) then
        return ignoreInvalidStartupConfigRequest(configRequest)
    end
    local receivedResponseCode = configRequest.responseCode
    local responseText = tostring(configRequest.responseBody or "")
    configRequest.responseBody = nil
    if receivedResponseCode ~= eCurlCode.CURLE_OK or responseText == "" or ResponseHasErrorMarker(responseText) then
        return scheduleStartupConfigRetry(configRequest, "request failed")
    end
    local decodedResponse = nil
    local decodeOk = pcall(function()
        decodedResponse = json.decode(responseText)
    end)
    responseText = nil
    local configPayload = type(decodedResponse) == "table" and decodedResponse.c or nil
    local hasValidResponseFields = validateResponseFields("startupConfig", decodedResponse)
    if not decodeOk or not hasValidResponseFields or type(decodedResponse) ~= "table" or decodedResponse.o ~= true or type(configPayload) ~= "table" then
        return finishStartupConfigRequest(configRequest, "fatal_failed", "decode failed")
    end
    if not isStartupConfigRequestTable(configRequest) then
        return ignoreInvalidStartupConfigRequest(configRequest)
    end
    configRequest.state = "validating"
    KSStartupConfigState.state = "validating"
    local shouldSkipAbort, extraNilPadding, trailingNilPadding, finishRequest, failedRequest, failureState, shapeFailureReason
    if type(configPayload.p) == "table" and type(configPayload.s) == "table" then
        if configRequest.stage ~= KS_STARTUP_STAGE_EDITION then
            goto validateConfigPayload
        end
        if type(configPayload.g) == "table" and type(configPayload.r) == "table" and type(configPayload.o) == "table" and type(configPayload.e) == "table" and type(configPayload.i) == "table" then
            goto validateConfigPayload
        end
    end
    finishRequest = finishStartupConfigRequest
    failedRequest = configRequest
    failureState = "fatal_failed"
    shapeFailureReason, shouldSkipAbort, extraNilPadding, trailingNilPadding = "shape invalid"
    do
        return finishRequest(failedRequest, failureState, shapeFailureReason, shouldSkipAbort, extraNilPadding, trailingNilPadding)
    end
    ::validateConfigPayload::
    local isConfigValid, configDigest = ksValidateStartupConfig(decodedResponse, configPayload, configRequest.stage, configRequest.edition)
    if not isConfigValid then
        configRequest.cleanupDone = true
        return finishStartupConfigRequest(configRequest, "fatal_failed", "validation failed", true)
    end
    if configRequest.stage == KS_STARTUP_STAGE_EDITION and (not ksApplyEventPayloadConfig(configPayload) or not ksApplyActivityConfig(configPayload)) then
        configRequest.cleanupDone = true
        return finishStartupConfigRequest(configRequest, "fatal_failed", "apply failed", true)
    end
    if not isStartupConfigRequestTable(configRequest) then
        return ignoreInvalidStartupConfigRequest(configRequest)
    end
    activeStartupConfigPayload = configPayload
    activeStartupConfigDigest = configDigest
    return finishStartupConfigRequest(configRequest, "success")
end

local function tickStartupConfigRequest()
    local pendingRequest = KSStartupConfigState.request
    if type(pendingRequest) ~= "table" then
        return
    end
    if not isStartupConfigRequestTable(pendingRequest) then
        return ignoreInvalidStartupConfigRequest(pendingRequest)
    end
    local nowSeconds = getMonotonicSeconds()
    if pendingRequest.state == "queued" then
        pendingRequest.attempt = pendingRequest.attempt + 1
        pendingRequest.state = "dispatching"
        KSStartupConfigState.state = "queued"
        local dispatchTimeoutSeconds = getRequestTimeoutSeconds("startupConfig", 30)
        pendingRequest.deadline = nowSeconds + dispatchTimeoutSeconds
        if Script.QueueJob(function()
            dispatchStartupConfigRequest(pendingRequest)
        end) == false then
            scheduleStartupConfigRetry(pendingRequest, "queue failed")
        end
    elseif pendingRequest.state ~= "dispatching" and pendingRequest.state ~= "in_flight" and pendingRequest.state ~= "response_processing" and pendingRequest.state ~= "parsing" and pendingRequest.state ~= "validating" then
        if pendingRequest.state == "in_flight" then
            if pendingRequest.curl then
                local finishedCheckOk, isTransferFinished = pcall(pendingRequest.curl.GetFinished, pendingRequest.curl)
                if not finishedCheckOk then
                    finishStartupConfigRequest(pendingRequest, "fatal_failed", "callback failed")
                elseif isTransferFinished then
                    pendingRequest.state = "response_processing"
                    KSStartupConfigState.state = "response_processing"
                    if Script.QueueJob(function()
                        collectStartupConfigResponse(pendingRequest)
                    end) == false then
                        scheduleStartupConfigRetry(pendingRequest, "response queue failed")
                    end
                end
            end
        elseif pendingRequest.state == "response_received" then
            pendingRequest.state = "parsing"
            KSStartupConfigState.state = "parsing"
            local parseTimeoutSeconds = getRequestTimeoutSeconds("startupConfig", 30)
            pendingRequest.deadline = nowSeconds + parseTimeoutSeconds
            if Script.QueueJob(function()
                processStartupConfigResponse(pendingRequest)
            end) == false then
                scheduleStartupConfigRetry(pendingRequest, "parse queue failed")
            end
        elseif pendingRequest.state == "retry_wait" then
            if nowSeconds >= (pendingRequest.nextAttemptAt or nowSeconds) then
                pendingRequest.state = "queued"
                KSStartupConfigState.state = "queued"
            end
        end
    elseif nowSeconds >= (pendingRequest.deadline or nowSeconds) then
        finishStartupConfigRequest(pendingRequest, "timeout_failed", "timeout")
    elseif pendingRequest.state == "in_flight" then
        if pendingRequest.curl then
            local inFlightCheckOk, isInFlightTransferFinished = pcall(pendingRequest.curl.GetFinished, pendingRequest.curl)
            if not inFlightCheckOk then
                finishStartupConfigRequest(pendingRequest, "fatal_failed", "callback failed")
            elseif isInFlightTransferFinished then
                pendingRequest.state = "response_processing"
                KSStartupConfigState.state = "response_processing"
                if Script.QueueJob(function()
                    collectStartupConfigResponse(pendingRequest)
                end) == false then
                    scheduleStartupConfigRetry(pendingRequest, "response queue failed")
                end
            end
        end
    elseif pendingRequest.state == "response_received" then
        pendingRequest.state = "parsing"
        KSStartupConfigState.state = "parsing"
        local responseParseTimeout = getRequestTimeoutSeconds("startupConfig", 30)
        pendingRequest.deadline = nowSeconds + responseParseTimeout
        if Script.QueueJob(function()
            processStartupConfigResponse(pendingRequest)
        end) == false then
            scheduleStartupConfigRetry(pendingRequest, "parse queue failed")
        end
    elseif pendingRequest.state == "retry_wait" then
        if nowSeconds >= (pendingRequest.nextAttemptAt or nowSeconds) then
            pendingRequest.state = "queued"
            KSStartupConfigState.state = "queued"
        end
    end
end

function FetchStartupConfig(configStage, editionName, onRequestComplete)
    configStage = tostring(configStage or KS_STARTUP_STAGE_EDITION):lower()
    editionName = tostring(editionName or ""):lower()
    local requestEndpoint = "bridge://loader/retired"
    if configStage == KS_STARTUP_STAGE_BOOTSTRAP then
        requestEndpoint = requestEndpoint .. "?stage=bootstrap"
    elseif configStage == KS_STARTUP_STAGE_EDITION then
        if ksIsStartupEdition(editionName) then
            requestEndpoint = requestEndpoint .. "?stage=edition&edition=" .. editionName
        end
    else
        abortOnStartupConfigFailure("startup config stage invalid")
        return false
    end
    local isAuthValid, authFailureReason = validateRequestAuth("startupConfig", { scriptToken = __a25 })
    if not isAuthValid then
        abortOnStartupConfigFailure(("startup config auth contract failed (%s)"):format(tostring(authFailureReason)))
        return false
    end
    if KSStartupConfigState.request then
        return true
    end
    local requestGeneration = (tonumber(KSStartupConfigState.generation) or 0) + 1
    KSStartupConfigState.generation = requestGeneration
    KSStartupConfigState.state = "queued"
    KSStartupConfigState.request = {
        generation = requestGeneration,
        state = "queued",
        stage = configStage,
        edition = editionName,
        endpoint = requestEndpoint,
        callback = onRequestComplete,
        attempt = 0,
    }
    return true
end

function FetchStartupSnapshot(requestedEdition)
    if not loaderAdapter then
        return true
    end
    if ShouldUnload() then
        return false
    end
    local editionInput = requestedEdition
    local normalizedEdition
    if ksIsStartupEdition(editionInput) then
        local editionString = tostring(requestedEdition)
        editionInput = editionString
        normalizedEdition = editionString.lower(editionInput)
        if normalizedEdition then
            goto editionResolved
        end
    end
    normalizedEdition = ""
    ::editionResolved::
    local snapshotBuild = normalizedEdition or editionInput
    if normalizedEdition == "" or not normalizedEdition then
        if isGameVersionEnhanced then
            snapshotBuild = "enhanced"
            if snapshotBuild then
                goto buildResolved
            end
        end
        snapshotBuild = "legacy"
    end
    ::buildResolved::
    local requestStatus, snapshotResponse, requestErrorCode = loaderAdapter.request("startup.snapshot", { build = snapshotBuild, edition = normalizedEdition ~= "" and normalizedEdition or nil }, 15000)
    local isRestrictionApplied, isRestrictionExtended = KSApplyRemovalRestriction(snapshotResponse)
    if isRestrictionExtended then
        KSNotifyRemovalRestriction(snapshotResponse.removal_restriction.remaining_seconds)
    end
    local snapshotPayload = type(snapshotResponse) == "table" and snapshotResponse.snapshot or nil
    local snapshotConfigs = type(snapshotPayload) == "table" and snapshotPayload.config or nil
    local permissionSnapshot = type(snapshotPayload) == "table" and snapshotPayload.permissions or nil
    local isSnapshotLoaded
    if requestStatus == "ok" and type(snapshotConfigs) == "table" and type(snapshotConfigs.bootstrap) == "table" and type(permissionSnapshot) == "table" and type(permissionSnapshot.p) == "table" then
        if normalizedEdition == "" then
            goto storeSnapshot
        end
        if type(snapshotConfigs.edition) == "table" then
            goto storeSnapshot
        end
    end
    requestScriptUnload("config_failed")
    isSnapshotLoaded = false
    do
        return isSnapshotLoaded
    end
    ::storeSnapshot::
    KS_STARTUP_SNAPSHOT = snapshotPayload
    KS_STARTUP_SNAPSHOT_CONFIGS = { bootstrap = snapshotConfigs.bootstrap, edition = snapshotConfigs.edition }
    KS_STARTUP_PERMISSION_SNAPSHOT = permissionSnapshot
    return true
end

if isTableOrUserdata(Script) then
    if type(Script.RegisterLooped) == "function" then
        Script.RegisterLooped(tickStartupConfigRequest)
    end
else
    abortOnStartupConfigFailure("startup config tick API unavailable")
end

local function runStartupAfterBootstrapConfig()
    if not reportRuntimeProgressPhase("bootstrap_ready") then
        failRuntimeBridgeInit()
        return
    end
    setStartupPhase("core", 0.3)
    local isInStartupCoroutine = false

    local function runCooperativeStartup(startupRoutine)
        if type(startupRoutine) ~= "function" or type(coroutine) ~= "table" or type(coroutine.create) ~= "function" then
            return false
        end
        local startupCoroutine = coroutine.create(function()
            isInStartupCoroutine = true
            startupRoutine()
            isInStartupCoroutine = false
        end)

        local function scheduleStartupResume()
            if ShouldUnload() then
                isInStartupCoroutine = false
                return
            end
            if Script.QueueJob(function()
                if ShouldUnload() then
                    isInStartupCoroutine = false
                    return
                end
                local resumeOk, resumeError = coroutine.resume(startupCoroutine)
                if not resumeOk then
                    isInStartupCoroutine = false
                    Logger.LogError("K-Script: cooperative startup failed.")
                    requestScriptUnload()
                    return
                end
                if coroutine.status(startupCoroutine) ~= "dead" then
                    scheduleStartupResume()
                end
            end) == false then
                isInStartupCoroutine = false
                Logger.LogError("K-Script: cooperative startup queue failed.")
                requestScriptUnload()
            end
        end

        scheduleStartupResume()
        return true
    end

    local function logPatternScanResult(loggedPatternName, isPatternFound)
        logStartupMessage(isPatternFound and eLogColor.GREEN or eLogColor.YELLOW, string.format("Pattern %s: %s", tostring(loggedPatternName or "unknown"), isPatternFound and "found" or "not found"))
    end

    function ptrnScan(patternName, patternSignature, failureCode, unloadReason, isOptional)
        patternSignature = tostring(patternSignature or "")
        if patternSignature == "" then
            logPatternScanResult(patternName, false)
            if isOptional then
                return nil
            end
            ksWipeStartupPatterns("signature scan failure")
            failStartup(failureCode or "KS-260")
            requestScriptUnload(unloadReason or "config_failed")
            return nil
        end
        local maxScanAttempts = patternName == "GBS" and 1 or 3
        for scanAttempt = 1, maxScanAttempts do
            if not isInStartupCoroutine then
                yieldScriptPeriodically(true)
            end
            local matchAddress = Memory.Scan(patternSignature)
            if isInStartupCoroutine then
                coroutine.yield(scanAttempt < maxScanAttempts and "signature_scan_retry" or "signature_scan")
            else
                yieldScriptPeriodically(true)
            end
            if matchAddress ~= nil and matchAddress ~= 0 then
                logPatternScanResult(patternName, true)
                return matchAddress
            end
        end
        logPatternScanResult(patternName, false)
        if patternName ~= "GBS" then
            if isOptional then
                return nil
            end
            ksWipeStartupPatterns("signature scan failure")
            failStartup(failureCode or "KS-260")
            requestScriptUnload(unloadReason or "config_failed")
            return nil
        end
    end

    local legacyBuildStringAddress = ptrnScan("GBS", ksPattern("GBS"))
    if legacyBuildStringAddress ~= nil then
        local legacyBuildString = Memory.ReadString(legacyBuildStringAddress)
        if legacyBuildString ~= ksSupportedBuild("legacy") then
            GUI.AddToast("K-Script", ("Unsupported Game Build Detected!\nPlease wait for an Update! (%s)"):format(legacyBuildString), 15000, eToastPos.TOP_RIGHT)
            requestScriptUnload()
            return
        end
    else
        local enhancedBuildStringAddress = Memory.Rip(ptrnScan("GBSE", ksPattern("GBSE")) + 3)
        if enhancedBuildStringAddress ~= nil then
            local enhancedBuildString = Memory.ReadString(enhancedBuildStringAddress)
            isGameVersionEnhanced = true
            local supportedBuildMajor, supportedBuildRevision = ksSupportedBuild("enhanced"):match("^(%d+)%.(%d+)$")
            local detectedBuildMajor, detectedBuildRevision = tostring(enhancedBuildString):match("^(%d+)%.(%d+)$")
            if not detectedBuildMajor then
                GUI.AddToast("K-Script", ("Unsupported Game Build Detected!\nPlease wait for an Update! (%s)"):format(enhancedBuildString), 15000, eToastPos.TOP_RIGHT)
                requestScriptUnload()
                return
            end
            if detectedBuildMajor ~= supportedBuildMajor then
                GUI.AddToast("K-Script", ("Unsupported Game Build Detected!\nPlease wait for an Update! (%s)"):format(enhancedBuildString), 15000, eToastPos.TOP_RIGHT)
                requestScriptUnload()
                return
            elseif detectedBuildRevision ~= supportedBuildRevision then
                GUI.AddToast("K-Script", ("Game Build Revision Changed!\nScript may still work, but use caution. (%s)"):format(enhancedBuildString), 10000, eToastPos.TOP_RIGHT)
            end
        else
            GUI.AddToast("K-Script", "Failed to Find critical Patterns!", 15000, eToastPos.TOP_RIGHT)
            requestScriptUnload()
            return
        end
    end
    local detectedEdition = isGameVersionEnhanced and KS_STARTUP_EDITION_ENHANCED or KS_STARTUP_EDITION_LEGACY
    ksWipeStartupPatterns("edition detected")

    local function runEditionStartup()
        if not reportRuntimeProgressPhase("edition_ready") then
            failRuntimeBridgeInit()
            return
        end
        setStartupPhase("runtime", 0.52)

        local function nopPatchPattern(patchPatternName, patchByteCount)
            local patchAddress = ptrnScan(patchPatternName, ksPattern(patchPatternName), nil, nil, true)
            if patchAddress == nil then
                return false
            end
            local readUnsignedByte
            if type(Memory.ReadUByte) == "function" then
                readUnsignedByte = Memory
                readUnsignedByte = readUnsignedByte.ReadUByte
                if readUnsignedByte then
                    goto readUnsignedByteResolved
                end
            end
            readUnsignedByte = nil
            ::readUnsignedByteResolved::
            local readSignedByte
            if type(Memory.ReadByte) == "function" then
                readSignedByte = Memory
                readSignedByte = readSignedByte.ReadByte
                if readSignedByte then
                    goto readSignedByteResolved
                end
            end
            readSignedByte = nil
            ::readSignedByteResolved::
            local writeUnsignedByte
            if type(Memory.WriteUByte) == "function" then
                writeUnsignedByte = Memory
                writeUnsignedByte = writeUnsignedByte.WriteUByte
                if writeUnsignedByte then
                    goto writeUnsignedByteResolved
                end
            end
            writeUnsignedByte = nil
            ::writeUnsignedByteResolved::
            local writeSignedByte
            if type(Memory.WriteByte) == "function" then
                writeSignedByte = Memory
                writeSignedByte = writeSignedByte.WriteByte
                if writeSignedByte then
                    goto writeSignedByteResolved
                end
            end
            writeSignedByte = nil
            ::writeSignedByteResolved::

            local function readPatchByte(byteAddress)
                if readUnsignedByte then
                    local readUByteOk, unsignedByteValue = pcall(readUnsignedByte, byteAddress)
                    if readUByteOk and type(unsignedByteValue) == "number" then
                        return true, math.floor(unsignedByteValue) % 256
                    end
                end
                if readSignedByte then
                    local readByteOk, signedByteValue = pcall(readSignedByte, byteAddress)
                    if readByteOk and type(signedByteValue) == "number" then
                        return true, math.floor(signedByteValue) % 256
                    end
                end
                return false, nil
            end

            local function writePatchByte(targetAddress, newByteValue)
                if writeUnsignedByte then
                    local writeUByteOk, writeUByteResult = pcall(writeUnsignedByte, targetAddress, newByteValue)
                    if writeUByteOk and writeUByteResult ~= false then
                        return true
                    end
                end
                if writeSignedByte then
                    local writeByteOk, writeByteResult = pcall(writeSignedByte, targetAddress, newByteValue >= 128 and newByteValue - 256 or newByteValue)
                    if writeByteOk and writeByteResult ~= false then
                        return true
                    end
                end
                return false
            end

            local originalBytes = {}
            for backupOffset = 0, patchByteCount - 1 do
                local originalReadOk, originalByte = readPatchByte(patchAddress + backupOffset)
                if not originalReadOk then
                    return false
                end
                originalBytes[backupOffset + 1] = originalByte
            end
            local isPatchVerified = true
            for patchOffset = 0, patchByteCount - 1 do
                local isNopWritten = writePatchByte(patchAddress + patchOffset, 144)
                local verifyReadOk, verifiedByte = readPatchByte(patchAddress + patchOffset)
                if not (isNopWritten and verifyReadOk) or verifiedByte ~= 144 then
                    isPatchVerified = false
                    break
                end
            end
            if not isPatchVerified then
                for restoreOffset = 0, patchByteCount - 1 do
                    writePatchByte(patchAddress + restoreOffset, originalBytes[restoreOffset + 1])
                end
                return false
            end
            return true
        end

        local function patchPatternByte(patternKey, byteOffset, patchByteValue)
            local patternMatchAddress = ptrnScan(patternKey, ksPattern(patternKey), nil, nil, true)
            if patternMatchAddress == nil then
                return false
            end
            local patchAddress = patternMatchAddress + (tonumber(byteOffset) or 0)
            local desiredByte = math.floor(tonumber(patchByteValue) or 0) % 256
            local readUnsignedByte
            if type(Memory.ReadUByte) == "function" then
                readUnsignedByte = Memory
                readUnsignedByte = readUnsignedByte.ReadUByte
                if readUnsignedByte then
                    goto readUnsignedByteResolved
                end
            end
            readUnsignedByte = nil
            ::readUnsignedByteResolved::
            local readSignedByte
            if type(Memory.ReadByte) == "function" then
                readSignedByte = Memory
                readSignedByte = readSignedByte.ReadByte
                if readSignedByte then
                    goto readSignedByteResolved
                end
            end
            readSignedByte = nil
            ::readSignedByteResolved::
            local writeUnsignedByte
            if type(Memory.WriteUByte) == "function" then
                writeUnsignedByte = Memory
                writeUnsignedByte = writeUnsignedByte.WriteUByte
                if writeUnsignedByte then
                    goto writeUnsignedByteResolved
                end
            end
            writeUnsignedByte = nil
            ::writeUnsignedByteResolved::
            local writeSignedByte
            if type(Memory.WriteByte) == "function" then
                writeSignedByte = Memory
                writeSignedByte = writeSignedByte.WriteByte
                if writeSignedByte then
                    goto writeSignedByteResolved
                end
            end
            writeSignedByte = nil
            ::writeSignedByteResolved::

            local function tryReadByte(byteAddress)
                if readUnsignedByte then
                    local unsignedReadOk, unsignedByte = pcall(readUnsignedByte, byteAddress)
                    if unsignedReadOk and type(unsignedByte) == "number" then
                        return true, math.floor(unsignedByte) % 256
                    end
                end
                if readSignedByte then
                    local signedReadOk, signedByte = pcall(readSignedByte, byteAddress)
                    if signedReadOk and type(signedByte) == "number" then
                        return true, math.floor(signedByte) % 256
                    end
                end
                return false, nil
            end

            local function tryWriteByte(targetAddress, byteToWrite)
                if writeUnsignedByte then
                    local unsignedWriteOk, unsignedWriteResult = pcall(writeUnsignedByte, targetAddress, byteToWrite)
                    if unsignedWriteOk and unsignedWriteResult ~= false then
                        return true
                    end
                end
                if writeSignedByte then
                    local signedWriteOk, signedWriteResult = pcall(writeSignedByte, targetAddress, byteToWrite >= 128 and byteToWrite - 256 or byteToWrite)
                    if signedWriteOk and signedWriteResult ~= false then
                        return true
                    end
                end
                return false
            end

            local originalReadOk, originalByte = tryReadByte(patchAddress)
            if not originalReadOk then
                return false
            end
            local isByteWritten = tryWriteByte(patchAddress, desiredByte)
            local verifyReadOk, verifiedByte = tryReadByte(patchAddress)
            if isByteWritten and verifyReadOk and verifiedByte == desiredByte then
                return true
            end
            tryWriteByte(patchAddress, originalByte)
            return false
        end

        if isGameVersionEnhanced then
            nopPatchPattern("ASPE", 15)
            nopPatchPattern("ANPE", 15)
            patchPatternByte("FLE", -4, 255)
        else
            nopPatchPattern("ASP", 25)
            nopPatchPattern("ANP", 25)
        end
        local cpuNameAddress
        if not isGameVersionEnhanced then
            cpuNameAddress = Memory.Rip(ptrnScan("GCIN", ksPattern("GCIN")) + 3)
        else
            cpuNameAddress = Memory.Rip(ptrnScan("GCINE", ksPattern("GCINE")) + 3)
        end
        local cpuSpeedAddress
        if not isGameVersionEnhanced then
            cpuSpeedAddress = Memory.Rip(ptrnScan("GCIS", ksPattern("GCIS")) + 3)
        else
            cpuSpeedAddress = Memory.Rip(ptrnScan("GCISE", ksPattern("GCISE")) + 3)
        end
        local gpuNameAddress = nil
        local gpuDirectXVersionAddress = nil
        local gpuDeviceTableAddress = nil
        local gpuVendorStringAddress = nil
        if not isGameVersionEnhanced then
            gpuNameAddress = Memory.Rip(ptrnScan("GVCIN", ksPattern("GVCIN")) + 3)
            gpuDirectXVersionAddress = Memory.Rip(ptrnScan("GVCIDXV", ksPattern("GVCIDXV")) + 3)
            gpuVendorStringAddress = Memory.Rip(ptrnScan("GVCIVEN", ksPattern("GVCIVEN")) + 3)
        else
            gpuDeviceTableAddress = Memory.Rip(ptrnScan("GPTBE", ksPattern("GPTBE")) + 3)
        end
        local motherboardNameAddress
        if not isGameVersionEnhanced then
            motherboardNameAddress = Memory.Rip(ptrnScan("GBIN", ksPattern("GBIN")) + 3)
        else
            motherboardNameAddress = Memory.Rip(ptrnScan("GBINE", ksPattern("GBINE")) + 3)
        end
        local windowsVersionAddress
        if not isGameVersionEnhanced then
            windowsVersionAddress = Memory.Rip(ptrnScan("GWV", ksPattern("GWV")) + 3)
        else
            windowsVersionAddress = Memory.Rip(ptrnScan("GWVE", ksPattern("GWVE")) + 3)
        end
        local biosVersionAddress
        if not isGameVersionEnhanced then
            biosVersionAddress = Memory.Rip(ptrnScan("GBIV", ksPattern("GBIV")) + 3)
        else
            biosVersionAddress = Memory.Rip(ptrnScan("GBIVE", ksPattern("GBIVE")) + 3)
        end
        local biosVendorAddress
        if not isGameVersionEnhanced then
            biosVendorAddress = Memory.Rip(ptrnScan("GBIVEN", ksPattern("GBIVEN")) + 3)
        else
            biosVendorAddress = Memory.Rip(ptrnScan("GBIVENE", ksPattern("GBIVENE")) + 3)
        end
        local baseBoardManufacturerAddress
        if not isGameVersionEnhanced then
            baseBoardManufacturerAddress = Memory.Rip(ptrnScan("GBIMAN", ksPattern("GBIMAN")) + 3)
        else
            baseBoardManufacturerAddress = Memory.Rip(ptrnScan("GBIMANE", ksPattern("GBIMANE")) + 3)
        end
        local giveControlEventTrigger
        if not isGameVersionEnhanced then
            giveControlEventTrigger = ptrnScan("CGCET", ksPattern("CGCET"))
        else
            giveControlEventTrigger = ptrnScan("CGCETE", ksPattern("CGCETE"))
        end
        local weaponDamageEventTrigger
        if not isGameVersionEnhanced then
            weaponDamageEventTrigger = ptrnScan("CWDET", ksPattern("CWDET"))
        else
            weaponDamageEventTrigger = ptrnScan("CWDETE", ksPattern("CWDETE"))
        end
        if weaponDamageEventTrigger ~= nil then
            weaponDamageEventTrigger = Memory.Rip(weaponDamageEventTrigger + 1)
        end
        local removeWeaponEventTrigger
        if not isGameVersionEnhanced then
            removeWeaponEventTrigger = ptrnScan("CRWET", ksPattern("CRWET"), nil, nil, true)
        else
            removeWeaponEventTrigger = ptrnScan("CRWETE", ksPattern("CRWETE"), nil, nil, true)
        end
        local hostKickSessionPointer = nil
        local hostKickResponsePatchA = nil
        local hostKickResponsePatchB = nil
        local hostKickPatternKey = isGameVersionEnhanced and "SCKPE" or "SCKP"
        local hostKickSessionPatternKey = isGameVersionEnhanced and "SCSSE" or "SCSS"
        local hostKickBlacklistPatternKey = isGameVersionEnhanced and "SCBLE" or "SCBL"
        local hostKickResponseAPatternKey = isGameVersionEnhanced and "SCRAE" or "SCRA"
        local hostKickResponseBPatternKey = isGameVersionEnhanced and "SCRBE" or "SCRB"
        local hostKickFunction = ptrnScan(hostKickPatternKey, ksPattern(hostKickPatternKey), nil, nil, true)
        local hostKickBlacklistFunction = ptrnScan(hostKickBlacklistPatternKey, ksPattern(hostKickBlacklistPatternKey), nil, nil, true)
        local hostKickSessionMatch = ptrnScan(hostKickSessionPatternKey, ksPattern(hostKickSessionPatternKey), nil, nil, true)
        if hostKickSessionMatch ~= nil then
            hostKickSessionPointer = Memory.Rip(hostKickSessionMatch + (isGameVersionEnhanced and 26 or 3))
        end
        local hostKickResponseAMatch = ptrnScan(hostKickResponseAPatternKey, ksPattern(hostKickResponseAPatternKey), nil, nil, true)
        local hostKickResponseBMatch = ptrnScan(hostKickResponseBPatternKey, ksPattern(hostKickResponseBPatternKey), nil, nil, true)
        if hostKickResponseAMatch ~= nil then
            hostKickResponsePatchA = hostKickResponseAMatch + (isGameVersionEnhanced and 2 or 10)
        end
        if hostKickResponseBMatch ~= nil then
            hostKickResponsePatchB = hostKickResponseBMatch + (isGameVersionEnhanced and 2 or 15)
        end
        local blameKillDamageTypePatch, blameKillScopePatch
        if not isGameVersionEnhanced then
            blameKillDamageTypePatch = ptrnScan("BKDT", ksPattern("BKDT"))
            blameKillScopePatch = ptrnScan("BKSP", ksPattern("BKSP"))
        else
            blameKillDamageTypePatch = ptrnScan("BKDTE", ksPattern("BKDTE"))
            blameKillScopePatch = ptrnScan("BKSPE", ksPattern("BKSPE"))
        end
        local geoLocInfoMatch
        if not isGameVersionEnhanced then
            geoLocInfoMatch = ptrnScan("RGGLI", ksPattern("RGGLI"))
        else
            geoLocInfoMatch = ptrnScan("RGGLIE", ksPattern("RGGLIE"))
        end
        local geoLocInfoFunction
        if geoLocInfoMatch ~= nil then
            if not isGameVersionEnhanced then
                geoLocInfoFunction = Memory.Rip(geoLocInfoMatch + 16)
            else
                geoLocInfoFunction = Memory.Rip(geoLocInfoMatch + 3)
            end
        else
            return
        end
        local natTypeMatch
        if not isGameVersionEnhanced then
            natTypeMatch = ptrnScan("NINT", ksPattern("NINT"))
        else
            natTypeMatch = ptrnScan("NINTE", ksPattern("NINTE"))
        end
        local natTypeAddress
        if natTypeMatch ~= nil then
            natTypeAddress = Memory.Rip(natTypeMatch + 6)
        else
            return
        end
        local writeBoolFunction
        if not isGameVersionEnhanced then
            writeBoolFunction = ptrnScan("WB", ksPattern("WB"))
        else
            writeBoolFunction = ptrnScan("WBE", ksPattern("WBE"))
        end
        if writeBoolFunction == nil then
            return
        end
        local writeUnsignedFunction
        if not isGameVersionEnhanced then
            writeUnsignedFunction = ptrnScan("WU", ksPattern("WU"))
        else
            writeUnsignedFunction = ptrnScan("WUE", ksPattern("WUE"))
        end
        if writeUnsignedFunction == nil then
            return
        end
        local privilegeCheckMatch
        if not isGameVersionEnhanced then
            privilegeCheckMatch = ptrnScan("RRCHP", ksPattern("RRCHP"))
        else
            privilegeCheckMatch = ptrnScan("RRCHPE", ksPattern("RRCHPE"))
        end
        local privilegeCheckFunction
        if privilegeCheckMatch == nil then
            return
        else
            privilegeCheckFunction = Memory.Rip(privilegeCheckMatch + 1)
        end
        local networkSessionMatch
        if not isGameVersionEnhanced then
            networkSessionMatch = ptrnScan("CNS", ksPattern("CNS"))
        else
            networkSessionMatch = ptrnScan("CNSE", ksPattern("CNSE"))
        end
        local networkSessionAddress
        if networkSessionMatch == nil then
            return
        else
            networkSessionAddress = Memory.Rip(networkSessionMatch + 3)
        end
        if cpuNameAddress ~= nil then
            local cpuName = Memory.ReadString(cpuNameAddress)
            HW_COMPONENTS.CPU_NAME = cpuName
        end
        if cpuSpeedAddress ~= nil then
            local cpuSpeed = Memory.ReadString(cpuSpeedAddress)
            HW_COMPONENTS.CPU_SPEED = cpuSpeed
        end
        if motherboardNameAddress ~= nil then
            local motherboardName = Memory.ReadString(motherboardNameAddress)
            HW_COMPONENTS.MOBO_NAME = motherboardName
        end
        if motherboardNameAddress ~= nil then
            local windowsVersion = Memory.ReadString(windowsVersionAddress)
            HW_COMPONENTS.WINDOWS_VERSION = windowsVersion
        end
        if gpuNameAddress ~= nil then
            local gpuName = Memory.ReadString(gpuNameAddress)
            HW_COMPONENTS.GPU_NAME = gpuName
        end
        if gpuDirectXVersionAddress ~= nil then
            local gpuDirectXVersion = Memory.ReadString(gpuDirectXVersionAddress)
            HW_COMPONENTS.GPU_DIRECTX_VERSION = gpuDirectXVersion
        end
        if biosVersionAddress ~= nil then
            local biosVersion = Memory.ReadString(biosVersionAddress)
            HW_COMPONENTS.BIOS_VERSION = biosVersion
        end
        if biosVendorAddress ~= nil then
            local biosVendor = Memory.ReadString(biosVendorAddress)
            HW_COMPONENTS.BIOS_VENDOR = biosVendor
        end
        if baseBoardManufacturerAddress ~= nil then
            local baseBoardManufacturer = Memory.ReadString(baseBoardManufacturerAddress)
            HW_COMPONENTS.BASE_BOARD_MANUFA = baseBoardManufacturer
        end
        if gpuDeviceTableAddress ~= nil then
            local adapterRecordSize = 10048

            local function readAdapterRecordString(recordTableBase, recordIndex, fieldOffset)
                return Memory.ReadString(recordTableBase + recordIndex * adapterRecordSize + fieldOffset)
            end

            local adapterCountAddress = Memory.Rip(ptrnScan("GICE", ksPattern("GICE")) + 3) + 2
            if adapterCountAddress == nil then
                Logger.LogError("K-Script: runtime initialization failed.")
                requestScriptUnload()
                return
            end
            local adapterCount = Memory.ReadUShort(adapterCountAddress)

            local function toUpperOrEmpty(sourceText)
                return (sourceText or ""):upper()
            end

            local function isSoftwarePnpId(pnpId)
                if not pnpId or pnpId == "" then
                    return true
                end
                pnpId = pnpId:upper()
                if pnpId:find("ROOT\\", 1, true) then
                    return true
                end
                if pnpId:find("SWD\\", 1, true) then
                    return true
                end
                if pnpId:find("SW\\", 1, true) then
                    return true
                end
                return false
            end

            local function isVirtualDisplayAdapter(nameText, captionText, descriptionText, processorText)
                local combinedAdapterText = ((nameText or "") .. " " .. (captionText or "") .. " " .. (descriptionText or "") .. " " .. (processorText or "")):upper()
                local renderOnlyMarker, unusedExtraMarker = "RENDER ONLY"
                for _, virtualMarker in ipairs({
                    "MICROSOFT BASIC DISPLAY",
                    "MICROSOFT REMOTE DISPLAY",
                    "REMOTE DISPLAY",
                    "INDIRECT DISPLAY",
                    "RDP",
                    "VIRTUAL",
                    "MIRAGE",
                    "VMWARE",
                    "VIRTUALBOX",
                    "PARALLELS",
                    "HYPER%-V",
                    "CITRIX",
                    "DISPLAYLINK",
                    renderOnlyMarker,
                    unusedExtraMarker,
                }) do
                    if virtualMarker:find("%%") then
                        if combinedAdapterText:match(virtualMarker) then
                            return true
                        end
                    elseif combinedAdapterText:find(virtualMarker, 1, true) then
                        return true
                    end
                end
                return false
            end

            local function isIntegratedGpu(captionText, nameText, descriptionText, processorText)
                local upperAdapterText = toUpperOrEmpty((captionText or "") .. " " .. (nameText or "") .. " " .. (descriptionText or "") .. " " .. (processorText or ""))
                if upperAdapterText:find("RADEON(TM) GRAPHICS", 1, true) then
                    return true
                end
                if upperAdapterText:find("INTEL(R) UHD", 1, true) then
                    return true
                end
                if upperAdapterText:find("INTEL(R) IRIS", 1, true) then
                    return true
                end
                if upperAdapterText:find("INTEL(R) GRAPHICS", 1, true) then
                    return true
                end
                if upperAdapterText:find("RADEON 7", 1, true) and upperAdapterText:find("M", 1, true) then
                    return true
                end
                return false
            end

            local function isDiscreteGpu(captionText, nameText, descriptionText, processorText)
                local upperAdapterText = toUpperOrEmpty((captionText or "") .. " " .. (nameText or "") .. " " .. (descriptionText or "") .. " " .. (processorText or ""))
                if upperAdapterText:find("GEFORCE", 1, true) then
                    return true
                end
                if upperAdapterText:find("RTX", 1, true) then
                    return true
                end
                if upperAdapterText:find("GTX", 1, true) then
                    return true
                end
                if upperAdapterText:find("QUADRO", 1, true) then
                    return true
                end
                if upperAdapterText:find("TESLA", 1, true) then
                    return true
                end
                if upperAdapterText:find("RADEON RX", 1, true) then
                    return true
                end
                if upperAdapterText:find("FIREPRO", 1, true) then
                    return true
                end
                if upperAdapterText:find("RADEON PRO", 1, true) then
                    return true
                end
                return false
            end

            local function scoreGpuAdapter(pnpIdText, deviceIdText, nameText, captionText, descriptionText, processorText)
                local totalScore = 0
                if isSoftwarePnpId(pnpIdText) then
                    totalScore = totalScore - 200
                end
                if isVirtualDisplayAdapter(nameText, captionText, descriptionText, processorText) then
                    totalScore = totalScore - 150
                end
                if toUpperOrEmpty((pnpIdText or "") .. " " .. (deviceIdText or "")):find("PCI\\VEN_", 1, true) then
                    totalScore = totalScore + 30
                end
                if isDiscreteGpu(captionText, nameText, descriptionText, processorText) then
                    totalScore = totalScore + 200
                end
                if isIntegratedGpu(captionText, nameText, descriptionText, processorText) then
                    totalScore = totalScore - 80
                end
                return totalScore
            end

            local bestAdapterScore = -999999
            local bestAdapter = nil
            for adapterIndex = 0, adapterCount - 1 do
                local adapterCompatibility = readAdapterRecordString(gpuDeviceTableAddress, adapterIndex, 8)
                local adapterDacType = readAdapterRecordString(gpuDeviceTableAddress, adapterIndex, 520)
                local creationClassName = readAdapterRecordString(gpuDeviceTableAddress, adapterIndex, 2096)
                local adapterCaption = readAdapterRecordString(gpuDeviceTableAddress, adapterIndex, 1560)
                local adapterDescription = readAdapterRecordString(gpuDeviceTableAddress, adapterIndex, 2672)
                local adapterDeviceId = readAdapterRecordString(gpuDeviceTableAddress, adapterIndex, 3184)
                local driverDate = readAdapterRecordString(gpuDeviceTableAddress, adapterIndex, 3720)
                local driverVersion = readAdapterRecordString(gpuDeviceTableAddress, adapterIndex, 4240)
                local infFilename = readAdapterRecordString(gpuDeviceTableAddress, adapterIndex, 4768)
                local infSection = readAdapterRecordString(gpuDeviceTableAddress, adapterIndex, 5280)
                local installedDisplayDrivers = readAdapterRecordString(gpuDeviceTableAddress, adapterIndex, 5800)
                local adapterName = readAdapterRecordString(gpuDeviceTableAddress, adapterIndex, 6360)
                local pnpDeviceId = readAdapterRecordString(gpuDeviceTableAddress, adapterIndex, 6888)
                local adapterStatus = readAdapterRecordString(gpuDeviceTableAddress, adapterIndex, 7440)
                local systemCreationClassName = readAdapterRecordString(gpuDeviceTableAddress, adapterIndex, 7960)
                local systemName = readAdapterRecordString(gpuDeviceTableAddress, adapterIndex, 8472)
                local videoModeDescription = readAdapterRecordString(gpuDeviceTableAddress, adapterIndex, 9024)
                local videoProcessor = readAdapterRecordString(gpuDeviceTableAddress, adapterIndex, 9536)
                local adapterScore = scoreGpuAdapter(pnpDeviceId, adapterDeviceId, adapterName, adapterCaption, adapterDescription, videoProcessor)
                if bestAdapterScore < adapterScore then
                    bestAdapterScore = adapterScore
                    bestAdapter = { caption = adapterCaption, pnp = pnpDeviceId }
                end
                if bestAdapter then
                    HW_COMPONENTS.GPU_NAME = bestAdapter.caption
                    HW_COMPONENTS.GPU_PNP_DEVICE_ID = bestAdapter.pnp
                    HW_COMPONENTS.GPU_DRIVER_NAME = bestAdapter.driverName
                end
            end
        end
        ksDeferStartupPatternWipe("signature scan", 7500)

        local function parseGpuVendorString(vendorInfoText)
            local vendorIdDigits = vendorInfoText:match("Vendor:%s*(%d+)")
            local deviceIdDigits = vendorInfoText:match("Device:%s*(%d+)")
            local subsystemIdDigits = vendorInfoText:match("Subsystem:%s*(%d+)")
            local revisionDigits = vendorInfoText:match("Rev:%s*(%d+)")
            if not (vendorIdDigits and deviceIdDigits and subsystemIdDigits) or not revisionDigits then
                return nil, "Failed to parse GPU vendor string"
            end
            return tonumber(vendorIdDigits), tonumber(deviceIdDigits), tonumber(subsystemIdDigits), tonumber(revisionDigits)
        end

        local function buildPciDeviceId(vendorInfoText)
            local vendorId, deviceId, subsystemId, revisionId = parseGpuVendorString(vendorInfoText)
            if not vendorId then
                Logger.LogError("K-Script: Failed to create critical Data #3!")
                requestScriptUnload()
                return nil
            end
            local vendorHex = string.format("%04X", vendorId)
            local deviceHex = string.format("%04X", deviceId)
            local subsystemHex = string.format("%08X", subsystemId)
            local revisionHex = string.format("%02X", revisionId)
            return string.format("PCI\\VEN_%s&DEV_%s&SUBSYS_%s&REV_%s", vendorHex, deviceHex, subsystemHex, revisionHex)
        end

        if gpuVendorStringAddress ~= nil then
            local gpuPnpDeviceId = buildPciDeviceId(Memory.ReadString(gpuVendorStringAddress))
            HW_COMPONENTS.GPU_PNP_DEVICE_ID = gpuPnpDeviceId
        end
        local expectedOnlineVersion = ksGameValue("onlineVersion")
        local isVersionCheckScheduled = false
        local isOnlineVersionChecked = false

        local function trySignalRuntimeReady()
            if startupProgressState.status == "ready" then
                return true
            end
            if not isRuntimeGenerationCurrent() or startupProgressState.status ~= "running" then
                return false
            end
            if isOnlineVersionChecked then
                return queueRuntimeReadySignal()
            end
            return false
        end

        local function verifyOnlineVersion()
            if not isRuntimeGenerationCurrent() then
                return false
            end
            setStartupPhase("finalizing", 0.95)
            if isOnlineVersionChecked or ShouldUnload() then
                return true
            end
            if not ksNativeDbLoaded or type(NETWORK) ~= "table" or type(NETWORK.GET_ONLINE_VERSION) ~= "function" then
                failStartup("KS-260")
                Logger.LogError("K-Script: online version check unavailable.")
                requestScriptUnload()
                return false
            end
            local currentOnlineVersion = NETWORK.GET_ONLINE_VERSION()
            isOnlineVersionChecked = true
            if currentOnlineVersion ~= expectedOnlineVersion then
                failStartup("KS-260")
                notify(("Online Version Unsupported, wait for an Update. (%s)"):format(tostring(expectedOnlineVersion)))
                requestScriptUnload()
                return false
            end
            trySignalRuntimeReady()
            return true
        end

        local function scheduleOnlineVersionCheck()
            if isVersionCheckScheduled then
                return
            end
            isVersionCheckScheduled = true
            local versionCheckGeneration = loaderLoadGeneration
            Script.QueueJob(function()
                Script.Yield(1500)
                if versionCheckGeneration ~= startupProgressState.generation or not isRuntimeGenerationCurrent() then
                    return
                end
                if ShouldUnload() then
                    return
                end
                verifyOnlineVersion()
            end)
        end

        TransitionState = {
            EMPTY = 0,
            SP_SWOOP_UP = 1,
            MP_SWOOP_UP = 2,
            CREATOR_SWOOP_UP = 3,
            PRE_HUD_CHECKS = 4,
            WAIT_HUD_EXIT = 5,
            WAIT_FOR_SUMMON = 6,
            SP_SWOOP_DOWN = 7,
            MP_SWOOP_DOWN = 8,
            CANCEL_JOINING = 9,
            RETRY_LOADING = 10,
            RETRY_LOADING_SLOT_1 = 11,
            RETRY_LOADING_SLOT_2 = 12,
            RETRY_LOADING_SLOT_3 = 13,
            RETRY_LOADING_SLOT_4 = 14,
            WAIT_ON_INVITE = 15,
            PREJOINING_FM_SESSION_CHECKS = 16,
            LOOK_FOR_FRESH_JOIN_FM = 17,
            LOOK_TO_JOIN_ANOTHER_SESSION_FM = 18,
            CONFIRM_FM_SESSION_JOINING = 19,
            WAIT_JOIN_FM_SESSION = 20,
            CREATION_ENTER_SESSION = 21,
            PRE_FM_LAUNCH_SCRIPT = 22,
            FM_TEAMFULL_CHECK = 23,
            START_FM_LAUNCH_SCRIPT = 24,
            FM_TRANSITION_CREATE_PLAYER = 25,
            IS_FM_AND_TRANSITION_READY = 26,
            FM_SWOOP_DOWN = 27,
            POST_BINK_VIDEO_WARP = 28,
            FM_FINAL_SETUP_PLAYER = 29,
            MOVE_FM_TO_RUNNING_STATE = 30,
            FM_HOW_TO_TERMINATE = 31,
            START_CREATOR_PRE_LAUNCH_SCRIPT_CHECK = 32,
            START_CREATOR_LAUNCH_SCRIPT = 33,
            CREATOR_TRANSITION_CREATE_PLAYER = 34,
            IS_CREATOR_AND_TRANSITION_READY = 35,
            CREATOR_SWOOP_DOWN = 36,
            CREATOR_FINAL_SETUP_PLAYER = 37,
            MOVE_CREATOR_TO_RUNNING_STATE = 38,
            PREJOINING_TESTBED_SESSION_CHECKS = 39,
            LOOK_FOR_FRESH_JOIN_TESTBED = 40,
            LOOK_FOR_FRESH_HOST_TESTBED = 41,
            LOOK_TO_JOIN_ANOTHER_SESSION_TESTBED = 42,
            LOOK_TO_HOST_SESSION_TESTBED = 43,
            CONFIRM_TESTBED_SESSION_JOINING = 44,
            WAIT_JOIN_TESTBED_SESSION = 45,
            START_TESTBED_LAUNCH_SCRIPT = 46,
            TESTBED_TRANSITION_CREATE_PLAYER = 47,
            IS_TESTBED_AND_TRANSITION_READY = 48,
            TESTBED_SWOOP_DOWN = 49,
            TESTBED_FINAL_SETUP_PLAYER = 50,
            MOVE_TESTBED_TO_RUNNING_STATE = 51,
            TESTBED_HOW_TO_TERMINATE = 52,
            QUIT_CURRENT_SESSION_PROMPT = 53,
            WAIT_FOR_TRANSITION_SESSION_TO_SETUP = 54,
            TERMINATE_SP = 55,
            WAIT_TERMINATE_SP = 56,
            KICK_TERMINATE_SESSION = 57,
            TERMINATE_SESSION = 58,
            WAIT_TERMINATE_SESSION = 59,
            TERMINATE_SESSION_AND_HOLD = 60,
            TERMINATE_SESSION_AND_MOVE_INTO_HOLDING_STATE = 61,
            TEAM_SWAPPING_CHECKS = 62,
            RETURN_TO_SINGLEPLAYER = 63,
            WAIT_FOR_SINGLEPLAYER_TO_START = 64,
            WAITING_FOR_EXTERNAL_TERMINATION_CALL = 65,
            TERMINATE_MAINTRANSITION = 66,
            WAIT_FOR_DIRTY_LOAD_CONFIRM = 67,
            DLC_INTRO_BINK = 68,
            SPAWN_INTO_PERSONAL_VEHICLE = 69,
        }
        eNetGameEvent = {
            OBJECT_ID_FREED_EVENT = 0,
            OBJECT_ID_REQUEST_EVENT = 1,
            ARRAY_DATA_VERIFY_EVENT = 2,
            SCRIPT_ARRAY_DATA_VERIFY_EVENT = 3,
            REQUEST_CONTROL_EVENT = 4,
            GIVE_CONTROL_EVENT = 5,
            WEAPON_DAMAGE_EVENT = 6,
            REQUEST_PICKUP_EVENT = 7,
            REQUEST_MAP_PICKUP_EVENT = 8,
            GAME_CLOCK_EVENT = 9,
            GAME_WEATHER_EVENT = 10,
            RESPAWN_PLAYER_PED_EVENT = 11,
            GIVE_WEAPON_EVENT = 12,
            REMOVE_WEAPON_EVENT = 13,
            REMOVE_ALL_WEAPONS_EVENT = 14,
            VEHICLE_COMPONENT_CONTROL_EVENT = 15,
            FIRE_EVENT = 16,
            EXPLOSION_EVENT = 17,
            START_PROJECTILE_EVENT = 18,
            UPDATE_PROJECTILE_TARGET_EVENT = 19,
            REMOVE_PROJECTILE_ENTITY_EVENT = 20,
            BREAK_PROJECTILE_TARGET_LOCK_EVENT = 21,
            ALTER_WANTED_LEVEL_EVENT = 22,
            CHANGE_RADIO_STATION_EVENT = 23,
            RAGDOLL_REQUEST_EVENT = 24,
            PLAYER_TAUNT_EVENT = 25,
            PLAYER_CARD_STAT_EVENT = 26,
            DOOR_BREAK_EVENT = 27,
            SCRIPTED_GAME_EVENT = 28,
            REMOTE_SCRIPT_INFO_EVENT = 29,
            REMOTE_SCRIPT_LEAVE_EVENT = 30,
            MARK_AS_NO_LONGER_NEEDED_EVENT = 31,
            CONVERT_TO_SCRIPT_ENTITY_EVENT = 32,
            SCRIPT_WORLD_STATE_EVENT = 33,
            CLEAR_AREA_EVENT = 34,
            CLEAR_RECTANGLE_AREA_EVENT = 35,
            NETWORK_REQUEST_SYNCED_SCENE_EVENT = 36,
            NETWORK_START_SYNCED_SCENE_EVENT = 37,
            NETWORK_STOP_SYNCED_SCENE_EVENT = 38,
            NETWORK_UPDATE_SYNCED_SCENE_EVENT = 39,
            INCIDENT_ENTITY_EVENT = 40,
            GIVE_PED_SCRIPTED_TASK_EVENT = 41,
            GIVE_PED_SEQUENCE_TASK_EVENT = 42,
            NETWORK_CLEAR_PED_TASKS_EVENT = 43,
            NETWORK_START_PED_ARREST_EVENT = 44,
            NETWORK_START_PED_UNCUFF_EVENT = 45,
            NETWORK_SOUND_CAR_HORN_EVENT = 46,
            NETWORK_ENTITY_AREA_STATUS_EVENT = 47,
            NETWORK_GARAGE_OCCUPIED_STATUS_EVENT = 48,
            PED_CONVERSATION_LINE_EVENT = 49,
            SCRIPT_ENTITY_STATE_CHANGE_EVENT = 50,
            NETWORK_PLAY_SOUND_EVENT = 51,
            NETWORK_STOP_SOUND_EVENT = 52,
            NETWORK_PLAY_AIRDEFENSE_FIRE_EVENT = 53,
            NETWORK_BANK_REQUEST_EVENT = 54,
            NETWORK_AUDIO_BARK_EVENT = 55,
            REQUEST_DOOR_EVENT = 56,
            NETWORK_TRAIN_REPORT_EVENT = 57,
            NETWORK_TRAIN_REQUEST_EVENT = 58,
            NETWORK_INCREMENT_STAT_EVENT = 59,
            MODIFY_VEHICLE_LOCK_WORD_STATE_DATA = 60,
            MODIFY_PTFX_WORD_STATE_DATA_SCRIPTED_EVOLVE_EVENT = 61,
            REQUEST_PHONE_EXPLOSION_EVENT = 62,
            REQUEST_DETACHMENT_EVENT = 63,
            KICK_VOTES_EVENT = 64,
            GIVE_PICKUP_REWARDS_EVENT = 65,
            BLOW_UP_VEHICLE_EVENT = 66,
            NETWORK_SPECIAL_FIRE_EQUIPPED_WEAPON = 67,
            NETWORK_RESPONDED_TO_THREAT_EVENT = 68,
            NETWORK_SHOUT_TARGET_POSITION = 69,
            VOICE_DRIVEN_MOUTH_MOVEMENT_FINISHED_EVENT = 70,
            PICKUP_DESTROYED_EVENT = 71,
            UPDATE_PLAYER_SCARS_EVENT = 72,
            NETWORK_CHECK_EXE_SIZE_EVENT = 73,
            NETWORK_PTFX_EVENT = 74,
            NETWORK_PED_SEEN_DEAD_PED_EVENT = 75,
            REMOVE_STICKY_BOMB_EVENT = 76,
            NETWORK_CHECK_CODE_CRCS_EVENT = 77,
            INFORM_SILENCED_GUNSHOT_EVENT = 78,
            PED_PLAY_PAIN_EVENT = 79,
            CACHE_PLAYER_HEAD_BLEND_DATA_EVENT = 80,
            REMOVE_PED_FROM_PEDGROUP_EVENT = 81,
            REPORT_MYSELF_EVENT = 82,
            REPORT_CASH_SPAWN_EVENT = 83,
            ACTIVATE_VEHICLE_SPECIAL_ABILITY_EVENT = 84,
            BLOCK_WEAPON_SELECTION = 85,
            NETWORK_CHECK_CATALOG_CRC = 86,
        }
        eNetObjectTypeNames = {
            [0] = "NET_OBJ_TYPE_AUTOMOBILE",
            [1] = "NET_OBJ_TYPE_BIKE",
            [2] = "NET_OBJ_TYPE_BOAT",
            [3] = "NET_OBJ_TYPE_DOOR",
            [4] = "NET_OBJ_TYPE_HELI",
            [5] = "NET_OBJ_TYPE_OBJECT",
            [6] = "NET_OBJ_TYPE_PED",
            [7] = "NET_OBJ_TYPE_PICKUP",
            [8] = "NET_OBJ_TYPE_PICKUP_PLACEMENT",
            [9] = "NET_OBJ_TYPE_PLANE",
            [10] = "NET_OBJ_TYPE_SUBMARINE",
            [11] = "NET_OBJ_TYPE_PLAYER",
            [12] = "NET_OBJ_TYPE_TRAILER",
            [13] = "NET_OBJ_TYPE_TRAIN",
            [14] = "NET_OBJ_TYPE_GLASS_PANE",
            [15] = "NUM_NET_OBJ_TYPES",
        }
        local featureModuleId = "m2"
        setStartupModuleId(featureModuleId)
        local featureModuleVariant = "default"

        local function getSanitizedModuleError()
            local lastModuleError = nil
            if type(KSModules) == "table" and type(KSModules.lastError) == "table" then
                lastModuleError = KSModules.lastError[featureModuleId]
            end
            local sanitizedErrorCode = tostring(lastModuleError or "unknown"):gsub("[^%w_%-]", "_")
            if sanitizedErrorCode == "" then
                sanitizedErrorCode = "unknown"
            end
            return sanitizedErrorCode:sub(1, 64)
        end

        local function isSignatureVerificationFailure(failureCode)
            return failureCode == "verify_signature"
        end

        local function loadFeatureModule()
            if not isRuntimeGenerationCurrent() then
                return true
            end
            setStartupPhase("modules", 0.73)
            if type(KSModules) ~= "table" or type(KSModules.ensureAsync) ~= "function" then
                Logger.LogError("K-Script: module unavailable.")
                if type(reportRuntimeIntegrityEvent) == "function" then
                    reportRuntimeIntegrityEvent("feature_plane_unavailable", true)
                end
                return false
            end
            local moduleContext = {
                variant = featureModuleVariant,
                KS_RUNTIME_LOAD_GENERATION = loaderLoadGeneration,
                __ksSettingsSaveState = { generation = loaderLoadGeneration, active = false, invocationCount = 0 },
                KS_NATIVE_HOST_FACTORY = true,
                LogStartupStage = logStartupFeatureStage,
                startTime = scriptLoadStartClock,
                Features = registeredFeatures,
                activeFeatures = onlineUserJoinButtons,
                loadPlayerNotes = loadPlayerNotes,
                safe = toDisplayStringOrNA,
                DP = DP,
                e_dances = e_dances,
                vehicleProtNames = vehicleProtNames,
                m_RegionCode = m_RegionCode,
                netNatType = netNatType,
                CGiveControlEventTrigger = giveControlEventTrigger,
                CWeaponDamageEventTrigger = weaponDamageEventTrigger,
                CRemoveWeaponEventTrigger = removeWeaponEventTrigger,
                KSHostKickFunction = hostKickFunction,
                KSHostKickBlacklistFunction = hostKickBlacklistFunction,
                KSHostKickSessionPointer = hostKickSessionPointer,
                KSHostKickResponsePatchA = hostKickResponsePatchA,
                KSHostKickResponsePatchB = hostKickResponsePatchB,
                KSBlameKillDamageTypePatch = blameKillDamageTypePatch,
                KSBlameKillScopePatch = blameKillScopePatch,
                rlRosGetGeoLocInfo = geoLocInfoFunction,
                sm_NetInfo_m_NatType = natTypeAddress,
                WriteBool = writeBoolFunction,
                WriteUnsigned = writeUnsignedFunction,
                CNetworkSession = networkSessionAddress,
                LookupModderReasonForPlayer = LookupModderReasonForPlayer,
                KSCanonicalPlayerIdentifier = KSCanonicalPlayerIdentifier,
                KSClearRemotePlayerStatus = KSClearRemotePlayerStatus,
                KSClearAllRemotePlayerStatuses = KSClearAllRemotePlayerStatuses,
                KSClearDetectedPlayerCache = KSClearDetectedPlayerCache,
                KSReportBlacklistActionResult = KSReportBlacklistActionResult,
                KSResolveCrewIdentity = KSResolveCrewIdentity,
                KS_REMOTE_PLAYER_STATUS_STATE = KSRemotePlayerStatusState,
                KS_RUNTIME_EDITION = isGameVersionEnhanced and "enhanced" or "legacy",
                KS_LOADER_SCRIPT_TIER = type(KS_STARTUP_PERMISSION_SNAPSHOT) == "table" and type(KS_STARTUP_PERMISSION_SNAPSHOT.p) == "table" and KS_STARTUP_PERMISSION_SNAPSHOT.p.n or nil,
                SwitchScriptId = ksGlobal("SwitchScriptId"),
                KS_RuntimeGenerationIsCurrent = isRuntimeGenerationCurrent,
                ShouldUnload = ShouldUnload,
                rlRosCredentials_HasPrivileges = privilegeCheckFunction,
                KSDispatchPlayerFeature = KSDispatchPlayerFeature,
                KSDispatchRuntimeFeature = KSDispatchRuntimeFeature,
                LogFeatureAction = LogFeatureAction,
                KSGetRemovalFeatureGateState = KSGetRemovalFeatureGateState,
                KSTriggerRemovalAbuseSelfTest = KSTriggerRemovalAbuseSelfTest,
                KSRuntimeTerminalViolation = KSRuntimeTerminalViolation,
            }

            function moduleContext.KS_GetBrandTexture()
                if toastTexture == nil then
                    return nil
                end
                return toastTexture:GetCurrent()
            end

            moduleContext.__r25 = clearRuntimeSession
            moduleContext.rpc_clear_activity = rpc_clear_activity
            KS_RUNTIME_MODULE_CONTEXT = moduleContext
            local moduleLoadStartClock = os.clock()
            local moduleLoadGeneration = loaderLoadGeneration
            return KSModules.ensureAsync(featureModuleId, true, moduleContext, function(loadedModule, loadFailureReason)
                if moduleLoadGeneration ~= startupProgressState.generation or not isRuntimeGenerationCurrent() then
                    return
                end
                setStartupPhase("modules", 0.88)
                if ShouldUnload() then
                    return
                end
                if type(loadedModule) ~= "table" then
                    failStartup("KS-260")
                    local failureReason = loadFailureReason or getSanitizedModuleError()
                    Logger.LogError("K-Script: module load failed.")
                    if isSignatureVerificationFailure(failureReason) and type(reportRuntimeIntegrityEvent) == "function" then
                        reportRuntimeIntegrityEvent(("feature_plane_%s"):format(failureReason), true)
                    end
                    requestScriptUnload("module_failed")
                    return
                end
                local moduleCapabilities = loadedModule.capabilities
                for _, requiredCapabilityName in ipairs({ "feature_plane.runtime_context", "feature_plane.exclusive_sync", "feature_plane.sync_data" }) do
                    local requiredCapability = type(moduleCapabilities) == "table" and moduleCapabilities[requiredCapabilityName] or nil
                    if type(requiredCapability) ~= "table" or requiredCapability.provider ~= "m2" or requiredCapability.generation ~= moduleLoadGeneration or requiredCapability.active ~= true then
                        failStartup("KS-260")
                        Logger.LogError("[K-Script Module] feature-plane capability contract invalid")
                        requestScriptUnload("module_capability_failed")
                        return
                    end
                end
                featurePlaneCapabilities = moduleCapabilities
                if type(loadedModule.variant) == "string" and loadedModule.variant ~= "" then
                    featureModuleVariant = loadedModule.variant
                end
                featureActionLogState.accepting = true
                if type(loadedModule.runtimeControl) ~= "function" or type(loadedModule.dispatchRuntimeControl) ~= "function" then
                    failStartup("KS-260")
                    Logger.LogError("[K-Script Module] authenticated runtime control contract invalid")
                    requestScriptUnload("module_capability_failed")
                    return
                end
                KS_RUNTIME_CONTROL_HANDLER = loadedModule.runtimeControl
                if type(KS_RUNTIME_MODULE_CONTEXT) == "table" then
                    KS_RUNTIME_MODULE_CONTEXT.KSDispatchRuntimeControlAction = loadedModule.dispatchRuntimeControl
                end
                if type(loadedModule.init) == "function" then
                    setStartupPhase("modules", 0.9)
                    if loadedModule.init() == false then
                        failStartup("KS-260")
                        Logger.LogError("K-Script: module initialization failed.")
                        requestScriptUnload("module_failed")
                        return
                    end
                end
                if type(loadedModule.onUIReady) ~= "function" or type(loadedModule.startRuntime) ~= "function" then
                    failStartup("KS-260")
                    Logger.LogError("K-Script: UI initialization unavailable.")
                    requestScriptUnload("ui_registration_failed")
                    return
                end
                if not reportRuntimeProgressPhase("modules_ready") then
                    failRuntimeBridgeInit()
                    return
                end
                local uiReadyGeneration = loaderLoadGeneration
                local uiReadyResult = loadedModule.onUIReady(function(isUiRegistered)
                    if uiReadyGeneration ~= startupProgressState.generation or not isRuntimeGenerationCurrent() then
                        return
                    end
                    if not isUiRegistered then
                        failStartup("KS-260")
                        requestScriptUnload("ui_registration_failed")
                    end
                end)
                local runtimeStartResult = loadedModule.startRuntime("main-runtime-ready")
                if uiReadyResult == false or runtimeStartResult == false then
                    failStartup("KS-260")
                    Logger.LogError("K-Script: UI initialization failed.")
                    requestScriptUnload("ui_registration_failed")
                    return
                end
                setStartupPhase("finalizing", 0.94)
                scheduleOnlineVersionCheck()
            end)
        end

        local hasQueuedModuleLoad = false
        ;(function()
            setStartupPhase("modules", 0.72)
            if hasQueuedModuleLoad then
                return
            end
            hasQueuedModuleLoad = true
            Script.QueueJob(function()
                if not isRuntimeGenerationCurrent() then
                    return
                end
                if ShouldUnload() then
                    return
                end
                if not loadFeatureModule() then
                    failStartup("KS-260")
                    requestScriptUnload()
                    return
                end
            end)
        end)()
    end

    setStartupPhase("configuration", 0.36)
    FetchStartupConfig(KS_STARTUP_STAGE_EDITION, detectedEdition, function(isEditionConfigLoaded)
        if isEditionConfigLoaded and not ShouldUnload() then
            setStartupPhase("runtime", 0.52)
            if not runCooperativeStartup(runEditionStartup) then
                failStartup("KS-260")
                Logger.LogError("K-Script: cooperative startup unavailable.")
                requestScriptUnload()
            end
        end
    end)
end

if FetchStartupSnapshot(startupEdition) ~= true or ShouldUnload() then
    return
end
if FetchUserPermissions(false) ~= true or ShouldUnload() then
    return
end
setStartupPhase("session", 0.14)
FetchStartupConfig(KS_STARTUP_STAGE_BOOTSTRAP, nil, function(isBootstrapConfigLoaded)
    if isBootstrapConfigLoaded and not ShouldUnload() then
        runStartupAfterBootstrapConfig()
    end
end)
