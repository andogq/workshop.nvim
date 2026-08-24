local W_project = require("workshop.project")
local W_socket = require("workshop.socket")
local WorkshopClient = require("workshop.client")
local api = require("workshop.api")

local M = {}

---@class workshop.Config
---
---Path to `workshop` socket, or a function that returns the path.
---@field socket string | fun():string
M.config = {
    socket = W_socket.find_socket_path,
}

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
                config.cmd = vim.list_extend({
                    "workshop",
                    "exec",
                    "--",
                }, config.cmd --[[@as string[] ]])
            end
            vim.notify(vim.inspect(config.cmd))

            -- HACK: Hardcoded.
            config.root_dir = "/project"
            config.cmd_env = {}

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
    if client ~= nil then
        return client
    end

    local socket ---@type string
    local config_socket = M.config.socket
    if type(config_socket) == "function" then
        socket = config_socket()
    else
        socket = config_socket
    end

    client = WorkshopClient:new({ socket = socket })

    return client
end

---Start a workshop within this project.
---@param name? string
M.start_workshop = function(name)
    local workshop_client = M.get_client()
    local project = W_project.current_project(workshop_client)

    local workshops = api.list_workshops(workshop_client, project).workshops

    ---@param workshop workshop.api.WorkshopInfo
    local start_workshop = function(workshop)
        vim.print("starting workshop", workshop)
    end
    if workshops == nil or #workshops == 0 then
        -- No workshops.
        return
    elseif #workshops == 1 then
        start_workshop(workshops[1])
    elseif name then
        -- Select `name` workshop
        for _, workshop in ipairs(workshops) do
            if workshop.name == name then
                start_workshop(workshop)
                break
            end
        end
    else
        vim.ui.select(workshops, {
            format_item =
                ---@param workshop workshop.api.WorkshopInfo
                function(workshop)
                    return string.format("%s (%s)", workshop.name, workshop.status)
                end,
        }, start_workshop)
    end
end

return M
