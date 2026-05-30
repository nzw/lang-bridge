import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'app/app.dart';
import 'app/app_config.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // google_sign_in v7 はシングルトンを一度だけ初期化する必要がある。
  // Android は Credential Manager のために serverClientId（ウェブ OAuth クライアント ID）が必須。
  if (!kIsWeb) {
    try {
      await GoogleSignIn.instance.initialize(
        serverClientId: AppConfig.googleServerClientId,
      );
    } catch (_) {}
  }
  runApp(const ProviderScope(child: DictionaryApp()));
}
