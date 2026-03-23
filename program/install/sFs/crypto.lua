local chacha20 = require("chacha20")
local utils = require("utils")
local sha256= require("sha256")

local crypto = {}

local state = {
    pool_key = nil,
    pool_key_gen_time = 0,
    counter = 0
}

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
    if state.pool_key == nil or os.epoch("utc") - state.pool_key_gen_time > 600000 then
        if settings.get("crypto.use_random_org", false) then
            state.pool_key = get_secure_bytes(32)
            state.pool_key_gen_time = os.epoch("utc")
        end

        if state.pool_key == nil then
            local entropy = tostring(os.epoch("utc")) ..
                            tostring(math.random(1, 0xfffffff)) ..
                            shell.getRunningProgram() ..
                            tostring(os.clock()) ..
                            tostring(os.computerID())
            state.pool_key = sha256.hash(entropy)
        end
    end

    local random = chacha20.crypt(("\0"):rep(length), state.pool_key, "CSPRNG_NONCE", state.counter)
    state.counter = state.counter + 1

    return random
end

return crypto