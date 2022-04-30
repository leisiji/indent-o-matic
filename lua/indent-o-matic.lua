local indent_o_matic = {}
local preferences = {}

-- Get value of option
local function opt(name)
    return vim.api.nvim_buf_get_option(0, name)
end

-- Set value of option
local function setopt(name, value)
    return vim.api.nvim_buf_set_option(0, name, value)
end

-- Get a line's contents as a string (0-indexed)
local function line_at(index)
    return vim.api.nvim_buf_get_lines(0, index, index + 1, true)[1]
end

-- Search if a list has a specific value
-- This should be faster than a binary search for small lists
local function contains(list, value)
    for _, v in ipairs(list) do
        if value == v then
            return true
        end
    end

    return false
end

-- Get the configuration's value or its default if not set
local function config(config_key, default_value)
    -- Attempt to get filetype specific config if available
    local ft_preferences = preferences['filetype_' .. opt('filetype')]
    if type(ft_preferences) == 'table' then
        local value = ft_preferences[config_key]
        if value ~= nil then
            return value
        end
    end

    -- No filetype specific config, try the global one or fallback to default
    local value = preferences[config_key]
    if value == nil then
        value = default_value
    end

    return value
end

local function syntax_skip(line, col)
    local syntax = vim.fn.synIDattr(vim.fn.synIDtrans(vim.fn.synID(line, col, 1)), 'name')
    if syntax:match('String$') or syntax:match('Comment$') or syntax:match('Doc$') then
        return true
    end
    return false
end

local function skip_comment_by_ts(lang_tree)
    if lang_tree == nil then
        return 0
    end

    for _, tree in ipairs(lang_tree:trees()) do
      local root = tree:root()
      for node, _ in root:iter_children() do
        local type = node:type()
        if type ~= 'comment' then
          local line, _, _ = node:start()
          return line
        end
      end
    end

    return 0
end

-- Configure the plugin
function indent_o_matic.setup(options)
    if type(options) == 'table' then
        preferences = options
    else
        local msg = "Can't setup indent-o-matic, correct syntax is: "
        msg = msg .. "require('indent-o-matic').setup { ... }"
        error(msg)
    end
end

-- Attempt to detect current buffer's indentation and apply it to local settings
function indent_o_matic.detect()
    -- Detect default indentation values (0 for tabs, N for N spaces)
    local default = opt('expandtab') and opt('shiftwidth') or 0
    local detected = default

    -- Options
    local max_lines = config('max_lines', 2048)
    local standard_widths = config('standard_widths', { 2, 4 })

    -- treesitter
    local lang_tree = require('nvim-treesitter.parsers').get_parser(0)
    local i = skip_comment_by_ts(lang_tree)

    -- Loop over every line, breaking once it finds something that looks like a
    -- standard indentation or if it reaches end of file
    while i ~= max_lines do
        local first_char

        local ok, line = pcall(function() return line_at(i) end)
        if not ok then
            -- End of file
            break
        end

        -- Skip empty lines
        if #line == 0 then
            goto continue
        end

        -- If a line starts with a tab then the file must be tab indented
        -- else if it starts with spaces it tries to detect if it's the file's indentation
        first_char = line:sub(1, 1)
        if first_char == '\t' then
            detected = 0
            break
        elseif first_char == ' ' then
            -- Figure out the number of spaces used and if it should be the indentation
            local j = 2
            while j ~= #line and j < 10 do
                local c = line:sub(j, j)
                if c == '\t' then
                    -- Spaces and then a tab? WTF? Ignore this unholy line
                    goto continue
                elseif c ~= ' ' then
                    break
                end

                j = j + 1
            end

            if lang_tree == nil and syntax_skip(i, j) then
                goto continue
            end

            -- If it's a standard number of spaces it's probably the file's indentation
            j = j - 1
            if contains(standard_widths, j) then
                detected = j
                break
            end
        end

        -- "We have continue at home"
        ::continue::
        i = i + 1
    end

    if detected ~= default then
        if detected == 0 then
            setopt('expandtab', false)
        else
            setopt('expandtab', true)
            setopt('tabstop', detected)
            setopt('softtabstop', detected)
            setopt('shiftwidth', detected)
        end
    end
end

return indent_o_matic
