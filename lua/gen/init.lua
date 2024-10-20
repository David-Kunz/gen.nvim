local prompts = require("gen.prompts")
local nvim_data_dir = vim.fn.stdpath("data")
local roo_path = nvim_data_dir .. "/gen"
local custom_prompts_path = roo_path .. "/prompts.json"
local function initialize_custom_prompts()
    if vim.fn.isdirectory(roo_path) then
        vim.fn.mkdir(roo_path)
    end
    local file = io.open(custom_prompts_path, "w")
    if file then
        file:write("{}")
        file:close()
    end
end
local function read_json_promts()
    local file = io.open(custom_prompts_path)
    if not file then
        initialize_custom_prompts()
        return {}
    end
    local content = file:read("*a")
    local ok, decoded = pcall(vim.json.decode, content)
    if not ok then
        vim.notify("Couldn't read custom prompt file at " .. custom_prompts_path, vim.log.levels.ERROR)
        return {}
    end
    return decoded
end
local function merge_tables(tbl_source, tbl_target)
    for key, value in pairs(tbl_source) do
        if type(value) == "table" and type(tbl_target[key]) == "table" then
            merge_tables(value, tbl_target[key])
        else
            tbl_target[key] = value
        end
    end
end
local custom_promts = read_json_promts()
merge_tables(custom_promts, prompts)
local M = {}

local globals = {}
local function reset(keep_selection)
    if not keep_selection then
        globals.curr_buffer = nil
        globals.start_pos = nil
        globals.end_pos = nil
    end
    globals.result_buffer = nil
    globals.float_win = nil
    globals.result_string = ""
    globals.context = nil
    globals.context_buffer = nil
    if globals.temp_filename then
        os.remove(globals.temp_filename)
        globals.temp_filename = nil
    end
end
reset()

local function trim_table(tbl)
    local function is_whitespace(str)
        return str:match("^%s*$") ~= nil
    end

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
    file = false,
    debug = false,
    body = { stream = true },
    show_prompt = false,
    show_model = false,
    quit_map = "q",
    accept_map = "<c-cr>",
    retry_map = "<c-r>",
    hidden = false,
    command = function(options)
        return "curl --silent --no-buffer -X POST http://"
            .. options.host
            .. ":"
            .. options.port
            .. "/api/chat -d $body"
    end,
    json_response = true,
    display_mode = "float",
    no_auto_close = false,
    init = function()
        pcall(io.popen, "ollama serve > /dev/null 2>&1 &")
    end,
    list_models = function(options)
        local response =
            vim.fn.systemlist("curl --silent --no-buffer http://" .. options.host .. ":" .. options.port .. "/api/tags")
        local list = vim.fn.json_decode(response)
        local models = {}
        for key, _ in pairs(list.models) do
            table.insert(models, list.models[key].name)
        end
        table.sort(models)
        return models
    end,
}
for k, v in pairs(default_options) do
    M[k] = v
end

M.setup = function(opts)
    for k, v in pairs(opts) do
        M[k] = v
    end
end

