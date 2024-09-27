--!nolint LocalShadow

-- from: https://github.com/itsfrank/frkcli

local process = require("@lune/process")

local M = {}

type ArgKind = "POSITIONAL" | "FLAG" | "OPTION"
type ArgOptions = {
    help: string?,
    aliases: { string }?,
    default: string?, -- if this is not nil, the arg will be optional
}

-- this is what is stored, we guarante non nullity when args are added so this types makes Luau feel better
type ArgOptionsSafe = {
    help: string,
    aliases: { string },
    default: string?,
}

type ArgData = {
    name: string,
    kind: ArgKind,
    options: ArgOptionsSafe,
}

type ParseResult = {
    values: { [string]: string },
    flags: { [string]: boolean },
}

local DEFAULT_OPTIONS: ArgOptionsSafe = {
    help = "",
    default = nil,
    aliases = {},
}

local DEFAULT_HELP_SET = {
    ["-h"] = true,
    ["--help"] = true,
}

local function validateKeyOrError(key: string)
    if (key:sub(1, 2) == "--" or key:sub(1, 1) == "-") and not key:find(" ") then
        return
    end
    error(`arg key {key} is invalid. Keys must start with either '-' or '--' and may not contain spaces`)
end

function M.new(name: string, description: string?, helpKeys: { string }?)
    -- args that trigger print help + abort
    local helpSet: { [string]: boolean } = DEFAULT_HELP_SET
    if helpKeys ~= nil then
        helpSet = {}
        for _, k in helpKeys do
            helpSet[k] = true
        end
    end

    -- I'm fairly certain this is not the right pattern for making objects, but it results in single definition + great LSP so I'm happy
    local cli = {}
    cli.name = name
    cli.description = description
    cli._helpSet = helpSet
    cli._positionals = {} :: { ArgData }
    cli._flags = {} :: { ArgData }
    cli._options = {} :: { ArgData }
    cli._nameSet = {} :: { [string]: boolean }
    cli._requiredList = {} :: { string }
    cli._lookup = {} :: { [string]: ArgData }
    cli._requiredPositionalCount = 0
    cli._defaultResult = { values = {}, flags = {} } :: ParseResult

    local function addArgLookups(keys: { string }, argData: ArgData)
        for _, k in keys do
            if cli._helpSet[k] ~= nil then
                error(`key '{k}' is already used as a help key.`)
            end
            validateKeyOrError(k)
            if cli._lookup[k] ~= nil then
                error(`key '{k}' already exists.`)
            end
            cli._lookup[k] = argData
        end
    end

    local function addNameErrorOnDuplicate(name: string)
        if cli._nameSet[name] ~= nil then
            error(`arg with name {name} already exists`)
        end
        cli._nameSet[name] = true
    end

    local function makseSafeOptions(options: ArgOptions?): ArgOptionsSafe
        if options == nil then
            return DEFAULT_OPTIONS
        end
        assert(options)

        options.aliases = if options.aliases == nil then {} else options.aliases

        return options :: ArgOptionsSafe
    end

    function cli:addPositional(name: string, options: ArgOptions?)
        local options = makseSafeOptions(options)

        local argData: ArgData = {
            name = name,
            kind = "POSITIONAL",
            options = options,
        }
        addNameErrorOnDuplicate(name)
        if options.default == nil then
            -- check positional required ordering, can't have a required pos after an optional one
            local last = cli._positionals[#cli._positionals]
            if last ~= nil and last.options.default ~= nil then
                error(
                    `{name} is required, but {last.name} is optional. Cannot have required positional after optional positional`
                )
            end

            table.insert(cli._requiredList, name)
        else
            cli._defaultResult.values[name] = options.default
        end
        table.insert(cli._positionals, argData)
    end

    function cli:addFlag(name: string, options: ArgOptions?)
        if options and options.default ~= nil then
            -- these are called constants :)
            error(`flag {name} has non nil default, default value is not supported for flags`)
        end

        local options = makseSafeOptions(options)

        local argData: ArgData = {
            name = name,
            kind = "FLAG",
            options = options,
        }
        addNameErrorOnDuplicate(name)
        addArgLookups({ "--" .. name, table.unpack(options.aliases) }, argData)

        if options.default ~= nil then
            error(`flag {name} has non nil default value, defaults are not supported for flag args`)
        end

        cli._defaultResult.flags[name] = false
        table.insert(cli._flags, argData)
    end

    function cli:addOption(name: string, options: ArgOptions?)
        local options = makseSafeOptions(options)

        local argData: ArgData = {
            name = name,
            kind = "OPTION",
            options = options,
        }
        addNameErrorOnDuplicate(name)
        addArgLookups({ "--" .. name, table.unpack(options.aliases) }, argData)
        if options.default == nil then
            table.insert(cli._requiredList, name)
        else
            if options.default == nil then
                error(`optional arg {name} must have a default value`)
            end
            assert(options.default ~= nil)
            cli._defaultResult.values[name] = options.default
        end
        table.insert(cli._options, argData)
    end

    -- return: data, err - where data is a table, and err is a string
    -- errors early, first encountered error ends the parse
    -- if a help key is found will print help text and exit the process
    function cli:parse(args: { string }): (ParseResult?, string?)
        local parsed: ParseResult = { values = {}, flags = {} } :: ParseResult

        local positionalIdx = 1
        local skipNext = false -- used for options
        for i, arg in args do
            -- asking for help?
            if cli._helpSet[arg] ~= nil then
                print(cli:help())
                process.exit(0)
            end

            if skipNext then
                skipNext = false
                continue
            end

            local hasDash = arg:sub(1, 1) == "-"
            local argData: ArgData? = nil
            local value: string? = nil

            if not hasDash then -- positional
                if positionalIdx > #cli._positionals then
                    return nil, `too many positional arguments, expected {#cli._positionals}.`
                end
                argData = cli._positionals[positionalIdx]
                value = arg
            else -- flag or option
                argData = cli._lookup[arg]
            end

            if argData == nil then
                return nil, `unknown flag or option: '{arg}'`
            end
            assert(argData ~= nil)

            -- handle flags early
            if argData.kind == "FLAG" then
                parsed.flags[argData.name] = true
                continue
            end

            -- get option value
            if argData.kind == "OPTION" then
                if i < #args then
                    value = args[i + 1]
                    skipNext = true
                end
            end

            -- resolve positionals and options
            if value == nil then
                return nil, `no value provided for option '{arg}'`
            end
            assert(value ~= nil)

            parsed.values[argData.name] = value
        end

        -- check all required options are provided
        for _, name in cli._requiredList do
            if parsed.values[name] == nil and parsed.flags[name] == nil then
                return nil, `required arg '{name}' was not found`
            end
        end

        -- apply defaults for missing optional
        for k, v in cli._defaultResult.flags do
            if parsed.flags[k] == nil then
                parsed.flags[k] = v
            end
        end
        for k, v in cli._defaultResult.values do
            if parsed.values[k] == nil then
                parsed.values[k] = v
            end
        end

        return parsed, nil
    end

    function cli:help(indent: number?): string
        local ind = "  "
        if indent ~= nil then
            ind = string.rep(" ", indent)
        end

        local helpLines: { { string } } = {}

        -- usage
        local usage = `usage: {cli.name}`
        if #cli._flags > 0 or #cli._options > 0 then
            usage ..= " [options]"
        end
        for _, arg in cli._positionals do
            if arg.options.default == nil then
                usage ..= ` <{arg.name}>`
            else
                usage ..= ` [{arg.name}]`
            end
        end
        table.insert(helpLines, { usage })

        -- description
        if cli.description ~= nil then
            table.insert(helpLines, {})
            table.insert(helpLines, { "description:" })
            table.insert(helpLines, { ind, cli.description })
        end

        local function makeArgLine(arg: ArgData): { string }
            local keys = arg.name
            if arg.kind ~= "POSITIONAL" then
                keys = `--{arg.name}`
                for _, a in arg.options.aliases do
                    keys ..= `, {a}`
                end
            end

            local desc = ""
            -- optional & default
            if arg.kind ~= "FLAG" then
                if arg.options.default == nil then
                    desc ..= "[required]"
                else
                    assert(arg.options.default)
                    desc ..= `[default:  '{arg.options.default}']`
                end
            end

            if arg.options.help then
                if desc ~= "" then
                    desc ..= " "
                end
                desc ..= arg.options.help
            end

            return { ind, keys, desc }
        end

        -- positionals
        if #cli._positionals > 0 then
            table.insert(helpLines, {})
            table.insert(helpLines, { "positional arguments:" })
            for _, arg in cli._positionals do
                table.insert(helpLines, makeArgLine(arg))
            end
        end

        -- flags
        if #cli._flags > 0 then
            table.insert(helpLines, {})
            table.insert(helpLines, { "flags:" })
            for _, arg in cli._flags do
                table.insert(helpLines, makeArgLine(arg))
            end
        end

        -- options
        if #cli._options > 0 then
            table.insert(helpLines, {})
            table.insert(helpLines, { "options:" })
            for _, arg in cli._options do
                table.insert(helpLines, makeArgLine(arg))
            end
        end

        local helpText = ""
        for _, line in helpLines do
            helpText ..= table.concat(line, " ") .. "\n"
        end
        return helpText
    end

    return cli
end

return M
