local prompts = require("gen.prompts")
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

local default_options = {
    model = "mistral:instruct",
    debug = false,
    show_prompt = false,
    show_model = false,
    command = 'curl --silent --no-buffer -X POST http://localhost:11434/api/generate -d $body',
    json_response = true,
    no_auto_close = false,
    display_mode = "float",
    no_auto_close = false,
    init = function() pcall(io.popen, "ollama serve > /dev/null 2>&1 &") end
}
for k, v in pairs(default_options) do M[k] = v end

M.setup = function(opts) for k, v in pairs(opts) do M[k] = v end end

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
        relative = "cursor",
        width = new_win_width,
        height = new_win_height,
        row = new_win_row,
        col = 0,
        style = "minimal",
        border = "single"
    }
end

function write_to_buffer(lines)
    if not M.result_buffer or not vim.api.nvim_buf_is_valid(M.result_buffer) then
        return
    end

    local all_lines = vim.api.nvim_buf_get_lines(M.result_buffer, 0, -1, false)

    local last_row = #all_lines
    local last_row_content = all_lines[last_row]
    local last_col = string.len(last_row_content)

    local text = table.concat(lines or {}, "\n")

    vim.api.nvim_buf_set_option(M.result_buffer, "modifiable", true)
    vim.api.nvim_buf_set_text(M.result_buffer, last_row - 1, last_col,
                              last_row - 1, last_col, vim.split(text, "\n"))
    vim.api.nvim_buf_set_option(M.result_buffer, "modifiable", false)
end

function create_window(opts)
    if M.display_mode == "float" then
        if M.result_buffer then
            vim.api.nvim_buf_delete(M.result_buffer, {force = true})
        end
        local win_opts = vim.tbl_deep_extend("force", get_window_options(),
                                             opts.win_config)
        M.result_buffer = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_option(M.result_buffer, "filetype", "markdown")

        M.float_win = vim.api.nvim_open_win(M.result_buffer, true, win_opts)
    else
        vim.cmd("vnew gen.nvim")
        M.result_buffer = vim.fn.bufnr("%")
        M.float_win = vim.fn.win_getid()
        vim.api.nvim_buf_set_option(M.result_buffer, "filetype", "markdown")
        vim.api.nvim_buf_set_option(M.result_buffer, "buftype", "nofile")
        vim.api.nvim_win_set_option(M.float_win, "wrap", true)
    end
end

function reset()
    M.result_buffer = nil
    M.float_win = nil
    M.result_string = ""
    M.context = nil
end

