local cc_strings = require("cc.strings")
local utils      = require("sFs.utils")

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

local function encrypt_files(encryption_key)
    
end

local function rewrite_prompt(prompt, last_prompt_height)
    local x, y = term.getCursorPos()
    if last_prompt_height > 0 then
        for i = 1, last_prompt_height do
            term.setCursorPos(1, y-i)
            term.clearLine()
        end
    end

    last_prompt_height = math.ceil(#prompt / width) + 1

    term.setCursorPos(1, term.getCursorPos())
    print(prompt)
    write("> ")

    return last_prompt_height
end

local width, height = term.getSize()

local header = string.rep("-", math.ceil((width-13)/2)) .. " PLEASE READ " .. string.rep("-", math.floor((width-13)/2))
local instructions = cc_strings.wrap("There are detailed installation instructions and technical details in the book you got with the install disk.\nEvery step and choice in this installation is explained in detail in the book, every step is also labeled with its relevant page number.\n\nNOTE: You can not interupt the install process, If you regret installing sFs read the book for instructions")

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

local prompt_win = window.create(term.current(), 1, height-4, width, 5)
---Prompt a user for input
---@param question string
---@param error? string
---@param blit_fg? string A blit string
---@param blit_bg? string A blit string
---@return string
local function ask(question, error, blit_fg, blit_bg)
    if not blit_fg then blit_fg = string.rep("0", #question) end
    if not blit_bg then blit_bg = string.rep("f", #question) end

    local oldTerm = term.redirect(prompt_win)
    prompt_win.clear()
    prompt_win.setCursorPos(1, 1)
    
    if error then 
        prompt_win.setTextColor(colors.red)
        print(error)
        prompt_win.setTextColor(colors.white)
    end


    local question_lines = cc_strings.wrap(question)
    local blit_fg_lines = cc_strings.wrap(blit_fg)
    local blit_bg_lines = cc_strings.wrap(blit_bg)
    for i = 1, #question_lines do
        term.blit(question_lines[i], blit_fg_lines[i], blit_bg_lines[i])
    end

    write("\n> ")
    
    local answer = read()
    term.redirect(oldTerm)
    
    return answer
end

::redo_pass::
local password = ""
local error
while true do
    password = ask("Enter a password (min 8 characters), p.5", error, "0000000000000000022222222222222222222444")

    if #password < 8 then error = "Password must be at least 8 characters long"
    else break end
end

local agree = ""
local error
while true do
    agree = ask(string.format("This computers password will be: %s, \nIs this correct? (Y/n)", password), error, "000000000000000000000000000000000")
end

