import '../domain/dictionary_entry.dart';
import '../domain/repositories.dart';
import '../domain/saved_sync_url.dart';
import 'validate_import_format_use_case.dart';

class AutoSyncConflict {
  const AutoSyncConflict({
    required this.appEntry,
    required this.sheetLang1,
    required this.sheetLang2,
    required this.sheetMemo,
  });

  final DictionaryEntry appEntry;
  final String sheetLang1;
  final String sheetLang2;
  final String sheetMemo;
}

class AutoSyncResult {
  const AutoSyncResult({
    this.addedFromSheet = 0,
    this.conflicts = const [],
    this.newEntriesFromSheet = const [],
    this.manualEntriesToExport = const [],
    this.exportedSheetName,
    this.skippedDueToHeader = false,
  });

  /// addOnly / forceApply で追加したシート→アプリのエントリ数。
  final int addedFromSheet;

  /// mergeConfirm モードで検出された競合（同キー・内容相違）。
  final List<AutoSyncConflict> conflicts;

  /// mergeConfirm モードでシート側に新規追加されていたエントリ。
  final List<DictionaryEntry> newEntriesFromSheet;

  /// アプリ側の manual エントリで、シートに存在しないもの。
  final List<DictionaryEntry> manualEntriesToExport;

  /// アプリ→シートに書き出した新シート名（exportRowsToNewSheet 後に設定）。
  final String? exportedSheetName;

  /// ヘッダー自動判定に失敗してスキップされた場合 true。
  final bool skippedDueToHeader;

  bool get hasPendingAction =>
      conflicts.isNotEmpty || newEntriesFromSheet.isNotEmpty || manualEntriesToExport.isNotEmpty;
}

class AutoSyncUseCase {
  const AutoSyncUseCase({
    required this.syncRepo,
    required this.userRepo,
    required this.validator,
  });

  final SyncRepository syncRepo;
  final UserDictionaryRepository userRepo;
  final ValidateImportFormatUseCase validator;

  /// 自動同期を実行する。
  ///
  /// [savedUrl] の [AutoSyncMode] に応じて処理する。
  /// mergeConfirm モードのときは競合リストを返すのみで実際の変更は行わない
  /// — UI 側で確認後に [applyMergeConflicts] を呼ぶこと。
  Future<AutoSyncResult> execute(SavedSyncUrl savedUrl) async {
    // ─── 1. シートデータ取得 ─────────────────────────────────────────────────
    final List<List<String>> allRows;
    final String effectiveSheetName;

    if (savedUrl.autoSyncSheetName != null) {
      allRows = await syncRepo.importRowsFromSheet(
        spreadsheetUrlOrId: savedUrl.url,
        sheetName: savedUrl.autoSyncSheetName!,
      );
      effectiveSheetName = savedUrl.autoSyncSheetName!;
    } else {
      // 全シートを順に取得してマージ（最初のシートを使用）
      final result = await syncRepo.listSheetNames(savedUrl.url);
      final sheetNames = result.sheetNames;
      if (sheetNames.isEmpty) {
        return const AutoSyncResult(skippedDueToHeader: true);
      }
      effectiveSheetName = sheetNames.first;
      allRows = await syncRepo.importRowsFromSheet(
        spreadsheetUrlOrId: savedUrl.url,
        sheetName: effectiveSheetName,
      );
    }

    if (allRows.length < 2) {
      // ヘッダー行のみ or 空
      return const AutoSyncResult();
    }

    // ─── 2. ヘッダー自動判定 ─────────────────────────────────────────────────
    final FormatValidationResult format;
    try {
      format = validator.execute(allRows.first);
    } catch (_) {
      return const AutoSyncResult(skippedDueToHeader: true);
    }

    // ─── 3. アプリ側エントリ取得とキーマップ構築 ─────────────────────────────
    final existingEntries = await userRepo.listAll();
    // キー: lang1\tlang2 → DictionaryEntry
    final appKeyMap = {
      for (final e in existingEntries) '${e.lang1}\t${e.lang2}': e,
    };
    // キー: lang1\tlang2 → シート行番号（addOnly/forceApply で ID 生成に使用）
    final ssId = _spreadsheetIdFrom(savedUrl.url);
    final now = DateTime.now();

    // ─── 4. シート行をパース ─────────────────────────────────────────────────
    final sheetKeySet = <String>{};
    final toAdd = <DictionaryEntry>[];
    final conflicts = <AutoSyncConflict>[];
    final newFromSheet = <DictionaryEntry>[];

    for (var i = 1; i < allRows.length; i++) {
      final row = allRows[i];
      final lang1 = _valueAt(row, format.lang1Index);
      final lang2 = _valueAt(row, format.lang2Index);
      if (lang1.isEmpty || lang2.isEmpty) continue;

      final memo = format.memoIndex != null ? _valueAt(row, format.memoIndex!) : '';
      final key = '$lang1\t$lang2';
      sheetKeySet.add(key);

      final id = 'sheet2-$ssId-$effectiveSheetName-$i';
      final entry = DictionaryEntry(
        id: id,
        lang1: lang1,
        lang2: lang2,
        memo: memo,
        categories: [effectiveSheetName],
        sourceType: EntrySourceType.userSheet,
        sourceUrl: savedUrl.url,
        createdAt: appKeyMap[key]?.createdAt ?? now,
        updatedAt: now,
      );

      final existing = appKeyMap[key];
      if (existing == null) {
        // シート新規エントリ
        if (savedUrl.autoSyncMode == AutoSyncMode.mergeConfirm) {
          newFromSheet.add(entry);
        } else {
          toAdd.add(entry);
        }
      } else if (savedUrl.autoSyncMode == AutoSyncMode.mergeConfirm) {
        // 既存エントリとの内容比較（lang1/lang2は同じ、memoが違う場合のみ競合）
        if (existing.memo != memo) {
          conflicts.add(AutoSyncConflict(
            appEntry: existing,
            sheetLang1: lang1,
            sheetLang2: lang2,
            sheetMemo: memo,
          ));
        }
      }
    }

    // ─── 5. アプリ側 manual エントリでシートに存在しないもの ─────────────────
    final manualNotInSheet = existingEntries
        .where(
          (e) =>
              e.sourceType == EntrySourceType.manual &&
              !sheetKeySet.contains('${e.lang1}\t${e.lang2}'),
        )
        .toList();

    // ─── 6. モード別の変更適用 ─────────────────────────────────────────────
    switch (savedUrl.autoSyncMode) {
      case AutoSyncMode.addOnly:
        if (toAdd.isNotEmpty) {
          await userRepo.upsertMany(toAdd);
        }
        // manual エントリをシートに書き出す
        final exportedSheetName = await _exportManualEntries(
          savedUrl,
          manualNotInSheet,
          now,
        );
        return AutoSyncResult(
          addedFromSheet: toAdd.length,
          manualEntriesToExport: manualNotInSheet,
          exportedSheetName: exportedSheetName,
        );

      case AutoSyncMode.forceApply:
        // 既存の userSheet エントリ（同一スプレッドシート）を全削除して再インポート
        final staleIds = existingEntries
            .where(
              (e) =>
                  e.sourceType == EntrySourceType.userSheet &&
                  _spreadsheetIdFrom(e.sourceUrl ?? '') == ssId,
            )
            .map((e) => e.id)
            .toList();
        if (staleIds.isNotEmpty) {
          await userRepo.deleteManyByIds(staleIds);
        }
        // 全シート行をインポート（addOnly と違い既存チェックなし）
        final allEntries = <DictionaryEntry>[];
        for (var i = 1; i < allRows.length; i++) {
          final row = allRows[i];
          final l1 = _valueAt(row, format.lang1Index);
          final l2 = _valueAt(row, format.lang2Index);
          if (l1.isEmpty || l2.isEmpty) continue;
          final m = format.memoIndex != null ? _valueAt(row, format.memoIndex!) : '';
          allEntries.add(DictionaryEntry(
            id: 'sheet2-$ssId-$effectiveSheetName-$i',
            lang1: l1,
            lang2: l2,
            memo: m,
            categories: [effectiveSheetName],
            sourceType: EntrySourceType.userSheet,
            sourceUrl: savedUrl.url,
            createdAt: now,
            updatedAt: now,
          ));
        }
        if (allEntries.isNotEmpty) {
          await userRepo.upsertMany(allEntries);
        }
        return AutoSyncResult(addedFromSheet: allEntries.length);

      case AutoSyncMode.mergeConfirm:
        // 実際の変更は UI 確認後に applyMergeConflicts() で行う
        return AutoSyncResult(
          conflicts: conflicts,
          newEntriesFromSheet: newFromSheet,
          manualEntriesToExport: manualNotInSheet,
        );
    }
  }

