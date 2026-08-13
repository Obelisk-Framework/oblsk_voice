-- core/modules/oblsk_voice/tests/voice_service_spec.lua
-- Run from the repository root: lua5.4 modules/oblsk_voice/tests/voice_service_spec.lua
local scriptDir = arg[0]:match('(.*/)') or './'
local ROOT = scriptDir .. '..'

dofile(scriptDir .. 'support/fivem_stubs.lua')

Config = dofile(ROOT .. '/shared/config.lua')

dofile(ROOT .. '/server/adapters/NativeAdapter.lua')
dofile(ROOT .. '/server/adapters/PmaAdapter.lua')
dofile(ROOT .. '/server/adapters/YacaAdapter.lua')
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


test('pma adapter proxies proximity/radio/call through pma-voice exports', function()
    Config.provider = 'pma'
    VoiceService.resetAdapterForTests()

    _G.__pmaCalls = {}
    VoiceService.setProximity(1, 12.0)
    VoiceService.joinRadioChannel(1, '155.475')
    VoiceService.startCall(42, 1, 2)
    VoiceService.leaveRadioChannel(1, '155.475')
    VoiceService.endCall(42, 1, 2)

    eq(#_G.__pmaCalls, 7)
    eq(_G.__pmaCalls[1].fn, 'setTalkerProximity')
    eq(_G.__pmaCalls[2].fn, 'setPlayerRadio')
    eq(_G.__pmaCalls[2].args[1], 1)
    eq(_G.__pmaCalls[2].args[2], '155.475')
    eq(_G.__pmaCalls[3].fn, 'setPlayerRadio') -- startCall sourceA
    eq(_G.__pmaCalls[4].fn, 'setPlayerRadio') -- startCall sourceB
    eq(_G.__pmaCalls[5].fn, 'setPlayerRadio') -- leaveRadioChannel
    eq(_G.__pmaCalls[5].args[3], true) -- 3rd arg is "remove"
    eq(_G.__pmaCalls[6].fn, 'setPlayerRadio') -- endCall sourceA
    eq(_G.__pmaCalls[7].fn, 'setPlayerRadio') -- endCall sourceB
end)
test('yaca adapter uses its own radio-channel and phone-call exports', function()
    Config.provider = 'yaca'
    VoiceService.resetAdapterForTests()

    _G.__yacaCalls = {}
    VoiceService.setProximity(1, 12.0)
    VoiceService.leaveRadioChannel(1, '155.475')
    VoiceService.joinRadioChannel(1, '155.475')
    VoiceService.startCall(42, 1, 2)
    VoiceService.endCall(42, 1, 2)

    eq(#_G.__yacaCalls, 5)
    eq(_G.__yacaCalls[1].fn, 'setPlayerVoiceRange')
    eq(_G.__yacaCalls[2].fn, 'setActiveRadioChannel')
    eq(_G.__yacaCalls[2].args[3], false) -- 3rd arg is "leaving"
    eq(_G.__yacaCalls[3].fn, 'setActiveRadioChannel')
    eq(_G.__yacaCalls[3].args[3], true)
    eq(_G.__yacaCalls[4].fn, 'phoneCallStart')
    eq(_G.__yacaCalls[5].fn, 'phoneCallEnd')
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
