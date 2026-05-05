import 'package:flutter/material.dart';
import 'package:gymlog/db/db_helper.dart';
import 'package:gymlog/screens/exercise_history_screen.dart';
import 'package:gymlog/utils/app_colors.dart';

const _muscleGroups = [
  'Chest', 'Back', 'Shoulders', 'Biceps', 'Triceps',
  'Legs', 'Glutes', 'Core', 'Full Body', 'Other',
];

class ExerciseLibraryScreen extends StatefulWidget {
  const ExerciseLibraryScreen({super.key});
  @override
  State<ExerciseLibraryScreen> createState() => _ExerciseLibraryScreenState();
}

class _ExerciseLibraryScreenState extends State<ExerciseLibraryScreen> {
  List<Map<String, dynamic>> _exercises = [];
  List<Map<String, dynamic>> _filtered = [];
  final _searchCtrl = TextEditingController();
  final _nameController = TextEditingController();
  bool _newIsBodyweight = false;
  String? _newMuscleGroup;

  @override
  void initState() {
    super.initState();
    _load();
    _searchCtrl.addListener(_applyFilter);
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_applyFilter);
    _searchCtrl.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final list = await DBHelper.getExercisesWithType();
    if (mounted) {
      setState(() {
        _exercises = list;
        _applyFilter();
      });
    }
  }

  void _applyFilter() {
    final query = _searchCtrl.text.toLowerCase();
    setState(() {
      _filtered = query.isEmpty
          ? _exercises
          : _exercises
              .where((e) =>
                  (e['name'] as String).toLowerCase().contains(query))
              .toList();
    });
  }

  Future<void> _toggleBodyweight(Map<String, dynamic> exercise) async {
    final current = (exercise['is_bodyweight'] as int? ?? 0) == 1;
    await DBHelper.setExerciseBodyweight(exercise['name'] as String, !current);
    await _load();
  }

  Future<void> _setMuscleGroup(
      Map<String, dynamic> exercise, String? group) async {
    await DBHelper.setExerciseMuscleGroup(exercise['name'] as String, group);
    await _load();
  }

  Future<void> _confirmDelete(Map<String, dynamic> exercise) async {
    final name = exercise['name'] as String;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBg(ctx),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete exercise?',
            style: TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary(ctx))),
        content: Text(
          'Remove "$name" from your library?\nThis won\'t delete past sets.',
          style: TextStyle(color: AppColors.textSecondary(ctx)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: TextStyle(color: AppColors.textSecondary(ctx))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
              backgroundColor: const Color(0xFFE53935).withValues(alpha: 0.08),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Delete',
                style: TextStyle(
                    color: Color(0xFFE53935), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await DBHelper.deleteExercise(name);
      await _load();
    }
  }

  Future<void> _showAddDialog() async {
    _nameController.clear();
    _newIsBodyweight = false;
    _newMuscleGroup = null;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardBg(context),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: EdgeInsets.fromLTRB(
              24, 20, 24, 24 + MediaQuery.of(ctx).viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: AppColors.border(ctx),
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Text('Add Exercise',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary(ctx))),
              const SizedBox(height: 16),
              TextField(
                controller: _nameController,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                style: TextStyle(color: AppColors.textPrimary(ctx)),
                decoration: InputDecoration(
                  labelText: 'Exercise name',
                  labelStyle:
                      TextStyle(color: AppColors.textSecondary(ctx)),
                  filled: true,
                  fillColor: AppColors.inputFill(ctx),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide:
                        BorderSide(color: AppColors.border(ctx)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide:
                        BorderSide(color: AppColors.textPrimary(ctx), width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text('Muscle Group',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: AppColors.textSecondary(ctx))),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: _muscleGroups.map((g) {
                  final selected = _newMuscleGroup == g;
                  return GestureDetector(
                    onTap: () => setModal(
                        () => _newMuscleGroup = selected ? null : g),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: selected
                            ? const Color(0xFFE8E8E8)
                                .withValues(alpha: 0.25)
                            : AppColors.inputFill(ctx),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: selected
                              ? const Color(0xFFE8E8E8)
                              : AppColors.border(ctx),
                          width: 1.5,
                        ),
                      ),
                      child: Text(g,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: selected
                                  ? const Color(0xFF8B7500)
                                  : AppColors.textSecondary(ctx))),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Bodyweight exercise',
                      style: TextStyle(
                          color: AppColors.textPrimary(ctx))),
                  Switch(
                    value: _newIsBodyweight,
                    activeThumbColor: Colors.black,
                    onChanged: (v) =>
                        setModal(() => _newIsBodyweight = v),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () async {
                  final name = _nameController.text.trim();
                  if (name.isEmpty) return;
                  await DBHelper.setExerciseBodyweight(
                      name, _newIsBodyweight);
                  if (_newMuscleGroup != null) {
                    await DBHelper.setExerciseMuscleGroup(
                        name, _newMuscleGroup);
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                  await _load();
                },
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBtnBg(ctx),
                    foregroundColor: AppColors.primaryBtnFg(ctx),
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
                child: const Text('Add'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMuscleGroupPicker(Map<String, dynamic> exercise) async {
    final current = exercise['muscle_group'] as String?;

    await showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardBg(context),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                      color: AppColors.border(ctx),
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 14),
              Text('Muscle Group',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary(ctx))),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ..._muscleGroups.map((g) {
                    final sel = current == g;
                    return GestureDetector(
                      onTap: () async {
                        Navigator.pop(ctx);
                        await _setMuscleGroup(exercise, sel ? null : g);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: sel
                              ? const Color(0xFFE8E8E8)
                                  .withValues(alpha: 0.25)
                              : AppColors.inputFill(ctx),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: sel
                                ? const Color(0xFFE8E8E8)
                                : AppColors.border(ctx),
                            width: 1.5,
                          ),
                        ),
                        child: Text(g,
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: sel
                                    ? const Color(0xFF8B7500)
                                    : AppColors.textPrimary(ctx))),
                      ),
                    );
                  }),
                  if (current != null)
                    GestureDetector(
                      onTap: () async {
                        Navigator.pop(ctx);
                        await _setMuscleGroup(exercise, null);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE53935)
                              .withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: const Color(0xFFE53935)
                                  .withValues(alpha: 0.3)),
                        ),
                        child: const Text('Clear',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFE53935))),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bg = AppColors.background(context);
    final card = AppColors.cardBg(context);
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);
    final border = AppColors.border(context);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text('Exercise Library',
            style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 20,
                color: textPrimary,
                letterSpacing: -0.3)),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        backgroundColor: AppColors.primaryBtnBg(context),
        foregroundColor: AppColors.primaryBtnFg(context),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              style: TextStyle(color: textPrimary),
              decoration: InputDecoration(
                hintText: 'Search exercises…',
                hintStyle:
                    TextStyle(color: AppColors.hintText(context)),
                prefixIcon:
                    Icon(Icons.search, color: textSecondary, size: 20),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.close,
                            color: textSecondary, size: 18),
                        onPressed: _searchCtrl.clear,
                      )
                    : null,
                filled: true,
                fillColor: card,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: border, width: 1.5),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: textPrimary, width: 2),
                ),
              ),
            ),
          ),
          // List
          Expanded(
            child: _filtered.isEmpty
                ? Center(
                    child: Text(
                      _exercises.isEmpty
                          ? 'No exercises yet.'
                          : 'No matches for "${_searchCtrl.text}"',
                      style: TextStyle(color: textSecondary),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(0, 4, 0, 100),
                    itemCount: _filtered.length,
                    separatorBuilder: (_, __) => Divider(
                        height: 1,
                        indent: 16,
                        endIndent: 16,
                        color: border),
                    itemBuilder: (ctx, i) {
                      final ex = _filtered[i];
                      final isBw =
                          (ex['is_bodyweight'] as int? ?? 0) == 1;
                      final muscleGroup =
                          ex['muscle_group'] as String?;
                      return ListTile(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ExerciseHistoryScreen(
                                exerciseName: ex['name'] as String),
                          ),
                        ),
                        onLongPress: () => _confirmDelete(ex),
                        leading: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                              color: isBw
                                  ? const Color(0xFFE8E8E8)
                                      .withValues(alpha: 0.2)
                                  : border.withValues(alpha: 0.5),
                              shape: BoxShape.circle),
                          child: Icon(
                            isBw
                                ? Icons.accessibility_new
                                : Icons.fitness_center,
                            size: 18,
                            color: isBw
                                ? Colors.orange[800]
                                : textSecondary,
                          ),
                        ),
                        title: Text(ex['name'] as String,
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: textPrimary)),
                        subtitle: muscleGroup != null
                            ? Text(muscleGroup,
                                style: TextStyle(
                                    fontSize: 12, color: textSecondary))
                            : null,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            GestureDetector(
                              onTap: () =>
                                  _showMuscleGroupPicker(ex),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                    color: muscleGroup != null
                                        ? AppColors.gold
                                            .withValues(alpha: 0.20)
                                        : border.withValues(alpha: 0.5),
                                    borderRadius:
                                        BorderRadius.circular(8)),
                                child: Text(
                                  muscleGroup ?? 'Tag',
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: muscleGroup != null
                                          ? AppColors.goldDark
                                          : textSecondary),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () => _toggleBodyweight(ex),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                    color: isBw
                                        ? const Color(0xFFE8E8E8)
                                            .withValues(alpha: 0.15)
                                        : border.withValues(alpha: 0.5),
                                    borderRadius:
                                        BorderRadius.circular(8),
                                    border: Border.all(
                                        color: isBw
                                            ? Colors.orange.shade300
                                            : border)),
                                child: Text(
                                  isBw ? 'BW' : 'W',
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: isBw
                                          ? Colors.orange[800]
                                          : textSecondary),
                                ),
                              ),
                            ),
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
