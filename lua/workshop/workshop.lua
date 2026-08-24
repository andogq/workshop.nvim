local api = require("workshop.api")

---@alias Status "On" | "Off" | "Pending" | "Waiting" | "Error" | "Unknown"

---@class Workshop
---Client used for this workshop.
---@field client WorkshopClient
---Name of the workshop.
---@field name string
---Project ID this workshop belongs to.
---@field project string
---Definition file.
---@field path string
---Whether this workshop has been launched.
---@field launched boolean
---Container status.
---@field status Status
---Hostname this workshop is accessible from (only if it's running).
---@field hostname? string
local Workshop = {}
Workshop.__index = Workshop

---@param client WorkshopClient
---@param name string
---@param path string
---@param launched boolean
---@param status Status
---@param hostname? string
Workshop.new = function(client, name, project, path, launched, status, hostname)
    local workshop = setmetatable({}, Workshop)
    workshop.client = client
    workshop.name = name
    workshop.project = project
    workshop.path = path
    workshop.launched = launched
    workshop.status = status
    workshop.hostname = hostname
    return workshop
end

---@param client WorkshopClient
---@param info workshop.api.WorkshopInfo
Workshop.from_info = function(client, info)
    return Workshop.new(
        client,
        info.name,
        info["project-id"],
        info.path,
        true,
        info.status,
        info.hostname
    )
end

---@param client WorkshopClient
---@param file workshop.api.WorkshopFile
Workshop.from_file = function(client, file)
    return Workshop.new(client, file.name, file["project-id"], file.path, false, "Unknown", nil)
end

---@class StartOpts
---If the workshop hasn't been started, launch it.
---@field allow_launch? boolean
---If the workshop is already running, restart it.
---@field allow_restart? boolean

---Start (optionally launching or restarting) the workshop. Returns `true` if the start is
---successful, `false` otherwise (including if launching/restarting) isn't allowed.
---@param opts StartOpts
---@returns boolean
function Workshop:start(opts)
    if not self.launched then
        if opts.allow_launch then
            self:lifecycle_action("launch")
            return true
        end

        return false
    end

    if self.status == "Off" or self.status == "Unknown" then
        self:lifecycle_action("start")
        return true
    elseif self.status == "On" and opts.allow_restart then
        self:lifecycle_action("stop")
        self:lifecycle_action("start")
        return true
    end

    return false
end

---Stop the workshop, if it's running.
function Workshop:stop()
    self:lifecycle_action("stop")
end

---Perform a lifecycle action on the workshop, and wait for it to complete.
---@param action "start" | "stop" | "launch"
function Workshop:lifecycle_action(action)
    -- Trigger the change.
    local change = api.workshop_action(self.client, self.project, { self.name }, action)
    api.wait_change(self.client, change.id)
    -- Ensure that the representation is up-to-date.
    self:fetch()
end

---Fetch the latest metadata from the API.
function Workshop:fetch()
    local updated =
        Workshop.from_info(self.client, api.get_workshop(self.client, self.project, self.name))
    for k, v in pairs(updated) do
        self[k] = v
    end
end

return Workshop
