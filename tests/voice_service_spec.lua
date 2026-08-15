-- core/modules/oblsk_voice/tests/voice_service_spec.lua
-- Run from the repository root: lua5.4 modules/oblsk_voice/tests/voice_service_spec.lua
local scriptDir = arg[0]:match('(.*/)') or './'
local ROOT = scriptDir .. '..'

_G.__TEST_RESOURCE_ROOT = ROOT
dofile(scriptDir .. 'support/fivem_stubs.lua')

-- Deliberately hostile: this is what the shared global Config looks like when
-- some OTHER plugin's shared/config.lua loaded last into the one Lua global
-- environment core/fxmanifest.lua globs everything into. Nothing in
-- VoiceService may read it - it self-loads modules/oblsk_voice/shared/config.lua
-- instead. Set BEFORE VoiceService.lua loads, so the load-time path is covered.
Config = { provider = 'saltychat', booths = {}, secondsPerBill = 60 }

dofile(ROOT .. '/server/adapters/NativeAdapter.lua')
dofile(ROOT .. '/server/adapters/PmaAdapter.lua')
dofile(ROOT .. '/server/adapters/YacaAdapter.lua')
dofile(ROOT .. '/server/adapters/SaltychatAdapter.lua')
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
    VoiceService.setConfigForTests({ provider = 'native' })

    _G.__lastProximity = nil
    VoiceService.setProximity(1, 15.0)

    eq(_G.__lastProximity, 15.0)
end)

test('joinRadioChannel/leaveRadioChannel are safe no-ops under the native adapter', function()
    VoiceService.setConfigForTests({ provider = 'native' })

    local ok = pcall(VoiceService.joinRadioChannel, 1, '155.475')
    eq(ok, true)
    local ok2 = pcall(VoiceService.leaveRadioChannel, 1, '155.475')
    eq(ok2, true)
end)

test('startCall/endCall are safe no-ops under the native adapter', function()
    VoiceService.setConfigForTests({ provider = 'native' })

    local ok = pcall(VoiceService.startCall, 1, 2, 3)
    eq(ok, true)
    local ok2 = pcall(VoiceService.endCall, 1)
    eq(ok2, true)
end)

test('an unknown Config.provider falls back to the native adapter', function()
    VoiceService.setConfigForTests({ provider = 'not-a-real-provider' })

    _G.__lastProximity = nil
    VoiceService.setProximity(1, 10.0)

    eq(_G.__lastProximity, 10.0)
end)


