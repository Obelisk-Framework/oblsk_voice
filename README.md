# oblsk_voice

Provider-agnostic voice module. `VoiceService` is the only thing any other
plugin calls; it resolves to whichever `VoiceAdapter` this module's
`shared/config.lua` `Config.provider` names. See
`docs/superpowers/specs/2026-08-13-phone-booth-and-voice-service-design.md`.

## Configuring a provider

`shared/config.lua`:

```lua
Config.provider = 'native' -- 'native' | 'pma' | 'yaca' | 'saltychat'
```

| `Config.provider` | Backing FiveM resource that must be running | Proximity | Radio channels | Calls |
| --- | --- | --- | --- | --- |
| `native` (default) | none | yes (game native) | no-op | no-op |
| `pma` | `pma-voice` | yes | yes | yes (as a radio channel) |
| `yaca` | `yaca-voice` | yes | yes | yes (phone-call exports) |
| `saltychat` | `saltychat` | yes | yes | yes (radio channel + phone speaker) |

`native` is always safe: it has **zero external dependencies**, gives real
proximity voice through the bare game native, and degrades radio and calls to
silent no-ops — no audio, but nothing errors, blocks, or crashes. Leave it as
the default unless you have actually installed one of the voice resources
above.

### Caveat on the non-native adapters

The resource names and export signatures the `pma`, `yaca` and `saltychat`
adapters call are **best effort, taken from each project's current upstream
documentation, and have NOT been verified against a live install** by this
repo. Before you rely on one of them in production, check the export names
and argument order against the version of that resource you are actually
running (`server/adapters/PmaAdapter.lua`, `YacaAdapter.lua`,
`SaltychatAdapter.lua` — each is a handful of lines and easy to correct). If
an export name is wrong, the symptom is a runtime error from the voice
resource, not a silent failure.

There is also a known open design question with the non-native providers that
model voice as a *single* primary channel (SaltyChat in particular): a player
on a radio channel who then takes a call can only be in one of them at a
time. This is not resolved yet — see the design doc.

## Config isolation

`server/services/VoiceService.lua` reads its own `shared/config.lua` through
`LoadResourceFile` + `load(..., 't', {})` in an isolated environment rather
than the bare global `Config`. This is deliberate: `core/fxmanifest.lua` globs
every core/module/plugin shared script into one FXServer resource, so all of
them share a single Lua global environment and the last `Config = {}` to load
wins. Do not "simplify" this back to reading the global.
