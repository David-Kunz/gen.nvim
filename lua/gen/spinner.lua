local M = {}

-- User configuration section
local config = {
    -- Show notification when done.
    -- Set to false to disable.
    show_notification = true,
    -- Name of the plugin.
    plugin = "Gen.nvim",
    -- Spinner frames.
    spinner_frames = {
        "⠋",
        "⠙",
        "⠹",
        "⠸",
        "⠼",
        "⠴",
        "⠦",
        "⠧",
        "⠇",
        "⠏",
    },
}

local spinner_index = 1
local spinner_timer = nil
local spinner_buf = nil
local spinner_win = nil

--- Show a spinner at the specified position.
---@param position? table
function M.show_spinner(position)
    -- Default position the top right corner
    local default_position = {
        relative = "editor",
        width = 1,
        height = 1,
        col = vim.o.columns - 1,
        row = 0,
    }
    local options = position or default_position
    options.style = "minimal"

    -- Create buffer and window for the spinner
    spinner_buf = vim.api.nvim_create_buf(false, true)
    spinner_win = vim.api.nvim_open_win(spinner_buf, false, options)

    -- Set up timer and update spinner
    spinner_timer = vim.loop.new_timer()
    spinner_timer:start(
        0,
        100,
        vim.schedule_wrap(function()
            vim.api.nvim_buf_set_lines(spinner_buf, 0, -1, false, { config.spinner_frames[spinner_index] })
            spinner_index = spinner_index % #config.spinner_frames + 1
        end)
    )
end

--- Hide the spinner.
function M.hide_spinner()
    if spinner_timer then
        spinner_timer:stop()
        spinner_timer:close()
        spinner_timer = nil
        if spinner_win then
            vim.api.nvim_win_close(spinner_win, true)
        end
        if spinner_buf then
            vim.api.nvim_buf_delete(spinner_buf, { force = true })
        end

        if config.show_notification then
            vim.notify("Done!", vim.log.levels.INFO, { title = config.plugin })
        end
    end
end

return M
