-- lua/gen/core/placeholders.lua
local M = {}

-- Recibe un string 'text' con tokens ($input, $register, etc.)
-- y 'content' que sustituye a $text.
function M.substitute_placeholders(text, content)
    if not text then
        return text
    end

    -- 1) $input -> prompt que pide al usuario
    if string.find(text, "%$input") then
        local answer = vim.fn.input("Prompt: ")
        text = string.gsub(text, "%$input", answer)
    end

    -- 2) $register_X
    text = string.gsub(text, '%$register_([%w*+:/"])', function(r_name)
        local regval = vim.fn.getreg(r_name)
        if not regval or regval:match("^%s*$") then
            error("Prompt uses $register_" .. r_name .. " but register is empty")
        end
        return regval
    end)

    -- 3) $register
    if string.find(text, "%$register") then
        local regval = vim.fn.getreg('"')
        if not regval or regval:match("^%s*$") then
            error("Prompt uses $register but yank register is empty")
        end
        text = string.gsub(text, "%$register", regval)
    end

    -- 4) Sustituir $text y $filetype
    --    Ojo con los '%' en content
    content = string.gsub(content, "%%", "%%%%")
    text = string.gsub(text, "%$text", content)
    text = string.gsub(text, "%$filetype", vim.bo.filetype)

    -- 5) Finalmente escapar '%'
    text = string.gsub(text, "%%", "%%%%")

    return text
end

return M
