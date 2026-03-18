local utils = {}

---Create a shallow copy of a table1
---@param table1 table
---@return table
function utils.copy_table(table1)
    local table2 = {}
    for key, value in pairs(table1) do
        table2[key] = value
    end
    return table2
end

---Takes arbitrary number of numbers and adds them in mod 32
---@param ... number
---@return number
function utils.add32(...)
    local sum = 0
    local args = { ... }
    for _, number in ipairs(args) do
        sum = bit32.band((sum + number), 0xffffffff)
    end

    return sum
end

---Convert a string in to a integer based on its bytes, taken from (https://stackoverflow.com/questions/5241799/lua-dealing-with-non-ascii-byte-streams-byteorder-change)
---@param str string
---@param endian "big"|"little"
---@param signed boolean
---@return integer
function utils.bytes_to_int(str, endian, signed)
    local t = { str:byte(1, -1) }
    if endian == "big" then --reverse bytes
        local tt = {}
        for k = 1, #t do
            tt[#t - k + 1] = t[k]
        end
        t = tt
    end
    local n = 0
    for k = 1, #t do
        n = n + t[k] * 2 ^ ((k - 1) * 8)
    end
    if signed then
        n = (n > 2 ^ (#t * 8 - 1) - 1) and (n - 2 ^ (#t * 8)) or n -- if last bit set, negative.
    end
    return n
end

---Convert a 32 bit integer to a list of integers 0-255 (bytes)
---@param num integer
---@return table
function utils.bytes_from_int32(num)
    return { bit32.extract(num, 0, 8), bit32.extract(num, 8, 8), bit32.extract(num, 16, 8), bit32.extract(num, 24, 8) }
end

---Convert an integer into a hex string padded by "pad" using 0s
---@param num number
---@param pad integer
---@return string
function utils.int_to_hex(num, pad)
    local format = string.format("%%0%dx", pad)
    return string.format(format, num)
end

function utils.print_table_as_hex(raw_table, pad)
    local print_table = {}
    for _, value in ipairs(raw_table) do
        table.insert(print_table, utils.int_to_hex(value, pad))
    end
    textutils.pagedTabulate(print_table)
end

---The same as os.pullEvent exept it doesn't stop on terminate events
---@param event? string The event filter
---@return string event The event name of the returned event
---@return ...
function utils.pullEventOverride(event)
    repeat
        ---@diagnostic disable-next-line: lowercase-global
        event_new, data = os.pullEventRaw(event)
    until event_new ~= "terminate"

    return event_new, data
end

---Convert a string into a string of 2 digit hex numbers, usefull for saving encrypted data in filenames
---@param str string
---@return string
function utils.hex_from_string(str)
    local hex = {}
    for i = 1, #str do
        hex[i] = string.format("%02x", string.byte(str, i))
    end

    return table.concat(hex)
end

---Convert a hex string into a string of characters
---@param hex any
---@return string
function utils.string_from_hex(hex)
    local str = {}

    for i = 1, #hex, 2 do
        table.insert(str, string.char(tonumber(string.sub(hex, i, i + 1), 16) --[[@as integer]]))
    end

    return table.concat(str)
end

---Split a string at char
---@param str string
---@param char string
---@return table
function utils.split_by_char(str, char)
    local split = {}

    for sub_str in string.gmatch(str, char) do
        table.insert(split, sub_str)
    end

    return split
end

return utils
