local prompts = require('gen.prompts')
local M = {}

local curr_buffer = nil
local start_pos = nil
local end_pos = nil

local function trim_table(tbl)
    local function is_whitespace(str) return str:match("^%s*$") ~= nil end

    while #tbl > 0 and (tbl[1] == "" or is_whitespace(tbl[1])) do
        table.remove(tbl, 1)
    end

    while #tbl > 0 and (tbl[#tbl] == "" or is_whitespace(tbl[#tbl])) do
        table.remove(tbl, #tbl)
    end

    return tbl
end

local function get_window_options()

    local width = math.floor(vim.o.columns * 0.9) -- 90% of the current editor's width
    local height = math.floor(vim.o.lines * 0.9)
    local row = math.floor((vim.o.lines - height) / 2)
    local col = math.floor((vim.o.columns - width) / 2)

    local cursor = vim.api.nvim_win_get_cursor(0)
    local new_win_width = vim.api.nvim_win_get_width(0)
    local win_height = vim.api.nvim_win_get_height(0)

    local middle_row = win_height / 2

    local new_win_height = math.floor(win_height / 2)
    local new_win_row
    if cursor[1] <= middle_row then
        new_win_row = 5
    else
        new_win_row = -5 - new_win_height
    end

    return {
        relative = 'cursor',
        width = new_win_width,
        height = new_win_height,
        row = new_win_row,
        col = 0,
        style = 'minimal',
        border = 'single'
    }
end

M.command = 'ollama run $model $prompt'
M.model = 'mistral:instruct'

M.exec = function(options)
    local opts = vim.tbl_deep_extend('force', {
        model = M.model,
        command = M.command,
        win_config = M.win_config
    }, options)
    pcall(io.popen, 'ollama serve > /dev/null 2>&1 &')
    curr_buffer = vim.fn.bufnr('%')
    local mode = opts.mode or vim.fn.mode()
    if mode == 'v' or mode == 'V' then
        start_pos = vim.fn.getpos("'<")
        end_pos = vim.fn.getpos("'>")
        end_pos[3] = vim.fn.col("'>") -- in case of `V`, it would be maxcol instead
    else
        local cursor = vim.fn.getpos('.')
        start_pos = cursor
        end_pos = start_pos
    end

    local content = table.concat(vim.api.nvim_buf_get_text(curr_buffer,
                                                           start_pos[2] - 1,
                                                           start_pos[3] - 1,
                                                           end_pos[2] - 1,
                                                           end_pos[3] - 1, {}),
                                 '\n')

    local function substitute_placeholders(input)
        if not input then return end
        local text = input
        if string.find(text, "%$input") then
            local answer = vim.fn.input("Prompt: ")
            text = string.gsub(text, "%$input", answer)
        end

        if string.find(text, "%$register") then
            local register = vim.fn.getreg('"')
            if not register or register:match("^%s*$") then
                error("Prompt uses $register but yank register is empty")
            end

            text = string.gsub(text, "%$register", register)
        end

        text = string.gsub(text, "%$text", content)
        text = string.gsub(text, "%$filetype", vim.bo.filetype)
        return text
    end

    local prompt = opts.prompt

    if type(prompt) == "function" then
        prompt = prompt({content = content, filetype = vim.bo.filetype})
    end

    prompt = vim.fn.shellescape(substitute_placeholders(prompt))
    local extractor = substitute_placeholders(opts.extract)
    local cmd = opts.command
    cmd = string.gsub(cmd, "%$prompt", prompt)
    cmd = string.gsub(cmd, "%$model", opts.model)
    if result_buffer then vim.cmd('bd' .. result_buffer) end
    local win_opts = vim.tbl_deep_extend('force', get_window_options(),
                                         opts.win_config)
    result_buffer = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_option(result_buffer, 'filetype', 'markdown')

    local float_win = vim.api.nvim_open_win(result_buffer, true, win_opts)

    local result_string = ''
    local lines = {}
    local job_id
    job_id = vim.fn.jobstart(cmd, {
        on_stdout = function(_, data, _)
            -- window was closed, so cancel the job
            if not vim.api.nvim_win_is_valid(float_win) then
                vim.fn.jobstop(job_id)
                return
            end
            result_string = result_string .. table.concat(data, '\n')
            lines = vim.split(result_string, '\n', true)
            vim.api.nvim_buf_set_lines(result_buffer, 0, -1, false, lines)
            vim.api.nvim_win_call(float_win, function()
                vim.fn.feedkeys('$')
            end)
        end,
        on_exit = function(a, b)
            if b == 0 and opts.replace then
                if extractor then
                    local extracted = result_string:match(extractor)
                    if not extracted then
                        vim.cmd('bd ' .. result_buffer)
                        return
                    end
                    lines = vim.split(extracted, '\n', true)
                end
                lines = trim_table(lines)
                vim.api.nvim_buf_set_text(curr_buffer, start_pos[2] - 1,
                                          start_pos[3] - 1, end_pos[2] - 1,
                                          end_pos[3] - 1, lines)
                vim.cmd('bd ' .. result_buffer)
            end
        end
    })
    vim.keymap.set('n', '<esc>', function() vim.fn.jobstop(job_id) end,
                   {buffer = result_buffer})

    vim.api.nvim_buf_attach(result_buffer, false,
                            {on_detach = function() result_buffer = nil end})

end

M.win_config = {}

M.prompts = prompts
function select_prompt(cb)
    local promptKeys = {}
    for key, _ in pairs(M.prompts) do table.insert(promptKeys, key) end
    table.sort(promptKeys)
    vim.ui.select(promptKeys, {
        prompt = 'Prompt:',
        format_item = function(item)
            return table.concat(vim.split(item, '_'), ' ')
        end
    }, function(item, idx) cb(item) end)
end

vim.api.nvim_create_user_command('Gen', function(arg)
    local mode
    if arg.range == 0 then
        mode = 'n'
    else
        mode = 'v'
    end
    if arg.args ~= '' then
        local prompt = M.prompts[arg.args]
        if not prompt then
            print("Invalid prompt '" .. arg.args .. "'")
            return
        end
        p = vim.tbl_deep_extend('force', {mode = mode}, prompt)
        return M.exec(p)
    end
    select_prompt(function(item)
        if not item then return end
        p = vim.tbl_deep_extend('force', {mode = mode}, M.prompts[item])
        M.exec(p)
    end)

end, {
    range = true,
    nargs = '?',
    complete = function(ArgLead, CmdLine, CursorPos)
        local promptKeys = {}
        for key, _ in pairs(M.prompts) do
            if key:lower():match("^" .. ArgLead:lower()) then
                table.insert(promptKeys, key)
            end
        end
        table.sort(promptKeys)
        return promptKeys
    end
})

return M
