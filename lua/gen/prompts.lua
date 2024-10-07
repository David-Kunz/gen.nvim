return {
    Generate = {
        prompt = "Generate a comprehensive response based on the following input: \"$input\". Ensure that the response is well-structured and relevant to the context.",
        replace = true
    },
    Chat = {
        prompt = "Engage in a conversation based on the following input: \"$input\". Provide a detailed and thoughtful response that encourages further discussion."
    },
    Summarize = {
        prompt = "Summarize the key points of the following text, capturing its main ideas concisely while retaining important details:\n$text"
    },
    Ask = {
        prompt = "Given the following text, respond to the query \"$input\" with an answer that is both insightful and informative:\n$text"
    },
    Change = {
        prompt = "Modify the following text based on the instruction \"$input\". Ensure the output is natural, contextually appropriate, and without additional quotes around it:\n$text",
        replace = true
    },
    Enhance_Grammar_Spelling = {
        prompt = "Improve the grammar and spelling of the following text while maintaining its original meaning and tone. Output the final version without adding quotes around it:\n$text",
        replace = true
    },
    Enhance_Wording = {
        prompt = "Enhance the wording of the following text to make it more engaging, precise, and fluid while preserving its intended meaning. Output the final version without quotes:\n$text",
        replace = true
    },
    Make_Concise = {
        prompt = "Refine the following text to be as concise as possible while retaining its core message and clarity. Output the final version without quotes:\n$text",
        replace = true
    },
    Make_List = {
        prompt = "Convert the following text into a well-formatted markdown list, breaking it down into clear, organized points:\n$text",
        replace = true
    },
    Make_Table = {
        prompt = "Transform the following text into a well-structured markdown table with clear headers and data alignment:\n$text",
        replace = true
    },
    Review_Code = {
        prompt = "Review the following code carefully and provide detailed suggestions for improvement, including best practices, optimization tips, and potential issues:\n```$filetype\n$text\n```"
    },
    Enhance_Code = {
        prompt = "Enhance the following code by improving its efficiency, readability, and overall structure. Ensure the result follows best practices and output the code in the format:\n```$filetype\n...\n```:\n```$filetype\n$text\n```",
        replace = true,
        extract = "```$filetype\n(.-)```"
    },
    Change_Code = {
        prompt = "Modify the following code based on the input \"$input\". Ensure the changes are accurate, efficient, and follow coding best practices. Output the result in the format:\n```$filetype\n...\n```:\n```$filetype\n$text\n```",
        replace = true,
        extract = "```$filetype\n(.-)```"
    }
}
