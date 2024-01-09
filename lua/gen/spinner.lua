local M = {}

local spinner = {
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
}

local spinner_index = 1 -- to keep track of the spinner frame
local spinner_shown = false -- to keep track if spinner is already shown
local spinner_timer = nil -- timer for updating the spinner
local interval = 120 -- spinner update interval in ms

local function update_spinner()
    local spinner_frame = spinner[spinner_index]
    spinner_index = spinner_index % #spinner + 1
    print(spinner_frame)
end

M.show_spinner = function()
    if not spinner_shown then
        vim.notify("Generating...", vim.log.levels.INFO, { title = "Gen.nvim" })
        spinner_timer = vim.loop.new_timer()
        spinner_timer:start(interval, interval, vim.schedule_wrap(update_spinner))
        spinner_shown = true
    end
end

M.hide_spinner = function()
    if spinner_shown then
        vim.notify("Done!", vim.log.levels.INFO, { title = "Gen.nvim" })
        spinner_shown = false
        if spinner_timer == nil then
            return
        end
        spinner_timer:stop()
        spinner_timer:close()
        spinner_timer = nil
    end
end

return M
