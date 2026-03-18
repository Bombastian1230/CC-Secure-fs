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
S_fs.isReadOnly = function (path)
    path = O_fs.combine(path)
    if path:find("^rom/") or path:find("^sfs/") then
        return true
    end
    return false
end

--- Returns the size of the file in bytes
--- @param path string
--- @return integer
S_fs.getSize = function (path)
    path = O_fs.combine(path)
    if S_fs.isReadOnly(path) then return O_fs.getSize(path) end
    local size = O_fs.getSize(path)
    return math.max(0, size - 12)
end

--- Returns the size of the file in bytes, includes the prefixed 12 byte nonce
--- @param path string
--- @return integer
S_fs.getRawSize = function (path)
    return O_fs.getSize(path)
end

S_fs.delete = function (path)
    path = O_fs.combine(path)
    if not S_fs.isReadOnly(path) then
        O_fs.delete(path)
    else
        error("Access denied")
    end
end

S_fs.move = function (source, destination)
    source = O_fs.combine(source)
    destination = O_fs.combine(destination)
    if not  S_fs.isReadOnly(destination) then
        O_fs.move(source, destination)
    else
        error("Access denied")
    end
end

S_fs.attributes = function (path)
    path = O_fs.combine(path)
    local att = O_fs.attributes(path)
    att.isReadOnly = S_fs.isReadOnly(path)
    return att
end

S_fs.list = function (path)
    path = O_fs.combine(path)
    local list = O_fs.list(path)
    
    local filtered = {}
    for _, name in ipairs(list) do
        if name:match("^%.tmp_") then
            table.insert(filtered, name)
        end
    end

    return filtered
end

S_fs.exists = function (path)
    path = O_fs.combine(path)
    if path:match("%.tmp_") then return false end
    return O_fs.exists(path)
end

S_fs.find = function(wildcard)
    local results = O_fs.find(wildcard)
    local filtered = {}
    for _, path in ipairs(results) do
        if not path:match("%.tmp_") then
            table.insert(filtered, path)
        end
    end
    return filtered
end


---Open a file for reading/writing
---@param path string
---@param mode ccTweaked.fs.openMode
---@return table|nil
---@return string?
S_fs.open = function(path, mode)
    path = O_fs.combine(path)
    ---@cast path string

    local isTrucating = mode:match("^w")
    local isWriteable = mode:match("[wa+]")
    local isAppending = mode:match("^a")
    local isExisting = S_fs.exists(path)

    if path:find("^sfs/") and isWriteable then
        return nil
    end
    if S_fs.isReadOnly(path) or path:match("startup%.lua") then
        return O_fs.open(path, mode)
    end

    local S_handle = {}

    -- Create a temporary unencrypted file
    local tmp_path = "sfs/.tmp_" .. path:gsub("/", "_")
    local tmp_handle = O_fs.open(tmp_path, "w+b")

    local O_handle, err
    if not isTrucating and isExisting then
        -- If a file isn't in write mode use the first 12 bytes as nonce and decrypt the file
        O_handle, err = O_fs.open(path, "r+b")
        if O_handle == nil then return O_handle, err end

        S_handle.nonce = O_handle.read(12)

        while true do
            local e_chunk = O_handle.read(4096)
            if e_chunk == nil then break end

            local chunk = chacha20.crypt(e_chunk, encryption_key, S_handle.nonce)
            tmp_handle.write(chunk)
        end

        if isAppending then
            tmp_handle.seek("end", 0)
        else
            tmp_handle.seek("set", 0)
        end
    else
        -- Otherwise generate a new random nonce
        O_handle, err = O_fs.open(path, "w+b")
        if O_handle == nil then return O_handle, err end

        S_handle.nonce = chacha20.generate_nonce()
    end

    for k, v in pairs(O_handle) do
        S_handle[k] = v
    end

    ----- Functions that are always available
    ---Seek a position in a file
    ---@param whence "set"|"cur"|"end"
    ---@param offset integer
    ---@return integer
    S_handle.seek = function(whence, offset)
        return tmp_handle.seek(whence, offset)
    end
    ---Read the file content 'count' amount of bytes, defaults to 1
    ---@param count? number
    ---@return string content The content of the file
    S_handle.read = function(count)
        return tmp_handle.read(count or 1)
    end
    ---Read all remaining bytes of the file
    ---@return string
    S_handle.readAll = function()
        return tmp_handle.readAll()
    end
    ---Read the one line of the file
    ---@param withTrailing boolean
    ---@return string content
    S_handle.readLine = function(withTrailing)
        return tmp_handle.readLine(withTrailing)
    end

    if isWriteable then
        ----- Functions for Write handles
        ---Write to the file using either a byte or string
        ---@param ... string|integer
        S_handle.write = function(...)
            tmp_handle.write(...)
        end
        ---Write to the file using a string with a newline
        S_handle.writeLine = function(line)
            tmp_handle.writeLine(line)
        end

        local function saveToDisk() 
            local tmp_position = tmp_handle.seek("cur", 0)
            local O_position = O_handle.seek("cur", 0)

            local new_nonce = chacha20.generate_nonce()

            tmp_handle.seek("set", 0)
            O_handle.seek("set", 0)
            O_handle.write(new_nonce)
    
            while true do
                local chunk = tmp_handle.read(4096)
                if chunk == nil then break end

                O_handle.write(chunk)
            end        

            tmp_handle.seek("set", tmp_position)
            O_handle.seek("set", O_position)
        end

        ---Flush the file, saving it without closing it
        S_handle.flush = saveToDisk

        ---Close the file
        S_handle.close = function()
            saveToDisk()

            O_handle.close()
            tmp_handle.close()
            O_fs.delete(tmp_path)
        end
    else
        S_handle.close = function()
            O_handle.close()
            tmp_handle.close()
            O_fs.delete(tmp_path)
        end
    end


    return S_handle
end

S_fs.copy = function (source, destination)
    source = O_fs.combine(source)
    destination = O_fs.combine(destination)

    if not S_fs.exists(source) then
        error(source .. ": No such file")
    end
    if S_fs.isReadOnly(destination) then
        error("Access denied")
    end

    local source_file = assert(S_fs.open(source, "rb"))
    local destination_file = assert(S_fs.open(destination, "wb"))

    while true do
        local chunk = source_file.read(4096)
        if chunk == nil then break end

        destination_file.write(chunk)
    end

    source_file.close()
    destination_file.close()
end


encryption_key =
"\104\147\125\51\76\33\131\137\146\36\149\132\182\20\37\180\47\233\201\129\180\60\36\43\189\30\125\174\149\242\30\88"
