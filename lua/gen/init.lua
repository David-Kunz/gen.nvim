-- lua/gen/init.lua
local globals = require("gen.utils.globals")
local default_opts = require("gen.utils.default_options")
local prepare_opts = require("gen.core.prepare_options")
local selection = require("gen.core.selection")
local command = require("gen.core.command")
local writer = require("gen.core.writer")
local response = require("gen.core.response")
local create_window = require("gen.window.create")
local close_window = require("gen.window.close")
local reset = require("gen.utils.reset")

-- Módulo con prompts
local prompts = require("gen.prompts")

local M = {}

-------------------------------------------------------------------
-- CONFIGURACIÓN INICIAL
-------------------------------------------------------------------
-- Copia de las opciones por defecto
M.config = {}
for k, v in pairs(default_opts) do
    M.config[k] = v
end

-- Para que el usuario pueda sobreescribir opciones
function M.setup(opts)
    if type(opts) == "table" then
        for k, v in pairs(opts) do
            M.config[k] = v
        end
    end
end

-------------------------------------------------------------------
-- FUNCIÓN PRINCIPAL: EXEC
-------------------------------------------------------------------
function M.exec(user_options)
    -- 1) Mezcla configuración por defecto con la recibida
    local opts = prepare_opts(M.config, user_options)

    -- 2) Llamada a init si existe
    if type(opts.init) == "function" then
        opts.init(opts)
    end

    -- 3) Guardamos posición del cursor (o selección visual)
    selection.store_selection(opts, globals)

    -- 4) Obtenemos el contenido a enviar (todo buffer o selección)
    local content = selection.get_content(globals)

    -- 5) Construimos prompt y comando (curl) final
    local cmd, prompt = command.prepare_prompt_and_command(opts, content, globals)
    if not cmd then
        return -- si no hay prompt válido, abortar
    end

    -- 6) Si hay contexto previo, añadimos separador en el buffer
    if globals.context then
        writer.write_to_buffer({ "", "", "---", "" }, globals)
    end

    -- 7) Llamamos a run_command
    M.run_command(cmd, opts)
end

