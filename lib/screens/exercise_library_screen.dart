import 'package:flutter/material.dart';
import 'package:gymlog/db/db_helper.dart';
import 'package:gymlog/screens/exercise_history_screen.dart';

class ExerciseLibraryScreen extends StatefulWidget {
  const ExerciseLibraryScreen({super.key});
  @override
  State<ExerciseLibraryScreen> createState() => _ExerciseLibraryScreenState();
}

class _ExerciseLibraryScreenState extends State<ExerciseLibraryScreen> {
  List<Map<String, dynamic>> _exercises = [];
  final _nameController = TextEditingController();
  bool _newIsBodyweight = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final list = await DBHelper.getExercisesWithType();
    setState(() => _exercises = list);
  }

  Future<void> _toggleBodyweight(Map<String, dynamic> exercise) async {
    final current = (exercise['is_bodyweight'] as int? ?? 0) == 1;
    await DBHelper.setExerciseBodyweight(exercise['name'] as String, !current);
    await _load();
  }

  Future<void> _confirmDelete(Map<String, dynamic> exercise) async {
    final name = exercise['name'] as String;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete exercise?',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: Text(
          'Remove "$name" from your library?\nThis won\'t delete past sets that used it.',
          style: const TextStyle(color: Color(0xFF666666)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xFF888888))),
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
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
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
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Add Exercise',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextField(
                controller: _nameController,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Exercise name',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Bodyweight exercise'),
                  Switch(
                    value: _newIsBodyweight,
                    activeThumbColor: Colors.black,
                    onChanged: (v) => setModal(() => _newIsBodyweight = v),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () async {
                  final name = _nameController.text.trim();
                  if (name.isEmpty) return;
                  await DBHelper.setExerciseBodyweight(name, _newIsBodyweight);
                  if (ctx.mounted) Navigator.pop(ctx);
                  await _load();
                },
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Exercise Library',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: _exercises.isEmpty
          ? const Center(
              child: Text('No exercises yet.',
                  style: TextStyle(color: Colors.grey)))
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _exercises.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, indent: 16, endIndent: 16),
              itemBuilder: (ctx, i) {
                final ex = _exercises[i];
                final isBw = (ex['is_bodyweight'] as int? ?? 0) == 1;
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
                            ? const Color(0xFFFFD700).withValues(alpha: 0.2)
                            : Colors.grey[100],
                        shape: BoxShape.circle),
                    child: Icon(
                      isBw
                          ? Icons.accessibility_new
                          : Icons.fitness_center,
                      size: 18,
                      color: isBw ? Colors.orange[800] : Colors.grey[600],
                    ),
                  ),
                  title: Text(ex['name'] as String,
                      style: const TextStyle(fontWeight: FontWeight.w500)),
                  trailing: GestureDetector(
                    onTap: () => _toggleBodyweight(ex),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                          color: isBw
                              ? const Color(0xFFFFD700).withValues(alpha: 0.15)
                              : Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: isBw
                                  ? Colors.orange.shade300
                                  : Colors.grey.shade300)),
                      child: Text(
                        isBw ? 'Bodyweight' : 'Weighted',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isBw
                                ? Colors.orange[800]
                                : Colors.grey[700]),
                      ),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }
}
