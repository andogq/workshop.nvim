local cli = require("workshop.cli")
local assert = require("luassert")

describe("workshop.cli", function()
    describe("build_exec_command", function()
        it("builds a basic exec command", function()
            local command = cli.build_exec_command("/project", "dev", { "bash" })

            assert.same({
                "workshop",
                "exec",
                "-p",
                "/project",
                "dev",
                "--",
                "bash",
            }, command)
        end)

        it("uses a custom working directory", function()
            local command = cli.build_exec_command(
                "/project",
                "dev",
                { "ls" },
                { cwd = "/tmp" }
            )

            assert.same({
                "workshop",
                "exec",
                "-p",
                "/project",
                "-w",
                "/tmp",
                "dev",
                "--",
                "ls",
            }, command)
        end)

        it("injects environment variables", function()
            local command = cli.build_exec_command(
                "/project",
                "dev",
                { "env" },
                { env = { FOO = "bar", BAZ = "qux" } }
            )

            assert.same({
                "workshop",
                "exec",
                "-p",
                "/project",
                "--env",
                "BAZ=qux",
                "--env",
                "FOO=bar",
                "dev",
                "--",
                "env",
            }, command)
        end)

        it("handles an empty opts table", function()
            local command = cli.build_exec_command("/project", "dev", { "bash" }, {})

            assert.same({
                "workshop",
                "exec",
                "-p",
                "/project",
                "dev",
                "--",
                "bash",
            }, command)
        end)

        it("handles a command with multiple arguments", function()
            local command = cli.build_exec_command(
                "/project",
                "dev",
                { "python", "-c", "print('hello')" }
            )

            assert.same({
                "workshop",
                "exec",
                "-p",
                "/project",
                "dev",
                "--",
                "python",
                "-c",
                "print('hello')",
            }, command)
        end)
    end)
end)
