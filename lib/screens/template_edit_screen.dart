import 'package:flutter/material.dart';
import 'package:gymlog/db/db_helper.dart';
import 'package:gymlog/utils/app_colors.dart';

class TemplateEditScreen extends StatefulWidget {
  final int templateId;
  final String templateName;
  final String templateType;
  final List<String> exercises;

  const TemplateEditScreen({
    super.key,
    required this.templateId,
    required this.templateName,
    required this.templateType,
    required this.exercises,
  });

  @override
  State<TemplateEditScreen> createState() => _TemplateEditScreenState();
}

class _TemplateEditScreenState extends State<TemplateEditScreen> {
  late List<String> _exercises;
  late TextEditingController _nameCtrl;
  List<String> _allExercises = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _exercises = List<String>.from(widget.exercises);
    _nameCtrl = TextEditingController(text: widget.templateName);
    _loadExercises();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadExercises() async {
    final list = await DBHelper.getExercises();
    if (mounted) setState(() => _allExercises = list);
  }

  Future<void> _showAddExerciseSheet() async {
    final card = AppColors.cardBg(context);
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);
    final border = AppColors.border(context);

    final searchCtrl = TextEditingController();
    List<String> filtered = List<String>.from(_allExercises);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          builder: (ctx, scrollCtrl) => Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: Column(
                  children: [
                    Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                          color: border,
                          borderRadius: BorderRadius.circular(2)),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Add Exercise',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: searchCtrl,
                      onChanged: (v) => setModal(() {
                        filtered = _allExercises
                            .where((e) =>
                                e.toLowerCase().contains(v.toLowerCase()))
                            .toList();
                      }),
                      style: TextStyle(color: textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Search exercises…',
                        hintStyle: TextStyle(color: AppColors.hintText(ctx)),
                        prefixIcon: Icon(Icons.search,
                            color: textSecondary, size: 20),
                        filled: true,
                        fillColor: AppColors.inputFill(ctx),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              BorderSide(color: border, width: 1.5),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                              color: textPrimary, width: 2),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) =>
                      Divider(height: 1, color: border),
                  itemBuilder: (ctx, i) {
                    final name = filtered[i];
                    final already = _exercises.contains(name);
                    return ListTile(
                      title: Text(name,
                          style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: already
                                  ? textSecondary
                                  : textPrimary)),
                      trailing: already
                          ? Icon(Icons.check_circle_outline,
                              color: AppColors.gold, size: 20)
                          : Icon(Icons.add_circle_outline,
                              color: textSecondary, size: 20),
                      onTap: already
                          ? null
                          : () {
                              setState(() => _exercises.add(name));
                              setModal(() {});
                              Navigator.pop(ctx);
                            },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Template name cannot be empty')),
      );
      return;
    }
    if (_exercises.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one exercise')),
      );
      return;
    }
    setState(() => _saving = true);
    await DBHelper.updateTemplateExercises(
        widget.templateId, name, _exercises);
    if (mounted) Navigator.pop(context, true);
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
        title: Text(
          'Edit Template',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 20,
            color: textPrimary,
            letterSpacing: -0.3,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: Text(
              'Save',
              style: TextStyle(
                color: AppColors.gold,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Name field
                Text(
                  'TEMPLATE NAME',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: textSecondary,
                      letterSpacing: 1.2),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: textPrimary),
                  decoration: InputDecoration(
                    hintText: 'e.g. Push Day A',
                    hintStyle: TextStyle(color: AppColors.hintText(context)),
                    filled: true,
                    fillColor: AppColors.inputFill(context),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
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

                const SizedBox(height: 24),

                // Exercises header
                Row(children: [
                  Text(
                    'EXERCISES',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: textSecondary,
                        letterSpacing: 1.2),
                  ),
                  const Spacer(),
                  Text(
                    '${_exercises.length} exercises',
                    style: TextStyle(fontSize: 12, color: textSecondary),
                  ),
                ]),
                const SizedBox(height: 8),

                if (_exercises.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: border.withValues(alpha: 0.5), width: 1.5),
                    ),
                    child: Center(
                      child: Text(
                        'No exercises yet.\nTap + to add exercises.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: textSecondary, fontSize: 14),
                      ),
                    ),
                  )
                else
                  ReorderableListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _exercises.length,
                    onReorder: (oldIndex, newIndex) {
                      setState(() {
                        if (newIndex > oldIndex) newIndex--;
                        final item = _exercises.removeAt(oldIndex);
                        _exercises.insert(newIndex, item);
                      });
                    },
                    itemBuilder: (ctx, i) {
                      final name = _exercises[i];
                      return Container(
                        key: ValueKey('$name-$i'),
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: card,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 4),
                          leading: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: AppColors.gold.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                '${i + 1}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.goldDark,
                                ),
                              ),
                            ),
                          ),
                          title: Text(
                            name,
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                                color: textPrimary),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                onPressed: () =>
                                    setState(() => _exercises.removeAt(i)),
                                icon: const Icon(Icons.close,
                                    size: 18, color: Color(0xFFE53935)),
                                style: IconButton.styleFrom(
                                  backgroundColor: const Color(0xFFE53935)
                                      .withValues(alpha: 0.08),
                                  minimumSize: const Size(32, 32),
                                  padding: EdgeInsets.zero,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                              const SizedBox(width: 4),
                              ReorderableDragStartListener(
                                index: i,
                                child: Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Icon(Icons.drag_handle,
                                      color: textSecondary),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),

          // Add exercise button
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              decoration: BoxDecoration(
                color: AppColors.bottomBarBg(context),
                border: Border(top: BorderSide(color: border, width: 1)),
              ),
              child: ElevatedButton.icon(
                onPressed: _showAddExerciseSheet,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Exercise',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: const Color(0xFF111111),
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
