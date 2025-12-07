import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:vector_math/vector_math.dart' as vector;
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

// =======================
// 1. 数据模型
// =======================

class ClubStats {
  String name;
  double carry;
  double sideError;
  double depthError;
  ClubStats(this.name, this.carry, this.sideError, this.depthError);
  
  Map<String, dynamic> toJson() => {'name': name, 'carry': carry, 'sideError': sideError, 'depthError': depthError};
  factory ClubStats.fromJson(Map<String, dynamic> json) => ClubStats(json['name'], json['carry'], json['sideError'], json['depthError']);
}

class GolfHole {
  final int number;
  final int par;
  final LatLng tee;
  final LatLng green;
  GolfHole({required this.number, required this.par, required this.tee, required this.green});
  LatLng get center => LatLng((tee.latitude + green.latitude)/2, (tee.longitude + green.longitude)/2);
}

class ShotRecord {
  final int holeNumber;
  final int shotNumber;
  final LatLng from;
  final LatLng to;
  final String clubUsed;
  final double distance;

  ShotRecord(this.holeNumber, this.shotNumber, this.from, this.to, this.clubUsed, this.distance);

  Map<String, dynamic> toJson() => {
    'holeNumber': holeNumber, 'shotNumber': shotNumber,
    'fromLat': from.latitude, 'fromLng': from.longitude,
    'toLat': to.latitude, 'toLng': to.longitude,
    'clubUsed': clubUsed, 'distance': distance,
  };
  factory ShotRecord.fromJson(Map<String, dynamic> json) => ShotRecord(
    json['holeNumber'], json['shotNumber'], LatLng(json['fromLat'], json['fromLng']), LatLng(json['toLat'], json['toLng']), json['clubUsed'], json['distance']
  );
}

class HoleScore {
  final int holeNumber;
  final int par;
  final int shotsTaken;
  final int putts;
  final int penalties;
  int get totalScore => shotsTaken + putts + penalties;
  bool get isGIR => shotsTaken <= (par - 2);

  HoleScore({required this.holeNumber, required this.par, required this.shotsTaken, required this.putts, required this.penalties});

  Map<String, dynamic> toJson() => {'holeNumber': holeNumber, 'par': par, 'shotsTaken': shotsTaken, 'putts': putts, 'penalties': penalties};
  factory HoleScore.fromJson(Map<String, dynamic> json) => HoleScore(holeNumber: json['holeNumber'], par: json['par'], shotsTaken: json['shotsTaken'], putts: json['putts'], penalties: json['penalties']);
}

class RoundHistory {
  final String id;
  final String date;
  final String courseName;
  final List<HoleScore> scorecard;
  final List<ShotRecord> shots;

  RoundHistory({required this.id, required this.date, required this.courseName, required this.scorecard, required this.shots});

  Map<String, dynamic> toJson() => {
    'id': id, 'date': date, 'courseName': courseName,
    'scorecard': scorecard.map((e) => e.toJson()).toList(),
    'shots': shots.map((e) => e.toJson()).toList(),
  };
  factory RoundHistory.fromJson(Map<String, dynamic> json) => RoundHistory(
    id: json['id'], date: json['date'], courseName: json['courseName'],
    scorecard: (json['scorecard'] as List).map((e) => HoleScore.fromJson(e)).toList(),
    shots: (json['shots'] as List).map((e) => ShotRecord.fromJson(e)).toList(),
  );
  int get totalScore => scorecard.fold(0, (sum, item) => sum + item.totalScore);
}

// =======================
// 2. 主程序入口
// =======================

void main() {
  runApp(const PinSeekerApp());
}

class PinSeekerApp extends StatelessWidget {
  const PinSeekerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PinSeeker V5.2',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green, brightness: Brightness.dark),
        appBarTheme: const AppBarTheme(backgroundColor: Colors.black, elevation: 0),
        textTheme: ThemeData.dark().textTheme.apply(fontFamilyFallback: ["PingFang SC", "Microsoft YaHei", "sans-serif"]),
      ),
      home: const AuthScreen(),
    );
  }
}

