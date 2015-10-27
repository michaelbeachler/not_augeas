define not_augeas::not_augi(
  $search             = undef,
  $replace            = undef,
  $match              = undef,
  $path               = undef,
) {

  file_text { $name:
    search              => $search,
    replace             => $replace,
    match               => $match,
    path                => $path,
  }

}
