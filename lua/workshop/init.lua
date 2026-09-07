local Project = require("workshop.project")
local WorkshopClient = require("workshop.client")
local lsp = require("workshop.lsp")
local ui = require("workshop.util.ui")

local M = {}

---A function for each LSP, which can modify the command to add options to enable path mapping.
---@alias Workshop.PathMappingConfig table<string, fun(project_root: string, cmd: string[]):string[]>

---@class workshop.Config
---
---Path to `workshop` socket, or a function that returns the path.
---@field socket string?
---@field path_mapping Workshop.PathMappingConfig
M.config = {
    path_mapping = {
        clangd = function(project_root, cmd)
            local mapping = project_root .. "=/project"

            local flag = "--path-mappings"
            for i, value in ipairs(cmd) do
                if value:sub(1, #flag) == flag then
                    -- If the flag exactly matches, the following argument contains the mappings.
                    if value == flag then
                        i = i + 1
                    end

                    -- Append the mapping as a comma separated list.
                    cmd[i] = cmd[i] .. "," .. mapping
                end
            end

            -- Flag wasn't found, so just add it.
            vim.list_extend(cmd, { flag .. "=" .. mapping })

            return cmd
        end,
    },
}

---@class workshop.Opts
---
---Path to `workshop` socket, or a function that returns the path.
---@field socket? string | fun():string
---@field path_mapping? Workshop.PathMappingConfig

---@param opts? workshop.Opts
M.setup = function(opts)
    opts = opts or {}
    M.config = vim.tbl_deep_extend("force", M.config, opts)

    local client = M.get_client()

    if opts.wrap_start and not M.start_wrapped then
        M.start_wrapped = true
        vim.lsp.start = lsp.wrap_start(client, vim.lsp.start)
    end
end

---@type WorkshopClient
local client = nil

---Fetch the current client instance.
M.get_client = function()
    if client == nil then
        client = WorkshopClient.new({ socket = M.config.socket })
    end

    return client
end

M.workshops = function()
    local workshop_client = M.get_client()
    local root = vim.fs.root(0, { ".git", ".workshop" }) or vim.fn.getcwd(0)
    local project = Project.ensure(workshop_client, root)

    local lines = { "Workshops:" }
    for _, workshop in vim.spairs(project:workshops()) do
        table.insert(lines, string.format("- %s (%s)", workshop.name, workshop.status))
    end
    ui.float(lines)
end

return M
