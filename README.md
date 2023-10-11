# gen.nvim

Generate text using LLMs with customizable prompts

## Video

[![Local LLMs in Neovim: gen.nvim](https://user-images.githubusercontent.com/1009936/273126287-7b5f2b40-c678-47c5-8f21-edf9516f6034.jpg)](https://youtu.be/FIZt7MinpMY?si=KChSuJJDyrcTdYiM)


## Requires

- [Ollama](https://ollama.ai/) with an appropriate model, e.g. [`mistral:instruct`](https://ollama.ai/library/mistral) or [`zephyr`](https://ollama.ai/library/zephyr) (customizable)

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

- `prompt`: Prompt which can use the following placeholders:
   - `$text`: Visually selected text
   - `$filetype`: Filetype of the buffer (e.g. `javascript`)
   - `$input`: Additional user input
- `replace`: `true` if the selected text shall be replaced with the generated output
- `extract`: Regular expression used to extract the generated result

You can change the model by setting `require('gen').model = 'your_model'`, e.g.

```lua
require('gen').model = 'zephyr' -- default 'mistral:instruct'
```

Here are all [available models](https://ollama.ai/library).

You can also change the complete command with

```lua
require('gen').command = 'your command' -- default 'ollama run $model $prompt'
```

You can use the placeholders `$model` and `$prompt`.
