#!/usr/bin/env -S nu --stdin
const DIR = path self .
const MANIFEST = path self manifest.nuon

let data: table<disk: path, repo: path> = open $MANIFEST
  | update disk { path expand }
  | update repo { prepend $DIR | path join }

def copy [
  src: path
  dst: path
  --force
]: nothing -> nothing {
  mkdir --verbose ($dst | path dirname)
  if $force {
    cp --verbose $src $dst
  } else {
    cp --update --verbose $src $dst
  }
}

# Synchronize files from this repository to local configuration.
def main [
  --show # Show the dataset of known config files
  --load # Copy files from the repository to config location
  --dump # Copy files from config location to repository
]: nothing -> nothing {
  if $show { return $data }
  if not $load and not $dump { return (help main) }
  for $row in $data {
    if $load {
      copy $row.repo $row.disk
    } else if $dump {
      copy $row.disk $row.repo --force
    }
  }
}
