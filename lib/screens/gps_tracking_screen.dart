import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:gymlog/utils/app_colors.dart';
import 'package:gymlog/utils/ki_styles.dart';

/// Result returned to the caller when the user finishes a tracked run.
class GpsTrackingResult {
  final double distanceKm;
  final int durationSeconds;
  final List<Map<String, dynamic>> points; // {lat, lng, alt, ts}
  const GpsTrackingResult({
    required this.distanceKm,
    required this.durationSeconds,
    required this.points,
  });
}

class GpsTrackingScreen extends StatefulWidget {
  const GpsTrackingScreen({super.key});
  @override
  State<GpsTrackingScreen> createState() => _GpsTrackingScreenState();
}

enum _TrackingState { idle, tracking, paused, finished }

class _GpsTrackingScreenState extends State<GpsTrackingScreen> {
  final MapController _mapCtrl = MapController();
  final List<LatLng> _route = [];
  final List<Map<String, dynamic>> _points = [];

  _TrackingState _state = _TrackingState.idle;
  StreamSubscription<Position>? _positionSub;
  Timer? _timer;

  int _elapsedSeconds = 0;
  double _distanceMeters = 0;
  LatLng? _currentPos;
  bool _locationReady = false;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _initLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() => _errorMsg = 'Location services are disabled.');
      return;
    }
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() => _errorMsg = 'Location permission denied.');
        return;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      setState(() => _errorMsg = 'Location permission permanently denied. Enable it in Settings.');
      return;
    }
    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
    if (!mounted) return;
    setState(() {
      _currentPos = LatLng(pos.latitude, pos.longitude);
      _locationReady = true;
    });
    _mapCtrl.move(_currentPos!, 16);
  }

  void _startTracking() {
    setState(() => _state = _TrackingState.tracking);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsedSeconds++);
    });
    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5, // update every 5 meters
      ),
    ).listen(_onPosition);
  }

  void _onPosition(Position pos) {
    if (_state != _TrackingState.tracking) return;
    final newPoint = LatLng(pos.latitude, pos.longitude);
    if (_route.isNotEmpty) {
      _distanceMeters += Geolocator.distanceBetween(
        _route.last.latitude, _route.last.longitude,
        newPoint.latitude, newPoint.longitude,
      );
    }
    setState(() {
      _currentPos = newPoint;
      _route.add(newPoint);
      _points.add({
        'lat': pos.latitude,
        'lng': pos.longitude,
        'alt': pos.altitude,
        'ts': pos.timestamp.millisecondsSinceEpoch,
      });
    });
    _mapCtrl.move(newPoint, _mapCtrl.camera.zoom);
  }

  void _pauseTracking() {
    _positionSub?.pause();
    _timer?.cancel();
    setState(() => _state = _TrackingState.paused);
  }

  void _resumeTracking() {
    _positionSub?.resume();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsedSeconds++);
    });
    setState(() => _state = _TrackingState.tracking);
  }

  void _finish() {
    _positionSub?.cancel();
    _timer?.cancel();
    final result = GpsTrackingResult(
      distanceKm: _distanceMeters / 1000,
      durationSeconds: _elapsedSeconds,
      points: List.from(_points),
    );
    Navigator.pop(context, result);
  }

  String _fmtDuration(int secs) {
    final h = secs ~/ 3600;
    final m = (secs % 3600) ~/ 60;
    final s = secs % 60;
    if (h > 0) return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String _fmtDistance(double meters) {
    if (meters < 1000) return '${meters.toStringAsFixed(0)} m';
    return '${(meters / 1000).toStringAsFixed(2)} km';
  }

  @override
  Widget build(BuildContext context) {
    final bg = AppColors.background(context);
    final textPrimary = AppColors.textPrimary(context);
    final textTertiary = AppColors.textTertiary(context);
    final accent = AppColors.accentContainer(context);

    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        children: [
          // ── Map ──
          if (_errorMsg != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.location_off_rounded, size: 48, color: textTertiary),
                    const SizedBox(height: 16),
                    Text(_errorMsg!, textAlign: TextAlign.center,
                        style: KiStyles.body(color: textTertiary)),
                    const SizedBox(height: 24),
                    OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Go back', style: KiStyles.body(color: textPrimary)),
                    ),
                  ],
                ),
              ),
            )
          else if (!_locationReady)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: accent),
                  const SizedBox(height: 16),
                  Text('Getting location...', style: KiStyles.body(color: textTertiary)),
                ],
              ),
            )
          else
            FlutterMap(
              mapController: _mapCtrl,
              options: MapOptions(
                initialCenter: _currentPos!,
                initialZoom: 16,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.Yonatanzvi.gymlog',
                ),
                if (_route.length >= 2)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: _route,
                        color: accent,
                        strokeWidth: 4,
                      ),
                    ],
                  ),
                MarkerLayer(
                  markers: [
                    if (_route.isNotEmpty)
                      Marker(
                        point: _route.first,
                        width: 14,
                        height: 14,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                    if (_currentPos != null)
                      Marker(
                        point: _currentPos!,
                        width: 18,
                        height: 18,
                        child: Container(
                          decoration: BoxDecoration(
                            color: accent,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2.5),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),

          // ── Top bar (back + title) ──
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back_rounded, color: textPrimary),
                    onPressed: () {
                      if (_state == _TrackingState.idle || _state == _TrackingState.finished) {
                        Navigator.pop(context);
                      } else {
                        _pauseTracking();
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            backgroundColor: AppColors.cardBg(ctx),
                            title: Text('Discard run?',
                                style: KiStyles.headlineMd(color: AppColors.textPrimary(ctx))),
                            content: Text('Your route will not be saved.',
                                style: KiStyles.body(color: AppColors.textSecondary(ctx))),
                            actions: [
                              TextButton(
                                onPressed: () { Navigator.pop(ctx); _resumeTracking(); },
                                child: Text('Continue', style: KiStyles.label(color: accent)),
                              ),
                              TextButton(
                                onPressed: () { Navigator.pop(ctx); Navigator.pop(context); },
                                child: Text('Discard',
                                    style: KiStyles.label(color: AppColors.error(ctx))),
                              ),
                            ],
                          ),
                        );
                      }
                    },
                  ),
                  const Spacer(),
                  Text('GPS TRACKING', style: KiStyles.label(color: textTertiary)),
                  const SizedBox(width: 8),
                ],
              ),
            ),
          ),

          // ── Bottom stats + controls ──
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: SafeArea(
              top: false,
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                decoration: BoxDecoration(
                  color: AppColors.cardBg(context),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Stats row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _statColumn(_fmtDuration(_elapsedSeconds), 'TIME', textPrimary, textTertiary),
                        Container(width: 1, height: 36, color: AppColors.border(context)),
                        _statColumn(_fmtDistance(_distanceMeters), 'DISTANCE', textPrimary, textTertiary),
                        if (_elapsedSeconds > 0 && _distanceMeters > 0) ...[
                          Container(width: 1, height: 36, color: AppColors.border(context)),
                          _statColumn(
                            '${(_elapsedSeconds / 60 / (_distanceMeters / 1000)).toStringAsFixed(1)} min/km',
                            'PACE', textPrimary, textTertiary,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Control buttons
                    if (_state == _TrackingState.idle)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _locationReady ? _startTracking : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accent,
                            foregroundColor: AppColors.primaryBtnFg(context),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 0,
                          ),
                          child: Text('Start', style: KiStyles.bodySemibold(color: AppColors.primaryBtnFg(context))),
                        ),
                      )
                    else if (_state == _TrackingState.tracking)
                      Row(children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _pauseTracking,
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: AppColors.border(context)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            child: Text('Pause', style: KiStyles.bodySemibold(color: textPrimary)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _finish,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: accent,
                              foregroundColor: AppColors.primaryBtnFg(context),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              elevation: 0,
                            ),
                            child: Text('Finish', style: KiStyles.bodySemibold(color: AppColors.primaryBtnFg(context))),
                          ),
                        ),
                      ])
                    else if (_state == _TrackingState.paused)
                      Row(children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _resumeTracking,
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: AppColors.border(context)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            child: Text('Resume', style: KiStyles.bodySemibold(color: textPrimary)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _finish,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: accent,
                              foregroundColor: AppColors.primaryBtnFg(context),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              elevation: 0,
                            ),
                            child: Text('Finish', style: KiStyles.bodySemibold(color: AppColors.primaryBtnFg(context))),
                          ),
                        ),
                      ]),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statColumn(String value, String label, Color textPrimary, Color textTertiary) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value, style: KiStyles.headlineMd(color: textPrimary)),
        const SizedBox(height: 2),
        Text(label, style: KiStyles.labelSm(color: textTertiary)),
      ],
    );
  }
}
