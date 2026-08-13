-- core/modules/oblsk_voice/tests/support/fivem_stubs.lua
-- Minimal stand-ins for the FiveM natives/globals VoiceService and its
-- adapters touch, so these specs run under plain lua5.4 with no game
-- runtime. Real natives are game-provided globals in FXServer; here they're
-- plain functions that record what they were called with.
function NetworkSetTalkerProximity(range)
    _G.__lastProximity = range
end

_G.exports = setmetatable({}, {
    __index = function()
        return setmetatable({}, {
            __call = function() return nil end,
        })
    end,
})
