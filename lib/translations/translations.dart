import 'package:get/get.dart';

import 'en.dart';
import 'ar.dart';
import 'ur.dart';
import 'de.dart';
import 'es.dart';
import 'fr.dart';
import 'zh.dart';
import 'hi.dart';
import 'pt.dart';
import 'ru.dart';

class AppTranslations extends Translations {
  @override
  Map<String, Map<String, String>> get keys => {
        'en': en,
        'ar': ar,
        'ur': ur,
        'de': de,
        'es': es,
        'fr': fr,
        'zh': zh,
        'hi': hi,
        'pt': pt,
        'ru': ru,
      };
}
