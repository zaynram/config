# nu-lint-ignore-file: block_brace_spacing
module package {
  # Canonical source of registered "update" commands; run by `pkg update`
  const UPDATE_REGISTRY: list<record<target: string, command: list<string>>> = [
    [target command];
    [claude-code [claude upgrade]]
    [homebrew:* [brew upgrade]]
    [pipx:* [pipx upgrade-all]]
    [cargo:crates [cargo install-update --all]]
    [bun:bun [bun upgrade --canary]]
    [bun:node_modules [bun --global update]]
    [pixi:pixi [pixi self-update]]
    [pixi:tools [pixi global update]]
  ]
  # Read the logs for managed runs between the given dates or matching the pattern.
  #
  # Commands are run from within the user cache directory (usually `~/.cache`), so
  # patterns may expressed as relative paths.
  @category history
  export def "pkg hist" [
    ...match: oneof<string, glob> # Path or glob expression(s) to match filenames against
    --max-results (-m): int = 5 # Maximum number of results to return
    --no-throw (-n) = true # Set to `false` to treat no matching files as an error
    --prune (-p): duration # Remove files older than this age
    --include (-i): string # Only include this type of log (choices: 'out'|'err')
    --min-age: duration # Include files with an age greater than this duration
    --max-age: duration # Include files with an age less than this duration
    --truncate (-t): oneof<int, record<head: int>, record<tail: int>> # Truncate output text
    --delete-all (-d) # Remove ALL string-matched files (ignores datetime bounds)
    --latest (-l) # Print the latest 'err' to stderr and return out (default for empty `match`)
    --check (-c) # Throw an error if the latest matching run did not succeed
    --enumerate (-e) # Return the matching items without their file contents expanded
  ]: nothing -> oneof<table<date: string, type: string>, nothing> {
    try { cd ~/.cache/ } catch { error make --unspanned "unable to access cache directory" }

    let last: int = if $latest { 1 } else { $max_results }
    let date: datetime = date now
    let args: list = $match | default --empty {
        log-files * --date * --types [*] | values | into glob
      } | compact

    let predicate: closure = {|f: record<name: string, type: string, modified: datetime>|
      if $f.type == dir { return false } else if $delete_all { return true }
      let age: duration = $date - $f.modified
      if $prune != null { return ($age > $prune) }
      [
        ($max_age == null or $age < $max_age)
        ($min_age == null or $age > $min_age)
        ($include == null or $f.name =~ $'($include).log')
      ] | all {}
    }

    let items: list<record<name: path, modified: datetime>> = try {
      ls ...$args | where $predicate | reject type | sort-by modified | last $last
    } catch {
      if $no_throw {
        print --stderr $'(ansi yellow)no items matched the provided criteria(ansi rst)'
      } else {
        let labels: table<text: string, span: record> = [
          [text span];
          [max_age (metadata $max_age).span]
          [min_age (metadata $min_age).span]
          [match_arg (metadata $match).span]
          [prune_age (metadata $prune).span]
        ] | compact
        error make {msg: "could not find any matching logs" labels: $labels}
      }
    }

    if $enumerate {
      $items | enumerate
    } else if $prune != null or $delete_all {
      for $name in $items.name {
        try { rm $name } catch { continue }
        print $"removed (ansi green)`($name)`(ansi rst)"
      }
    } else if ($match | is-not-empty) {
      $items
      | insert date { get modified | format date %F }
      | insert type { get name | parse '{_}_pkg-{_}.{x}.log' | $in.0?.x }
      | insert text {
        let lines: list<string> = try { open --raw $in.name | lines } catch { [] }
          | reverse | take until { $in =~ `auto-update start` }
          | reverse | drop 1
        match $truncate {
          null => $lines
          {tail: $n} => { $lines | last $n }
          {head: $n} | $n => { $lines | first $n }
        } | str join "\n"
      } | reject name modified size
    } else {
      let out: path = $items | where name =~ .out.log | last | get --optional name
      let err: path = $out | str replace out err
      match {out: $out err: $err check: $check} {
        {out: null err: null} | {err: null check: true} => { return }
        {err: $e check: true} => {
          let msg: string = try { open --raw $e | str trim }
          if ($msg | is-not-empty) { error make --unspanned $msg }
        }
        {out: $o err: $e check: false} => {
          if ($e | path exists) { open --raw $e | print --stderr $in }
          try { open --raw $o } catch { error make --unspanned $"could not open `($o)`" }
        }
      }
    }
  }

