import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:vector_math/vector_math.dart' as vector;

// --- 1. 球杆数据模型 ---
class ClubStats {
  final String name;       // 球杆名称
  final double carry;      // 落点距离 (米)
  final double sideError;  // 左右散布 (米)
  final double depthError; // 前后散布 (米)

  ClubStats(this.name, this.carry, this.sideError, this.depthError);
}

void main() {
  runApp(const PinSeekerApp());
}

class PinSeekerApp extends StatelessWidget {
  const PinSeekerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PinSeeker Strategy',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green, brightness: Brightness.dark),
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
  // --- 地理坐标 (Duvenhof 第1洞) ---
  final LatLng _teePosition = const LatLng(51.253049, 6.610663); 
  final LatLng _greenPosition = const LatLng(51.256450, 6.610883); 

  // --- 2. 您的定制球杆库 (已更新数据) ---
  final List<ClubStats> _myBag = [
    ClubStats("Driver", 200.0, 45.0, 65.0),
    ClubStats("3 Wood", 190.0, 35.0, 40.0),
    ClubStats("3 Hybrid", 160.0, 28.0, 38.0),
    ClubStats("6 Iron", 140.0, 20.0, 32.0),
    ClubStats("7 Iron", 130.0, 18.0, 20.0),
    ClubStats("8 Iron", 120.0, 15.0, 15.0),
    ClubStats("9 Iron", 110.0, 12.0, 10.0),
    ClubStats("W (PW)", 100.0, 10.0, 10.0),
    ClubStats("S (SW)", 95.0, 8.0, 5.0),
    ClubStats("58° Wedge", 80.0, 6.0, 4.0),
  ];

  late ClubStats _selectedClub;
  double _aimAngle = 0.0; // 瞄准偏角 (相对于果岭直线的角度)
  
  // 状态显示
  double _remainingDistance = 0.0; // 下一杆剩余距离

  @override
  void initState() {
    super.initState();
    _selectedClub = _myBag[0]; // 默认选 Driver
  }

  // --- 几何算法 ---
  
  // 计算两点间的真实距离 (米)
  double _calculateDistance(LatLng p1, LatLng p2) {
    const Distance distance = Distance();
    return distance.as(LengthUnit.Meter, p1, p2);
  }

  // 计算方位角 (Bearing)
  double _calculateBearing(LatLng start, LatLng end) {
    final lat1 = vector.radians(start.latitude);
    final lat2 = vector.radians(end.latitude);
    final dLon = vector.radians(end.longitude - start.longitude);
    final y = math.sin(dLon) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
    final bearing = math.atan2(y, x);
    return (vector.degrees(bearing) + 360) % 360;
  }

  // 计算目标落点坐标
  LatLng _calculateDestination(LatLng start, double distanceMeters, double bearingDegrees) {
    const double earthRadius = 6378137.0;
    final double radLat = vector.radians(start.latitude);
    final double radLon = vector.radians(start.longitude);
    final double radBearing = vector.radians(bearingDegrees);
    final double angularDist = distanceMeters / earthRadius;
    final double endLat = math.asin(math.sin(radLat) * math.cos(angularDist) +
        math.cos(radLat) * math.sin(angularDist) * math.cos(radBearing));
    final double endLon = radLon + math.atan2(
        math.sin(radBearing) * math.sin(angularDist) * math.cos(radLat),
        math.cos(angularDist) - math.sin(radLat) * math.sin(endLat));
    return LatLng(vector.degrees(endLat), vector.degrees(endLon));
  }

  // 生成椭圆点集
  List<LatLng> _calculateEllipsePoints(
      LatLng center, double widthMeters, double heightMeters, double rotationDegrees) {
    final List<LatLng> points = [];
    const int segments = 36; 
    const double earthRadius = 6378137.0;
    final double rotationRad = vector.radians(rotationDegrees);

    for (int i = 0; i <= segments; i++) {
      final double theta = (i / segments) * 2 * math.pi;
      final double dx = (widthMeters / 2) * math.cos(theta);
      final double dy = (heightMeters / 2) * math.sin(theta);
      final double rotatedX = dx * math.cos(rotationRad) - dy * math.sin(rotationRad);
      final double rotatedY = dx * math.sin(rotationRad) + dy * math.cos(rotationRad);
      final double dLat = rotatedY / earthRadius;
      final double dLon = rotatedX / (earthRadius * math.cos(vector.radians(center.latitude)));
      points.add(LatLng(center.latitude + vector.degrees(dLat), center.longitude + vector.degrees(dLon)));
    }
    return points;
  }

  // --- 交互逻辑: 点击地图调整方向 ---
  void _onMapTap(TapPosition tapPosition, LatLng point) {
    // 1. 计算发球台到点击点的角度
    double tapBearing = _calculateBearing(_teePosition, point);
    // 2. 计算发球台到果岭的标准角度
    double holeBearing = _calculateBearing(_teePosition, _greenPosition);
    
    // 3. 更新瞄准偏差值 (Tap角度 - 洞线角度)
    double diff = tapBearing - holeBearing;
    if (diff > 180) diff -= 360;
    if (diff < -180) diff += 360;

    setState(() {
      _aimAngle = diff; // 更新瞄准方向
    });
  }

