import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:gymlog/screens/main_shell.dart';
import 'package:gymlog/screens/body_measurements_screen.dart';
import 'package:gymlog/utils/app_colors.dart';
import 'package:gymlog/utils/ki_styles.dart';
import 'package:gymlog/utils/transitions.dart';

class ProfileSetupScreen extends StatefulWidget {
  final bool isEditing;
  const ProfileSetupScreen({super.key, this.isEditing = false});
  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen>
    with SingleTickerProviderStateMixin {
  final _nameController = TextEditingController();
  final _heightController = TextEditingController();
  String? _imagePath;
  bool _saving = false;
  bool _nameError = false;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim =
        CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero)
        .animate(
            CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward();

    if (widget.isEditing) _loadExisting();
  }

  Future<void> _loadExisting() async {
    final prefs = await SharedPreferences.getInstance();
    final height = prefs.getDouble('user_height_cm');
    setState(() {
      _nameController.text = prefs.getString('user_name') ?? '';
      _imagePath = prefs.getString('user_image');
      if (height != null) _heightController.text = height.toInt().toString();
    });
  }

  Future<String?> _persistImage(String pickerPath) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final photosDir = Directory('${dir.path}/profile_photos');
      if (!photosDir.existsSync()) photosDir.createSync(recursive: true);
      final dest =
          '${photosDir.path}/profile_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await File(pickerPath).copy(dest);
      return dest;
    } catch (_) {
      return null;
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardBg(context),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                  color: AppColors.border(ctx),
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 20),
            Text(
              'Profile Photo',
              style: KiStyles.headlineMd(color: AppColors.textPrimary(ctx)),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.border(ctx).withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.camera_alt_outlined,
                    color: AppColors.textPrimary(ctx), size: 20),
              ),
              title: Text('Take a photo',
                  style: KiStyles.body(color: AppColors.textPrimary(ctx))),
              onTap: () async {
                Navigator.pop(ctx);
                final img = await picker.pickImage(
                    source: ImageSource.camera, imageQuality: 80);
                if (img != null) {
                  final saved = await _persistImage(img.path);
                  if (mounted) setState(() => _imagePath = saved ?? img.path);
                }
              },
            ),
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.border(ctx).withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.photo_library_outlined,
                    color: AppColors.textPrimary(ctx), size: 20),
              ),
              title: Text('Choose from gallery',
                  style: KiStyles.body(color: AppColors.textPrimary(ctx))),
              onTap: () async {
                Navigator.pop(ctx);
                final img = await picker.pickImage(
                    source: ImageSource.gallery, imageQuality: 80);
                if (img != null) {
                  final saved = await _persistImage(img.path);
                  if (mounted) setState(() => _imagePath = saved ?? img.path);
                }
              },
            ),
            if (_imagePath != null)
              Builder(builder: (ctx2) {
                final destructive = AppColors.destructive(ctx2);
                return ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: destructive.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.delete_outline,
                        color: destructive, size: 20),
                  ),
                  title: Text('Remove photo',
                      style: KiStyles.body(color: destructive)),
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() => _imagePath = null);
                  },
                );
              }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _nameError = true);
      return;
    }
    setState(() => _saving = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_name', name);
      final height = double.tryParse(_heightController.text.trim());
      if (height != null && height > 0) {
        await prefs.setDouble('user_height_cm', height);
      }
      if (_imagePath != null) {
        await prefs.setString('user_image', _imagePath!);
      } else {
        await prefs.remove('user_image');
      }
      if (!mounted) return;
      if (widget.isEditing) {
        Navigator.pop(context, true);
      } else {
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => const MainShell()));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Something went wrong. Please try again.')),
        );
      }
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    _nameController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bg = AppColors.background(context);
    final textPrimary = AppColors.textPrimary(context);
    final textSecondary = AppColors.textSecondary(context);
    final border = AppColors.border(context);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SlideTransition(
            position: _slideAnim,
            child: SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 16),

                  // ── Brand mark ──
                  Text(
                    'GYMLOG',
                    style: TextStyle(
                      fontFamily: 'Lexend',
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      fontStyle: FontStyle.italic,
                      letterSpacing: 4,
                      color: AppColors.accentContainer(context),
                    ),
                  ),

                  const SizedBox(height: 52),

                  // ── Heading ──
                  Text(
                    widget.isEditing ? 'EDIT PROFILE' : 'WELCOME',
                    style: KiStyles.headlineXl(color: textPrimary),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    widget.isEditing
                        ? 'Update your profile details'
                        : 'Set up your profile\nto start logging workouts',
                    textAlign: TextAlign.center,
                    style: KiStyles.body(color: textSecondary),
                  ),

                  const SizedBox(height: 44),

                  // ── Avatar picker ──
                  GestureDetector(
                    onTap: _pickImage,
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        Container(
                          width: 116,
                          height: 116,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: border.withValues(alpha: 0.5),
                            border: Border.all(
                              color: _imagePath != null
                                  ? AppColors.accentContainer(context)
                                  : border,
                              width: _imagePath != null ? 3 : 2,
                            ),
                          ),
                          child: ClipOval(
                            child: _imagePath != null
                                ? Image.file(File(_imagePath!),
                                    fit: BoxFit.cover)
                                : Center(
                                    child: Icon(Icons.person_outline,
                                        size: 48, color: textSecondary),
                                  ),
                          ),
                        ),
                        Builder(builder: (context) {
                          final ac = AppColors.accentContainer(context);
                          return Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: ac,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.camera_alt,
                                color: AppColors.background(context), size: 17),
                          );
                        }),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),
                  Text(
                    'Tap to add photo',
                    style: KiStyles.labelSm(color: textSecondary),
                  ),

                  const SizedBox(height: 40),

                  // ── Name field ──
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'YOUR NAME',
                        style: KiStyles.label(color: textSecondary),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _nameController,
                        textCapitalization: TextCapitalization.words,
                        style: KiStyles.bodySemibold(color: textPrimary),
                        decoration: InputDecoration(
                          hintText: 'e.g. Alex',
                          hintStyle:
                              TextStyle(color: AppColors.hintText(context)),
                          prefixIcon: Icon(Icons.person_outline,
                              color: _nameError ? AppColors.error(context) : textSecondary),
                          errorText: _nameError ? 'Name is required' : null,
                          filled: true,
                          fillColor: AppColors.inputFill(context),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 16),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                                color: _nameError ? AppColors.error(context) : border, width: 1.5),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                                color: _nameError ? AppColors.error(context) : textPrimary, width: 2),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: AppColors.error(context), width: 1.5),
                          ),
                          focusedErrorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: AppColors.error(context), width: 2),
                          ),
                        ),
                        onChanged: (_) { if (_nameError) setState(() => _nameError = false); },
                        onSubmitted: (_) => _save(),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // ── Height field ──
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'HEIGHT (CM)',
                            style: KiStyles.label(color: textSecondary),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '— used for BMI in body measurements',
                            style: TextStyle(
                              fontSize: 10,
                              color: textSecondary.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _heightController,
                        keyboardType: TextInputType.number,
                        style: KiStyles.bodySemibold(color: textPrimary),
                        decoration: InputDecoration(
                          hintText: 'e.g. 178',
                          hintStyle:
                              TextStyle(color: AppColors.hintText(context)),
                          prefixIcon: Icon(Icons.height_rounded,
                              color: textSecondary),
                          suffixText: 'cm',
                          suffixStyle: TextStyle(color: textSecondary),
                          filled: true,
                          fillColor: AppColors.inputFill(context),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 16),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide:
                                BorderSide(color: border, width: 1.5),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                                color: textPrimary, width: 2),
                          ),
                        ),
                      ),
                    ],
                  ),

                  // ── Body Stats button (edit mode only) ──
                  if (widget.isEditing) ...[
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        fadeSlideRoute(const BodyMeasurementsScreen()),
                      ),
                      icon: Icon(Icons.monitor_weight_outlined,
                          color: textPrimary, size: 18),
                      label: Text(
                        'Body Measurements',
                        style: KiStyles.body(color: textPrimary),
                      ),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                        side: BorderSide(color: border, width: 1.5),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ],

                  const SizedBox(height: 44),

                  // ── CTA button ──
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryBtnBg(context),
                        foregroundColor: AppColors.primaryBtnFg(context),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                        disabledBackgroundColor: AppColors.primaryBtnBg(context)
                            .withValues(alpha: 0.4),
                      ),
                      child: _saving
                          ? SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  color: AppColors.primaryBtnFg(context),
                                  strokeWidth: 2.5))
                          : Text(
                              widget.isEditing
                                  ? 'Save Changes'
                                  : 'Get Started',
                              style: KiStyles.bodySemibold(
                                  color: AppColors.primaryBtnFg(context)),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
