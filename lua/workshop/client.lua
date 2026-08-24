local http = require("workshop.util.http")

---Default locations where workshop socket may be present.
---@type (string|fun():string?)[]
local DEFAULT_SOCKET_PATHS = {
    function()
        return vim.env["WORKSHOP_SOCKET"]
    end,
    function()
        return vim.env["WORKSHOP"]
    end,
    "/var/lib/workshop/workshop.socket",
    "/var/snap/workshop/common/workshop/workshop.socket",
}

---Search for the workshop socket in known locations.
---@return string | nil
local find_socket_path = function()
    for _, path in ipairs(DEFAULT_SOCKET_PATHS) do
        local strpath = nil
        if type(path) == "function" then
            strpath = path()
        else
            strpath = path
        end

        if strpath ~= nil and vim.uv.fs_stat(strpath) then
            return strpath
        end
    end
end

---@param socket string
---@return HttpClient
local create_http_client = function(socket)
    ---@param key "get" | "post"
    local wrap = function(key)
        ---@param req HttpRequest
        ---@return HttpResponse
        return function(req)
            ---@type HttpResponse
            return http[key](req, {
                unix_socket = socket,
            })
        end
    end

    return {
        get = wrap("get"),
        post = wrap("post"),
    }
end

---@class WorkshopClient: HttpClient
---@field socket string
local WorkshopClient = {}
WorkshopClient.__index = WorkshopClient

---@class WorkshopClientOpts
---
---Path to workshop socket. If not provided, the file system will be searched.
---@field socket? string

---Create a new workshop client, and attempt to connect to a socket.
---@param opts WorkshopClientOpts
---@return WorkshopClient
function WorkshopClient.new(opts)
    local client = setmetatable({}, WorkshopClient)

    opts.socket = opts.socket or find_socket_path()
    if opts.socket == nil then
        error("cannot create client, socket not provided")
    end

    -- Assign fields from the http client
    local http_client = create_http_client(opts.socket)
    client = vim.tbl_extend("error", client, http_client)

    return client
end

return WorkshopClient
