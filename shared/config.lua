-- core/modules/oblsk_voice/shared/config.lua
Config = {}

Config.Debug = false

-- Which VoiceAdapter backs VoiceService. 'native' is the safe default: real
-- proximity via the bare game native, radio/calls degrade to no-op (no
-- audio, but nothing crashes or blocks) when no voice resource is running.
-- See docs/superpowers/specs/2026-08-13-phone-booth-and-voice-service-design.md §A.
Config.provider = 'native' -- 'native' | 'pma' | 'yaca' | 'saltychat'

return Config
