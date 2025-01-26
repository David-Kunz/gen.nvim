return {
    Generate = {
        prompt = {
            en = [[Generate the following code. Include all explanations as inline comments using $filetype syntax.
Do not include any additional text or descriptions outside the code:
$input]],
            es = [[Genera el siguiente código. Incluye todas las explicaciones como comentarios dentro del código usando la sintaxis de $filetype.
No incluyas texto ni descripciones adicionales fuera del código:
$input]],
        },
        replace = true,
    },
    Chat = {
        prompt = {
            en = "$input",
            es = "$input",
        },
    },
    Summarize = {
        prompt = {
            en = "Summarize the following text:\n$text",
            es = "Resume el siguiente texto:\n$text",
        },
    },
    Ask = {
        prompt = {
            en = "Regarding the following text, $input:\n$text",
            es = "Con respecto al siguiente texto, $input:\n$text",
        },
    },
    Change = {
        prompt = {
            en = "Change the following text, $input, just output the final text without additional quotes:\n$text",
            es = "Cambia el siguiente texto, $input, solo muestra el texto final sin comillas adicionales:\n$text",
        },
        replace = true,
    },
    Enhance_Grammar_Spelling = {
        prompt = {
            en = "Improve grammar and spelling in the following text. Output only the final text, no quotes:\n$text",
            es = "Mejora la gramática y la ortografía del siguiente texto. Muestra solo el texto final, sin comillas:\n$text",
        },
        replace = true,
    },
    Enhance_Wording = {
        prompt = {
            en = "Use better wording for the following text. Output only the final text, no quotes:\n$text",
            es = "Mejora la redacción del siguiente texto. Muestra solo el texto final, sin comillas:\n$text",
        },
        replace = true,
    },
    Make_Concise = {
        prompt = {
            en = "Make the following text simple and concise. Output only the final text, no quotes:\n$text",
            es = "Haz que el siguiente texto sea lo más simple y conciso posible. Muestra solo el texto final, sin comillas:\n$text",
        },
        replace = true,
    },
    Make_List = {
        prompt = {
            en = "Convert the following text into a list. Output only the list (no extra text):\n$text",
            es = "Convierte el siguiente texto en una lista. Muestra solo la lista (sin texto extra):\n$text",
        },
        replace = true,
    },
    Make_Table = {
        prompt = {
            en = "Convert the following text into a table (no markdown). Output only the table:\n$text",
            es = "Convierte el siguiente texto en una tabla (sin markdown). Muestra solo la tabla:\n$text",
        },
        replace = true,
    },

    -- ========================================
    --   EJEMPLOS PARA PROMPTS DE CÓDIGO
    -- ========================================
    Review_Code = {
        prompt = {
            en = [[Review the following code and make concise suggestions. If you add explanations, put them as comments in the $filetype syntax. Output only the modified code with comments included: $text]],
            es = [[Revisa el siguiente código y haz sugerencias concisas. Si añades explicaciones, ponlas como comentarios usando la sintaxis de $filetype. Muestra solo el código modificado con los comentarios incluidos: $text]],
        },
    },

    Enhance_Code = {
        prompt = {
            en = [[Enhance the following code. If you add explanations, include them as valid $filetype comments. Output only the final code, no markdown or extra quotes: $text]],
            es = [[Mejora el siguiente código. Si añades explicaciones, inclúyelas como comentarios válidos de $filetype. Muestra solo el código final, sin markdown ni comillas extra: $text]],
        },
        replace = true,
        -- Quita el extract si ya no usas ``` fences
        -- extract = "```$filetype\n(.-)```",
    },
    Change_Code = {
        prompt = {
            en = [[Make the following changes to the code, $input. If you need to explain, add inline comments in $filetype. Output only the resulting code, no markdown fences: $text]],
            es = [[Realiza los siguientes cambios en el código, $input. Si necesitas explicar algo, añádelo como comentarios en $filetype.  Muestra únicamente el código resultante, sin formateo markdown: $text]],
        },
        replace = true,
    },
}
