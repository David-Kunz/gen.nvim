-- lua/gen/core/response.lua
local globals = require("gen.utils.globals")
local writer = require("gen.core.writer")

local M = {}

function M.process_response(str, json_response)
    if #str == 0 then
        return
    end

    local text
    if json_response then
        -- Caso: es JSON -> intentamos decodificar
        -- Se quita el prefijo 'data: ' si aparece
        if str:sub(1, 6) == "data: " then
            str = str:gsub("data: ", "", 1)
        end

        local success, result = pcall(function()
            return vim.fn.json_decode(str)
        end)

        if success then
            -- Ollama chat endpoint
            if result.message and result.message.content then
                text = result.message.content
                globals.context = globals.context or {}
                globals.context_buffer = globals.context_buffer or ""
                globals.context_buffer = globals.context_buffer .. text
                if result.done then
                    table.insert(globals.context, {
                        role = "assistant",
                        content = globals.context_buffer,
                    })
                    globals.context_buffer = ""
                end

            -- Groq chat endpoint
            elseif result.choices then
                local choice = result.choices[1]
                text = choice.delta.content
                if text then
                    globals.context = globals.context or {}
                    globals.context_buffer = globals.context_buffer or ""
                    globals.context_buffer = globals.context_buffer .. text
                end
                if choice.finish_reason == "stop" then
                    table.insert(globals.context, {
                        role = "assistant",
                        content = globals.context_buffer,
                    })
                    globals.context_buffer = ""
                end

            -- llamacpp version
            elseif result.content then
                text = result.content
                globals.context = result.content

            -- ollama generate endpoint
            elseif result.response then
                text = result.response
                if result.context then
                    globals.context = result.context
                end
            end
        else
            writer.write_to_buffer({ "", "====== ERROR ====", str, "-------------", "" }, globals)
            if globals.job_id then
                vim.fn.jobstop(globals.job_id)
            end
        end
    else
        text = str
    end

    if not text then
        return
    end

    -- Añadimos el texto a la variable result_string
    globals.result_string = globals.result_string .. text

    -- Dividimos por líneas y escribimos al buffer
    local lines = vim.split(text, "\n")
    writer.write_to_buffer(lines, globals)
end

return M
