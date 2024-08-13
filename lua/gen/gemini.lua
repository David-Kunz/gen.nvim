local M = {}

M.Process_response_gemini = function(str, job_id, json_response, context, context_buffer, result_string, write_to_buffer)
    if string.len(str) == 0 then
        return nil, context, context_buffer, result_string
    end
    local text

    if json_response then
        if string.sub(str, 1, 6) == "data: " then
            str = string.gsub(str, "data: ", "", 1)
        end
        local success, result = pcall(function()
            return vim.fn.json_decode(str)
        end)

        if success then
            if result.candidates then
                local content = result.candidates[1].content.parts[1].text
                if content then
                    text = content

                    context = context or {}
                    context_buffer = context_buffer or ""
                    context_buffer = context_buffer .. content

                    if result.done then
                        table.insert(context, {
                            role = "assistant",
                            content = context_buffer,
                        })
                        context_buffer = ""
                    end
                else
                    print("No text in this candidate's first part")
                end
            else
                print("No text in the first part")
            end
        else
            write_to_buffer({ "", "====== ERROR ====", str, "-------------", "" })
            vim.fn.jobstop(job_id)
        end
    else
        text = str
    end

    if text == nil then
        return nil, context, context_buffer, result_string
    end

    result_string = result_string .. text
    local lines = vim.split(text, "\n")
    write_to_buffer(lines)

    return lines, context, context_buffer, result_string
end

M.prepare_body = function(body, prompt, context)
    local contents = {}
    if context then
        contents = context
    end
    table.insert(contents, { role = "user", parts = { { text = prompt } } })
    body.contents = contents
    return body
end

M.model_config = {
    process_response = M.Process_response_gemini,
    prepare_body = M.prepare_body,
}

return M
