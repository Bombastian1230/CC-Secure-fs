local args = { ... }

if #args == 0 then
    local program_name = arg[0] or shell.getRunningProgram()
    print("Usage: " .. program_name .. " <path>")
    return
end

local path = shell.resolve(args[1])
if not fs.exists(path) then
    printError("File: " .. path .. " does not exist")
    return
end
if fs.isReadOnly(path) then
    printError("Cannot crypt: " .. path .. " it is read only")
    return
end

local encrypted_file = fs.open(path, "r")
local decryped_file = fs.open(path .. ".tmp", "w")

print(nonce)