import 'package:flutter_web_plugins/url_strategy.dart';

// Web: use clean path URLs (no leading `#`).
void configureUrlStrategy() => usePathUrlStrategy();
