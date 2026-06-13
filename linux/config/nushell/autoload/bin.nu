module bin {
  use std/util 'path add'
  # Load the standard set of binary directories to PATH
  export def --env load [] {
    let bins: list<path> = [.local .cargo .pixi .bun go]
      | par-each { prepend $nu.home-dir | path join bin }
      | append [/home/linuxbrew/.linuxbrew/bin]
    path add $bins
  }
}
export-env { use bin; bin load }
