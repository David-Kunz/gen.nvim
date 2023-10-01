return {
    Generate = {prompt = "$input1", replace = true},
    Summarize = {prompt = "Summarize the following text:\n\n```\n$text\n```"},
    Ask = {prompt = "Regarding the following text, $input1:\n\n```\n$text\n```"},
    Enhance_Grammar = {
        prompt = "Enhance the grammar and spelling in the following text:\n\n```\n$text\n```",
        replace = true
    },
    Enhance_Wording = {
        prompt = "Enhance the wording in the following text:\n\n```\n$text\n```",
        replace = true
    },
    Make_Concise = {
        prompt = "Make the following text as simple and concise as possible:\n\n```\n$text\n```",
        replace = true
    },
    Make_List = {
        prompt = "Render the following text as a markdown list:\n\n```\n$text\n```",
        replace = true
    },
    Make_Table = {
        prompt = "Render the following text as a markdown table:\n\n```\n$text\n```",
        replace = true
    },
    Review_Code = {
        prompt = "Review the following code and make concise suggestions:\n\n```$filetype\n$text\n```"
    },
    Enhance_Code = {
        prompt = "Enhance the following code, only ouput the result in format ```$filetype\n...\n```:\n\n```$filetype\n$text\n```",
        replace = true,
        extract = "```$filetype\n(.-)```"
    },
    Change_Code = {
        prompt = "Regarding the following code, $input1, only ouput the result in format ```$filetype\n...\n```:\n\n```$filetype\n$text\n```",
        replace = true,
        extract = "```$filetype\n(.-)```"
    }
}

