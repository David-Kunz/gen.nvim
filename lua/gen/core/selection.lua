-- lua/gen/core/selection.lua
local M = {}

-- Guarda en 'globals' el buffer y las posiciones de inicio/fin
-- según modo visual (v/V) o cursor normal.
function M.store_selection(opts, globals)
    -- Solo si el buffer donde vamos a mostrar el resultado (result_buffer)
    -- NO coincide con el buffer actual (winbufnr(0)).
    if globals.result_buffer ~= vim.fn.winbufnr(0) then
        globals.curr_buffer = vim.fn.winbufnr(0)
        local mode = opts.mode or vim.fn.mode()

        if mode == "v" or mode == "V" then
            globals.start_pos = vim.fn.getpos("'<")
            globals.end_pos = vim.fn.getpos("'>")
            local max_col = vim.api.nvim_win_get_width(0)
            if globals.end_pos[3] > max_col then
                globals.end_pos[3] = vim.fn.col("'>") - 1
            end
        else
            local cursor = vim.fn.getpos(".")
            globals.start_pos = cursor
            globals.end_pos = cursor
        end
    end
end

-- Devuelve el contenido (string) según la selección. Si no hay selección,
-- devuelve el contenido entero del buffer actual.
function M.get_content(globals)
    if not globals.start_pos or not globals.end_pos then
        return ""
    end

    if globals.start_pos[2] == globals.end_pos[2] and globals.start_pos[3] == globals.end_pos[3] then
        -- Sin selección -> texto de todo el buffer
        return table.concat(vim.api.nvim_buf_get_lines(globals.curr_buffer, 0, -1, false), "\n")
    else
        return table.concat(
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
end

return M
