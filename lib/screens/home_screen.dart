import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'package:gymlog/db/db_helper.dart';
import 'package:gymlog/screens/profile_setup_screen.dart';
import 'package:gymlog/screens/month_workouts_screen.dart';
import 'package:gymlog/screens/log_workout_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Map<String, dynamic>> _workouts = [];
  String _userName = '';
  String? _userImage;
  DateTime _currentMonth = DateTime(DateTime.now().year, DateTime.now().month);

  Set<int> get _workedOutDays {
    final result = <int>{};
    for (final w in _workouts) {
      final date = _parseDate(w['date'] as String);
      if (date != null &&
          date.month == _currentMonth.month &&
          date.year == _currentMonth.year) {
        result.add(date.day);
      }
    }
    return result;
  }

  List<Map<String, dynamic>> get _monthWorkouts {
    return _workouts.where((w) {
      final date = _parseDate(w['date'] as String);
      return date != null &&
          date.month == _currentMonth.month &&
          date.year == _currentMonth.year;
    }).toList();
  }

  DateTime? _parseDate(String dateStr) {
    try {
      final datePart = dateStr.trim().split(RegExp(r'\s+')).first;
      final parts = datePart.split('/');
      return DateTime(
          int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
    } catch (_) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final w = await DBHelper.getWorkouts();
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _workouts = w;
      _userName = prefs.getString('user_name') ?? '';
      _userImage = prefs.getString('user_image');
    });
  }

  void _prevMonth() => setState(() =>
  _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1));
  void _nextMonth() => setState(() =>
  _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1));

  String get _monthLabel {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[_currentMonth.month - 1]} ${_currentMonth.year}';
  }

  @override
  Widget build(BuildContext context) {
    final daysInMonth =
    DateUtils.getDaysInMonth(_currentMonth.year, _currentMonth.month);
    final firstWeekday =
        DateTime(_currentMonth.year, _currentMonth.month, 1).weekday % 7;
    final monthWorkouts = _monthWorkouts;
    final totalMonthSeconds = monthWorkouts.fold(
        0, (sum, w) => sum + (w['duration_seconds'] as int? ?? 0));
    final workedDays = _workedOutDays;
    final isCurrentMonth = _currentMonth.year == DateTime.now().year &&
        _currentMonth.month == DateTime.now().month;
    final today = DateTime.now().day;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text('GymLog',
            style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        actions: [
          if (totalMonthSeconds > 0)
            Center(
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.timer_outlined,
                        size: 14, color: Color(0xFFFFD700)),
                    const SizedBox(width: 5),
                    Text(
                      DBHelper.formatDuration(totalMonthSeconds),
                      style: const TextStyle(
                        color: Color(0xFFFFD700),
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          GestureDetector(
            onTap: () async {
              await Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const ProfileSetupScreen(isEditing: true)));
              _load();
            },
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: Colors.grey[200],
                backgroundImage:
                _userImage != null ? FileImage(File(_userImage!)) : null,
                child: _userImage == null
                    ? Text(
                    _userName.isNotEmpty
                        ? _userName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                        fontSize: 15))
                    : null,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            if (_userName.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: Row(children: [
                  Text('Hey, $_userName 💪',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                ]),
              ),
            const SizedBox(height: 16),

            // ── Month navigator ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: _prevMonth,
                  ),
                  Text(_monthLabel,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: Icon(Icons.chevron_right,
                        color: isCurrentMonth ? Colors.grey[300] : Colors.black),
                    onPressed: isCurrentMonth ? null : _nextMonth,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // ── Day-of-week headers ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
                    .map((d) => SizedBox(
                  width: 36,
                  child: Center(
                    child: Text(d,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[500])),
                  ),
                ))
                    .toList(),
              ),
            ),

            const SizedBox(height: 8),

            // ── Calendar grid ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 4,
                  childAspectRatio: 1,
                ),
                itemCount: firstWeekday + daysInMonth,
                itemBuilder: (ctx, index) {
                  if (index < firstWeekday) return const SizedBox();
                  final day = index - firstWeekday + 1;
                  final isToday = isCurrentMonth && day == today;
                  final hasWorkout = workedDays.contains(day);
                  final isFuture = isCurrentMonth && day > today;

                  final tappedDate = DateTime(
                      _currentMonth.year, _currentMonth.month, day);

                  return GestureDetector(
                    onTap: isFuture
                        ? null
                        : hasWorkout
                            ? () async {
                                await showModalBottomSheet(
                                  context: context,
                                  shape: const RoundedRectangleBorder(
                                    borderRadius: BorderRadius.vertical(
                                        top: Radius.circular(16)),
                                  ),
                                  builder: (_) => SafeArea(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const SizedBox(height: 8),
                                        Container(
                                          width: 40,
                                          height: 4,
                                          decoration: BoxDecoration(
                                            color: Colors.grey[300],
                                            borderRadius:
                                                BorderRadius.circular(2),
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        ListTile(
                                          leading: const Icon(Icons.list_alt),
                                          title: const Text('View workouts'),
                                          onTap: () {
                                            Navigator.pop(context);
                                            Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                    builder: (_) =>
                                                        MonthWorkoutsScreen(
                                                            workouts:
                                                                monthWorkouts,
                                                            monthLabel:
                                                                _monthLabel,
                                                            initialDay: day)));
                                          },
                                        ),
                                        ListTile(
                                          leading: const Icon(Icons.add),
                                          title:
                                              const Text('Add another workout'),
                                          onTap: () {
                                            Navigator.pop(context);
                                            Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                    builder: (_) =>
                                                        LogWorkoutScreen(
                                                            initialDate:
                                                                tappedDate)));
                                          },
                                        ),
                                        const SizedBox(height: 8),
                                      ],
                                    ),
                                  ),
                                );
                                _load();
                              }
                            : () async {
                                await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) => LogWorkoutScreen(
                                            initialDate: tappedDate)));
                                _load();
                              },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: hasWorkout
                            ? const Color(0xFFFFD700)
                            : isToday
                            ? Colors.black
                            : Colors.grey[100],
                      ),
                      child: Center(
                        child: Text(
                          '$day',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: hasWorkout || isToday
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: hasWorkout
                                ? Colors.black
                                : isToday
                                ? Colors.white
                                : isFuture
                                ? Colors.grey[300]
                                : Colors.black87,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 20),

            // ── Stats ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _StatChip(
                    icon: Icons.local_fire_department,
                    label: '${workedDays.length}',
                    sub: 'workouts this month',
                    color: const Color(0xFFFFD700),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── View list button ──
            if (monthWorkouts.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => MonthWorkoutsScreen(
                                workouts: monthWorkouts,
                                monthLabel: _monthLabel)));
                    _load();
                  },
                  icon: const Icon(Icons.list_alt, color: Colors.black),
                  label: Text(
                      'View ${monthWorkouts.length} workout${monthWorkouts.length > 1 ? 's' : ''} this month',
                      style: const TextStyle(color: Colors.black)),
                  style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                      side: const BorderSide(color: Colors.black),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12))),
                ),
              ),

            const SizedBox(height: 100),
          ],
        ),
      ),
      floatingActionButton: Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewPadding.bottom),
        child: FloatingActionButton.extended(
          onPressed: () async {
            await Navigator.push(context,
                MaterialPageRoute(builder: (_) => LogWorkoutScreen()));
            _load();
          },
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add),
          label: const Text('New Workout'),
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sub;
  final Color color;
  const _StatChip(
      {required this.icon,
        required this.label,
        required this.sub,
        required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 8),
          Text(label,
              style:
              const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(width: 6),
          Text(sub, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
        ],
      ),
    );
  }
}
