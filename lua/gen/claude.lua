local M = {}

M.Process_response_claude = function(str, job_id, json_response, globals, write_to_buffer)
    if string.len(str) == 0 then
        write_to_buffer({ "Warning: Received empty string" })
        return
    end
    local text

    if json_response then
        local data_packet = str:sub(2, -2)
        if data_packet == "" then
            write_to_buffer({ "Warning: Empty data packet after trimming" })
            return
        end
        local success, result = pcall(function()
            return vim.fn.json_decode(data_packet)
        end)
        if not success then
            write_to_buffer({ "Error decoding JSON: " .. tostring(result) })
            -- return
        end
        write_to_buffer({ "\n", result[1], "\n" })

        if success then
            if result.candidates then
                local content = result.candidates[1].content.parts[1].text
                if content then
                    text = content

                    globals.context = globals.context or {}
                    globals.context_buffer = globals.context_buffer or ""
                    globals.context_buffer = globals.context_buffer .. content

                    if result.done then
                        table.insert(globals.context, {
                            role = "model",
                            content = globals.context_buffer,
                        })
                        globals.context_buffer = ""
                    end
                else
                    print("No text in this candidate's first part")
                end
            else
                print("No text in the first part")
                write_to_buffer({ "data", result.data, "" })
            end
        else
            write_to_buffer({ "", "====== ERROR ====", str, "-------------", "" })
            vim.fn.jobstop(job_id)
        end
    else
        text = str
    end

    if text == nil then
        return
    end

    globals.result_string = globals.result_string .. text
    local lines = vim.split(text, "\n")
    write_to_buffer(lines)
end

M.handle_claude_response = function(data, job_id, opts, globals, write_to_buffer)
    local json_string = data[1]
    if opts.debug then
        write_to_buffer({ "---Raw JSON---", json_string, "--------" })
    end

    local success, json_data = pcall(vim.fn.json_decode, json_string)
    if not success then
        write_to_buffer({ "Error parsing JSON: " .. tostring(json_data) })
        return
    end

    if opts.debug then
        write_to_buffer({ "Parsed structure:", vim.inspect(json_data), "" })
    end

    -- Handle different response structures
    if type(json_data) == "string" then
        -- If json_data is still a string, try parsing it again
        success, json_data = pcall(vim.fn.json_decode, json_data)
        if not success then
            write_to_buffer({ "Error parsing inner JSON: " .. tostring(json_data) })
            return
        end
    end

    if json_data.data then
        write_to_buffer({ json_data.data })
    elseif json_data.content then
        write_to_buffer({ json_data.content })
    elseif json_data.text then
        write_to_buffer({ json_data.text })
    elseif json_data.message then
        write_to_buffer({ json_data.message })
    else
        write_to_buffer({ "Unexpected response structure:", vim.inspect(json_data) })
    end

    -- Accumulate response in globals for context
    globals.result_string = (globals.result_string or "")
        .. (json_data.data or json_data.content or json_data.text or json_data.message or "")

    -- Check if this is the end of the response
    if json_data.done or json_data.is_final then
        write_to_buffer({ "---Response Complete---" })
        -- Here you might want to add the accumulated response to the context
        if globals.context then
            table.insert(globals.context, {
                role = "assistant",
                content = globals.result_string,
            })
        end
        globals.result_string = "" -- Reset for next response
    end
end

M.model_config = {
    process_response = M.Process_response_claude,
    prepare_body = M.prepare_body,
}

M.default_options = {
    model = "gemini-1.5-pro",
    project = "your-project",
    location = "us-central1",
    host = "aiplatform.googleapis.com",
    port = "443",
}

M.setup = function(opts)
    M.default_options = vim.tbl_deep_extend("force", M.default_options, opts or {})
end

M.prepare_body = function(opts, prompt, globals)
    local body = vim.tbl_extend("force", {}, opts.body)
    -- local contents = {}
    -- -- if globals.context then
    -- --     contents = globals.context
    -- -- end

    local cwd = vim.fn.getcwd()

    local excludePattern = [[
  **/*.{png,jpg,jpeg,gif,svg,mp4,webm,avi,mp3,wav,flac,zip,tar,gz,bz2,7z,iso,bin,exe,app,dmg,deb,rpm,apk,fig,xd,blend,fbx,obj,tmp,swp,
    lock,DS_Store,sqlite,log,sqlite3,dll,woff,woff2,ttf,eot,otf,ico,icns,csv,doc,docx,ppt,pptx,xls,xlsx,pdf,cmd,bat,dat,baseline,ps1,bin,exe,app,tmp,diff,bmp,ico},
      **/{.editorconfig,.eslintignore,.eslintrc,tsconfig.json,.gitignore,.npmrc,LICENSE,esbuild.config.mjs,manifest.json,package-lock.json,
        version-bump.mjs,versions.json,yarn.lock,CONTRIBUTING.md,CHANGELOG.md,SECURITY.md,.nvmrc,.env,.env.production,.prettierrc,.prettierignore,.stylelintrc,
        CODEOWNERS,commitlint.config.js,renovate.json,pre-commit-config.yaml,.vimrc,poetry.lock,changelog.md,contributing.md,.pretterignore,.pretterrc.json,
        .pretterrc.yml,.pretterrc.js,.eslintrc.js,.eslintrc.json,.eslintrc.yml,.eslintrc.yaml,.stylelintrc.js,.stylelintrc.json,.stylelintrc.yml,.stylelintrc.yaml},
              **/{screenshots,dist,node_modules,.git,.github,.vscode,build,coverage,tmp,out,temp,logs,__pycache__,.aider*,.venv,venv,.pdm*.avante*}/**
    ]]

    local temp_file = os.tmpname()
    local cmd = string.format(
        "code2prompt %s  --exclude '%s' --relative-paths --no-codeblock --output %s",
        vim.fn.shellescape(cwd),
        vim.fn.shellescape(excludePattern),
        vim.fn.shellescape(temp_file)
    )
    local success, result = pcall(vim.fn.system, cmd)
    if not success then
        print("Error: Unable to execute code2prompt command: " .. tostring(result))
        os.remove(temp_file)
        return nil
    end

    local codebase_content = {}
    local file, err = io.open(temp_file, "r")
    if file then
        codebase_content = file:read("*all")
        file:close()
        os.remove(temp_file)
    else
        print("Warning: Unable to read temporary file. Proceeding without codebase context. Error: " .. tostring(err))
    end
    local cleaned_prompt = prompt:gsub("\\'", "")
    local cleaned_codebase = codebase_content:gsub("\\'", "")

    local system_instruction = ""
    if opts.system_instruction ~= nil then
        system_instruction = opts.system_instruction
    else
        system_instruction = M.default_options.system_instruction
    end

    body.data = {
        system = system_instruction,
        codebase = #codebase_content > 0 and cleaned_codebase or "",
        prompt = cleaned_prompt,
    }

    return body
end

return M
