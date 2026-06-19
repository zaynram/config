# ——— ~/.config/nushell/login.nu ——————————————————————————————————————————————
# metadata = { drafted: 2026-06-11, author: ramda }

# ——— constants ———————————————————————————————————————————————————————————————
const __usr: record = {
  autoload: $nu.user-autoload-dirs.0?
  bin: /usr/bin/
  config: ($nu.default-config-dir | path dirname)
  data: ($nu.data-dir | path dirname)
  home: $nu.home-dir
  local: ($nu.home-dir | path join .local)
  modules: ($nu.data-dir | path join modules)
  scripts: ($nu.data-dir | path join scripts)
  plugins: ($nu.data-dir | path join plugins)
}

const __vdr: record = {
  autoload: $nu.vendor-autoload-dirs.2?
  plugins: ($nu.data-dir | path join plugins (version).version)
}

job spawn {
  let missing: list = $__usr | merge $__vdr | values | where ($it | path type) == null
  if ($missing | is-empty) { return }
  for $d in $missing { try { mkdir --verbose $d } }
}

const NU_LIB_DIRS = [$__usr.scripts $__usr.modules]
const NU_PLUGIN_DIRS = [($nu.current-exe | path dirname) $__usr.plugins]

# ——— imports——————————————————————————————————————————————————————————————————
use std/util "path add"
use custom [ path plugin ]
use custom/alias.nu *
use custom/utilities.nu *

# ——— environment —————————————————————————————————————————————————————————————
load-env {
  XDG_CONFIG_HOME: ($env.XDG_CONFIG_HOME? | default $__usr.config)
  XDG_DATA_HOME: ($env.XDG_DATA_HOME? | default $__usr.data)
  PNPM_HOME: ($__usr.data | path join pnpm)
  NUPM_HOME: ($__usr.data | path join nupm)
  TOPIARY_CONFIG_FILE: ($__usr.config | path join topiary languages.ncl)
  TOPIARY_LANGUAGE_DIR: ($__usr.config | path join topiary queries)
  CARAPACE_LENIENT: 1
  CARAPACE_BRIDGES: `fish,bash,cobra,argcomplete,urfavecli,complete,click,yargs,kitten,tealdeer,tldr-python-client`
  NU_LIB_DIRS: [
    ...($env.nu_lib_dirs? | default [])
    ($__usr.data | path join nupm | path join modules)
  ]
}

# ——— activation ——————————————————————————————————————————————————————————————
if $nu.is-interactive and $env.pid? == null {
  let posh_config: path = $__usr.config | path join oh-my-posh prompt.json
  let carapace_nu: path = $nu.vendor-autoload-dirs | last | path join carapace.nu
  try {
    oh-my-posh init nu --config $posh_config
    carapace _carapace nushell | save --force $carapace_nu
    $env.pid = $nu.pid
    fortune | ansi gradient --fgstart 0x40c9ff --fgend 0xe81cff | print
  } catch {
    error make --unspanned "shell startup exited with errors"
  }
}

# ——— custom commands —————————————————————————————————————————————————————————

def "error wrap" [
  msg: string # An error message to include in the rendered output
  --code: string # An optional identifier to contextualize the error
]: oneof<nothing, error> -> error {
  error make --unspanned ({msg: $msg code: $code} | compact --empty)
}

module usr {
  # Interact with a plugin definition file or directory.
  @category core
  export def plugins [
    target?: string # The name of the plugin to target
    --directory (-d) # Resolve the target as a directory and open its `mod.nu` file
  ]: nothing -> nothing {
    let dir: directory = $__usr.plugins
    try { mkdir $dir; cd $dir } catch {
      error wrap "could not resolve config directory" --code usr::plugins::unresolved_directory
    }
    if $target == null {
      let choice: path = try { ls --full-paths **/mod.nu } catch { [] }
        | path truncate --root .
        | path select --message "could not detect any installed plugins"
      if $choice != null { editor $choice }
    } else {
      let resolved: path = if $directory { $target | path join mod.nu } else { $target | path extension --replace nu }
      editor $resolved
    }
  }

  # Interact with a module definition file.
  @category core
  export def modules [
    target?: string # The name of the module to target
    --directory (-d) # Resolve the target as a directory and open its `mod.nu` file
  ]: nothing -> nothing {
    let dir: directory = $__usr.modules
    try { mkdir $dir; cd $dir } catch {
      error wrap "could not resolve config directory" --code usr::modules::unresolved_directory
    }
    if $target == null {
      let choice: path = try { ls --full-paths **/*.nu }
        | path truncate --root .
        | path select --message "could not detect any modules"
      if $choice != null { editor $choice }
    } else {
      let resolved: path = if $directory { $target | path join mod.nu } else { $target | path extension --replace nu }
      editor $resolved
    }
  }

  # Interact with a file from an autoload directory.
  #
  # If the `target` argument is omitted, the items in the directory will be listed.
  @category core
  export def autoload [
    target?: string # The name of the autoload file to target
    --user (-u) = true # Set `false` to use the vendor autoload directory
    --path (-p) # Return the resolved path instead of default behavior
  ]: nothing -> oneof<nothing, table> {
    let dir: path = if $user { $__usr } else { $__vdr } | get autoload
    try { mkdir $dir; cd $dir } catch {
      error wrap "could not resolve autoload directory" --code usr::autoload::unresolved_directory
    }
    let resolved: path = if $target == null {
      try { ls --short-names } | path select --message "could not detect any scripts"
    } else {
      $target | path extension --replace nu
    }
    if $path or $resolved == null { return $resolved }
    editor $resolved
  }

  const EXCLUDE: list<string> = [
    vale/styles/
    helix/runtime/
    logs/
    `.(bck|shm|wal|msgpackz|sqlite3)`
    `Code - Insiders`
    `nushell/(autoload/|history.txt)`
    google-chrome-for-testing
  ]

  # Edit a non-nushell configuration file.
  #
  # If no `target` is provided, the eligible target candidates are listed instead.
  @category filesystem
  export def config [
    # nu-lint-ignore: kebab_case_commands
    target?: oneof<string, path> # The directory name to search for config files under
    --glob (-g): glob # Glob expression to gather files within the parent directory
    --path (-p): path # Exact path (relative to target if provided, otherwise `~/.config`) of a file to edit
  ]: nothing -> oneof<nothing, table> {
    let dir: path = [$__usr.config $target] | compact --empty | path join
    try { mkdir $dir; cd $dir } catch {
      error wrap "could not resolve config directory" --code usr::config::unresolved_directory
    }

    if $path != null { editor $path | return }

    let notmatch: string = $EXCLUDE | str join '|'
    let children: list = try {
      ls --full-paths ($glob | default { '**/*' | into glob }) | where name !~ $notmatch
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

  const this: path = path self | path expand
  # Open the `login.nu` configuration file in an editor, or return
  # the resolved path as a string.
  export def login [
    --path (-p) # Return the path instead of opening the file in `editor`
  ]: nothing -> oneof<nothing, path> {
    if $path { return $this } else { editor $this }
  }

  # Navigate to (or print) a directory value from the `usr` record.
  export def --env main [
    key: oneof<string, cell-path> # Key of the $__usr constant
    --cd # Navigate to the directory instead of returning the path
  ]: nothing -> oneof<nothing, path> {
    let target: directory = $__usr
      | get --ignore-case --optional $key
      | default { error make --unspanned $'unknown key: ($key)' }
    if not $cd { return $target } else { cd $target }
  }
}

use usr
