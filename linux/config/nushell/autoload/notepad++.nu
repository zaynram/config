job spawn {
  cd $nu.home-dir
  let clutter = [NppExec/ backup/ themes/ *.xml] | where { path exists }
  if ($clutter | is-empty) { return }
  for $item in $clutter { try { rm --recursive --verbose $item } }
} | ignore
