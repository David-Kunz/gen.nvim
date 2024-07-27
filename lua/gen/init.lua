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
    model = "mistral",
    host = "localhost",
    port = "11434",
    debug = false,
    body = {stream = true},
    show_prompt = false,
    show_model = false,
    quit_map = "q",
    accept_map = "<c-cr>",
    retry_map = "<c-r>",
    command = function(options)
        return "curl --silent --no-buffer -X POST http://" .. options.host ..
                   ":" .. options.port .. "/api/chat -d $body"
    end,
    json_response = true,
    display_mode = "float",
    no_auto_close = false,
    init = function() pcall(io.popen, "ollama serve > /dev/null 2>&1 &") end,
    list_models = function(options)
        local response = vim.fn.systemlist(
                             "curl --silent --no-buffer http://" .. options.host ..
                                 ":" .. options.port .. "/api/tags")
        local list = vim.fn.json_decode(response)
        local models = {}
        for key, _ in pairs(list.models) do
            table.insert(models, list.models[key].name)
        end
        table.sort(models)
        return models
    end
}
for k, v in pairs(default_options) do M[k] = v end

M.setup = function(opts) for k, v in pairs(opts) do M[k] = v end end

local function reset()
    M.result_buffer = nil
    M.float_win = nil
    M.result_string = ""
    M.context = nil
    M.context_buffer = nil
end

local function close_window(buffer, opts)
    local lines = {}
    if opts.extract then
        local extracted = M.result_string:match(opts.extract)
        if not extracted then
            if not opts.no_auto_close then
                vim.api.nvim_win_hide(M.float_win)
                vim.api.nvim_buf_delete(M.result_buffer, {force = true})
                reset()
            end
            return
        end
        lines = vim.split(extracted, "\n", {trimempty = true})
    else
        lines = vim.split(M.result_string, "\n", {trimempty = true})
    end
    lines = trim_table(lines)
    vim.api.nvim_buf_set_text(curr_buffer, start_pos[2] - 1, start_pos[3] - 1,
                              end_pos[2] - 1, end_pos[3] > start_pos[3] and
                                  end_pos[3] or end_pos[3] - 1, lines)
    if not opts.no_auto_close then
        if M.float_win ~= nil then vim.api.nvim_win_hide(M.float_win) end
        if M.result_buffer ~= nil then
            vim.api.nvim_buf_delete(M.result_buffer, {force = true})
        end
        reset()
    end
end

local function get_window_options()
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
        border = "rounded"
    }
end

local function write_to_buffer(lines)
    if not M.result_buffer or not vim.api.nvim_buf_is_valid(M.result_buffer) then
        return
    end

    local all_lines = vim.api.nvim_buf_get_lines(M.result_buffer, 0, -1, false)

    local last_row = #all_lines
    local last_row_content = all_lines[last_row]
    local last_col = string.len(last_row_content)

    local text = table.concat(lines or {}, "\n")

    vim.api.nvim_set_option_value("modifiable", true, {buf = M.result_buffer})
    vim.api.nvim_buf_set_text(M.result_buffer, last_row - 1, last_col,
                              last_row - 1, last_col, vim.split(text, "\n"))
    -- Move the cursor to the end of the new lines
    local new_last_row = last_row + #lines - 1
    vim.api.nvim_win_set_cursor(M.float_win, {new_last_row, 0})

    vim.api.nvim_set_option_value("modifiable", false, {buf = M.result_buffer})
end

local function create_window(cmd, opts)
    local function setup_split()
        M.result_buffer = vim.fn.bufnr("%")
        M.float_win = vim.fn.win_getid()
        vim.api.nvim_set_option_value("filetype", "markdown",
                                      {buf = M.result_buffer})
        vim.api.nvim_set_option_value("buftype", "nofile",
                                      {buf = M.result_buffer})
        vim.api.nvim_set_option_value("wrap", true, {win = M.float_win})
        vim.api.nvim_set_option_value("linebreak", true, {win = M.float_win})
    end
    if M.display_mode == "float" then
        if M.result_buffer then
            vim.api.nvim_buf_delete(M.result_buffer, {force = true})
        end
        local win_opts = vim.tbl_deep_extend("force", get_window_options(),
                                             opts.win_config)
        M.result_buffer = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_set_option_value("filetype", "markdown",
                                      {buf = M.result_buffer})

        M.float_win = vim.api.nvim_open_win(M.result_buffer, true, win_opts)
    elseif M.display_mode == "horizontal-split" then
        vim.cmd("split gen.nvim")
        setup_split()
    else
        vim.cmd("vnew gen.nvim")
        setup_split()
    end
    vim.keymap.set("n", M.quit_map, "<cmd>quit<cr>", {buffer = M.result_buffer})
    vim.keymap.set("n", M.accept_map, function()
        opts.replace = true
        close_window(0, opts)
    end, {buffer = M.result_buffer})
    vim.keymap.set("n", M.retry_map, function()
        vim.api.nvim_win_close(0, true)
        M.run_command(cmd, opts)
    end, {buffer = M.result_buffer})
