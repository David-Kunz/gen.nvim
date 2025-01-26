local globals = require("gen.utils.globals")

local function reset(keep_selection)
    if not keep_selection then
        globals.curr_buffer = nil
        globals.start_pos = nil
        globals.end_pos = nil
    end
    if globals.job_id then
        vim.fn.jobstop(globals.job_id)
        globals.job_id = nil
    end
    globals.result_buffer = nil
    globals.float_win = nil
    globals.result_string = ""
    globals.context = nil
    globals.context_buffer = nil
    if globals.temp_filename then
        os.remove(globals.temp_filename)
        globals.temp_filename = nil
    end
end

return reset
