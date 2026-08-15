-- core/modules/oblsk_voice/server/adapters/PmaAdapter.lua
--- PmaAdapter - wraps AvarianKnight/pma-voice (Mumble-based). pma-voice owns
--- proximity via its own radio/proximity module once running, so this
--- adapter forwards through pma-voice's own exports rather than the bare
--- game native directly (two owners fighting over
--- NETWORK_SET_TALKER_PROXIMITY is a known source of proximity bugs in
--- every pma-voice integration guide).
---
--- pma-voice has no first-class "call" concept: a call is implemented, the
--- same way every existing pma-voice phone script does it, as a two-person
--- ephemeral radio channel — both parties get setPlayerRadio'd onto
--- 'call-<callId>' and released from it on hangup.
--- See docs/superpowers/specs/2026-08-13-phone-booth-and-voice-service-design.md §A.
PmaAdapter = {}

local RESOURCE = 'pma-voice'

local function callChannelId(callId)
    return 'call-' .. tostring(callId)
end

function PmaAdapter.setProximity(source, range)
    exports[RESOURCE]:setTalkerProximity(source, range)
end

--- Best-effort: maps `slot` onto pma-voice's short/long radio-range concept
--- - unverified against a live install, same tier as this adapter's other
--- exports.
function PmaAdapter.joinRadioChannel(source, channelId, slot)
    exports[RESOURCE]:setPlayerRadio(source, channelId, false, slot == 'primary' and 'long' or 'short')
end

function PmaAdapter.leaveRadioChannel(source, channelId, slot)
    exports[RESOURCE]:setPlayerRadio(source, channelId, true, slot == 'primary' and 'long' or 'short')
end

function PmaAdapter.startCall(callId, sourceA, sourceB)
    local channelId = callChannelId(callId)
    exports[RESOURCE]:setPlayerRadio(sourceA, channelId, false)
    exports[RESOURCE]:setPlayerRadio(sourceB, channelId, false)
end

function PmaAdapter.endCall(callId, sourceA, sourceB)
    local channelId = callChannelId(callId)
    if sourceA then exports[RESOURCE]:setPlayerRadio(sourceA, channelId, true) end
    if sourceB then exports[RESOURCE]:setPlayerRadio(sourceB, channelId, true) end
end

return PmaAdapter