// =======================
// 3. 登录页面
// =======================

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final TextEditingController _nameController = TextEditingController();

  Future<void> _login() async {
    if (_nameController.text.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('current_user', _nameController.text);
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const DashboardScreen()));
  }

  @override
  void initState() {
    super.initState();
    _checkAutoLogin();
  }

  Future<void> _checkAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey('current_user')) {
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const DashboardScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(image: DecorationImage(image: NetworkImage("https://images.unsplash.com/photo-1587174486073-ae5e5cff23aa?q=80&w=1080"), fit: BoxFit.cover)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Center(
            child: Container(
              padding: const EdgeInsets.all(30),
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), borderRadius: BorderRadius.circular(20)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("PINSEEKER", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 2, color: Colors.white)),
                  const SizedBox(height: 10),
                  const Text("Professional Golf Analytics", style: TextStyle(color: Colors.greenAccent)),
                  const SizedBox(height: 30),
                  TextField(controller: _nameController, decoration: InputDecoration(filled: true, fillColor: Colors.white10, hintText: "Enter your name", border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))),
                  const SizedBox(height: 20),
                  SizedBox(width: double.infinity, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.all(15)), onPressed: _login, child: const Text("ENTER CLUBHOUSE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))))
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// =======================
// 4. 单轮复盘总览页
// =======================

class RoundSummaryScreen extends StatelessWidget {
  final RoundHistory round;
  const RoundSummaryScreen({super.key, required this.round});

  @override
  Widget build(BuildContext context) {
    int totalScore = round.totalScore;
    int totalPar = round.scorecard.fold(0, (sum, item) => sum + item.par);
    int scoreToPar = totalScore - totalPar;
    int totalPutts = round.scorecard.fold(0, (sum, item) => sum + item.putts);
    int totalPens = round.scorecard.fold(0, (sum, item) => sum + item.penalties);
    int girCount = round.scorecard.where((h) => h.isGIR).length;
    double girPercent = round.scorecard.isNotEmpty ? (girCount / round.scorecard.length) * 100 : 0;

    return Scaffold(
      appBar: AppBar(title: const Text("Round Analysis")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(round.courseName, style: const TextStyle(fontSize: 18, color: Colors.grey)),
            Text(round.date, style: const TextStyle(fontSize: 14, color: Colors.white30)),
            const SizedBox(height: 20),
            Row(children: [
              _StatCard(label: "SCORE", value: "$totalScore", subValue: scoreToPar > 0 ? "+$scoreToPar" : "$scoreToPar", color: Colors.white),
              const SizedBox(width: 10),
              _StatCard(label: "GIR %", value: "${girPercent.toInt()}%", subValue: "$girCount/${round.scorecard.length}", color: Colors.greenAccent),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              _StatCard(label: "PUTTS", value: "$totalPutts", subValue: "Avg ${(totalPutts/18).toStringAsFixed(1)}", color: Colors.orangeAccent),
              const SizedBox(width: 10),
              _StatCard(label: "PENALTIES", value: "$totalPens", subValue: "Shots lost", color: Colors.redAccent),
            ]),
            const SizedBox(height: 30),
            const Text("HOLE BY HOLE REVIEW", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1, color: Colors.grey)),
            const SizedBox(height: 10),
            ListView.builder(
              shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
              itemCount: round.scorecard.length,
              itemBuilder: (ctx, i) {
                final hole = round.scorecard[i];
                return Card(
                  color: Colors.white10, margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(backgroundColor: Colors.grey[800], child: Text("${hole.holeNumber}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                    title: Row(children: [Text("Par ${hole.par}", style: const TextStyle(color: Colors.grey)), const SizedBox(width: 10), if (hole.isGIR) Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.green[900], borderRadius: BorderRadius.circular(4)), child: const Text("GIR", style: TextStyle(fontSize: 10, color: Colors.greenAccent)))]),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [Text("${hole.putts} Putts", style: const TextStyle(fontSize: 10, color: Colors.orangeAccent)), if (hole.penalties > 0) Text("${hole.penalties} Pen", style: const TextStyle(fontSize: 10, color: Colors.redAccent))]),
                      const SizedBox(width: 15), _buildScoreBadge(hole), const SizedBox(width: 10), const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey)
                    ]),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => GolfMapScreen(replayData: round, initialHoleIndex: i))),
                  ),
                );
              },
            )
          ],
        ),
      ),
    );
  }

  Widget _buildScoreBadge(HoleScore s) {
    Color color = Colors.white; BoxDecoration? deco;
    if (s.totalScore < s.par) { deco = BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.redAccent, width: 2)); }
    else if (s.totalScore > s.par) { deco = BoxDecoration(border: Border.all(color: Colors.blueAccent, width: 2)); }
    else { color = Colors.greenAccent; }
    return Container(width: 30, height: 30, decoration: deco, alignment: Alignment.center, child: Text("${s.totalScore}", style: TextStyle(color: color, fontWeight: FontWeight.bold)));
  }
}

class _StatCard extends StatelessWidget {
  final String label; final String value; final String subValue; final Color color;
  const _StatCard({required this.label, required this.value, required this.subValue, required this.color});
  @override
  Widget build(BuildContext context) {
    return Expanded(child: Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(15)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)), const SizedBox(height: 5), Text(value, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color)), Text(subValue, style: TextStyle(fontSize: 12, color: color.withOpacity(0.7)))])));
  }
}

