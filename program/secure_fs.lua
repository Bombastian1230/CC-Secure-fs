package.path = package.path .. ";./"
local chacha20 = require("program.chacha20")

S_fs = {}

local function checkResult(handle, ...)
    if ... == nil and handle._autoclose and not handle._closed then handle:close() end
    return ...
end

--- A file handle which can be read or written to.
--
-- @type Handle
local handleMetatable
handleMetatable = {
    __name = "FILE*",
    __tostring = function(self)
        if self._closed then
            return "file (closed)"
        else
            local hash = tostring(self._handle):match("table: (%x+)")
            return "file (" .. hash .. ")"
        end
    end,

    __index = {
        --- Close this file handle, freeing any resources it uses.
        --
        -- @treturn[1] true If this handle was successfully closed.
        -- @treturn[2] nil If this file handle could not be closed.
        -- @treturn[2] string The reason it could not be closed.
        -- @throws If this handle was already closed.
        close = function(self)
            if type(self) ~= "table" or getmetatable(self) ~= handleMetatable then
                error("bad argument #1 (FILE expected, got " .. type(self) .. ")", 2)
            end
            if self._closed then error("attempt to use a closed file", 2) end

            local handle = self._handle
            if handle.close then
                self._closed = true
                handle.close()
                return true
            else
                return nil, "attempt to close standard stream"
            end
        end,

        --- Flush any buffered output, forcing it to be written to the file
        --
        -- @throws If the handle has been closed
        flush = function(self)
            if type(self) ~= "table" or getmetatable(self) ~= handleMetatable then
                error("bad argument #1 (FILE expected, got " .. type(self) .. ")", 2)
            end
            if self._closed then error("attempt to use a closed file", 2) end

            local handle = self._handle
            if handle.flush then handle.flush() end
            return true
        end,

        --[[- Returns an iterator that, each time it is called, returns a new
        line from the file.

        This can be used in a for loop to iterate over all lines of a file

        Once the end of the file has been reached, @{nil} will be returned. The file is
        *not* automatically closed.

        @param ... The argument to pass to @{Handle:read} for each line.
        @treturn function():string|nil The line iterator.
        @throws If the file cannot be opened for reading
        @since 1.3

        @see io.lines
        @usage Iterate over every line in a file and print it out.

        ```lua
        local file = io.open("/rom/help/intro.txt")
        for line in file:lines() do
          print(line)
        end
        file:close()
        ```
        ]]
        lines = function(self, ...)
            if type(self) ~= "table" or getmetatable(self) ~= handleMetatable then
                error("bad argument #1 (FILE expected, got " .. type(self) .. ")", 2)
            end
            if self._closed then error("attempt to use a closed file", 2) end

            local handle = self._handle
            if not handle.read then return nil, "file is not readable" end

            local args = table.pack(...)
            return function()
                if self._closed then error("file is already closed", 2) end
                return checkResult(self, self:read(table.unpack(args, 1, args.n)))
            end
        end,

        --[[- Reads data from the file, using the specified formats. For each
        format provided, the function returns either the data read, or `nil` if
        no data could be read.

        The following formats are available:
        - `l`: Returns the next line (without a newline on the end).
        - `L`: Returns the next line (with a newline on the end).
        - `a`: Returns the entire rest of the file.
        - ~~`n`: Returns a number~~ (not implemented in CC).

        These formats can be preceded by a `*` to make it compatible with Lua 5.1.

        If no format is provided, `l` is assumed.

        @param ... The formats to use.
        @treturn (string|nil)... The data read from the file.
        ]]
        read = function(self, ...)
            if type(self) ~= "table" or getmetatable(self) ~= handleMetatable then
                error("bad argument #1 (FILE expected, got " .. type(self) .. ")", 2)
            end
            if self._closed then error("attempt to use a closed file", 2) end

            local handle = self._handle
            if not handle.read and not handle.readLine then return nil, "Not opened for reading" end

            local n = select("#", ...)
            local output = {}
            for i = 1, n do
                local arg = select(i, ...)
                local res
                if type(arg) == "number" then
                    if handle.read then res = handle.read(arg) end
                elseif type(arg) == "string" then
                    local format = arg:gsub("^%*", ""):sub(1, 1)

                    if format == "l" then
                        if handle.readLine then res = handle.readLine() end
                    elseif format == "L" and handle.readLine then
                        if handle.readLine then res = handle.readLine(true) end
                    elseif format == "a" then
                        if handle.readAll then res = handle.readAll() or "" end
                    elseif format == "n" then
                        res = nil -- Skip this format as we can't really handle it
                    else
                        error("bad argument #" .. i .. " (invalid format)", 2)
                    end
                else
                    error("bad argument #" .. i .. " (string expected, got " .. type(arg) .. ")", 2)
                end

                output[i] = res
                if not res then break end
            end

            -- Default to "l" if possible
            if n == 0 and handle.readLine then return handle.readLine() end
            return table.unpack(output, 1, n)
        end,

        --[[- Seeks the file cursor to the specified position, and returns the
        new position.

        `whence` controls where the seek operation starts, and is a string that
        may be one of these three values:
        - `set`: base position is 0 (beginning of the file)
        - `cur`: base is current position
        - `end`: base is end of file

        The default value of `whence` is `cur`, and the default value of `offset`
        is 0. This means that `file:seek()` without arguments returns the current
        position without moving.

        @tparam[opt] string whence The place to set the cursor from.
        @tparam[opt] number offset The offset from the start to move to.
        @treturn number The new location of the file cursor.
        ]]
        seek = function(self, whence, offset)
            if type(self) ~= "table" or getmetatable(self) ~= handleMetatable then
                error("bad argument #1 (FILE expected, got " .. type(self) .. ")", 2)
            end
            if self._closed then error("attempt to use a closed file", 2) end

            local handle = self._handle
            if not handle.seek then return nil, "file is not seekable" end

            -- It's a tail call, so error positions are preserved
            return handle.seek(whence, offset)
        end,

        --[[- Sets the buffering mode for an output file.

        This has no effect under ComputerCraft, and exists with compatility
        with base Lua.
        @tparam string mode The buffering mode.
        @tparam[opt] number size The size of the buffer.
        @see file:setvbuf Lua's documentation for `setvbuf`.
        @deprecated This has no effect in CC.
        ]]
        setvbuf = function(self, mode, size) end,

        --- Write one or more values to the file
        --
        -- @tparam string|number ... The values to write.
        -- @treturn[1] Handle The current file, allowing chained calls.
        -- @treturn[2] nil If the file could not be written to.
        -- @treturn[2] string The error message which occurred while writing.
        -- @changed 1.81.0 Multiple arguments are now allowed.
        write = function(self, ...)
            if type(self) ~= "table" or getmetatable(self) ~= handleMetatable then
                error("bad argument #1 (FILE expected, got " .. type(self) .. ")", 2)
            end
            if self._closed then error("attempt to use a closed file", 2) end

            local handle = self._handle
            if not handle.write then return nil, "file is not writable" end

            for i = 1, select("#", ...) do
                local arg = select(i, ...)

                handle.write(arg)
            end
            return self
        end,
    },
}

