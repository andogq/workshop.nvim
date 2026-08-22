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

---@param opts? workshop.Opts
M.setup = function(opts)
    opts = opts or {}
    M.config = vim.tbl_deep_extend("force", M.config, opts)

    -- Wrap vim.lsp.start
    vim.lsp.start = wrap_start(vim.lsp.start)

    -- Resolve the socket.
    local socket ---@type string
    local config_socket = M.config.socket
    if type(config_socket) == "function" then
        socket = config_socket()
    else
        socket = config_socket
    end

    -- Create the client.
    local client = WorkshopClient:new({
        socket = socket,
    })

    vim.print(api.system_info(client))
end

return M
