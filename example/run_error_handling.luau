--!nolint LocalShadow

local tasks = require("@tasks/tasks")
local req_params = require("env_params")

local task_file = "example/input/task.luau"
local task_fn = require("./task.luau") -- (optional) used only for type-information

-- create a task, task.create() takes a string, create_from_file is just a QoL wrapper
local task = tasks.create_from_file(task_file, req_params, task_fn)

local res, err = task:call("a", "b")

-- if the task does not succeed, err will contain a helpful message
-- as well as the response of the failed request (if applciable)
if err ~= nil then
    print(`error calling task: {err.message}`)
    if err.res then
        print(`with failure response:`)
        print(err.res)
    end
    return
end
assert(res ~= nil)

print("task completed sucessfully, output:")
print(res.output)

-- getting the logs requires an extra web request
local logs, err = res:fetch_logs()

-- same error pattern as call
if err ~= nil then
    print(`error fetching logs: {err.message}`)
    if err.res then
        print(`with failure response:`)
        print(err.res)
    end
    return
end
assert(logs ~= nil)

print("")
if #logs == 0 then
    print("task did not generate any logs")
else
    print("task logs:")
    for _, l in logs do
        print(`  {l}`)
    end
end
