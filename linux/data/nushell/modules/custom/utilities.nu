module utilities {
  # Open a file's raw text and apply syntax highlighting.
  #
  # Uses `nu_plugin_highlight` under the hood.
  export def read [
    path?: path # The path to the file to open
  ]: [oneof<nothing, string> -> string] { default $path | open --raw | highlight }

  def "dyn expand" [resolve: bool]: list<string> -> path {
    path join | if $resolve { $in | path expand } else { $in }
  }

  # Join a string or path with a preset or specified separator character.
  #
  # If no flag is passed, the default behavior will first try that of `--resolve`.
  # If the full path does not exist, then `--space` will be used.
  #
  # Pass the `--path` or `--resolve` flags to always treat the strings
  # as path segments even if the final path does not exist.
  @category core
  export def join [
    --char (-c): string # Join the strings with `char <value>`
    --resolve (-r) # Same as `--path` but pipes to `path expand`
    --none (-n) # Join the strings with no separator
    --esep (-e) # Join the strings with `char env_sep`
    --path (-p) # Join the strings with `char path_sep`
    --space (-s) # Join the strings with spaces
    --lines (-l) # Join the strings with `char line_sep`
    --nullable = true # Return null for empty lists (throws otherwise)
  ]: list<string> -> string {
    match {x: $in ?: $nullable} {
      {x: $ls} if ($ls | is-not-empty) => {
        if $none or $char != null {
          str join $char
        } else if $path or $resolve {
          dyn expand $resolve
        } else if $space {
          str join (char sp)
        } else if $lines {
          str join (char lsep)
        } else if $esep {
          str join (char esep)
        } else {
          let base: path = $in | path join | path expand
          if ($base | path exists) { return $base }
          $in | str join (char sp)
        }
      }
      {?: true} => { null }
      {?: false} => { error make --unspanned "no strings were provided" }
    }
  }
  # Replace the current shell instance with a fresh one.
  #
  # Optionally, a record can be piped in which will be merged into
  # the process environment.
  @category shells
  export def --env reload [
    --erase (-e) # Erase the history (clear without keeping scrollback)
    --force (-f) # Clear the cached PID to allow rerunning startup actions
    --login (-l) = true # Run Nushell as a login shell
  ]: oneof<nothing, record> -> nothing {
    default {} | load-env
    if $force { $env.pid = null }
    if $erase { clear } else { clear --keep-scrollback }
    if $login { exec nu --login } else { exec nu }
  }
  export alias rl = reload
  # Memoize (cache) a computed value.
  #
  # True memoization would require awareness of dependency state
  # to only recompute if the result would change. This is NOT implemented
  # in this function; instead use the `--recompute <bool>` flag to
  # monitor on the consumer side to indicate when recomputation is necessary.
  @category core
  export def --env memoize [
    --recompute (-r) = false # Whether to recompute the value even if cached
  ]: closure -> oneof<nothing, any> {
    let c: closure = $in
    let key: string = try { $c | to text | hash md5 } catch { '__memo_cache' }
    if $recompute { hide-env $key }
    $env | get --optional $key | default {
      let value: any = do --env --ignore-errors $c
      load-env {($key): $value}
      return $value
    }
  }
}

export use utilities *
