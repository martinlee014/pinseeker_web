import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:vector_math/vector_math.dart' as vector;
import 'package:geolocator/geolocator.dart';
// [移除] 移除了导致报错的缓存插件引用，改用原生网络加载

// --- 1. 数据模型 ---

class ClubStats {
  String name;
  double carry;
  double sideError;
  double depthError;
  ClubStats(this.name, this.carry, this.sideError, this.depthError);
}

class GolfHole {
  final int number;
  final int par;
  final LatLng tee;
  final LatLng green;
  final List<List<LatLng>> hazards;

  GolfHole({
    required this.number,
    required this.par,
    required this.tee,
    required this.green,
    this.hazards = const [],
  });
}

class ShotRecord {
  final int holeNumber;
  final int shotNumber;
  final LatLng from;
  final LatLng to;
  final String clubUsed;
  final double distance;

  ShotRecord(this.holeNumber, this.shotNumber, this.from, this.to,
      this.clubUsed, this.distance);
}

class HoleScore {
  final int holeNumber;
  final int par;
  final int shotsTaken;
  final int putts;
  final int penalties;
  int get totalScore => shotsTaken + putts + penalties;

  HoleScore(
      {required this.holeNumber,
      required this.par,
      required this.shotsTaken,
      required this.putts,
      required this.penalties});
}

void main() {
  runApp(const PinSeekerApp());
}

class PinSeekerApp extends StatelessWidget {
  const PinSeekerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PinSeeker Web',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.green, brightness: Brightness.dark),
        scaffoldBackgroundColor: Colors.black,
      ),
      home: const GolfMapScreen(),
    );
  }
}

class GolfMapScreen extends StatefulWidget {
  const GolfMapScreen({super.key});

  @override
  State<GolfMapScreen> createState() => _GolfMapScreenState();
}

class _GolfMapScreenState extends State<GolfMapScreen> {
  // --- 数据库 ---
  final List<GolfHole> _courseDatabase = [
    GolfHole(
        number: 1,
        par: 4,
        tee: const LatLng(51.253031, 6.610690),
        green: const LatLng(51.256435, 6.610896)),
    GolfHole(
        number: 2,
        par: 4,
        tee: const LatLng(51.256303, 6.611343),
        green: const LatLng(51.253027, 6.613838)),
    GolfHole(
        number: 3,
        par: 4,
        tee: const LatLng(51.253934, 6.613799),
        green: const LatLng(51.256955, 6.612713)),
  ];

  int _currentHoleIndex = 0;
  late LatLng _currentBallPos;
  final MapController _mapController = MapController();

  List<ShotRecord> _allShotsHistory = [];
  List<HoleScore> _scorecard = [];
  int _currentShotNum = 1;
  bool _isGettingLocation = false;

  double _windSpeed = 5.0;
  double _windDirection = 180.0;
  bool _showWindPanel = false;

  // --- 完整的球杆库 (Full Bag) ---
  final List<ClubStats> _myBag = [
    ClubStats("Driver", 200.0, 45.0, 65.0),
    ClubStats("3 Wood", 190.0, 35.0, 40.0),
    ClubStats("3 Hybrid", 160.0, 28.0, 38.0),
    ClubStats("6 Iron", 140.0, 20.0, 32.0), // 补回
    ClubStats("7 Iron", 130.0, 18.0, 20.0),
    ClubStats("8 Iron", 120.0, 15.0, 15.0), // 补回
    ClubStats("9 Iron", 110.0, 12.0, 10.0),
    ClubStats("W (PW)", 100.0, 10.0, 10.0), // 补回
    ClubStats("S (SW)", 95.0, 8.0, 5.0),
    ClubStats("58° Wedge", 80.0, 6.0, 4.0), // 补回
    ClubStats("Putter", 10.0, 0.0, 0.0), // 推杆保留
  ];

  late ClubStats _selectedClub;
  double _aimAngle = 0.0;
  double _playsLikeDistance = 0.0;

  GolfHole get _currentHole => _courseDatabase[_currentHoleIndex];

  @override
  void initState() {
    super.initState();
    _loadHole(0);
  }

