function join_strings(a: string, b: string, opts: { sep: string }?)
    local sep = ", "
    if opts ~= nil then
        sep = opts.sep
    end
    local res = `{a}{sep}{b}`
    print(`the result: {res}`)
    return {
        result = res,
    }
end

-- task file must return a function
return join_strings
