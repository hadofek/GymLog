import 'package:flutter/material.dart';
import 'package:gymlog/db/db_helper.dart';
import 'package:gymlog/screens/exercise_history_screen.dart';
import 'package:gymlog/utils/app_colors.dart';
import 'package:gymlog/utils/exercise_data.dart';
import 'package:gymlog/utils/ki_styles.dart';
import 'package:gymlog/utils/transitions.dart';
import 'package:gymlog/widgets/gymlog_wordmark.dart';
import 'package:gymlog/utils/weight_format.dart';

class PersonalRecordsScreen extends StatefulWidget {
  const PersonalRecordsScreen({super.key});
  @override
  State<PersonalRecordsScreen> createState() => _PersonalRecordsScreenState();
}

class _PersonalRecordsScreenState extends State<PersonalRecordsScreen> {
  List<Map<String, dynamic>> _prs = [];
  bool _loading = true;
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() => setState(() => _query = _searchCtrl.text));
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    await WeightFormat.load();
    final prs = await DBHelper.getAllExercisePRs();
    if (mounted) setState(() { _prs = prs; _loading = false; });
  }

  bool _isBodyweightExercise(Map<String, dynamic> row) {
    if ((row['is_bodyweight'] as int? ?? 0) == 1) return true;
    final bwNames = ExerciseData.bodyweight.values
        .expand((e) => e)
        .map((e) => e.toLowerCase())
        .toSet();
    return bwNames.contains((row['exercise_name'] as String).toLowerCase());
  }

  String _shortDate(String raw) {
    try {
      final parts = raw.trim().split(RegExp(r'\s+')).first.split('/');
      const months = ['Jan','Feb','Mar','Apr','May','Jun',
                      'Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${months[int.parse(parts[1]) - 1]} ${parts[0]}, ${parts[2]}';
    } catch (_) { return raw; }
  }

  List<Map<String, dynamic>> get _filtered {
    final q = _query.toLowerCase().trim();
    if (q.isEmpty) return _prs;
    return _prs.where((r) =>
        (r['exercise_name'] as String).toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final bg = AppColors.background(context);
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);
    final textTertiary = AppColors.textTertiary(context);
    final accentContainer = AppColors.accentContainer(context);
    final border = AppColors.border(context);
    final inputFill = AppColors.inputFill(context);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Row(
          children: [
            const GymlogWordmark(),
            const SizedBox(width: 10),
            Text('RECORDS', style: KiStyles.label(color: textTertiary)),
          ],
        ),
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: AppColors.accent(context)))
          : Column(
              children: [
                // ── Search ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Container(
                    decoration: BoxDecoration(
                      color: inputFill,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: border),
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
                        if (_query.isNotEmpty)
                          Semantics(
                            label: 'Clear search',
                            button: true,
                            child: GestureDetector(
                              onTap: () { _searchCtrl.clear(); setState(() => _query = ''); },
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

                // ── List ──
                Expanded(
                  child: _prs.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.emoji_events_outlined,
                                  size: 40, color: textSecondary),
                              const SizedBox(height: 16),
                              Text('No records yet',
                                  style: KiStyles.headlineMd(color: textPrimary)),
                              const SizedBox(height: 6),
                              Text('Log workouts to set personal bests',
                                  style: KiStyles.body(color: textSecondary)),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: _filtered.length,
                          itemBuilder: (_, i) {
                            final row = _filtered[i];
                            final name = row['exercise_name'] as String;
                            final isBW = _isBodyweightExercise(row);
                            final maxWeight =
                                (row['max_weight'] as num?)?.toDouble() ?? 0.0;
                            final maxReps =
                                (row['max_reps'] as num?)?.toInt() ?? 0;
                            final best1rm =
                                (row['best_1rm'] as num?)?.toDouble() ?? 0.0;
                            final sessions = row['session_count'] as int? ?? 0;
                            final lastDate = row['last_date'] as String? ?? '';

                            return InkWell(
                              onTap: () => Navigator.push(
                                context,
                                fadeSlideRoute(
                                      ExerciseHistoryScreen(exerciseName: name),
                                ),
                              ),
                              child: Column(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Rank number
                                        ConstrainedBox(
                                          constraints: const BoxConstraints(minWidth: 28),
                                          child: Text(
                                            (i + 1).toString().padLeft(2, '0'),
                                            style: KiStyles.labelSm(
                                                color: i == 0
                                                    ? accentContainer
                                                    : textTertiary),
                                          ),
                                        ),
                                        // Name + subtitle
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                name,
                                                style: KiStyles.bodySemibold(
                                                    color: textPrimary),
                                              ),
                                              const SizedBox(height: 3),
                                              Text(
                                                '$sessions session${sessions == 1 ? '' : 's'}'
                                                '${lastDate.isNotEmpty ? '  ·  ${_shortDate(lastDate)}' : ''}',
                                                style: KiStyles.labelSm(
                                                    color: textTertiary),
                                              ),
                                            ],
                                          ),
                                        ),
                                        // PR values
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          children: [
                                            if (!isBW && maxWeight > 0)
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    WeightFormat.format(maxWeight),
                                                    style: KiStyles.bodySemibold(
                                                        color: textPrimary),
                                                  ),
                                                  if (i == 0) ...[
                                                    const SizedBox(width: 6),
                                                    Text('★', style: KiStyles.label(color: accentContainer)),
                                                  ],
                                                ],
                                              ),
                                            if (isBW && maxReps > 0)
                                              Text(
                                                '$maxReps reps',
                                                style: KiStyles.bodySemibold(
                                                    color: textPrimary),
                                              ),
                                            if (!isBW && best1rm > 0)
                                              Text(
                                                'est. 1RM ${WeightFormat.formatRm(best1rm)}',
                                                style: KiStyles.labelSm(
                                                    color: textTertiary),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(width: 8),
                                        Icon(Icons.chevron_right_rounded,
                                            size: 14, color: textTertiary),
                                      ],
                                    ),
                                  ),
                                  Divider(
                                      height: 1,
                                      thickness: 0.5,
                                      color: AppColors.divider(context)),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
