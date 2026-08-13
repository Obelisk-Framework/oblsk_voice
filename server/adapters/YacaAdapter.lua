-- core/modules/oblsk_voice/server/adapters/YacaAdapter.lua
--- YacaAdapter - wraps yaca-systems/fivem-yaca-typescript (YaCA, TeamSpeak
--- based). Unlike pma-voice, YaCA has first-class phone-call support, so
--- startCall/endCall map onto its own call exports rather than borrowing
--- the radio-channel mechanism. Radio uses setActiveRadioChannel.
--- See docs/superpowers/specs/2026-08-13-phone-booth-and-voice-service-design.md §A.
YacaAdapter = {}

local RESOURCE = 'yaca-voice'

function YacaAdapter.setProximity(source, range)
    exports[RESOURCE]:setPlayerVoiceRange(source, range)
end

function YacaAdapter.joinRadioChannel(source, channelId)
    exports[RESOURCE]:setActiveRadioChannel(source, channelId, true)
end

function YacaAdapter.leaveRadioChannel(source, channelId)
    exports[RESOURCE]:setActiveRadioChannel(source, channelId, false)
end

function YacaAdapter.startCall(callId, sourceA, sourceB)
    exports[RESOURCE]:phoneCallStart(callId, sourceA, sourceB)
end

function YacaAdapter.endCall(callId, sourceA, sourceB)
    exports[RESOURCE]:phoneCallEnd(callId, sourceA, sourceB)
end

return YacaAdapter
