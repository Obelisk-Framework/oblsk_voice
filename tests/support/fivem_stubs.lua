-- core/modules/oblsk_voice/tests/support/fivem_stubs.lua
-- Minimal stand-ins for the FiveM natives/globals VoiceService and its
-- adapters touch, so these specs run under plain lua5.4 with no game
-- runtime. Real natives are game-provided globals in FXServer; here they're
-- plain functions that record what they were called with.
function NetworkSetTalkerProximity(range)
    _G.__lastProximity = range
end

--- VoiceService self-loads its own shared/config.lua through these two
--- natives (see VoiceService.loadOwnConfig) rather than reading the shared
--- global Config, so the harness has to provide them. The spec sets
--- _G.__TEST_RESOURCE_ROOT to the module root before loading VoiceService;
--- resource-relative paths ('modules/oblsk_voice/shared/config.lua') are
--- rebased onto it so the self-load reads the real file from disk.
function GetCurrentResourceName()
    return 'obelisk'
end

function LoadResourceFile(_, path)
    local relative = path:match('oblsk_voice/(.*)$') or path
    local file = io.open((_G.__TEST_RESOURCE_ROOT or '.') .. '/' .. relative, 'r')
    if not file then return nil end
    local content = file:read('*a')
    file:close()
    return content
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