  # Internal logger to wrap the print/save dynamic write logic
  def write-log [logs: record<out: path, err: path>]: record -> nothing {
    into record | items {|key value|
      if $key !~ std or ($value | describe) !~ string { return }
      let std = $key | parse 'std{x}' | $in.0?.x
      let lvl = match $std {
        out => $'(ansi blue_bold)INFO(ansi rst)'
        err => $'(ansi red_bold)ERROR(ansi rst)'
      }
      let txt = $'($lvl) ($value | lines | str trim | compact --empty | str join "\n")'
      let dst = $logs | default $logs.out? err | get --optional $std
      if $dst != null { $txt + "\n" | save --append $dst } else {
        match $std { err => { print --stderr $txt } out => { print $txt } }
      }
    }
  }

  # Inner function for `auto-update` to streamline bg/fg management
  def run-update [logs: record<out: path, err: path>]: nothing -> bool {
    try { cd ~/.cache/ } catch { error make --unspanned "unable to access cache directory" }

    let registry: list = $UPDATE_REGISTRY | enumerate | update index {|row| $row.index + 1 }
    let total: int = $registry | length

    {stdout: $"(date now) | auto-update start"} | write-log $logs
    let success: bool = $registry | each {|row|
        let prefix: string = [
          (date now | into string)
          ($row.index | append $total | str join ' of ')
          $'updating ($row.item.target)'
        ] | str join " | "
        let output: record = try {
          {stdout: $"($prefix)\n(run-external ...$row.item.command out+err>| to text)"}
        } catch {|err|
          {stderr: ($err.rendered? | default $'($row.item.target) did not succeed')}
        }
        $output | write-log $logs
        $output not-has stderr
      } | all {}
    {stdout: $"(date now) | auto-update end"} | write-log $logs

    return $success
  }

  def log-files [
    desc: string
    --root: path = ~/.cache/
    --date: oneof<datetime, string>
    --extension: string = log
    --types: list<string> = [out err]
  ]: nothing -> oneof<record<out: path, err: path>, record> {
    let when: string = $date
      | default { date now }
      | match ($in | describe) { datetime => { $in | format date %F } _ => $in }
    let stem: string = $root | path join $'($when)_pkg-($desc)'
    $types | par-each { append $'($stem).($in).($extension)' } | collect { into record }
  }

  # Auto-update all (registered) globally installed packages (non-elevated)
  @category platform
  export def --env "pkg update" [
    --force (-f) # Force the updater to run even if there is an existing log file
    --quiet (-q) # Suppress status messages and informational logging
    --verbose (-v) # Include additional information in the printed output
  ]: nothing -> nothing {
    # Remove log files older than one week (stale)
    let prev = log-files update --date * --types [*] | values | into glob
    pkg hist --prune 1wk ...$prev
    # Construct log filenames for today via `format date`
    let logs = log-files update
    # Check for today's log file already existing (require `--force` to overwrite)
    if ($logs | values | any { path exists }) and not $force { return }
    # Spawn the auto-update job and record its ID
    let job = job spawn { run-update $logs }
    # Suppress output if `--quiet` is passed
    if $quiet { return }
    # Print an info message to stdout otherwise
    let msg = $"(ansi blue)spawned background auto-update(ansi rst)"
    let jid = $"id: (ansi orange1)($job)(ansi rst)"
    if not $verbose { print $"($msg) \(($jid))" | return }
    $msg | append [
      $'job spawned with ($jid)'
      $'appending external output to (ansi green)`($logs.out)`(ansi rst)'
    ] | str join $"\n (ansi red)*(ansi rst) " | print
  }
}

overlay use package
pkg update --quiet
