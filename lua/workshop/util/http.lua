local M = {}

---@class HttpResponse
---HTTP status code.
---@field status integer
---Response headers, keys lowercased.
---@field headers table<string, string>
---Response body, decoded as JSON if possible, otherwise raw string.
---@field body any

---@class HttpClient
---@field get fun(req: HttpRequest): HttpResponse
---@field post fun(req: HttpRequest): HttpResponse

---Parse a curl `-i` response into status, headers, and body.
---@param stdout string
---@return HttpResponse
local parse_response = function(stdout)
    local header_end = stdout:find("\r?\n\r?\n")
    if not header_end then
        return { status = 0, headers = {}, body = stdout }
    end

    local header_block = stdout:sub(1, header_end - 1)
    local body = stdout:sub(header_end + 4)

    local lines = {}
    for line in header_block:gmatch("[^\r\n]+") do
        table.insert(lines, line)
    end

    local status = 0
    local status_line = lines[1] or ""
    local matched_status = status_line:match("^HTTP/%S+ (%d%d%d)")
    if matched_status then
        status = tonumber(matched_status) or 0
    end

    local headers = {}
    for i = 2, #lines do
        local key, value = lines[i]:match("^([^:]+):%s*(.*)$")
        if key then
            key = key:lower()
            if headers[key] then
                headers[key] = headers[key] .. ", " .. value
            else
                headers[key] = value
            end
        end
    end

    local ok, decoded = pcall(vim.fn.json_decode, body)
    if ok then
        body = decoded
    end

    return { status = status, headers = headers, body = body }
end

---@class RequestOpts
---Request HTTP method.
---@field method? "GET" | "POST"
---Request URL.
---@field url string
---Request query, to be appended to the URL.
---@field query? table
---Request body, to be encoded as JSON.
---@field body? table

---@class CurlOpts
---Path to curl binary.
---@field curl_path string?
---Path to a Unix socket to use for request.
---@field unix_socket string?

---@param str string | integer
---@return string
local url_encode = function(str)
    if type(str) == "number" or type(str) == "boolean" then
        return tostring(str)
    elseif type(str) ~= "string" then
        error("cannot URL encode component")
    end

    local encoded = str:gsub("\r?\n", "\r\n")
        :gsub("([^%w%-%.%_%~ ])", function(c)
            return string.format("%%%02X", c:byte())
        end)
        :gsub(" ", "+")
    return encoded
end

---@param url string
---@param query table?
---@return string
local build_full_url = function(url, query)
    local query_parts = {}

    for key, value in vim.spairs(query or {}) do
        table.insert(query_parts, string.format("%s=%s", url_encode(key), url_encode(value)))
    end

    if #query_parts == 0 then
        return url
    end

    return string.format("%s?%s", url, vim.fn.join(query_parts, "&"))
end

---@param opts RequestOpts
---@param curl_opts CurlOpts
---@return string[]
local build_command = function(opts, curl_opts)
    local args = { curl_opts.curl_path or "curl" }
    local headers = {}

    -- Include response headers in output.
    vim.list_extend(args, { "-i" })

    -- Request method.
    vim.list_extend(args, { "-X", opts.method or "GET" })

    -- JSON body.
    if opts.body then
        vim.list_extend(args, { "--data-raw", vim.fn.json_encode(opts.body) })
        headers["Content-Type"] = "application/json"
    end

    -- Request headers.
    for key, value in vim.spairs(headers) do
        vim.list_extend(args, { "-H", string.format("%s: %s", key, value) })
    end

    if curl_opts.unix_socket then
        vim.list_extend(args, { "--unix-socket", curl_opts.unix_socket })
    end

    -- Request URL is final thing.
    table.insert(args, build_full_url(opts.url, opts.query))

    return args
end

---@param opts RequestOpts
---@param curl_opts CurlOpts?
---@return HttpResponse
M.request = function(opts, curl_opts)
    opts.method = opts.method or "GET"
    curl_opts = curl_opts or {}

    local command = build_command(opts, curl_opts)

    -- Execute command.
    local result = vim.system(command, { text = true }):wait(10000)

    if result.code ~= 0 then
        local message = string.format(
            "%s %s - curl error exit_code=%s stderr=%s",
            opts.method,
            opts.url,
            result.code,
            result.stderr
        )
        error(message)
    end

    return parse_response(result.stdout)
end

M.get = function(opts, curl_opts)
    opts.method = "GET"
    return M.request(opts, curl_opts)
end

M.post = function(opts, curl_opts)
    opts.method = "POST"
    return M.request(opts, curl_opts)
end

return M
