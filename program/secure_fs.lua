---@diagnostic disable: deprecated
package.path = package.path .. ";./"
local chacha20 = require("chacha20")
local utils = require("utils")

S_fs = {}
O_fs = {}
for k, v in pairs(fs) do
    O_fs[k] = v
end


---Return the nonce used to encrypt a file
---@param path string
---@return string
function S_fs.getNonce(path)
    local hex = path:match("@([0-9a-fA-F]+)$")
    return utils.string_from_hex(hex)
end

---Returns the keystream for a specific block of data based on its position in the file
---@param position integer
---@param data_size integer
---@param path string
---@param key string
function S_fs.getKeystream(position, data_size, path, key)
    local nonce = S_fs.getNonce(path)
    local block_count = math.floor((position) / 64)
    local block_amount = math.floor((position + data_size) / 64) - block_count + 1
    local keystream = {}

    for block_count = block_count, block_count + block_amount do
        local block = chacha20.generate_keystream_block(key, nonce, block_count)
        for _, word in ipairs(block) do
            local bytes = utils.bytes_from_int32(word)
            for _, byte in ipairs(bytes) do
                table.insert(keystream, byte)
            end
        end
    end
    
    local keystream_start = (position) % 64 + 1
    local keystream_end = keystream_start + data_size - 1

    return { table.unpack(keystream, keystream_start, keystream_end) }
end

---En/decrypt the data using the keystream
---@param data string
---@param keystream integer[]
function S_fs.crypt(data, keystream)
    local crypted = {}
    for i = 1, #data do
        local byte = data:byte(i)
        crypted[i] = bit32.bxor(byte, keystream[i])
    end

    return string.char(table.unpack(crypted))
end

--- Return true if the path is mounted to the parrent, the new root folder counts as mounted
--- @param path string
--- @return boolean
S_fs.isDriveRoot = function(path)
    -- Force the root directory to be a mount.
    return O_fs.getDir(path) == ".." or O_fs.getDir(path) == "root" or
    O_fs.getDrive(path) ~= O_fs.getDrive(O_fs.getDir(path))
end

---Open a file for reading/writing
---@param path string
---@param mode ccTweaked.fs.openMode
---@return table|nil
---@return string?
S_fs.open = function(path, mode)
    print("Before O_fs.open")
    local O_handle, err = O_fs.open(path, mode)
    print("After O_fs.open")
    if O_handle == nil then return O_handle, err end
    print("After error check")

    local S_handle = {}
    for k, v in pairs(O_handle) do
        S_handle[k] = v
    end

    os.queueEvent("key_request", "fileopen", path)
    _, S_handle.key = os.pullEvent("key_response")


    ---Read the file
    ---@param count? number
    ---@return string content The decrypted content of the file
    S_handle.read = function(count)
        if count == nil then count = 1 end

        local current_pos = O_handle.seek("cur", 0)
        local e_content = O_handle.read(count)

        local keystream = S_fs.getKeystream(current_pos, #e_content, path, S_handle.key)
        utils.print_table_as_hex(keystream, 2)
        local content = S_fs.crypt(e_content, keystream)

        return content
    end

    S_handle.readAll = function ()
        local e_content = O_handle.readAll()
        local current_pos
    end

    return S_handle
end

print("Before S_fs.open")
local file, err = assert(S_fs.open("Testing.txt@82893adef889cf2ba4fabdea", "r"))

if file == nil then print(err, "crash") end

local out = assert(fs.open("Testing_2.txt@82893adef889cf2ba4fabdea", "w"))

out.write(file.read(7))

file.close()    
out.close()
