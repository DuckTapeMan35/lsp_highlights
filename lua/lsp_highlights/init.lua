local M = {}

M.config = {}

-- Get the background color of a highlight group
local function get_hl_color(hl_group_name)
    local hl = vim.api.nvim_get_hl(0, { name = hl_group_name, link = false })
    if hl.fg then
        return string.format("#%06x", hl.fg)
    elseif hl.bg then
        return string.format("#%06x", hl.bg)
    end
    return nil
end

-- Create a dedicated namespace for extmarks
local namespace = vim.api.nvim_create_namespace("DiagnosticLineHighlighter")

-- The custom diagnostic handler
local handler = {
     show = function(_, bufnr, diagnostics, _)
        if type(bufnr) ~= "number" or (bufnr ~= 0 and not vim.api.nvim_buf_is_valid(bufnr)) then
            return
        end
        vim.api.nvim_buf_clear_namespace(bufnr, namespace, 0, -1)
        -- Pre-create all highlight groups before the loop
        local severity_map = {
            [vim.diagnostic.severity.ERROR] = "DiagnosticSignError",
            [vim.diagnostic.severity.WARN]  = "DiagnosticSignWarn",
            [vim.diagnostic.severity.INFO]  = "DiagnosticSignInfo",
            [vim.diagnostic.severity.HINT]  = "DiagnosticSignHint",
        }
        for _, sign_group in pairs(severity_map) do
            local hl_color = get_hl_color(sign_group)
            if hl_color then
                local text_hl_group = string.format("DiagTextHL_%s", sign_group)
                vim.api.nvim_set_hl(0, text_hl_group, { fg = hl_color })
            end
        end
        -- Now apply the highlights
        for _, diagnostic in ipairs(diagnostics) do
            local sign_group = severity_map[diagnostic.severity]
            if not sign_group then goto continue end
            local text_hl_group = string.format("DiagTextHL_%s", sign_group)
            -- Verify the highlight group exists
            local hl_exists = vim.fn.hlexists(text_hl_group) == 1
            if not hl_exists then goto continue end
            local line_count = vim.api.nvim_buf_line_count(bufnr)
            if diagnostic.lnum >= line_count then goto continue end
            local line_content = vim.api.nvim_buf_get_lines(bufnr, diagnostic.lnum, diagnostic.lnum + 1, false)[1]
            local line_length = line_content and #line_content or 0
            vim.api.nvim_buf_set_extmark(bufnr, namespace, diagnostic.lnum, 0, {
              hl_group = text_hl_group,
              end_col = line_length,
              priority = 1000,
            })
            ::continue::
        end
    end,

    hide = function(_, bufnr)
        vim.api.nvim_buf_clear_namespace(bufnr, namespace, 0, -1)
    end,
}

function M.setup(user_config)
  M.config = vim.tbl_deep_extend("force", M.config, user_config or {})

    vim.diagnostic.handlers["diagnostic_line_highlighter"] = handler

    ---@type table
    local current_config = vim.diagnostic.config() or {}
    current_config.handlers = current_config.handlers or {}
    -- Avoid duplicates
    for _, h in ipairs(current_config.handlers) do
        if h == "diagnostic_line_highlighter" then
            return
        end
    end
    table.insert(current_config.handlers, "diagnostic_line_highlighter")
    vim.diagnostic.config(current_config)
end

return M
