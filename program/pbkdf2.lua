local utils = require "utils"
local crypto = require "crypto"
local hmac = require "hmac_sha256"

local pbkdf2 = {}

---Xor two strings, if str2 is longer than str1 the remaining bytes are ignored
---@param str1 string
---@param str2 string
local function xor_strings(str1, str2)
    local result = {}
    for i = 1, #str1 do
        result[i] = bit32.bxor(str1:byte(i), str2:byte(i))
    end

    return table.concat(result)
end

function pbkdf2.derive(password, salt, iterations)
    local U = hmac.sign(password, salt.."\0\0\0\1")
    local T = U
    for i = 1, iterations-1 do
        U = hmac.sign(password, U)
        T = xor_strings(T, U)

        utils.yield(1000, i)
    end

    return T
end

-- function pbkdf2.speed_test(pass, s)
--     local start = os.epoch("utc")
--     local count = 0

--     local U = hmac.sign(pass, s .. "\0\0\0\1")
--     local T = U
--     while os.epoch("utc") - start < 1000 do
--         for i = 1, 100 do
--             U = hmac.sign(pass, U)
--             T = xor_strings(T, U)
--         end
--         count = count + 100
--     end
--     print("Iterations per second: " .. count)
-- end
-- 
-- Result: 500 iterations/second

return pbkdf2