local function close_window(opts)
    local lines = {}
    if opts.extract then
        local extracted = globals.result_string:match(opts.extract)
        if not extracted then
            if not opts.no_auto_close then
                vim.api.nvim_win_hide(globals.float_win)
                if globals.result_buffer ~= nil then
                    vim.api.nvim_buf_delete(globals.result_buffer, { force = true })
                end
                reset()
            end
            return
        end
        lines = vim.split(extracted, "\n", { trimempty = true })
    else
        lines = vim.split(globals.result_string, "\n", { trimempty = true })
    end
    lines = trim_table(lines)
    vim.api.nvim_buf_set_text(
        globals.curr_buffer,
        globals.start_pos[2] - 1,
        globals.start_pos[3] - 1,
        globals.end_pos[2] - 1,
        globals.end_pos[3] > globals.start_pos[3] and globals.end_pos[3] or globals.end_pos[3] - 1,
        lines
    )
    -- in case another replacement happens
    globals.end_pos[2] = globals.start_pos[2] + #lines - 1
    globals.end_pos[3] = string.len(lines[#lines])
    if not opts.no_auto_close then
        if globals.float_win ~= nil then
            vim.api.nvim_win_hide(globals.float_win)
        end
        if globals.result_buffer ~= nil then
            vim.api.nvim_buf_delete(globals.result_buffer, { force = true })
        end
        reset()
    end
end

local function get_window_options(opts)
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

    local result = {
        relative = "cursor",
        width = new_win_width,
        height = new_win_height,
        row = new_win_row,
        col = 0,
        style = "minimal",
        border = "rounded",
    }

    local version = vim.version()
    if version.major > 0 or version.minor >= 10 then
        result.hide = opts.hidden
    end

    return result
end

local function write_to_buffer(lines)
    if not globals.result_buffer or not vim.api.nvim_buf_is_valid(globals.result_buffer) then
        return
    end

    local all_lines = vim.api.nvim_buf_get_lines(globals.result_buffer, 0, -1, false)

    local last_row = #all_lines
    local last_row_content = all_lines[last_row]
    local last_col = string.len(last_row_content)

    local text = table.concat(lines or {}, "\n")

    local cursor_pos = vim.api.nvim_win_get_cursor(globals.float_win)

    vim.api.nvim_set_option_value("modifiable", true, { buf = globals.result_buffer })
    vim.api.nvim_buf_set_text(
        globals.result_buffer,
        last_row - 1,
        last_col,
        last_row - 1,
        last_col,
        vim.split(text, "\n")
    )

    -- Move the cursor to the end of the new lines
    if cursor_pos[1] == last_row then
        local new_last_row = last_row + #lines - 1
        vim.api.nvim_win_set_cursor(globals.float_win, { new_last_row, 0 })
    end

    vim.api.nvim_set_option_value("modifiable", false, { buf = globals.result_buffer })
end

local function create_window(cmd, opts)
    local function setup_split()
        globals.result_buffer = vim.fn.bufnr("%")
        globals.float_win = vim.fn.win_getid()
        vim.api.nvim_set_option_value("filetype", "markdown", { buf = globals.result_buffer })
        vim.api.nvim_set_option_value("buftype", "nofile", { buf = globals.result_buffer })
        vim.api.nvim_set_option_value("wrap", true, { win = globals.float_win })
        vim.api.nvim_set_option_value("linebreak", true, { win = globals.float_win })
    end

    local display_mode = opts.display_mode or M.display_mode
    if display_mode == "float" then
        if globals.result_buffer then
            vim.api.nvim_buf_delete(globals.result_buffer, { force = true })
        end
        local win_opts = vim.tbl_deep_extend("force", get_window_options(opts), opts.win_config)
        globals.result_buffer = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_set_option_value("filetype", "markdown", { buf = globals.result_buffer })

        globals.float_win = vim.api.nvim_open_win(globals.result_buffer, true, win_opts)
    elseif display_mode == "horizontal-split" then
        vim.cmd("split gen.nvim")
        setup_split()
    else
        vim.cmd("vnew gen.nvim")
        setup_split()
    end
    vim.keymap.set("n", "<esc>", function()
        vim.fn.jobstop(Job_id)
    end, { buffer = globals.result_buffer })
    vim.keymap.set("n", M.quit_map, "<cmd>quit<cr>", { buffer = globals.result_buffer })
    vim.keymap.set("n", M.accept_map, function()
        opts.replace = true
        close_window(opts)
    end, { buffer = globals.result_buffer })
    vim.keymap.set("n", M.retry_map, function()
        vim.api.nvim_win_close(0, true)
        M.run_command(cmd, opts)
    end, { buffer = globals.result_buffer })
end

M.exec = function(options)
    local opts = vim.tbl_deep_extend("force", M, options)
    if opts.hidden then
        -- the only reasonable thing to do if no output can be seen
        opts.display_mode = "float" -- uses the `hide` option
        opts.replace = true
    end

    if type(opts.init) == "function" then
        opts.init(opts)
    end

    if globals.result_buffer ~= vim.fn.winbufnr(0) then
        globals.curr_buffer = vim.fn.winbufnr(0)
        local mode = opts.mode or vim.fn.mode()
        if mode == "v" or mode == "V" then
            globals.start_pos = vim.fn.getpos("'<")
            globals.end_pos = vim.fn.getpos("'>")
            local max_col = vim.api.nvim_win_get_width(0)
            if globals.end_pos[3] > max_col then
                globals.end_pos[3] = vim.fn.col("'>") - 1
            end -- in case of `V`, it would be maxcol instead
        else
            local cursor = vim.fn.getpos(".")
            globals.start_pos = cursor
            globals.end_pos = globals.start_pos
        end
    end

    local content
    if globals.start_pos == globals.end_pos then
        -- get text from whole buffer
        content = table.concat(vim.api.nvim_buf_get_lines(globals.curr_buffer, 0, -1, false), "\n")
    else
        content = table.concat(
            vim.api.nvim_buf_get_text(
                globals.curr_buffer,
                globals.start_pos[2] - 1,
                globals.start_pos[3] - 1,
                globals.end_pos[2] - 1,
                globals.end_pos[3],
                {}
            ),
            "\n"
        )
    end
    local function substitute_placeholders(input)
        if not input then
            return input
        end
        local text = input
        if string.find(text, "%$input") then
            local answer = vim.fn.input("Prompt: ")
            text = string.gsub(text, "%$input", answer)
        end

        text = string.gsub(text, '%$register_([%w*+:/"])', function(r_name)
            local register = vim.fn.getreg(r_name)
            if not register or register:match("^%s*$") then
                error("Prompt uses $register_" .. rname .. " but register " .. rname .. " is empty")
            end
            return register
        end)

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
        prompt = prompt({ content = content, filetype = vim.bo.filetype })
        if type(prompt) ~= "string" or string.len(prompt) == 0 then
            return
        end
    end

    prompt = substitute_placeholders(prompt)
    opts.extract = substitute_placeholders(opts.extract)
    prompt = string.gsub(prompt, "%%", "%%%%")

    globals.result_string = ""

    local cmd

    opts.json = function(body, shellescape)
        local json = vim.fn.json_encode(body)
        if shellescape then
            json = vim.fn.shellescape(json)
            if vim.o.shell == "cmd.exe" then
                json = string.gsub(json, '\\""', '\\\\\\"')
            end
        end
        return json
    end

    opts.prompt = prompt

    if type(opts.command) == "function" then
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
        local body = vim.tbl_extend("force", { model = opts.model, stream = true }, opts.body)
        local messages = {}
        if globals.context then
            messages = globals.context
        end
        -- Add new prompt to the context
        table.insert(messages, { role = "user", content = prompt })
        body.messages = messages
        if M.model_options ~= nil then -- llamacpp server - model options: eg. temperature, top_k, top_p
            body = vim.tbl_extend("force", body, M.model_options)
        end
        if opts.model_options ~= nil then -- override model options from gen command (if exist)
            body = vim.tbl_extend("force", body, opts.model_options)
        end

        if opts.file ~= nil then
            local json = opts.json(body, false)
            globals.temp_filename = os.tmpname()
            local fhandle = io.open(globals.temp_filename, "w")
            fhandle:write(json)
            fhandle:close()
            cmd = string.gsub(cmd, "%$body", "@" .. globals.temp_filename)
        else
            local json = opts.json(body, true)
            cmd = string.gsub(cmd, "%$body", json)
        end
    end

    if globals.context ~= nil then
        write_to_buffer({ "", "", "---", "" })
    end

    M.run_command(cmd, opts)
end

M.run_command = function(cmd, opts)
    if globals.result_buffer == nil or globals.float_win == nil or not vim.api.nvim_win_is_valid(globals.float_win) then
        create_window(cmd, opts)
        if opts.show_model then
            write_to_buffer({ "# Chat with " .. opts.model, "" })
        end
    end
    local partial_data = ""
    if opts.debug then
        print(cmd)
    end

    Job_id = vim.fn.jobstart(cmd, {
        -- stderr_buffered = opts.debug,
        on_stdout = function(_, data, _)
            -- window was closed, so cancel the job
            if not globals.float_win or not vim.api.nvim_win_is_valid(globals.float_win) then
                if Job_id then
                    vim.fn.jobstop(Job_id)
                end
                if globals.result_buffer then
                    vim.api.nvim_buf_delete(globals.result_buffer, { force = true })
                end
                reset()
                return
            end
            if opts.debug then
                vim.print("Response data: ", data)
            end
            for _, line in ipairs(data) do
                partial_data = partial_data .. line
                if line:sub(-1) == "}" then
                    partial_data = partial_data .. "\n"
                end
            end

            local lines = vim.split(partial_data, "\n", { trimempty = true })

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
                if not globals.float_win or not vim.api.nvim_win_is_valid(globals.float_win) then
                    if Job_id then
                        vim.fn.jobstop(Job_id)
                    end
                    return
                end

                if data == nil or #data == 0 then
                    return
                end

                globals.result_string = globals.result_string .. table.concat(data, "\n")
                local lines = vim.split(globals.result_string, "\n")
                write_to_buffer(lines)
            end
        end,
        on_exit = function(_, b)
            if b == 0 and opts.replace and globals.result_buffer then
                close_window(opts)
            end
        end,
    })

    local group = vim.api.nvim_create_augroup("gen", { clear = true })
    vim.api.nvim_create_autocmd("WinClosed", {
        buffer = globals.result_buffer,
        group = group,
        callback = function()
            if Job_id then
                vim.fn.jobstop(Job_id)
            end
            if globals.result_buffer then
                vim.api.nvim_buf_delete(globals.result_buffer, { force = true })
            end
            reset(true) -- keep selection in case of subsequent retries
        end,
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
        if M.show_model then
            heading = "##"
        end
        write_to_buffer({
            heading .. " Prompt:",
            "",
            table.concat(short_prompt, "\n"),
            "",
            "---",
            "",
        })
    end

    vim.api.nvim_buf_attach(globals.result_buffer, false, {
        on_detach = function()
            globals.result_buffer = nil
        end,
    })
end

M.win_config = {}

M.prompts = prompts
local function select_prompt(cb)
    local promptKeys = {}
    for key, _ in pairs(M.prompts) do
        table.insert(promptKeys, key)
    end
    table.sort(promptKeys)
    vim.ui.select(promptKeys, {
        prompt = "Prompt:",
        format_item = function(item)
            return table.concat(vim.split(item, "_"), " ")
        end,
    }, function(item)
        cb(item)
    end)
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
        local p = vim.tbl_deep_extend("force", { mode = mode }, prompt)
        return M.exec(p)
    end
    select_prompt(function(item)
        if not item then
            return
        end
        local p = vim.tbl_deep_extend("force", { mode = mode }, M.prompts[item])
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
    end,
})

local function validate_json(buffer)
    local content = table.concat(vim.api.nvim_buf_get_lines(buffer, 0, -1, false), "\n")
    local ok, decoded_json = pcall(vim.json.decode, content)
    if ok then
        return ok, decoded_json
    else
        return ok, "Invalid JSON, please fix it before saving!"
    end
end
vim.api.nvim_create_user_command("GenEditCustomPromts", function()
    local buf_list = vim.api.nvim_list_bufs()
    local existing_buf = nil
    for _, buf in ipairs(buf_list) do
        if vim.api.nvim_buf_is_loaded(buf) and vim.api.nvim_buf_get_name(buf) == custom_prompts_path then
            existing_buf = buf
            break
        end
    end
    -- Use existing buffer or create a new one
    local buffer
    if existing_buf then
        buffer = existing_buf
    else
        buffer = vim.api.nvim_create_buf(false, true) -- normal buffer
        vim.api.nvim_set_option_value("buftype", "", { buf = buffer })
        vim.api.nvim_set_option_value("filetype", "json", { buf = buffer })
        vim.api.nvim_set_option_value("modifiable", true, { buf = buffer })
        vim.api.nvim_set_option_value("readonly", false, { buf = buffer })
        vim.api.nvim_buf_set_name(buffer, custom_prompts_path)
    end
    vim.fn.bufload(buffer)
    local width = 80
    local height = 20
    local win = vim.api.nvim_open_win(buffer, true, {
        relative = "editor",
        width = width,
        height = height,
        row = math.ceil((vim.o.lines - height) / 2),
        col = math.ceil((vim.o.columns - width) / 2),
        border = "rounded",
        title = "Save and quit by pressing `" .. default_options.quit_map .. "`",
        title_pos = "center",
    })
    vim.keymap.set("n", M.quit_map, "<cmd>quit<cr>", { buffer = buffer })
    local file = io.open(custom_prompts_path, "r")
    if file then
        local content = vim.fn.readfile(custom_prompts_path)
        vim.api.nvim_buf_set_lines(buffer, 0, -1, false, content)
    else
        vim.api.nvim_buf_set_lines(buffer, 0, -1, false, { "{", "}" })
    end
    -- autocommand
    local augroup = vim.api.nvim_create_augroup("GenFloatEditor", { clear = true })
    vim.api.nvim_create_autocmd("BufLeave", {
        group = augroup,
        buffer = buffer,
        callback = function()
            local is_valid, decoded_json = validate_json(buffer)
            print("buff leave")
            if not is_valid then
                vim.notify("JSON is invalid. Will not save the changes!", vim.log.levels.WARN)
                vim.api.nvim_buf_delete(buffer, { force = true })
                return
            end
            -- Save file if JSON is valid
            local content = vim.api.nvim_buf_get_lines(buffer, 0, -1, false)
            vim.fn.writefile(content, custom_prompts_path)
            vim.api.nvim_buf_delete(buffer, { force = true })
            merge_tables(decoded_json, M.prompts)
        end,
    })
end, { desc = "Edit custom prompt json file", bang = true })

function Process_response(str, job_id, json_response)
    if string.len(str) == 0 then
        return
    end
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

                globals.context = globals.context or {}
                globals.context_buffer = globals.context_buffer or ""
                globals.context_buffer = globals.context_buffer .. content

                -- When the message sequence is complete, add it to the context
                if result.done then
                    table.insert(globals.context, {
                        role = "assistant",
                        content = globals.context_buffer,
                    })
                    -- Clear the buffer as we're done with this sequence of messages
                    globals.context_buffer = ""
                end
            elseif result.choices then -- groq chat endpoint
                local choice = result.choices[1]
                local content = choice.delta.content
                text = content

                if content ~= nil then
                    globals.context = globals.context or {}
                    globals.context_buffer = globals.context_buffer or ""
                    globals.context_buffer = globals.context_buffer .. content
                end

                -- When the message sequence is complete, add it to the context
                if choice.finish_reason == "stop" then
                    table.insert(globals.context, {
                        role = "assistant",
                        content = globals.context_buffer,
                    })
                    -- Clear the buffer as we're done with this sequence of messages
                    globals.context_buffer = ""
                end
            elseif result.content then -- llamacpp version
                text = result.content
                if result.content then
                    globals.context = result.content
                end
            elseif result.response then -- ollama generate endpoint
                text = result.response
                if result.context then
                    globals.context = result.context
                end
            end
        else
            write_to_buffer({ "", "====== ERROR ====", str, "-------------", "" })
            vim.fn.jobstop(job_id)
        end
    else
        text = str
    end

    if text == nil then
        return
    end

    globals.result_string = globals.result_string .. text
    local lines = vim.split(text, "\n")
    write_to_buffer(lines)
end

M.select_model = function()
    local models = M.list_models(M)
    vim.ui.select(models, { prompt = "Model:" }, function(item)
        if item ~= nil then
            print("Model set to " .. item)
            M.model = item
        end
    end)
end

return M
