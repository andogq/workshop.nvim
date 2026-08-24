local api = require("workshop.api")

local M = {}

---Project paths mapped to a project ID.
---@type table<string, string>
M._registered_projects = {}

---Return the project ID for the current buffer.
---@param client WorkshopClient
M.current_project = function(client)
    local root = vim.fs.root(0, { ".git", ".workshop" }) or vim.fn.getcwd(0)

    if M._registered_projects[root] then
        return M._registered_projects[root]
    end

    M._registered_projects[root] = api.ensure_project(client, root).id

    return M._registered_projects[root]
end

return M
