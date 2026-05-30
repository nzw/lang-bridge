import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../di/providers.dart';
import '../domain/dictionary_entry.dart';
import 'widgets/account_menu_button.dart';

class FlashcardPage extends ConsumerStatefulWidget {
  const FlashcardPage({super.key});

  @override
  ConsumerState<FlashcardPage> createState() => _FlashcardPageState();
}

class _FlashcardPageState extends ConsumerState<FlashcardPage> {
  final _random = math.Random();
  final PageController _pageController = PageController();
  List<DictionaryEntry> _allCards = const [];
  List<DictionaryEntry> _cards = const [];
  final List<DictionaryEntry> _retryCards = [];
  var _index = 0;
  var _showBack = false;
  var _loading = true;
  var _isLearningStarted = false;
  var _onlyFavorites = false;
  var _onlyNotRemembered = false;
  var _shuffle = false;
  var _isJapaneseOnFront = true;
  var _showMemoOnBack = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadCards();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadCards() async {
    if (!mounted) {
      return;
    }
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final cards = await ref.read(listFlashcardsUseCaseProvider).execute();
      if (!mounted) {
        return;
      }
      setState(() {
        _allCards = cards;
        _rebuildDeck();
        _loadError = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _allCards = [];
        _cards = [];
        _loadError = e.toString();
        _loading = false;
      });
    }
  }

  void _rebuildDeck() {
    var deck = _allCards.where((entry) {
      if (_onlyFavorites && !entry.isFavorite) {
        return false;
      }
      if (_onlyNotRemembered && entry.reviewScore > 0) {
        return false;
      }
      final selectedCats = ref.read(filterCategoriesProvider);
      if (selectedCats.isNotEmpty && !entry.categories.any(selectedCats.contains)) {
        return false;
      }
      return true;
    }).toList();

    if (_shuffle) {
      deck.shuffle(_random);
    }

    _cards = deck;
    _index = 0;
    _showBack = false;
    _retryCards.clear();
    if (_pageController.hasClients) {
      _pageController.jumpToPage(0);
    }
  }

  void _startLearning() {
    setState(() {
      _rebuildDeck();
      _isLearningStarted = true;
    });
  }

  void _nextCard() {
    if (_cards.isEmpty) {
      return;
    }
    setState(() {
      if (_index < _cards.length - 1) {
        _index++;
      } else if (_retryCards.isNotEmpty) {
        _cards = [..._cards, ..._retryCards];
        _retryCards.clear();
        _index++;
      } else {
        _index = 0;
      }
      _showBack = false;
    });
    _animateToIndex();
  }

  void _prevCard() {
    if (_cards.isEmpty) {
      return;
    }
    setState(() {
      _index = (_index - 1 + _cards.length) % _cards.length;
      _showBack = false;
    });
    _animateToIndex();
  }

  void _animateToIndex() {
    if (!_pageController.hasClients) {
      return;
    }
    _pageController.animateToPage(
      _index,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _toggleFavorite(DictionaryEntry card) async {
    final updated = card.copyWith(isFavorite: !card.isFavorite);
    await ref.read(userRepositoryProvider).upsert(updated);
    setState(() {
      _allCards = _allCards.map((e) => e.id == updated.id ? updated : e).toList();
      _cards = _cards.map((e) => e.id == updated.id ? updated : e).toList();
    });
    if (_onlyFavorites) {
      setState(_rebuildDeck);
    }
  }

  Future<void> _markResult(DictionaryEntry card, {required bool correct}) async {
    final score = correct ? card.reviewScore + 1 : (card.reviewScore > 0 ? card.reviewScore - 1 : 0);
    final updated = card.copyWith(reviewScore: score);
    await ref.read(userRepositoryProvider).upsert(updated);
    setState(() {
      _allCards = _allCards.map((e) => e.id == updated.id ? updated : e).toList();
      _cards = _cards.map((e) => e.id == updated.id ? updated : e).toList();
      if (!correct) {
        _retryCards.add(updated);
      }
    });
    _nextCard();
  }

  Widget _buildAnimatedFlashCard(BuildContext context, DictionaryEntry card) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: _showBack ? 1 : 0),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      builder: (context, value, _) {
        final angle = value * math.pi;
        final isBackVisible = value >= 0.5;
        final frontText = _isJapaneseOnFront ? card.lang1 : card.lang2;
        final backText = _isJapaneseOnFront ? card.lang2 : card.lang1;
        final displayText = isBackVisible ? backText : frontText;
        final hintText = isBackVisible ? 'タップで表面へ' : 'タップで裏面へ';

        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateY(angle),
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()..rotateY(isBackVisible ? math.pi : 0),
            child: Card(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        displayText,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 12),
                      Text(hintText),
                      const SizedBox(height: 8),
                      Text('習熟度: ${card.reviewScore}'),
                      if (card.memo.isNotEmpty &&
                          (_showMemoOnBack ? isBackVisible : !isBackVisible)) ...[
                        const SizedBox(height: 12),
                        Text('メモ: ${card.memo}', textAlign: TextAlign.center),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(userEntriesStreamProvider, (_, next) {
      if (next.hasValue && mounted) _loadCards();
    });
    final filterCats = ref.watch(filterCategoriesProvider);
    final allCategories = _allCards
        .expand((e) => e.categories)
        .where((c) => c.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    final selected = _cards.isEmpty ? null : _cards[_index];

    return Scaffold(
      appBar: AppBar(
        title: const Text('単語カード学習'),
        leading: _isLearningStarted
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: '学習設定に戻る',
                onPressed: () => setState(() => _isLearningStarted = false),
              )
            : null,
        actions: [
          const AccountMenuButton(showGoHome: true),
        ],
      ),
      body: PopScope(
        canPop: !_isLearningStarted,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && _isLearningStarted) {
            setState(() => _isLearningStarted = false);
          }
        },
        child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
              ? Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 48,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '読み込みに失敗しました',
                          style: Theme.of(context).textTheme.titleMedium,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        SelectableText(
                          _loadError!,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          onPressed: _loadCards,
                          icon: const Icon(Icons.refresh),
                          label: const Text('再試行'),
                        ),
                      ],
                    ),
                  ),
                )
          : !_isLearningStarted
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text('学習設定', style: Theme.of(context).textTheme.titleLarge),
                            const SizedBox(height: 8),
                            if (allCategories.isNotEmpty)
                              Theme(
                                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                                child: ExpansionTile(
                                  tilePadding: EdgeInsets.zero,
                                  childrenPadding: const EdgeInsets.only(bottom: 8),
                                  leading: Icon(
                                    Icons.label_outline,
                                    size: 22,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                  title: const Text('カテゴリで絞り込む'),
                                  subtitle: filterCats.isEmpty
                                      ? null
                                      : Text('${filterCats.length}件選択中'),
                                  children: [
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 4,
                                      children: [
                                        FilterChip(
                                          label: const Text('すべて'),
                                          selected: filterCats.isEmpty,
                                          onSelected: (_) => ref
                                              .read(filterCategoriesProvider.notifier)
                                              .update({}),
                                          visualDensity: VisualDensity.compact,
                                        ),
                                        for (final cat in allCategories)
                                          FilterChip(
                                            label: Text(cat),
                                            selected: filterCats.contains(cat),
                                            onSelected: (_) {
                                              final next = Set<String>.from(filterCats);
                                              if (next.contains(cat)) {
                                                next.remove(cat);
                                              } else {
                                                next.add(cat);
                                              }
                                              ref
                                                  .read(filterCategoriesProvider.notifier)
                                                  .update(next);
                                            },
                                            visualDensity: VisualDensity.compact,
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            SwitchListTile(
                              value: _onlyFavorites,
                              contentPadding: EdgeInsets.zero,
                              title: const Text('お気に入りのみ'),
                              onChanged: (value) => setState(() => _onlyFavorites = value),
                            ),
                            SwitchListTile(
                              value: _onlyNotRemembered,
                              contentPadding: EdgeInsets.zero,
                              title: const Text('覚えていない単語のみ'),
                              onChanged: (value) => setState(() => _onlyNotRemembered = value),
                            ),
                            SwitchListTile(
                              value: _shuffle,
                              contentPadding: EdgeInsets.zero,
                              title: const Text('シャッフル'),
                              onChanged: (value) => setState(() => _shuffle = value),
                            ),
                            SwitchListTile(
                              value: _showMemoOnBack,
                              contentPadding: EdgeInsets.zero,
                              title: const Text('メモを裏面に表示'),
                              onChanged: (value) => setState(() => _showMemoOnBack = value),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'カード表面の言語',
                              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 6),
                            SegmentedButton<bool>(
                              segments: const [
                                ButtonSegment<bool>(value: true, icon: Icon(Icons.flip_outlined), label: Text('ソース言語')),
                                ButtonSegment<bool>(value: false, icon: Icon(Icons.flip_outlined), label: Text('ターゲット言語')),
                              ],
                              selected: {_isJapaneseOnFront},
                              onSelectionChanged: (selection) {
                                setState(() => _isJapaneseOnFront = selection.first);
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + MediaQuery.of(context).padding.bottom),
                      child: FilledButton.icon(
                        onPressed: _startLearning,
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('カード学習を開始'),
                      ),
                    ),
                  ],
                )
              : _cards.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('条件に一致する単語がありません'),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: () => setState(() => _isLearningStarted = false),
                        child: const Text('設定に戻る'),
                      ),
                    ],
                  ),
                )
              : Builder(
                  builder: (context) {
                    final card = selected!;
                    return Padding(
                      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).padding.bottom),
                      child: Column(
                        children: [
                          Text('${_index + 1} / ${_cards.length}'),
                          const SizedBox(height: 16),
                          Expanded(
                            child: PageView.builder(
                              controller: _pageController,
                              itemCount: _cards.length,
                              onPageChanged: (newIndex) {
                                setState(() {
                                  _index = newIndex;
                                  _showBack = false;
                                });
                              },
                              itemBuilder: (context, i) {
                                final viewCard = _cards[i];
                                return Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                  child: InkWell(
                                    onTap: () => setState(() => _showBack = !_showBack),
                                    child: _buildAnimatedFlashCard(context, viewCard),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              IconButton(
                                onPressed: () => _toggleFavorite(card),
                                icon: Icon(card.isFavorite ? Icons.star : Icons.star_border),
                                tooltip: 'お気に入り切替',
                              ),
                              const Spacer(),
                              IconButton.filledTonal(
                                onPressed: _prevCard,
                                icon: const Icon(Icons.chevron_left),
                                tooltip: '前のカード',
                              ),
                              const SizedBox(width: 8),
                              IconButton.filled(
                                onPressed: _nextCard,
                                icon: const Icon(Icons.chevron_right),
                                tooltip: '次のカード',
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => _markResult(card, correct: false),
                                  child: const Text('覚えていない'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: FilledButton(
                                  onPressed: () => _markResult(card, correct: true),
                                  child: const Text('覚えた'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
      ),
    );
  }
}
