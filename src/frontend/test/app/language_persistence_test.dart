import 'dart:async';

import 'package:carnine_frontend/app/language_persistence.dart';
import 'package:carnine_frontend/features/dashboard/data/ui_state_store.dart';
import 'package:carnine_frontend/l10n/app_language_controller.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grpc/grpc.dart';

class _Store implements UiStateStore {
  String language = '';
  final List<String> saved = <String>[];

  /// Errors thrown by the next calls to [loadLanguage], one per call.
  final List<Object> loadErrors = <Object>[];
  Completer<void>? loadGate;

  @override
  Future<String> loadLanguage() async {
    await loadGate?.future;
    if (loadErrors.isNotEmpty) {
      throw loadErrors.removeAt(0);
    }
    return language;
  }

  @override
  Future<void> saveLanguage(String languageCode) async {
    saved.add(languageCode);
  }

  @override
  Future<String> loadLastPage() async => '';

  @override
  Future<void> saveLastPage(String page) async {}
}

void main() {
  late _Store store;
  late AppLanguageController controller;
  late LanguagePersistence persistence;

  setUp(() {
    store = _Store();
    controller = AppLanguageController();
    persistence = LanguagePersistence(controller: controller, store: store);
  });

  tearDown(() {
    persistence.dispose();
    controller.dispose();
  });

  test('brings back the language saved last, without saving it again', () {
    fakeAsync((async) {
      store.language = 'en';

      persistence.start();
      async.flushMicrotasks();

      expect(controller.locale, const Locale('en'));
      expect(store.saved, isEmpty);
    });
  });

  test('without a saved language it stays on the default', () {
    fakeAsync((async) {
      persistence.start();
      async.flushMicrotasks();

      expect(controller.locale, const Locale('de'));
    });
  });

  test('saves every language the user picks', () {
    fakeAsync((async) {
      persistence.start();
      async.flushMicrotasks();

      controller.setLocale(const Locale('fr'));
      controller.setLocale(const Locale('ja'));
      async.flushMicrotasks();

      expect(store.saved, ['fr', 'ja']);
    });
  });

  test('tries again while the backend is not up yet', () {
    fakeAsync((async) {
      store
        ..language = 'nl'
        ..loadErrors.addAll([
          GrpcError.unavailable('starting'),
          GrpcError.unavailable('starting'),
        ]);

      persistence.start();
      async.flushMicrotasks();
      expect(controller.locale, const Locale('de'));

      async.elapse(const Duration(seconds: 2));

      expect(controller.locale, const Locale('nl'));
    });
  });

  test('a language picked while it still loads wins', () {
    fakeAsync((async) {
      store
        ..language = 'en'
        ..loadGate = Completer<void>();
      persistence.start();
      async.flushMicrotasks();

      controller.setLocale(const Locale('sv'));
      store.loadGate!.complete();
      async.flushMicrotasks();

      expect(controller.locale, const Locale('sv'));
      expect(store.saved, ['sv']);
    });
  });
}
