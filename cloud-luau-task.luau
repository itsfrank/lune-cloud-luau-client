--!nolint LocalShadow

local frkcli = require("pkg/frkcli")

local fs = require("@lune/fs")
local net = require("@lune/net")
local stdio = require("@lune/stdio")
local process = require("@lune/process")
local task = require("@lune/task")
local datetime = require("@lune/datetime")
local serde = require("@lune/serde")

local function makeCli()
    local cli = frkcli.new(
        "cloud-luau-task",
        "A client for the Roblox Open Cloud Engine API for Executing Luau written in Luau for Lune"
    )

    cli:addOption("api-key", {
        aliases = { "-k" },
        help = "Path to a file containing your OpenCloud API key. You can also use the environment variable RBLX_OC_API_KEY to specify the API key. This option takes precedence over the environment variable.",
        default = "",
    })
    cli:addOption("universe", {
        aliases = { "--experience", "-u", "-e" },
        help = "ID of the experience (a.k.a. universe) containing the place you want to execute the task against.",
    })
    cli:addOption("place", {
        aliases = { "-p" },
        help = "ID of the place you want to execute the task against.",
    })
    cli:addOption("place-version", {
        aliases = { "-v" },
        help = "Version of the place you want to execute the task against. If not given, the latest version of the place will be used.",
        default = "",
    })
    cli:addOption("script-file", {
        aliases = { "-f" },
        help = "Path to a file containing your Luau script.",
    })
    cli:addOption("output", {
        aliases = { "-o" },
        help = "Path to a file to write the task's output to. If not given, output is written to stdout.",
        default = "",
    })
    cli:addOption("log-output", {
        aliases = { "-l" },
        help = "Path to a file to write the task's logs to. If not given, logs are written to stderr.",
        default = "",
    })
    cli:addFlag("continuous", {
        aliases = { "-c" },
        help = "If specified, this script will run in a loop and automatically create a new task after the previous task has finished, but only if the script file is updated. If the script file has not been updated, this script will wait for it to be updated before submitting a new task.",
    })

    return cli
end

local LOG_ERROR = "error"
-- local LOG_WARN = "warn"
local LOG_INFO = "info"

local _logs: { string } = {}
local _log_to_stderr = true
function log(level, message: string)
    local logLine = `[{datetime.now():toIsoDate()}] [{level}]: {message}`
    if _log_to_stderr then
        stdio.ewrite(logLine)
        stdio.ewrite("\n")
    else
        table.insert(_logs, logLine)
    end
end

local function trim(s)
    -- remove leadin/trailing whitespace and trailing\n
    return string.gsub(s, '^%s*(.-)%s*$', '%1')
end

local function validateMember(obj: any, key: string | number, objName: string)
    if obj[key] == nil then
        log(LOG_ERROR, `expected key '{key}' not found in {objName}, script may be out of date`)
    end
end

function readFileExitOnFailure(path): string
    local success, res = pcall(function()
        return fs.readFile(path)
    end)

    if success then
        return res
    end

    log(LOG_ERROR, `reading file: {path}\n{res}`)
    process.exit(1)
    return res
end

function makeRequest(url: string, headers: { [string]: string }, body: any?): (net.FetchResponse?, string?)
    local maxAttempts = 3
    for i = 1, maxAttempts do
        local res = net.request({
            url = url,
            headers = headers,
            method = if body == nil then "GET" else "POST",
            body = if body ~= nil then net.jsonEncode(body) else nil,
        })

        if res.ok then
            return res
        end

        log(LOG_ERROR, `Request failed: {res.statusCode} {res.statusMessage} retrying...`)
        log(LOG_ERROR, `url: {url}`)
        if res ~= nil then
            log(LOG_ERROR, `response: {net.jsonEncode(res, true)}`)
        end
        task.wait(1)
    end
    return nil, "Request failed: max retry attempts"
end

function loadApiKey(apiKeyArg: string): string
    local source = ""
    local key: string = ""
    if apiKeyArg ~= "" then
        local apiKeyArg = trim(apiKeyArg)
        source = `file {apiKeyArg}`
        key = trim(readFileExitOnFailure(apiKeyArg))
    elseif process.env["RBLX_OC_API_KEY"] ~= nil then
        source = "environment variable RBLX_OC_API_KEY"
        key = trim(process.env["RBLX_OC_API_KEY"])
    else
        log(LOG_ERROR, "API key missing, One of: option --api-key or env var RBLX_OC_API_KEY must be used")
    end

    if key == "" then
        log(LOG_ERROR, `failed reading api key from {source}`)
        process.exit(1)
    end

    return key
end

function createTask(apiKey: string, script: string, universeId: string, placeId: string, placeVersion: string)
    local headers = {
        ["Content-Type"] = "application/json",
        ["x-api-key"] = apiKey,
    }

    local data = {
        ["script"] = script,
    }

    local url = `https://apis.roblox.com/cloud/v2/universes/{universeId}/places/{placeId}/`
    if placeVersion ~= "" then
        url ..= `versions/{placeVersion}/`
    end
    url ..= "luau-execution-session-tasks"

    local res, err = makeRequest(url, headers, data)
    if err ~= nil then
        log(LOG_ERROR, `create task failed: {err}`)
        process.exit(1)
    end

    assert(res ~= nil)
    return net.jsonDecode(res.body)
