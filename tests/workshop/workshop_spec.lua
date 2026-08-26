local Workshop = require("workshop.workshop")
local api = require("workshop.api")
local assert = require("luassert")
local stub = require("luassert.stub")

describe("workshop.workshop", function()
    local client = {}

    describe(".new", function()
        it("stores the provided fields on the workshop", function()
            local workshop =
                Workshop.new(client, "ws-a", "proj-1", "/root/a.yaml", true, "On", "a.wp")

            assert.same(client, workshop.client)
            assert.equals("ws-a", workshop.name)
            assert.equals("proj-1", workshop.project)
            assert.equals("/root/a.yaml", workshop.path)
            assert.is_true(workshop.launched)
            assert.equals("On", workshop.status)
            assert.equals("a.wp", workshop.hostname)
        end)

        it("leaves hostname nil when not provided", function()
            local workshop =
                Workshop.new(client, "ws-a", "proj-1", "/root/a.yaml", false, "Unknown", nil)

            assert.is_nil(workshop.hostname)
        end)
    end)

    describe(".from_info", function()
        it("builds a launched workshop from workshop info", function()
            local workshop = Workshop.from_info(client, {
                ["project-id"] = "proj-1",
                name = "ws-a",
                path = "/root/a.yaml",
                status = "On",
                hostname = "a.wp",
            })

            assert.same(client, workshop.client)
            assert.equals("ws-a", workshop.name)
            assert.equals("proj-1", workshop.project)
            assert.equals("/root/a.yaml", workshop.path)
            assert.is_true(workshop.launched)
            assert.equals("On", workshop.status)
            assert.equals("a.wp", workshop.hostname)
        end)

        it("works without optional hostname", function()
            local workshop = Workshop.from_info(client, {
                ["project-id"] = "proj-2",
                name = "ws-b",
                path = "/root/b.yaml",
                status = "Off",
            })

            assert.equals("ws-b", workshop.name)
            assert.equals("proj-2", workshop.project)
            assert.is_true(workshop.launched)
            assert.equals("Off", workshop.status)
            assert.is_nil(workshop.hostname)
        end)
    end)

    describe(".from_file", function()
        it("builds an unlaunched workshop from a definition file", function()
            local workshop = Workshop.from_file(client, {
                ["project-id"] = "proj-1",
                name = "ws-a",
                path = "/root/a.yaml",
            })

            assert.same(client, workshop.client)
            assert.equals("ws-a", workshop.name)
            assert.equals("proj-1", workshop.project)
            assert.equals("/root/a.yaml", workshop.path)
            assert.is_false(workshop.launched)
            assert.equals("Unknown", workshop.status)
            assert.is_nil(workshop.hostname)
        end)
    end)

    describe(":start", function()
        local workshop
        local lifecycle_stub

        before_each(function()
            lifecycle_stub = stub(Workshop, "lifecycle_action")
        end)

        after_each(function()
            lifecycle_stub:revert()
        end)

        it("launches an unlaunched workshop when allow_launch is true", function()
            workshop = Workshop.from_file(client, {
                ["project-id"] = "proj-1",
                name = "ws-a",
                path = "/root/a.yaml",
            })

            local result = workshop:start({ allow_launch = true })

            assert.is_true(result)
            assert.spy(lifecycle_stub).was_called_with(workshop, "launch")
            assert.spy(lifecycle_stub).was_called(1)
        end)

        it("returns false for an unlaunched workshop when allow_launch is false", function()
            workshop = Workshop.from_file(client, {
                ["project-id"] = "proj-1",
                name = "ws-a",
                path = "/root/a.yaml",
            })

            local result = workshop:start({ allow_launch = false })

            assert.is_false(result)
            assert.spy(lifecycle_stub).was_not_called()
        end)

        it("starts an off workshop", function()
            workshop = Workshop.new(client, "ws-a", "proj-1", "/root/a.yaml", true, "Off", nil)

            local result = workshop:start({})

            assert.is_true(result)
            assert.spy(lifecycle_stub).was_called_with(workshop, "start")
            assert.spy(lifecycle_stub).was_called(1)
        end)

        it("starts a workshop with unknown status", function()
            workshop = Workshop.new(client, "ws-a", "proj-1", "/root/a.yaml", true, "Unknown", nil)

            local result = workshop:start({})

            assert.is_true(result)
            assert.spy(lifecycle_stub).was_called_with(workshop, "start")
            assert.spy(lifecycle_stub).was_called(1)
        end)

        it("restarts a running workshop when allow_restart is true", function()
            workshop = Workshop.new(client, "ws-a", "proj-1", "/root/a.yaml", true, "On", "a.wp")

            local result = workshop:start({ allow_restart = true })

            assert.is_true(result)
            assert.spy(lifecycle_stub).was_called_with(workshop, "stop")
            assert.spy(lifecycle_stub).was_called_with(workshop, "start")
            assert.spy(lifecycle_stub).was_called(2)
        end)

        it("returns false for a running workshop when allow_restart is false", function()
            workshop = Workshop.new(client, "ws-a", "proj-1", "/root/a.yaml", true, "On", "a.wp")

            local result = workshop:start({})

            assert.is_false(result)
            assert.spy(lifecycle_stub).was_not_called()
        end)
    end)

    describe(":stop", function()
        local lifecycle_stub

        before_each(function()
            lifecycle_stub = stub(Workshop, "lifecycle_action")
        end)

        after_each(function()
            lifecycle_stub:revert()
        end)

        it("delegates to lifecycle_action with stop", function()
            local workshop =
                Workshop.new(client, "ws-a", "proj-1", "/root/a.yaml", true, "On", "a.wp")

            workshop:stop()

            assert.spy(lifecycle_stub).was_called_with(workshop, "stop")
            assert.spy(lifecycle_stub).was_called(1)
        end)
    end)

    describe(":lifecycle_action", function()
        local action_stub
        local wait_stub
        local fetch_stub

        before_each(function()
            action_stub = stub(api, "workshop_action")
            wait_stub = stub(api, "wait_change")
            fetch_stub = stub(Workshop, "fetch")
        end)

        after_each(function()
            fetch_stub:revert()
            wait_stub:revert()
            action_stub:revert()
        end)

        it("triggers the action, waits, and fetches the latest state", function()
            action_stub.returns({ id = "change-1" })

            local workshop =
                Workshop.new(client, "ws-a", "proj-1", "/root/a.yaml", true, "On", "a.wp")
            workshop:lifecycle_action("stop")

            assert.spy(action_stub).was_called_with(client, "proj-1", { "ws-a" }, "stop")
            assert.spy(wait_stub).was_called_with(client, "change-1")
            assert.spy(fetch_stub).was_called_with(workshop)
        end)
    end)

    describe(":fetch", function()
        local get_stub

        before_each(function()
            get_stub = stub(api, "get_workshop")
        end)

        after_each(function()
            get_stub:revert()
        end)

        it("updates the workshop fields from the API", function()
            get_stub.returns({
                ["project-id"] = "proj-1",
                name = "ws-a",
                path = "/root/a.yaml",
                status = "Off",
            })

            local workshop =
                Workshop.new(client, "ws-a", "proj-1", "/root/a.yaml", true, "On", "a.wp")
            workshop:fetch()

            assert.spy(get_stub).was_called_with(client, "proj-1", "ws-a")
            assert.equals("Off", workshop.status)
            assert.equals("a.wp", workshop.hostname)
            assert.is_true(workshop.launched)
        end)

        it("updates the hostname when the workshop starts running", function()
            get_stub.returns({
                ["project-id"] = "proj-1",
                name = "ws-a",
                path = "/root/a.yaml",
                status = "On",
                hostname = "a.wp",
            })

            local workshop =
                Workshop.new(client, "ws-a", "proj-1", "/root/a.yaml", false, "Unknown", nil)
            workshop:fetch()

            assert.equals("On", workshop.status)
            assert.equals("a.wp", workshop.hostname)
            assert.is_true(workshop.launched)
        end)
    end)
end)
