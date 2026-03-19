local chacha20 = require("chacha20")
local utils = require("utils")

local crypto = {}

if not _G.__CRYPTO_STATE then
    _G.__CRYPTO_STATE = {
        pool_key = nil,
        pool_key_gen_time = 0,
        counter = 0
    }
end

local state = _G.__CRYPTO_STATE

---Use random.org to generate a secure bytestring
---@param count any
---@return string|nil
---@return string|nil
local function get_secure_bytes(count)
    local url = string.format("https://www.random.org/cgi-bin/randbyte?nbytes=%d&format=h", count)
    
    local response = http.get(url)
    if not response then
        return nil, "Connection failed"
    end

    local hex = response.readAll():gsub("%s+", "")
    response.close()

    return utils.string_from_hex(hex)
end

---Generate a cryptograficly secure number
---@param length integer How many bytes (characters) long the string should be
function crypto.random_bytes(length)
    if settings.get("crypto.use_random_org", false) then
        if state.pool_key == nil or os.epoch("utc") - state.pool_key_gen_time > 600000 then
            local new_key = get_secure_bytes(32)
            state.pool_key = new_key 
            if state.pool_key == nil then goto failsafe end

            state.pool_key_gen_time = os.epoch("utc")
        end
        
        local random = chacha20.crypt(("\0"):rep(length), state.pool_key, "CSPRNG_NONCE", state.counter)
        state.counter = state.counter + 1

        return random
    end

    ::failsafe::
    -- TODO: a backup prng
    error("Couldn't generate number")
end

return crypto