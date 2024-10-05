Sure! Here's a refined version of the README to improve clarity and readability:

---

# gen.nvim

Generate text using LLMs with customizable prompts

![gen_nvim](https://github.com/David-Kunz/gen.nvim/assets/1009936/79f17157-9327-484a-811b-2d71ceb8fbe3)

## Video

[![Local LLMs in Neovim: gen.nvim](https://user-images.githubusercontent.com/1009936/273126287-7b5f2b40-c678-47c5-8f21-edf9516f6034.jpg)](https://youtu.be/FIZt7MinpMY?si=KChSuJJDyrcTdYiM)

## Requirements

- [Ollama](https://ollama.ai/) with a suitable model, e.g. [`llama3.1`](https://ollama.com/library/llama3.1), [`mistral`](https://ollama.ai/library/mistral), etc.
- [Curl](https://curl.se/)

## Installation

Install with your favorite plugin manager, e.g. [lazy.nvim](https://github.com/folke/lazy.nvim)

### Minimal Configuration

```lua
{ "David-Kunz/gen.nvim" }
```

### Custom Parameters (with defaults)

```lua
{
    "David-Kunz/gen.nvim",
    opts = {
        model = "mistral", -- The default model to use.
        quit_map = "q", -- Keymap to close the response window.
        retry_map = "<c-r>", -- Keymap to re-send the current prompt.
        accept_map = "<c-cr>", -- Keymap to replace the previous selection with the last result.
        host = "localhost", -- The host running the Ollama service.
        port = "11434", -- The port on which the Ollama service is listening.
        display_mode = "float", -- The display mode. Can be "float", "split", or "horizontal-split".
        show_prompt = false, -- Shows the prompt submitted to Ollama.
        show_model = false, -- Displays the model in use at the beginning of the chat session.
        no_auto_close = false, -- Prevents the window from closing automatically.
        file = false, -- Writes the payload to a temporary file to keep the command short.
        hidden = false, -- Hides the generation window (implicitly sets `prompt.replace = true`), requires Neovim >= 0.10.
        init = function(options) pcall(io.popen, "ollama serve > /dev/null 2>&1 &") end, -- Function to initialize Ollama.
        command = function(options)
            local body = {model = options.model, stream = true}
            return "curl --silent --no-buffer -X POST http://" .. options.host .. ":" .. options.port .. "/api/chat -d $body"
        end,
        -- The command for the Ollama service. You can use placeholders $prompt, $model, and $body (shellescaped).
        -- This can also be a command string.
        -- The executed command must return a JSON object with { response, context }
        -- (context property is optional).
        -- list_models = '<omitted lua function>', -- Retrieves a list of model names.
        debug = false -- Prints errors and the command which is run.
    }
}
```

### Alternative Setup

Alternatively, you can call the `setup` function:

```lua
require('gen').setup({
  -- same as above
})
```

Here are all [available models](https://ollama.ai/library).

## Usage

Use the command `Gen` to generate text based on predefined and customizable prompts.

### Example Key Maps

```lua
vim.keymap.set({ 'n', 'v' }, '<leader>]', ':Gen<CR>')
```

You can also directly invoke it with one of the [predefined prompts](./lua/gen/prompts.lua) or your custom prompts:

```lua
vim.keymap.set('v', '<leader>]', ':Gen Enhance_Grammar_Spelling<CR>')
```

Once a conversation is started, the whole context is sent to the LLM. This allows you to ask follow-up questions with:

```lua
:Gen Chat
```

And once the window is closed, you start with a fresh conversation.

For prompts that don’t automatically replace the previously selected text (`replace = false`), you can replace the selected text with the generated output using `<c-cr>`.

You can select a model from a list of all installed models with:

```lua
require('gen').select_model()
```

## Custom Prompts

[All prompts](./lua/gen/prompts.lua) are defined in `require('gen').prompts`, and you can enhance or modify them.

### Example

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

### Prompt Properties

- `prompt`: (string | function) Prompt either as a string or a function that returns a string. The result can use the following placeholders:
  - `$text`: Visually selected text or the content of the current buffer.
  - `$filetype`: File type of the buffer (e.g. `javascript`).
  - `$input`: Additional user input.
  - `$register`: Value of the unnamed register (yanked text).
- `replace`: `true` if the selected text should be replaced with the generated output.
- `extract`: Regular expression used to extract the generated result.
- `model`: The model to use, e.g. `zephyr`, default: `mistral`.

## Tip

User selections can be delegated to [Telescope](https://github.com/nvim-telescope/telescope.nvim) with [telescope-ui-select](https://github.com/nvim-telescope/telescope-ui-select.nvim).

---
