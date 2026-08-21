local M = {}

---Default locations where workshop socket may be present.
---@type (string|fun():(string|nil))[]
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
---
---@return string | nil
M.find_socket_path = function()
    for _, path in pairs(DEFAULT_SOCKET_PATHS) do
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

return M
