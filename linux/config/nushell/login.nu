# ——— ~/.config/nushell/login.nu ——————————————————————————————————————————————
# metadata = { drafted: 2026-06-11, author: ramda }

# ——— constants ———————————————————————————————————————————————————————————————
const LOCATIONS: record = {
  autoload: $nu.user-autoload-dirs.0?
  bin: /usr/bin/
  config: ($nu.default-config-dir | path dirname)
  data: ($nu.data-dir | path dirname)
  home: $nu.home-dir
  local: ($nu.home-dir | path join .local)
  modules: ($nu.data-dir | path join modules)
  plugins: ($nu.data-dir | path join plugins (version).version)
  scripts: ($nu.data-dir | path join scripts)
}

# Navigate to (or print) a directory value from the `usr` record.
export def --env usr [
  key: oneof<string, cell-path> # Key of the $LOCATIONS constant
  --cd # Navigate to the directory instead of returning the path
]: nothing -> oneof<nothing, path> {
  let target: directory = $LOCATIONS
    | get --ignore-case --optional $key
    | default { error make --unspanned $'unknown key: ($key)' }
  if not $cd { return $target } else { cd $target }
}

job spawn {
  let missing: list = $LOCATIONS | values | where not ($it | path exists)
  if ($missing | is-empty) { return }
  for $d in $missing { try { mkdir --verbose $d } }
}

const NU_LIB_DIRS = [$LOCATIONS.scripts $LOCATIONS.modules]
const NU_PLUGIN_DIRS = [($nu.current-exe | path dirname) $LOCATIONS.plugins]

# ——— imports——————————————————————————————————————————————————————————————————
use std/util "path add"
use custom [ path plugin ]
use custom/alias.nu *
use custom/utilities.nu *

# ——— environment —————————————————————————————————————————————————————————————
load-env {
  XDG_CONFIG_HOME: ($env.XDG_CONFIG_HOME? | default { usr config })
  XDG_DATA_HOME: ($env.XDG_DATA_HOME? | default { usr data })
  PNPM_HOME: (usr data | path join pnpm)
  NUPM_HOME: (usr data | path join nupm)
  TOPIARY_CONFIG_FILE: (usr config | path join topiary languages.ncl)
  TOPIARY_LANGUAGE_DIR: (usr config | path join topiary queries)
  CARAPACE_LENIENT: 1
  CARAPACE_BRIDGES: `fish,bash,cobra,argcomplete,urfavecli,complete,click,yargs,kitten,tealdeer,tldr-python-client`
  NU_LIB_DIRS: [
    ...($env.nu_lib_dirs? | default [])
    (usr data | path join nupm | path join modules)
  ]
}

# ——— activation ——————————————————————————————————————————————————————————————
if $nu.is-interactive and $env.pid? == null {
  let posh_config: path = usr config | path join oh-my-posh prompt.json
  let carapace_nu: path = $nu.vendor-autoload-dirs | last | path join carapace.nu
  try {
    oh-my-posh init nu --config $posh_config
    carapace _carapace nushell | save --force $carapace_nu
  } catch {
    error make --unspanned "shell startup exited with errors"
  } finally {
    $env.pid = $nu.pid
    fortune | ansi gradient --fgstart 0x40c9ff --fgend 0xe81cff | print
  }
}
