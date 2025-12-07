import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'models.dart';
import 'services.dart';

class PlayScreen extends StatefulWidget {
  final RoundHistory? replayData;
  const PlayScreen({super.key, this.replayData});
  @override
  State<PlayScreen> createState() => _PlayScreenState();
}

class _PlayScreenState extends State<PlayScreen> {
  final List<GolfHole> _holes = CourseRepository.duvenhofHoles;
  List<ClubStats> _bag = CourseRepository.getDefaultBag();
  
  int _currentHoleIndex = 0;
  int _currentShotNum = 1;
  late LatLng _currentBallPos;
  LatLng? _manualDropPos;
  
  List<ShotRecord> _shots = [];
  List<HoleScore> _scorecard = [];
  
  double _windSpeed = 5.0;
  double _windDirection = 180.0;
  bool _showWindPanel = false;
  
  late ClubStats _selectedClub;
  double _aimAngle = 0.0;
  bool _isReplay = false;
  bool _isLoadingLoc = false;

  final MapController _mapController = MapController();
  GolfHole get _hole => _holes[_currentHoleIndex];

  @override
  void initState() {
    super.initState();
    if (widget.replayData != null) {
      _isReplay = true;
      _shots = widget.replayData!.shots;
      _scorecard = widget.replayData!.scorecard;
      _initHole(0);
    } else {
      _currentBallPos = _holes[0].tee;
      _selectedClub = _bag[0];
      WidgetsBinding.instance.addPostFrameCallback((_) => _checkTempSave());
    }
  }

  void _initHole(int index) {
    setState(() {
      _currentHoleIndex = index;
      
      // 如果是复盘模式，球位重置到发球台以便观看
      // 如果是打球模式，也重置到发球台
      _currentBallPos = _holes[index].tee;
      
      // [关键修复]：无论是否复盘，都必须初始化 _selectedClub
      // 否则 build 方法里的物理计算公式会因为找不到球杆而崩溃
      _selectedClub = _bag[0]; 

      if (!_isReplay) {
        _currentShotNum = 1;
        _manualDropPos = null;
        _aimAngle = 0.0;
      }
    });
    if (!_isReplay) StorageService.saveTempState(_currentHoleIndex, _currentShotNum, _scorecard, _shots, _currentBallPos);
    _moveCam();
  }

