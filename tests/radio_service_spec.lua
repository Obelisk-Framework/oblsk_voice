-- core/modules/oblsk_voice/tests/radio_service_spec.lua
-- Run from the repository root: lua5.4 modules/oblsk_voice/tests/radio_service_spec.lua
local scriptDir = arg[0]:match('(.*/)') or './'
local ROOT = scriptDir .. '../../..'

dofile(ROOT .. '/tests/support/fivem_stubs.lua')
dofile(ROOT .. '/core/server/ORM/Dialects/Init.lua')
dofile(ROOT .. '/core/server/ORM/Dialects/MySQL.lua')
dofile(ROOT .. '/core/server/ORM/Dialects/Postgres.lua')
dofile(ROOT .. '/core/server/ORM/Database.lua')
dofile(ROOT .. '/core/server/ORM/QueryBuilder.lua')
dofile(scriptDir .. '../server/services/RadioService.lua')

local makeFakeQueryBuilderModule = dofile(ROOT .. '/tests/support/fake_query_builder.lua')

local tests, failures, passed = {}, {}, 0
local function test(name, fn) tests[#tests + 1] = { name = name, fn = fn } end

local function eq(actual, expected, msg)
    if actual ~= expected then
        error(string.format('%s\n     expected: %s\n     actual:   %s',
            msg or 'assertion failed', tostring(expected), tostring(actual)), 2)
    end
end

local function truthy(v, msg)
    if not v then error(msg or 'expected a truthy value', 2) end
end

local function withFakeDb(fn)
    local tables = {}
    local original = QueryBuilder
    QueryBuilder = makeFakeQueryBuilderModule(tables)
    local ok, err = pcall(fn, tables)
    QueryBuilder = original
    if not ok then error(err, 2) end
end

local function withFakeVoice(fn)
    local calls = {}
    local original = VoiceService
    VoiceService = {
        joinRadioChannel = function(source, channelId, slot)
            table.insert(calls, { fn = 'join', source = source, channelId = channelId, slot = slot })
        end,
        leaveRadioChannel = function(source, channelId, slot)
            table.insert(calls, { fn = 'leave', source = source, channelId = channelId, slot = slot })
        end,
    }
    local ok, err = pcall(fn, calls)
    VoiceService = original
    if not ok then error(err, 2) end
end

test('list: returns presets oldest first', function()
    withFakeDb(function()
        local a = RadioService.create(1, { frequency = '155.475', label = 'Dispatch' })
        local b = RadioService.create(1, { frequency = '46.550', label = 'Ops' })

        local presets = RadioService.list(1)
        eq(#presets, 2)
        eq(presets[1].id, a.id)
        eq(presets[2].id, b.id)
    end)
end)

test('list: only returns the requesting character\'s presets', function()
    withFakeDb(function()
        RadioService.create(1, { frequency = '155.475', label = 'mine' })
        RadioService.create(2, { frequency = '400.000', label = 'theirs' })

        local mine = RadioService.list(1)
        eq(#mine, 1)
        eq(mine[1].label, 'mine')
    end)
end)

test('create: inserts and returns the created row', function()
    withFakeDb(function(tables)
        local preset = RadioService.create(1, { frequency = '155.475', label = 'Dispatch' })

        truthy(preset ~= nil, 'expected a returned row')
        eq(preset.character_id, 1)
        eq(preset.frequency, '155.475')
        eq(preset.label, 'Dispatch')
        eq(#tables.radio_presets, 1)
    end)
end)

test('create: a blank or missing frequency is rejected, nothing is inserted', function()
    withFakeDb(function(tables)
        local blank = RadioService.create(1, { frequency = '', label = 'Nope' })
        local missing = RadioService.create(1, { label = 'Also nope' })

        eq(blank, nil)
        eq(missing, nil)
        eq(#(tables.radio_presets or {}), 0)
    end)
end)

test('update: applies to the owning character\'s preset', function()
    withFakeDb(function()
        local preset = RadioService.create(1, { frequency = '155.475', label = 'Old label' })
        RadioService.update(1, preset.id, { label = 'New label' })

        local presets = RadioService.list(1)
        eq(presets[1].label, 'New label')
    end)
end)

test('update: a wrong characterId is a no-op, the row stays unchanged', function()
    withFakeDb(function()
        local preset = RadioService.create(1, { frequency = '155.475', label = 'Old label' })
        RadioService.update(2, preset.id, { label = 'Hijacked' })

        local presets = RadioService.list(1)
        eq(presets[1].label, 'Old label', 'the wrong character\'s update must not apply')
    end)
end)

test('delete: removes the owning character\'s preset', function()
    withFakeDb(function()
        local preset = RadioService.create(1, { frequency = '155.475', label = 'Gone soon' })
        RadioService.delete(1, preset.id)

        eq(#RadioService.list(1), 0)
    end)
end)

test('delete: a wrong characterId is a no-op, the preset survives', function()
    withFakeDb(function()
        local preset = RadioService.create(1, { frequency = '155.475', label = 'Safe' })
        RadioService.delete(2, preset.id)

        local presets = RadioService.list(1)
        eq(#presets, 1)
        eq(presets[1].label, 'Safe')
    end)
end)

test('tune: joins the new frequency on the given slot and records it', function()
    withFakeVoice(function(calls)
        RadioService.tune(1, 10, 'primary', '155.475')

        eq(#calls, 1)
        eq(calls[1].fn, 'join')
        eq(calls[1].source, 1)
        eq(calls[1].channelId, '155.475')
        eq(calls[1].slot, 'primary')

        local tuning = RadioService.getTuning(10)
        eq(tuning.primary.frequency, '155.475')
        eq(tuning.primary.muted, false)
    end)
end)

test('tune: retuning a slot leaves the old frequency before joining the new one', function()
    withFakeVoice(function(calls)
        RadioService.tune(1, 20, 'primary', '155.475')
        RadioService.tune(1, 20, 'primary', '46.550')

        eq(#calls, 3)
        eq(calls[2].fn, 'leave')
        eq(calls[2].channelId, '155.475')
        eq(calls[2].slot, 'primary')
        eq(calls[3].fn, 'join')
        eq(calls[3].channelId, '46.550')

        eq(RadioService.getTuning(20).primary.frequency, '46.550')
    end)
end)

test('tune: primary and secondary are independent slots', function()
    withFakeVoice(function()
        RadioService.tune(1, 30, 'primary', '155.475')
        RadioService.tune(1, 30, 'secondary', '46.550')

        local tuning = RadioService.getTuning(30)
        eq(tuning.primary.frequency, '155.475')
        eq(tuning.secondary.frequency, '46.550')
    end)
end)

test('untune: leaves the channel and clears that slot', function()
    withFakeVoice(function(calls)
        RadioService.tune(1, 40, 'primary', '155.475')
        RadioService.untune(1, 40, 'primary')

        eq(calls[2].fn, 'leave')
        eq(calls[2].channelId, '155.475')
        eq(RadioService.getTuning(40).primary, nil)
    end)
end)

test('getTuning: an untouched character has no tuning for either slot', function()
    eq(RadioService.getTuning(999).primary, nil)
    eq(RadioService.getTuning(999).secondary, nil)
end)

print('\nRunning RadioService (presets) unit tests\n')
for _, t in ipairs(tests) do
    local ok, err = pcall(t.fn)
    if ok then
        passed = passed + 1
        print('  ok   - ' .. t.name)
    else
        failures[#failures + 1] = t.name
        print('  FAIL - ' .. t.name)
        print('         ' .. tostring(err):gsub('\n', '\n         '))
    end
end

print(string.format('\n%d passed, %d failed', passed, #failures))
os.exit(#failures == 0 and 0 or 1)
