# nu-lint-ignore-file: kebab_case_commands
module config {
  use std/math
  const MODULES_DIR: path = $nu.data-dir | path join modules
  const PLUGINS_DIR: path = $nu.data-dir | path join plugins | path join (version).version

  def "simple error" [
    msg: string
    fn: string
  ]: oneof<error, record, nothing> -> error {
    error make --unspanned {
      msg: $msg
      code: $'autoload::config::($fn)::error'
      labels: []
      inner: ([$in] | compact)
    }
  }

  def --env "go to" [path: path]: nothing -> nothing {
    if not ($path | path exists) { mkdir $path }
    cd $path | return
  }

  def "path extension" [--replace (-r): string]: oneof<string, path> -> path {
    let parsed: record<parent: path, stem: string, extension: string> = $in | path parse
    if $replace == null { return $parsed.extension }
    $"($parsed.parent)($parsed.stem).($replace | str trim --left --char .)"
  }

  def "path truncate" [n?: int --root (-r): path]: [
    oneof<table, list> -> table
    nothing -> list
  ] {
    default []
    | par-each --keep-order {|item|
      let name: string = if $root != null {
        $item.name | path relative-to $root
      } else {
        let parts: list = $item | get name | path split
        let final: int = [($n | default 2) ($parts | length)] | math min
        $item.name | path split | last $final | path join
      }
      $item | update name $name
    }
    | collect
  }

  def "path select" [
    column: string = name
    --message (-m): string = `no files to select from`
  ]: [
    oneof<list, table> -> path
    nothing -> list
  ] {
    let paths: list = $in | default []
    if ($paths | is-empty) {
      simple error $message path_select
    } else {
      let prompt: string = $"open file with ($env.EDITOR? | default editor)"
      $paths
      | input list --fuzzy $"(ansi dark_gray)($prompt)(ansi rst)"
      | get --optional $column
    }
  }

  # Interact with a plugin definition file or directory.
  @category core
  export def /plugin [
    target?: string # The name of the plugin to target
    --directory (-d) # Resolve the target as a directory and open its `mod.nu` file
  ]: nothing -> nothing {
    try { go to $PLUGINS_DIR } catch {
      simple error "could not resolve plugin directory" /plugin
    }
    if $target == null {
      let choice: path = try { ls --full-paths **/mod.nu }
        | path truncate --root $PLUGINS_DIR
        | path select --message "could not detect any installed plugins"
      if $choice != null { editor $choice }
    } else {
      let resolved: path = if $directory { $target | path join mod.nu } else { $target | path extension --replace nu }
      editor $resolved
    }
  }

  # Interact with a module definition file.
  @category core
  export def /module [
    target?: string # The name of the module to target
    --directory (-d) # Resolve the target as a directory and open its `mod.nu` file
  ]: nothing -> nothing {
    # nu-lint-ignore: kebab_case_commands
    try { go to $MODULES_DIR } catch {
      simple error "could not resolve modules directory" /module
    }
    if $target == null {
      let choice: path = try { ls --full-paths **/*.nu }
        | path truncate --root $MODULES_DIR
        | path select --message "could not detect any modules"
      if $choice != null { editor $choice }
    } else {
      let resolved: path = if $directory { $target | path join mod.nu } else { $target | path extension --replace nu }
      editor $resolved
    }
  }

  const USER_AUTO: path = path self .
  const VENDOR_AUTO: path = $nu.vendor-autoload-dirs.2?

  # Return the path to an autoload directory.
  export def --env "autoload path" [
    name?: string # Stem or filename of a Nushell script
    --user (-u) # Target the user-autoload-dirs instead of vendor
    --goto (-g) # Navigate to the directory and return null
  ]: [
    nothing -> oneof<string, nothing>
    string -> string
    list<string> -> list<string>
  ] {
    let auto: path = if $user { $USER_AUTO } else { $VENDOR_AUTO }
    if $goto { cd $auto | return }
    if ([$in $name] | all {|x| $x == null }) { return $auto }
    $in | append [$name]
    | compact --empty
    | par-each --keep-order {|n| $auto | path join $'($n | path parse | get stem).nu' }
    | if ($in | length) > 1 { $in } else { $in.0? }
  }
  # Interact with a file from an autoload directory.
  #
  # If the `target` argument is omitted, the items in the directory will be listed.
  @category core
  export def /autoload [
    target?: string # The name of the autoload file to target
    --user (-u) = true # Set `false` to use the vendor autoload directory
  ]: nothing -> oneof<nothing, table> {
    let dir: path = if $user { $USER_AUTO } else { $VENDOR_AUTO }
    try { go to $dir } catch {
      simple error "could not resolve autoload directory" /autoload
    }
    if $target == null {
      let choice: path = try {
        ls --short-names
      } | path select --message "could not detect any scripts"
      if $choice != null { editor $choice }
    } else {
      let resolved: path = $target | path extension --replace nu
      editor $resolved
    }
  }

  const DOT_CONFIG: path = $nu.home-dir | path join .config
  const FILTER: string = 'nushell/(autoload/|history.txt)|Code - Insiders|google-chrome-for-testing|helix/runtime|.(bck|shm|wal|msgpackz|sqlite3)'
  # Edit a non-nushell configuration file.
  #
  # If no `target` is provided, the eligible target candidates are listed instead.
  @category filesystem
  export def /config [
    # nu-lint-ignore: kebab_case_commands
    target?: oneof<string, path> # The directory name to search for config files under
    --glob (-g): glob # Glob expression to gather files within the parent directory
    --path (-p): path # Exact path (relative to target if provided, otherwise `~/.config`) of a file to edit
  ]: nothing -> oneof<nothing, table> {
    let dir: path = [$DOT_CONFIG $target] | compact --empty | path join
    try { go to $dir } catch {
      simple error "could not resolve config directory" /config
    }

    if $path != null { editor $path | return }

    let pattern: glob = $glob | default { '**/*' | into glob }
    let children: list = try {
      ls --full-paths $pattern | where name !~ $FILTER
    } catch { [] }
    let files: list = $children | where type == file
    let count: int = $files | length

    if ($files | is-empty) {
      let choice: path = try {
        $children
        | each { ls ($in | path join **/*) }
        | flatten
        | path truncate --root $dir
        | path select --message "could not detect any external configuration files"
      }
      if $choice != null { editor $choice } | return
    } else if $count > 1 {
      let choice: path = $files | path truncate --root $dir | path select
      if $choice != null { editor $choice } | return
    } else if $count == 1 {
      editor ...$files | return
    } else {
      error make {
        msg: "could not resolve configuration file"
        label: {
          text: target
          span: (metadata $target).span
        }
      }
    }
  }
}

overlay use config