M.exec = function(options)
    local opts = vim.tbl_deep_extend("force", M, options)

    if type(opts.init) == 'function' then opts.init(opts) end

    curr_buffer = vim.fn.bufnr("%")
    local mode = opts.mode or vim.fn.mode()
    if mode == "v" or mode == "V" then
        start_pos = vim.fn.getpos("'<")
        end_pos = vim.fn.getpos("'>")
        end_pos[3] = vim.fn.col("'>") -- in case of `V`, it would be maxcol instead
    else
        local cursor = vim.fn.getpos(".")
        start_pos = cursor
        end_pos = start_pos
    end

    local content = table.concat(vim.api.nvim_buf_get_text(curr_buffer,
                                                           start_pos[2] - 1,
                                                           start_pos[3] - 1,
                                                           end_pos[2] - 1,
                                                           end_pos[3] - 1, {}),
                                 "\n")

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

        content = string.gsub(content, "%%", "%%%%")
        text = string.gsub(text, "%$text", content)
        text = string.gsub(text, "%$filetype", vim.bo.filetype)
        return text
    end

    local prompt = opts.prompt

    if type(prompt) == "function" then
        prompt = prompt({content = content, filetype = vim.bo.filetype})
    end

    prompt = substitute_placeholders(prompt)
    local extractor = substitute_placeholders(opts.extract)

    prompt = string.gsub(prompt, "%%", "%%%%")

    M.result_string = ""

    local cmd
    if type(opts.command) == 'function' then
        cmd = opts.command(opts)
    else
        cmd = M.command
    end

    if string.find(cmd, "%$prompt") then
        local prompt_escaped = vim.fn.shellescape(prompt)
        cmd = string.gsub(cmd, "%$prompt", prompt_escaped)
    end
    cmd = string.gsub(cmd, "%$model", opts.model)
    if string.find(cmd, "%$body") then
        local body = {model = opts.model, prompt = prompt, stream = true}
        if M.context then body.context = M.context end
        local json = vim.fn.json_encode(body)
        json = vim.fn.shellescape(json)
        cmd = string.gsub(cmd, "%$body", json)
    end

    if M.context ~= nil then write_to_buffer({"", "", "---", ""}) end

    local partial_data = ""
    if opts.debug then print(cmd) end

    if M.result_buffer == nil or M.float_win == nil or
        not vim.api.nvim_win_is_valid(M.float_win) then
        create_window(opts)
        if opts.show_model then
            write_to_buffer({"# Chat with " .. opts.model, ""})
        end
    end

    local job_id = vim.fn.jobstart(cmd, {
        -- stderr_buffered = opts.debug,
        on_stdout = function(_, data, _)
            -- window was closed, so cancel the job
            if not M.float_win or not vim.api.nvim_win_is_valid(M.float_win) then
                if job_id then vim.fn.jobstop(job_id) end
                if M.result_buffer then
                    vim.api.nvim_buf_delete(M.result_buffer, {force = true})
                end
                reset()
                return
            end

            for _, line in ipairs(data) do
                partial_data = partial_data .. line
                if line:sub(-1) == "}" then
                    partial_data = partial_data .. "\n"
                end
            end

            local lines = vim.split(partial_data, "\n", {trimempty = true})

            partial_data = table.remove(lines) or ""

            for _, line in ipairs(lines) do
                process_response(line, job_id, opts.json_response)
            end

            if partial_data:sub(-1) == "}" then
                process_response(partial_data, job_id, opts.json_response)
                partial_data = ""
            end
        end,
        on_stderr = function(_, data, _)
            if opts.debug then
                -- window was closed, so cancel the job
                if not M.float_win or not vim.api.nvim_win_is_valid(M.float_win) then
                    if job_id then vim.fn.jobstop(job_id) end
                    return
                end

                if data == nil or #data == 0 then return end

                M.result_string = M.result_string .. table.concat(data, "\n")
                local lines = vim.split(M.result_string, "\n")
                write_to_buffer(lines)
            end
        end,
        on_exit = function(a, b)
            if b == 0 and opts.replace and M.result_buffer then
                local lines = {}
                if extractor then
                    local extracted = M.result_string:match(extractor)
                    if not extracted then
                        if not opts.no_auto_close then
                            vim.api.nvim_win_hide(M.float_win)
                            vim.api.nvim_buf_delete(M.result_buffer,
                                                    {force = true})
                            reset()
                        end
                        return
                    end
                    lines = vim.split(extracted, "\n", true)
                else
                    lines = vim.split(M.result_string, "\n", true)
                end
                lines = trim_table(lines)
                vim.api.nvim_buf_set_text(curr_buffer, start_pos[2] - 1,
                                          start_pos[3] - 1, end_pos[2] - 1,
                                          end_pos[3] - 1, lines)
                if not opts.no_auto_close then
                    vim.api.nvim_win_hide(M.float_win)
                    vim.api.nvim_buf_delete(M.result_buffer, {force = true})
                    reset()
                end
            end
            M.result_string = ""
        end
    })

    local group = vim.api.nvim_create_augroup("gen", {clear = true})
    local event
    if opts.display_mode == 'float' then
        event = 'WinClosed'
    else
        event = 'BufDelete'
    end
    vim.api.nvim_create_autocmd(event, {
        buffer = M.result_buffer,
        group = group,
        callback = function()
            if job_id then vim.fn.jobstop(job_id) end
            if M.float_win ~= nil and vim.api.nvim_win_is_valid(M.float_win) then
                vim.api.nvim_win_close(M.float_win, true)
            end
            reset()
        end
    })

    if opts.show_prompt then
        local lines = vim.split(prompt, "\n")
        local short_prompt = {}
        for i = 1, #lines do
            lines[i] = "> " .. lines[i]
            table.insert(short_prompt, lines[i])
            if i >= 3 then
                if #lines > i then
                    table.insert(short_prompt, "...")
                end
                break
            end
        end
        local heading = "#"
        if M.show_model then heading = "##" end
        write_to_buffer({
            heading .. " Prompt:", "", table.concat(short_prompt, "\n"), "",
            "---", ""
        })
    end

    vim.keymap.set("n", "<esc>", function() vim.fn.jobstop(job_id) end,
                   {buffer = M.result_buffer})

    vim.api.nvim_buf_attach(M.result_buffer, false,
                            {on_detach = function() M.result_buffer = nil end})
end

M.win_config = {}

M.prompts = prompts
function select_prompt(cb)
    local promptKeys = {}
    for key, _ in pairs(M.prompts) do table.insert(promptKeys, key) end
    table.sort(promptKeys)
    vim.ui.select(promptKeys, {
        prompt = "Prompt:",
        format_item = function(item)
            return table.concat(vim.split(item, "_"), " ")
        end
    }, function(item, idx) cb(item) end)
end

vim.api.nvim_create_user_command("Gen", function(arg)
    local mode
    if arg.range == 0 then
        mode = "n"
    else
        mode = "v"
    end
    if arg.args ~= "" then
        local prompt = M.prompts[arg.args]
        if not prompt then
            print("Invalid prompt '" .. arg.args .. "'")
            return
        end
        p = vim.tbl_deep_extend("force", {mode = mode}, prompt)
        return M.exec(p)
    end
    select_prompt(function(item)
        if not item then return end
        p = vim.tbl_deep_extend("force", {mode = mode}, M.prompts[item])
        M.exec(p)
    end)
end, {
    range = true,
    nargs = "?",
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

function process_response(str, job_id, json_response)
    if string.len(str) == 0 then return end
    local text

    if json_response then
        local success, result = pcall(function()
            return vim.fn.json_decode(str)
        end)

        if success then
            text = result.response
            if result.context ~= nil then M.context = result.context end
        else
            write_to_buffer({"", "====== ERROR ====", str, "-------------", ""})
            vim.fn.jobstop(job_id)
        end
    else
        text = str
    end

    if text == nil then return end

    M.result_string = M.result_string .. text
    local lines = vim.split(text, "\n")
    write_to_buffer(lines)

end

return M
