local M = {}

---Default height and width of float.
local DEFAULT_SIZE = {
    width = 60,
    height = 4,
}
---Maximum percentage of width/height to allow.
local MAX_FILL = 0.8

---Open a centered floating window with the provided content.
---@param lines string[]
M.float = function(lines)
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

    local ui = vim.api.nvim_list_uis()[1]

    local width = math.min(DEFAULT_SIZE.width, math.floor(ui.width * MAX_FILL))
    local height = math.min(math.max(#lines, DEFAULT_SIZE.height), math.floor(ui.height * MAX_FILL))
    local row = math.floor((ui.height - height) / 2)
    local col = math.floor((ui.width - width) / 2)

    vim.api.nvim_open_win(buf, true, {
        relative = "editor",
        width = width,
        height = height,
        row = row,
        col = col,
        style = "minimal",
    })
end

return M
