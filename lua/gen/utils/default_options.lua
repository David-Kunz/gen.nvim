local default_options = {
    model = "mistral",
    thinking_model = "deepseek-r1",
    host = "localhost",
    port = "11434",
    file = false,
    debug = false,
    language = "en",
    body = { stream = true },
    show_prompt = false,
    show_model = false,
    quit_map = "q",
    accept_map = "<c-cr>",
    retry_map = "<c-r>",
    hidden = false,
    command = function(options)
        return "curl -q --silent --no-buffer -X POST http://"
            .. options.host
            .. ":"
            .. options.port
            .. "/api/chat -d $body"
    end,
    json_response = true,
    display_mode = "float",
    no_auto_close = false,
    init = function()
        pcall(io.popen, "ollama serve > /dev/null 2>&1 &")
    end,
    list_models = function(options)
        local response = vim.fn.systemlist(
            "curl -q --silent --no-buffer http://" .. options.host .. ":" .. options.port .. "/api/tags"
        )
        local list = vim.fn.json_decode(response)
        local models = {}
        for key, _ in pairs(list.models) do
            table.insert(models, list.models[key].name)
        end
        table.sort(models)
        return models
    end,
    result_filetype = "markdown",
}

return default_options