end

M.exec = function(options)
    local opts = vim.tbl_deep_extend("force", M, options)

    if type(opts.init) == 'function' then opts.init(opts) end

    if M.result_buffer ~= vim.fn.winbufnr(0) then
        curr_buffer = vim.fn.winbufnr(0)
        local mode = opts.mode or vim.fn.mode()
        if mode == "v" or mode == "V" then
            start_pos = vim.fn.getpos("'<")
            end_pos = vim.fn.getpos("'>")
            local max_col = vim.api.nvim_win_get_width(0)
            if end_pos[3] > max_col then
                end_pos[3] = vim.fn.col("'>") - 1
            end -- in case of `V`, it would be maxcol instead
        else
            local cursor = vim.fn.getpos(".")
            start_pos = cursor
            end_pos = start_pos
        end
    end

    local content = table.concat(vim.api.nvim_buf_get_text(curr_buffer,
                                                           start_pos[2] - 1,
                                                           start_pos[3] - 1,
                                                           end_pos[2] - 1,
                                                           end_pos[3], {}), "\n")

    local function substitute_placeholders(input)
        if not input then return input end
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
        if type(prompt) ~= 'string' or string.len(prompt) == 0 then
            return
        end
    end

    prompt = substitute_placeholders(prompt)
    opts.extract = substitute_placeholders(opts.extract)
    prompt = string.gsub(prompt, "%%", "%%%%")

    M.result_string = ""

    local cmd

    opts.json = function(body)
        local json = vim.fn.json_encode(body)
        json = vim.fn.shellescape(json)
        if vim.o.shell == 'cmd.exe' then
            json = string.gsub(json, '\\\"\"', '\\\\\\\"')
        end
        return json
    end

    opts.prompt = prompt

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
        local body = vim.tbl_extend("force",
                                    {model = opts.model, stream = true},
                                    opts.body)
        local messages = {}
        if M.context then messages = M.context end
        -- Add new prompt to the context
        table.insert(messages, {role = "user", content = prompt})
        body.messages = messages
        if M.model_options ~= nil then -- llamacpp server - model options: eg. temperature, top_k, top_p
            body = vim.tbl_extend("force", body, M.model_options)
        end
        if opts.model_options ~= nil then -- override model options from gen command (if exist)
            body = vim.tbl_extend("force", body, opts.model_options)
        end

        local json = opts.json(body)
        cmd = string.gsub(cmd, "%$body", json)
    end

    if M.context ~= nil then write_to_buffer({"", "", "---", ""}) end

    M.run_command(cmd, opts)

end

