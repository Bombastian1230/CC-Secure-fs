local utils = require "sFs.utils"
local hmac = require "sFs.hmac_sha256"

local pbkdf2 = {}

---Xor two strings, if str2 is longer than str1 the remaining bytes are ignored
---@param str1 string
---@param str2 string
local function xor_strings(str1, str2)
    local result = {}
    for i = 1, #str1 do
        result[i] = string.char(bit32.bxor(str1:byte(i), str2:byte(i)))
    end

    return table.concat(result)
end

---Derive an encryption key from a password
---@param password string The password
---@param salt string The salt
---@param iterations integer How many iterations do do
---@param progress_message string The progress message to display before the procentage and progress bar
---@return string
function pbkdf2.derive(password, salt, iterations, progress_message)
    local U = hmac.sign(password, salt .. "\0\0\0\1")
    local T = U

    local startX, startY = term.getCursorPos()

    local progress_update = string.format("%s ", progress_message)

    local bar_width = select(1, term.getSize()) - #progress_update - 2
    
    term.write(progress_update)
    local bar_x, bar_y = term.getCursorPos()
    utils.draw_inline_bar(bar_x, bar_y, 0, iterations - 1, bar_width)

    for i = 1, iterations - 1 do
        U = hmac.sign(password, U)
        T = xor_strings(T, U)

        utils.yield(500, i)

        if i % 500 == 0 or i == iterations - 1 then
            term.setCursorPos(startX, startY)
            term.clearLine()
            term.write(progress_update)
            utils.draw_inline_bar(bar_x, bar_y, i, iterations - 1, bar_width)
        end
    end

    return T
end

-- Speed: 2 ms/iteration

return pbkdf2
