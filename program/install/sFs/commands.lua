local utils = require "utils"
local pbkdf2 = require "pbkdf2"
local chacha20 = require "chacha20"

local valid_answers = {
    Y = true,
    y = true,
    N = true,
    n = true
}


local function logout()
    shell.run("sFs/login.lua")
end

local function raw_mode()
    term.setTextColor(colors.white)
    print("Are you sure you want to reboot into raw mode? (Y/N)")

    term.setTextColor(colors.yellow)
    write("> ")
    term.setTextColor(colors.white)

    while true do
        local response = read()

        if response:sub(1, 1):lower() == "y" then
            term.setTextColor(colors.orange)
            for i = 0, 5 do
                write("Rebooting into raw mode in " .. tostring(5 - i))
                term.setCursorPos(1, select(2, term.getCursorPos()))
                sleep(1)
            end

            settings.set("sFs.raw_mode", true)
            settings.save()

            os.reboot()
        elseif response:sub(1, 1):lower() == "n" then
            return true
        else
            local current_y, current_y = term.getCursorPos()

            term.setCursorPos(1, current_y - 2)
        end
    end
end

--- I am unsure if the way i have implemented the fs override allows this
--- Since S_fs.open refuses to write to secrets.txt you can't save the reencrypted encryption key
-- local function change_password()
--     local start_x, start_y = term.getCursorPos()
--     local width, height = term.getSize()

--     local d_pass = get_password()

--     local current_x, current_y = term.getCursorPos()

--     for i = 1, current_y - height do
--         term.clearLine()
--         term.setCursorPos(1, current_y - i)
--     end

--     print("Enter new password (min 8 characters)")
--     print()

--     local new_pass
--     while true do
--         write("New password: ")
--         new_pass = read()

--         if #new_pass < 8 then
--             term.setCursorPos(start_x, start_y)
--             term.clearLine()
--             term.setTextColor(colors.red)

--             print("Password must be longer than 8 characters")

--             term.setTextColor(colors.white)
--             term.clearLine()
--             goto continue
--         else
--             break
--         end
--         ::continue::
--     end

--     current_x, current_y = term.getCursorPos()

--     for i = 1, current_y - height do
--         term.clearLine()
--         term.setCursorPos(1, current_y - i)
--     end

--     local iterations
--     while true do
--         print("Security level? (1:Normal 2:Strong 3:Very Strong)")
--         write("> ")
--         local response = read()

--         if response == "1" or response == "normal" then
--             iterations = 10
--         elseif response == "2" or response == "strong" then
--             iterations = 50000
--         elseif response == "3" or response == "very strong" then
--             iterations = 100000
--         else
--             term.clearLine()
--             term.setCursorPos(start_x, start_y)
--             printError("Not a valid selection")
--         end

--         if iterations then
--             local time_to_derive = math.floor((iterations * 2) / 1000)
--             local prompt = string.format("Security level %s takes about %d seconds to verify your password, are you sure? (Y/n)", response, time_to_derive)
--             local blit_fg = "000000000000000" .. string.rep("3", #response) .. "0000000000000" .. string.rep("3", #tostring(time_to_derive)) .. "00000000000000000000000000000000000000000000000022222"
--             local blit_bg = string.rep("f", #prompt)

--             print(prompt)
--             print(blit_fg)
--             print(blit_bg)
--             print(time_to_derive)
--             print(#tostring(time_to_derive))

--             term.blit(prompt, blit_fg, blit_bg)
--             print()
--             write("> ")

--             while true do
--                 local response = read()

--                 if not valid_answers[response] then
--                     return
--                 else
--                     if response:lower() == "y" then
--                         break
--                     else
--                         return
--                     end
--                 end
--             end

--             if iterations then break end
--         end
--     end

--     local encryption_key = chacha20.crypt(secrets.encrypted_e_key, d_pass, secrets.e_key_nonce)
-- end

local args = { ... }
local command = args[1] --[[@as string]]

if command == nil then
    return
end

local first_letter = command:sub(1, 1):lower()
print(first_letter)

if first_letter == "l" then
    logout()
elseif first_letter == "r" then
    raw_mode()
else
    return
end
