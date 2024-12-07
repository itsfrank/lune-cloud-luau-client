local luau = require("@lune/luau")

local tasks = require("@tasks/tasks")

local task_file = "example/input/task.luau"
local task_encode, _err = tasks.encode_task_from_file(task_file, "hello", "world", { sep = "---" })
assert(task_encode ~= nil)
print(task_encode)

local loaded = luau.load(task_encode)
print(loaded())
