# gen.nvim

Generate text using LLMs with customizable prompts

## Video

[![Local LLMs in Neovim: gen.nvim](https://user-images.githubusercontent.com/1009936/273126287-7b5f2b40-c678-47c5-8f21-edf9516f6034.jpg)](https://youtu.be/FIZt7MinpMY?si=KChSuJJDyrcTdYiM)


## Requires

- [Ollama](https://ollama.ai/) with an appropriate model, e.g. [`mistral:instruct`](https://ollama.ai/library/mistral) or [`zephyr`](https://ollama.ai/library/zephyr) (customizable)

## Install

Install with your favorite plugin manager, e.g. [lazy.nvim](https://github.com/folke/lazy.nvim)

Example with Lazy

```lua
-- Minimal configuration
{ "David-Kunz/gen.nvim" },

```

```lua

-- Custom Parameters
{
    "David-Kunz/gen.nvim",
    opts = {
        model = "zephyr",                            -- The default model to use. Defaults to "mistral:instruct"
        debugCommand = true,                         -- Prints errors. Defaults to false.
        show_prompt = true,                          -- Shows the Prompt submitted to ollama. Defaults to false.
        auto_close_after_replace = false,            -- Closes the window after replacing the text. Defaults to true.
        ollama_url = "http://ollama.myserver.com",   -- The url of ollama service. Defaults to "http://localhost:11434"
    }
},
```


## Usage

Use command `Gen` to generate text based on predefined and customizable prompts.

Example key maps:

```lua
vim.keymap.set('v', '<leader>]', ':Gen<CR>')
vim.keymap.set('n', '<leader>]', ':Gen<CR>')
```

You can also directly invoke it with one of the [predefined prompts](./lua/gen/prompts.lua):

```lua
vim.keymap.set('v', '<leader>]', ':Gen Enhance_Grammar_Spelling<CR>')
```

## Options

All prompts are defined in `require('gen').prompts`, you can enhance or modify them.

Example:
```lua
require('gen').prompts['Elaborate_Text'] = {
  prompt = "Elaborate the following text:\n$text",
  replace = true
}
require('gen').prompts['Fix_Code'] = {
  prompt = "Fix the following code. Only ouput the result in format ```$filetype\n...\n```:\n```$filetype\n$text\n```",
  replace = true,
  extract = "```$filetype\n(.-)```"
}
```

You can use the following properties per prompt:

- `prompt`: (string | function) Prompt either as a string or a function which should return a string. The result can use the following placeholders:
   - `$text`: Visually selected text
   - `$filetype`: Filetype of the buffer (e.g. `javascript`)
   - `$input`: Additional user input
   - `$register`: Value of the unnamed register (yanked text)
- `replace`: `true` if the selected text shall be replaced with the generated output
- `extract`: Regular expression used to extract the generated result
- `model`: The model to use, e.g. `zephyr`, default: `mistral:instruct`
- `container`: Specify name of ollama container if you are using Docker to host ollama service

## Host Ollama in Docker

You can host ollama in a docker container. The following command will host ollama on port 11434.

```bash
docker run -p 11434:11434 -d --name ollama ollama/ollama:latest
```

To add models to the container, you can use the following command:
Replace `llama2:chat` with the model you want to add.

```bash
docker exec -it ollama ollama pull llama2:chat
```
