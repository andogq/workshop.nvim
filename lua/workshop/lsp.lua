local Project = require("workshop.project")

local M = {}

---@alias StartFunction fun(config: vim.lsp.ClientConfig, opts?: vim.lsp.start.Opts): integer?

---@param client WorkshopClient
---@return Project?
local get_project = function(client)
    local root = vim.fs.root(0, { ".workshop" })

    if root then
        return Project.ensure(client, root)
    end

    return nil
end

---@param workshops table<string, Workshop>
---@return Workshop?
local select_workshop = function(workshops)
    local workshop = nil
    local keys = vim.tbl_keys(workshops)
    if #keys == 0 then
        vim.notify("[workshop.nvim] no workshops found in project", vim.log.levels.WARN)
    else
        if #keys > 1 then
            vim.notify(
                "[workshop.nvim] multiple workshops found, selecting first",
                vim.log.levels.WARN
            )
        end

        workshop = workshops[keys[1]]
    end
    return workshop
end

---@param client WorkshopClient
---@param cmd string[]
---@return fun(dispatchers: vim.lsp.rpc.Dispatchers, config: vim.lsp.ClientConfig): vim.lsp.rpc.PublicClient
local create_lsp_cmd = function(client, cmd)
    return function(dispatchers, config)
        -- Copy the cmd so it can be modified.
        cmd = vim.list_extend({}, cmd --[[ @as string[] ]])

        -- Update the cmd.
        local root = vim.fs.root(0, { ".workshop" })
        if root then
            local project = Project.ensure(client, root)
            local workshops = project:workshops()
            local workshop = select_workshop(workshops)
            if workshop then
                workshop:start({ allow_launch = true })

                local mappings = require("workshop").config.path_mapping
                if mappings[config.name] then
                    cmd = mappings[config.name](root, cmd)
                end

                cmd = workshop:build_exec_command(cmd, {
                    env = config.cmd_env,
                })
            end
        end

        -- Start the standard LSP RPC client.
        return vim.lsp.rpc.start(
            cmd,
            dispatchers,
            { cwd = config.cmd_cwd, env = config.cmd_env, detached = config.detached }
        )
    end
end

---Wrap the provided start function.
---@param client WorkshopClient
---@param start StartFunction
---@return StartFunction
M.wrap_start = function(client, start)
    return function(config, opts)
        -- If `config.cmd` is a function, it cannot be redirected to the workshop.
        if type(config.cmd) == "function" then
            if get_project(client) ~= nil then
                vim.notify(
                    "[workshop.nvim] couldn't launch LSP in workshop as config.cmd is a function",
                    vim.log.levels.ERROR
                )
            end
            return start(config, opts)
        end

        config.cmd = create_lsp_cmd(client, config.cmd --[[ @as string[] ]])

        return start(config, opts)
    end
end

return M
