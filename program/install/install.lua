local cc_strings = require("cc.strings")
local utils      = require("sFs.utils")
local crypto     = require("sFs.crypto")
local pbkdf2     = require("sFs.pbkdf2")

term.clear()
term.setCursorPos(1, 1)
term.setCursorBlink(false)

local width, height = term.getSize()

print([[
      ______     _           _        _ _
     |  ____|   (_)         | |      | | |
  ___| |__ ___   _ _ __  ___| |_ __ _| | |
 / __|  __/ __| | | '_ \/ __| __/ _` | | |
 \__ \ |  \__ \ | | | | \__ \ || (_| | | |
 |___/_|  |___/ |_|_| |_|___/\__\__,_|_|_|
]])

local width, height = term.getSize()

local header = string.rep("-", math.ceil((width - 13) / 2)) ..
    " PLEASE READ " .. string.rep("-", math.floor((width - 13) / 2))
local instructions = cc_strings.wrap(
    "There are detailed installation instructions and technical details in the book you got with the install disk.\nEvery step and choice in this installation is explained in detail in the book, every step is also labeled with its relevant page number.")

local _, header_line = term.getCursorPos()
term.setTextColor(colors.lime)
print(header)

term.setTextColor(colors.yellow)
for _, line in ipairs(instructions) do
    print(line)
end

term.setTextColor(colors.white)
write("\nPress enter to begin install")

repeat
    local event, key = os.pullEvent("key")
until key == keys["enter"]

local win = window.create(term.current(), 1, height - 3, width, 4)
---Prompt a user for input
---@param question string
---@param error? string
---@param blit_fg? string A blit string
---@param blit_bg? string A blit string
---@return string
local function ask(question, error, blit_fg, blit_bg)
    if not blit_fg then blit_fg = string.rep("0", #question) end
    if not blit_bg then blit_bg = string.rep("f", #question) end

    local oldTerm = term.redirect(win)
    win.clear()
    win.setCursorPos(1, 1)

    if error then
        win.setTextColor(colors.red)
        print(error)
        win.setTextColor(colors.white)
    end


    local question_lines = cc_strings.wrap(question)
    local blit_index = 1
    for i = 1, #question_lines do
        local fg_blit_chunk, bg_blit_chunk = blit_fg:sub(blit_index, blit_index + #question_lines[i] - 1),
            blit_bg:sub(blit_index, blit_index + #question_lines[i] - 1)
        term.blit(question_lines[i], fg_blit_chunk, bg_blit_chunk)
        print()

        blit_index = blit_index + #question_lines[i]
    end

    write("> ")

    local answer = read()
    term.redirect(oldTerm)

    return answer
end

----- Prompt the user for selections -----
local valid_answers = {
    Y = true,
    y = true,
    N = true,
    n = true
}

-- Ask user for a password
::redo_pass::
local password = ""
local err
while true do
    password = ask("Enter a password (min 8 characters), p.5", err, "0000000000000000022222222222222222222444")

    if #password < 8 then
        err = "Password must be at least 8 characters long"
    else
        break
    end
end


-- Double check that the user entered the password correctly
local prompt = string.format("This computers password will be: %s, Is this correct? (Y/n)", password)
local blit_fg = "000000000000000000000000000000000" .. string.rep("9", #password) .. "000000000000000000222222"
local agree = ""
local err
while true do
    agree = ask(prompt, err, blit_fg)

    if not valid_answers[agree] then
        err = agree .. " is not a valid response"
    else
        break
    end
end

if agree:lower() == "n" then
    goto redo_pass
end

-- How many iterations?
local prompt =  "Security level? p.5 (1:Normal 2:Strong  3:Very Strong)"
local blit_fg = "000000000000000044442222222222222222222222222222222222"
local iterations, err
while true do
    local response = ask(prompt, err, blit_fg):lower()

    if response == "1" or response == "normal" then
        iterations = 10000
    elseif response == "2" or response == "strong" then
        iterations = 50000
    elseif response == "3" or response == "very strong" then
        iterations = 100000
    else
        err = "Not a valid selection"
    end

    if iterations then
        local prompt = string.format("Security level %s takes about %d seconds to verify your password, are you sure? (Y/n)", response, (iterations * 2) / 1000)
        local blit_fg =              "000000000000000" .. string.rep("3", #response) .. "0000000000000" ..  string.rep("3", #tostring((iterations * 2) / 1000)) .. "00000000000000000000000000000000000000000000000022222"
        local err
        while true do
            local response = ask(prompt, err, blit_fg)

            if not valid_answers[response] then
                err = response .. " is not a valid response"
            else
                if response:lower() == "y" then
                    break
                else
                    iterations = nil
                    break
                end
            end
        end

        if iterations then break end
    end
end

-- Enable auto login
local prompt = "Enable auto login? p.6 (Y/n)"
local blit_fg = "0000000000000000000444422222"
local auto_login = false
local err
while true do
    local response = ask(prompt, err, blit_fg)

    if not valid_answers[response] then
        err = response .. " is not a valid response"
    else
        if response:lower() == "y" then auto_login = true end
        break
    end
end

-- Eneable auto logout
local auto_logout = false
if term.isColor() then
    local prompt = "Enable auto logout? p.6 (Y/n)"
    local blit_fg = "00000000000000000000444422222"
    local err
    while true do
        local response = ask(prompt, err, blit_fg)

        if not valid_answers[agree] then
            err = agree .. " is not a valid response"
        else
            if response:lower() == "y" then auto_logout = true end
            break
        end
    end
end

-- Use random.org for random numbers
local prompt = "Use random.org for random numbers? p.7 (Y/n)"
local blit_fg = "00000000000000000000000000000000000444422222"
local allow_random = false
local err
while true do
    local response = ask(prompt, err, blit_fg)

    if not valid_answers[agree] then
        err = agree .. " is not a valid response"
    else
        if response:lower() == "y" then allow_random = true end
        break
    end
end

-- Last warning
local prompt =
"DO NOT SHUTDOWN COMPUTER UNTIL YOU SEE THE NORMAL SHELL. DO YOU UNDERSTAND? (type \"YES\" to procced type \"no\" to cancel install) p.8"
local blit_fg =
"111111111111111111111111111111111111111111111111111111111111111111111111111122222225552222222222222222222ee222222222222222222224444"
local understand = ""
local err
while true do
    understand = ask(prompt, err, blit_fg)

    if understand == "YES" then
        break
    elseif understand == "no" then
        os.reboot()
    else
        err = "Invalid selection, type YES or no"
    end
end

-- Set settings
settings.define("crypto.use_random_org",
    { description = "Whether or not to use random.org for CSPRNG initilizing", type = "boolean", default = true })
settings.set("crypto.use_random_org", allow_random)

-- Start accually initilizing everything
local header = string.rep("-", math.ceil((width - 26) / 2)) ..
    " DO NOT SHUTDOWN COMPUTER " .. string.rep("-", math.floor((width - 26) / 2))

term.setCursorPos(1, header_line - 1)
term.setTextColor(colors.orange)
print(header)
term.setTextColor(colors.white)

win.clear()
win.reposition(1, header_line, width, height - header_line)

local wind_width, win_height = win.getSize()
local oldTerm = term.redirect(win)

fs.makeDir("sFs")

-- Create the encryption key
term.setCursorPos(1, win_height)
term.write("Generating base key")
term.setCursorPos(1, win_height)
term.scroll(1)
local base_key = crypto.random_bytes(32)

local encryption_key = pbkdf2.derive(base_key, crypto.random_bytes(32), 20000, "Generating encryption key")

-- Create the password hash
term.write("Generating password salt")
term.scroll(1)
local salt = crypto.random_bytes(32)
local d_password = pbkdf2.derive(password, salt, iterations, "Generating password hash")

term.redirect(oldTerm)
