local Project = require("workshop.project")
local WorkshopClient = require("workshop.client")

describe("workshop.project", function()
    local client = WorkshopClient.new()
    local fixture_root = vim.fn.getcwd() .. "/tests/fixtures/sample-project"

    local project = Project.ensure(client, fixture_root)

    it("loads the project from the daemon", function()
        assert.equal(client, project.client)

        -- Project ID is stored in `.workshop.lock`, so can be used for cross-checking.
        local expected_id = vim.fn.readfile(string.format("%s/.workshop.lock", fixture_root))[1]
        assert.equal(expected_id, project.id)
    end)

    it("lists workshops before launch", function()
        vim.system({ "workshop", "remove" }, { cwd = fixture_root }):wait()
        assert.equal(1, vim.tbl_count(project:workshops()))
    end)

    it("lists workshops after launch", function()
        vim.system({ "workshop", "launch" }, { cwd = fixture_root }):wait()
        assert.equal(1, vim.tbl_count(project:workshops()))
    end)
end)
