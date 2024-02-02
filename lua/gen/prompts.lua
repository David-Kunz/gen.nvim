local M = {}

M.default_prompts = function()
return {
    Generate = { prompt = "$input", replace = true },
    Chat = { prompt = "$input" },
    Summarize = { prompt = "Summarize the following text:\n$text" },
    Ask = { prompt = "Regarding the following text, $input:\n$text" },
    Change = {
        prompt = "Change the following text, $input, just output the final text without additional quotes around it:\n$text",
        replace = true,
    },
    Enhance_Grammar_Spelling = {
        prompt = "Modify the following text to improve grammar and spelling, just output the final text without additional quotes around it:\n$text",
        replace = true,
    },
    Enhance_Wording = {
        prompt = "Modify the following text to use better wording, just output the final text without additional quotes around it:\n$text",
        replace = true,
    },
    Make_Concise = {
        prompt = "Modify the following text to make it as simple and concise as possible, just output the final text without additional quotes around it:\n$text",
        replace = true,
    },
    Make_List = {
        prompt = "Render the following text as a markdown list:\n$text",
        replace = true,
    },
    Make_Table = {
        prompt = "Render the following text as a markdown table:\n$text",
        replace = true,
    },
    Review_Code = {
        prompt = "Review the following code and make concise suggestions:\n```$filetype\n$text\n```",
    },
    Enhance_Code = {
        prompt = "Enhance the following code, only output the result in format ```$filetype\n...\n```:\n```$filetype\n$text\n```",
        replace = true,
        extract = "```$filetype\n(.-)```",
    },
    Change_Code = {
        prompt = "Regarding the following code, $input, only output the result in format ```$filetype\n...\n```:\n```$filetype\n$text\n```",
        replace = true,
        extract = "```$filetype\n(.-)```",
    },
}
end

-- this function is itself almost redundant, but it helps keep the
-- program syntax in init.lua clearer by accessing both user and default
-- prompts from the same file.
M.user_prompts = function(prompts)
    return prompts
end

return M
