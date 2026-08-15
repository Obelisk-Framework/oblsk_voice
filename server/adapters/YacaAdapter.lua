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

--- Best-effort: forwards `slot` as a 4th argument identifying which of
--- yaca-voice's concurrent channel slots this join targets - unverified
--- against a live install, same tier as this adapter's other exports.
function YacaAdapter.joinRadioChannel(source, channelId, slot)
    exports[RESOURCE]:setActiveRadioChannel(source, channelId, true, slot)
end

function YacaAdapter.leaveRadioChannel(source, channelId, slot)
    exports[RESOURCE]:setActiveRadioChannel(source, channelId, false, slot)
end

function YacaAdapter.startCall(callId, sourceA, sourceB)
    exports[RESOURCE]:phoneCallStart(callId, sourceA, sourceB)
end

function YacaAdapter.endCall(callId, sourceA, sourceB)
    exports[RESOURCE]:phoneCallEnd(callId, sourceA, sourceB)
end

return YacaAdapter
