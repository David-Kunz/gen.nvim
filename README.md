# gen.nvim

Generate text using LLMs with customizable prompts

<div align="center">

![gen_nvim](https://github.com/David-Kunz/gen.nvim/assets/1009936/79f17157-9327-484a-811b-2d71ceb8fbe3)

</div>

## Video

<div align="center">

[![Local LLMs in Neovim: gen.nvim](https://user-images.githubusercontent.com/1009936/273126287-7b5f2b40-c678-47c5-8f21-edf9516f6034.jpg)](https://youtu.be/FIZt7MinpMY?si=KChSuJJDyrcTdYiM)

</div>

## Requires

- [Ollama](https://ollama.ai/) with an appropriate model, e.g. [`llama3.2`](https://ollama.com/library/llama3.2), [`mistral`](https://ollama.ai/library/mistral), etc.
- [Curl](https://curl.se/)

## Install

Install with your favorite plugin manager, e.g. [lazy.nvim](https://github.com/folke/lazy.nvim)

Example with Lazy

```lua
-- Minimal configuration
{ "David-Kunz/gen.nvim" },

```

```lua

-- Custom Parameters (with defaults)
{
    "David-Kunz/gen.nvim",
    opts = {
        model = "mistral", -- The default model to use.
        quit_map = "q", -- set keymap to close the response window
        retry_map = "<c-r>", -- set keymap to re-send the current prompt
        accept_map = "<c-cr>", -- set keymap to replace the previous selection with the last result
        host = "localhost", -- The host running the Ollama service.
        port = "11434", -- The port on which the Ollama service is listening.
        display_mode = "float", -- The display mode. Can be "float" or "split" or "horizontal-split".
        show_prompt = false, -- Shows the prompt submitted to Ollama. Can be true (3 lines) or "full".
        show_model = false, -- Displays which model you are using at the beginning of your chat session.
        no_auto_close = false, -- Never closes the window automatically.
        file = false, -- Write the payload to a temporary file to keep the command short.
        hidden = false, -- Hide the generation window (if true, will implicitly set `prompt.replace = true`), requires Neovim >= 0.10
        init = function(options) pcall(io.popen, "ollama serve > /dev/null 2>&1 &") end,
        -- Function to initialize Ollama
        command = function(options)
            local body = {model = options.model, stream = true}
            return "curl --silent --no-buffer -X POST http://" .. options.host .. ":" .. options.port .. "/api/chat -d $body"
        end,
        -- The command for the Ollama service. You can use placeholders $prompt, $model and $body (shellescaped).
        -- This can also be a command string.
        -- The executed command must return a JSON object with { response, context }
        -- (context property is optional).
        -- list_models = '<omitted lua function>', -- Retrieves a list of model names
        result_filetype = "markdown", -- Configure filetype of the result buffer
        debug = false -- Prints errors and the command which is run.
    }
},
```

Here are all [available models](https://ollama.ai/library).

Alternatively, you can call the `setup` function:

```lua
require('gen').setup({
  -- same as above
})
```



## Usage

Use command `Gen` to generate text based on predefined and customizable prompts.

Example key maps:

```lua
vim.keymap.set({ 'n', 'v' }, '<leader>]', ':Gen<CR>')
```

You can also directly invoke it with one of the [predefined prompts](./lua/gen/prompts.lua) or your custom prompts:

```lua
vim.keymap.set('v', '<leader>]', ':Gen Enhance_Grammar_Spelling<CR>')
```

After a conversation begins, the entire context is sent to the LLM. That allows you to ask follow-up questions with

```lua
:Gen Chat
```

and once the window is closed, you start with a fresh conversation.

For prompts which don't automatically replace the previously selected text (`replace = false`), you can replace the selected text with the generated output with `<c-cr>`.

You can select a model from a list of all installed models with

```lua
require('gen').select_model()
```

## Custom Prompts

[All prompts](./lua/gen/prompts.lua) are defined in `require('gen').prompts`, you can enhance or modify them.

Example:
```lua
require('gen').prompts['Elaborate_Text'] = {
  prompt = "Elaborate the following text:\n$text",
  replace = true
}
require('gen').prompts['Fix_Code'] = {
  prompt = "Fix the following code. Only output the result in format ```$filetype\n...\n```:\n```$filetype\n$text\n```",
  replace = true,
  extract = "```$filetype\n(.-)```"
}
```

You can use the following properties per prompt:

- `prompt`: (string | function) Prompt either as a string or a function which should return a string. The result can use the following placeholders:
   - `$text`: Visually selected text or the content of the current buffer
   - `$filetype`: File type of the buffer (e.g. `javascript`)
   - `$input`: Additional user input
   - `$register`: Value of the unnamed register (yanked text)
- `replace`: `true` if the selected text shall be replaced with the generated output
- `extract`: Regular expression used to extract the generated result
- `model`: The model to use, default: `mistral`

## Tip

User selections can be delegated to [Telescope](https://github.com/nvim-telescope/telescope.nvim) with [telescope-ui-select](https://github.com/nvim-telescope/telescope-ui-select.nvim).
