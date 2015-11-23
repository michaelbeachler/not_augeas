define not_augeas::not_augi(
  $search             = undef,
  $replace            = undef,
  $match              = undef,
  $nomatch            = undef,
  $path               = undef,
  $tag                = undef,
  $order              = order,
) {

  file_text { $name:
    search              => $search,
    replace             => $replace,
    match               => $match,
    nomatch             => $nomatch,
    path                => $path,
    tag                 => $tag,
    order               => $order,
  }

}