// =======================
// 5. 设置 & 主页
// =======================

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isYards = false;
  @override
  void initState() { super.initState(); _loadSettings(); }
  Future<void> _loadSettings() async { final prefs = await SharedPreferences.getInstance(); setState(() { _isYards = (prefs.getString('unit_system') ?? 'meters') == 'yards'; }); }
  Future<void> _toggleUnits(bool value) async { final prefs = await SharedPreferences.getInstance(); await prefs.setString('unit_system', value ? 'yards' : 'meters'); setState(() { _isYards = value; }); }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Settings")),
      body: ListView(children: [SwitchListTile(title: const Text("Measurement Unit", style: TextStyle(fontWeight: FontWeight.bold)), subtitle: Text(_isYards ? "Yards (码)" : "Meters (米)", style: const TextStyle(color: Colors.grey)), secondary: const Icon(Icons.straighten, color: Colors.greenAccent), value: _isYards, activeColor: Colors.green, onChanged: _toggleUnits)]),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _username = "";
  List<RoundHistory> _history = [];

  @override
  void initState() { super.initState(); _loadData(); }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _username = prefs.getString('current_user') ?? "Golfer";
      List<String> rawHistory = prefs.getStringList('history_$_username') ?? [];
      _history = rawHistory.map((e) => RoundHistory.fromJson(jsonDecode(e))).toList().reversed.toList();
    });
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('current_user');
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AuthScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Hi, $_username"),
        actions: [
          IconButton(icon: const Icon(Icons.settings), onPressed: () async { await Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())); setState(() {}); }),
          IconButton(icon: const Icon(Icons.logout), onPressed: _logout)
        ],
      ),
      body: Padding(padding: const EdgeInsets.all(16.0), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        InkWell(
          onTap: () async { await Navigator.push(context, MaterialPageRoute(builder: (_) => const GolfMapScreen())); _loadData(); },
          child: Container(height: 120, decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.green[900]!, Colors.green[600]!]), borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.green.withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 5))]), child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.play_circle_fill, size: 50, color: Colors.white), SizedBox(width: 20), Text("START NEW ROUND", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white))])),
        ),
        const SizedBox(height: 30),
        const Text("ROUND HISTORY", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey)),
        const SizedBox(height: 10),
        Expanded(child: _history.isEmpty ? const Center(child: Text("No rounds played yet.", style: TextStyle(color: Colors.grey))) : ListView.builder(itemCount: _history.length, itemBuilder: (ctx, i) {
          final round = _history[i];
          return Card(color: Colors.grey[900], margin: const EdgeInsets.only(bottom: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)), child: ListTile(
            contentPadding: const EdgeInsets.all(15), title: Text(round.courseName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)), subtitle: Text(round.date, style: const TextStyle(color: Colors.grey)), trailing: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(10)), child: Text("${round.totalScore}", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.greenAccent))),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RoundSummaryScreen(round: round))),
          ));
        }))
      ])),
    );
  }
}

// =======================
// 6. 游戏/复盘主界面
// =======================

class GolfMapScreen extends StatefulWidget {
  final RoundHistory? replayData;
  final int initialHoleIndex; 
  const GolfMapScreen({super.key, this.replayData, this.initialHoleIndex = 0});
  @override
  State<GolfMapScreen> createState() => _GolfMapScreenState();
}

class _GolfMapScreenState extends State<GolfMapScreen> {
  final List<GolfHole> _courseDatabase = [
    GolfHole(number: 1, par: 4, tee: const LatLng(51.253031, 6.610690), green: const LatLng(51.256435, 6.610896)),
    GolfHole(number: 2, par: 4, tee: const LatLng(51.256303, 6.611343), green: const LatLng(51.253027, 6.613838)),
    GolfHole(number: 3, par: 4, tee: const LatLng(51.253934, 6.613799), green: const LatLng(51.256955, 6.612713)),
    GolfHole(number: 4, par: 4, tee: const LatLng(51.256230, 6.613031), green: const LatLng(51.253919, 6.614703)),
    GolfHole(number: 5, par: 5, tee: const LatLng(51.253513, 6.613811), green: const LatLng(51.257468, 6.611944)),
    GolfHole(number: 6, par: 3, tee: const LatLng(51.257525, 6.611174), green: const LatLng(51.256186, 6.609659)),
    GolfHole(number: 7, par: 4, tee: const LatLng(51.256339, 6.608953), green: const LatLng(51.259878, 6.608542)),
    GolfHole(number: 8, par: 3, tee: const LatLng(51.259387, 6.608203), green: const LatLng(51.259375, 6.606481)),
    GolfHole(number: 9, par: 4, tee: const LatLng(51.259009, 6.607590), green: const LatLng(51.256032, 6.606043)),
    GolfHole(number: 10, par: 3, tee: const LatLng(51.256458, 6.606498), green: const LatLng(51.257419, 6.606892)),
    GolfHole(number: 11, par: 4, tee: const LatLng(51.256823, 6.607438), green: const LatLng(51.259129, 6.604306)),
    GolfHole(number: 12, par: 3, tee: const LatLng(51.259052, 6.603608), green: const LatLng(51.260501, 6.601357)),
    GolfHole(number: 13, par: 3, tee: const LatLng(51.260501, 6.601357), green: const LatLng(51.259186, 6.602760)),
    GolfHole(number: 14, par: 5, tee: const LatLng(51.259147, 6.601981), green: const LatLng(51.255365, 6.601745)),
    GolfHole(number: 15, par: 4, tee: const LatLng(51.255140, 6.603011), green: const LatLng(51.258660, 6.603824)),
    GolfHole(number: 16, par: 4, tee: const LatLng(51.259015, 6.603646), green: const LatLng(51.256333, 6.605922)),
    GolfHole(number: 17, par: 4, tee: const LatLng(51.255532, 6.606054), green: const LatLng(51.256139, 6.608421)),
    GolfHole(number: 18, par: 4, tee: const LatLng(51.256022, 6.608926), green: const LatLng(51.252957, 6.609506)),
  ];

