local pbkdf2 = require("pbkdf2")
local utils  = require("utils")
local chacha20 = require("chacha20")

local backup_pullEvent = os.pullEvent
os.pullEvent = utils.pullEventOverride

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

---Returns the sensative info about the computer
---@return {iterations: number, salt: string, password_validation: string, encrypted_e_key: string, e_key_nonce: string}
local function get_secrets()
    local file = assert(fs.open("sFs/secrets.txt", "r"))
    local secrets = {
        iterations = tonumber(file.readLine()),
        salt = file.readLine(),
        password_validation = file.readLine(),
        encrypted_e_key = file.readLine(),
        e_key_nonce = file.readLine()
    }
    file.close()

    return secrets
end

local secrets = get_secrets()

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

local function full_check(pass)
    local d_pass = pbkdf2.derive(pass, secrets.salt, secrets.iterations)
    local correct = chacha20.crypt(secrets.password_validation, d_pass, "T69YTLag5DPx") == secrets.password_validation

    return correct, d_pass
end

local function manual_input()
    print(string.format("Type password carefully, it will take ~%d seconds to verify", (secrets.iterations * 2) / 1000))

    local startX, startY = term.getCursorPos()
    
    while true do
        -- Basic password check
        term.write("Password: ")
        local password = read()
        local success, reason = basic_check(password)

        if not success then
            term.setCursorPos(startX, startY)
            term.clearLine()
            term.setTextColor(colors.red)

            print(reason)

            term.setTextColor(colors.white)
            term.clearLine()
            goto continue
        end

        -- Full password check
        local correct, d_pass = full_check()

        if correct then
            term.setTextColor(colors.green)
            print("Correct password")
            term.setTextColor(colors.white)

            return d_pass
        else
            term.setCursorPos(startX, startY)
            term.clearLine()
            term.setTextColor(colors.red)

            print("Incorrect password, try again")

            term.setTextColor(colors.white)
            term.clearLine()

            goto continue
        end

        ::continue::
    end
end

local function auto_login()
    local d_pass
    for drive in peripheral.find("drive") do
        local path = fs.combine(drive.getMountPath(), "password.txt")

        local success, file = pcall(fs.open, path, "r")
        if success then
            assert(file)
            local password = assert(file.readAll())
            file.close()

            if basic_check(password) then
                local correct, tmp_d_pass = full_check(password)
                if correct then
                    d_pass = tmp_d_pass
                end
            end

            break
        end
    end

    if d_pass == nil then
        term.setTextColor(colors.red)
        print("Failed to find any valid passwords in files in root of attached drives")
        term.setTextColor(colors.white)
        return nil
    end

    return d_pass
end

---@type string|nil Hello world, i am logging in
local d_pass
if settings.get("sFs.auto_login", false) then
    d_pass = auto_login()
end

if d_pass == nil then
    d_pass = manual_input()
end

local encryption_key = chacha20.crypt(secrets.encrypted_e_key, d_pass, secrets.e_key_nonce)

-- Overides
_G.fs = require("secure_fs")
fs.init_key(encryption_key)

---Loads a chunk from file filename or from the standard input, if no file name is given.
---@param filename string
---@param mode? "b"|"bt"|"t"
---@param env? table
_G.loadfile = function (filename, mode, env)
    local handle = fs.open(filename, "r")
    if handle == nil then return nil, "File not found" end

    local content = assert(handle.readAll())
    handle.close()

    return load(content, "@" .. filename, mode, env or _G)
end

---Opens the named file and executes its content as a Lua chunk. When called without arguments, dofile executes the content of the standard input (stdin). Returns all values returned by the chunk. In case of errors, dofile propagates the error to its caller. (That is, dofile does not run in protected mode.)
---@param filename string
---@return ...
_G.dofile = function (filename)
    local f, err = loadfile(filename)
    if f == nil then return nil, err end
    return f()
end

os.pullEvent = backup_pullEvent