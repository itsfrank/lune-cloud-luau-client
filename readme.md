# lune-cloud-luau-client

> If you are looking to execute tasks from your own Lune scripts, I rewrote
> this entire project as a library with a muhch more ergonomic API for use from
> lune scripts. You can find it in the [ergo-input](https://github.com/itsfrank/lune-cloud-luau-client/tree/ergo-input?tab=readme-ov-file) branch

This is a lune port of the sample client script provided by Roblox in the
[announcement](https://devforum.roblox.com/t/beta-open-cloud-engine-api-for-executing-luau/3172185?u=itsfrank17) of the Open Cloud
Engine API for Executing Luau beta.

### usage

#### Prerequisites

1. Make sure you have lune installed: [documentation](https://lune-org.github.io/docs/getting-started/1-installation)
2. Make an api key for the API: [instructions the announcement](https://devforum.roblox.com/t/beta-open-cloud-engine-api-for-executing-luau/3172185?u=itsfrank17)
    - put the key in a file and use the `-k` option
    - or set the `RBLX_OC_API_KEY` environment variable with your key as the value

#### CLI

The CLI is documented via help text:
```
> lune cloud-luau-task.luau -- --help
```

#### Example

you can find an example invocation and output in the [example](example) folder
