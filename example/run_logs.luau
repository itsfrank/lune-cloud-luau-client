--!nolint LocalShadow

local tasks = require("@llc_tasks/tasks")
local req_params = require("env_params")

local task_file = "example/task.luau"

local task = tasks.create_from_file(task_file, req_params)
local res, _ = task:call("a", "b")
assert(res ~= nil)
print("task completed sucessfully, output:")
print(res.output)

-- getting the logs requires an extra web request
local logs, _ = res:fetch_logs()
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
