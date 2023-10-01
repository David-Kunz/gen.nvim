# gen.nvim

Generate text using LLMs with customizable prompts

## Requires

- [Ollama](https://ollama.ai/) with model `mistral:instruct` (customizable)

## Usage

Use command `Gen` to generate text based on predefined and customizable prompts.

Example key maps:

```lua
vim.keymap.set('v', '<leader>]', ':Gen<CR>')
vim.keymap.set('n', '<leader>]', ':Gen<CR>')
```

You can also directly invoke it with one of the [predefined prompts](./lua/gen/prompts.lua):

```lua
vim.keymap.set('v', '<leader>]', ':Gen Enhance_Grammar<CR>')
```

## Options

All prompts are defined in `require('gen').prompts`, you can enhance or modify them.

Example:
```lua
table.insert(require('gen').prompts, {
    Elaborate_Text = {
        prompt = "Elaborate the following text: $text",
        replace = true
    },
    Fix_Code = {
        prompt = "Fix the following code. Only ouput the result in format ```$filetype\n...\n```:\n\n```$filetype\n$text\n```",
        replace = true,
        extract = "```$filetype\n(.-)```"
    }
})
```

You can use the following properties per prompt:

- `prompt`: Prompt which can use the following placeholders:
   - `$text`: Visually selected text
   - `$filetype`: Filetype of the buffer (e.g. `javascript`)
   - `$input1`: Additional user input (as well as `$input2 ... $input5`)
- `replace`: Shall the selected text be replaced?
- `extract`: Regular expression used to extract the generated result

You can change the command to execute the prompt with

```lua
require('gen').command = 'your command' -- default 'ollama run $model """$prompt"""'
```

You can use the placeholders `$model` (`require('gen').model`) and `$prompt`.
