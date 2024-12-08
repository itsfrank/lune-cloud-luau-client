local tasks = require("@tasks/tasks")
local req_params = require("env_params")

local task_file = "example/task.luau"
local task_fn = require("./task.luau") -- (optional) used only for type-information

local task = tasks.create_from_file(task_file, req_params, task_fn)

-- task.poll_opts has polling settings
-- defaults: {poll_wait_seconds = 1, poll_max_attempts = -1, on_poll = nil}
task.poll_opts.poll_wait_seconds = 2 -- wait 2 seconds between polls for result
task.poll_opts.poll_max_attempts = 10 -- error if poll more than that (-1 to poll forever, default)
task.poll_opts.on_poll = function(body, res)
    print(`polled task status, res code: {res.statusCode}`)
    print(`task state: {body["state"]}`)
end

local res, _ = task:call("a", "b")
assert(res ~= nil)

print("task completed sucessfully, output:")
print(res.output)
