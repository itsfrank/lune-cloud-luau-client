--!nolint LocalShadow

local fs = require("@lune/fs")
local LuaEncode = require("./LuaEncode")
local tasks_client = require("./tasks_client")

local m_tasks = {}

export type Error = tasks_client.TasksError

export type RequestParams = {
    api_key: string,
    universe_id: number | string,
    place_id: number | string,
    place_version: (number | string)?,
}

function m_tasks.encode_task_from_file(file_path: string, ...): (string?, Error?)
    local task_fn_str = fs.readFile(file_path)
    return m_tasks.encode_task(task_fn_str, ...)
end

function m_tasks.encode_task(task_fn_str: string, ...): (string?, Error?)
    local args = { ... }
    local args_encode = ""
    local ok, err = pcall(function()
        args_encode = LuaEncode(args, { OutputWarnings = false })
    end)
    if not ok then
        return nil, { message = `error encoding args: {err}` }
    end

    local task_encode =
        `function t() {task_fn_str}\nend;\nfunction a() return {args_encode}\nend\nreturn t()(table.unpack(a()))`
    return task_encode
end

function m_tasks.create_from_file(file_path: string, req_params: RequestParams)
    local task_str = fs.readFile(file_path)
    return m_tasks.create(task_str, req_params)
end

function m_tasks.create(task_str: string, req_params: RequestParams)
    local task = {
        task_str = task_str,
        req_params = req_params,
    }

    type TaskHandle = typeof(make_task_handle("", {}, { api_key = "", universe_id = "", place_id = "" }))

    function task:call(...): (TaskHandle?, Error?)
        self = self :: typeof(task)
        local task_encode, err = m_tasks.encode_task(task_str, ...)
        if err ~= nil then
            return nil, err
        end
        assert(task_encode ~= nil)

        local res, err = tasks_client.create_task(task_encode, self.req_params)
        if err ~= nil then
            return nil, err
        end
        assert(res) -- create_task ensure res contains a member named 'path'

        return make_task_handle(res.path, res, req_params)
    end

    return task
end

function make_task_handle(path: string, task_create_res: any, req_params: RequestParams)
    local handle = {
        path = path,
        req_params = req_params,
        task_create_res = task_create_res,
    }

    type TaskResult = typeof(make_task_result({}))

    function handle:wait(poll_options): (TaskResult?, Error?)
        self = self :: typeof(task)

        return make_task_result({})
    end

    return handle
end

function make_task_result(data: any)
    return {
        data = data,
    }
end

return m_tasks
