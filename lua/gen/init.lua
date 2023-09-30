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

M.run_llm = function(prompt)
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
    local instruction = string.gsub(M.prompts[prompt], "%$text", content)
    local cmd = 'ollama run mistral:instruct """' .. instruction .. '"""'
    if result_buffer then vim.cmd('bd' .. result_buffer) end
    -- vim.cmd('vs enew')
    local width = math.floor(vim.o.columns * 0.9) -- 90% of the current editor's width
    local height = math.floor(vim.o.lines * 0.9)
    local row = math.floor((vim.o.lines - height) / 2)
    local col = math.floor((vim.o.columns - width) / 2)

    -- local opts = {
    --     relative = 'editor',
    --     width = width,
    --     height = height,
    --     row = row,
    --     col = col,
    --     style = 'minimal',
    --     border = 'single'
    -- }
    -- local buf = vim.api.nvim_create_buf(false, true)
    -- local float_win = vim.api.nvim_open_win(buf, true, opts)

    vim.cmd('vs enew')

    result_buffer = vim.fn.bufnr('%')
    local term_id = vim.fn.termopen(cmd .. '\n', {
        on_exit = function()
            local lines = vim.api
                              .nvim_buf_get_lines(result_buffer, 0, -1, false)
            lines = trim_table(lines)
            vim.api.nvim_buf_set_text(curr_buffer, start_pos[2] - 1,
                                      start_pos[3] - 1, end_pos[2] - 1,
                                      end_pos[3] - 1, lines)
            vim.cmd('bd' .. result_buffer)
            result_buffer = nil
        end
    })

end

M.prompts = {
    Summarize = "Summarize the following text: $text",
    FixGrammar = "Fix the grammar in the following text: $text"
}

vim.api.nvim_create_user_command('Gen', function()
    local promptKeys = {}
    for key, _ in pairs(M.prompts) do table.insert(promptKeys, key) end
    vim.ui.select(promptKeys, {prompt = 'Prompt:'},
                  function(item, idx) M.run_llm(item) end)

end, {range = true})

return M