  /// mergeConfirm モードでユーザーが確認した後に変更を適用する。
  ///
  /// [resolvedConflicts] は各競合に対して true=シート版採用、false=アプリ版維持。
  Future<String?> applyMergeConflicts({
    required SavedSyncUrl savedUrl,
    required List<AutoSyncConflict> conflicts,
    required Map<String, bool> resolvedConflicts, // key = appEntry.id → true=use sheet
    required List<DictionaryEntry> newEntries,
    required bool addNewFromSheet,
    required bool exportManualEntries,
    required List<DictionaryEntry> manualEntries,
  }) async {
    final now = DateTime.now();
    final toUpsert = <DictionaryEntry>[];

    // 競合解決
    for (final conflict in conflicts) {
      final useSheet = resolvedConflicts[conflict.appEntry.id] ?? false;
      if (useSheet) {
        toUpsert.add(conflict.appEntry.copyWith(
          memo: conflict.sheetMemo,
          updatedAt: now,
        ));
      }
    }

    // シート新規追加分
    if (addNewFromSheet) {
      toUpsert.addAll(newEntries);
    }

    if (toUpsert.isNotEmpty) {
      await userRepo.upsertMany(toUpsert);
    }

    // アプリ追加分をシートに書き出す
    if (exportManualEntries && manualEntries.isNotEmpty) {
      return _exportManualEntries(savedUrl, manualEntries, now);
    }
    return null;
  }

  /// manual エントリをスプレッドシートの新シートに書き出す。
  Future<String?> _exportManualEntries(
    SavedSyncUrl savedUrl,
    List<DictionaryEntry> entries,
    DateTime now,
  ) async {
    if (entries.isEmpty) return null;
    final d = '${now.year}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}';
    final newSheetName = 'LangBridge追加_$d';
    final rows = <List<String>>[
      ['ソース言語', 'ターゲット言語', 'メモ', 'カテゴリ'],
      ...entries.map((e) => [e.lang1, e.lang2, e.memo, e.categories.join('//')]),
    ];
    await syncRepo.exportRowsToNewSheet(
      spreadsheetUrlOrId: savedUrl.url,
      newSheetName: newSheetName,
      rows: rows,
    );
    return newSheetName;
  }

  static String _spreadsheetIdFrom(String url) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return url;
    final segments = uri.pathSegments;
    final dIdx = segments.indexOf('d');
    if (dIdx >= 0 && dIdx + 1 < segments.length) {
      return segments[dIdx + 1];
    }
    return url;
  }

  static String _valueAt(List<String> row, int index) {
    if (index < 0 || index >= row.length) return '';
    return row[index].trim();
  }
}
