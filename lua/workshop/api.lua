local M = {}

---@class workshop.api.HttpRequest
---
---URL of request.
---@field url string
---URL query, apended after the URL.
---@field query? table
---The request body.
---@field body? string|table
---The request form.
---@field form? table
---Additional curl arguments.
---@field raw? table
---Request headers.
---@field headers? table<string, string>

---@class workshop.api.HttpResponse
---
---Curl process exit code.
---@field exit integer
---HTTP status code.
---@field status integer
---Response headers.
---@field headers table
---Response body.
---@field body string

---@class workshop.api.HttpClient
---@field get fun(req: workshop.api.HttpRequest): workshop.api.HttpResponse
---@field post fun(req: workshop.api.HttpRequest): workshop.api.HttpResponse

---A project as returned by `/v1/projects` — a directory known to the daemon.
---@class workshop.api.Project
---@field id string
---@field path string

---@class workshop.api.HealthCheckInfo
---@field timestamp string
---@field message? string
---@field code? string

---@class workshop.api.StoreAccount
---@field id? string
---@field username? string
---@field ['display-name']? string
---@field validation? string

---@class workshop.api.SdkInfo
---@field name string
---@field version? string
---@field channel? string
---@field website? string
---@field publisher? workshop.api.StoreAccount
---@field source? string
---@field revision? string
---@field ['built-at']? string
---@field ['installed-at']? string
---@field ['health-check']? workshop.api.HealthCheckInfo

---@class workshop.api.SdkFullInfo
---@field name string
---@field website? string
---@field publisher? workshop.api.StoreAccount

---A launched workshop with a live status (`GET .../workshops` → `workshops`).
---@class workshop.api.WorkshopInfo
---@field ['project-id'] string
---@field name string
---@field base? string
---@field status string
---@field sdks? workshop.api.SdkInfo[]
---@field notes? string[]
---The workshop's routable hostname on the `.wp` domain. Sent with `omitempty`,
---so it is present only once the workshop is running and has a network identity.
---@field hostname? string
---Absolute path to the definition file. Only the single-workshop endpoint
---(`GET .../workshops/<name>`) includes it.
---@field path? string

---A workshop *definition file* on disk (`GET .../workshops` → `files`).
---These may exist without a running container — i.e. the workshop is `Off`.
---@class workshop.api.WorkshopFile
---@field ['project-id'] string
---@field name string
---@field path string

---@class workshop.api.WorkshopsResponse
---@field workshops? workshop.api.WorkshopInfo[]
---@field files? workshop.api.WorkshopFile[]

---A task's completion progress.
---`total` is 1 for indeterminate work.
---@class workshop.api.TaskProgress
---@field label string
---@field done number
---@field total number

---A single task within a change.
---@class workshop.api.ChangeTask
---@field id string
---@field kind string
---@field summary? string
---@field status string
---Verbose log lines emitted by the task (present when `verbose=true`).
---@field log? string[]
---Completion progress for the task.
---@field progress? workshop.api.TaskProgress
---Kind-specific data (e.g. an `exec` task carries `exit-code`).
---@field data? table<string, any>

---A daemon change: the async unit of work returned by mutating endpoints.
---@class workshop.api.Change
---@field id string
---@field kind string
---@field summary? string
---@field status string
---@field ready boolean
---@field err? string
---@field tasks? workshop.api.ChangeTask[]

---@param response workshop.api.HttpResponse
---@return table
local process_response = function(response)
    local body = vim.fn.json_decode(response.body)

    if body.type == "error" or response.status < 200 or response.status >= 300 then
        error("invalid API response")
    end

    return body.result
end

---@param response workshop.api.HttpResponse
---@return table
local decode_envelope = function(response)
    local body = vim.fn.json_decode(response.body)

    if body.type == "error" or response.status < 200 or response.status >= 300 then
        error("invalid API response")
    end

    return body
end

---@param value string
---@return string
local encode_url_part = function(value)
    return (
        value:gsub("[^%w%-%.%_%~]", function(c)
            return string.format("%%%02X", c:byte())
        end)
    )
end

---Fetch the daemon version.
---@param client workshop.api.HttpClient
---@return { version: string }
M.system_info = function(client)
    return process_response(client.get({ url = "/v1/system-info" }))
end

---List every project the daemon currently knows about.
---@param client workshop.api.HttpClient
---@return workshop.api.Project[]
M.projects = function(client)
    return process_response(client.get({ url = "/v1/projects" }))
end

