local Workshop = require("workshop.workshop")
local api = require("workshop.api")

---@class Project
---Client used for this project.
---@field client WorkshopClient
---Daemon ID of the project.
---@field id string
local Project = {}
Project.__index = Project

---Project paths mapped to a project ID.
---@type table<string, Project>
Project._registered_projects = {}

---@param client WorkshopClient
---@param id string
---@return Project
Project.new = function(client, id)
    local project = setmetatable({}, Project)
    project.client = client
    project.id = id
    return project
end

---Produce the `Project` for a given root directory.
---@param client WorkshopClient
---@param root string
---@returns Project
Project.ensure = function(client, root)
    if Project._registered_projects[root] then
        return Project._registered_projects[root]
    end

    local project = api.ensure_project(client, root)
    Project._registered_projects[root] = Project.new(client, project.id)

    return Project._registered_projects[root]
end

---List workshops available in this project.
---@return Workshop[]
function Project:workshops()
    local api_workshops = api.list_workshops(self.client, self.id)

    local workshops = {}

    -- Pre-fill files, so they can be later overridden.
    for _, file in ipairs(api_workshops.files) do
        local workshop = Workshop.from_file(self.client, file)
        workshops[workshop.name] = workshop
    end

    -- Fill running workshops, overridding any file definitions.
    for _, info in ipairs(api_workshops.workshops) do
        local existing = workshops[info.name] or {}
        local workshop = Workshop.from_info(self.client, info, existing.path)
        workshops[workshop.name] = workshop
    end

    return workshops
end

return Project
