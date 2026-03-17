---@diagnostic disable: deprecated
package.path = package.path .. ";./"
local chacha20 = require("chacha20")
local utils = require("utils")

S_fs = {}
O_fs = {}
for k, v in pairs(fs) do
    O_fs[k] = v
end

---@type string
local encryption_key = nil

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
    local S_handle = {}
    print("in open")
    if not O_fs.exists(path) then
        S_handle.nonce = chacha20.generate_nonce()
    end

    -- If the mode is write or append try to create the file
    if mode:match("^w.?.?") or mode:match("^a.?") then
        local create_handle, err = O_fs.open(path, "ab")
        if create_handle == nil then return create_handle, err end
        
        create_handle.close()
    end
    
    local O_handle, err = O_fs.open(path, "r+b")
    if O_handle == nil then return O_handle, err end
    
    for k, v in pairs(O_handle) do
        S_handle[k] = v
    end
    
    if S_handle.nonce == nil then
        S_handle.nonce = O_handle.read(12)
    end
    
    print(S_handle.nonce)

    -- Create a temporary unencrypted file
    local tmp_handle = O_fs.open("os/.tmp_" .. string.gsub(path, "\\", "_"), "w+b")
    print("os/.tmp_" .. string.gsub(path, "\\", "_"))
    for i = 1, O_fs.getSize(path), 4096 do
        local chunk = O_handle.read(4096)
        
        tmp_handle.write(chunk)
    end

    


    -- ---Read the file
    -- ---@param count? number
    -- ---@return string content The decrypted content of the file
    -- S_handle.read = function(count)
    --     if count == nil then count = 1 end

    --     local current_pos = O_handle.seek("cur", 0)
    --     local e_content = O_handle.read(count)

    --     local keystream = S_fs.getKeystream(current_pos, #e_content, path, S_handle.key)
    --     local content = S_fs.crypt(e_content, keystream)

    --     return content
    -- end

    -- S_handle.readAll = function ()
    --     local current_pos = O_handle.seek("cur", 0)
    --     local e_content = O_handle.readAll()

    --     local keystream = S_fs.getKeystream(current_pos, #e_content, path, S_handle.key)
    --     local content = S_fs.crypt(e_content, keystream)

    --     return content
    -- end

    -- S_handle.readLine = function (withTrailing)
    --     local current_pos = O_handle.seek("cur", 0)
    --     local e_content = O_handle.readLine(withTrailing)

    --     local keystream = S_fs.getKeystream(current_pos, #e_content, path, S_handle.key)
    --     local content = S_fs.crypt(e_content, keystream)

    --     return content
    -- end

    -- S_handle.write = function (...)
    --     local content
    --     if type(...) == "string" then
    --         content = ...
    --     elseif type(...) == "number" then
    --         content = string.char(...)
    --     end

    --     local current_pos = O_handle.seek("cur", 0)
        
    --     local keystream = S_fs.getKeystream(current_pos, #content, path, S_handle.key)
    --     local e_content = S_fs.crypt(content, keystream)

    --     O_handle.write(e_content)
    -- end

    -- S_handle.writeLine = function (text)
        
    --     S_handle.write(text .. "\n")
    -- end

    -- S_handle.flush = function ()
        
    -- end

    return S_handle
end

encryption_key = "\104\147\125\51\76\33\131\137\146\36\149\132\182\20\37\180\47\233\201\129\180\60\36\43\189\30\125\174\149\242\30\88"
print(encryption_key)

local file, err = assert(S_fs.open("Testing.txt", "w"))

if file == nil then print(err, "crash") end



file.close()
