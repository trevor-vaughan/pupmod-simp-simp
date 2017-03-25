function simp::knockout(Array $array) {
  $included = $array.filter |$data| {
    $data !~ /^--/
  }

  $excluded = $array.filter |$data| {
    $data =~ /^--/
  }.map |$data| {
    delete($data, '--')
  }

  return $included - $excluded
}
