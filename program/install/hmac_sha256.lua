local sha256 = require "sha256"
local utils = require "utils"

local hmac_sha256 = {}

local B = 64

local ipad = 0x36
local opad = 0x5c

---Prepares a key by hashing and/or padding it with zeros
---@param key string
local function key_prep(key)
    if #key > B then
        key = utils.string_from_hex(sha256.hash(key))
    end

    local pad_by = B - #key
    key = key .. string.rep("\0", pad_by)

    return { string.byte(key, 1, #key) }
end

---Takes a key and a message and HMAC-SHA256 signs it
---@param s_key string
---@param message string
function hmac_sha256.sign(s_key, message)
    local key = key_prep(s_key)
    
    local S_i = {}
    local S_o = {}

    for i = 1, #key do
        S_i[i] = string.char(bit32.bxor(key[i], ipad))
        S_o[i] = string.char(bit32.bxor(key[i], opad))
    end

    local inner_data = table.concat(S_i) .. message
    local inner_hash = utils.string_from_hex(sha256.hash(inner_data))

    local outer_data = table.concat(S_o) .. inner_hash
    return utils.string_from_hex(sha256.hash(outer_data))
end

return hmac_sha256