-------------------------------------------------------------------
-- GESTIONAR EJECUCIÓN DE COMANDO
-------------------------------------------------------------------
function M.run_command(cmd, opts)
    -- Si no hay ventana abierta o buffer para resultados, creamos uno
    if (not globals.result_buffer) or not globals.float_win or (not vim.api.nvim_win_is_valid(globals.float_win)) then
        create_window(cmd, opts)
        if opts.show_model then
            writer.write_to_buffer({ "# Chat with " .. opts.model, "" }, globals)
        end
    end

    -- Acumulador de datos parciales
    local partial_data = ""

    if opts.debug then
        print("Gen command:", cmd)
    end

    -- Lanzamos el job (comando curl o lo que definas)
    globals.job_id = vim.fn.jobstart(cmd, {
        on_stdout = function(_, data, _)
            -- Si han cerrado la ventana, matamos el job
            if (not globals.float_win) or (not vim.api.nvim_win_is_valid(globals.float_win)) then
                if globals.job_id then
                    vim.fn.jobstop(globals.job_id)
                end
                if globals.result_buffer then
                    vim.api.nvim_buf_delete(globals.result_buffer, { force = true })
                end
                reset()
                return
            end

            -- Si debug, mostramos data
            if opts.debug then
                vim.print("Response data: ", data)
            end

            -- Acumula data en partial_data
            for _, line in ipairs(data) do
                partial_data = partial_data .. line
                if line:sub(-1) == "}" then
                    partial_data = partial_data .. "\n"
                end
            end

            local lines = vim.split(partial_data, "\n", { trimempty = true })
            partial_data = table.remove(lines) or ""

            for _, line in ipairs(lines) do
                response.process_response(line, opts.json_response)
            end

            -- Si partial_data acaba en "}", procesarlo también
            if partial_data:sub(-1) == "}" then
                response.process_response(partial_data, opts.json_response)
                partial_data = ""
            end
        end,
        on_stderr = function(_, data, _)
            if opts.debug then
                if not globals.float_win or not vim.api.nvim_win_is_valid(globals.float_win) then
                    if globals.job_id then
                        vim.fn.jobstop(globals.job_id)
                    end
                    return
                end
                if data and #data > 0 then
                    globals.result_string = globals.result_string .. table.concat(data, "\n")
                    local lines = vim.split(globals.result_string, "\n")
                    writer.write_to_buffer(lines, globals)
                end
            end
        end,
        on_exit = function(_, exit_code)
            -- Si exit_code=0 y opts.replace, cerramos ventana e insertamos
            if exit_code == 0 and opts.replace and globals.result_buffer then
                close_window(opts)
            end
        end,
    })

    -- Autocmd para cerrar job si cierran la ventana
    local group = vim.api.nvim_create_augroup("gen", { clear = true })
    vim.api.nvim_create_autocmd("WinClosed", {
        buffer = globals.result_buffer,
        group = group,
        callback = function()
            if globals.job_id then
                vim.fn.jobstop(globals.job_id)
            end
            if globals.result_buffer then
                vim.api.nvim_buf_delete(globals.result_buffer, { force = true })
            end
            reset(true) -- keep_selection = true
        end,
    })

    -- Mostrar prompt si se desea
    if opts.show_prompt then
        local lines = vim.split(opts.prompt or "", "\n", { trimempty = false })
        local short_prompt = {}
        for i = 1, #lines do
            lines[i] = "> " .. lines[i]
            table.insert(short_prompt, lines[i])
            if i >= 3 and opts.show_prompt ~= "full" then
                if #lines > i then
                    table.insert(short_prompt, "...")
                end
                break
            end
        end

        local heading = "#"
        if M.config.show_model then
            heading = "##"
        end

        writer.write_to_buffer({
            heading .. " Prompt:",
            "",
            table.concat(short_prompt, "\n"),
            "",
            "---",
            "",
        }, globals)
    end

    -- Cuando se “desatacha” (por si acaso)
    vim.api.nvim_buf_attach(globals.result_buffer, false, {
        on_detach = function()
            globals.result_buffer = nil
        end,
    })
end

-------------------------------------------------------------------
-- COMANDO USER: Gen
-------------------------------------------------------------------
vim.api.nvim_create_user_command("Gen", function(arg)
    local mode = (arg.range == 0) and "n" or "v"

    if arg.args ~= "" then
        -- Se pasa prompt como argumento
        local prompt_key = arg.args
        local prompt_obj = prompts[prompt_key]
        if not prompt_obj then
            print("Invalid prompt '" .. prompt_key .. "'")
            return
        end

        local prompt_text
        if type(prompt_obj.prompt) == "table" then
            prompt_text = prompt_obj.prompt[M.config.language]
            if not prompt_text then
                print("No prompt for language '" .. M.config.language .. "' in '" .. prompt_key .. "'.")
                return
            end
        else
            prompt_text = prompt_obj.prompt
        end

        -- Unir opciones
        local final_opts = vim.tbl_deep_extend("force", { mode = mode, prompt = prompt_text }, prompt_obj)
        M.exec(final_opts)
        return
    end

    -- Si no se pasa argumento, mostrar un menú de selección
    local promptKeys = {}
    for k, _ in pairs(prompts) do
        table.insert(promptKeys, k)
    end
    table.sort(promptKeys)

    vim.ui.select(promptKeys, {
        prompt = "Selecciona un Prompt:",
        format_item = function(item)
            -- solo hace un split para mejorar la legibilidad
            return table.concat(vim.split(item, "_"), " ")
        end,
    }, function(selected_prompt)
        if not selected_prompt then
            return
        end

        local prompt_obj = prompts[selected_prompt]
        if not prompt_obj then
            print("Prompt '" .. selected_prompt .. "' not found.")
            return
        end

        local prompt_text
        if type(prompt_obj.prompt) == "table" then
            prompt_text = prompt_obj.prompt[M.config.language]
            if not prompt_text then
                print("No prompt for language '" .. M.config.language .. "' in '" .. selected_prompt .. "'.")
                return
            end
        else
            prompt_text = prompt_obj.prompt
        end

        local final_opts = vim.tbl_deep_extend("force", { mode = mode, prompt = prompt_text }, prompt_obj)
        M.exec(final_opts)
    end)
end, {
    range = true,
    nargs = "?",
    complete = function(ArgLead)
        local completions = {}
        for key, _ in pairs(prompts) do
            if key:lower():match("^" .. ArgLead:lower()) then
                table.insert(completions, key)
            end
        end
        table.sort(completions)
        return completions
    end,
})

