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

    local isTrucating = mode:match("^w")
    local isWriteable = mode:match("[wa+]")
    local isAppending = mode:match("^a")
    local isExisting = O_fs.exists(path)

    
    -- Create a temporary unencrypted file
    local tmp_handle = O_fs.open("os/.tmp_" .. string.gsub(path, "\\", "_"), "w+b")
    print("os/.tmp_" .. string.gsub(path, "\\", "_"))
    

    local O_handle, err
    if not isTrucating and isExisting then
        O_handle, err = O_fs.open(path, "r+b")
        if O_handle == nil then return O_handle, err end

        S_handle.nonce = O_handle.read(12)

        for i = 1, O_fs.getSize(path), 4096 do
            local e_chunk = O_handle.read(4096)

            local chunk = chacha20.crypt(e_chunk, encryption_key, S_handle.nonce)
            
            tmp_handle.write(chunk)
        end

        if isAppending then
            tmp_handle.seek("end", 0)
        else
            tmp_handle.seek("set", 0)
        end
    else
        S_handle.nonce = chacha20.generate_nonce()
    end



    
    for k, v in pairs(O_handle) do
        S_handle[k] = v
    end
    
    if S_handle.nonce == nil then
        S_handle.nonce = O_handle.read(12)
    end

    if not isTrucating
    
    print(S_handle.nonce)

    ---Read the file content 'count' amount of bytes, defaults to 1
    ---@param count? number
    ---@return string content The content of the file
    S_handle.read = function (count)
        if not mode:match("b") then
            count = 1
        end
        return tmp_handle.read(count)
    end
    ---Read all remaining bytes of the file
    ---@return string
    S_handle.readAll = function ()
        return tmp_handle.readAll()
    end
    ---Read the one line of the file
    ---@param withTrailing boolean
    ---@return string content 
    S_handle.readLine = function (withTrailing)
        return tmp_handle.readLine(withTrailing)
    end
    ---Write to the file using either a byte or string
    ---@param ... string|integer
    S_handle.write = function (...)
        tmp_handle.write(...)
    end 
    ---Write to the file using a string with a newline
    S_handle.writeLine = function (line)
        tmp_handle.writeLine(line)
    end

    ---Flush the file, saving it without closing it
    S_handle.flush = function ()
        local tmp_position = tmp_handle.seek("cur", 0)
        local O_position = O_handle.seeK("cur", 0)

        local new_nonce = chacha20.generate_nonce()
        local file_length = tmp_handle.seek("end", 0)

        tmp_handle.seek("set", 0)
        O_handle.seek("set", 0)
        O_handle.write(new_nonce)

        for i = 1, file_length, 4096 do
            local chunk = tmp_handle.read(4096)

            local e_chunk = chacha20.crypt(chunk, encryption_key, new_nonce)

            O_handle.write(e_chunk)
        end

        O_handle.flush()

        tmp_handle.seek("set", tmp_position)
        O_handle.seek("set", O_position)
    end

    S_handle.close = function ()
        local new_nonce = chacha20.generate_nonce()
        local file_length = tmp_handle.seek("end", 0)

        tmp_handle.seek("set", 0)
        O_handle.seek("set", 0)
        O_handle.write(new_nonce)

        for i = 1, file_length, 4096 do
            local chunk = tmp_handle.read(4096)

            local e_chunk = chacha20.crypt(chunk, encryption_key, new_nonce)

            O_handle.write(e_chunk)
        end

        O_handle.close()
    end

    return S_handle
end

encryption_key = "\104\147\125\51\76\33\131\137\146\36\149\132\182\20\37\180\47\233\201\129\180\60\36\43\189\30\125\174\149\242\30\88"
print(encryption_key)

local file, err = assert(S_fs.open("Testing.txt", "w"))

if file == nil then print(err, "crash") end



file.close()