M.run_command = function(cmd, opts)
    if M.result_buffer == nil or M.float_win == nil or
        not vim.api.nvim_win_is_valid(M.float_win) then
        create_window(cmd, opts)
        if opts.show_model then
            write_to_buffer({"# Chat with " .. opts.model, ""})
        end
    end
    local partial_data = ""
    if opts.debug then print(cmd) end

    Job_id = vim.fn.jobstart(cmd, {
        -- stderr_buffered = opts.debug,
        on_stdout = function(_, data, _)
            -- window was closed, so cancel the job
            if not M.float_win or not vim.api.nvim_win_is_valid(M.float_win) then
                if Job_id then vim.fn.jobstop(Job_id) end
                if M.result_buffer then
                    vim.api.nvim_buf_delete(M.result_buffer, {force = true})
                end
                reset()
                return
            end
            if opts.debug then vim.print('Response data: ', data) end
            for _, line in ipairs(data) do
                partial_data = partial_data .. line
                if line:sub(-1) == "}" then
                    partial_data = partial_data .. "\n"
                end
            end

            local lines = vim.split(partial_data, "\n", {trimempty = true})

            partial_data = table.remove(lines) or ""

            for _, line in ipairs(lines) do
                Process_response(line, Job_id, opts.json_response)
            end

            if partial_data:sub(-1) == "}" then
                Process_response(partial_data, Job_id, opts.json_response)
                partial_data = ""
            end
        end,
        on_stderr = function(_, data, _)
            if opts.debug then
                -- window was closed, so cancel the job
                if not M.float_win or not vim.api.nvim_win_is_valid(M.float_win) then
                    if Job_id then vim.fn.jobstop(Job_id) end
                    return
                end

                if data == nil or #data == 0 then return end

                M.result_string = M.result_string .. table.concat(data, "\n")
                local lines = vim.split(M.result_string, "\n")
                write_to_buffer(lines)
            end
        end,
        on_exit = function(_, b)
            if b == 0 and opts.replace and M.result_buffer then
                close_window(b, opts)
            end
        end
    })

    local group = vim.api.nvim_create_augroup("gen", {clear = true})
    vim.api.nvim_create_autocmd('WinClosed', {
        buffer = M.result_buffer,
        group = group,
        callback = function()
            if Job_id then vim.fn.jobstop(Job_id) end
            if M.result_buffer then
                vim.api.nvim_buf_delete(M.result_buffer, {force = true})
            end
            reset()
        end
    })

    if opts.show_prompt then
        local lines = vim.split(opts.prompt, "\n")
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

    vim.keymap.set("n", "<esc>", function() vim.fn.jobstop(Job_id) end,
                   {buffer = M.result_buffer})

    vim.api.nvim_buf_attach(M.result_buffer, false,
                            {on_detach = function() M.result_buffer = nil end})
end

M.win_config = {}

M.prompts = prompts
local function select_prompt(cb)
    local promptKeys = {}
    for key, _ in pairs(M.prompts) do table.insert(promptKeys, key) end
    table.sort(promptKeys)
    vim.ui.select(promptKeys, {
        prompt = "Prompt:",
        format_item = function(item)
            return table.concat(vim.split(item, "_"), " ")
        end
    }, function(item) cb(item) end)
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
        local p = vim.tbl_deep_extend("force", {mode = mode}, prompt)
        return M.exec(p)
    end
    select_prompt(function(item)
        if not item then return end
        local p = vim.tbl_deep_extend("force", {mode = mode}, M.prompts[item])
        M.exec(p)
    end)
end, {
    range = true,
    nargs = "?",
    complete = function(ArgLead)
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

function Process_response(str, job_id, json_response)
    if string.len(str) == 0 then return end
    local text

    if json_response then
        -- llamacpp response string -- 'data: {"content": "hello", .... }' -- remove 'data: ' prefix, before json_decode
        if string.sub(str, 1, 6) == "data: " then
            str = string.gsub(str, "data: ", "", 1)
        end
        local success, result = pcall(function()
            return vim.fn.json_decode(str)
        end)

        if success then
            if result.message and result.message.content then -- ollama chat endpoint
                local content = result.message.content
                text = content

                M.context = M.context or {}
                M.context_buffer = M.context_buffer or ""
                M.context_buffer = M.context_buffer .. content

                -- When the message sequence is complete, add it to the context
                if result.done then
                    table.insert(M.context, {
                        role = "assistant",
                        content = M.context_buffer
                    })
                    -- Clear the buffer as we're done with this sequence of messages
                    M.context_buffer = ""
                end
            elseif result.choices then -- groq chat endpoint
                local choice = result.choices[1]
                local content = choice.delta.content
                text = content

                if content ~= nil then
                    M.context = M.context or {}
                    M.context_buffer = M.context_buffer or ""
                    M.context_buffer = M.context_buffer .. content
                end

                -- When the message sequence is complete, add it to the context
                if choice.finish_reason == "stop" then
                    table.insert(M.context, {
                        role = "assistant",
                        content = M.context_buffer
                    })
                    -- Clear the buffer as we're done with this sequence of messages
                    M.context_buffer = ""
                end
            elseif result.content then -- llamacpp version
                text = result.content
                if result.content then M.context = result.content end
            elseif result.response then -- ollama generate endpoint
                text = result.response
                if result.context then M.context = result.context end
            end
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

M.select_model = function()
    local models = M.list_models(M)
    vim.ui.select(models, {prompt = "Model:"}, function(item)
        if item ~= nil then
            print("Model set to " .. item)
            M.model = item
        end
    end)
end

return M
