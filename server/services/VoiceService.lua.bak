-- core/modules/oblsk_voice/server/services/VoiceService.lua
--- VoiceService - the one seam every other plugin calls into for voice.
--- Resolves Config.provider to a VoiceAdapter once (cached) and forwards
--- every call to it. Never call a provider's own exports/natives from
--- outside this file. See
--- docs/superpowers/specs/2026-08-13-phone-booth-and-voice-service-design.md §A.
VoiceService = {}

local adapters = {
    native = NativeAdapter,
    pma = PmaAdapter,
    yaca = YacaAdapter,
    saltychat = SaltychatAdapter,
}

local activeAdapter

local function resolveAdapter()
    local adapter = adapters[Config.provider]
    if not adapter then
        print(('[VoiceService] WARNING: unknown Config.provider "%s", falling back to native'):format(tostring(Config.provider)))
        adapter = NativeAdapter
    end
    return adapter
end

local function adapter()
    if not activeAdapter then
        activeAdapter = resolveAdapter()
    end
    return activeAdapter
end

--- Test-only: forces VoiceService to re-resolve its adapter from the
--- current Config.provider. Never called from production code paths.
function VoiceService.resetAdapterForTests()
    activeAdapter = resolveAdapter()
end

--- @param source number
--- @param range number metres
function VoiceService.setProximity(source, range)
    adapter().setProximity(source, range)
end

--- @param source number
--- @param channelId string
function VoiceService.joinRadioChannel(source, channelId)
    adapter().joinRadioChannel(source, channelId)
end

--- @param source number
--- @param channelId string
function VoiceService.leaveRadioChannel(source, channelId)
    adapter().leaveRadioChannel(source, channelId)
end

--- @param callId number
--- @param sourceA number
--- @param sourceB number
function VoiceService.startCall(callId, sourceA, sourceB)
    adapter().startCall(callId, sourceA, sourceB)
end

--- @param callId number
function VoiceService.endCall(callId)
    adapter().endCall(callId)
end

return VoiceService
