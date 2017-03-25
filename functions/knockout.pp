function simp::knockout(Array $array) >> Array {
  $included = $array.filter |$data| {
    $data !~ /^--.*/
  }
  $excluded = $array.filter |$data| {
    $data =~ /^--.*/
  }.map |$data| {
      delete($data, '--')
  }
  $included - $excluded

}