local function make_file(handle)
    return setmetatable({ _handle = handle }, handleMetatable)
end

local defaultInput = make_file({ readLine = _G.read })

local defaultOutput = make_file({ write = _G.write })

local defaultError = make_file({
    write = function(...)
        local oldColour
        if term.isColour() then
            oldColour = term.getTextColour()
            term.setTextColour(colors.red)
        end
        _G.write(...)
        if term.isColour() then term.setTextColour(oldColour) end
    end,
})

local currentInput = defaultInput
local currentOutput = defaultOutput
stdin = defaultInput
stdout = defaultOutput
stderr = defaultError

function close(file)
    if file == nil then return currentOutput:close() end

    if type(file) ~= "table" or getmetatable(file) ~= handleMetatable then
        error("bad argument #1 (FILE expected, got " .. type(file) .. ")", 2)
    end
    return file:close()
end

function flush()
    return currentOutput:flush()
end

function input(file)
    if type(file) == "string" then
        local res, err = open(file, "r")
        if not res then error(err, 2) end
        currentInput = res
    elseif type(file) == "table" and getmetatable(file) == handleMetatable then
        currentInput = file
    elseif file ~= nil then
        error("bad fileument #1 (FILE expected, got " .. type(file) .. ")", 2)
    end

    return currentInput
end


function lines(filename, ...)
    if filename then
        local ok, err = open(filename, "r")
        if not ok then error(err, 2) end

        -- We set this magic flag to mark this file as being opened by io.lines and so should be
        -- closed automatically
        ok._autoclose = true
        return ok:lines(...)
    else
        return currentInput:lines(...)
    end
end

function open(filename, mode)

    local file, err = fs.open(filename, mode or "r")
    if not file then return nil, err end

    return make_file(file)
end

--- Return true if the path is mounted to the parrent, the new root folder counts as mounted
--- @param path string
--- @return boolean
function S_fs.isDriveRoot(path)
    -- Force the root directory to be a mount.
    return fs.getDir(path) == ".." or fs.getDir(path) == "root" or fs.getDrive(path) ~= fs.getDrive(fs.getDir(path))
end

--- Opens a file
--- @param path any
--- @param mode any
function S_fs.open(path, mode)
    if path:match(".+root$") then
        error("Cannot create/open files/folders called root.")
    end

    local handle = io.open(path, mode)
    os.queueEvent("key request")
    local _, key = os.pullEvent("key response")
    handle.key = key

    return 
end


----ReadWriteHandle overides
--- Read file 
--- @param count? integer
function S_fs.ReadWriteHandle:read(count)
    if count == nil then count = 1 end


end

return S_fs