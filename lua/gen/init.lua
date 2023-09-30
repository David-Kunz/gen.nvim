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

M.run_llm = function(opts)
    curr_buffer = vim.fn.bufnr('%')
    start_pos = vim.fn.getpos("'<")
    end_pos = vim.fn.getpos("'>")
    end_pos[3] = vim.fn.col("'>") -- in case of `V`, it would be maxcol instead

    local content = table.concat(vim.api.nvim_buf_get_text(curr_buffer,
                                                           start_pos[2] - 1,
                                                           start_pos[3] - 1,
                                                           end_pos[2] - 1,
                                                           end_pos[3] - 1, {}),
                                 '\n')
    local text = vim.fn.shellescape(lines)
    local instruction = string.gsub(opts.prompt, "%$text", content)
    local cmd = 'ollama run mistral:instruct """' .. instruction .. '"""'
    if result_buffer then vim.cmd('bd' .. result_buffer) end
    -- vim.cmd('vs enew')
    local width = math.floor(vim.o.columns * 0.9) -- 90% of the current editor's width
    local height = math.floor(vim.o.lines * 0.9)
    local row = math.floor((vim.o.lines - height) / 2)
    local col = math.floor((vim.o.columns - width) / 2)

    local win_opts = {
        relative = 'editor',
        width = width,
        height = height,
        row = row,
        col = col,
        style = 'minimal',
        border = 'single'
    }
    local buf = vim.api.nvim_create_buf(false, true)
    local float_win = vim.api.nvim_open_win(buf, true, win_opts)
    result_buffer = vim.fn.bufnr('%')

    -- local output = {}
    -- local term_id = vim.fn.termopen(cmd .. '\n', {
    --     -- on_stdout = function(_, data, _)
    --     --   table.insert(output, data[1])
    --     -- end,
    --     on_exit = function(a,b,c)
    --         local lines = vim.api
    --                           .nvim_buf_get_lines(result_buffer, 0, -1, false)
    --         lines = trim_table(lines)
    --         vim.api.nvim_buf_set_text(curr_buffer, start_pos[2] - 1,
    --                                   start_pos[3] - 1, end_pos[2] - 1,
    --                                   end_pos[3] - 1, lines)
    --         vim.cmd('bd' .. result_buffer)
    --         result_buffer = nil
    --     end
    -- })
    -- local handle = io.popen(cmd)
    -- local result = handle:read("*a")
    -- handle:close()
    -- print(result)

    -- vim.api.nvim_buf_set_text(curr_buffer, start_pos[2] - 1,
    --                           start_pos[3] - 1, end_pos[2] - 1,
    --                           end_pos[3] - 1, vim.split(result, '\n'))

    local result_string = ''
    local lines = {}
    local job_id = vim.fn.jobstart(cmd, {
        on_stdout = function(_, data, _)
            result_string = result_string .. table.concat(data, '\n')
            lines = vim.split(result_string, '\n', true)
            vim.api.nvim_buf_set_lines(result_buffer, 0, -1, false, lines)
        end,
        on_exit = function(a, b)
            if b == 0 and opts.replace then
                lines = trim_table(lines)
                vim.api.nvim_buf_set_text(curr_buffer, start_pos[2] - 1,
                                          start_pos[3] - 1, end_pos[2] - 1,
                                          end_pos[3] - 1, lines)
            end
            vim.cmd('bd ' .. result_buffer)
            result_buffer = nil
        end
    })
    vim.keymap.set('n', '<esc>', function() vim.fn.jobstop(job_id) end,
                   {buffer = result_buffer})

end

M.prompts = {
    Summarize = {prompt = "Summarize the following text: $text", replace = true},
    FixGrammar = {
        prompt = "Fix the grammar in the following text: $text",
        replace = true
    },
    Enhance = {prompt = "Enhance the following text: $text", replace = true},
    Simplify = {prompt = "Simplify the following text: $text", replace = true}
}

vim.api.nvim_create_user_command('Gen', function()
    local promptKeys = {}
    for key, _ in pairs(M.prompts) do table.insert(promptKeys, key) end
    vim.ui.select(promptKeys, {prompt = 'Prompt:'},
                  function(item, idx) M.run_llm(M.prompts[item]) end)

end, {range = true})

return M
