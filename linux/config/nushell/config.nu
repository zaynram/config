# ——— config.nu ———————————————————————————————————————————————————————————————
# manager = cargo
# version = "0.112.2"
# docs = { cli: "config nu --doc | nu-highlight | less -R",
#          web: "https://www.nushell.sh/book/configuration.html" }

# ——— environment —————————————————————————————————————————————————————————————
load-env {
  EDITOR: /usr/bin/hx
  VISUAL: (
    [/mnt/c/Users/ramda/AppData/Local/Programs]
    | append 'Microsoft VS Code Insiders'
    | path join bin code-insiders
  )
}
# ——— configuration ———————————————————————————————————————————————————————————
$env.config.buffer_editor = $env.EDITOR
$env.config.edit_mode = "emacs"
$env.config.show_banner = false
$env.config.highlight_resolved_externals = true
$env.config.table.mode = "compact"
$env.config.table.index_mode = "auto"
$env.config.table.header_on_separator = true
$env.config.table.batch_duration = 300ms
$env.config.table.missing_value_symbol = "×"
$env.config.history.file_format = "sqlite"
$env.config.history.max_size = 10_000
$env.config.history.isolation = true
$env.config.rm.always_trash = true
$env.config.auto_cd_implicit = true
$env.config.clip.resident_mode = false
$env.config.cursor_shape.emacs = "blink_underscore"
$env.config.completions.external.max_results = 50
$env.config.use_kitty_protocol = true
$env.config.error_style = "nested"
$env.config.error_lines = 2
$env.config.display_errors.termination_signal = false
$env.config.keybindings ++= [
  {
    name: reload_config
    modifier: none
    keycode: f5
    mode: [emacs vi_normal vi_insert]
    event: {
      send: executehostcommand
      cmd: (
        [
          ...(try { ls $nu.user-autoload-dirs | get name } | default [])
          $nu.env-path
          $nu.config-path
        ] | where ($it | path type) == file
        | par-each --keep-order { $'source `($in)`' } | str join '; '
      )
    }
  }
]
