local M = {}

---@class ExecOpts
---@field cwd? string Working directory in the workshop (defaults to `/project`)
---@field env? table<string, string> Environment variables to inject (if value is empty, it will be inherited).

---Build `workshop exec` command.
---@param project string Path to workshop project.
---@param workshop string Workshop name to execute command in.
---@param command string[] Command to execute.
---@param opts? ExecOpts
---@return string[]
M.build_exec_command = function(project, workshop, command, opts)
    if project == "" then
        error("project path not provided")
    end

    local exec_command = { "workshop", "exec", "-p", project }

    opts = opts or {}
    if opts.cwd then
        vim.list_extend(exec_command, { "-w", opts.cwd })
    end
    for var, value in vim.spairs(opts.env or {}) do
        vim.list_extend(exec_command, { "--env", string.format("%s=%s", var, value) })
    end

    -- Workshop name is only positional argument.
    table.insert(exec_command, workshop)

    -- Exec command follows `--`.
    table.insert(exec_command, "--")
    vim.list_extend(exec_command, command)

    return exec_command
end

return M