-------------------------------------------------------------------
-- COMANDO USER: TGen
-------------------------------------------------------------------
vim.api.nvim_create_user_command("TGen", function(arg)
    -- Al igual que Gen, detectamos si hay selección
    local mode = (arg.range == 0) and "n" or "v"

    -- Cambiamos a nuestro modelo "pensante"
    M.config.model = M.config.thinking_model

    if arg.args ~= "" then
        -- Se pasa prompt como argumento
        local prompt_key = arg.args
        local prompt_obj = prompts[prompt_key]
        if not prompt_obj then
            print("Invalid prompt '" .. prompt_key .. "'")
            -- restauramos el modelo original
            M.config.model = M.config.thinking_model
            return
        end

        local prompt_text
        if type(prompt_obj.prompt) == "table" then
            prompt_text = prompt_obj.prompt[M.config.language]
            if not prompt_text then
                print("No prompt for language '" .. M.config.language .. "' in '" .. prompt_key .. "'.")
                -- restauramos el modelo original
                M.config.model = M.config.thinking_model
                return
            end
        else
            prompt_text = prompt_obj.prompt
        end

        local final_opts = vim.tbl_deep_extend("force", { mode = mode, prompt = prompt_text }, prompt_obj)
        M.exec(final_opts)
    else
        -- Menú de selección si no se pasa prompt
        local promptKeys = {}
        for k, _ in pairs(prompts) do
            table.insert(promptKeys, k)
        end
        table.sort(promptKeys)

        vim.ui.select(promptKeys, {
            prompt = "Selecciona un Prompt (TGen):",
            format_item = function(item)
                return table.concat(vim.split(item, "_"), " ")
            end,
        }, function(selected_prompt)
            if not selected_prompt then
                M.config.model = M.config.thinking_model
                return
            end

            local prompt_obj = prompts[selected_prompt]
            if not prompt_obj then
                print("Prompt '" .. selected_prompt .. "' not found.")
                M.config.model = M.config.thinking_model
                return
            end

            local prompt_text
            if type(prompt_obj.prompt) == "table" then
                prompt_text = prompt_obj.prompt[M.config.language]
                if not prompt_text then
                    print("No prompt for language '" .. M.config.language .. "' in '" .. selected_prompt .. "'.")
                    M.config.model = M.config.thinking_model
                    return
                end
            else
                prompt_text = prompt_obj.prompt
            end

            local final_opts = vim.tbl_deep_extend("force", { mode = mode, prompt = prompt_text }, prompt_obj)
            M.exec(final_opts)
        end)
    end
end, {
    range = true,
    nargs = "?",
    complete = function(ArgLead)
        local completions = {}
        for key, _ in pairs(prompts) do
            if key:lower():match("^" .. ArgLead:lower()) then
                table.insert(completions, key)
            end
        end
        table.sort(completions)
        return completions
    end,
})

-------------------------------------------------------------------
-- CAMBIAR MODELO
-------------------------------------------------------------------
function M.select_model()
    local models = M.config.list_models(M.config)
    vim.ui.select(models, { prompt = "Model:" }, function(item)
        if item then
            print("Model set to " .. item)
            M.config.model = item
        end
    end)
end

return M
