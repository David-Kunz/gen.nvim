-- lua/gen/core/writer.lua
local M = {}

function M.write_to_buffer(lines, globals)
    if not globals.result_buffer or not vim.api.nvim_buf_is_valid(globals.result_buffer) then
        return
    end

    -- Leemos las líneas actuales en el buffer
    local all_lines = vim.api.nvim_buf_get_lines(globals.result_buffer, 0, -1, false)
    local last_row = #all_lines
    local last_row_content = all_lines[last_row] or ""
    local last_col = #last_row_content

    -- Unimos las líneas nuevas en un string
    local text = table.concat(lines or {}, "\n")

    -- Marcamos como modificable
    vim.api.nvim_set_option_value("modifiable", true, { buf = globals.result_buffer })

    -- Insertamos texto al final
    vim.api.nvim_buf_set_text(
        globals.result_buffer,
        last_row - 1,
        last_col,
        last_row - 1,
        last_col,
        vim.split(text, "\n")
    )

    -- Ajustamos cursor
    if globals.float_win and vim.api.nvim_win_is_valid(globals.float_win) then
        local cursor_pos = vim.api.nvim_win_get_cursor(globals.float_win)
        if cursor_pos[1] == last_row then
            local new_last_row = last_row + #lines - 1
            vim.api.nvim_win_set_cursor(globals.float_win, { new_last_row, 0 })
        end
    end

    -- Volvemos a inmodificable
    vim.api.nvim_set_option_value("modifiable", false, { buf = globals.result_buffer })
end

return M
