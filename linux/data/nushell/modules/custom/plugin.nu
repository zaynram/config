module plugin {
    # Install a plugin using cargo and automatically add it
    #
    @category plugin
    export def install [
        name: oneof<path, string> # The name of the plugin (must start with 'nu_plugin_')
        --owner(-o): string # The owner of the repository to install from
    ]: nothing -> nothing {
        let args: list = match $owner {
            null => [$name]
            _    => [--git $'https://github.com/($owner)/($name).git']
        }
        try {
            cargo install ...$args
            plugin add (
                $env.CARGO_HOME?
                | default ($nu.home-dir | path join .cargo)
                | path join bin $name
            )
        } catch {
            error make {
                msg: "plugin installation failed"
                labels: [
                    {
                        text: `plugin`
                        span: (metadata $name).span
                    }
                    {
                        text: `arguments`
                        span: (metadata $args).span
                    }
                ]
            }
        }
    }
}

export use plugin *
