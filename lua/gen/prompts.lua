return {
    Generate = {prompt = "$input", replace = true},
    Summarize = {prompt = "Summarize the following text:\n$text"},
    Ask = {prompt = "Regarding the following text, $input:\n$text"},
    Change = {prompt = "Change the following text, $input:\n$text"},
    Enhance_Grammar_Spelling = {
        prompt = "Modify the following text to improve grammar and spelling:\n$text",
        replace = true
    },
    Enhance_Wording = {
        prompt = "Modify the following text to use better wording:\n$text",
        replace = true
    },
    Make_Concise = {
        prompt = "Modify the following text to make it as simple and concise as possible:\n$text",
        replace = true
    },
    Make_List = {
        prompt = "Render the following text as a markdown list:\n$text",
        replace = true
    },
    Make_Table = {
        prompt = "Render the following text as a markdown table:\n$text",
        replace = true
    },
    Review_Code = {
        prompt = "Review the following code and make concise suggestions:\n```$filetype\n$text\n```"
    },
    Enhance_Code = {
        prompt = "Enhance the following code, only ouput the result in format ```$filetype\n...\n```:\n```$filetype\n$text\n```",
        replace = true,
        extract = "```$filetype\n(.-)```"
    },
    Change_Code = {
        prompt = "Regarding the following code, $input, only ouput the result in format ```$filetype\n...\n```:\n```$filetype\n$text\n```",
        replace = true,
        extract = "```$filetype\n(.-)```"
    }
}

