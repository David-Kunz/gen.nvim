-- lua/gen/core/command.lua
local globals = require("gen.utils.globals")
local placeholders = require("gen.core.placeholders")

local M = {}

-- Genera el prompt final (sustituyendo placeholders),
-- compone el JSON body y devuelve el comando resultante (cmd).
function M.prepare_prompt_and_command(opts, content, globals)
    -- 1) Resolvemos el prompt (si es tabla, usamos opts.language)
    local prompt = opts.prompt
    if type(prompt) == "table" then
        prompt = prompt[opts.language]
        if not prompt then
            print("No prompt defined for language '" .. opts.language .. "'.")
            return nil
        end
    end

    -- 2) Si prompt es función, llamarla
    if type(prompt) == "function" then
        prompt = prompt({ content = content, filetype = vim.bo.filetype })
    end

    if not prompt or prompt == "" then
        return nil
    end

    -- 3) Sustitución de placeholders
    prompt = placeholders.substitute_placeholders(prompt, content)
    opts.extract = placeholders.substitute_placeholders(opts.extract, content)

    -- Reiniciamos la cadena de resultados
    globals.result_string = ""

    -- 4) Determinar comando final (string)
    local cmd
    if type(opts.command) == "function" then
        cmd = opts.command(opts)
    else
        cmd = opts.command
    end

    -- Sustituimos $model si aparece en cmd
    cmd = string.gsub(cmd, "%$model", opts.model)

    -- Si aparece $prompt, lo escapamos
    if string.find(cmd, "%$prompt") then
        local escaped = vim.fn.shellescape(prompt)
        cmd = string.gsub(cmd, "%$prompt", escaped)
    end

    -- 5) Si aparece $body, armamos el JSON
    if string.find(cmd, "%$body") then
        local body = vim.tbl_extend("force", { model = opts.model, stream = true }, opts.body or {})

        -- Añadimos la conversación
        local messages = globals.context or {}
        table.insert(messages, { role = "user", content = prompt })
        body.messages = messages

        -- Combinar más opciones de modelo
        if opts.model_options then
            body = vim.tbl_extend("force", body, opts.model_options)
        end

        -- Función para json_encode
        opts.json = opts.json
            or function(obj, shellescape)
                local encoded = vim.fn.json_encode(obj)
                if shellescape then
                    encoded = vim.fn.shellescape(encoded)
                end
                return encoded
            end

        -- Decidimos si guardar a un archivo temporal
        if opts.file then
            local json_str = opts.json(body, false)
            globals.temp_filename = os.tmpname()
            local f = io.open(globals.temp_filename, "w")
            if f then
                f:write(json_str)
                f:close()
            end
            cmd = string.gsub(cmd, "%$body", "@" .. globals.temp_filename)
        else
            local json_str = opts.json(body, true)
            cmd = string.gsub(cmd, "%$body", json_str)
        end
    end

    -- Guardamos el prompt final
    opts.prompt = prompt

    return cmd, prompt
end

return M