  void _moveCam() {
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      double b = GolfMath.bearing(_hole.tee, _hole.green);
      _mapController.moveAndRotate(_hole.tee, 17.0, -b);
    });
  }

  Future<void> _checkTempSave() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey('temp_hole')) {
      showDialog(context: context, barrierDismissible: false, builder: (ctx) => AlertDialog(
        title: const Text("未完成比赛"), content: const Text("是否继续？"),
        actions: [
          TextButton(onPressed: () { StorageService.clearTempState(); _initHole(0); Navigator.pop(ctx); }, child: const Text("放弃", style: TextStyle(color: Colors.red))),
          ElevatedButton(onPressed: () { _restoreTemp(prefs); Navigator.pop(ctx); }, child: const Text("继续")),
        ]
      ));
    } else { _initHole(0); }
  }

  void _restoreTemp(SharedPreferences prefs) {
    setState(() {
      _currentHoleIndex = prefs.getInt('temp_hole') ?? 0;
      _currentShotNum = prefs.getInt('temp_shot') ?? 1;
      _currentBallPos = LatLng(prefs.getDouble('temp_lat') ?? _holes[0].tee.latitude, prefs.getDouble('temp_lng') ?? _holes[0].tee.longitude);
      if (prefs.containsKey('temp_card')) {
         var list = jsonDecode(prefs.getString('temp_card')!);
         _scorecard = (list as List).map((e) => HoleScore.fromJson(e)).toList();
      }
      if (prefs.containsKey('temp_shots')) {
         var list = jsonDecode(prefs.getString('temp_shots')!);
         _shots = (list as List).map((e) => ShotRecord.fromJson(e)).toList();
      }
      _selectedClub = _bag[0];
    });
    _moveCam();
  }

  void _recordShot(LatLng pos, double dist) {
    setState(() {
      _shots.add(ShotRecord(_hole.number, _currentShotNum, _currentBallPos, pos, _selectedClub.name, dist));
      _currentBallPos = pos;
      _currentShotNum++;
      _manualDropPos = null;
      _aimAngle = 0.0;
      double d = GolfMath.dist(_currentBallPos, _hole.green);
      if (d < 50) _selectedClub = _bag.last; else _selectedClub = _bag[0];
    });
    StorageService.saveTempState(_currentHoleIndex, _currentShotNum, _scorecard, _shots, _currentBallPos);
    _mapController.move(pos, 18.0);
  }

  Future<void> _useGPS() async {
    setState(() => _isLoadingLoc = true);
    try {
      LocationPermission p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
      if (p == LocationPermission.denied) return;
      
      Position pos = await Geolocator.getCurrentPosition();
      LatLng gps = LatLng(pos.latitude, pos.longitude);
      
      if (GolfMath.dist(gps, _hole.center) > 500) {
        if(!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("⚠️ GPS 偏差过大 (不在球洞附近)")));
      }
      
      double dist = GolfMath.dist(_currentBallPos, gps);
      _recordShot(gps, dist); 
    } catch(e) { debugPrint(e.toString()); } 
    finally { if (mounted) setState(() => _isLoadingLoc = false); }
  }

  Future<void> _finishRound() async {
    if (_isReplay) { Navigator.pop(context); return; }
    final prefs = await SharedPreferences.getInstance();
    String user = prefs.getString('current_user') ?? "Guest";
    RoundHistory history = RoundHistory(id: DateTime.now().toIso8601String(), date: DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now()), courseName: "Duvenhof Golf Club", scorecard: _scorecard, shots: _shots);
    await StorageService.saveRound(user, history);
    await StorageService.clearTempState();
    if(!mounted) return;
    Navigator.pop(context);
  }

  void _finishHole() {
    int putts = 2; int penalties = 0;
    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (c, ss) => AlertDialog(
      title: Text("Hole ${_hole.number} 结算"),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[const Text("Putts"), Row(children:[IconButton(icon:const Icon(Icons.remove),onPressed:()=>ss(()=>putts>0?putts--:0)), Text("$putts"), IconButton(icon:const Icon(Icons.add),onPressed:()=>ss(()=>putts++))])]),
        Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[const Text("Penalties"), Row(children:[IconButton(icon:const Icon(Icons.remove),onPressed:()=>ss(()=>penalties>0?penalties--:0)), Text("$penalties"), IconButton(icon:const Icon(Icons.add),onPressed:()=>ss(()=>penalties++))])]),
      ]),
      actions: [
        ElevatedButton(onPressed: () {
          setState(() {
            _scorecard.removeWhere((s) => s.holeNumber == _hole.number);
            _scorecard.add(HoleScore(holeNumber: _hole.number, par: _hole.par, shotsTaken: _currentShotNum-1, putts: putts, penalties: penalties));
            if (_currentHoleIndex < _holes.length - 1) _initHole(_currentHoleIndex + 1); else _finishRound();
          });
          Navigator.pop(ctx);
        }, child: const Text("Save & Next"))
      ],
    )));
  }

  @override
  Widget build(BuildContext context) {
    double bearing = GolfMath.bearing(_currentBallPos, _hole.green);
    double shotBearing = bearing + _aimAngle;
    LatLng landing = GolfMath.calculateWindShot(_currentBallPos, _selectedClub.carry, shotBearing, _windSpeed, _windDirection);
    List<LatLng> ellipse = GolfMath.getEllipsePoints(landing, _selectedClub.sideError, _selectedClub.depthError, 90 - shotBearing);
    double distToGreen = GolfMath.dist(_currentBallPos, _hole.green);

    return Scaffold(
      appBar: AppBar(
        title: Text("HOLE ${_hole.number} (${_isReplay?'REPLAY':'LIVE'})"),
        leading: _isReplay ? const BackButton() : null,
        actions: [
          if(!_isReplay) IconButton(icon: const Icon(Icons.home), onPressed: () { StorageService.saveTempState(_currentHoleIndex, _currentShotNum, _scorecard, _shots, _currentBallPos); Navigator.pop(context); }),
          IconButton(icon: const Icon(Icons.flag), onPressed: _finishHole)
        ],
      ),
      body: Stack(children: [
        FlutterMap(mapController: _mapController, options: MapOptions(initialCenter: _hole.tee, initialZoom: 17.0, initialRotation: -bearing, onTap: (pos, pt){ if(!_isReplay) setState(()=> _aimAngle = GolfMath.bearing(_currentBallPos, pt)-bearing); }, onLongPress: (pos, pt){ if(!_isReplay) setState(()=> _manualDropPos = pt); }), children: [
          TileLayer(urlTemplate: 'https://mt1.google.com/vt/lyrs=y&x={x}&y={y}&z={z}'),
          
          // 轨迹层 (复盘时显示白色，实战时显示自己打过的)
          PolylineLayer(polylines: _shots.where((s) => s.holeNumber == _hole.number).map((s) => Polyline(points: [s.from, s.to], color: Colors.white, strokeWidth: 2)).toList()),
          
          if (!_isReplay) ...[
            PolylineLayer(polylines: [
              Polyline(points: [_currentBallPos, landing], color: Colors.blue),
              Polyline(points: [landing, _hole.green], color: Colors.yellow) // 虚线移除,改用颜色区分
            ]),
            PolygonLayer(polygons: [Polygon(points: ellipse, color: Colors.blue.withOpacity(0.3), borderColor: Colors.blue, borderStrokeWidth: 1)]),
          ],
          MarkerLayer(markers: [
            Marker(point: _hole.green, child: const Icon(Icons.flag, color: Colors.red)),
            // 在复盘模式下，显示每一杆的落点
            if (_isReplay)
              ..._shots.where((s) => s.holeNumber == _hole.number).map((s) => Marker(point: s.to, child: const Icon(Icons.circle, color: Colors.white, size: 8))),
            
            // 当前位置
            if (!_isReplay) Marker(point: _currentBallPos, child: const Icon(Icons.circle, color: Colors.white, size: 12)),
            
            if (_manualDropPos != null) Marker(point: _manualDropPos!, child: const Icon(Icons.location_on, color: Colors.purple))
          ])
        ]),
        
        if (!_isReplay) Positioned(bottom: 20, left: 10, right: 10, child: Card(color: Colors.black87, child: Column(children: [
          ListTile(title: Text("To Pin: ${distToGreen.toInt()}m"), trailing: DropdownButton<ClubStats>(value: _selectedClub, dropdownColor: Colors.grey[800], items: _bag.map((c) => DropdownMenuItem(value: c, child: Text(c.name, style: const TextStyle(color: Colors.white)))).toList(), onChanged: (v) => setState(() => _selectedClub = v!))),
          if (_manualDropPos != null) ElevatedButton(onPressed: () => _recordShot(_manualDropPos!, GolfMath.dist(_currentBallPos, _manualDropPos!)), child: const Text("确认手工落点"))
          else ElevatedButton.icon(icon: _isLoadingLoc ? const SizedBox(width:10,height:10,child:CircularProgressIndicator()) : const Icon(Icons.near_me), onPressed: _isLoadingLoc ? null : _useGPS, label: const Text("记录落点 (GPS)"))
        ])))
      ]),
    );
  }
}