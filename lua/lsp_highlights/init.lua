local M = {}

M.config = {}

-- Helper: Get the background color of a highlight group
local function get_hl_color(hl_group_name)
    local hl = vim.api.nvim_get_hl_by_name(hl_group_name, true)
    if hl.background then
        return string.format("#%06x", hl.background)
    elseif hl.foreground then
        return string.format("#%06x", hl.foreground)
    end
    return nil
end

-- Create a dedicated namespace for extmarks
local namespace = vim.api.nvim_create_namespace("DiagnosticLineHighlighter")

-- The custom diagnostic handler
local handler = {
    show = function(_, bufnr, diagnostics, _)
        if type(bufnr) ~= "number" or bufnr == 0 then return end
        if not vim.api.nvim_buf_is_valid(bufnr) then return end

        vim.api.nvim_buf_clear_namespace(bufnr, namespace, 0, -1)

        for _, diagnostic in ipairs(diagnostics) do
            local severity_map = {
                [vim.diagnostic.severity.ERROR] = "DiagnosticSignError",
                [vim.diagnostic.severity.WARN]  = "DiagnosticSignWarn",
                [vim.diagnostic.severity.INFO]  = "DiagnosticSignInfo",
                [vim.diagnostic.severity.HINT]  = "DiagnosticSignHint",
            }
            local sign_group = severity_map[diagnostic.severity]
            if not sign_group then goto continue end

            local hl_color = get_hl_color(sign_group)
            if not hl_color then goto continue end

            -- Create a highlight group with foreground color only
            local text_hl_group = string.format("DiagTextHL_%s", sign_group)
            vim.api.nvim_set_hl(0, text_hl_group, { fg = hl_color })

            -- Use nvim_buf_add_highlight with -1 for end-of-line
            vim.api.nvim_buf_add_highlight(
                bufnr,
                namespace,
                text_hl_group,
                diagnostic.lnum,   -- 0-indexed line
                0,                 -- start column
                -1                 -- end column (-1 = end of line)
            )

            ::continue::
        end
    end,

    hide = function(_, bufnr)
        vim.api.nvim_buf_clear_namespace(bufnr, namespace, 0, -1)
    end,
}

function M.setup(user_config)
    M.config = vim.tbl_deep_extend("force", M.config, user_config or {})

    -- Register our custom handler
    vim.diagnostic.handlers["diagnostic_line_highlighter"] = handler

    -- Add the handler to the current diagnostic configuration
    local current_config = vim.diagnostic.config() or {}
    current_config.handlers = current_config.handlers or {}
    table.insert(current_config.handlers, "diagnostic_line_highlighter")
    vim.diagnostic.config(current_config)
end

return M
