# oblsk_voice

Provider-agnostic voice module. `VoiceService` is the only thing any other
plugin calls; it resolves to whichever `VoiceAdapter` `Config.provider`
names (`native` | `pma` | `yaca` | `saltychat`). See
`docs/superpowers/specs/2026-08-13-phone-booth-and-voice-service-design.md`.
