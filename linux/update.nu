#!/usr/bin/env -S nu --stdin
const DIR = path self .
const MANIFEST = path self manifest.nuon
# Synchronize files from this repository to local configuration.
def main [
  --show # Show the dataset of known config files
  --load # Copy files from the repository to config location
  --dump # Copy files from config location to repository
]: nothing -> nothing {
  if $show { return (open $MANIFEST) }
  if not $load and not $dump { return (help main) }
  open $MANIFEST | par-each {|row|
    let src = $row.src | path expand
    let dst = $row.dst | prepend $DIR | path join
    mkdir ($dst | path dirname)
    if $load {
      cp --update --verbose $dst $src
    } else if $dump {
      cp --update --verbose $src $dst
    }
  } | return
}
