module path {
  # Retrieve or replace the extension of a path.
  @category filesystem
  export def extension [
    --replace (-r): string # The extension to replace the current with
  ]: path -> path {
    let parsed: record<parent: path, stem: string, extension: string> = $in | path parse
    if $replace == null { return $parsed.extension }
    $"($parsed.parent)($parsed.stem).($replace | str trim --left --char .)"
  }
  # Truncate a path by segment count or relativity to a base path.
  #
  # The `--from` argument uses regex matching on the first character
  # so `--from s` and `--from start` are both valid and will result
  # in the same behavior.
  @category filesystem
  export def truncate [
    n: int = -1 # The number of segments to truncate to
    --root (-r): path # The base path to use as relative anchor
    --from (-f): string = end # Remove segments from start|end
  ]: [
    table<name: string> -> table<name: string>
    list<oneof<path, string>> -> list<oneof<path, string>>
  ] {
    let queue: any = $in
    let trim: closure = if $from =~ e {
      {|n: int| last $n }
    } else if $from =~ s {
      {|n: int| first $n }
    } else { error make --unspanned $'unknown value for `--from`: ($from)' }
    let glob: bool = $queue | any {|x| $x not-has name }
    $queue | par-each --keep-order {|item|
      let base: path = if $glob { $item } else { $item.name }
        | if $root == null { $in } else { path relative-to ($root | path expand) }
      let list: list<string> = $base | path split
      let keep: int = $list | length
        | if $n < 0 { $in } else { append $n | math min }
      let path: path = $list | do $trim $keep | path join
      if $glob { $path } else { $item | update name $path }
    } | collect
  }
  # Select a path from the input interactively.
  @category platform
  export def select [
    column: string = name # Column name to extract the path value from
    --message (-m): string = `no files to select from` # Error message if the input is empty
    --optional (-o) # No-op on empty input instead of making an error
  ]: [
    oneof<list, table> -> path
    nothing -> list
  ] {
    if ($in | is-not-empty) {
      let prompt: string = $"open file with ($env.EDITOR? | default editor)"
      $in | input list --fuzzy $"(ansi dark_gray)($prompt)(ansi rst)" | get --optional $column
    } else if not $optional {
      error make $message
    }
  }
  # Check if command(s) are available on PATH.
  #
  # Note that `all` is used for the test so if more than one
  # name is provided then any missing command will return false.
  @category filesystem
  export def "on path" [name?: string]: oneof<nothing, string, list<string>> -> bool {
    append $name
    | compact --empty
    | all { which $in | is-not-empty }
  }
}

export use path *
