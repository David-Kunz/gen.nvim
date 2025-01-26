local reset = require("gen.utils.reset")
local trim_table = require("gen.utils.trim_table")
local globals = require("gen.utils.globals")

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

return close_window
