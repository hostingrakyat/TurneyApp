// Cross-platform URL strategy hook. On web this switches go_router to clean
// path URLs (no `#`), matching the cPanel `.htaccess` rewrite so links like
// `protourney.id/c/my-cup-ab12cd` resolve. On mobile it is a no-op.
export 'url_strategy_stub.dart'
    if (dart.library.html) 'url_strategy_web.dart';
