local W_socket = require("workshop.socket")
local WorkshopClient = require("workshop.client")
local api = require("workshop.api")

local M = {}

---@class workshop.Config
---
---Path to `workshop` socket, or a function that returns the path.
---@field socket string | fun():string

---@type workshop.Config
M.config = {
    socket = W_socket.find_socket_path,
}

---@class workshop.Opts
---
---Path to `workshop` socket, or a function that returns the path.
---@field socket? string | fun():string

---@param opts? workshop.Opts
M.setup = function(opts)
    opts = opts or {}
    M.config = vim.tbl_deep_extend("force", M.config, opts)

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
