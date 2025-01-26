-- lua/gen/core/prepare_options.lua
local M = {}

-- Combina opciones por defecto (base_config) con las del usuario (user_options).
-- Aplica alguna lógica adicional si opts.hidden es true.
function M.prepare_options(base_config, user_options)
    local opts = vim.tbl_deep_extend("force", base_config, user_options or {})
    if opts.hidden then
        opts.display_mode = "float"
        opts.replace = true
    end
    return opts
end

-- Exporta con un nombre más corto también
return M.prepare_options