test('pma adapter proxies proximity/radio/call through pma-voice exports', function()
    VoiceService.setConfigForTests({ provider = 'pma' })

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
    VoiceService.setConfigForTests({ provider = 'yaca' })

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


test('saltychat adapter uses SetPlayerVoiceRange/SetPlayerRadioChannel/SetPhoneSpeaker exports', function()
    VoiceService.setConfigForTests({ provider = 'saltychat' })

    _G.__saltyCalls = {}
    VoiceService.setProximity(1, 12.0)
    VoiceService.joinRadioChannel(1, '155.475')
    VoiceService.leaveRadioChannel(1, '155.475')
    VoiceService.startCall(42, 1, 2)
    VoiceService.endCall(42, 1, 2)

    -- Total 11 calls: setProximity (1) + joinRadioChannel (1) + leaveRadioChannel (1)
    --                + startCall (4: 2x SetPlayerRadioChannel + 2x SetPhoneSpeaker)
    --                + endCall (4: 2x SetPlayerRadioChannel + 2x SetPhoneSpeaker)
    eq(#_G.__saltyCalls, 11)
    eq(_G.__saltyCalls[1].fn, 'SetPlayerVoiceRange')
    eq(_G.__saltyCalls[1].args[2], 12.0) -- 2nd arg is range

    eq(_G.__saltyCalls[2].fn, 'SetPlayerRadioChannel')
    eq(_G.__saltyCalls[2].args[2], '155.475') -- 2nd arg is channel
    eq(_G.__saltyCalls[2].args[3], true) -- 3rd arg is "primary"

    eq(_G.__saltyCalls[3].fn, 'SetPlayerRadioChannel')
    eq(_G.__saltyCalls[3].args[2], '') -- 2nd arg is empty channel name = leave

    -- startCall for callId 42 puts both sources in 'call-42' channel
    eq(_G.__saltyCalls[4].fn, 'SetPlayerRadioChannel')
    eq(_G.__saltyCalls[4].args[2], 'call-42') -- sourceA joins call channel
    eq(_G.__saltyCalls[5].fn, 'SetPlayerRadioChannel')
    eq(_G.__saltyCalls[5].args[2], 'call-42') -- sourceB joins call channel

    eq(_G.__saltyCalls[6].fn, 'SetPhoneSpeaker')
    eq(_G.__saltyCalls[6].args[2], true) -- sourceA phone speaker on
    eq(_G.__saltyCalls[7].fn, 'SetPhoneSpeaker')
    eq(_G.__saltyCalls[7].args[2], true) -- sourceB phone speaker on

    -- endCall leaves both sources from call channel and turns off speaker
    eq(_G.__saltyCalls[8].fn, 'SetPlayerRadioChannel')
    eq(_G.__saltyCalls[8].args[2], '') -- sourceA leaves call channel
    eq(_G.__saltyCalls[9].fn, 'SetPhoneSpeaker')
    eq(_G.__saltyCalls[9].args[2], false) -- sourceA phone speaker off

    eq(_G.__saltyCalls[10].fn, 'SetPlayerRadioChannel')
    eq(_G.__saltyCalls[10].args[2], '') -- sourceB leaves call channel
    eq(_G.__saltyCalls[11].fn, 'SetPhoneSpeaker')
    eq(_G.__saltyCalls[11].args[2], false) -- sourceB phone speaker off
end)

test('saltychat adapter maps slot to the isPrimary flag on both join and leave', function()
    VoiceService.setConfigForTests({ provider = 'saltychat' })

    _G.__saltyCalls = {}
    VoiceService.joinRadioChannel(1, '155.475', 'primary')
    VoiceService.joinRadioChannel(1, '46.550', 'secondary')
    VoiceService.leaveRadioChannel(1, '155.475', 'primary')
    VoiceService.leaveRadioChannel(1, '46.550', 'secondary')

    eq(#_G.__saltyCalls, 4)
    eq(_G.__saltyCalls[1].args[2], '155.475')
    eq(_G.__saltyCalls[1].args[3], true) -- primary -> isPrimary true
    eq(_G.__saltyCalls[2].args[2], '46.550')
    eq(_G.__saltyCalls[2].args[3], false) -- secondary -> isPrimary false
    eq(_G.__saltyCalls[3].args[3], true) -- leave primary keeps isPrimary true
    eq(_G.__saltyCalls[4].args[3], false) -- leave secondary keeps isPrimary false
end)

test('joinRadioChannel/leaveRadioChannel default slot to primary when omitted', function()
    VoiceService.setConfigForTests({ provider = 'saltychat' })

    _G.__saltyCalls = {}
    VoiceService.joinRadioChannel(1, '155.475')

    eq(_G.__saltyCalls[1].args[3], true)
end)

test('yaca adapter forwards slot as the 4th setActiveRadioChannel argument', function()
    VoiceService.setConfigForTests({ provider = 'yaca' })

    _G.__yacaCalls = {}
    VoiceService.joinRadioChannel(1, '155.475', 'primary')
    VoiceService.joinRadioChannel(1, '46.550', 'secondary')

    eq(_G.__yacaCalls[1].args[4], 'primary')
    eq(_G.__yacaCalls[2].args[4], 'secondary')
end)

test('pma adapter maps slot to pma-voice long/short radioType', function()
    VoiceService.setConfigForTests({ provider = 'pma' })

    _G.__pmaCalls = {}
    VoiceService.joinRadioChannel(1, '155.475', 'primary')
    VoiceService.joinRadioChannel(1, '46.550', 'secondary')

    eq(_G.__pmaCalls[1].args[4], 'long')
    eq(_G.__pmaCalls[2].args[4], 'short')
end)

test('native adapter ignores slot, still a safe no-op', function()
    VoiceService.setConfigForTests({ provider = 'native' })

    local ok = pcall(VoiceService.joinRadioChannel, 1, '155.475', 'secondary')
    eq(ok, true)
end)

test('VoiceService ignores a colliding shared global Config from another plugin', function()
    -- The global Config at the top of this file claims provider 'saltychat'.
    -- Reloading from disk must yield oblsk_voice's own default ('native'),
    -- proving no production path reads the shared global.
    eq(Config.provider, 'saltychat')
    VoiceService.setConfigForTests(nil) -- nil = re-read shared/config.lua from disk

    _G.__saltyCalls = {}
    _G.__lastProximity = nil
    VoiceService.setProximity(1, 9.0)

    eq(_G.__lastProximity, 9.0, 'expected the native adapter, not the global Config\'s saltychat')
    eq(#_G.__saltyCalls, 0, 'the colliding global Config must not reach VoiceService')
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