  void _loadHole(int index) {
    setState(() {
      _currentHoleIndex = index;
      _currentBallPos = _courseDatabase[index].tee;
      _currentShotNum = 1;
      _selectedClub = _myBag[0];
      _aimAngle = 0.0;
    });
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        double bearing =
            _calculateBearing(_currentHole.tee, _currentHole.green);
        _mapController.moveAndRotate(_currentHole.tee, 17.5, -bearing);
      }
    });
  }

  // --- GPS 逻辑 ---
  Future<void> _recordLocationAsLandingPoint() async {
    setState(() => _isGettingLocation = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) throw "Permission denied";
      }

      // 获取 GPS
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 10));

      LatLng gpsPos = LatLng(position.latitude, position.longitude);
      double dist = _calculateDistance(_currentBallPos, gpsPos);

      if (!mounted) return;
      _showShotConfirmationDialog(gpsPos, dist);
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("GPS Error: $e")));
    } finally {
      if (mounted) setState(() => _isGettingLocation = false);
    }
  }

  void _showShotConfirmationDialog(LatLng landingPos, double distance) {
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          ClubStats tempClub = _selectedClub;
          return StatefulBuilder(builder: (context, setState) {
            return AlertDialog(
              backgroundColor: Colors.grey[900],
              title: const Text("记录这一杆", style: TextStyle(color: Colors.white)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("${distance.toInt()}m",
                      style: const TextStyle(
                          fontSize: 30,
                          color: Colors.greenAccent,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  const Text("使用的球杆:", style: TextStyle(color: Colors.grey)),
                  DropdownButton<ClubStats>(
                    value: tempClub,
                    dropdownColor: Colors.grey[800],
                    style: const TextStyle(color: Colors.white, fontSize: 18),
                    items: _myBag
                        .map((c) =>
                            DropdownMenuItem(value: c, child: Text(c.name)))
                        .toList(),
                    onChanged: (v) => setState(() => tempClub = v!),
                  ),
                ],
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text("取消")),
                ElevatedButton(
                  onPressed: () {
                    _confirmShot(landingPos, distance, tempClub);
                    Navigator.pop(ctx);
                  },
                  child: const Text("确认"),
                )
              ],
            );
          });
        });
  }

  void _confirmShot(LatLng landingPos, double distance, ClubStats club) {
    setState(() {
      _allShotsHistory.add(ShotRecord(_currentHole.number, _currentShotNum,
          _currentBallPos, landingPos, club.name, distance));
      _currentBallPos = landingPos;
      _currentShotNum++;
      _aimAngle = 0.0;
      _autoSelectClub();
      _mapController.move(landingPos, 18.0);
    });
  }

  // --- 记分与物理算法 ---
  void _finishHoleDialog() {
    int putts = 2;
    int penalties = 0;
    showDialog(
        context: context,
        builder: (ctx) {
          return StatefulBuilder(builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.grey[900],
              title: Text("HOLE ${_currentHole.number} 完成"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildCounterRow("推杆 (Putts)", putts,
                      (val) => setDialogState(() => putts = val)),
                  const SizedBox(height: 10),
                  _buildCounterRow("罚杆 (Penalties)", penalties,
                      (val) => setDialogState(() => penalties = val)),
                ],
              ),
              actions: [
                ElevatedButton(
                    onPressed: () {
                      _saveHoleScore(putts, penalties);
                      Navigator.pop(ctx);
                    },
                    child: const Text("保存并下一洞"))
              ],
            );
          });
        });
  }

  Widget _buildCounterRow(String label, int value, Function(int) onChanged) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: const TextStyle(color: Colors.white)),
      Row(children: [
        IconButton(
            icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
            onPressed: () => value > 0 ? onChanged(value - 1) : null),
        Text("$value",
            style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold)),
        IconButton(
            icon: const Icon(Icons.add_circle_outline, color: Colors.green),
            onPressed: () => onChanged(value + 1)),
      ])
    ]);
  }

  void _saveHoleScore(int putts, int penalties) {
    int shots = _currentShotNum > 0 ? _currentShotNum - 1 : 0;
    setState(() {
      _scorecard.add(HoleScore(
          holeNumber: _currentHole.number,
          par: _currentHole.par,
          shotsTaken: shots,
          putts: putts,
          penalties: penalties));
      if (_currentHoleIndex < _courseDatabase.length - 1) {
        _loadHole(_currentHoleIndex + 1);
      } else {
        _showFullScorecard();
      }
    });
  }

  void _showFullScorecard() {
    showModalBottomSheet(
        context: context,
        backgroundColor: Colors.black,
        builder: (ctx) {
          return Container(
              padding: const EdgeInsets.all(20),
              height: 500,
              child: Column(children: [
                const Text("SCORECARD",
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
                const SizedBox(height: 20),
                Table(border: TableBorder.all(color: Colors.grey), children: [
                  const TableRow(children: [
                    Text("Hole", textAlign: TextAlign.center),
                    Text("Par", textAlign: TextAlign.center),
                    Text("Score", textAlign: TextAlign.center)
                  ]),
                  ..._scorecard.map((s) => TableRow(children: [
                        Padding(
                            padding: const EdgeInsets.all(8),
                            child: Text("${s.holeNumber}",
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.white))),
                        Padding(
                            padding: const EdgeInsets.all(8),
                            child: Text("${s.par}",
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.white))),
                        Padding(
                            padding: const EdgeInsets.all(8),
                            child: Text("${s.totalScore}",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color: _getScoreColor(s.totalScore, s.par),
                                    fontWeight: FontWeight.bold))),
                      ])),
                ]),
                const Spacer(),
                ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text("Close"))
              ]));
        });
  }

  Color _getScoreColor(int score, int par) {
    if (score < par) return Colors.redAccent;
    if (score == par) return Colors.greenAccent;
    if (score == par + 1) return Colors.blueAccent;
    return Colors.white;
  }

  void _showClubEditor() {
    showModalBottomSheet(
        context: context,
        backgroundColor: Colors.grey[900],
        isScrollControlled: true,
        builder: (ctx) {
          return StatefulBuilder(builder: (context, setModalState) {
            return Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("EDIT: ${_selectedClub.name}",
                          style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white)),
                      const SizedBox(height: 20),
                      Text("Carry: ${_selectedClub.carry.toInt()}m"),
                      Slider(
                          value: _selectedClub.carry,
                          min: 50,
                          max: 300,
                          divisions: 50,
                          activeColor: Colors.green,
                          onChanged: (val) {
                            setModalState(() => _selectedClub.carry = val);
                            setState(() {});
                          }),
                      Text("Spread: ${_selectedClub.sideError.toInt()}m"),
                      Slider(
                          value: _selectedClub.sideError,
                          min: 0,
                          max: 100,
                          divisions: 100,
                          activeColor: Colors.blue,
                          onChanged: (val) {
                            setModalState(() => _selectedClub.sideError = val);
                            setState(() {});
                          }),
                      ElevatedButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text("DONE"))
                    ]));
          });
        });
  }

  LatLng _calculateWindAdjustedLandingZone(
      LatLng start, double baseDistance, double bearingDegrees) {
    double relativeWindAngle = (_windDirection - bearingDegrees + 180) % 360;
    double windRad = vector.radians(relativeWindAngle);
    double headWindComp = _windSpeed * math.cos(windRad);
    double crossWindComp = _windSpeed * math.sin(windRad);
    double distEffect = headWindComp * 0.01 * baseDistance;
    double sideEffect = crossWindComp * 0.005 * baseDistance;
    double newDistance = baseDistance - distEffect;
    _playsLikeDistance = newDistance;
    double bearingShift = vector.degrees(math.atan2(sideEffect, newDistance));
    return _calculateDestination(
        start, newDistance, bearingDegrees + bearingShift);
  }

  double _calculateBearing(LatLng start, LatLng end) {
    final lat1 = vector.radians(start.latitude);
    final lat2 = vector.radians(end.latitude);
    final dLon = vector.radians(end.longitude - start.longitude);
    final y = math.sin(dLon) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
    return (vector.degrees(math.atan2(y, x)) + 360) % 360;
  }

  double _calculateDistance(LatLng p1, LatLng p2) =>
      const Distance().as(LengthUnit.Meter, p1, p2);
  LatLng _calculateDestination(
      LatLng start, double distanceMeters, double bearingDegrees) {
    const double earthRadius = 6378137.0;
    final double radLat = vector.radians(start.latitude);
    final double radLon = vector.radians(start.longitude);
    final double radBearing = vector.radians(bearingDegrees);
    final double angularDist = distanceMeters / earthRadius;
    final double endLat = math.asin(math.sin(radLat) * math.cos(angularDist) +
        math.cos(radLat) * math.sin(angularDist) * math.cos(radBearing));
    final double endLon = radLon +
        math.atan2(
            math.sin(radBearing) * math.sin(angularDist) * math.cos(radLat),
            math.cos(angularDist) - math.sin(radLat) * math.sin(endLat));
    return LatLng(vector.degrees(endLat), vector.degrees(endLon));
  }

  List<LatLng> _calculateEllipsePoints(
      LatLng center, double width, double height, double rotation) {
    final List<LatLng> points = [];
    final double rotationRad = vector.radians(rotation);
    for (int i = 0; i <= 36; i++) {
      final double theta = (i / 36) * 2 * math.pi;
      final double dx = (width / 2) * math.cos(theta);
      final double dy = (height / 2) * math.sin(theta);
      final double rx = dx * math.cos(rotationRad) - dy * math.sin(rotationRad);
      final double ry = dx * math.sin(rotationRad) + dy * math.cos(rotationRad);
      final double dLat = ry / 6378137.0;
      final double dLon =
          rx / (6378137.0 * math.cos(vector.radians(center.latitude)));
      points.add(LatLng(center.latitude + vector.degrees(dLat),
          center.longitude + vector.degrees(dLon)));
    }
    return points;
  }

  void _autoSelectClub() {
    double dist = _calculateDistance(_currentBallPos, _currentHole.green);
    try {
      _selectedClub = _myBag.lastWhere((c) => c.carry >= dist - 5);
    } catch (e) {
      _selectedClub = _myBag[0];
    }
    if (dist < 50) _selectedClub = _myBag.last;
  }

  void _onMapTap(TapPosition tapPosition, LatLng point) {
    double tapBearing = _calculateBearing(_currentBallPos, point);
    double holeBearing = _calculateBearing(_currentBallPos, _currentHole.green);
    double diff = tapBearing - holeBearing;
    if (diff > 180) diff -= 360;
    if (diff < -180) diff += 360;
    setState(() {
      _aimAngle = diff;
    });
  }

  @override
  Widget build(BuildContext context) {
    double holeBearing = _calculateBearing(_currentBallPos, _currentHole.green);
    double currentShotBearing = holeBearing + _aimAngle;

    // 物理计算
    LatLng plannedPos = _calculateWindAdjustedLandingZone(
        _currentBallPos, _selectedClub.carry, currentShotBearing);
    List<LatLng> ellipsePoints = _calculateEllipsePoints(
        plannedPos,
        _selectedClub.sideError,
        _selectedClub.depthError,
        90 - currentShotBearing);
    double distanceToGreen =
        _calculateDistance(_currentBallPos, _currentHole.green);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text("HOLE ${_currentHole.number} - SHOT $_currentShotNum"),
        leading: IconButton(
            icon: const Icon(Icons.list_alt), onPressed: _showFullScorecard),
        actions: [
          IconButton(
              icon: Icon(Icons.air,
                  color: _showWindPanel ? Colors.blue : Colors.grey),
              onPressed: () =>
                  setState(() => _showWindPanel = !_showWindPanel)),
          IconButton(
              icon: const Icon(Icons.flag_circle, color: Colors.greenAccent),
              onPressed: _finishHoleDialog),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentHole.tee,
              initialZoom: 17.5,
              initialRotation: -holeBearing,
              onTap: _onMapTap,
            ),
            children: [
              // [核心] 使用默认的 NetworkTileProvider 即可，Safari 浏览器会自动缓存图片
              // 在 Web 端，不需要复杂的缓存插件，浏览器的 HTTP Cache 机制最稳定
              TileLayer(
                urlTemplate:
                    'https://mt1.google.com/vt/lyrs=y&x={x}&y={y}&z={z}',
              ),

              PolylineLayer(
                  polylines: _allShotsHistory
                      .where((s) => s.holeNumber == _currentHole.number)
                      .map((s) => Polyline(
                          points: [s.from, s.to],
                          color: Colors.white,
                          strokeWidth: 3.0))
                      .toList()),
              MarkerLayer(
                  markers: _allShotsHistory
                      .where((s) => s.holeNumber == _currentHole.number)
                      .map((s) => Marker(
                          point: s.to,
                          child: const Icon(Icons.circle,
                              color: Colors.white, size: 8)))
                      .toList()),

              PolylineLayer(polylines: [
                Polyline(
                    points: [_currentBallPos, plannedPos],
                    strokeWidth: 1.5,
                    color: Colors.blueAccent),
                Polyline(
                    points: [plannedPos, _currentHole.green],
                    strokeWidth: 1.5,
                    color: Colors.yellowAccent,
                    isDotted: true),
              ]),
              PolygonLayer(polygons: [
                Polygon(
                    points: ellipsePoints,
                    color: Colors.blueAccent.withOpacity(0.3),
                    borderColor: Colors.blue,
                    isFilled: true),
              ]),
              MarkerLayer(markers: [
                Marker(
                    point: _currentHole.green,
                    child: const Icon(Icons.flag, color: Colors.red, size: 30)),
                Marker(
                    point: _currentBallPos,
                    child: Container(
                        decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.black, width: 2)),
                        width: 16,
                        height: 16)),
                Marker(
                    point: plannedPos,
                    child: const Icon(Icons.gps_fixed,
                        color: Colors.yellow, size: 20)),
              ]),
            ],
          ),
          if (_showWindPanel)
            Positioned(
              top: 10,
              right: 10,
              child: Card(
                  color: Colors.black87,
                  child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(children: [
                        Text("Wind: ${_windSpeed.toInt()} m/s",
                            style: const TextStyle(color: Colors.blueAccent)),
                        SizedBox(
                            height: 100,
                            child: RotatedBox(
                                quarterTurns: 3,
                                child: Slider(
                                    value: _windSpeed,
                                    min: 0,
                                    max: 20,
                                    onChanged: (v) =>
                                        setState(() => _windSpeed = v)))),
                        Text("Dir: ${_windDirection.toInt()}°"),
                        SizedBox(
                            width: 100,
                            child: Slider(
                                value: _windDirection,
                                min: 0,
                                max: 360,
                                divisions: 8,
                                onChanged: (v) =>
                                    setState(() => _windDirection = v)))
                      ]))),
            ),
          Positioned(
            bottom: 20,
            left: 10,
            right: 10,
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14)),
                    onPressed: _isGettingLocation
                        ? null
                        : _recordLocationAsLandingPoint,
                    icon: _isGettingLocation
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child:
                                CircularProgressIndicator(color: Colors.white))
                        : const Icon(Icons.near_me),
                    label: Text(
                        _isGettingLocation ? "GPS 定位中..." : "📍 到达落点 (记录GPS)"),
                  ),
                ),
                const SizedBox(height: 10),
                Card(
                  color: Colors.grey[900]!.withOpacity(0.95),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("To Pin: ${distanceToGreen.toInt()}m",
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold)),
                                  Text(
                                      "Plays Like: ${_playsLikeDistance.toInt()}m",
                                      style: const TextStyle(
                                          color: Colors.blue, fontSize: 12)),
                                ]),
                            Row(children: [
                              DropdownButton<ClubStats>(
                                value: _selectedClub,
                                dropdownColor: Colors.grey[800],
                                style:
                                    const TextStyle(color: Colors.greenAccent),
                                underline: Container(),
                                items: _myBag
                                    .map((c) => DropdownMenuItem(
                                        value: c, child: Text(c.name)))
                                    .toList(),
                                onChanged: (v) =>
                                    setState(() => _selectedClub = v!),
                              ),
                              IconButton(
                                  icon: const Icon(Icons.edit,
                                      size: 16, color: Colors.grey),
                                  onPressed: _showClubEditor)
                            ]),
                          ],
                        ),
                        Row(children: [
                          const Text("Aim",
                              style: TextStyle(color: Colors.grey)),
                          Expanded(
                              child: Slider(
                                  value: _aimAngle,
                                  min: -30,
                                  max: 30,
                                  activeColor: Colors.blue,
                                  onChanged: (v) =>
                                      setState(() => _aimAngle = v))),
                        ]),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}
