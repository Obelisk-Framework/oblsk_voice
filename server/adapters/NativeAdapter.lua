-- core/modules/oblsk_voice/server/adapters/NativeAdapter.lua
--- NativeAdapter - the safe default VoiceAdapter. Real proximity via the
--- bare game native (no external voice resource required). Radio channels
--- and calls are no-ops: gameplay state still transitions normally, there
--- is just no audio, so a server can run every plugin above VoiceService
--- with zero voice resources installed and nothing breaks.
--- See docs/superpowers/specs/2026-08-13-phone-booth-and-voice-service-design.md §A.
NativeAdapter = {}

function NativeAdapter.setProximity(source, range)
    NetworkSetTalkerProximity(range)
end

function NativeAdapter.joinRadioChannel(source, channelId) end
function NativeAdapter.leaveRadioChannel(source, channelId) end
function NativeAdapter.startCall(callId, sourceA, sourceB) end
function NativeAdapter.endCall(callId) end

return NativeAdapter
