local curl = require("plenary.curl")

---@param socket string
---@return workshop.api.HttpClient
local create_http_client = function(socket)
    local wrap = function(key)
        ---@param req workshop.api.HttpRequest
        ---@return workshop.api.HttpResponse
        return function(req)
            -- Allow requests to relative URLs, since the host doesn't matter for Unix sockets.
            if req.url:sub(1, 1) == "/" then
                req.url = "http://workshop" .. req.url
            end

            -- Ensure body is JSON encoded, with correct headers.
            if type(req.body) == "table" then
                req.body = vim.fn.json_encode(req.body)
                req.headers = vim.tbl_extend(
                    "force",
                    req.headers or {},
                    { ["Content-Type"] = "application/json" }
                )
            end

            -- Provide the socket path to curl.
            req.raw = vim.list_extend(req.raw or {}, { "--unix-socket", socket })

            ---@type workshop.api.HttpResponse
            return curl[key](req)
        end
    end

    return {
        get = wrap("get"),
        post = wrap("post"),
    }
end

---@class WorkshopClient: workshop.api.HttpClient
---@field socket string
local WorkshopClient = {}
WorkshopClient.__index = WorkshopClient

---@class WorkshopClientOpts
---
---Path to workshop socket.
---@field socket string

---Create a new workshop client, and attempt to connect to a socket.
---@param opts WorkshopClientOpts
---@return WorkshopClient
function WorkshopClient:new(opts)
    local client = setmetatable({}, WorkshopClient)

    client.socket = opts.socket

    -- Assign fields from the http client
    local http_client = create_http_client(client.socket)
    client = vim.tbl_extend("error", client, http_client)

    return client
end

return WorkshopClient
