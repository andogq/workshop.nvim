local Project = require("workshop.project")
local api = require("workshop.api")
local assert = require("luassert")
local stub = require("luassert.stub")

describe("workshop.project", function()
    local client = {}

    before_each(function()
        Project._registered_projects = {}
    end)

    describe(".new", function()
        it("stores the client and id on the project", function()
            local project = Project.new(client, "project-1")

            assert.same(client, project.client)
            assert.equals("project-1", project.id)
        end)
    end)

    describe(".ensure", function()
        local ensure_stub

        before_each(function()
            ensure_stub = stub(api, "ensure_project")
        end)

        after_each(function()
            ensure_stub:revert()
        end)

        it("calls api.ensure_project for an unseen root and caches the result", function()
            ensure_stub.returns({ id = "proj-foo" })

            local project = Project.ensure(client, "/foo")

            assert.spy(ensure_stub).was_called_with(client, "/foo")
            assert.equals("proj-foo", project.id)
            assert.same(client, project.client)
            assert.same(project, Project._registered_projects["/foo"])
        end)

        it("returns the cached project for a known root without calling the api again", function()
            ensure_stub.returns({ id = "cached-id" })

            local first = Project.ensure(client, "/bar")
            local second = Project.ensure(client, "/bar")

            assert.spy(ensure_stub).was_called(1)
            assert.same(first, second)
        end)
    end)

    describe(":workshops", function()
        local project
        local ensure_stub
        local list_stub

        before_each(function()
            ensure_stub = stub(api, "ensure_project")
            ensure_stub.returns({ id = "proj-1" })

            list_stub = stub(api, "list_workshops")

            project = Project.ensure(client, "/root")
        end)

        after_each(function()
            list_stub:revert()
            ensure_stub:revert()
        end)

        it("returns an empty table when there are no files or running workshops", function()
            list_stub.returns({ files = {}, workshops = {} })

            local workshops = project:workshops()

            assert.spy(list_stub).was_called_with(client, "proj-1")
            assert.same({}, workshops)
        end)

        it("builds workshops from definition files", function()
            list_stub.returns({
                files = {
                    { ["project-id"] = "proj-1", name = "file-a", path = "/root/a.yaml" },
                },
                workshops = {},
            })

            local workshops = project:workshops()

            assert.is_not_nil(workshops["file-a"])
            assert.equals("file-a", workshops["file-a"].name)
            assert.equals("proj-1", workshops["file-a"].project)
            assert.equals("/root/a.yaml", workshops["file-a"].path)
            assert.is_false(workshops["file-a"].launched)
            assert.equals("Unknown", workshops["file-a"].status)
        end)

        it("builds workshops from running workshops", function()
            list_stub.returns({
                files = {},
                workshops = {
                    {
                        ["project-id"] = "proj-1",
                        name = "running-a",
                        path = "/root/a.yaml",
                        status = "On",
                        hostname = "a.wp",
                    },
                },
            })

            local workshops = project:workshops()

            assert.is_not_nil(workshops["running-a"])
            assert.equals("running-a", workshops["running-a"].name)
            assert.equals("proj-1", workshops["running-a"].project)
            assert.is_true(workshops["running-a"].launched)
            assert.equals("On", workshops["running-a"].status)
            assert.equals("a.wp", workshops["running-a"].hostname)
        end)

        it("overrides file workshops with running workshops of the same name", function()
            list_stub.returns({
                files = {
                    { ["project-id"] = "proj-1", name = "shared", path = "/root/shared.yaml" },
                },
                workshops = {
                    {
                        ["project-id"] = "proj-1",
                        name = "shared",
                        path = "/root/shared.yaml",
                        status = "On",
                    },
                },
            })

            local workshops = project:workshops()

            assert.is_not_nil(workshops["shared"])
            assert.is_true(workshops["shared"].launched)
            assert.equals("On", workshops["shared"].status)
        end)

        it("merges distinct file and running workshops", function()
            list_stub.returns({
                files = {
                    { ["project-id"] = "proj-1", name = "off", path = "/root/off.yaml" },
                },
                workshops = {
                    {
                        ["project-id"] = "proj-1",
                        name = "on",
                        path = "/root/on.yaml",
                        status = "On",
                    },
                },
            })

            local workshops = project:workshops()

            assert.is_not_nil(workshops["off"])
            assert.is_false(workshops["off"].launched)
            assert.is_not_nil(workshops["on"])
            assert.is_true(workshops["on"].launched)
        end)
    end)
end)
