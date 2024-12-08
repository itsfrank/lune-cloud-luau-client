# lune-luau-cloud-tasks (llc_tasks)

Run cloud luau tasks ergonomically with typechecking!

With llc_tasks, you can execute a task by calling it just like you would a
normal function. And, optionally, the call and return can fully leverage Luau's
typesystem.

```Luau
-- my_task.luau
return function(a: string, b: string)
    print(`a: {a}, b: {b}`)
    return `{a}, {b}`
end

-- run.luau
local llc_tasks = require("@llc_tasks/tasks")

local task_file = "./my_task"
local task = llc_tasks.create_from_file(task_file, {api_key="...", universe_id=123, place_id=321})

-- we are ignoring errors, check out the examples/error_handling folder for error handling
local res, _ = task:call("hello", "world")
assert(res.output == "hello, world")

local logs, _ = res:fetch_logs()
assert(logs[1] == "a: hello, b: world")
```

Run the above with `lune run run.luau`

## Typechecking

If your task is in a luau file that returns a function, you can get typechecking like so:

```Luau
-- function is never used, only passed for type inferrence
local _task_fn = require("./my_task")
-- pass the required function as the last param
local task = llc_tasks.create_from_file("./my_task", {...}, _task_fn)

local res, _ = task:call() -- this would error, since the input is (string, string)
local sum = res.result + 1 -- error, 'res.result' is string, not number
```

This has the advantage of making your tasks reusable, any module that returns a function is now a cloud task!**

** module that doesn't require anything that will not be in the place where the task is executed
