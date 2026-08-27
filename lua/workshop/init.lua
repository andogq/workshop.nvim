local Project = require("workshop.project")
local WorkshopClient = require("workshop.client")
local ui = require("workshop.util.ui")

local M = {}

---@class workshop.Config
---
---Path to `workshop` socket, or a function that returns the path.
---@field socket string?
M.config = {}

---@type StartFunction | nil
M.wrapped_start = nil

---@alias StartFunction fun(config: vim.lsp.ClientConfig, opts?: vim.lsp.start.Opts): integer?

---@param start StartFunction
---@return StartFunction
local wrap_start = function(start)
    if not M.wrapped_start then
        M.wrapped_start = function(config, opts)
            -- Update the cmd.
            if type(config.cmd) == "table" then
                local client = M.get_client()
                local root = vim.fs.root(0, { ".git", ".workshop" }) or vim.fn.getcwd(0)
                local project = Project.ensure(client, root)
                local workshops = project:workshops()

                -- Just select the first workshop.
                local keys = vim.tbl_keys(workshops)
                if #keys >= 1 then
                    local workshop = workshops[keys[1]]
                    workshop:start({ allow_launch = true })
                    config.cmd = workshop:build_exec_command(config.cmd --[[@as string[] ]])
                end
            end

            return start(config, opts)
        end
    end

    return M.wrapped_start
end

---@class workshop.Opts
---
---Path to `workshop` socket, or a function that returns the path.
---@field socket? string | fun():string
---@field wrap_start? boolean

---@param opts? workshop.Opts
M.setup = function(opts)
    opts = opts or {}
    M.config = vim.tbl_deep_extend("force", M.config, opts)

    if opts.wrap_start then
        -- Wrap vim.lsp.start
        vim.lsp.start = wrap_start(vim.lsp.start)
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