---Look up a single project by its daemon ID. Returns `nil` when no project
---with that ID is currently registered.
---@param client workshop.api.HttpClient
---@param project_id string
---@return workshop.api.Project|nil
M.get_project = function(client, project_id)
    local all = M.projects(client)
    for _, project in ipairs(all) do
        if project.id == project_id then
            return project
        end
    end
    return nil
end

---Resolve a directory to a project, registering it with the daemon if it
---isn't known yet. This is the entry point for any per-directory query.
---@param client workshop.api.HttpClient
---@param project_path string
---@return workshop.api.Project
M.ensure_project = function(client, project_path)
    return process_response(client.post({
        url = "/v1/projects",
        body = { path = project_path },
    }))
end

---List the workshops of a project: both launched instances (with a live status)
---and definition files on disk (which may be `Off`).
---@param client workshop.api.HttpClient
---@param project_id string
---@return workshop.api.WorkshopsResponse
M.list_workshops = function(client, project_id)
    return process_response(client.get({
        url = "/v1/projects/" .. encode_url_part(project_id) .. "/workshops?state=available",
    }))
end

---Fetch the current state of a single workshop.
---`GET /v1/projects/<projectId>/workshops/<name>`
---@param client workshop.api.HttpClient
---@param project_id string
---@param name string
---@return workshop.api.WorkshopInfo
M.get_workshop = function(client, project_id, name)
    return process_response(client.get({
        url = "/v1/projects/" .. encode_url_part(project_id) .. "/workshops/" .. encode_url_part(
            name
        ),
    }))
end

---Fetch store/metadata details for a single SDK.
---@param client workshop.api.HttpClient
---@param name string
---@return workshop.api.SdkFullInfo
M.get_sdk_info = function(client, name)
    return process_response(client.get({
        url = "/v1/sdks/" .. encode_url_part(name),
    }))
end

---Post to an async endpoint and return the id of the change to wait on plus
---the (endpoint-specific) result payload.
---@param client workshop.api.HttpClient
---@param url_path string
---@param body? table
---@return { change: string, result: any }
M.post_async = function(client, url_path, body)
    local envelope = decode_envelope(client.post({
        url = url_path,
        body = body,
    }))

    if type(envelope) ~= "table" or type(envelope.change) ~= "string" then
        error("expected an async response with a change id")
    end

    return { change = envelope.change, result = envelope.result }
end

---Trigger a lifecycle action on one or more workshops and wait for the change
---to complete.
---
---`POST /v1/projects/<id>/workshops` with `{ names, action, options? }`
---returns an async change; we wait on it here so callers get back control
---only once the operation is fully done.
---
---When `options.mode` is `"wait-on-error"` the daemon pauses mid-build with
---status `"Wait"` instead of failing. In that case the change is returned
---as-is so the caller can decide whether to continue, abort, or debug.
---@param client workshop.api.HttpClient
---@param project_id string
---@param names string[]
---@param action "start"|"launch"|"stop"|"refresh"|"remove"
---@param options? { mode?: "transactional"|"wait-on-error"|"continue"|"abort", verbose?: boolean, refresh_option?: "update"|"restore" }
---@return workshop.api.Change
M.workshop_action = function(client, project_id, names, action, options)
    local body = { names = names, action = action }
    if options then
        local opts = {}
        if options.mode ~= nil then
            opts.mode = options.mode
        end
        if options.verbose ~= nil then
            opts.verbose = options.verbose
        end
        if options.refresh_option ~= nil then
            opts["refresh-option"] = options.refresh_option
        end
        body.options = opts
    end

    local async =
        M.post_async(client, "/v1/projects/" .. encode_url_part(project_id) .. "/workshops", body)

    local change = M.wait_change(client, async.change)

    if
        change.err and not (options and options.mode == "wait-on-error" and change.status == "Wait")
    then
        error(change.err)
    end

    return change
end

---Poll the current state of a change without blocking. Pass `verbose=true`
---to include task log lines in the response.
---
---Unlike `wait_change`, this returns immediately whether or not the change is
---still running; callers must loop until `change.ready` is `true`.
---@param client workshop.api.HttpClient
---@param change_id string
---@param verbose? boolean
---@return workshop.api.Change
M.get_change = function(client, change_id, verbose)
    local query = verbose and "?verbose=true" or ""
    return process_response(client.get({
        url = "/v1/changes/" .. encode_url_part(change_id) .. query,
    }))
end

---Wait for a change to finish and return it.
---@param client workshop.api.HttpClient
---@param change_id string
---@return workshop.api.Change
M.wait_change = function(client, change_id)
    return process_response(client.get({
        url = "/v1/changes/" .. encode_url_part(change_id) .. "/wait",
    }))
end

return M
