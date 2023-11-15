local prompts = require("gen.prompts")
local M = {}

local curr_buffer = nil
local start_pos = nil
local end_pos = nil

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

M.command = "ollama run $model $prompt"
M.model = "mistral:instruct"
M.container = nil
M.debugCommand = false

local commandContainer = "docker exec $container ollama run $model $prompt"

M.exec = function(options)
    if M.container ~= nil and M.command == "ollama run $model $prompt" then
        M.command = commandContainer
    end
    local opts = vim.tbl_deep_extend("force", {
        model = M.model,
        command = M.command,
        container = M.container,
        debugCommand = M.debugCommand,
        win_config = M.win_config,
    }, options)
    if opts.container ~= nil then
        pcall(io.popen, "docker start " .. opts.container)
    else
        pcall(io.popen, "ollama serve > /dev/null 2>&1 &")
    end
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

    local content = table.concat(
        vim.api.nvim_buf_get_text(curr_buffer, start_pos[2] - 1, start_pos[3] - 1, end_pos[2] - 1, end_pos[3] - 1, {}),
        "\n"
    )

    local function substitute_placeholders(input)
        if not input then
            return
        end
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
        prompt = prompt({ content = content, filetype = vim.bo.filetype })
    end

    prompt = substitute_placeholders(prompt)
    local extractor = substitute_placeholders(opts.extract)
    local cmd = opts.command
    prompt = string.gsub(prompt, "%%", "%%%%")
    cmd = string.gsub(cmd, "%$prompt", prompt)
    cmd = string.gsub(cmd, "%$model", opts.model)
    if opts.container ~= nil then
        cmd = string.gsub(cmd, "%$container", opts.container)
    end
    if M.result_buffer == nil then
        vim.cmd("vnew")
        M.result_buffer = vim.fn.bufnr("%")
        M.float_win = vim.fn.win_getid()
        vim.api.nvim_buf_set_option(M.result_buffer, "filetype", "markdown")
        vim.api.nvim_win_set_option(M.float_win, "wrap", true)
    end

    local result_string = ""
    local lines = {}
    local job_id
    local data = {
        model = opts.model,
        prompt = prompt,
        stream = false,
    }

    if M.context then
        data.context = M.context
    end

    local json = vim.fn.json_encode(data)
    cmd = "curl -X POST http://localhost:11434/api/generate -d '" .. json .. "'"

    vim.api.nvim_buf_set_option(M.result_buffer, "modifiable", true)
    vim.api.nvim_buf_set_lines(
        M.result_buffer,
        -1,
        -1,
        false,
        vim.split("```text\n================\n" .. prompt .. "\n================\n```\n", "\n")
    )
    vim.api.nvim_buf_set_option(M.result_buffer, "modifiable", false)
    vim.fn.feedkeys("G")
    job_id = vim.fn.jobstart(cmd, {
        on_stdout = function(_, data, _)
            -- window was closed, so cancel the job
            if not vim.api.nvim_win_is_valid(M.float_win) then
                vim.fn.jobstop(job_id)
                vim.cmd("bd " .. M.result_buffer)
                M.result_buffer = nil
                M.float_win = nil
                return
            end

            local body = vim.fn.json_decode(table.concat(data, "\n"))

            result_string = result_string .. table.concat(data, "\n")
            lines = vim.split(result_string, "\n", true)
            lines = vim.split(body.response .. "\n", "\n")
            vim.api.nvim_buf_set_option(M.result_buffer, "modifiable", true)
            vim.api.nvim_buf_set_lines(M.result_buffer, -1, -1, false, lines)
            vim.api.nvim_buf_set_option(M.result_buffer, "modifiable", false)
            vim.fn.feedkeys("G")
            M.context = body.context
        end,
        on_stderr = function(_, data, _)
            if opts.debugCommand then
                -- window was closed, so cancel the job
                if not vim.api.nvim_win_is_valid(M.float_win) then
                    vim.fn.jobstop(job_id)
                    return
                end
                result_string = result_string .. table.concat(data, "\n")
                lines = vim.split(result_string, "\n", true)
                vim.api.nvim_buf_set_lines(M.result_buffer, -1, -1, false, lines)
            end
        end,
        on_exit = function(a, b)
            if b == 0 and opts.replace then
                if extractor then
                    local extracted = result_string:match(extractor)
                    if not extracted then
                        vim.cmd("bd " .. M.result_buffer)
                        M.result_buffer = nil
                        M.float_win = nil
                        return
                    end
                    lines = vim.split(extracted, "\n", true)
                end
                lines = trim_table(lines)
                vim.api.nvim_buf_set_text(
                    curr_buffer,
                    start_pos[2] - 1,
                    start_pos[3] - 1,
                    end_pos[2] - 1,
                    end_pos[3] - 1,
                    lines
                )
                vim.cmd("bd " .. M.result_buffer)
                M.result_buffer = nil
                M.float_win = nil
            end
        end,
    })
    vim.keymap.set("n", "<esc>", function()
        vim.fn.jobstop(job_id)
    end, { buffer = M.result_buffer })

    vim.api.nvim_buf_attach(M.result_buffer, false, {
        on_detach = function()
            M.result_buffer = nil
        end,
    })
end

M.win_config = {}

M.prompts = prompts
function select_prompt(cb)
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
    }, function(item, idx)
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
        p = vim.tbl_deep_extend("force", { mode = mode }, prompt)
        return M.exec(p)
    end
    select_prompt(function(item)
        if not item then
            return
        end
        p = vim.tbl_deep_extend("force", { mode = mode }, M.prompts[item])
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
    end,
})

return M
