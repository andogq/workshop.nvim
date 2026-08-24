---@diagnostic disable: undefined-field
local http = require("workshop.util.http")

local stub = require("luassert.stub")

describe("http", function()
    local system_stub
    before_each(function()
        system_stub = stub(vim, "system")
        system_stub.returns({
            wait = function()
                return {
                    code = 0,
                    stdout = "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\n\r\n{}",
                    stderr = "",
                }
            end,
        })
    end)
    after_each(function()
        system_stub:revert()
    end)

    it("defaults to get request", function()
        http.request({ url = "http://example.com/hello" })
        assert.are.same(
            { "curl", "-i", "-X", "GET", "http://example.com/hello" },
            system_stub.calls[1].vals[1]
        )
    end)

    for _, method in ipairs({ "GET", "POST" }) do
        it(string.format("handles method: %s", method), function()
            http.request({ url = "http://example.com/hello", method = method })
            assert.are.same(
                { "curl", "-i", "-X", method, "http://example.com/hello" },
                system_stub.calls[1].vals[1]
            )
        end)
    end

    it("builds query parameters", function()
        http.request({
            url = "http://example.com/hello",
            query = {
                param_string = "abc",
                param_integer = 123,
                param_boolean = true,
                param_escaped = "abc\n=%",
            },
        })
        assert.are.same({
            "curl",
            "-i",
            "-X",
            "GET",
            "http://example.com/hello?param_boolean=true&param_escaped=abc%0D%0A%3D%25&param_integer=123&param_string=abc",
        }, system_stub.calls[1].vals[1])
    end)

    it("omits query string when query is empty", function()
        http.request({ url = "http://example.com/hello", query = {} })
        assert.are.same({
            "curl",
            "-i",
            "-X",
            "GET",
            "http://example.com/hello",
        }, system_stub.calls[1].vals[1])
    end)

    it("sends JSON body and Content-Type header", function()
        http.request({
            method = "POST",
            url = "http://example.com/hello",
            body = { key = "value", count = 42 },
        })
        assert.are.same({
            "curl",
            "-i",
            "-X",
            "POST",
            "--data-raw",
            '{"key": "value", "count": 42}',
            "-H",
            "Content-Type: application/json",
            "http://example.com/hello",
        }, system_stub.calls[1].vals[1])
    end)

    it("uses custom curl path", function()
        http.request({ url = "http://example.com/hello" }, { curl_path = "/opt/bin/curl" })
        assert.are.same({
            "/opt/bin/curl",
            "-i",
            "-X",
            "GET",
            "http://example.com/hello",
        }, system_stub.calls[1].vals[1])
    end)

    it("uses unix socket", function()
        http.request({ url = "http://example.com/hello" }, { unix_socket = "/var/run/docker.sock" })
        local args = system_stub.calls[1].vals[1]
        assert.is_true(vim.tbl_contains(args, "--unix-socket"))
        assert.is_true(vim.tbl_contains(args, "/var/run/docker.sock"))
    end)

    it("returns status, headers, and decoded JSON body", function()
        system_stub.returns({
            wait = function()
                return {
                    code = 0,
                    stdout = "HTTP/1.1 201 Created\r\nContent-Type: application/json\r\nX-Request-Id: abc-123\r\n\r\n{\"ok\":true}",
                    stderr = "",
                }
            end,
        })

        local result = http.request({ url = "http://example.com/hello" })
        assert.are.same(201, result.status)
        assert.are.same({ ok = true }, result.body)
        assert.are.same("application/json", result.headers["content-type"])
        assert.are.same("abc-123", result.headers["x-request-id"])
    end)

    it("returns raw body when response is not JSON", function()
        system_stub.returns({
            wait = function()
                return {
                    code = 0,
                    stdout = "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\n\r\nhello world",
                    stderr = "",
                }
            end,
        })

        local result = http.request({ url = "http://example.com/hello" })
        assert.are.same(200, result.status)
        assert.are.same("hello world", result.body)
        assert.are.same("text/plain", result.headers["content-type"])
    end)

    it("get helper sets method and returns response table", function()
        system_stub.returns({
            wait = function()
                return {
                    code = 0,
                    stdout = "HTTP/1.1 200 OK\r\n\r\n{\"method\":\"GET\"}",
                    stderr = "",
                }
            end,
        })

        local result = http.get({ url = "http://example.com/hello" })
        assert.are.same({ method = "GET" }, result.body)
        assert.are.same(200, result.status)
        assert.are.same({
            "curl",
            "-i",
            "-X",
            "GET",
            "http://example.com/hello",
        }, system_stub.calls[1].vals[1])
    end)

    it("post helper sets method and returns response table", function()
        system_stub.returns({
            wait = function()
                return {
                    code = 0,
                    stdout = "HTTP/1.1 200 OK\r\n\r\n{\"method\":\"POST\"}",
                    stderr = "",
                }
            end,
        })

        local result = http.post({ url = "http://example.com/hello" })
        assert.are.same({ method = "POST" }, result.body)
        assert.are.same(200, result.status)
        assert.are.same({
            "curl",
            "-i",
            "-X",
            "POST",
            "http://example.com/hello",
        }, system_stub.calls[1].vals[1])
    end)

    it("errors on non-zero exit code", function()
        system_stub.returns({
            wait = function()
                return { code = 7, stdout = "", stderr = "connection refused" }
            end,
        })

        local ok, err = pcall(function()
            http.request({ method = "GET", url = "http://example.com/hello" })
        end)

        assert.is_false(ok)
        assert.is_truthy(err)
        assert.matches("exit_code=7", err)
        assert.matches("connection refused", err)
    end)
end)
