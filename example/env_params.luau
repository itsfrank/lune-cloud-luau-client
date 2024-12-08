-- get the request params from env vars
local process = require("@lune/process")

local params = {
    api_key = process.env["RBX_OC_TASKS_API_KEY"] :: string,
    universe_id = process.env["RBX_OC_TASKS_UNIVERSE_ID"] :: string,
    place_id = process.env["RBX_OC_TASKS_PLACE_ID"] :: string,
    place_version = nil, -- not sure why I have to include this one, lsp yells at me if i dont
}

if params.api_key == nil or params.api_key == "" then
    error(`env var 'RBX_OC_TASKS_API_KEY' must be set for this example to work`)
end
if params.universe_id == nil or params.universe_id == "" then
    error(`env var 'RBX_OC_TASKS_UNIVERSE_ID' must be set for this example to work`)
end
if params.place_id == nil or params.place_id == "" then
    error(`env var 'RBX_OC_TASKS_PLACE_ID' must be set for this example to work`)
end

return params
