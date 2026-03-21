local utils = require("utils")

---Generate the matrix state
---@param key string A 32 character long string
---@param block_count number The current block count
---@param nonce string A 12 byte long string
local function initilize_matrix(key, block_count, nonce)
    local matrix = { 0x61707865, 0x3320646e, 0x79622d32, 0x6b206574 }

    for i = 1, #key, 4 do
        table.insert(matrix, utils.bytes_to_int(string.sub(key, i, i + 3), "little", false))
    end

    table.insert(matrix, block_count)

    for i = 1, #nonce, 4 do
        table.insert(matrix, utils.bytes_to_int(string.sub(nonce, i, i + 3), "big", false))
    end

    return matrix
end

---A quater round of chacha encryption
---@param matrix_state integer[]
---@param a_i integer
---@param b_i integer
---@param c_i integer
---@param d_i integer
local function quater_round(matrix_state, a_i, b_i, c_i, d_i)
    local a, b, c, d = matrix_state[a_i], matrix_state[b_i], matrix_state[c_i], matrix_state[d_i]

    a = utils.add32(a, b)
    d = bit32.bxor(d, a)
    d = bit32.lrotate(d, 16)

    c = utils.add32(c, d)
    b = bit32.bxor(b, c)
    b = bit32.lrotate(b, 12)

    a = utils.add32(a, b)
    d = bit32.bxor(d, a)
    d = bit32.lrotate(d, 8)

    c = utils.add32(c, d)
    b = bit32.bxor(b, c)
    b = bit32.lrotate(b, 7)

    matrix_state[a_i], matrix_state[b_i], matrix_state[c_i], matrix_state[d_i] = a, b, c, d
end

---Does both a collumn round and a diagonal round on the matrix state
---@param matrix_state integer[]
local function double_round(matrix_state)
    quater_round(matrix_state, 1, 5, 9, 13) -- Column rounds
    quater_round(matrix_state, 2, 6, 10, 14)
    quater_round(matrix_state, 3, 7, 11, 15)
    quater_round(matrix_state, 4, 8, 12, 16)
    quater_round(matrix_state, 1, 6, 11, 16) -- Diagonal rounds
    quater_round(matrix_state, 2, 7, 12, 13)
    quater_round(matrix_state, 3, 8, 9, 14)
    quater_round(matrix_state, 4, 5, 10, 15)
end

---Genereates a 64 byte chunk of the key stream (Doesn't serialise the matrix)
---@param key string
---@param nonce string
---@param block_count integer
---@return integer[]
local function generate_keystream_block(key, nonce, block_count)
    local matrix_state = initilize_matrix(key, block_count, nonce)
    local initial_matrix_state = utils.copy_table(matrix_state)

    for i = 1, 10 do
        double_round(matrix_state)
    end

    for i = 1, #matrix_state do
        matrix_state[i] = utils.add32(matrix_state[i], initial_matrix_state[i])
    end

    return matrix_state
end

---Generates a keystream long enough to encrypt a message of length `length`
---@param key string
---@param nonce string
---@param length integer
---@param initial_block_count integer
---@return integer[] keystream
local function generate_keystream(key, nonce, length, initial_block_count)
    local keystream = {}
    for block_count = initial_block_count, math.ceil(length / 64) + initial_block_count do
        local block = generate_keystream_block(key, nonce, block_count)

        for _, word in ipairs(block) do
            local bytes = utils.bytes_from_int32(word)
            for _, byte in ipairs(bytes) do
                table.insert(keystream, byte)
            end
        end

        utils.yield(10, block_count)
    end

    return keystream
end

---Encrypts text using ChaCha20
---@param plaintext string The text to encrypt
---@param key string A 32 character long string
---@param nonce? string A random string 12 bytes long, if unspecified automaticaly generated.
---@param block_count? integer The block count to start on
---@return string ciphertext The encrypted text
---@return string nonce The nonce used to encrypt the text
local function encrypt(plaintext, key, nonce, block_count)
    if nonce == nil then
        local crypto = require("sFs.crypto")
        nonce = crypto.random_bytes(12)
    end

    local keystream = generate_keystream(key, nonce, #plaintext, block_count or 0)

    local cipherbytes = {}
    for i = 1, #plaintext do
        local plainbyte = string.byte(string.sub(plaintext, i))
        table.insert(cipherbytes, bit32.bxor(keystream[i], plainbyte))

        utils.yield(4096, i)
    end

    return string.char(table.unpack(cipherbytes)), nonce
end

return {
    crypt = encrypt,
    generate_keystream = generate_keystream,
    generate_keystream_block =
        generate_keystream_block
}
