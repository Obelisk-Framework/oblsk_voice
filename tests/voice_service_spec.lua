-- core/modules/oblsk_voice/tests/voice_service_spec.lua
-- Run from the repository root: lua5.4 modules/oblsk_voice/tests/voice_service_spec.lua
local scriptDir = arg[0]:match('(.*/)') or './'
local ROOT = scriptDir .. '..'

dofile(scriptDir .. 'support/fivem_stubs.lua')

Config = dofile(ROOT .. '/shared/config.lua')

dofile(ROOT .. '/server/adapters/NativeAdapter.lua')
dofile(ROOT .. '/server/services/VoiceService.lua')

local tests, failures, passed = {}, {}, 0
local function test(name, fn) tests[#tests + 1] = { name = name, fn = fn } end

local function eq(actual, expected, msg)
    if actual ~= expected then
        error(string.format('%s\n     expected: %s\n     actual:   %s',
            msg or 'assertion failed', tostring(expected), tostring(actual)), 2)
    end
end

test('setProximity calls the native talker-proximity native under the native adapter', function()
    Config.provider = 'native'
    VoiceService.resetAdapterForTests()

    _G.__lastProximity = nil
    VoiceService.setProximity(1, 15.0)

    eq(_G.__lastProximity, 15.0)
end)

test('joinRadioChannel/leaveRadioChannel are safe no-ops under the native adapter', function()
    Config.provider = 'native'
    VoiceService.resetAdapterForTests()

    local ok = pcall(VoiceService.joinRadioChannel, 1, '155.475')
    eq(ok, true)
    local ok2 = pcall(VoiceService.leaveRadioChannel, 1, '155.475')
    eq(ok2, true)
end)

test('startCall/endCall are safe no-ops under the native adapter', function()
    Config.provider = 'native'
    VoiceService.resetAdapterForTests()

    local ok = pcall(VoiceService.startCall, 1, 2, 3)
    eq(ok, true)
    local ok2 = pcall(VoiceService.endCall, 1)
    eq(ok2, true)
end)

test('an unknown Config.provider falls back to the native adapter', function()
    Config.provider = 'not-a-real-provider'
    VoiceService.resetAdapterForTests()

    _G.__lastProximity = nil
    VoiceService.setProximity(1, 10.0)

    eq(_G.__lastProximity, 10.0)
end)

for _, t in ipairs(tests) do
    local ok, err = pcall(t.fn)
    if ok then
        passed = passed + 1
    else
        failures[#failures + 1] = { name = t.name, err = err }
    end
end

print(string.format('%d/%d passed', passed, #tests))
for _, f in ipairs(failures) do
    print(string.format('FAIL: %s\n  %s', f.name, f.err))
end
os.exit(#failures == 0 and 0 or 1)
