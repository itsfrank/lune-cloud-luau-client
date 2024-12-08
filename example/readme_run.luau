-- run.luau
local req_params = require("env_params")
local llc_tasks = require("@llc_tasks")

local task_file = "example/readme_my_task.luau"
local task = llc_tasks.create_from_file(task_file, req_params)

-- we are ignoring errors, check out the examples/error_handling folder for error handling
local res, _ = task:call("hello", "world")
assert(res.output == "hello, world")

local logs, _ = res:fetch_logs()
assert(logs[1] == "a: hello, b: world")
