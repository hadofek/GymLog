import 'package:flutter/material.dart';
import 'package:gymlog/db/db_helper.dart';
import 'package:gymlog/screens/exercise_history_screen.dart';
import 'package:gymlog/utils/exercise_data.dart';
import 'package:gymlog/utils/app_colors.dart';
import 'package:gymlog/utils/ki_styles.dart';
import 'package:gymlog/widgets/tip_overlay.dart';

class ExerciseLibraryScreen extends StatefulWidget {
  const ExerciseLibraryScreen({super.key});
  @override
  State<ExerciseLibraryScreen> createState() => _ExerciseLibraryScreenState();
}

class _ExerciseLibraryScreenState extends State<ExerciseLibraryScreen> {
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String? _expandedCategory;
  Set<String> _loggedNames = {};

  static final Map<String, List<String>> _library = ExerciseData.full;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() => setState(() => _searchQuery = _searchCtrl.text));
    _loadLogged();
  }

  Future<void> _loadLogged() async {
    final names = await DBHelper.getExerciseNamesWithSets();
    if (mounted) setState(() => _loggedNames = names);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<String> get _searchResults {
    final q = _searchQuery.toLowerCase().trim();
    if (q.isEmpty) return [];
    final seen = <String>{};
    return _library.values
        .expand((list) => list)
        .where((name) => name.toLowerCase().contains(q) && seen.add(name.toLowerCase()))
        .toList()
      ..sort();
  }

  void _openHistory(String name) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ExerciseHistoryScreen(exerciseName: name)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bg = AppColors.background(context);
    final textPrimary = AppColors.textPrimary(context);
    final textTertiary = AppColors.textTertiary(context);
    final border = AppColors.border(context);
    final inputFill = AppColors.inputFill(context);
    final accent = AppColors.accentContainer(context);

    final hasSearch = _searchQuery.isNotEmpty;
    final searchResults = _searchResults;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text('Exercise Library', style: KiStyles.headlineMd(color: textPrimary)),
      ),
      body: Column(
        children: [
          // ── Search bar ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Container(
              decoration: BoxDecoration(
                color: inputFill,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: border, width: 1),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Icon(Icons.search_rounded, size: 17, color: textTertiary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      style: KiStyles.body(color: textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Search exercises',
                        hintStyle: KiStyles.body(color: textTertiary),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  if (_searchQuery.isNotEmpty)
                    Semantics(
                      label: 'Clear search',
                      button: true,
                      child: GestureDetector(
                        onTap: () {
                          _searchCtrl.clear();
                          setState(() => _searchQuery = '');
                        },
                        behavior: HitTestBehavior.opaque,
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(Icons.close_rounded, size: 16, color: textTertiary),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Divider(height: 1, thickness: 0.5, color: border),

          // ── Exercise list ──
          Expanded(
            child: hasSearch
                ? _buildFlatList(searchResults, textPrimary, textTertiary, border, accent)
                : _buildAccordion(textPrimary, textTertiary, border, accent),
          ),
        ],
      ),
    );
  }

  Widget _buildFlatList(
    List<String> names,
    Color textPrimary,
    Color textTertiary,
    Color border,
    Color accent,
  ) {
    if (names.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search_off_rounded, size: 32, color: textTertiary),
              const SizedBox(height: 12),
              Text('No exercises match "$_searchQuery"',
                  textAlign: TextAlign.center,
                  style: KiStyles.body(color: textTertiary)),
              const SizedBox(height: 4),
              Text('You can add custom exercises when logging a workout.',
                  textAlign: TextAlign.center,
                  style: KiStyles.labelSm(color: textTertiary)),
            ],
          ),
        ),
      );
    }
    bool tipAssigned = false;
    return ListView.builder(
      itemCount: names.length,
      itemBuilder: (_, i) {
        final name = names[i];
        final hasHistory = _loggedNames.contains(name.toLowerCase());
        final showTip = hasHistory && !tipAssigned;
        if (showTip) tipAssigned = true;
        return _exerciseRow(name, textPrimary, textTertiary, border, accent, showTip: showTip);
      },
    );
  }

  Widget _buildAccordion(
    Color textPrimary,
    Color textTertiary,
    Color border,
    Color accent,
  ) {
    final categories = _library.keys.toList();
    return ListView.builder(
      itemCount: categories.length,
      itemBuilder: (_, i) {
        final cat = categories[i];
        final exercises = _library[cat]!;
        final isExpanded = _expandedCategory == cat;
        final loggedCount =
            exercises.where((n) => _loggedNames.contains(n.toLowerCase())).length;

        return Column(
          children: [
            // ── Category header ──
            InkWell(
              onTap: () => setState(() =>
                  _expandedCategory = isExpanded ? null : cat),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                child: SizedBox(
                  height: 52,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(cat,
                            style: KiStyles.bodySemibold(color: textPrimary)),
                      ),
                      if (loggedCount > 0 && !isExpanded)
                        Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: Text('$loggedCount logged',
                              style: KiStyles.labelSm(color: textTertiary)),
                        ),
                      AnimatedRotation(
                        turns: isExpanded ? 0.25 : 0,
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOutCubic,
                        child: Icon(Icons.chevron_right_rounded,
                            size: 18, color: textTertiary),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Divider(height: 1, thickness: 0.5, color: border),

            // ── Exercises (animated expand) ──
            AnimatedSize(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeInOutCubic,
              child: isExpanded
                  ? Builder(builder: (ctx) {
                      bool tipAssigned = false;
                      return Column(
                        children: exercises.map((name) {
                          final hasHistory = _loggedNames.contains(name.toLowerCase());
                          final showTip = hasHistory && !tipAssigned;
                          if (showTip) tipAssigned = true;
                          return _exerciseRow(name, textPrimary, textTertiary, border, accent, showTip: showTip);
                        }).toList(),
                      );
                    })
                  : const SizedBox.shrink(),
            ),
          ],
        );
      },
    );
  }

  Widget _exerciseRow(
    String name,
    Color textPrimary,
    Color textTertiary,
    Color border,
    Color accent, {
    bool showTip = false,
  }) {
    final hasHistory = _loggedNames.contains(name.toLowerCase());
    final row = InkWell(
      onTap: () => _openHistory(name),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
            child: SizedBox(
              height: 48,
              child: Row(
                children: [
                  Expanded(
                    child: Text(name, style: KiStyles.body(color: textPrimary)),
                  ),
                  if (hasHistory)
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                          color: accent, shape: BoxShape.circle),
                    )
                  else
                    Icon(Icons.chevron_right_rounded,
                        size: 16, color: textTertiary),
                ],
              ),
            ),
          ),
          Divider(height: 1, thickness: 0.5, color: border),
        ],
      ),
    );
    if (!showTip) return row;
    return TipOverlay(
      tipKey: 'tip_library_progress',
      tipTitle: 'Progress dot',
      tipBody: 'The amber dot means you have logged this exercise. Tap it to see your history and progress chart.',
      direction: TipDirection.left,
      child: row,
    );
  }
}
