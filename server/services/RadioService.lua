--- RadioService (oblsk_voice) - per-character saved radio-frequency presets
--- and current channel tuning. Relocated from oblsk_phone (which owned this
--- as a phone-app-only feature) so both oblsk_phone's Radio app and
--- oblsk_radio's handheld HUD share one character's radio state instead of
--- each keeping their own. See
--- docs/superpowers/specs/2026-08-15-radio-plugin-design.md.
---
--- Every mutation is scoped to the calling character's own rows; a
--- presetId that doesn't belong to that character is silently ignored
--- rather than trusted, since it always arrives from the client.
RadioService = {}

--- @param characterId number
--- @return table[] this character's saved presets, oldest first
function RadioService.list(characterId)
    return QueryBuilder.new('radio_presets')
        :where('character_id', characterId)
        :orderBy('id', 'asc')
        :getSync()
end

--- @param characterId number
--- @param attributes table { frequency, label }
--- @return table|nil the created row, or nil if frequency is missing/blank
function RadioService.create(characterId, attributes)
    local frequency = attributes and attributes.frequency
    if type(frequency) ~= 'string' or frequency == '' then
        return nil
    end

    local id = QueryBuilder.new('radio_presets'):insert({
        character_id = characterId,
        frequency = frequency,
        label = attributes.label,
        created_at = Database.now(),
        updated_at = Database.now(),
    })

    return QueryBuilder.new('radio_presets'):where('id', id):firstSync()
end

--- Partial update, no-op if this preset does not belong to characterId.
--- @param characterId number
--- @param presetId number
--- @param attributes table any subset of { frequency, label }
function RadioService.update(characterId, presetId, attributes)
    local owned = QueryBuilder.new('radio_presets')
        :where('id', presetId):where('character_id', characterId):firstSync()
    if not owned then
        return
    end

    local changes = { updated_at = Database.now() }
    if attributes.frequency ~= nil then changes.frequency = attributes.frequency end
    if attributes.label ~= nil then changes.label = attributes.label end

    QueryBuilder.new('radio_presets')
        :where('id', presetId):where('character_id', characterId):update(changes)
end

--- No-op if this preset does not belong to characterId.
--- @param characterId number
--- @param presetId number
function RadioService.delete(characterId, presetId)
    local owned = QueryBuilder.new('radio_presets')
        :where('id', presetId):where('character_id', characterId):firstSync()
    if not owned then
        return
    end

    QueryBuilder.new('radio_presets')
        :where('id', presetId):where('character_id', characterId):delete()
end

--- In-memory per-character tuning state. Ephemeral - cleared implicitly on
--- server restart, and callers are expected to untune on disconnect (see
--- oblsk_phone/server/main.lua and oblsk_radio/server/main.lua). Never
--- persisted: only the saved presets above are real, durable state.
local tuning = {} -- characterId -> { primary = {frequency, muted}|nil, secondary = {...}|nil }

--- @param characterId number
--- @return table { primary = {frequency, muted}|nil, secondary = {...}|nil }
function RadioService.getTuning(characterId)
    return tuning[characterId] or {}
end

--- Leaves the old frequency on this slot (if any), joins the new one, and
--- records it. @param source number @param characterId number
--- @param slot string 'primary'|'secondary' @param frequency string
function RadioService.tune(source, characterId, slot, frequency)
    local state = tuning[characterId] or {}
    tuning[characterId] = state

    local current = state[slot]
    if current then
        VoiceService.leaveRadioChannel(source, current.frequency, slot)
    end

    VoiceService.joinRadioChannel(source, frequency, slot)
    state[slot] = { frequency = frequency, muted = false }
end

--- @param source number @param characterId number @param slot string
function RadioService.untune(source, characterId, slot)
    local state = tuning[characterId]
    local current = state and state[slot]
    if not current then
        return
    end

    VoiceService.leaveRadioChannel(source, current.frequency, slot)
    state[slot] = nil
end

return RadioService