  int _currentHoleIndex = 0;
  late LatLng _currentBallPos; 
  LatLng? _manualDropPos;
  final MapController _mapController = MapController();
  
  List<ShotRecord> _allShotsHistory = [];
  List<HoleScore> _scorecard = [];
  int _currentShotNum = 1;
  bool _isLoadingLoc = false;
  bool _isGettingLocation = false;
  bool _isReplayMode = false;
  bool _useYards = false; 

  double _windSpeed = 5.0; 
  double _windDirection = 180.0;
  bool _showWindPanel = false;

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
    ClubStats("Putter", 10.0, 0.0, 0.0),
  ];

  late ClubStats _selectedClub;
  double _aimAngle = 0.0; 
  double _playsLikeDistance = 0.0;

  GolfHole get _currentHole => _courseDatabase[_currentHoleIndex];

  @override
  void initState() {
    super.initState();
    _loadSettings();
    
    // 初始化球杆 (修复点：确保任何模式下都不为空)
    _selectedClub = _myBag[0];

    if (widget.replayData != null) {
      _isReplayMode = true;
      _scorecard = widget.replayData!.scorecard;
      _allShotsHistory = widget.replayData!.shots;
      // 复盘也加载第一洞或指定洞
      _loadHole(widget.initialHoleIndex);
    } else {
      _currentBallPos = _courseDatabase[0].tee;
      WidgetsBinding.instance.addPostFrameCallback((_) { _checkSavedRound(); });
    }
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _useYards = (prefs.getString('unit_system') ?? 'meters') == 'yards';
    });
  }

  String _formatDist(double meters) {
    if (_useYards) {
      int yards = (meters * 1.09361).toInt();
      return "$yards yd";
    }
    return "${meters.toInt()} m";
  }

  // --- 存档与恢复 ---
  Future<void> _checkSavedRound() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey('current_round_hole')) {
      if (!mounted) return;
      showDialog(context: context, barrierDismissible: false, builder: (ctx) => AlertDialog(
        title: const Text("发现未完成比赛"), content: const Text("是否继续上次的比赛？"),
        actions: [
          TextButton(onPressed: () { _clearSavedData(); _initNewRound(); Navigator.pop(ctx); }, child: const Text("新比赛", style: TextStyle(color: Colors.red))),
          ElevatedButton(onPressed: () { _loadSavedData(); Navigator.pop(ctx); }, child: const Text("继续")),
        ],
      ));
    } else { _initNewRound(); }
  }

  void _initNewRound() { _loadHole(0); setState(() { _scorecard.clear(); _allShotsHistory.clear(); }); }

  Future<void> _saveRoundData() async {
    if (_isReplayMode) return;
    final prefs = await SharedPreferences.getInstance();
    prefs.setInt('current_round_hole', _currentHoleIndex);
    prefs.setInt('current_shot_num', _currentShotNum);
    prefs.setString('scorecard', jsonEncode(_scorecard.map((e) => e.toJson()).toList()));
    prefs.setString('shots', jsonEncode(_allShotsHistory.map((e) => e.toJson()).toList()));
    prefs.setDouble('ball_lat', _currentBallPos.latitude);
    prefs.setDouble('ball_lng', _currentBallPos.longitude);
  }

  Future<void> _loadSavedData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentHoleIndex = prefs.getInt('current_round_hole') ?? 0;
      _currentShotNum = prefs.getInt('current_shot_num') ?? 1;
      _currentBallPos = LatLng(prefs.getDouble('ball_lat') ?? _courseDatabase[0].tee.latitude, prefs.getDouble('ball_lng') ?? _courseDatabase[0].tee.longitude);
      if (prefs.containsKey('scorecard')) {
        List<dynamic> list = jsonDecode(prefs.getString('scorecard')!);
        _scorecard = list.map((e) => HoleScore.fromJson(e)).toList();
      }
      if (prefs.containsKey('shots')) {
        List<dynamic> list = jsonDecode(prefs.getString('shots')!);
        _allShotsHistory = list.map((e) => ShotRecord.fromJson(e)).toList();
      }
      _selectedClub = _myBag[0];
      _aimAngle = 0.0;
    });
    _moveCamera();
  }

  Future<void> _clearSavedData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('current_round_hole'); await prefs.remove('current_shot_num'); await prefs.remove('scorecard'); await prefs.remove('shots'); await prefs.remove('ball_lat'); await prefs.remove('ball_lng');
  }

  Future<void> _finishAndArchiveRound() async {
    if (_isReplayMode) { Navigator.pop(context); return; }
    final prefs = await SharedPreferences.getInstance();
    String username = prefs.getString('current_user') ?? "Golfer";
    RoundHistory history = RoundHistory(id: DateTime.now().toIso8601String(), date: DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now()), courseName: "Duvenhof Golf Club", scorecard: _scorecard, shots: _allShotsHistory);
    List<String> list = prefs.getStringList('history_$username') ?? [];
    list.add(jsonEncode(history.toJson()));
    await prefs.setStringList('history_$username', list);
    await _clearSavedData();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const DashboardScreen()), (route) => false);
  }

  void _loadHole(int index) {
    setState(() {
      _currentHoleIndex = index;
      _currentBallPos = _courseDatabase[index].tee;
      
      _selectedClub = _myBag[0];
      _aimAngle = 0.0;

      if (!_isReplayMode) {
        _manualDropPos = null;
        _currentShotNum = 1;
      }
    });
    if (!_isReplayMode) _saveRoundData();
    _moveCamera();
  }

  void _moveCamera() {
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      double bearing = _calculateBearing(_currentHole.tee, _currentHole.green);
      _mapController.moveAndRotate(_currentHole.tee, 17.0, -bearing);
    });
  }

  // --- GPS ---
  Future<void> _recordLocationAsLandingPoint() async {
    setState(() => _isLoadingLoc = true);
    try {
      LocationPermission p = await Geolocator.checkPermission();
      if(p==LocationPermission.denied) p = await Geolocator.requestPermission();
      if(p==LocationPermission.denied) throw "No Permission";
      Position pos = await Geolocator.getCurrentPosition();
      LatLng gps = LatLng(pos.latitude, pos.longitude);
      
      if (_calculateDistance(gps, _currentHole.center) > 500) {
        if(!mounted) return;
        _showGPSWarningDialog(gps);
        return;
      }
      _showShotConfirmationDialog(gps, _calculateDistance(_currentBallPos, gps), isManual: false);
    } catch(e) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"))); }
    finally { if(mounted) setState(() => _isLoadingLoc = false); }
  }

  Future<void> _setStartToCurrentGPS() async {
    setState(() => _isLoadingLoc = true);
    try {
      Position position = await Geolocator.getCurrentPosition();
      LatLng gpsPos = LatLng(position.latitude, position.longitude);
      setState(() { _currentBallPos = gpsPos; _aimAngle = 0.0; _autoSelectClub(); });
      _mapController.move(gpsPos, 18.0);
      _saveRoundData();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("发球点已更新")));
    } catch (e) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"))); }
    finally { if (mounted) setState(() => _isLoadingLoc = false); }
  }

  // --- UI Dialogs ---
  void _showHoleSelector() {
    showModalBottomSheet(context: context, backgroundColor: Colors.grey[900], builder: (ctx) => GridView.builder(padding: const EdgeInsets.all(20), gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 5, mainAxisSpacing: 10, crossAxisSpacing: 10), itemCount: _courseDatabase.length, itemBuilder: (c, i) => InkWell(onTap: () { Navigator.pop(ctx); _loadHole(i); }, child: Container(decoration: BoxDecoration(color: _currentHoleIndex == i ? Colors.green : Colors.grey[800], borderRadius: BorderRadius.circular(10), border: _scorecard.any((s) => s.holeNumber == i + 1) ? Border.all(color: Colors.yellow, width: 2) : null), alignment: Alignment.center, child: Text("${i+1}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))))));
  }
  void _showGPSWarningDialog(LatLng gps) { showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text("⚠️ 定位异常"), content: const Text("距离过远 (>500m)"), actions: [TextButton(onPressed: ()=>Navigator.pop(ctx), child: const Text("取消")), ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red), onPressed: (){Navigator.pop(ctx); _showShotConfirmationDialog(gps, _calculateDistance(_currentBallPos, gps), isManual:false);}, child: const Text("强制记录"))])); }
  
  void _showShotHistoryDialog() {
    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (context, setDialogState) { var list = _allShotsHistory.where((s) => s.holeNumber == _currentHole.number).toList(); return AlertDialog(backgroundColor: Colors.grey[900], title: Text("HOLE ${_currentHole.number} 记录"), content: SizedBox(width: double.maxFinite, height: 300, child: list.isEmpty ? const Center(child: Text("暂无记录")) : ListView.builder(itemCount: list.length, itemBuilder: (c, i) { var s = list[i]; return ListTile(leading: CircleAvatar(backgroundColor: Colors.white, child: Text("${s.shotNumber}")), title: Text("${s.clubUsed} - ${_formatDist(s.distance)}"), trailing: _isReplayMode ? null : IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () { setState(() { _allShotsHistory.remove(s); if (_currentShotNum > 1) _currentShotNum--; }); setDialogState(() {}); _saveRoundData(); })); })), actions: [TextButton(onPressed: ()=>Navigator.pop(ctx), child: const Text("关闭"))]); }));
  }

  void _confirmManualDrop() { if (_manualDropPos == null) return; double dist = _calculateDistance(_currentBallPos, _manualDropPos!); _showShotConfirmationDialog(_manualDropPos!, dist, isManual: true); }
  
  void _showShotConfirmationDialog(LatLng pos, double dist, {required bool isManual}) {
    showDialog(context: context, barrierDismissible: false, builder: (ctx) { ClubStats tmp = _selectedClub; return StatefulBuilder(builder: (c, ss) => AlertDialog(backgroundColor: Colors.grey[900], title: Text(isManual?"手工落点":"GPS落点"), content: Column(mainAxisSize: MainAxisSize.min, children: [Text(_formatDist(dist), style: const TextStyle(fontSize: 30, color: Colors.greenAccent)), DropdownButton<ClubStats>(value: tmp, dropdownColor: Colors.grey[800], items: _myBag.map((e)=>DropdownMenuItem(value: e, child: Text(e.name))).toList(), onChanged: (v)=>ss(()=>tmp=v!))]), actions: [TextButton(onPressed: ()=>Navigator.pop(ctx), child: const Text("取消")), ElevatedButton(onPressed: (){ _recordShot(pos, dist, tmp); Navigator.pop(ctx); }, child: const Text("确认"))])); });
  }

  void _recordShot(LatLng pos, double dist, ClubStats club) {
    setState(() {
      _allShotsHistory.add(ShotRecord(_currentHole.number, _currentShotNum, _currentBallPos, pos, club.name, dist));
      _currentBallPos = pos; _manualDropPos = null; _currentShotNum++; _aimAngle = 0.0; _autoSelectClub(); _mapController.move(pos, 18.0);
    });
    _saveRoundData();
  }

  void _finishHoleDialog() {
    if (_isReplayMode) return;
    int putts = 2; int penalties = 0;
    var exist = _scorecard.firstWhere((s)=>s.holeNumber==_currentHole.number, orElse: ()=>HoleScore(holeNumber:0, par:0, shotsTaken:0, putts:2, penalties:0));
    if(exist.holeNumber!=0) { putts=exist.putts; penalties=exist.penalties; }
    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (c, ss) => AlertDialog(backgroundColor: Colors.grey[900], title: Text("Hole ${_currentHole.number} 结算"), content: Column(mainAxisSize: MainAxisSize.min, children: [
      Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[const Text("Putts"), Row(children:[IconButton(icon:const Icon(Icons.remove),onPressed:()=>ss(()=>putts>0?putts--:0)), Text("$putts"), IconButton(icon:const Icon(Icons.add),onPressed:()=>ss(()=>putts++))])]),
      Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[const Text("Penalties"), Row(children:[IconButton(icon:const Icon(Icons.remove),onPressed:()=>ss(()=>penalties>0?penalties--:0)), Text("$penalties"), IconButton(icon:const Icon(Icons.add),onPressed:()=>ss(()=>penalties++))])]),
    ]), actions: [
      TextButton(onPressed: (){Navigator.pop(ctx); _showShotHistoryDialog();}, child: const Text("修改击球", style:TextStyle(color:Colors.orange))),
      ElevatedButton(onPressed: (){ _saveHoleScore(putts, penalties); Navigator.pop(ctx); }, child: const Text("保存并下一洞"))
    ])));
  }

  void _saveHoleScore(int putts, int penalties) {
    int shots = _currentShotNum > 0 ? _currentShotNum - 1 : 0;
    setState(() {
      _scorecard.removeWhere((s) => s.holeNumber == _currentHole.number);
      _scorecard.add(HoleScore(holeNumber: _currentHole.number, par: _currentHole.par, shotsTaken: shots, putts: putts, penalties: penalties));
      if (_currentHoleIndex < _courseDatabase.length - 1) { _loadHole(_currentHoleIndex + 1); } else { _showFullScorecard(); }
    });
    _saveRoundData();
  }

  void _showFullScorecard() {
    showDialog(context: context, builder: (ctx) => Scaffold(backgroundColor: Colors.transparent, body: Container(width: double.infinity, height: double.infinity, color: Colors.black87, padding: const EdgeInsets.all(20), child: Column(children: [
      const SizedBox(height: 40),
      const Text("SCORECARD", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
      const SizedBox(height: 20),
      Expanded(child: SingleChildScrollView(child: Table(border: TableBorder.all(color: Colors.grey), columnWidths: const {0:FlexColumnWidth(0.8),5:FlexColumnWidth(1.2)}, children: [
        const TableRow(children: [Text("Hole"), Text("Par"), Text("Shot"), Text("Putt"), Text("Pen"), Text("Net")]),
        ..._scorecard.map((s) => TableRow(children: [
          Text("${s.holeNumber}", textAlign: TextAlign.center), Text("${s.par}", textAlign: TextAlign.center), Text("${s.shotsTaken}", textAlign: TextAlign.center),
          Text("${s.putts}", textAlign: TextAlign.center), Text("${s.penalties}", textAlign: TextAlign.center),
          Container(alignment: Alignment.center, decoration: BoxDecoration(shape: BoxShape.circle, color: s.totalScore < s.par ? Colors.red : (s.totalScore > s.par ? Colors.blue : Colors.transparent)), child: Text("${s.totalScore}", style: const TextStyle(fontWeight: FontWeight.bold)))
        ]))
      ]))),
      if(!_isReplayMode) SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _finishAndArchiveRound, child: const Text("FINISH ROUND")))
      else ElevatedButton(onPressed: ()=>Navigator.pop(ctx), child: const Text("CLOSE"))
    ]))));
  }

  // --- 算法 ---
  double _calculateBearing(LatLng s, LatLng e) { final dLon = vector.radians(e.longitude - s.longitude); final y = math.sin(dLon) * math.cos(vector.radians(e.latitude)); final x = math.cos(vector.radians(s.latitude)) * math.sin(vector.radians(e.latitude)) - math.sin(vector.radians(s.latitude)) * math.cos(vector.radians(e.latitude)) * math.cos(dLon); return (vector.degrees(math.atan2(y, x)) + 360) % 360; }
  double _calculateDistance(LatLng p1, LatLng p2) => const Distance().as(LengthUnit.Meter, p1, p2);
  LatLng _calculateDestination(LatLng s, double dist, double bear) { const R = 6378137.0; final radLat = vector.radians(s.latitude); final radLon = vector.radians(s.longitude); final radBear = vector.radians(bear); final angDist = dist / R; final endLat = math.asin(math.sin(radLat) * math.cos(angDist) + math.cos(radLat) * math.sin(angDist) * math.cos(radBear)); final endLon = radLon + math.atan2(math.sin(radBear) * math.sin(angDist) * math.cos(radLat), math.cos(angDist) - math.sin(radLat) * math.sin(endLat)); return LatLng(vector.degrees(endLat), vector.degrees(endLon)); }
  List<LatLng> _calculateEllipsePoints(LatLng center, double width, double height, double rotation) { final points = <LatLng>[]; final radRot = vector.radians(rotation); for(int i=0; i<=36; i++){ final t = (i/36)*2*math.pi; final dx = (width/2)*math.cos(t); final dy = (height/2)*math.sin(t); final rx = dx*math.cos(radRot)-dy*math.sin(radRot); final ry = dx*math.sin(radRot)+dy*math.cos(radRot); final dLat = ry/6378137.0; final dLon = rx/(6378137.0*math.cos(vector.radians(center.latitude))); points.add(LatLng(center.latitude+vector.degrees(dLat), center.longitude+vector.degrees(dLon))); } return points; }
  void _autoSelectClub() { double d = _calculateDistance(_currentBallPos, _currentHole.green); try{ _selectedClub = _myBag.lastWhere((c)=>c.carry >= d-5); } catch(e){_selectedClub = _myBag[0];} if(d<50) _selectedClub = _myBag.last; }
  void _onMapTap(TapPosition pos, LatLng pt) { if(_isReplayMode) return; double b = _calculateBearing(_currentBallPos, pt); double holeB = _calculateBearing(_currentBallPos, _currentHole.green); double diff = b - holeB; if(diff>180) diff-=360; if(diff<-180) diff+=360; setState((){ _aimAngle = diff; }); }
  LatLng _calculateWindAdjustedLandingZone(LatLng s, double d, double b) { double relWind = (_windDirection - b + 180) % 360; double rad = vector.radians(relWind); double head = _windSpeed * math.cos(rad); double cross = _windSpeed * math.sin(rad); double newD = d - (head * 0.01 * d); double shift = vector.degrees(math.atan2(cross * 0.005 * d, newD)); _playsLikeDistance = newD; return _calculateDestination(s, newD, b + shift); }
  void _showClubEditor() { showModalBottomSheet(context: context, backgroundColor: Colors.grey[900], isScrollControlled: true, builder: (ctx) { return StatefulBuilder(builder: (context, setModalState) { return Padding(padding: const EdgeInsets.all(20.0), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [Text("EDIT: ${_selectedClub.name}", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)), const SizedBox(height: 20), Text("Carry: ${_formatDist(_selectedClub.carry)}"), Slider(value: _selectedClub.carry, min: 50, max: 300, divisions: 50, activeColor: Colors.green, onChanged: (val) { setModalState(() => _selectedClub.carry = val); setState(() {}); }), Text("Spread: ${_formatDist(_selectedClub.sideError)}"), Slider(value: _selectedClub.sideError, min: 0, max: 100, divisions: 100, activeColor: Colors.blue, onChanged: (val) { setModalState(() => _selectedClub.sideError = val); setState(() {}); }), ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text("DONE"))])); }); }); }

  @override
  Widget build(BuildContext context) {
    // 修复变量名：bearing -> holeBearing
    double holeBearing = _calculateBearing(_currentBallPos, _currentHole.green);
    double shotBearing = holeBearing + _aimAngle;
    LatLng landing = _calculateWindAdjustedLandingZone(_currentBallPos, _selectedClub.carry, shotBearing);
    List<LatLng> ellipse = _calculateEllipsePoints(landing, _selectedClub.sideError, _selectedClub.depthError, 90 - shotBearing);
    double distToGreen = _calculateDistance(_currentBallPos, _currentHole.green);

    // 获取当前洞的历史轨迹（用于复盘）
    var holeHistory = _allShotsHistory.where((s) => s.holeNumber == _currentHole.number).toList();

    return Scaffold(
      appBar: AppBar(
        title: InkWell(
          onTap: _isReplayMode ? null : _showHoleSelector,
          child: Row(mainAxisSize: MainAxisSize.min, children: [Text("HOLE ${_currentHole.number}", style: const TextStyle(fontWeight: FontWeight.bold)), if (!_isReplayMode) const Icon(Icons.arrow_drop_down)]),
        ),
        leading: _isReplayMode ? const BackButton() : IconButton(icon: const Icon(Icons.list_alt), onPressed: _showFullScorecard),
        actions: [
          if(!_isReplayMode) IconButton(icon: const Icon(Icons.home), onPressed: () { _saveRoundData(); Navigator.pop(context); }),
          if(!_isReplayMode) IconButton(icon: const Icon(Icons.history, color:Colors.orangeAccent), onPressed: _showShotHistoryDialog),
          IconButton(icon: Icon(Icons.air, color: _showWindPanel ? Colors.blue : Colors.grey), onPressed: () => setState(() => _showWindPanel = !_showWindPanel)),
          if(!_isReplayMode) IconButton(icon: const Icon(Icons.flag_circle, color:Colors.greenAccent), onPressed: _finishHoleDialog),
        ],
      ),
      body: Stack(children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _currentHole.tee, initialZoom: 17.5, initialRotation: -holeBearing,
            onTap: _onMapTap,
            onLongPress: _isReplayMode ? null : (t, p) => setState(() => _manualDropPos = p),
          ),
          children: [
            TileLayer(urlTemplate: 'https://mt1.google.com/vt/lyrs=y&x={x}&y={y}&z={z}'),
            
            // 轨迹层：复盘时显示所有历史轨迹
            PolylineLayer(polylines: holeHistory.map((s) => Polyline(points: [s.from, s.to], color: _isReplayMode ? Colors.cyanAccent : Colors.white, strokeWidth: 3.0)).toList()),
            
            // 标记层：复盘时显示落点详细信息 (亮色标签)
            MarkerLayer(markers: [
              Marker(point: _currentHole.green, child: const Icon(Icons.flag, color: Colors.red, size: 30)),
              
              if (_isReplayMode)
                ...holeHistory.map((s) => Marker(
                  point: s.to,
                  width: 100, height: 40,
                  child: Column(children: [
                    const Icon(Icons.location_on, color: Colors.cyanAccent, size: 20),
                    Container(padding: const EdgeInsets.all(2), decoration: BoxDecoration(color: Colors.black.withOpacity(0.7), borderRadius: BorderRadius.circular(4)), child: Text("${s.clubUsed}\n${_formatDist(s.distance)}", style: const TextStyle(color: Colors.yellowAccent, fontSize: 10), textAlign: TextAlign.center))
                  ]),
                )),

              if (!_isReplayMode) ...[
                Marker(point: _currentBallPos, child: Container(decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: Colors.black)), width: 16, height: 16)),
                Marker(point: landing, child: const Icon(Icons.gps_fixed, color: Colors.yellow, size: 20)),
                if (_manualDropPos != null) Marker(point: _manualDropPos!, child: const Icon(Icons.location_on, color: Colors.purpleAccent, size: 40), alignment: Alignment.topCenter)
              ]
            ]),

            if (!_isReplayMode) ...[
              PolylineLayer(polylines: [
                Polyline(points: [_currentBallPos, landing], color: Colors.blueAccent, strokeWidth: 1.5), 
                Polyline(points: [landing, _currentHole.green], color: Colors.yellowAccent, strokeWidth: 1.5)
              ]),
              PolygonLayer(polygons: [Polygon(points: ellipse, color: Colors.blue.withOpacity(0.3), borderColor: Colors.blue, borderStrokeWidth: 1)]),
            ]
          ],
        ),
        
        if (_showWindPanel) Positioned(top: 10, right: 10, child: Card(color: Colors.black87, child: Padding(padding: const EdgeInsets.all(8), child: Column(children: [Text("Wind: ${_windSpeed.toInt()}"), Slider(value: _windSpeed, min: 0, max: 20, onChanged: (v) => setState(() => _windSpeed = v)), Text("Dir: ${_windDirection.toInt()}"), Slider(value: _windDirection, min: 0, max: 360, divisions: 8, onChanged: (v) => setState(() => _windDirection = v))])))),

        if (!_isReplayMode) Positioned(bottom: 20, left: 10, right: 10, child: Card(color: Colors.black87, child: Column(children: [
          ListTile(
            title: Text("To Pin: ${_formatDist(distToGreen)}"),
            trailing: DropdownButton<ClubStats>(value: _selectedClub, dropdownColor: Colors.grey[800], items: _myBag.map((c) => DropdownMenuItem(value: c, child: Text(c.name))).toList(), onChanged: (v) => setState(() => _selectedClub = v!)),
          ),
          Row(children: [const Text("Aim"), Expanded(child: Slider(value: _aimAngle.clamp(-90.0, 90.0), min: -90.0, max: 90.0, onChanged: (v) => setState(() => _aimAngle = v)))]),
          if (_manualDropPos != null) ElevatedButton(onPressed: () => _recordShot(_manualDropPos!, _calculateDistance(_currentBallPos, _manualDropPos!), _selectedClub), child: const Text("确认手工落点"))
          else ElevatedButton.icon(icon: _isLoadingLoc ? const SizedBox(width:10,height:10,child:CircularProgressIndicator()) : const Icon(Icons.near_me), onPressed: _isLoadingLoc ? null : _recordLocationAsLandingPoint, label: const Text("记录落点 (GPS)"))
        ])))
      ]),
    );
  }
}