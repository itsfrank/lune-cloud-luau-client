local tasks = require("@llc_tasks/tasks")
local req_params = require("env_params")

local task_file = "example/task_no_input.luau"
local task_fn = require("./task_no_input.luau") -- (optional) used only for type-information

-- create a task, task.create() takes a string, create_from_file is just a QoL wrapper
local task = tasks.create_from_file(task_file, req_params, task_fn)

-- call takes the same input as your function does
-- if you pass task_fn to tasks.create, call will be typechecked
local res, _ = task:call()
assert(res ~= nil)

print("task completed sucessfully, output:")
-- res.output will be properly typed, matching your function's return value if task_fn is passed
print(res.output)

local logs, _ = res:fetch_logs()
print(logs)
