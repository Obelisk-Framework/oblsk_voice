-- core/modules/oblsk_voice/server/services/VoiceService.lua
--- VoiceService - the one seam every other plugin calls into for voice.
--- Resolves this module's own config.provider to a VoiceAdapter once
--- (cached) and forwards every call to it. Never call a provider's own
--- exports/natives from outside this file. See
--- docs/superpowers/specs/2026-08-13-phone-booth-and-voice-service-design.md §A.
VoiceService = {}

local adapters = {
    native = NativeAdapter,
    pma = PmaAdapter,
    yaca = YacaAdapter,
    saltychat = SaltychatAdapter,
}

--- Reads THIS module's own shared/config.lua in an isolated environment, the
--- same way core/server/bootstrap.lua reads each plugin's Config.Requires.
--- Deliberately NOT the bare global `Config`: core/fxmanifest.lua globs every
--- core/module/plugin shared script into ONE FXServer resource, so they all
--- share a single Lua global environment and the last `Config = {}` to load
--- wins. Reading the global here would hand VoiceService whatever unrelated
--- plugin happened to load last.
local function loadOwnConfig()
    local path = 'modules/oblsk_voice/shared/config.lua'
    local content = LoadResourceFile(GetCurrentResourceName(), path)
    if not content then return {} end
    local chunk = load(content, path, 't', {})
    if not chunk then return {} end
    local ok, cfg = pcall(chunk)
    return (ok and type(cfg) == 'table') and cfg or {}
end

--- Loaded once, at script load: the config never changes at runtime, and
--- re-reading/compiling the file on every setProximity/joinRadioChannel call
--- would be pure waste.
local VoiceConfig = loadOwnConfig()

local activeAdapter

local function resolveAdapter()
    local adapter = adapters[VoiceConfig.provider]
    if not adapter then
        print(('[VoiceService] WARNING: unknown Config.provider "%s", falling back to native'):format(tostring(VoiceConfig.provider)))
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

--- Test-only: replaces the self-loaded config and drops the cached adapter so
--- the next call re-resolves. Passing nil re-reads shared/config.lua from
--- disk. Never called from production code paths.
--- @param cfg table|nil
function VoiceService.setConfigForTests(cfg)
    VoiceConfig = cfg or loadOwnConfig()
    activeAdapter = nil
end

--- Test-only: forces VoiceService to re-resolve its adapter from the
--- currently loaded config. Never called from production code paths.
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
--- @param slot string|nil 'primary' (default) or 'secondary'
function VoiceService.joinRadioChannel(source, channelId, slot)
    adapter().joinRadioChannel(source, channelId, slot or 'primary')
end

--- @param source number
--- @param channelId string
--- @param slot string|nil 'primary' (default) or 'secondary'
function VoiceService.leaveRadioChannel(source, channelId, slot)
    adapter().leaveRadioChannel(source, channelId, slot or 'primary')
end

--- @param callId number
--- @param sourceA number
--- @param sourceB number
function VoiceService.startCall(callId, sourceA, sourceB)
    adapter().startCall(callId, sourceA, sourceB)
end

--- @param callId number
--- @param sourceA number|nil
--- @param sourceB number|nil
function VoiceService.endCall(callId, sourceA, sourceB)
    adapter().endCall(callId, sourceA, sourceB)
end

return VoiceService
