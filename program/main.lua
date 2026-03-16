---@diagnostic disable: deprecated
local key = string.char( 0x43, 0x42, 0x9f, 0x5e, 0x72, 0x89, 0x47, 0x0c, 0x83, 0x55, 0x3f, 0xa9, 0x24, 0x90, 0x64, 0x64, 0x03, 0x6f, 0x33, 0x3d, 0xf4, 0x96, 0x59, 0xfd, 0x41, 0x56, 0xc0, 0x04, 0x32, 0xf1, 0xbd, 0xfa )

---@type {string: {realpath: string, nonce: string}}
local files = {}

-- Data senders
local function keySender()
    while key do
        local event, data = os.pullEvent("key request")
        os.queueEvent("key response", key)
    end
end

local function fileSender()
    while true do
       local _, filepath = os.pullEvent("file request")
       os.queueEvent("file response", files[filepath])
    end
end

-- Helper
local function reqursive_file_search(parent)
    local files = fs.list(parent)
    local filepaths = {}

    for i = 1, #files do
        local path = fs.combine(parent, files[i])
        if path == "rom" then
            goto skip
        end

        if fs.isDir(path) then
            local sub_files = reqursive_file_search(path)
            table.move(sub_files, 1, #sub_files, #filepaths, filepaths)
        else
            table.insert(filepaths, path)
        end

        ::skip::
    end

    return filepaths
end

-- On startup
local function get_files()
    for _, filepath in ipairs(reqursive_file_search("/")) do
        print(filepath)
    end
end

get_files()

-- parallel.waitForAny(fileSender, keySender)