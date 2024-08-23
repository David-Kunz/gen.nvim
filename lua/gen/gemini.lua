local M = {}

M.Process_response_gemini = function(str, job_id, json_response, globals, write_to_buffer)
    if string.len(str) == 0 then
        return
    end
    local text

    if json_response then
        local success, result = pcall(function()
            return vim.fn.json_decode(str)
        end)
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

M.handle_gemini_response = function(data, job_id, opts, globals, write_to_buffer)
    local json_string = data[1]
    if opts.debug then
        write_to_buffer({ "---json1---", json_string, "--------" })
    end
    json_string = json_string:gsub("^data: ", "")
    json_string = json_string:gsub("\r$", "")

    if opts.debug then
        write_to_buffer({ "---json2---", json_string, "--------" })
    end
    local json_data = vim.fn.json_decode(json_string)

    if json_data.candidates then
        -- Check if 'content' and 'parts' exist within the first candidate
        if json_data.candidates[1].content and json_data.candidates[1].content.parts then
            write_to_buffer({ json_data.candidates[1].content.parts[1].text })
        else
            if opts.debug then
                write_to_buffer({
                    "---CANDIDATE_FORMAT_ERROR---",
                    "Candidate is missing 'content' or 'parts'",
                    "--------",
                })
            end
            -- {"usageMetadata": {"promptTokenCount": 13495,"candidatesTokenCount": 525,"totalTokenCount": 14020}}
            if json_data.usageMetadata then
                write_to_buffer({ "\n\n------------", "promptTokenCount: ", json_data.usageMetadata.promptTokenCount })
                write_to_buffer({ "", "totalTokenCount: ", json_data.usageMetadata.totalTokenCount })
            end
        end
    else
        write_to_buffer({ "---NO CANDIDATES---", json_data, "--------" })
    end

    -- if json_data.candidates then
    --     write_to_buffer({ json_data.candidates[1].content.parts[1].text })
    -- else
    --     write_to_buffer({ "---NO CANDIDATES---", json_data, "--------" })
    -- end
end

M.model_config = {
    process_response = M.Process_response_gemini,
    prepare_body = M.prepare_body,
}

M.default_options = {
    model = "gemini-1.5-pro",
    project = "your-project",
    location = "us-central1",
    host = "aiplatform.googleapis.com",
    system_instruction = "You are a professional programmer.",
    port = "443",
    command = function(options)
        local access_token = vim.fn.system("gcloud auth print-access-token"):gsub("\n", "")
        return "curl --silent --no-buffer -X POST "
            .. "https://"
            .. options.location
            .. "-"
            .. options.host
            .. "/v1/projects/"
            .. options.project
            .. "/locations/"
            .. options.location
            .. "/publishers/google/models/"
            .. options.model
            .. ":streamGenerateContent "
            .. "-H 'Authorization: Bearer "
            .. access_token
            .. "' "
            .. "-H 'Content-Type: application/json' "
            .. "-d $body"
    end,
}

M.setup = function(opts)
    M.default_options = vim.tbl_deep_extend("force", M.default_options, opts or {})
end

M.prepare_body = function(opts, prompt, globals)
    local body = vim.tbl_extend("force", {}, opts.body)
    local contents = {}
    if globals.context then
        contents = globals.context
    end

    -- Add system instruction --
    local system_instruction = ""
    if opts.system_instruction ~= nil then
        system_instruction = opts.system_instruction
    else
        system_instruction = M.default_options.system_instruction
    end

    local cwd = vim.fn.getcwd()

    local excludePattern = [[
  **/*.{png,jpg,jpeg,gif,svg,mp4,webm,avi,mp3,wav,flac,zip,tar,gz,bz2,7z,iso,bin,exe,app,dmg,deb,rpm,apk,fig,xd,blend,fbx,obj,tmp,swp,\
    lock,DS_Store,sqlite,log,sqlite3,dll,woff,woff2,ttf,eot,otf,ico,icns,csv,doc,docx,ppt,pptx,xls,xlsx,pdf,cmd,bat,dat,baseline,ps1,bin,exe,app,tmp,diff,bmp,ico},
      **/{.editorconfig,.eslintignore,.eslintrc,tsconfig.json,.gitignore,.npmrc,LICENSE,esbuild.config.mjs,manifest.json,package-lock.json,\
        version-bump.mjs,versions.json,yarn.lock,CONTRIBUTING.md,CHANGELOG.md,SECURITY.md,.nvmrc,.env,.env.production,.prettierrc,.prettierignore,.stylelintrc,\
        CODEOWNERS,commitlint.config.js,renovate.json,pre-commit-config.yaml,.vimrc,poetry.lock,changelog.md,contributing.md,.pretterignore,.pretterrc.json,\
        .pretterrc.yml,.pretterrc.js,.eslintrc.js,.eslintrc.json,.eslintrc.yml,.eslintrc.yaml,.stylelintrc.js,.stylelintrc.json,.stylelintrc.yml,.stylelintrc.yaml},
              **/{screenshots,dist,node_modules,.git,.github,.vscode,build,coverage,tmp,out,temp,logs,__pycache__,.aider*,.venv,venv,.pdm*.avante*}/**
    ]]

    -- Get output directly from code2prompt
    local fileExtensions = vim.fn.input("File extensions for c2p (i.e. *.go,*.html): ")
    local cmd = string.format(
        "code2prompt %s --json --include '%s' --exclude '%s' --include-priority --relative-paths --diff",
        cwd,
        fileExtensions,
        excludePattern
    )
    local handle = io.popen(cmd)
    local codebase_content
    if handle then
        codebase_content = handle:read("*a")
        local success, exit_type, exit_code = handle:close()
        if not success then
            print("Error: c2p command failed. Exit type:", exit_type, "Exit code:", exit_code)
            return nil
        end
        if codebase_content == "" then
            print("Error: c2p command returned empty result")
            return nil
        end
        -- Print the second line of codebase_content
        local lines = vim.split(codebase_content, "\n")
        if #lines >= 2 then
            -- print("Second line of codebase_content:", lines[2])
        else
            print("codebase_content has less than 2 lines")
        end
    else
        print("Error: Unable to execute c2p command")
        return nil
    end

    -- Combine system_instruction and codebase_content
    -- local combined_system_instruction =
    --     string.format("%s\n\n<codebase>%s</codebase>\n\n", system_instruction, codebase_content)
    body.systemInstruction = { role = "user", parts = { { text = system_instruction } } }

    -- Add combined content and new prompt to the context
    -- local combined_prompt = string.format("<codebase>%s</codebase>\n\n%s", codebase_content, prompt)
    table.insert(contents, {
        role = "user",
        parts = {
            { text = string.format("<context>%s</context>", codebase_content) },
            { text = prompt },
        },
    })
    body.contents = contents

    if M.model_options ~= nil then -- llamacpp server - model options: eg. temperature, top_k, top_p
        body = vim.tbl_extend("force", body, M.model_options)
    end
    if opts.model_options ~= nil then -- override model options from gen command (if exist)
        body = vim.tbl_extend("force", body, opts.model_options)
    end

    return body
end

return M
