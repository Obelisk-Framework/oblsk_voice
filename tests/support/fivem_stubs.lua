-- core/modules/oblsk_voice/tests/support/fivem_stubs.lua
-- Minimal stand-ins for the FiveM natives/globals VoiceService and its
-- adapters touch, so these specs run under plain lua5.4 with no game
-- runtime. Real natives are game-provided globals in FXServer; here they're
-- plain functions that record what they were called with.
function NetworkSetTalkerProximity(range)
    _G.__lastProximity = range
end

local function record(bucket)
    return function(_, fn)
        return function(self, ...)
            local args = { ... }
            _G[bucket] = _G[bucket] or {}
            table.insert(_G[bucket], { fn = fn, args = args })
        end
    end
end

_G.exports = setmetatable({}, {
    __index = function(_, resourceName)
        local bucket = resourceName == 'pma-voice' and '__pmaCalls'
            or resourceName == 'yaca-voice' and '__yacaCalls'
            or resourceName == 'saltychat' and '__saltyCalls'
            or '__unknownVoiceCalls'
        return setmetatable({}, { __index = record(bucket) })
    end,
})
