local pbkdf2 = require("pbkdf2")

term.setCursorPos(1, 1)
term.clear()
term.setTextColor(colors.white)
print([[

           /$$$$$$$$              /$$                     /$$          
          | $$_____/             | $$                    |__/          
  /$$$$$$$| $$     /$$$$$$$      | $$  /$$$$$$   /$$$$$$  /$$ /$$$$$$$ 
 /$$_____/| $$$$$ /$$_____/      | $$ /$$__  $$ /$$__  $$| $$| $$__  $$
|  $$$$$$ | $$__/|  $$$$$$       | $$| $$  \ $$| $$  \ $$| $$| $$  \ $$
 \____  $$| $$    \____  $$      | $$| $$  | $$| $$  | $$| $$| $$  | $$
 /$$$$$$$/| $$    /$$$$$$$/      | $$|  $$$$$$/|  $$$$$$$| $$| $$  | $$
|_______/ |__/   |_______/       |__/ \______/  \____  $$|__/|__/  |__/
                                                /$$  \ $$              
                                               |  $$$$$$/              
                                                \______/               
]])

local hashed_pass_file = assert(fs.open("sFs/secrets.txt", "r"))
local hashed_pass = hashed_pass_file.read(32)
hashed_pass_file.close()



local iterations = settings.get("sFs.iterations", 10000)
local salt = settings.get("sFs.salt", "OooooO Spoooky salt,its going to")

local password
if settings.get("sFs.auto_login", false) then
    for drive in peripheral.find("drive") do
        local path = fs.combine(drive.getMountPath(), "password.txt")

        local success, file = pcall(fs.open, path, "r")
        if success then
            assert(file)
            password = file.read()
        end
    end

    if password == nil then
        term.setTextColor(colors.red)
        print("Failed to find any password.txt files in root of attached drives")
        term.setTextColor(colors.white)
    end
end

---A basic check to skip doing pbkdf2 for passwords that are to short, can be added to later if i come up with something
---@param pass string
---@return boolean
---@return string?
local function basic_check(pass)
    if #pass < 8 then
        return false, "Input is to short to be the password"
    end
    return true
end

if password == nil then
    print(string.format("Type password carefully, it will take around %d seconds to verify", (iterations * 2) / 1000))

    local startX, startY = term.getCursorPos()
    
    local input_pass
    while true do
        term.write("Password: ")
        input_pass = read()
        local success, reason = basic_check(input_pass)

        if success then
            password = input_pass
            break
        else
            term.setCursorPos(startX, startY)
            term.clearLine()
            term.setTextColor(colors.red)

            print(reason)

            term.setTextColor(colors.white)
            term.clearLine()
        end
    end

    password = input_pass
end