end

function pollForTaskCompletion(apiKey: string, path: string)
    local headers = {
        ["x-api-key"] = apiKey,
    }
    local url = `https://apis.roblox.com/cloud/v2/{path}`
    log(LOG_INFO, "Waiting for task to finish...")

    while true do
        local res, err = makeRequest(url, headers)
        if err ~= nil then
            log(LOG_ERROR, `get task info failed: {err}`)
        end
        assert(res ~= nil)

        local luauTask = net.jsonDecode(res.body)
        validateMember(luauTask, "state", "taskPollResponse")
        if luauTask["state"] ~= "PROCESSING" then
            return luauTask
        else
            task.wait(2)
        end
    end
end

function getTaskLogs(apiKey: string, taskPath: string): { string }
    local headers = {
        ["x-api-key"] = apiKey,
    }
    local url = `https://apis.roblox.com/cloud/v2/{taskPath}/logs`

    local res, err = makeRequest(url, headers)
    if err ~= nil then
        log(LOG_ERROR, `get task logs failed: {err}`)
        process.exit(1)
    end
    assert(res ~= nil)

    local logs = net.jsonDecode(res.body)

    validateMember(logs, "luauExecutionSessionTaskLogs", "taskLogsResponse")
    if #logs["luauExecutionSessionTaskLogs"] == 0 then
        return {} -- no logs found
    end
    validateMember(logs["luauExecutionSessionTaskLogs"][1], "messages", "taskLogsEntry")
    return logs["luauExecutionSessionTaskLogs"][1]["messages"]
end

function handleLogs(task: any, apiKey: string, logOutputFilePath: string)
    validateMember(task, "path", "taskCompleteResponse")
    local logs = getTaskLogs(apiKey, task["path"])
    if #logs == 0 then
        log(LOG_INFO, "the task did not produce any logs")
        return
    end

    if logOutputFilePath == "" then
        log(LOG_INFO, "Task logs:")
        for _, l in logs do
            log(LOG_INFO, `  {l}`)
        end
    else
        local success, err = pcall(function()
            fs.writeFile(logOutputFilePath, table.concat(logs, "\n"))
            log(LOG_INFO, `Task logs written to: {logOutputFilePath}`)
        end)

        if not success then
            log(LOG_ERROR, `writing log file failed: {err}`)
            process.exit(1)
        end
    end
end

function handleSuccess(task: any, ouptutPath: string)
    validateMember(task, "output", "taskCompleteResponse")
    local output = task["output"]

    if output["results"] then
        if ouptutPath == "" then
            log(LOG_INFO, "Task output:")
            log(LOG_INFO, net.jsonEncode(output["results"], true))
        else
            local success, err = pcall(function()
                fs.writeFile(ouptutPath, net.jsonEncode(output["results"], true))
                log(LOG_INFO, `Task results written to: {ouptutPath}`)
            end)
            if not success then
                log(LOG_ERROR, `writing result file failed: {err}`)
                process.exit(1)
            end
        end
    else
        log(LOG_INFO, "The task did not return any results")
    end
end

function handleFailure(task: any)
    log(LOG_ERROR, `Task failed, error:\n{net.jsonEncode(task["error"])}`)
end

function main()
    --
    local cli = makeCli()
    local args, err = cli:parse(process.args)
    if err ~= nil then
        log(LOG_ERROR, `failed to parse args: {err}`)
        process.exit(1)
    end
    assert(args ~= nil)
    local apiKey = loadApiKey(args.values["api-key"])
    --
    local waitingPrinted = false
    local prevScriptHash = nil
    while true do
        local script = readFileExitOnFailure(args.values["script-file"])
        local scriptHash = serde.hash("sha256", script)
        if scriptHash == prevScriptHash then
            if not waitingPrinted then
                log(LOG_INFO, "Waiting for changes to script file...")
                waitingPrinted = true
            end
            task.wait(0.5)
            continue
        end
        if prevScriptHash ~= nil then
            log(LOG_INFO, "Detected change to script file, submitting new task")
        end
        prevScriptHash = scriptHash
        waitingPrinted = false

        local task =
            createTask(apiKey, script, args.values["universe"], args.values["place"], args.values["place-version"])
        log(LOG_INFO, `Task created, path: {task["path"]}`)

        task = pollForTaskCompletion(apiKey, task["path"])
        log(LOG_INFO, `Task is now in {task["state"]} state`)

        handleLogs(task, apiKey, args.values["log-output"])
        if task["state"] == "COMPLETE" then
            handleSuccess(task, args.values["output"])
        else
            handleFailure(task)
        end

        if not args.flags["continuous"] then
            break
        end
    end
end

main()