  @override
  Widget build(BuildContext context) {
    // 1. 基础角度计算
    double holeBearing = _calculateBearing(_teePosition, _greenPosition);
    double currentShotBearing = holeBearing + _aimAngle;
    
    // 2. 计算落点 (Landing Zone) - 基于当前球杆
    LatLng landingZone = _calculateDestination(_teePosition, _selectedClub.carry, currentShotBearing);
    
    // 3. 计算椭圆
    List<LatLng> ellipsePoints = _calculateEllipsePoints(
      landingZone, _selectedClub.sideError, _selectedClub.depthError, 90 - currentShotBearing 
    );

    // 4. 计算下一杆剩余距离 (从落点到果岭)
    _remainingDistance = _calculateDistance(landingZone, _greenPosition);

    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: _teePosition, 
              initialZoom: 17.0,
              initialRotation: -holeBearing, // Heads Up 模式
              onTap: _onMapTap, // 开启“上帝之手”点击交互
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate, // 禁止用户手动旋转地图
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://mt1.google.com/vt/lyrs=y&x={x}&y={y}&z={z}',
                userAgentPackageName: 'com.pinseeker.app',
              ),
              
              // --- 辅助线层 ---
              PolylineLayer(polylines: [
                // 1. 瞄准线 (Tee -> 落点)
                Polyline(
                  points: [_teePosition, landingZone], 
                  strokeWidth: 2.0, 
                  color: Colors.white,
                ),
                // 2. 策略线 (落点 -> 果岭) - 提示下一杆路径
                Polyline(
                  points: [landingZone, _greenPosition], 
                  strokeWidth: 2.0, 
                  color: Colors.yellowAccent, 
                  isDotted: true, // 虚线表示“未来”
                ),
              ]),

              // --- 椭圆层 ---
              PolygonLayer(polygons: [
                Polygon(
                  points: ellipsePoints, 
                  color: Colors.blueAccent.withOpacity(0.4), 
                  borderColor: Colors.white, 
                  borderStrokeWidth: 1, 
                  isFilled: true
                ),
              ]),

              // --- 标记层 ---
              MarkerLayer(markers: [
                Marker(point: _teePosition, child: const Icon(Icons.sports_golf, color: Colors.white, size: 24)),
                Marker(point: _greenPosition, child: const Icon(Icons.flag, color: Colors.red, size: 30)),
                // 落点中心瞄准星 (已修复图标报错)
                Marker(
                  point: landingZone, 
                  child: const Icon(Icons.gps_fixed, color: Colors.yellowAccent, size: 20)
                ),
              ]),
            ],
          ),
          
          // --- 顶部状态栏 ---
          Positioned(
            top: 50, left: 20, right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.yellowAccent.withOpacity(0.5))
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("NEXT SHOT", style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
                      Text("${_remainingDistance.toInt()}m", style: const TextStyle(color: Colors.yellowAccent, fontSize: 24, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const Icon(Icons.arrow_forward, color: Colors.white54),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text("TO PIN", style: TextStyle(color: Colors.grey, fontSize: 10)),
                      Text("Target", style: TextStyle(color: Colors.white, fontSize: 14)),
                    ],
                  )
                ],
              ),
            ),
          ),

          // --- 底部控制面板 ---
          Positioned(
            bottom: 40, left: 20, right: 20,
            child: Card(
              color: Colors.grey[900]!.withOpacity(0.95),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 球杆选择
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        DropdownButton<ClubStats>(
                          value: _selectedClub,
                          dropdownColor: Colors.grey[800],
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                          underline: Container(), // 去掉下划线
                          icon: const Icon(Icons.arrow_drop_down, color: Colors.green),
                          items: _myBag.map((c) => DropdownMenuItem(value: c, child: Text(c.name))).toList(),
                          onChanged: (v) => setState(() => _selectedClub = v!),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text("Carry: ${_selectedClub.carry.toInt()}m", style: const TextStyle(color: Colors.greenAccent, fontSize: 16)),
                            Text("散布 ±${(_selectedClub.sideError/2).toInt()}m", style: const TextStyle(color: Colors.grey, fontSize: 10)),
                          ],
                        )
                      ],
                    ),
                    const Divider(color: Colors.white12),
                    // 瞄准滑块
                    Row(
                      children: [
                        const Text("Aim", style: TextStyle(color: Colors.grey, fontSize: 12)),
                        Expanded(
                          child: Slider(
                            value: _aimAngle, min: -30, max: 30,
                            activeColor: _aimAngle.abs() > 5 ? Colors.orange : Colors.green,
                            onChanged: (v) => setState(() => _aimAngle = v),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}