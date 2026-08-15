-- core/modules/oblsk_voice/server/adapters/SaltychatAdapter.lua
--- SaltychatAdapter - wraps v10networkscom/saltychat-fivem (SaltyChat,
--- TeamSpeak based). SaltyChat's exports are server-side and take a
--- numeric player id directly (no client round-trip needed for these
--- setters). startCall puts both parties into the same radio channel with
--- their phone speaker enabled, which is how SaltyChat's own phone
--- integrations bridge two players without a dedicated "call" export.
--- See docs/superpowers/specs/2026-08-13-phone-booth-and-voice-service-design.md §A.
SaltychatAdapter = {}

local RESOURCE = 'saltychat'

local function callChannelName(callId)
    return 'call-' .. tostring(callId)
end

function SaltychatAdapter.setProximity(source, range)
    exports[RESOURCE]:SetPlayerVoiceRange(source, range)
end

function SaltychatAdapter.joinRadioChannel(source, channelId, slot)
    exports[RESOURCE]:SetPlayerRadioChannel(source, channelId, slot == 'primary')
end

function SaltychatAdapter.leaveRadioChannel(source, channelId, slot)
    exports[RESOURCE]:SetPlayerRadioChannel(source, '', slot == 'primary')
end

function SaltychatAdapter.startCall(callId, sourceA, sourceB)
    local channel = callChannelName(callId)
    exports[RESOURCE]:SetPlayerRadioChannel(sourceA, channel, true)
    exports[RESOURCE]:SetPlayerRadioChannel(sourceB, channel, true)
    exports[RESOURCE]:SetPhoneSpeaker(sourceA, true)
    exports[RESOURCE]:SetPhoneSpeaker(sourceB, true)
end

function SaltychatAdapter.endCall(callId, sourceA, sourceB)
    if sourceA then
        exports[RESOURCE]:SetPlayerRadioChannel(sourceA, '', true)
        exports[RESOURCE]:SetPhoneSpeaker(sourceA, false)
    end
    if sourceB then
        exports[RESOURCE]:SetPlayerRadioChannel(sourceB, '', true)
        exports[RESOURCE]:SetPhoneSpeaker(sourceB, false)
    end
end

return SaltychatAdapter
