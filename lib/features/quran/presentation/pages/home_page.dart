import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/arabic_utils.dart';
import '../../data/services/quran_audio_service.dart';
import '../../domain/entities/surah.dart';
import '../state/quran_controller.dart';
import '../widgets/equalizer_icon.dart';
import '../widgets/mini_player.dart';
import 'player_page.dart';

enum _Filter { all, favorites }

class _IndexedSurah {
  const _IndexedSurah(this.surah, this.arabic, this.english);

  final Surah surah;
  final String arabic;
  final String english;
}

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.audioService,
    required this.surahs,
    required this.controller,
  });

  final QuranAudioService audioService;
  final List<Surah> surahs;
  final QuranController controller;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // Approximate layout metrics, only used to jump close to the current surah
  // before Scrollable.ensureVisible makes it exact.
  static const double _headerExtent = 170;
  static const double _pinnedExtent = 124;
  static const double _tileExtent = 78;

  late final List<_IndexedSurah> _index;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _currentTileKey = GlobalKey();

  String _query = '';
  _Filter _filter = _Filter.all;

  @override
  void initState() {
    super.initState();

    // Normalize names once instead of on every keystroke / rebuild.
    _index = widget.surahs
        .map(
          (s) => _IndexedSurah(
            s,
            ArabicUtils.normalize(s.arabicName),
            ArabicUtils.normalize(s.englishName),
          ),
        )
        .toList();

    // When the app opens with a restored session, bring that surah into view
    // instead of always starting at the top of the list.
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToCurrent());
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToCurrent() {
    if (!mounted || !_scrollController.hasClients) return;
    if (!widget.audioService.hasSession.value) return;

    final index = widget.audioService.player.currentIndex;
    if (index == null || index <= 0) return;

    final position = _scrollController.position;

    // 1) Jump close to the tile so the lazy list builds it.
    final itemTop = _headerExtent + _pinnedExtent + 4 + index * _tileExtent;
    final target = (itemTop - position.viewportDimension * 0.3)
        .clamp(0.0, position.maxScrollExtent)
        .toDouble();
    _scrollController.jumpTo(target);

    // 2) Fine-tune using the real tile position.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final tileContext = _currentTileKey.currentContext;
      if (!mounted || tileContext == null) return;

      Scrollable.ensureVisible(tileContext, alignment: 0.3);
    });
  }

  List<Surah> _visibleSurahs() {
    final query = ArabicUtils.normalize(_query);

    return _index.where((entry) {
      if (_filter == _Filter.favorites &&
          !widget.controller.isFavorite(entry.surah.number)) {
        return false;
      }

      if (query.isEmpty) return true;

      return entry.surah.number.toString() == query ||
          entry.arabic.contains(query) ||
          entry.english.contains(query);
    }).map((entry) => entry.surah).toList();
  }

  void _openSurah(Surah surah) {
    // Intentionally not awaited: playback must not block navigation.
    unawaited(widget.audioService.playSurah(surah.number - 1));

    PlayerPage.open(
      context,
      audioService: widget.audioService,
      surahs: widget.surahs,
      controller: widget.controller,
    );
  }

  @override
  Widget build(BuildContext context) {
    final player = widget.audioService.player;

    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final colors = context.colors;
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final visible = _visibleSurahs();

        return Scaffold(
          appBar: AppBar(
            title: const Text('القرآن الكريم'),
            actions: [
              IconButton(
                tooltip: isDark ? 'الوضع الفاتح' : 'الوضع الداكن',
                onPressed: () =>
                    widget.controller.toggleTheme(isDarkNow: isDark),
                icon: Icon(
                  isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                ),
              ),
              const SizedBox(width: 4),
            ],
          ),
          bottomNavigationBar: MiniPlayer(
            audioService: widget.audioService,
            surahs: widget.surahs,
            controller: widget.controller,
          ),
          body: StreamBuilder<int?>(
            stream: player.currentIndexStream,
            initialData: player.currentIndex,
            builder: (context, indexSnapshot) {
              return StreamBuilder<bool>(
                stream: player.playingStream,
                initialData: player.playing,
                builder: (context, playingSnapshot) {
                  final isPlaying = playingSnapshot.data ?? false;
                  final currentNumber = widget.audioService.hasSession.value &&
                          indexSnapshot.data != null
                      ? indexSnapshot.data! + 1
                      : null;

                  return CustomScrollView(
                    controller: _scrollController,
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    slivers: [
                      SliverToBoxAdapter(
                        child: _Header(total: widget.surahs.length),
                      ),
                      SliverPersistentHeader(
                        pinned: true,
                        delegate: _PinnedHeaderDelegate(
                          height: 124,
                          color: colors.background,
                          child: _buildSearchAndFilter(colors),
                        ),
                      ),
                      if (visible.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: _EmptyState(
                            isFavorites: _filter == _Filter.favorites &&
                                _query.trim().isEmpty,
                          ),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                          sliver: SliverList.builder(
                            itemCount: visible.length,
                            itemBuilder: (context, i) {
                              final surah = visible[i];
                              final isCurrent = surah.number == currentNumber;

                              return _SurahTile(
                                key: isCurrent ? _currentTileKey : null,
                                surah: surah,
                                isCurrent: isCurrent,
                                isPlaying: isCurrent && isPlaying,
                                isFavorite:
                                    widget.controller.isFavorite(surah.number),
                                onTap: () => _openSurah(surah),
                                onToggleFavorite: () {
                                  HapticFeedback.selectionClick();
                                  widget.controller
                                      .toggleFavorite(surah.number);
                                },
                              );
                            },
                          ),
                        ),
                    ],
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildSearchAndFilter(AppColors colors) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        children: [
          SizedBox(
            height: 52,
            child: TextField(
              controller: _searchController,
              textDirection: TextDirection.rtl,
              textInputAction: TextInputAction.search,
              onChanged: (value) => setState(() => _query = value),
              decoration: InputDecoration(
                hintText: 'ابحث بالاسم أو برقم السورة...',
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                prefixIcon: Icon(Icons.search, color: colors.gold),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'مسح',
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      ),
                filled: true,
                fillColor: colors.card,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide(color: colors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide(color: colors.gold, width: 1.5),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 44,
            width: double.infinity,
            child: SegmentedButton<_Filter>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(
                  value: _Filter.all,
                  icon: const Icon(Icons.menu_book_outlined, size: 18),
                  label: const Text('كل السور'),
                ),
                ButtonSegment(
                  value: _Filter.favorites,
                  icon: const Icon(Icons.favorite_border, size: 18),
                  label: Text(
                    'المفضلة (${ArabicUtils.toArabicDigits(widget.controller.favoritesCount)})',
                  ),
                ),
              ],
              selected: {_filter},
              onSelectionChanged: (selection) {
                setState(() => _filter = selection.first);
              },
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.resolveWith((states) {
                  return states.contains(WidgetState.selected)
                      ? colors.goldSoft
                      : colors.card;
                }),
                foregroundColor: WidgetStateProperty.resolveWith((states) {
                  return states.contains(WidgetState.selected)
                      ? colors.goldText
                      : colors.muted;
                }),
                side: WidgetStatePropertyAll(BorderSide(color: colors.border)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PinnedHeaderDelegate extends SliverPersistentHeaderDelegate {
  _PinnedHeaderDelegate({
    required this.height,
    required this.color,
    required this.child,
  });

  final double height;
  final Color color;
  final Widget child;

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Material(
      color: color,
      surfaceTintColor: Colors.transparent,
      elevation: overlapsContent ? 2 : 0,
      shadowColor: context.colors.shadow,
      child: child,
    );
  }

  @override
  bool shouldRebuild(covariant _PinnedHeaderDelegate oldDelegate) => true;
}

class _Header extends StatelessWidget {
  const _Header({required this.total});

  final int total;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        children: [
          Text(
            'القرآن الكريم',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: colors.goldText,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'بصوت الشيخ مشاري بن راشد العفاسي',
            style: TextStyle(fontSize: 14, color: colors.muted),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: colors.goldSoft,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${ArabicUtils.toArabicDigits(total)} سورة',
              style: TextStyle(
                color: colors.goldText,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.isFavorites});

  final bool isFavorites;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isFavorites ? Icons.favorite_border : Icons.search_off_rounded,
              size: 56,
              color: colors.gold,
            ),
            const SizedBox(height: 16),
            Text(
              isFavorites
                  ? 'لم تضف أي سورة إلى المفضلة بعد'
                  : 'لا توجد نتائج مطابقة',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              isFavorites
                  ? 'اضغط على القلب بجوار أي سورة لإضافتها هنا'
                  : 'جرّب البحث باسم آخر أو برقم السورة',
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _SurahTile extends StatelessWidget {
  const _SurahTile({
    super.key,
    required this.surah,
    required this.isCurrent,
    required this.isPlaying,
    required this.isFavorite,
    required this.onTap,
    required this.onToggleFavorite,
  });

  final Surah surah;
  final bool isCurrent;
  final bool isPlaying;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: isCurrent ? colors.goldSoft : colors.card,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: isCurrent ? colors.gold : colors.border,
            width: isCurrent ? 1.5 : 1,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isCurrent ? colors.card : colors.goldSoft,
                    border: Border.all(color: colors.gold.withValues(alpha: 0.7)),
                  ),
                  child: Center(
                    child: isCurrent
                        ? EqualizerIcon(
                            animating: isPlaying,
                            color: colors.gold,
                            size: 20,
                          )
                        : Text(
                            ArabicUtils.toArabicDigits(surah.number),
                            style: TextStyle(
                              color: colors.goldText,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        surah.arabicName,
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        surah.englishName,
                        style: TextStyle(fontSize: 13, color: colors.muted),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: isFavorite ? 'إزالة من المفضلة' : 'إضافة إلى المفضلة',
                  onPressed: onToggleFavorite,
                  icon: Icon(
                    isFavorite ? Icons.favorite : Icons.favorite_border,
                    color: isFavorite ? colors.gold : colors.muted,
                  ),
                ),
                Icon(
                  isPlaying
                      ? Icons.pause_circle_filled
                      : (isCurrent
                          ? Icons.play_circle_filled
                          : Icons.play_circle_outline),
                  color: colors.gold,
                  size: 32,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}