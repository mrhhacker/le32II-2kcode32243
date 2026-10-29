function x_90uMKtXsPZc4OXDLpFEd8f2kpmVFjeYL_syc(obfuscatedBlob)
    local function maskToByte(unmaskedNumber)
        return (unmaskedNumber or 0) & 255
    end

    local function readUint32LE(byteOffset)
        local lowByte, midLowByte, midHighByte, highByte = obfuscatedBlob:byte(byteOffset, byteOffset + 3)
        return maskToByte(lowByte) | maskToByte(midLowByte) << 8 | maskToByte(midHighByte) << 16 | maskToByte(highByte) << 24
    end

    local decodedChars = {}
    local cipherMode = maskToByte(obfuscatedBlob:byte(1))
    local keySeed = readUint32LE(2)
    local primaryKeyStride = maskToByte(obfuscatedBlob:byte(6))
    local primaryKeyOffset = maskToByte(obfuscatedBlob:byte(7))
    local secondaryKeyOffset = maskToByte(obfuscatedBlob:byte(8))
    local expectedLength = readUint32LE(9)
    for blobIndex = 13, #obfuscatedBlob do
        local payloadPosition = blobIndex - 12
        local primaryKeyByte = maskToByte(keySeed + payloadPosition * primaryKeyStride + primaryKeyOffset)
        local secondaryKeyByte = maskToByte((keySeed >> payloadPosition % 4 * 8) + payloadPosition * 13 + secondaryKeyOffset)
        local cipherByte = obfuscatedBlob:byte(blobIndex)
        local plainByte
        if cipherMode == 0 then
            plainByte = maskToByte(cipherByte ~ primaryKeyByte ~ secondaryKeyByte)
        elseif cipherMode == 1 then
            plainByte = maskToByte((cipherByte ~ secondaryKeyByte) - primaryKeyByte)
        elseif cipherMode == 2 then
            plainByte = maskToByte(cipherByte + secondaryKeyByte ~ primaryKeyByte)
        else
            plainByte = maskToByte((cipherByte ~ primaryKeyByte) - secondaryKeyByte)
        end
        decodedChars[#decodedChars + 1] = string.char(plainByte)
    end
    if expectedLength and #decodedChars ~= expectedLength then
        return ""
    end
    return table.concat(decodedChars)
end

local function isIndexableValue(candidateValue)
    local valueType = type(candidateValue)
    return valueType == "table" or valueType == "userdata"
end

local function hasFunctionMember(apiTable, memberName)
    if not isIndexableValue(apiTable) then
        return false
    end
    return type(apiTable[memberName]) == "function"
end

local function yieldScriptClamped(delayMs, fallbackMs)
    local requestedMs = tonumber(delayMs)
    if requestedMs == nil or requestedMs ~= requestedMs then
        requestedMs = tonumber(fallbackMs) or 0
    end
    local clampedMs = math.max(0, math.min(requestedMs, 2147483647))
    return Script.Yield(math.tointeger(math.ceil(clampedMs)))
end

local KS_ACTIVATION_ID = "00000000000000000000000000000000"
local KS_WATERMARK_ID = "000000000000000000000000"
local KS_BUILD_ID = "00000000000000000000"
local registrationSecretHex = "0000000000000000000000000000000000000000000000000000000000000000"
local registrationHmacKeyHex = "0000000000000000000000000000000000000000000000000000000000000000"
local BRIDGE_ACTIVE_GUARD_KEY = "__ks_bridge_v3_active_" .. KS_ACTIVATION_ID
local globalEnvTable = _ENV or _G
local MAX_FRAME_BYTES = 6291456
local MAX_PAYLOAD_BYTES = 4194304
local DIRECT_PAYLOAD_MAX_BYTES = 262144
local PAYLOAD_CHUNK_BYTES = 262144
local MAX_PAYLOAD_CHUNKS = 16

local function base64EncodedLength(byteCount)
    return math.floor((byteCount + 2) / 3) * 4
end

if not (DIRECT_PAYLOAD_MAX_BYTES < 1) and not (MAX_PAYLOAD_BYTES < DIRECT_PAYLOAD_MAX_BYTES) and not (PAYLOAD_CHUNK_BYTES < 1024) and not (MAX_PAYLOAD_BYTES < PAYLOAD_CHUNK_BYTES) and not (MAX_PAYLOAD_CHUNKS < 1) and not (MAX_PAYLOAD_BYTES > PAYLOAD_CHUNK_BYTES * MAX_PAYLOAD_CHUNKS) then
    local maxChunkFrameEncodedBytes = base64EncodedLength(base64EncodedLength(PAYLOAD_CHUNK_BYTES) + 4096)
    if not (MAX_FRAME_BYTES <= maxChunkFrameEncodedBytes + 512) then
        goto configLimitsValid
    end
end
SetShouldUnload()
do
    return
end
::configLimitsValid::
if #KS_ACTIVATION_ID ~= 32 or #KS_WATERMARK_ID < 16 or #KS_BUILD_ID < 8 then
    SetShouldUnload()
    return
end
if rawget(globalEnvTable, BRIDGE_ACTIVE_GUARD_KEY) then
    return
end
rawset(globalEnvTable, BRIDGE_ACTIVE_GUARD_KEY, true)
if (function(encodedConstant)
    return (encodedConstant ~ 3519025864) & 4294967295
end)(1060196501) < 0 then
    error("")
end
if not hasFunctionMember(Script, "QueueJob") or not hasFunctionMember(Script, "Yield") then
    rawset(globalEnvTable, BRIDGE_ACTIVE_GUARD_KEY, nil)
    if type(SetShouldUnload) == "function" then
        SetShouldUnload()
    end
    return
end
local queueJobPcallOk, queueJobPcallResult = pcall(Script.QueueJob, function()
    local openDeadlineMs = 0
    local trackedReadPipe = nil
    local trackedWritePipe = nil
    local isShutdownTriggered = false
    local bootOverlay = { active = false, frame = 0, handler = nil }

    function bootOverlay.stop()
        bootOverlay.active = false
        local registeredHandler = bootOverlay.handler
        bootOverlay.handler = nil
        if registeredHandler ~= nil and hasFunctionMember(EventMgr, "RemoveHandler") then
            pcall(EventMgr.RemoveHandler, registeredHandler)
        end
    end

    function bootOverlay.start()
        if bootOverlay.active or not hasFunctionMember(EventMgr, "RegisterHandler") or not isIndexableValue(eLuaEvent) or eLuaEvent.ON_PRESENT == nil or not hasFunctionMember(ImGui, "GetDisplaySize") or not hasFunctionMember(ImGui, "BgAddRectFilled") or not hasFunctionMember(ImGui, "BgAddText") then
            return false
        end
        bootOverlay.active = true
        local registerOk, overlayHandlerId = pcall(EventMgr.RegisterHandler, eLuaEvent.ON_PRESENT, function()
            if not bootOverlay.active or isShutdownTriggered then
                return
            end
            if type(ShouldUnload) == "function" and ShouldUnload() then
                bootOverlay.stop()
                return
            end
            local displaySizeOk, displayWidth, displayHeight = pcall(ImGui.GetDisplaySize)
            if not displaySizeOk or type(displayWidth) ~= "number" or type(displayHeight) ~= "number" or displayWidth <= 0 or displayHeight <= 0 then
                return
            end
            bootOverlay.frame = bootOverlay.frame + 1
            local dotAnimationStep = math.floor(bootOverlay.frame / 18)
            local panelWidth = 292
            local panelLeft = math.floor((displayWidth - panelWidth) * 0.5)
            local panelTop = math.max(20, math.floor(displayHeight * 0.045))
            local panelRight = panelLeft + panelWidth
            local panelBottom = panelTop + 54
            ImGui.BgAddRectFilled(panelLeft - 1, panelTop - 1, panelRight + 1, panelBottom + 1, 94, 30, 34, 230, 9, 0)
            ImGui.BgAddRectFilled(panelLeft, panelTop, panelRight, panelBottom, 10, 10, 12, 238, 8, 0)
            ImGui.BgAddRectFilled(panelLeft, panelTop, panelLeft + 4, panelBottom, 217, 28, 35, 255, 8, 0)
            ImGui.BgAddText(panelLeft + 17, panelTop + 10, "K-SCRIPT", 235, 52, 58, 255)
            ImGui.BgAddText(panelLeft + 17, panelTop + 29, "Starting secure runtime" .. string.rep(".", dotAnimationStep % 3 + 1), 235, 235, 238, 255)
        end)
        if not registerOk or overlayHandlerId == nil or overlayHandlerId == false then
            bootOverlay.active = false
            bootOverlay.handler = nil
            return false
        end
        bootOverlay.handler = overlayHandlerId
        return true
    end

    local function shutdownBridge(readPipe, writePipe)
        if isShutdownTriggered then
            return
        end
        isShutdownTriggered = true
        bootOverlay.stop()
        if not readPipe then
            readPipe = trackedReadPipe
        end
        if not writePipe then
            writePipe = trackedWritePipe
        end
        if readPipe then
            readPipe:close()
        end
        if writePipe and writePipe ~= readPipe then
            writePipe:close()
        end
        active_write_pipe = nil
        trackedReadPipe = nil
        rawset(globalEnvTable, BRIDGE_ACTIVE_GUARD_KEY, nil)
        if type(SetShouldUnload) == "function" then
            SetShouldUnload()
        end
    end

    bootOverlay.start()
    ;(function()
        local accumulateWorkAndYield, bytesToHex, hexToBytes, sha256Hex, hmacKeyPadCache, hmacKeyPadCacheSize, hmacSha256Hex, constantTimeEqual, constantTimeBytesEqual, encodeBase64, decodeBase64, applyChacha20Keystream, deriveSessionKeys, deriveFrameNonce, buildFrameMacMessage, runtimeClock
        do
            local uint32Mask = 4294967295
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
            local pendingWorkUnits = 0
            local workUnitsPerYield = 131072

            function accumulateWorkAndYield(workUnits)
                pendingWorkUnits = pendingWorkUnits + (tonumber(workUnits) or 1)
                if pendingWorkUnits < workUnitsPerYield then
                    return
                end
                pendingWorkUnits = 0
                Script.Yield(0)
            end

            local function packUint32BigEndian(uint32Word)
                return string.char(uint32Word >> 24 & 255, uint32Word >> 16 & 255, uint32Word >> 8 & 255, uint32Word & 255)
            end

            local function computeSha256Digest(messageBytes)
                local messageByteLength = #messageBytes
                local bitLengthHighWord = math.floor(messageByteLength / 536870912)
                local bitLengthLowMask = uint32Mask
                messageBytes = messageBytes .. "\x80" .. string.rep("\x00", (56 - (messageByteLength + 1) % 64) % 64) .. packUint32BigEndian(bitLengthHighWord) .. packUint32BigEndian(messageByteLength * 8 & bitLengthLowMask)
                local hashStateA = 1779033703
                local hashStateB = 3144134277
                local hashStateC = 1013904242
                local hashStateD = 2773480762
                local hashStateE = 1359893119
                local hashStateF = 2600822924
                local hashStateG = 528734635
                local hashStateH = 1541459225
                local messageSchedule = {}
                for blockOffset = 1, #messageBytes, 64 do
                    local blockWordOne, blockWordTwo, blockWordThree, blockWordFour, blockWordFive, blockWordSix, blockWordSeven, blockWordEight, blockWordNine, blockWordTen, blockWordEleven, blockWordTwelve, blockWordThirteen, blockWordFourteen, blockWordFifteen, blockWordSixteen = string.unpack(">I4I4I4I4I4I4I4I4I4I4I4I4I4I4I4I4", messageBytes, blockOffset)
                    messageSchedule[16] = blockWordSixteen
                    messageSchedule[15] = blockWordFifteen
                    messageSchedule[14] = blockWordFourteen
                    messageSchedule[13] = blockWordThirteen
                    messageSchedule[12] = blockWordTwelve
                    messageSchedule[11] = blockWordEleven
                    messageSchedule[10] = blockWordTen
                    messageSchedule[9] = blockWordNine
                    messageSchedule[8] = blockWordEight
                    messageSchedule[7] = blockWordSeven
                    messageSchedule[6] = blockWordSix
                    messageSchedule[5] = blockWordFive
                    messageSchedule[4] = blockWordFour
                    messageSchedule[3] = blockWordThree
                    messageSchedule[2] = blockWordTwo
                    messageSchedule[1] = blockWordOne
                    for scheduleIndex = 17, 64 do
                        local sigmaZeroInput = messageSchedule[scheduleIndex - 15]
                        local sigmaOneInput = messageSchedule[scheduleIndex - 2]
                        messageSchedule[scheduleIndex] = messageSchedule[scheduleIndex - 16] + (((sigmaZeroInput >> 7 | sigmaZeroInput << 25) ~ (sigmaZeroInput >> 18 | sigmaZeroInput << 14) ~ sigmaZeroInput >> 3) & uint32Mask) + messageSchedule[scheduleIndex - 7] + (((sigmaOneInput >> 17 | sigmaOneInput << 15) ~ (sigmaOneInput >> 19 | sigmaOneInput << 13) ~ sigmaOneInput >> 10) & uint32Mask) & uint32Mask
                    end
                    local roundStateA = hashStateA
                    local roundStateB = hashStateB
                    local roundStateC = hashStateC
                    local roundStateD = hashStateD
                    local roundStateE = hashStateE
                    local roundStateF = hashStateF
                    local roundStateG = hashStateG
                    local roundStateH = hashStateH
                    for roundIndex = 1, 64 do
                        local roundTermOne = roundStateH + (((roundStateE >> 6 | roundStateE << 26) ~ (roundStateE >> 11 | roundStateE << 21) ~ (roundStateE >> 25 | roundStateE << 7)) & uint32Mask) + (roundStateE & roundStateF ~ ~roundStateE & roundStateG) + sha256RoundConstants[roundIndex] + messageSchedule[roundIndex] & uint32Mask
                        local nextRoundStateH = roundStateG
                        local nextRoundStateG = roundStateF
                        local nextRoundStateF = roundStateE
                        local nextRoundStateE = roundStateD + roundTermOne & uint32Mask
                        local nextRoundStateD = roundStateC
                        local nextRoundStateC = roundStateB
                        local nextRoundStateB = roundStateA
                        roundStateA = roundTermOne + ((((roundStateA >> 2 | roundStateA << 30) ~ (roundStateA >> 13 | roundStateA << 19) ~ (roundStateA >> 22 | roundStateA << 10)) & uint32Mask) + (roundStateA & roundStateB ~ roundStateA & roundStateC ~ roundStateB & roundStateC) & uint32Mask) & uint32Mask
                        roundStateB = nextRoundStateB
                        roundStateC = nextRoundStateC
                        roundStateD = nextRoundStateD
                        roundStateE = nextRoundStateE
                        roundStateF = nextRoundStateF
                        roundStateG = nextRoundStateG
                        roundStateH = nextRoundStateH
                    end
                    hashStateD = hashStateD + roundStateD & uint32Mask
                    hashStateC = hashStateC + roundStateC & uint32Mask
                    hashStateB = hashStateB + roundStateB & uint32Mask
                    hashStateA = hashStateA + roundStateA & uint32Mask
                    hashStateH = hashStateH + roundStateH & uint32Mask
                    hashStateG = hashStateG + roundStateG & uint32Mask
                    hashStateF = hashStateF + roundStateF & uint32Mask
                    hashStateE = hashStateE + roundStateE & uint32Mask
                    accumulateWorkAndYield(64)
                end
                return packUint32BigEndian(hashStateA) .. packUint32BigEndian(hashStateB) .. packUint32BigEndian(hashStateC) .. packUint32BigEndian(hashStateD) .. packUint32BigEndian(hashStateE) .. packUint32BigEndian(hashStateF) .. packUint32BigEndian(hashStateG) .. packUint32BigEndian(hashStateH)
            end

            function bytesToHex(rawBytes)
                local hexText = rawBytes:gsub(".", function(byteChar)
                    return string.format("%02x", byteChar:byte())
                end)
                return hexText
            end

            function hexToBytes(hexInput)
                if type(hexInput) ~= "string" or #hexInput % 2 ~= 0 or hexInput:find("[^0-9a-fA-F]") then
                    return nil
                end
                local decodedBytes = hexInput:gsub("..", function(hexPair)
                    return string.char(tonumber(hexPair, 16))
                end)
                return decodedBytes
            end

            function sha256Hex(messageToHash)
                return bytesToHex(computeSha256Digest(messageToHash))
            end

            hmacKeyPadCache = {}
            hmacKeyPadCacheSize = 0

            local function getHmacKeyPads(hmacKey)
                if #hmacKey > 64 then
                    hmacKey = computeSha256Digest(hmacKey)
                end
                hmacKey = hmacKey .. string.rep("\x00", 64 - #hmacKey)
                local cachedKeyPads = hmacKeyPadCache[hmacKey]
                if cachedKeyPads then
                    return cachedKeyPads.inner, cachedKeyPads.outer
                end
                local innerPadChars = {}
                local outerPadChars = {}
                for keyByteIndex = 1, 64 do
                    local keyByte = hmacKey:byte(keyByteIndex)
                    innerPadChars[keyByteIndex] = string.char(keyByte ~ 54)
                    outerPadChars[keyByteIndex] = string.char(keyByte ~ 92)
                end
                local keyPads = { inner = table.concat(innerPadChars), outer = table.concat(outerPadChars) }
                if hmacKeyPadCacheSize < 16 then
                    hmacKeyPadCache[hmacKey] = keyPads
                    hmacKeyPadCacheSize = hmacKeyPadCacheSize + 1
                end
                return keyPads.inner, keyPads.outer
            end

            local function computeHmacSha256(macKey, macMessage)
                local innerKeyPad, outerKeyPad = getHmacKeyPads(macKey)
                return computeSha256Digest(outerKeyPad .. computeSha256Digest(innerKeyPad .. macMessage))
            end

            function hmacSha256Hex(macKey, macMessage)
                return bytesToHex(computeHmacSha256(macKey, macMessage))
            end

            function constantTimeEqual(leftString, rightString)
                if type(leftString) ~= "string" or type(rightString) ~= "string" or #leftString ~= #rightString then
                    return false
                end
                local differenceBits = 0
                for byteIndex = 1, #leftString do
                    differenceBits = differenceBits | leftString:byte(byteIndex) ~ rightString:byte(byteIndex)
                end
                return differenceBits == 0
            end

            function constantTimeBytesEqual(leftBytes, rightBytes)
                if type(leftBytes) ~= "string" or type(rightBytes) ~= "string" or #leftBytes ~= #rightBytes then
                    return false
                end
                local differenceBits = 0
                for byteIndex = 1, #leftBytes do
                    differenceBits = differenceBits | leftBytes:byte(byteIndex) ~ rightBytes:byte(byteIndex)
                end
                return differenceBits == 0
            end

            local base64Alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
            local sextetToBase64Char = {}
            for alphabetCharIndex = 1, #base64Alphabet do
                local alphabetChar = base64Alphabet:sub(alphabetCharIndex, alphabetCharIndex)
                sextetToBase64Char[alphabetCharIndex] = alphabetChar
            end

            function encodeBase64(bytesToEncode)
                local encodedParts = {}
                for tripletOffset = 1, #bytesToEncode, 3 do
                    if tripletOffset > 1 and (tripletOffset - 1) % 384 == 0 then
                        accumulateWorkAndYield(256)
                    end
                    local packedTriplet = (bytesToEncode:byte(tripletOffset) or 0) << 16 | (bytesToEncode:byte(tripletOffset + 1) or 0) << 8 | (bytesToEncode:byte(tripletOffset + 2) or 0)
                    encodedParts[#encodedParts + 1] = sextetToBase64Char[(packedTriplet >> 18 & 63) + 1] .. sextetToBase64Char[(packedTriplet >> 12 & 63) + 1] .. (tripletOffset + 1 <= #bytesToEncode and sextetToBase64Char[(packedTriplet >> 6 & 63) + 1] or "=") .. (tripletOffset + 2 <= #bytesToEncode and sextetToBase64Char[(packedTriplet & 63) + 1] or "=")
                end
                return table.concat(encodedParts)
            end

            local base64ByteToSextet = {}
            for alphabetByteIndex = 1, #base64Alphabet do
                local alphabetByte = base64Alphabet:byte(alphabetByteIndex)
                base64ByteToSextet[alphabetByte] = alphabetByteIndex - 1
            end

            function decodeBase64(encodedText, maxDecodedBytes)
                if type(encodedText) ~= "string" or #encodedText % 4 ~= 0 or #encodedText > math.ceil(maxDecodedBytes / 3) * 4 + 4 then
                    return nil
                end
                local decodedParts = {}
                local decodedByteCount = 0
                for quadOffset = 1, #encodedText, 4 do
                    if quadOffset > 1 and (quadOffset - 1) % 512 == 0 then
                        accumulateWorkAndYield(256)
                    end
                    local firstQuadByte, secondQuadByte, thirdQuadByte, fourthQuadByte = encodedText:byte(quadOffset, quadOffset + 3)
                    local invalidPaddingResult
                    if firstQuadByte ~= 61 and secondQuadByte ~= 61 and (thirdQuadByte ~= 61 or fourthQuadByte == 61) then
                        if thirdQuadByte ~= 61 and fourthQuadByte ~= 61 then
                            goto decodeValidQuad
                        end
                        if quadOffset + 3 == #encodedText then
                            goto decodeValidQuad
                        end
                    end
                    invalidPaddingResult = nil
                    do
                        return invalidPaddingResult
                    end
                    ::decodeValidQuad::
                    local firstSextet = base64ByteToSextet[firstQuadByte]
                    local secondSextet = base64ByteToSextet[secondQuadByte]
                    local thirdSextet = thirdQuadByte == 61 and 0 or base64ByteToSextet[thirdQuadByte]
                    local fourthSextet = fourthQuadByte == 61 and 0 or base64ByteToSextet[fourthQuadByte]
                    if firstSextet == nil or secondSextet == nil or thirdSextet == nil or fourthSextet == nil then
                        return nil
                    end
                    local packedSextets = firstSextet << 18 | secondSextet << 12 | thirdSextet << 6 | fourthSextet
                    if thirdQuadByte == 61 then
                        decodedParts[#decodedParts + 1] = string.char(packedSextets >> 16 & 255)
                        decodedByteCount = decodedByteCount + 1
                    elseif fourthQuadByte == 61 then
                        decodedParts[#decodedParts + 1] = string.char(packedSextets >> 16 & 255, packedSextets >> 8 & 255)
                        decodedByteCount = decodedByteCount + 2
                    else
                        decodedParts[#decodedParts + 1] = string.char(packedSextets >> 16 & 255, packedSextets >> 8 & 255, packedSextets & 255)
                        decodedByteCount = decodedByteCount + 3
                    end
                    if maxDecodedBytes < decodedByteCount then
                        return nil
                    end
                end
                return table.concat(decodedParts)
            end

            function applyChacha20Keystream(keyBytes, nonceBytes, messageBytes)
                if type(keyBytes) ~= "string" or #keyBytes ~= 32 or type(nonceBytes) ~= "string" or #nonceBytes ~= 12 or type(messageBytes) ~= "string" or #messageBytes > MAX_FRAME_BYTES then
                    return nil
                end
                local keyWordOne, keyWordTwo, keyWordThree, keyWordFour, keyWordFive, keyWordSix, keyWordSeven, keyWordEight = string.unpack("<I4I4I4I4I4I4I4I4", keyBytes)
                local nonceWordOne, nonceWordTwo, nonceWordThree = string.unpack("<I4I4I4", nonceBytes)
                local blockWordsFormat = "<I4I4I4I4I4I4I4I4I4I4I4I4I4I4I4I4"
                local messageLength = #messageBytes
                local outputBlocks = {}
                local blockCounter = 1
                for blockOffset = 1, messageLength, 64 do
                    local workingConstantOne = 1634760805
                    local workingConstantTwo = 857760878
                    local workingConstantThree = 2036477234
                    local workingConstantFour = 1797285236
                    local workingKeyOne = keyWordOne
                    local workingKeyTwo = keyWordTwo
                    local workingKeyThree = keyWordThree
                    local workingKeyFour = keyWordFour
                    local workingKeyFive = keyWordFive
                    local workingKeySix = keyWordSix
                    local workingKeySeven = keyWordSeven
                    local workingKeyEight = keyWordEight
                    local workingCounter = blockCounter
                    local workingNonceOne = nonceWordOne
                    local workingNonceTwo = nonceWordTwo
                    local workingNonceThree = nonceWordThree
                    for doubleRoundIndex = 1, 10 do
                        local columnConstantOneMid = workingConstantOne + workingKeyOne & uint32Mask
                        local columnCounterMid = ((workingCounter ~ columnConstantOneMid) << 16 | (workingCounter ~ columnConstantOneMid) >> 16) & uint32Mask
                        local columnKeyFiveMid = workingKeyFive + columnCounterMid & uint32Mask
                        local columnKeyOneMid = ((workingKeyOne ~ columnKeyFiveMid) << 12 | (workingKeyOne ~ columnKeyFiveMid) >> 20) & uint32Mask
                        local columnConstantOne = columnConstantOneMid + columnKeyOneMid & uint32Mask
                        local columnCounter = ((columnCounterMid ~ columnConstantOne) << 8 | (columnCounterMid ~ columnConstantOne) >> 24) & uint32Mask
                        local columnKeyFive = columnKeyFiveMid + columnCounter & uint32Mask
                        local columnKeyOne = ((columnKeyOneMid ~ columnKeyFive) << 7 | (columnKeyOneMid ~ columnKeyFive) >> 25) & uint32Mask
                        local columnConstantTwoMid = workingConstantTwo + workingKeyTwo & uint32Mask
                        local columnNonceOneMid = ((workingNonceOne ~ columnConstantTwoMid) << 16 | (workingNonceOne ~ columnConstantTwoMid) >> 16) & uint32Mask
                        local columnKeySixMid = workingKeySix + columnNonceOneMid & uint32Mask
                        local columnKeyTwoMid = ((workingKeyTwo ~ columnKeySixMid) << 12 | (workingKeyTwo ~ columnKeySixMid) >> 20) & uint32Mask
                        local columnConstantTwo = columnConstantTwoMid + columnKeyTwoMid & uint32Mask
                        local columnNonceOne = ((columnNonceOneMid ~ columnConstantTwo) << 8 | (columnNonceOneMid ~ columnConstantTwo) >> 24) & uint32Mask
                        local columnKeySix = columnKeySixMid + columnNonceOne & uint32Mask
                        local columnKeyTwo = ((columnKeyTwoMid ~ columnKeySix) << 7 | (columnKeyTwoMid ~ columnKeySix) >> 25) & uint32Mask
                        local columnConstantThreeMid = workingConstantThree + workingKeyThree & uint32Mask
                        local columnNonceTwoMid = ((workingNonceTwo ~ columnConstantThreeMid) << 16 | (workingNonceTwo ~ columnConstantThreeMid) >> 16) & uint32Mask
                        local columnKeySevenMid = workingKeySeven + columnNonceTwoMid & uint32Mask
                        local columnKeyThreeMid = ((workingKeyThree ~ columnKeySevenMid) << 12 | (workingKeyThree ~ columnKeySevenMid) >> 20) & uint32Mask
                        local columnConstantThree = columnConstantThreeMid + columnKeyThreeMid & uint32Mask
                        local columnNonceTwo = ((columnNonceTwoMid ~ columnConstantThree) << 8 | (columnNonceTwoMid ~ columnConstantThree) >> 24) & uint32Mask
                        local columnKeySeven = columnKeySevenMid + columnNonceTwo & uint32Mask
                        local columnKeyThree = ((columnKeyThreeMid ~ columnKeySeven) << 7 | (columnKeyThreeMid ~ columnKeySeven) >> 25) & uint32Mask
                        local columnConstantFourMid = workingConstantFour + workingKeyFour & uint32Mask
                        local columnNonceThreeMid = ((workingNonceThree ~ columnConstantFourMid) << 16 | (workingNonceThree ~ columnConstantFourMid) >> 16) & uint32Mask
                        local columnKeyEightMid = workingKeyEight + columnNonceThreeMid & uint32Mask
                        local columnKeyFourMid = ((workingKeyFour ~ columnKeyEightMid) << 12 | (workingKeyFour ~ columnKeyEightMid) >> 20) & uint32Mask
                        local columnConstantFour = columnConstantFourMid + columnKeyFourMid & uint32Mask
                        local columnNonceThree = ((columnNonceThreeMid ~ columnConstantFour) << 8 | (columnNonceThreeMid ~ columnConstantFour) >> 24) & uint32Mask
                        local columnKeyEight = columnKeyEightMid + columnNonceThree & uint32Mask
                        local columnKeyFour = ((columnKeyFourMid ~ columnKeyEight) << 7 | (columnKeyFourMid ~ columnKeyEight) >> 25) & uint32Mask
                        local diagonalConstantOneMid = columnConstantOne + columnKeyTwo & uint32Mask
                        local diagonalNonceThreeMid = ((columnNonceThree ~ diagonalConstantOneMid) << 16 | (columnNonceThree ~ diagonalConstantOneMid) >> 16) & uint32Mask
                        local diagonalKeySevenMid = columnKeySeven + diagonalNonceThreeMid & uint32Mask
                        local diagonalKeyTwoMid = ((columnKeyTwo ~ diagonalKeySevenMid) << 12 | (columnKeyTwo ~ diagonalKeySevenMid) >> 20) & uint32Mask
                        workingConstantOne = diagonalConstantOneMid + diagonalKeyTwoMid & uint32Mask
                        workingNonceThree = ((diagonalNonceThreeMid ~ workingConstantOne) << 8 | (diagonalNonceThreeMid ~ workingConstantOne) >> 24) & uint32Mask
                        workingKeySeven = diagonalKeySevenMid + workingNonceThree & uint32Mask
                        workingKeyTwo = ((diagonalKeyTwoMid ~ workingKeySeven) << 7 | (diagonalKeyTwoMid ~ workingKeySeven) >> 25) & uint32Mask
                        local diagonalConstantTwoMid = columnConstantTwo + columnKeyThree & uint32Mask
                        local diagonalCounterMid = ((columnCounter ~ diagonalConstantTwoMid) << 16 | (columnCounter ~ diagonalConstantTwoMid) >> 16) & uint32Mask
                        local diagonalKeyEightMid = columnKeyEight + diagonalCounterMid & uint32Mask
                        local diagonalKeyThreeMid = ((columnKeyThree ~ diagonalKeyEightMid) << 12 | (columnKeyThree ~ diagonalKeyEightMid) >> 20) & uint32Mask
                        workingConstantTwo = diagonalConstantTwoMid + diagonalKeyThreeMid & uint32Mask
                        workingCounter = ((diagonalCounterMid ~ workingConstantTwo) << 8 | (diagonalCounterMid ~ workingConstantTwo) >> 24) & uint32Mask
                        workingKeyEight = diagonalKeyEightMid + workingCounter & uint32Mask
                        workingKeyThree = ((diagonalKeyThreeMid ~ workingKeyEight) << 7 | (diagonalKeyThreeMid ~ workingKeyEight) >> 25) & uint32Mask
                        local diagonalConstantThreeMid = columnConstantThree + columnKeyFour & uint32Mask
                        local diagonalNonceOneMid = ((columnNonceOne ~ diagonalConstantThreeMid) << 16 | (columnNonceOne ~ diagonalConstantThreeMid) >> 16) & uint32Mask
                        local diagonalKeyFiveMid = columnKeyFive + diagonalNonceOneMid & uint32Mask
                        local diagonalKeyFourMid = ((columnKeyFour ~ diagonalKeyFiveMid) << 12 | (columnKeyFour ~ diagonalKeyFiveMid) >> 20) & uint32Mask
                        workingConstantThree = diagonalConstantThreeMid + diagonalKeyFourMid & uint32Mask
                        workingNonceOne = ((diagonalNonceOneMid ~ workingConstantThree) << 8 | (diagonalNonceOneMid ~ workingConstantThree) >> 24) & uint32Mask
                        workingKeyFive = diagonalKeyFiveMid + workingNonceOne & uint32Mask
                        workingKeyFour = ((diagonalKeyFourMid ~ workingKeyFive) << 7 | (diagonalKeyFourMid ~ workingKeyFive) >> 25) & uint32Mask
                        local diagonalConstantFourMid = columnConstantFour + columnKeyOne & uint32Mask
                        local diagonalNonceTwoMid = ((columnNonceTwo ~ diagonalConstantFourMid) << 16 | (columnNonceTwo ~ diagonalConstantFourMid) >> 16) & uint32Mask
                        local diagonalKeySixMid = columnKeySix + diagonalNonceTwoMid & uint32Mask
                        local diagonalKeyOneMid = ((columnKeyOne ~ diagonalKeySixMid) << 12 | (columnKeyOne ~ diagonalKeySixMid) >> 20) & uint32Mask
                        workingConstantFour = diagonalConstantFourMid + diagonalKeyOneMid & uint32Mask
                        workingNonceTwo = ((diagonalNonceTwoMid ~ workingConstantFour) << 8 | (diagonalNonceTwoMid ~ workingConstantFour) >> 24) & uint32Mask
                        workingKeySix = diagonalKeySixMid + workingNonceTwo & uint32Mask
                        workingKeyOne = ((diagonalKeyOneMid ~ workingKeySix) << 7 | (diagonalKeyOneMid ~ workingKeySix) >> 25) & uint32Mask
                    end
                    local keystreamWordOne = workingConstantOne + 1634760805 & uint32Mask
                    local keystreamWordTwo = workingConstantTwo + 857760878 & uint32Mask
                    local keystreamWordThree = workingConstantThree + 2036477234 & uint32Mask
                    local keystreamWordFour = workingConstantFour + 1797285236 & uint32Mask
                    local keystreamWordFive = workingKeyOne + keyWordOne & uint32Mask
                    local keystreamWordSix = workingKeyTwo + keyWordTwo & uint32Mask
                    local keystreamWordSeven = workingKeyThree + keyWordThree & uint32Mask
                    local keystreamWordEight = workingKeyFour + keyWordFour & uint32Mask
                    local keystreamWordNine = workingKeyFive + keyWordFive & uint32Mask
                    local keystreamWordTen = workingKeySix + keyWordSix & uint32Mask
                    local keystreamWordEleven = workingKeySeven + keyWordSeven & uint32Mask
                    local keystreamWordTwelve = workingKeyEight + keyWordEight & uint32Mask
                    local keystreamWordThirteen = workingCounter + blockCounter & uint32Mask
                    local keystreamWordFourteen = workingNonceOne + nonceWordOne & uint32Mask
                    local keystreamWordFifteen = workingNonceTwo + nonceWordTwo & uint32Mask
                    local keystreamWordSixteen = workingNonceThree + nonceWordThree & uint32Mask
                    if messageLength >= blockOffset + 63 then
                        local messageWordOne, messageWordTwo, messageWordThree, messageWordFour, messageWordFive, messageWordSix, messageWordSeven, messageWordEight, messageWordNine, messageWordTen, messageWordEleven, messageWordTwelve, messageWordThirteen, messageWordFourteen, messageWordFifteen, messageWordSixteen = string.unpack(blockWordsFormat, messageBytes, blockOffset)
                        outputBlocks[#outputBlocks + 1] = string.pack(blockWordsFormat, messageWordOne ~ keystreamWordOne, messageWordTwo ~ keystreamWordTwo, messageWordThree ~ keystreamWordThree, messageWordFour ~ keystreamWordFour, messageWordFive ~ keystreamWordFive, messageWordSix ~ keystreamWordSix, messageWordSeven ~ keystreamWordSeven, messageWordEight ~ keystreamWordEight, messageWordNine ~ keystreamWordNine, messageWordTen ~ keystreamWordTen, messageWordEleven ~ keystreamWordEleven, messageWordTwelve ~ keystreamWordTwelve, messageWordThirteen ~ keystreamWordThirteen, messageWordFourteen ~ keystreamWordFourteen, messageWordFifteen ~ keystreamWordFifteen, messageWordSixteen ~ keystreamWordSixteen)
                    else
                        local keystreamBlock = string.pack(blockWordsFormat, keystreamWordOne, keystreamWordTwo, keystreamWordThree, keystreamWordFour, keystreamWordFive, keystreamWordSix, keystreamWordSeven, keystreamWordEight, keystreamWordNine, keystreamWordTen, keystreamWordEleven, keystreamWordTwelve, keystreamWordThirteen, keystreamWordFourteen, keystreamWordFifteen, keystreamWordSixteen)
                        local tailOutputChars = {}
                        for tailByteOffset = 0, messageLength - blockOffset do
                            tailOutputChars[tailByteOffset + 1] = string.char(messageBytes:byte(blockOffset + tailByteOffset) ~ keystreamBlock:byte(tailByteOffset + 1))
                        end
                        outputBlocks[#outputBlocks + 1] = table.concat(tailOutputChars)
                    end
                    blockCounter = blockCounter + 1
                    if blockCounter % 8 == 0 then
                        accumulateWorkAndYield(512)
                    end
                end
                return table.concat(outputBlocks)
            end

            local function hkdfExpandKey(pseudoRandomKey, infoLabel)
                local expandedKey = computeHmacSha256(pseudoRandomKey, infoLabel .. "\x01")
                return #expandedKey == 32 and expandedKey or nil
            end

            local function buildPipeBindingString(sessionId, luaNonceHex, challengeBytes, loadGeneration, sessionGeneration)
                return "ks-pipe-v3|proto=3|enc=1|session=" .. sessionId .. "|lua_nonce=" .. luaNonceHex .. "|challenge=" .. bytesToHex(challengeBytes) .. "|load_generation=" .. tostring(loadGeneration) .. "|session_generation=" .. tostring(sessionGeneration) .. "|activation=" .. KS_ACTIVATION_ID .. "|build=" .. KS_BUILD_ID .. "|watermark=" .. KS_WATERMARK_ID
            end

            function deriveSessionKeys(secretKey, sessionId, luaNonceHex, challengeBytes, loadGeneration, sessionGeneration)
                if type(secretKey) ~= "string" or #secretKey ~= 32 or type(luaNonceHex) ~= "string" or not luaNonceHex:match("^[0-9a-f]+$") or #luaNonceHex ~= 32 or type(challengeBytes) ~= "string" or #challengeBytes ~= 32 then
                    return nil
                end
                local bindingString = buildPipeBindingString(sessionId, luaNonceHex, challengeBytes, loadGeneration, sessionGeneration)
                local pipeRootKey = computeHmacSha256("ks-pipe-v3-salt|" .. bindingString, secretKey)
                if #pipeRootKey ~= 32 then
                    return nil
                end
                local pipeContext = {
                    binding_hex = sha256Hex(bindingString),
                    session_id = sessionId,
                    activation_id = KS_ACTIVATION_ID,
                    load_generation = loadGeneration,
                    session_generation = sessionGeneration,
                    loader_to_lua = {
                        enc = hkdfExpandKey(pipeRootKey, "ks-pipe-v3-l2lua-enc"),
                        mac = hkdfExpandKey(pipeRootKey, "ks-pipe-v3-l2lua-mac"),
                    },
                    lua_to_loader = {
                        enc = hkdfExpandKey(pipeRootKey, "ks-pipe-v3-lua2l-enc"),
                        mac = hkdfExpandKey(pipeRootKey, "ks-pipe-v3-lua2l-mac"),
                    },
                }
                if not pipeContext.loader_to_lua.enc or not pipeContext.loader_to_lua.mac or not pipeContext.lua_to_loader.enc or not pipeContext.lua_to_loader.mac then
                    return nil
                end
                return pipeContext
            end

            function deriveFrameNonce(directionKeys, directionLabel, messageType, sequenceNumber)
                local nonceMac = computeHmacSha256(directionKeys.mac, "ks-pipe-v3-nonce|" .. directionLabel .. "|" .. tostring(messageType) .. "|" .. tostring(sequenceNumber))
                if #nonceMac ~= 32 then
                    return nil
                end
                return nonceMac:sub(1, 12)
            end

            function buildFrameMacMessage(pipeContext, directionLabel, messageType, sequenceNumber, nonceBase64, ciphertextBase64, ciphertextLength)
                return "KSP3E|3|1|" .. directionLabel .. "|" .. pipeContext.binding_hex .. "|session=" .. pipeContext.session_id .. "|load_generation=" .. tostring(pipeContext.load_generation) .. "|session_generation=" .. tostring(pipeContext.session_generation) .. "|activation=" .. pipeContext.activation_id .. "|" .. tostring(messageType) .. "|" .. tostring(sequenceNumber) .. "|" .. nonceBase64 .. "|" .. tostring(ciphertextLength) .. "|" .. ciphertextBase64
            end

            runtimeClock = { reader = nil, source_origin = 0, epoch_origin = 0, last = 0 }

            function runtimeClock.epoch_ms()
                local epochTimeOk, epochSeconds = pcall(os.time)
                if not epochTimeOk or type(epochSeconds) ~= "number" or epochSeconds ~= epochSeconds or epochSeconds < 0 then
                    return nil
                end
                return math.floor(epochSeconds * 1000)
            end

            if hasFunctionMember(ImGui, "GetTime") then
                local imGuiProbeOk, imGuiProbeSeconds = pcall(ImGui.GetTime)
                if imGuiProbeOk and type(imGuiProbeSeconds) == "number" and imGuiProbeSeconds == imGuiProbeSeconds and imGuiProbeSeconds >= 0 then
                    function runtimeClock.reader()
                        local imGuiTimeOk, imGuiTimeSeconds = pcall(ImGui.GetTime)
                        if imGuiTimeOk and type(imGuiTimeSeconds) == "number" and imGuiTimeSeconds == imGuiTimeSeconds and imGuiTimeSeconds >= 0 then
                            return math.floor(imGuiTimeSeconds * 1000)
                        end
                        return nil
                    end
                end
            end
            if not runtimeClock.reader then
                function runtimeClock.reader()
                    local clockOk, clockSeconds = pcall(os.clock)
                    if clockOk and type(clockSeconds) == "number" and clockSeconds == clockSeconds and clockSeconds >= 0 then
                        return math.floor(clockSeconds * 1000)
                    end
                    return nil
                end
            end
            local readerOriginMs = runtimeClock.reader() or 0
            runtimeClock.source_origin = readerOriginMs
            local epochOriginMs = runtimeClock.epoch_ms() or 0
            runtimeClock.epoch_origin = epochOriginMs

            function runtimeClock.monotonic_ms()
                local readerNowMs = runtimeClock.reader()
                local readerElapsedMs = type(readerNowMs) == "number" and readerNowMs >= runtimeClock.source_origin and readerNowMs - runtimeClock.source_origin or 0
                local epochNowMs = runtimeClock.epoch_ms()
                local epochElapsedMs = type(epochNowMs) == "number" and epochNowMs >= runtimeClock.epoch_origin and epochNowMs - runtimeClock.epoch_origin or 0
                local monotonicNowMs = math.floor(math.max(runtimeClock.last, readerElapsedMs, epochElapsedMs))
                runtimeClock.last = monotonicNowMs
                return monotonicNowMs
            end
        end
        local tryYieldScript, makeJsonObject, encodeJson, decodeJson, sessionIdHex, pipeSharedSecret, loaderReadPipe, loaderWritePipe
        do
            function tryYieldScript(yieldMs)
                if hasFunctionMember(Script, "Yield") then
                    yieldScriptClamped(yieldMs)
                    return true
                end
                return false
            end

            local function openFileWithRetry(filePath, openMode, deadlineMs)
                local currentMonotonicMs
                repeat
                    local openOk, openedFile = pcall(io.open, filePath, openMode)
                    if openOk and openedFile then
                        return openedFile
                    end
                    if type(ShouldUnload) == "function" and ShouldUnload() then
                        return nil
                    end
                    if not tryYieldScript(250) then
                        return nil
                    end
                    currentMonotonicMs = runtimeClock.monotonic_ms()
                until deadlineMs <= currentMonotonicMs
                return nil
            end

            if not (function()
                return hasFunctionMember(Script, "RegisterLooped") and hasFunctionMember(Script, "QueueJob") and hasFunctionMember(EventMgr, "RegisterHandler") and isIndexableValue(Cherax) and isIndexableValue(GTA)
            end)() then
                return shutdownBridge(nil, nil)
            end

            local function quoteJsonString(textToQuote)
                return '"' .. tostring(textToQuote):gsub('[%z\x01-\x1f\\"]', function(charToEscape)
                    return ({
                        ['"'] = '\\"',
                        ["\\"] = "\\\\",
                        ["\x08"] = "\\b",
                        ["\x0c"] = "\\f",
                        ["\n"] = "\\n",
                        ["\r"] = "\\r",
                        ["\t"] = "\\t",
                    })[charToEscape] or string.format("\\u%04x", charToEscape:byte())
                end) .. '"'
            end

            local forcedJsonObjects = setmetatable({}, { __mode = "k" })

            function makeJsonObject(sourceFields)
                local jsonObject = {}
                if type(sourceFields) == "table" then
                    for fieldKey, fieldValue in pairs(sourceFields) do
                        jsonObject[fieldKey] = fieldValue
                    end
                end
                forcedJsonObjects[jsonObject] = true
                return jsonObject
            end

            function encodeJson(valueToEncode, nestingDepth)
                nestingDepth = (nestingDepth or 0) + 1
                if nestingDepth > 8 then
                    error("json depth", 0)
                end
                local valueType = type(valueToEncode)
                if valueType == "nil" then
                    return "null"
                end
                if valueType == "boolean" then
                    return valueToEncode and "true" or "false"
                end
                if valueType == "number" then
                    if valueToEncode ~= valueToEncode or valueToEncode == math.huge or valueToEncode == -math.huge then
                        error("json number", 0)
                    end
                    return tostring(valueToEncode)
                end
                if valueType == "string" then
                    return quoteJsonString(valueToEncode)
                end
                if valueType ~= "table" then
                    error("json type", 0)
                end
                local isArrayLike = not forcedJsonObjects[valueToEncode]
                local maxArrayIndex = 0
                local fieldCount = 0
                for fieldKey in pairs(valueToEncode) do
                    if type(accumulateWorkAndYield) == "function" then
                        accumulateWorkAndYield(8)
                    end
                    fieldCount = fieldCount + 1
                    if fieldCount > 64 then
                        error("json fields", 0)
                    end
                    if type(fieldKey) == "number" and not (fieldKey < 1) and fieldKey % 1 == 0 then
                        maxArrayIndex = math.max(maxArrayIndex, fieldKey)
                    else
                        isArrayLike = false
                    end
                end
                local encodedParts = {}
                if isArrayLike then
                    for arrayIndex = 1, maxArrayIndex do
                        encodedParts[#encodedParts + 1] = encodeJson(valueToEncode[arrayIndex], nestingDepth)
                    end
                    return "[" .. table.concat(encodedParts, ",") .. "]"
                end
                for fieldName, fieldValue in pairs(valueToEncode) do
                    if type(accumulateWorkAndYield) == "function" then
                        accumulateWorkAndYield(8)
                    end
                    if type(fieldName) ~= "string" or #fieldName > 64 then
                        error("json key", 0)
                    end
                    encodedParts[#encodedParts + 1] = quoteJsonString(fieldName) .. ":" .. encodeJson(fieldValue, nestingDepth)
                end
                return "{" .. table.concat(encodedParts, ",") .. "}"
            end

            function decodeJson(jsonText)
                if type(jsonText) ~= "string" or #jsonText > MAX_FRAME_BYTES then
                    return nil
                end
                local parsePosition = 1
                local parsedValueCount = 0

                local function skipWhitespace()
                    local whitespaceStart, whitespaceEnd = jsonText:find("^[ \n\r\t]*", parsePosition)
                    parsePosition = (whitespaceEnd or parsePosition - 1) + 1
                end

                local function parseJsonValue(nestingDepth)
                    nestingDepth = nestingDepth + 1
                    parsedValueCount = parsedValueCount + 1
                    if nestingDepth > 12 or parsedValueCount > 16384 then
                        error("json bounds", 0)
                    end
                    if parsedValueCount % 64 == 0 then
                        accumulateWorkAndYield(64)
                    end
                    skipWhitespace()
                    local leadingChar = jsonText:sub(parsePosition, parsePosition)
                    if leadingChar == "{" then
                        parsePosition = parsePosition + 1
                        local parsedObject = {}
                        skipWhitespace()
                        if jsonText:sub(parsePosition, parsePosition) == "}" then
                            parsePosition = parsePosition + 1
                            return parsedObject
                        end
                        while true do
                            local objectKey = parseJsonValue(nestingDepth)
                            if type(objectKey) ~= "string" or #objectKey > 64 then
                                error("json key", 0)
                            end
                            skipWhitespace()
                            if jsonText:sub(parsePosition, parsePosition) ~= ":" then
                                error("json colon", 0)
                            end
                            parsePosition = parsePosition + 1
                            parsedObject[objectKey] = parseJsonValue(nestingDepth)
                            skipWhitespace()
                            local objectSeparator = jsonText:sub(parsePosition, parsePosition)
                            if objectSeparator == "}" then
                                parsePosition = parsePosition + 1
                                break
                            end
                            if objectSeparator ~= "," then
                                error("json separator", 0)
                            end
                            parsePosition = parsePosition + 1
                        end
                        return parsedObject
                    end
                    if leadingChar == "[" then
                        parsePosition = parsePosition + 1
                        local parsedArray = {}
                        skipWhitespace()
                        if jsonText:sub(parsePosition, parsePosition) == "]" then
                            parsePosition = parsePosition + 1
                            return parsedArray
                        end
                        while true do
                            parsedArray[#parsedArray + 1] = parseJsonValue(nestingDepth)
                            if #parsedArray > 4096 then
                                error("json array", 0)
                            end
                            skipWhitespace()
                            local arraySeparator = jsonText:sub(parsePosition, parsePosition)
                            if arraySeparator == "]" then
                                parsePosition = parsePosition + 1
                                break
                            end
                            if arraySeparator ~= "," then
                                error("json separator", 0)
                            end
                            parsePosition = parsePosition + 1
                        end
                        return parsedArray
                    end
                    if leadingChar == '"' then
                        parsePosition = parsePosition + 1
                        local stringParts = {}
                        local decodedLength = 0
                        while true do
                            local scanWindowEnd = math.min(#jsonText, parsePosition + 8191)
                            local scanWindow = jsonText:sub(parsePosition, scanWindowEnd)
                            local specialCharOffset = scanWindow:find('[\\"%z\x01-\x1f]')
                            if not specialCharOffset then
                                if #scanWindow == 0 then
                                    error("json string", 0)
                                end
                                stringParts[#stringParts + 1] = scanWindow
                                decodedLength = decodedLength + #scanWindow
                                parsePosition = scanWindowEnd + 1
                                if decodedLength > MAX_FRAME_BYTES then
                                    error("json string", 0)
                                end
                                accumulateWorkAndYield(512)
                                if parsePosition > #jsonText then
                                    error("json string", 0)
                                end
                            else
                                local specialCharPos = parsePosition + specialCharOffset - 1
                                if specialCharPos > parsePosition then
                                    local literalRun = jsonText:sub(parsePosition, specialCharPos - 1)
                                    stringParts[#stringParts + 1] = literalRun
                                    decodedLength = decodedLength + #literalRun
                                    parsePosition = specialCharPos
                                end
                                local specialChar = jsonText:sub(parsePosition, parsePosition)
                                if specialChar == "" then
                                    error("json string", 0)
                                end
                                if specialChar == '"' then
                                    parsePosition = parsePosition + 1
                                    break
                                end
                                if specialChar == "\\" then
                                    local escapeLetter = jsonText:sub(parsePosition + 1, parsePosition + 1)
                                    local escapeReplacements = { b = "\x08", f = "\x0c", n = "\n", r = "\r", t = "\t", ['"'] = '"', ["\\"] = "\\", ["/"] = "/" }
                                    if escapeLetter == "u" then
                                        local unicodeHex = jsonText:sub(parsePosition + 2, parsePosition + 5)
                                        local codePoint = tonumber(unicodeHex, 16)
                                        if not codePoint or not utf8 or type(utf8.char) ~= "function" then
                                            error("json unicode", 0)
                                        end
                                        local unicodeChar = utf8.char(codePoint)
                                        stringParts[#stringParts + 1] = unicodeChar
                                        decodedLength = decodedLength + #unicodeChar
                                        parsePosition = parsePosition + 6
                                    else
                                        if escapeReplacements[escapeLetter] == nil then
                                            error("json escape", 0)
                                        end
                                        stringParts[#stringParts + 1] = escapeReplacements[escapeLetter]
                                        decodedLength = decodedLength + #escapeReplacements[escapeLetter]
                                        parsePosition = parsePosition + 2
                                    end
                                else
                                    if specialChar:byte() < 32 then
                                        error("json control", 0)
                                    end
                                    error("json control", 0)
                                end
                                if decodedLength > MAX_FRAME_BYTES then
                                    error("json string", 0)
                                end
                            end
                        end
                        return table.concat(stringParts)
                    end
                    if jsonText:sub(parsePosition, parsePosition + 3) == "true" then
                        parsePosition = parsePosition + 4
                        return true
                    end
                    if jsonText:sub(parsePosition, parsePosition + 4) == "false" then
                        parsePosition = parsePosition + 5
                        return false
                    end
                    if jsonText:sub(parsePosition, parsePosition + 3) == "null" then
                        parsePosition = parsePosition + 4
                        return nil
                    end
                    local numberLiteral = jsonText:match("^%-?%d+%.?%d*[eE]?[%+%-]?%d*", parsePosition)
                    if not numberLiteral or numberLiteral == "" then
                        error("json value", 0)
                    end
                    parsePosition = parsePosition + #numberLiteral
                    return tonumber(numberLiteral)
                end

                local parseOk, parsedRoot = pcall(parseJsonValue, 0)
                if not parseOk then
                    return nil
                end
                skipWhitespace()
                if parsePosition <= #jsonText then
                    return nil
                end
                return parsedRoot
            end

            local localAppDataDir = os.getenv("LOCALAPPDATA")
            if type(localAppDataDir) ~= "string" or #localAppDataDir == 0 then
                return shutdownBridge(nil, nil)
            end
            openDeadlineMs = runtimeClock.monotonic_ms() + 40000
            local runtimeFile = openFileWithRetry(localAppDataDir .. "\\K-Script Loader\\runtime.dat", "rb", openDeadlineMs)
            if not runtimeFile then
                return shutdownBridge(nil, nil)
            end
            local runtimeLines = {}
            for lineIndex = 1, 7 do
                runtimeLines[lineIndex] = runtimeFile:read("*l")
            end
            runtimeFile:close()
            if not runtimeLines[7] or #runtimeLines[7] > 128 then
                return shutdownBridge(nil, nil)
            end
            local recordVersion, pipePath, sharedSecretHex, runtimeExpiryText, authTokenPath, runtimeRecordMac
            recordVersion, pipePath, sharedSecretHex, runtimeExpiryText, sessionIdHex, authTokenPath, runtimeRecordMac = table.unpack(runtimeLines)
            pipeSharedSecret = hexToBytes(sharedSecretHex)
            local runtimeExpiryMs = tonumber(runtimeExpiryText)
            local pipePathPrefix = "\\\\.\\pipe\\"
            local recordCheckEpochMs = runtimeClock.epoch_ms()
            if recordVersion ~= "3" or not pipeSharedSecret or #pipeSharedSecret ~= 32 or not runtimeExpiryMs or not recordCheckEpochMs or runtimeExpiryMs < recordCheckEpochMs or type(pipePath) ~= "string" or pipePath:sub(1, #pipePathPrefix) ~= pipePathPrefix or not pipePath:sub(#pipePathPrefix + 1):match("^[0-9a-f]+$") or #pipePath ~= #pipePathPrefix + 48 or type(sessionIdHex) ~= "string" or not sessionIdHex:match("^[0-9a-f]+$") or #sessionIdHex ~= 32 or type(authTokenPath) ~= "string" or #authTokenPath > 1024 or type(runtimeRecordMac) ~= "string" then
                pipeSharedSecret = nil
                return shutdownBridge(nil, nil)
            end
            if not constantTimeEqual(runtimeRecordMac, hmacSha256Hex(pipeSharedSecret, "3|" .. sessionIdHex .. "|" .. runtimeExpiryText .. "|" .. pipePath .. "|" .. authTokenPath)) then
                pipeSharedSecret = nil
                return shutdownBridge(nil, nil)
            end
            local authTokenFile = openFileWithRetry(authTokenPath, "rb", openDeadlineMs)
            if not authTokenFile then
                pipeSharedSecret = nil
                return shutdownBridge(nil, nil)
            end
            local authTokenLine = authTokenFile:read("*l")
            authTokenFile:close()
            if type(authTokenLine) ~= "string" or #authTokenLine < 5 or #authTokenLine > 192 then
                pipeSharedSecret = nil
                return shutdownBridge(nil, nil)
            end
            local tokenExpiryText, tokenCounterText, tokenMac = authTokenLine:gsub("\r$", ""):match("^(%d+):(%d+):([0-9a-f]+)$")
            local tokenExpiryMs = tonumber(tokenExpiryText)
            local tokenCounter = tonumber(tokenCounterText)
            local tokenCheckEpochMs = runtimeClock.epoch_ms()
            if not tokenExpiryMs or not tokenCheckEpochMs or tokenExpiryMs < tokenCheckEpochMs or tokenCounter ~= 0 or not tokenMac or #tokenMac ~= 64 or not constantTimeEqual(tokenMac, hmacSha256Hex(pipeSharedSecret, tokenExpiryText .. "|" .. tokenCounterText)) then
                pipeSharedSecret = nil
                return shutdownBridge(nil, nil)
            end
            local pipeOpenEpochMs = runtimeClock.epoch_ms()
            if not pipeOpenEpochMs then
                pipeSharedSecret = nil
                return shutdownBridge(nil, nil)
            end
            openDeadlineMs = runtimeClock.monotonic_ms() + math.max(0, math.min(40000, runtimeExpiryMs - pipeOpenEpochMs))
            loaderReadPipe = openFileWithRetry(pipePath, "r+b", openDeadlineMs)
            if not loaderReadPipe then
                pipeSharedSecret = nil
                return shutdownBridge(nil, nil)
            end
            trackedReadPipe = loaderReadPipe
            loaderWritePipe = openFileWithRetry(pipePath, "r+b", openDeadlineMs)
            if not loaderWritePipe then
                pipeSharedSecret = nil
                return shutdownBridge(loaderReadPipe, nil)
            end
            trackedWritePipe = loaderWritePipe
            loaderReadPipe:setvbuf("no")
            loaderWritePipe:setvbuf("no")
        end
        local secureChannel, seenNonceSet, nonceHistoryRing, nonceRingSlot, isUnloaded, shutdownReason, sendEncryptedFrameWithDeadline, sendEncryptedFrame, receiveEncryptedFrame, decodeJsonWithDeadline, luaNonceHex, loaderHelloPayload
        do
            secureChannel = nil
            seenNonceSet = {}
            nonceHistoryRing = {}
            nonceRingSlot = 1

            local function acceptFreshNonce(nonceHex)
                if seenNonceSet[nonceHex] then
                    return false
                end
                local evictedNonce = nonceHistoryRing[nonceRingSlot]
                if evictedNonce then
                    seenNonceSet[evictedNonce] = nil
                end
                seenNonceSet[nonceHex] = true
                nonceHistoryRing[nonceRingSlot] = nonceHex
                nonceRingSlot = nonceRingSlot % 256 + 1
                return true
            end

            isUnloaded = false
            shutdownReason = nil

            local function computeFrameTimeoutMs(payloadLength)
                local nonNegativeLength = math.max(0, tonumber(payloadLength) or 0)
                return math.max(5000, math.min(60000, 5000 + math.floor(nonNegativeLength / 1024) * 100))
            end

            local function runWithDeadline(operation, timeoutMs)
                if isUnloaded or type(operation) ~= "function" then
                    return nil
                end
                local startedAtMs = runtimeClock.monotonic_ms()
                local firstResult, secondResult, thirdResult = operation()
                if isUnloaded then
                    return nil
                end
                if math.max(500, math.min(60000, tonumber(timeoutMs) or 5000)) < runtimeClock.monotonic_ms() - startedAtMs then
                    return nil
                end
                return firstResult, secondResult, thirdResult
            end

            local function buildPlainFrameLine(opcode, sequenceNumber, framePayload)
                local encodedPayload = encodeBase64(framePayload)
                return "KSP3:" .. opcode .. ":" .. sequenceNumber .. ":" .. encodedPayload .. ":" .. hmacSha256Hex(pipeSharedSecret, "KSP3|" .. opcode .. "|" .. sequenceNumber .. "|" .. encodedPayload) .. "\n"
            end

            local function writePlainFrame(opcode, sequenceNumber, framePayload)
                local frameLine = buildPlainFrameLine(opcode, sequenceNumber, framePayload)
                local writeStatus = loaderWritePipe:write(frameLine)
                local flushStatus = writeStatus ~= nil and loaderWritePipe:flush() or nil
                return writeStatus ~= nil and flushStatus ~= nil
            end

            local function readPlainFrame(frameByteLimit)
                local frameLine = loaderReadPipe:read("*l")
                if type(frameLine) ~= "string" or frameByteLimit < #frameLine then
                    return nil
                end
                local protocolTag, opcodeText, sequenceText, payloadBase64, macHex = frameLine:match("^([^:]+):([^:]+):([^:]+):([^:]*):([^:]+)$")
                if not opcodeText or not opcodeText:match("^%d+$") or not sequenceText:match("^%d+$") then
                    return nil
                end
                local opcode = tonumber(opcodeText)
                local sequenceNumber = tonumber(sequenceText)
                if protocolTag ~= "KSP3" or not opcode or opcode < 1 or opcode > 13 or not sequenceNumber or sequenceNumber < 1 or opcode % 1 ~= 0 or sequenceNumber % 1 ~= 0 or type(macHex) ~= "string" or #macHex ~= 64 then
                    return nil
                end
                if not constantTimeEqual(macHex, hmacSha256Hex(pipeSharedSecret, "KSP3|" .. opcodeText .. "|" .. sequenceText .. "|" .. payloadBase64)) then
                    return nil
                end
                local decodedPayload = decodeBase64(payloadBase64, frameByteLimit)
                if decodedPayload == nil then
                    return nil
                end
                return opcode, sequenceNumber, decodedPayload
            end

            local function buildEncryptedFrameLine(opcode, sequenceNumber, plainPayload)
                local activeChannel = secureChannel
                if not activeChannel then
                    return nil
                end
                local outboundKeys = activeChannel.lua_to_loader
                local directionLabel = "lua2loader"
                local frameNonce = deriveFrameNonce(outboundKeys, directionLabel, opcode, sequenceNumber)
                if not frameNonce then
                    return nil
                end
                local ciphertext = applyChacha20Keystream(outboundKeys.enc, frameNonce, plainPayload)
                if not ciphertext then
                    return nil
                end
                local nonceBase64 = encodeBase64(frameNonce)
                local ciphertextBase64 = encodeBase64(ciphertext)
                local macInput = buildFrameMacMessage(activeChannel, directionLabel, opcode, sequenceNumber, nonceBase64, ciphertextBase64, #ciphertext)
                local macHex = hmacSha256Hex(outboundKeys.mac, macInput)
                if isUnloaded or secureChannel ~= activeChannel then
                    return nil
                end
                return "KSP3E:1:" .. opcode .. ":" .. sequenceNumber .. ":" .. nonceBase64 .. ":" .. ciphertextBase64 .. ":" .. macHex .. "\n"
            end

            function sendEncryptedFrameWithDeadline(opcode, sequenceNumber, plainPayload)
                local frameLine = runWithDeadline(function()
                    return buildEncryptedFrameLine(opcode, sequenceNumber, plainPayload)
                end, computeFrameTimeoutMs(#plainPayload))
                if not frameLine then
                    return false
                end
                local writeStatus = loaderWritePipe:write(frameLine)
                local flushStatus = writeStatus ~= nil and loaderWritePipe:flush() or nil
                return writeStatus ~= nil and flushStatus ~= nil
            end

            function sendEncryptedFrame(opcode, sequenceNumber, plainPayload)
                local frameLine = buildEncryptedFrameLine(opcode, sequenceNumber, plainPayload)
                if not frameLine then
                    return false
                end
                local writeStatus = loaderWritePipe:write(frameLine)
                local flushStatus = writeStatus ~= nil and loaderWritePipe:flush() or nil
                return writeStatus ~= nil and flushStatus ~= nil
            end

            local function verifyAndDecryptFrameLine(frameLine, frameByteLimit)
                local activeChannel = secureChannel
                local activeSeenNonceSet = seenNonceSet
                local activeNonceHistoryRing = nonceHistoryRing
                if not activeChannel then
                    return nil
                end
                if frameLine:sub(1, 5) == "KSP3:" then
                    return nil
                end
                local frameVersion, opcodeText, sequenceText, nonceBase64, ciphertextBase64, receivedMacHex = frameLine:match("^KSP3E:([^:]+):([^:]+):([^:]+):([^:]*):([^:]*):([^:]+)$")
                if frameVersion ~= "1" or not opcodeText or not opcodeText:match("^%d+$") or not sequenceText or not sequenceText:match("^%d+$") or type(receivedMacHex) ~= "string" or #receivedMacHex ~= 64 then
                    return nil
                end
                local opcode = tonumber(opcodeText)
                local sequenceNumber = tonumber(sequenceText)
                if not opcode or opcode < 1 or opcode > 13 or opcode % 1 ~= 0 or not sequenceNumber or sequenceNumber < 1 or sequenceNumber % 1 ~= 0 then
                    return nil
                end
                local frameNonce = decodeBase64(nonceBase64, 12)
                if type(frameNonce) ~= "string" or #frameNonce ~= 12 then
                    return nil
                end
                local ciphertext = decodeBase64(ciphertextBase64, frameByteLimit)
                if type(ciphertext) ~= "string" or frameByteLimit < #ciphertext then
                    return nil
                end
                local inboundKeys = activeChannel.loader_to_lua
                local directionLabel = "loader2lua"
                local macInput = buildFrameMacMessage(activeChannel, directionLabel, opcode, sequenceNumber, nonceBase64, ciphertextBase64, #ciphertext)
                local expectedMacHex = hmacSha256Hex(inboundKeys.mac, macInput)
                if not constantTimeEqual(receivedMacHex, expectedMacHex) then
                    return nil
                end
                if isUnloaded or secureChannel ~= activeChannel or seenNonceSet ~= activeSeenNonceSet or nonceHistoryRing ~= activeNonceHistoryRing then
                    return nil
                end
                local expectedNonce = deriveFrameNonce(inboundKeys, directionLabel, opcode, sequenceNumber)
                if not expectedNonce or not constantTimeBytesEqual(frameNonce, expectedNonce) then
                    return nil
                end
                local nonceHex = bytesToHex(frameNonce)
                if not acceptFreshNonce(nonceHex) then
                    return nil
                end
                local plainPayload = applyChacha20Keystream(inboundKeys.enc, frameNonce, ciphertext)
                if isUnloaded or secureChannel ~= activeChannel or seenNonceSet ~= activeSeenNonceSet or nonceHistoryRing ~= activeNonceHistoryRing then
                    return nil
                end
                if type(plainPayload) ~= "string" or frameByteLimit < #plainPayload then
                    return nil
                end
                return opcode, sequenceNumber, plainPayload
            end

            function receiveEncryptedFrame(frameByteLimit)
                if not secureChannel then
                    return nil
                end
                local frameLine = loaderReadPipe:read("*l")
                if type(frameLine) ~= "string" or frameByteLimit < #frameLine then
                    return nil
                end
                return runWithDeadline(function()
                    return verifyAndDecryptFrameLine(frameLine, frameByteLimit)
                end, computeFrameTimeoutMs(#frameLine))
            end

            function decodeJsonWithDeadline(jsonText)
                return runWithDeadline(function()
                    return decodeJson(jsonText)
                end, computeFrameTimeoutMs(#jsonText))
            end

            if not hasFunctionMember(Cherax, "GetUID") then
                pipeSharedSecret = nil
                return shutdownBridge(loaderReadPipe, loaderWritePipe)
            end
            local cheraxUid = tostring(Cherax.GetUID() or "")
            if not cheraxUid:match("^[1-9]%d*$") or #cheraxUid > 20 then
                pipeSharedSecret = nil
                return shutdownBridge(loaderReadPipe, loaderWritePipe)
            end
            local registrationMacHex = hmacSha256Hex(registrationHmacKeyHex, table.concat({
                "ks-registration-cherax-v1",
                registrationSecretHex,
                KS_ACTIVATION_ID,
                KS_BUILD_ID,
                KS_WATERMARK_ID,
                cheraxUid,
            }, "|"))
            registrationHmacKeyHex = nil
            registrationSecretHex = nil
            luaNonceHex = sha256Hex(pipeSharedSecret .. "|" .. sessionIdHex .. "|" .. tostring(runtimeClock.epoch_ms() or runtimeClock.monotonic_ms()) .. "|" .. KS_ACTIVATION_ID):sub(1, 32)
            local luaHelloPayload = table.concat({
                sessionIdHex,
                KS_ACTIVATION_ID,
                KS_BUILD_ID,
                KS_WATERMARK_ID,
                luaNonceHex,
                cheraxUid,
                registrationMacHex,
            }, "|")
            if not writePlainFrame(1, 1, luaHelloPayload) then
                pipeSharedSecret = nil
                return shutdownBridge(loaderReadPipe, loaderWritePipe)
            end
            local helloReplyOpcode, helloReplySequence
            helloReplyOpcode, helloReplySequence, loaderHelloPayload = readPlainFrame(8192)
            if helloReplyOpcode ~= 2 or helloReplySequence ~= 1 or type(loaderHelloPayload) ~= "string" then
                pipeSharedSecret = nil
                return shutdownBridge(loaderReadPipe, loaderWritePipe)
            end
        end
        local isRuntimeReady, pendingCancelRequestIds, pendingRequestsById, asyncCompletionQueue, isPumpLoopRegistered, isPumpRunning, nextPumpAtMs, isSecureLoaderQueued, isStartingSecureLoader, queueScriptJob, stopRuntime, secureLoaderEntry, hostGlobals, secureLoaderContext, lastResponseAtMs, runBridgeExchange
        do
            local helloHeaderFields = {}
            local helloFieldStart = 1
            for helloFieldIndex = 1, 4 do
                local helloNewlinePos = loaderHelloPayload:find("\n", helloFieldStart, true)
                if not helloNewlinePos then
                    pipeSharedSecret = nil
                    return shutdownBridge(loaderReadPipe, loaderWritePipe)
                end
                helloHeaderFields[helloFieldIndex] = loaderHelloPayload:sub(helloFieldStart, helloNewlinePos - 1)
                helloFieldStart = helloNewlinePos + 1
            end
            local challengeBytes = loaderHelloPayload:sub(helloFieldStart)
            local loadGeneration = tonumber(helloHeaderFields[2])
            local sessionGeneration = tonumber(helloHeaderFields[3])
            local helloOptionFlag, helloOptionValueText = tostring(helloHeaderFields[4] or ""):match("^([01]):(%d+)$")
            local helloOptionValue = tonumber(helloOptionValueText)
            if helloHeaderFields[1] ~= "3" or #challengeBytes ~= 32 or not loadGeneration or loadGeneration < 1 or loadGeneration % 1 ~= 0 or not sessionGeneration or sessionGeneration < 1 or sessionGeneration % 1 ~= 0 or not helloOptionFlag or not helloOptionValue or helloOptionValue < 0 or helloOptionValue > 8191 or helloOptionValue % 1 ~= 0 then
                pipeSharedSecret = nil
                return shutdownBridge(loaderReadPipe, loaderWritePipe)
            end
            secureChannel = deriveSessionKeys(pipeSharedSecret, sessionIdHex, luaNonceHex, challengeBytes, loadGeneration, sessionGeneration)
            if not secureChannel then
                pipeSharedSecret = nil
                return shutdownBridge(loaderReadPipe, loaderWritePipe)
            end
            if not sendEncryptedFrame(3, 2, challengeBytes) then
                pipeSharedSecret = nil
                return shutdownBridge(loaderReadPipe, loaderWritePipe)
            end
            local stageRequestId = sha256Hex(sessionIdHex .. "|" .. tostring(loadGeneration) .. "|secure_loader|" .. tostring(runtimeClock.epoch_ms() or runtimeClock.monotonic_ms())):sub(1, 32)
            local stageRequestJson = encodeJson(makeJsonObject({
                v = 3,
                kind = "request",
                request_id = stageRequestId,
                command = "stage.get",
                load_generation = loadGeneration,
                session_generation = sessionGeneration,
                body = makeJsonObject({ stage_id = "secure_loader" }),
            }))
            local stageRequestSequence = 3
            local handshakeReadSequence = 2
            if not sendEncryptedFrame(9, stageRequestSequence, stageRequestJson) then
                pipeSharedSecret = nil
                return shutdownBridge(loaderReadPipe, loaderWritePipe)
            end
            local handshakeWriteSequence = stageRequestSequence + 1
            local stageFramePayload = nil
            while true do
                local stageReplyOpcode, stageReplySequence
                stageReplyOpcode, stageReplySequence, stageFramePayload = receiveEncryptedFrame(MAX_FRAME_BYTES)
                if not stageReplyOpcode or stageReplySequence ~= handshakeReadSequence then
                    pipeSharedSecret = nil
                    return shutdownBridge(loaderReadPipe, loaderWritePipe)
                end
                handshakeReadSequence = handshakeReadSequence + 1
                if stageReplyOpcode == 4 and type(stageFramePayload) == "string" then
                    break
                end
                if stageReplyOpcode ~= 7 or stageFramePayload ~= "" then
                    pipeSharedSecret = nil
                    return shutdownBridge(loaderReadPipe, loaderWritePipe)
                end
                if not tryYieldScript(50) or not sendEncryptedFrame(14, handshakeWriteSequence, "") then
                    pipeSharedSecret = nil
                    return shutdownBridge(loaderReadPipe, loaderWritePipe)
                end
                handshakeWriteSequence = handshakeWriteSequence + 1
            end
            local stageHeaderFields = {}
            local stageFieldStart = 1
            for stageFieldIndex = 1, 8 do
                local stageNewlinePos = stageFramePayload:find("\n", stageFieldStart, true)
                if not stageNewlinePos then
                    pipeSharedSecret = nil
                    return shutdownBridge(loaderReadPipe, loaderWritePipe)
                end
                stageHeaderFields[stageFieldIndex] = stageFramePayload:sub(stageFieldStart, stageNewlinePos - 1)
                stageFieldStart = stageNewlinePos + 1
            end
            local secureLoaderSource = stageFramePayload:sub(stageFieldStart)
            local stageExpiresAtMs = tonumber(stageHeaderFields[3])
            local stageSourceLength = tonumber(stageHeaderFields[4])
            local stageLoadGeneration = tonumber(stageHeaderFields[6])
            local stageSessionGeneration = tonumber(stageHeaderFields[7])
            local stageOptionFlag, stageOptionValueText = tostring(stageHeaderFields[8] or ""):match("^([01]):(%d+)$")
            local stageOptionValue = tonumber(stageOptionValueText)
            local nowEpochMs = runtimeClock.epoch_ms()
            if stageHeaderFields[1] ~= "3" or not stageHeaderFields[2]:match("^[0-9a-f]+$") or #stageHeaderFields[2] ~= 16 or not stageExpiresAtMs or not nowEpochMs or stageExpiresAtMs < nowEpochMs or not stageSourceLength or stageSourceLength ~= #secureLoaderSource or stageSourceLength < 1 or stageSourceLength > MAX_PAYLOAD_BYTES or not stageHeaderFields[5]:match("^[0-9a-f]+$") or #stageHeaderFields[5] ~= 64 or not constantTimeEqual(stageHeaderFields[5], sha256Hex(secureLoaderSource)) or stageLoadGeneration ~= loadGeneration or stageSessionGeneration ~= sessionGeneration or stageOptionFlag ~= helloOptionFlag or stageOptionValue ~= helloOptionValue then
                pipeSharedSecret = nil
                return shutdownBridge(loaderReadPipe, loaderWritePipe)
            end
            local stageSha256 = stageHeaderFields[5]
            if not sendEncryptedFrame(5, handshakeWriteSequence, stageSha256) then
                pipeSharedSecret = nil
                return shutdownBridge(loaderReadPipe, loaderWritePipe)
            end
            local heartbeatWriteSequence = handshakeWriteSequence + 1
            isRuntimeReady = false
            local requestSequence = 1
            local outboundRequestQueue = {}
            pendingCancelRequestIds = {}
            pendingRequestsById = {}
            asyncCompletionQueue = { completions = {}, active = false }
            local runtimeEnv = nil
            local runtimeUnloadDeadlineMs = 0
            local unloadAckRequest = nil
            isPumpLoopRegistered = false
            isPumpRunning = false
            nextPumpAtMs = 0
            isSecureLoaderQueued = false
            isStartingSecureLoader = false

            function queueScriptJob(jobFunction)
                local jobQueuedOk, jobQueueResult = pcall(Script.QueueJob, jobFunction)
                return jobQueuedOk and jobQueueResult ~= false
            end

            local reportedUnloadReason = "unknown"
            local allowedUnloadReasons = {
                startup_exception = true,
                render_hang_guard = true,
                config_failed = true,
                permissions_failed = true,
                module_failed = true,
                module_capability_failed = true,
                stage_load_failed = true,
                discord_ipc_failed = true,
                discord_invalidated = true,
                audio_failed = true,
                native_context_failed = true,
                ui_registration_failed = true,
                user_unload = true,
                policy_unload = true,
                unknown = true,
            }

            function stopRuntime(stopReason)
                if isUnloaded then
                    return
                end
                isUnloaded = true
                shutdownReason = stopReason
                pipeSharedSecret = nil
                secureChannel = nil
                outboundRequestQueue = {}
                pendingCancelRequestIds = {}
                pendingRequestsById = {}
                asyncCompletionQueue.completions = {}
                seenNonceSet = {}
                nonceHistoryRing = {}
                nonceRingSlot = 1
                hmacKeyPadCache = {}
                hmacKeyPadCacheSize = 0
                shutdownBridge(loaderReadPipe, loaderWritePipe)
                loaderReadPipe = nil
                loaderWritePipe = nil
            end

            local function generateRequestId()
                requestSequence = requestSequence + 1
                local hashSha256 = sha256Hex
                local sessionPart = sessionIdHex
                local loadGenerationPart = tostring(loadGeneration)
                local sequencePart = tostring(requestSequence)
                local stringifyClock = tostring
                local clockMs = runtimeClock.monotonic_ms()
                return hashSha256(sessionPart .. "|" .. loadGenerationPart .. "|" .. sequencePart .. "|" .. stringifyClock(clockMs)):sub(1, 32)
            end

            local function enqueueBridgeRequest(commandName, requestBody, timeoutMs, isInternal, onComplete)
                if isUnloaded or #outboundRequestQueue >= 16 then
                    return nil
                end
                local pendingRequestCount = 0
                for _ in pairs(pendingRequestsById) do
                    pendingRequestCount = pendingRequestCount + 1
                    if pendingRequestCount >= 16 then
                        return nil
                    end
                end
                local requestId = generateRequestId()
                local requestEntry = {
                    request_id = requestId,
                    command = commandName,
                    body = makeJsonObject(type(requestBody) == "table" and requestBody or {}),
                    deadline = runtimeClock.monotonic_ms() + math.max(250, math.min(30000, tonumber(timeoutMs) or 10000)),
                    completed = false,
                    internal = isInternal == true,
                    on_complete = type(onComplete) == "function" and onComplete or nil,
                    poll_interval_ms = commandName == "players.status.getBatch" and 250 or 20,
                }
                pendingRequestsById[requestId] = requestEntry
                local queueInsertIndex = #outboundRequestQueue + 1
                if requestEntry.internal then
                    for queuedIndex, queuedRequest in ipairs(outboundRequestQueue) do
                        if not queuedRequest.internal then
                            queueInsertIndex = queuedIndex
                            break
                        end
                    end
                end
                table.insert(outboundRequestQueue, queueInsertIndex, requestEntry)
                return requestEntry
            end

            local bridgeApi = {
                version = 3,
                contract = "ks-loader-adapter-v3",
                load_generation = loadGeneration,
                session_generation = sessionGeneration,
                max_frame_bytes = MAX_FRAME_BYTES,
                max_payload_bytes = MAX_PAYLOAD_BYTES,
                direct_payload_max_bytes = DIRECT_PAYLOAD_MAX_BYTES,
                payload_chunk_bytes = PAYLOAD_CHUNK_BYTES,
                max_payload_chunks = MAX_PAYLOAD_CHUNKS,
                player_identity_observations = false,
            }

            function bridgeApi.request(commandName, requestBody, timeoutMs)
                local requestEntry = enqueueBridgeRequest(commandName, requestBody, timeoutMs, false)
                if not requestEntry then
                    return "unavailable", nil, "QUEUE_UNAVAILABLE", "The service is unavailable."
                end
                local isFirstPoll = true
                while not isUnloaded and not requestEntry.completed and runtimeClock.monotonic_ms() < requestEntry.deadline do
                    local waitMs
                    if requestEntry.sent then
                        waitMs = 20
                        if waitMs then
                            goto applyWaitMs
                        end
                    end
                    if isFirstPoll then
                        waitMs = 0
                        if waitMs then
                            goto applyWaitMs
                        end
                    end
                    waitMs = 2
                    ::applyWaitMs::
                    requestEntry.consumer_wait_ms = waitMs
                    if not tryYieldScript(waitMs) then
                        break
                    end
                    isFirstPoll = false
                end
                if not requestEntry.completed then
                    requestEntry.cancelled = true
                    pendingRequestsById[requestEntry.request_id] = nil
                    pendingCancelRequestIds[#pendingCancelRequestIds + 1] = requestEntry.request_id
                    return "timeout", nil, "COMMAND_TIMEOUT", "The request timed out."
                end
                requestEntry.consumed = true
                return requestEntry.status, requestEntry.data, requestEntry.code, requestEntry.message
            end

            function bridgeApi.request_async(commandName, requestBody, timeoutMs, onComplete)
                if commandName ~= "players.status.getBatch" then
                    return nil, "ASYNC_COMMAND_NOT_ALLOWED", "This command requires synchronous authorization."
                end
                if type(onComplete) ~= "function" then
                    return nil, "INVALID_CALLBACK", "A completion callback is required."
                end
                local requestEntry = enqueueBridgeRequest(commandName, requestBody, timeoutMs, false, onComplete)
                if not requestEntry then
                    return nil, "QUEUE_UNAVAILABLE", "The service is unavailable."
                end
                return requestEntry.request_id
            end

            function bridgeApi.signal(signalReason, signalContext)
                return bridgeApi.request("runtime.signal", {
                    reason = signalReason,
                    context = makeJsonObject(type(signalContext) == "table" and signalContext or {}),
                }, 5000)
            end

            function bridgeApi.terminal_violation(violationReason)
                return bridgeApi.request("runtime.terminalViolation", { reason = violationReason }, 5000)
            end

            function bridgeApi.set_unload_reason(requestedReason)
                requestedReason = tostring(requestedReason or "unknown")
                if not allowedUnloadReasons[requestedReason] then
                    requestedReason = "unknown"
                end
                reportedUnloadReason = requestedReason
                return requestedReason
            end

            local secureLoaderEnv = {
                assert = assert,
                pcall = pcall,
                xpcall = xpcall,
                ipairs = ipairs,
                pairs = pairs,
                next = next,
                tonumber = tonumber,
                tostring = tostring,
                type = type,
                select = select,
                setmetatable = setmetatable,
                rawget = rawget,
                rawset = rawset,
                math = math,
                string = string,
                table = table,
                coroutine = coroutine,
                utf8 = utf8,
            }
            setmetatable(secureLoaderEnv, {
                __index = function()
                    return nil
                end,
                __metatable = "locked",
            })

            local function compileInSlices(sourceText, chunkName, loadMode, chunkEnv)
                if type(sourceText) ~= "string" then
                    return nil, "invalid chunk"
                end
                local readOffset = 1
                local sourceLength = #sourceText
                local sliceSeed = sourceLength % 251 + 17
                local isFirstSlice = true
                local compiledChunk, compileError = load(function()
                    if readOffset > sourceLength then
                        return nil
                    end
                    sliceSeed = (sliceSeed * 73 + 41) % 997
                    local sliceLength = isFirstSlice and 7 + sliceSeed % 23 or 73 + sliceSeed % 181
                    isFirstSlice = false
                    local sliceEnd = math.min(sourceLength, readOffset + sliceLength - 1)
                    local sliceText = string.sub(sourceText, readOffset, sliceEnd)
                    readOffset = sliceEnd + 1
                    return sliceText
                end, chunkName, loadMode, chunkEnv)
                local exhaustedOffset = sourceLength + 1
                chunk = nil
                readOffset = exhaustedOffset
                return compiledChunk, compileError
            end

            local secureLoaderChunk = compileInSlices(secureLoaderSource, "@ks", "bt", secureLoaderEnv)
            if type(secureLoaderChunk) ~= "function" then
                return stopRuntime("secure_loader_compile_failed")
            end
            local secureLoaderOk
            secureLoaderOk, secureLoaderEntry = pcall(secureLoaderChunk)
            if not secureLoaderOk or type(secureLoaderEntry) ~= "function" then
                return stopRuntime("secure_loader_contract_failed")
            end
            hostGlobals = { io = io, os = os }
            for _, hostGlobalName in ipairs({
                "assert",
                "pcall",
                "xpcall",
                "ipairs",
                "pairs",
                "next",
                "tonumber",
                "tostring",
                "type",
                "select",
                "setmetatable",
                "rawget",
                "rawset",
                "collectgarbage",
                "math",
                "string",
                "table",
                "coroutine",
                "utf8",
                "CBaseModelInfo",
                "CNetGamePlayer",
                "CObjectCreationDataNode",
                "CPed",
                "CPedAppearanceDataNode",
                "CPedCreationDataNode",
                "CPedGameStateDataNode",
                "CPedTaskTreeDataNode",
                "CPlayerAppearanceDataNode",
                "CPlayerInfo",
                "CVehicleAppearanceDataNode",
                "CVehicleCreationDataNode",
                "CVehicleModelInfo",
                "CVehicleProximityMigrationDataNode",
                "CVehicleTaskDataNode",
                "Cherax",
                "ClickGUI",
                "Curl",
                "EventMgr",
                "Feature",
                "FeatureMgr",
                "FileMgr",
                "GTA",
                "GUI",
                "GamerHandle",
                "GamerInfo",
                "ImGui",
                "ImGuiCol",
                "ImGuiCond",
                "ImGuiInputTextFlags",
                "ImGuiKey",
                "ImGuiMouseCursor",
                "ImGuiStyleVar",
                "ImGuiTabBarFlags",
                "ImGuiTableColumnFlags",
                "ImGuiTableFlags",
                "ImGuiWindowFlags",
                "ListGUI",
                "Logger",
                "Memory",
                "ModderDB",
                "Natives",
                "NetworkObjectMgr",
                "Players",
                "PoolMgr",
                "Script",
                "ScriptGlobal",
                "ScriptLocal",
                "SetShouldUnload",
                "ShouldUnload",
                "Tab",
                "Texture",
                "Time",
                "Utils",
                "V2",
                "V3",
                "eCurlCode",
                "eCurlOption",
                "eFeatureType",
                "eGuiMode",
                "eLogColor",
                "eLuaEvent",
                "eProtectionType",
                "eReportReason",
                "eSyncDataNode",
                "eToastPos",
                "AUDIO",
                "CAM",
                "CLOCK",
                "CUTSCENE",
                "DATAFILE",
                "DECORATOR",
                "DLC",
                "ENTITY",
                "FIRE",
                "GRAPHICS",
                "HUD",
                "INTERIOR",
                "ITEMSET",
                "LOADINGSCREEN",
                "MISC",
                "MOBILE",
                "MONEY",
                "NETWORK",
                "OBJECT",
                "PAD",
                "PATHFIND",
                "PED",
                "PHYSICS",
                "PLAYER",
                "RECORDING",
                "REPLAY",
                "SCRIPT",
                "SHAPETEST",
                "SOCIALCLUB",
                "STATS",
                "STREAMING",
                "TASK",
                "VEHICLE",
                "WATER",
                "WEAPON",
                "ZONE",
            }) do
                local hostGlobalValue = _ENV[hostGlobalName]
                if hostGlobalValue ~= nil then
                    hostGlobals[hostGlobalName] = hostGlobalValue
                end
            end
            secureLoaderContext = {
                bridge = bridgeApi,
                host = hostGlobals,
                stage_sha256 = stageSha256,
                sha256 = sha256Hex,
                decode_base64 = decodeBase64,
                now_ms = runtimeClock.epoch_ms,
                max_frame_bytes = MAX_FRAME_BYTES,
                max_payload_bytes = MAX_PAYLOAD_BYTES,
                direct_payload_max_bytes = DIRECT_PAYLOAD_MAX_BYTES,
                payload_chunk_bytes = PAYLOAD_CHUNK_BYTES,
                max_payload_chunks = MAX_PAYLOAD_CHUNKS,
            }

            function secureLoaderContext.compile(moduleSource, unusedChunkName, moduleEnv)
                return compileInSlices(moduleSource, "@ks", "bt", moduleEnv)
            end

            function secureLoaderContext.set_runtime_env(providedRuntimeEnv)
                runtimeEnv = providedRuntimeEnv
            end

            function secureLoaderContext.dismiss_boot_visual()
                bootOverlay.stop()
            end

            secureLoaderContext.stop = stopRuntime
            if not sendEncryptedFrame(6, heartbeatWriteSequence, "") then
                return stopRuntime("initial_heartbeat_write_failed")
            end
            local runtimeWriteSequence = heartbeatWriteSequence + 1
            local heartbeatFrameType, heartbeatFrameSequence, heartbeatFramePayload = receiveEncryptedFrame(MAX_FRAME_BYTES)
            if heartbeatFrameType ~= 7 or heartbeatFrameSequence ~= handshakeReadSequence or heartbeatFramePayload ~= "" then
                return stopRuntime("initial_heartbeat_invalid")
            end
            local runtimeReadSequence = handshakeReadSequence + 1
            lastResponseAtMs = runtimeClock.monotonic_ms()

            function asyncCompletionQueue.queue(completedRequest)
                if type(completedRequest) ~= "table" or type(completedRequest.on_complete) ~= "function" or #asyncCompletionQueue.completions >= 16 then
                    return false
                end
                completedRequest.consumed = true
                asyncCompletionQueue.completions[#asyncCompletionQueue.completions + 1] = {
                    callback = completedRequest.on_complete,
                    status = completedRequest.status,
                    data = completedRequest.data,
                    code = completedRequest.code,
                    message = completedRequest.message,
                }
                completedRequest.on_complete = nil
                completedRequest.data = nil
                return true
            end

            function asyncCompletionQueue.drain()
                if isUnloaded or asyncCompletionQueue.active or #asyncCompletionQueue.completions == 0 then
                    return true
                end
                asyncCompletionQueue.active = true
                local completionEntry = table.remove(asyncCompletionQueue.completions, 1)
                local completionCallback = completionEntry.callback
                completionEntry.callback = nil
                local callbackOk = pcall(completionCallback, completionEntry.status, completionEntry.data, completionEntry.code, completionEntry.message)
                completionEntry.data = nil
                asyncCompletionQueue.active = false
                if not callbackOk and not isUnloaded then
                    stopRuntime("async_callback_failed")
                    return false
                end
                return not isUnloaded
            end

            local function applyResponseMessage(responseMessage)
                if type(responseMessage) ~= "table" or responseMessage.v ~= 3 or responseMessage.kind ~= "response" or responseMessage.load_generation ~= loadGeneration or responseMessage.session_generation ~= sessionGeneration or type(responseMessage.request_id) ~= "string" then
                    return false
                end
                local respondedRequest = pendingRequestsById[responseMessage.request_id]
                if not respondedRequest then
                    return true
                end
                pendingRequestsById[responseMessage.request_id] = nil
                respondedRequest.status = tostring(responseMessage.status or "error")
                respondedRequest.code = tostring(responseMessage.code or "INTERNAL_ERROR")
                respondedRequest.message = tostring(responseMessage.message or "The request could not be completed.")
                respondedRequest.data = type(responseMessage.data) == "table" and responseMessage.data or {}
                respondedRequest.completed = true
                if respondedRequest.on_complete and not asyncCompletionQueue.queue(respondedRequest) then
                    return false
                end
                if respondedRequest.command == "startup.snapshot" and respondedRequest.status == "ok" then
                    bridgeApi.module_failure_reports = respondedRequest.data.module_failure_reports == 1
                end
                if respondedRequest.command == "runtime.ready" and respondedRequest.status == "ok" then
                    bridgeApi.player_identity_observations = respondedRequest.data.player_identity_observations == 1
                    isRuntimeReady = true
                    bootOverlay.stop()
                end
                if unloadAckRequest == respondedRequest then
                    return stopRuntime("runtime_unload_acknowledged")
                end
                return true
            end

            local function isValidStaffNotification(staffNotification)
                if type(staffNotification) ~= "table" then
                    return false
                end
                local allowedNotificationFields = {
                    v = true,
                    notification_id = true,
                    type = true,
                    message = true,
                    sender_label = true,
                    created_at_ms = true,
                    expires_at_ms = true,
                    requires_acknowledgement = true,
                }
                local notificationFieldCount = 0
                for notificationFieldName in pairs(staffNotification) do
                    if not allowedNotificationFields[notificationFieldName] then
                        return false
                    end
                    notificationFieldCount = notificationFieldCount + 1
                end
                if notificationFieldCount ~= 8 or staffNotification.v ~= 1 or type(staffNotification.notification_id) ~= "string" or #staffNotification.notification_id ~= 32 or not staffNotification.notification_id:match("^[0-9a-f]+$") or staffNotification.type ~= "MESSAGE" and staffNotification.type ~= "WARNING" or type(staffNotification.message) ~= "string" or #staffNotification.message < 1 or #staffNotification.message > 4000 or staffNotification.message:find("[%z\x01-\x08\x0b\x0c\x0e-\x1f\x7f]") or staffNotification.sender_label ~= "K-Script Staff" or type(staffNotification.created_at_ms) ~= "number" or math.type(staffNotification.created_at_ms) ~= "integer" or type(staffNotification.expires_at_ms) ~= "number" or math.type(staffNotification.expires_at_ms) ~= "integer" or staffNotification.created_at_ms <= 0 or staffNotification.expires_at_ms <= staffNotification.created_at_ms or staffNotification.expires_at_ms - staffNotification.created_at_ms > 7862400000 or type(staffNotification.requires_acknowledgement) ~= "boolean" or staffNotification.requires_acknowledgement ~= (staffNotification.type == "WARNING") then
                    return false
                end
                return utf8.len(staffNotification.message) ~= nil
            end

            local function isValidRuntimeControl(controlCommand)
                if type(controlCommand) ~= "table" then
                    return false
                end
                if not runtimeClock.epoch_ms() then
                    return false
                end
                local allowedControlFields = {
                    v = true,
                    command_id = true,
                    action = true,
                    sender_rockstar_id = true,
                    sender_name = true,
                    target_rockstar_id = true,
                    load_generation = true,
                    created_at_ms = true,
                    expires_at_ms = true,
                }
                local controlFieldCount = 0
                for controlFieldName in pairs(controlCommand) do
                    if not allowedControlFields[controlFieldName] then
                        return false
                    end
                    controlFieldCount = controlFieldCount + 1
                end
                return controlFieldCount == 9
            end

            local function handlePushMessage(pushMessage)
                if type(pushMessage) ~= "table" or pushMessage.v ~= 3 or pushMessage.kind ~= "push" or pushMessage.load_generation ~= loadGeneration or pushMessage.session_generation ~= sessionGeneration or type(pushMessage.push_id) ~= "string" or type(pushMessage.command) ~= "string" or type(pushMessage.body) ~= "table" then
                    return false
                end
                if pushMessage.command == "policy.update" then
                    if runtimeEnv and type(runtimeEnv.KSBridgeOnPolicyUpdate) == "function" then
                        runtimeEnv.KSBridgeOnPolicyUpdate(pushMessage.body)
                    end
                elseif pushMessage.command == "session.expiring" then
                    if runtimeEnv and type(runtimeEnv.KSBridgeOnSessionExpiring) == "function" then
                        runtimeEnv.KSBridgeOnSessionExpiring(pushMessage.body)
                    end
                elseif pushMessage.command == "users.refresh" then
                    if isRuntimeReady and runtimeEnv and type(runtimeEnv.KSBridgeOnOnlineUsersRefresh) == "function" then
                        runtimeEnv.KSBridgeOnOnlineUsersRefresh(pushMessage.body)
                    end
                elseif pushMessage.command == "staff.notification.deliver" then
                    if not isRuntimeReady or not isValidStaffNotification(pushMessage.body) or not runtimeEnv or type(runtimeEnv.KSBridgeOnStaffNotification) ~= "function" then
                        return false
                    end
                    local notificationCallOk, isNotificationHandled = pcall(runtimeEnv.KSBridgeOnStaffNotification, pushMessage.body)
                    if notificationCallOk and isNotificationHandled == true then
                        enqueueBridgeRequest("staff.notification.receipt", { notification_id = pushMessage.body.notification_id }, 5000, true)
                    end
                elseif pushMessage.command == "runtime.control.deliver" then
                    if not isRuntimeReady or not isValidRuntimeControl(pushMessage.body) or not runtimeEnv or type(runtimeEnv.KSBridgeOnRuntimeControl) ~= "function" then
                        return false
                    end
                    local controlCallOk, controlOutcome = pcall(runtimeEnv.KSBridgeOnRuntimeControl, pushMessage.body)
                    if not controlCallOk or not ({
                        executed = true,
                        rejected_stale = true,
                        rejected_session = true,
                        rejected_host = true,
                        rejected_target = true,
                        rejected_invalid = true,
                        scheduling_failed = true,
                        execution_failed = true,
                    })[controlOutcome] then
                        controlOutcome = "execution_failed"
                    end
                    if not enqueueBridgeRequest("runtime.control.result", { command_id = pushMessage.body.command_id, result = controlOutcome }, 5000, true) then
                        return false
                    end
                elseif pushMessage.command == "runtime.unload" then
                    local unloadGraceMs = math.max(250, math.min(5000, tonumber(pushMessage.body.deadline_ms) or 1000))
                    runtimeUnloadDeadlineMs = runtimeClock.monotonic_ms() + unloadGraceMs
                    local unloadToastMessage = type(pushMessage.body.message) == "string" and string.sub(pushMessage.body.message, 1, 256) or ""
                    if unloadToastMessage ~= "" and type(GUI) == "table" and type(GUI.AddToast) == "function" then
                        local toastPosition = type(eToastPos) == "table" and eToastPos.TOP_RIGHT or nil
                        pcall(GUI.AddToast, "K-Script", unloadToastMessage, 5000, toastPosition)
                    end
                    local cleanupStatus = "ok"
                    if runtimeEnv and type(runtimeEnv.KSBridgeOnUnload) == "function" and runtimeEnv.KSBridgeOnUnload(pushMessage.body) == "partial" then
                        cleanupStatus = "partial"
                    end
                    unloadAckRequest = enqueueBridgeRequest("runtime.unloadAck", { push_id = pushMessage.push_id, cleanup_status = cleanupStatus }, 1000, true)
                    if not unloadAckRequest then
                        return stopRuntime("runtime_unload")
                    end
                else
                    return false
                end
                return true
            end

            local function sendUnloadedStatusAndStop()
                local unloadedStatusJson = encodeJson({
                    v = 3,
                    status = "unloaded",
                    load_generation = loadGeneration,
                    session_generation = sessionGeneration,
                    reason = reportedUnloadReason,
                })
                sendEncryptedFrameWithDeadline(8, runtimeWriteSequence, unloadedStatusJson)
                runtimeWriteSequence = runtimeWriteSequence + 1
                return stopRuntime("local_unload")
            end

            local function yieldAndCheckUnload(yieldMs)
                if not tryYieldScript(math.max(0, tonumber(yieldMs) or 0)) then
                    return "scheduler_unavailable"
                end
                if type(ShouldUnload) == "function" and ShouldUnload() then
                    sendUnloadedStatusAndStop()
                    return "unloaded"
                end
                return "ready"
            end

            local function waitForRequestConsumer(completedRequest)
                local waitDeadlineMs = math.min(completedRequest.deadline, runtimeClock.monotonic_ms() + 25)
                while not isUnloaded and not completedRequest.consumed and waitDeadlineMs > runtimeClock.monotonic_ms() do
                    local consumerWaitMs = math.min(20, math.max(0, tonumber(completedRequest.consumer_wait_ms) or 0))
                    local yieldStatus = yieldAndCheckUnload(consumerWaitMs + 1)
                    if yieldStatus ~= "ready" then
                        return yieldStatus
                    end
                end
                return "ready"
            end

            local responseYieldMs = 5

            function asyncCompletionQueue.expire(currentTimeMs)
                local expiredRequestIds = {}
                for requestId, trackedRequest in pairs(pendingRequestsById) do
                    if trackedRequest.on_complete and currentTimeMs >= trackedRequest.deadline then
                        expiredRequestIds[#expiredRequestIds + 1] = requestId
                    end
                end
                for _, expiredRequestId in ipairs(expiredRequestIds) do
                    local expiredRequest = pendingRequestsById[expiredRequestId]
                    if expiredRequest then
                        pendingRequestsById[expiredRequestId] = nil
                        expiredRequest.cancelled = true
                        expiredRequest.status = "timeout"
                        expiredRequest.data = {}
                        expiredRequest.code = "COMMAND_TIMEOUT"
                        expiredRequest.message = "The request timed out."
                        expiredRequest.completed = true
                        if expiredRequest.sent then
                            pendingCancelRequestIds[#pendingCancelRequestIds + 1] = expiredRequestId
                        end
                        if not asyncCompletionQueue.queue(expiredRequest) then
                            return false
                        end
                    end
                end
                return true
            end

            function asyncCompletionQueue.pending_poll_interval_ms()
                local pendingPollIntervalMs = nil
                for _, inflightRequest in pairs(pendingRequestsById) do
                    if inflightRequest.sent then
                        local requestPollIntervalMs = math.max(20, math.min(250, tonumber(inflightRequest.poll_interval_ms) or 20))
                        if not pendingPollIntervalMs or not math.min(pendingPollIntervalMs, requestPollIntervalMs) then
                            pendingPollIntervalMs = requestPollIntervalMs
                        end
                    end
                end
                return pendingPollIntervalMs
            end

            function runBridgeExchange()
                if isUnloaded then
                    return
                end
                if type(ShouldUnload) == "function" and ShouldUnload() then
                    return sendUnloadedStatusAndStop()
                end
                local nowMs = runtimeClock.monotonic_ms()
                if runtimeUnloadDeadlineMs > 0 and nowMs >= runtimeUnloadDeadlineMs then
                    return stopRuntime("runtime_unload_deadline")
                end
                if not asyncCompletionQueue.expire(nowMs) then
                    return stopRuntime("async_completion_queue_full")
                end
                local hasPendingRequests = next(pendingRequestsById) ~= nil
                if not (#pendingCancelRequestIds > 0) then
                    return
                end
                local outgoingOpcode = 6
                local outgoingPayload = ""
                local cancelledRequestId = table.remove(pendingCancelRequestIds, 1)
                local nextQueuedRequest = nil
                if cancelledRequestId then
                    outgoingOpcode = 13
                    outgoingPayload = encodeJson({
                        v = 3,
                        request_id = cancelledRequestId,
                        load_generation = loadGeneration,
                        session_generation = sessionGeneration,
                    })
                else
                    nextQueuedRequest = table.remove(outboundRequestQueue, 1)
                    while nextQueuedRequest and nextQueuedRequest.cancelled do
                        nextQueuedRequest = table.remove(outboundRequestQueue, 1)
                    end
                end
                if nextQueuedRequest then
                    nextQueuedRequest.sent = true
                    outgoingOpcode = 9
                    outgoingPayload = encodeJson({
                        v = 3,
                        kind = "request",
                        request_id = nextQueuedRequest.request_id,
                        command = nextQueuedRequest.command,
                        load_generation = loadGeneration,
                        session_generation = sessionGeneration,
                        body = nextQueuedRequest.body,
                    })
                end
                if not sendEncryptedFrameWithDeadline(outgoingOpcode, runtimeWriteSequence, outgoingPayload) then
                    return stopRuntime("write_failed")
                end
                runtimeWriteSequence = runtimeWriteSequence + 1
                if not tryYieldScript(responseYieldMs) then
                    return stopRuntime("scheduler_unavailable")
                end
                local responseOpcode, responseSequence, responsePayload = receiveEncryptedFrame(MAX_FRAME_BYTES)
                if not responseOpcode or responseSequence ~= runtimeReadSequence then
                    return stopRuntime("response_invalid")
                end
                runtimeReadSequence = runtimeReadSequence + 1
                lastResponseAtMs = runtimeClock.monotonic_ms()
                if responseOpcode == 7 then
                    if responsePayload ~= "" then
                        return stopRuntime("poll_invalid")
                    end
                elseif responseOpcode == 10 then
                    local decodedResponse = decodeJsonWithDeadline(responsePayload)
                    local matchedRequest = type(decodedResponse) == "table" and pendingRequestsById[decodedResponse.request_id] or nil
                    if not applyResponseMessage(decodedResponse) then
                        return stopRuntime("response_invalid")
                    end
                    if matchedRequest and not isUnloaded then
                        local consumerWaitStatus = waitForRequestConsumer(matchedRequest)
                        if consumerWaitStatus == "unloaded" then
                            return
                        end
                        if consumerWaitStatus ~= "ready" then
                            return stopRuntime(consumerWaitStatus)
                        end
                    end
                elseif responseOpcode == 11 then
                    local decodedPush = decodeJsonWithDeadline(responsePayload)
                    if not handlePushMessage(decodedPush) then
                        return stopRuntime("push_invalid")
                    end
                else
                    return stopRuntime("opcode_invalid")
                end
            end
        end

        local function pumpBridge()
            if isUnloaded or not isPumpLoopRegistered then
                return false
            end
            if isPumpRunning then
                return true
            end
            local pumpNowMs = runtimeClock.monotonic_ms()
            local shouldUnloadHook = ShouldUnload
            local hasUrgentWork = shouldUnloadHook == "function" and shouldUnloadHook or #pendingCancelRequestIds > 0
            if not hasUrgentWork and pumpNowMs < nextPumpAtMs then
                return true
            end
            local firstPendingRequestId = next(pendingRequestsById)
            if not hasUrgentWork and firstPendingRequestId == nil and isRuntimeReady and pumpNowMs - lastResponseAtMs < 250 then
                nextPumpAtMs = math.min(lastResponseAtMs + 250, pumpNowMs + 50)
                return true
            end
            isPumpRunning = true
            local pumpOk = pcall(runBridgeExchange)
            isPumpRunning = false
            local nextPollIntervalMs = asyncCompletionQueue.pending_poll_interval_ms()
            nextPumpAtMs = runtimeClock.monotonic_ms() + (nextPollIntervalMs or 50)
            if not pumpOk and not isUnloaded then
                return stopRuntime("bridge_pump_execution_failed")
            end
            return pumpOk
        end

        local function isBridgeFullyStarted()
            return isPumpLoopRegistered and isSecureLoaderQueued
        end

        local function ensureSecureLoaderStarted()
            if isUnloaded then
                return false
            end
            if isBridgeFullyStarted() then
                return true
            end
            if isStartingSecureLoader then
                return false
            end
            isStartingSecureLoader = true
            if not isPumpLoopRegistered then
                isStartingSecureLoader = false
                return false
            end
            if not isSecureLoaderQueued then
                local capturedLoaderEntry = secureLoaderEntry
                local capturedLoaderContext = secureLoaderContext
                if type(capturedLoaderEntry) ~= "function" or type(capturedLoaderContext) ~= "table" then
                    isStartingSecureLoader = false
                    return stopRuntime("secure_loader_contract_failed")
                end
                isSecureLoaderQueued = true
                if not queueScriptJob(function()
                    if isUnloaded then
                        return
                    end
                    local loaderRunOk, loaderRunResult = pcall(capturedLoaderEntry, capturedLoaderContext)
                    capturedLoaderEntry = nil
                    capturedLoaderContext = nil
                    if not loaderRunOk or loaderRunResult == false then
                        stopRuntime("secure_loader_execution_failed")
                    end
                end) then
                    isSecureLoaderQueued = false
                    isStartingSecureLoader = false
                    return false
                end
                secureLoaderEntry = nil
                secureLoaderContext = nil
                hostGlobals = nil
            end
            isStartingSecureLoader = false
            return isBridgeFullyStarted()
        end

        local registerLoopOk, registerLoopResult = pcall(Script.RegisterLooped, function()
            if isUnloaded then
                return
            end
            if not isBridgeFullyStarted() then
                ensureSecureLoaderStarted()
            end
            pumpBridge()
            asyncCompletionQueue.drain()
        end)
        isPumpLoopRegistered = registerLoopOk and registerLoopResult ~= false
        if not isPumpLoopRegistered then
            return stopRuntime("bridge_pump_schedule_failed")
        end
        local loaderStartDeadlineMs = runtimeClock.monotonic_ms() + 250
        while not isBridgeFullyStarted() and not isUnloaded and loaderStartDeadlineMs > runtimeClock.monotonic_ms() do
            ensureSecureLoaderStarted()
            if isBridgeFullyStarted() then
                break
            end
            if not tryYieldScript(10) then
                return stopRuntime("secure_loader_schedule_failed")
            end
        end
        if not isBridgeFullyStarted() and not ensureSecureLoaderStarted() then
            return stopRuntime("secure_loader_schedule_failed")
        end
    end)()
end)
if not queueJobPcallOk or queueJobPcallResult == false then
    rawset(globalEnvTable, BRIDGE_ACTIVE_GUARD_KEY, nil)
    if type(SetShouldUnload) == "function" then
        SetShouldUnload()
    end
end
