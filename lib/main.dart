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

  Map<String, dynamic> toJson() => {
        'name': name,
        'carry': carry,
        'sideError': sideError,
        'depthError': depthError,
      };
  factory ClubStats.fromJson(Map<String, dynamic> json) => ClubStats(
        json['name'],
        json['carry'],
        json['sideError'],
        json['depthError'],
      );
}

class GolfHole {
  final int number;
  final int par;
  final LatLng tee;
  final LatLng green;
  GolfHole({
    required this.number,
    required this.par,
    required this.tee,
    required this.green,
  });
  LatLng get center => LatLng(
        (tee.latitude + green.latitude) / 2,
        (tee.longitude + green.longitude) / 2,
      );
}

class ShotRecord {
  final int holeNumber;
  final int shotNumber;
  final LatLng from;
  final LatLng to;
  final String clubUsed;
  final double distance;

  ShotRecord(
    this.holeNumber,
    this.shotNumber,
    this.from,
    this.to,
    this.clubUsed,
    this.distance,
  );

  Map<String, dynamic> toJson() => {
        'holeNumber': holeNumber,
        'shotNumber': shotNumber,
        'fromLat': from.latitude,
        'fromLng': from.longitude,
        'toLat': to.latitude,
        'toLng': to.longitude,
        'clubUsed': clubUsed,
        'distance': distance,
      };
  factory ShotRecord.fromJson(Map<String, dynamic> json) => ShotRecord(
        json['holeNumber'],
        json['shotNumber'],
        LatLng(json['fromLat'], json['fromLng']),
        LatLng(json['toLat'], json['toLng']),
        json['clubUsed'],
        json['distance'],
      );
}

class HoleScore {
  final int holeNumber;
  final int par;
  final int shotsTaken;
  final int putts;
  final int penalties;
  int get totalScore => shotsTaken + putts + penalties;

  HoleScore({
    required this.holeNumber,
    required this.par,
    required this.shotsTaken,
    required this.putts,
    required this.penalties,
  });

  Map<String, dynamic> toJson() => {
        'holeNumber': holeNumber,
        'par': par,
        'shotsTaken': shotsTaken,
        'putts': putts,
        'penalties': penalties,
      };
  factory HoleScore.fromJson(Map<String, dynamic> json) => HoleScore(
        holeNumber: json['holeNumber'],
        par: json['par'],
        shotsTaken: json['shotsTaken'],
        putts: json['putts'],
        penalties: json['penalties'],
      );
}

class RoundHistory {
  final String id;
  final String date;
  final String courseName;
  final List<HoleScore> scorecard;
  final List<ShotRecord> shots;

  RoundHistory({
    required this.id,
    required this.date,
    required this.courseName,
    required this.scorecard,
    required this.shots,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date,
        'courseName': courseName,
        'scorecard': scorecard.map((e) => e.toJson()).toList(),
        'shots': shots.map((e) => e.toJson()).toList(),
      };
  factory RoundHistory.fromJson(Map<String, dynamic> json) => RoundHistory(
        id: json['id'],
        date: json['date'],
        courseName: json['courseName'],
        scorecard: (json['scorecard'] as List)
            .map((e) => HoleScore.fromJson(e))
            .toList(),
        shots:
            (json['shots'] as List).map((e) => ShotRecord.fromJson(e)).toList(),
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
      title: 'PinSeeker V4.3',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
        colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.green, brightness: Brightness.dark),
        appBarTheme:
            const AppBarTheme(backgroundColor: Colors.black, elevation: 0),
        // [核心修复] 添加字体回退列表，强制支持中文和 Emoji
        textTheme: ThemeData.dark().textTheme.apply(
          fontFamilyFallback: [
            "PingFang SC", // iOS/Mac 中文
            "Heiti SC", // 旧版 Mac 中文
            "Microsoft YaHei", // Windows 中文
            "sans-serif", // 通用兜底
            "Apple Color Emoji", // iOS Emoji
            "Segoe UI Emoji", // Windows Emoji
            "Segoe UI Symbol",
          ],
        ),
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
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const DashboardScreen()),
    );
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
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: NetworkImage(
              "https://images.unsplash.com/photo-1587174486073-ae5e5cff23aa?q=80&w=1080",
            ),
            fit: BoxFit.cover,
          ),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Center(
            child: Container(
              padding: const EdgeInsets.all(30),
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "PINSEEKER",
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "Professional Golf Analytics",
                    style: TextStyle(color: Colors.greenAccent),
                  ),
                  const SizedBox(height: 30),
                  TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white10,
                      hintText: "Enter your name",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.all(15),
                      ),
                      onPressed: _login,
                      child: const Text(
                        "ENTER CLUBHOUSE",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
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

// =======================
// 4. 设置页面
// =======================

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isYards = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isYards = (prefs.getString('unit_system') ?? 'meters') == 'yards';
    });
  }

  Future<void> _toggleUnits(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('unit_system', value ? 'yards' : 'meters');
    setState(() {
      _isYards = value;
    });
  }

  void _showUserManual() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.grey[900],
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "📘 使用指南",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const Divider(color: Colors.white24),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    _HelpItem(
                      icon: Icons.play_circle_fill,
                      title: "开始比赛",
                      desc: "点击 Dashboard 的绿色按钮开始。如果上次未打完，系统会提示继续。",
                    ),
                    _HelpItem(
                      icon: Icons.my_location,
                      title: "开球修正",
                      desc: "在第一杆发球时，如果不在默认发球台，点击底部 '🎯 从当前GPS开球' 修正位置。",
                    ),
                    _HelpItem(
                      icon: Icons.near_me,
                      title: "GPS 记录落点",
                      desc: "打完球走到球边，点击红色 '📍 记录落点' 按钮。系统会通过 GPS 计算距离并绘制轨迹。",
                    ),
                    _HelpItem(
                      icon: Icons.touch_app,
                      title: "手工落点 (GPS不准时)",
                      desc: "如果 GPS 信号弱，长按地图上你的真实位置，会出现紫色标记，然后点击确认。",
                    ),
                    _HelpItem(
                      icon: Icons.edit,
                      title: "球杆调校",
                      desc: "点击底部球杆旁的 ✏️ 图标，可以自定义每支杆的击球距离和散布范围。",
                    ),
                    _HelpItem(
                      icon: Icons.air,
                      title: "风速调整",
                      desc: "点击顶部风扇图标，设置风向风速。App 会自动计算受风影响后的 'Plays Like' 距离。",
                    ),
                    _HelpItem(
                      icon: Icons.flag_circle,
                      title: "记分与GIR",
                      desc: "打完一洞后点击右上角旗帜，输入推杆数。系统自动计算总分和是否 GIR (标准杆上果岭)。",
                    ),
                    _HelpItem(
                      icon: Icons.history,
                      title: "复盘模式",
                      desc: "在主页点击历史记录卡片，可重现该场比赛的每一杆轨迹。",
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Settings")),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text(
              "Measurement Unit",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              _isYards ? "Yards (码)" : "Meters (米)",
              style: const TextStyle(color: Colors.grey),
            ),
            secondary: const Icon(Icons.straighten, color: Colors.greenAccent),
            value: _isYards,
            activeThumbColor: Colors.green,
            onChanged: _toggleUnits,
          ),
          const Divider(color: Colors.white10),
          ListTile(
            leading: const Icon(Icons.menu_book, color: Colors.blueAccent),
            title: const Text(
              "User Manual",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: const Text("How to use PinSeeker"),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: _showUserManual,
          ),
        ],
      ),
    );
  }
}

class _HelpItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String desc;
  const _HelpItem({
    required this.icon,
    required this.title,
    required this.desc,
  });
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.greenAccent, size: 28),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  desc,
                  style: const TextStyle(color: Colors.white70, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =======================
// 5. 主页 (Dashboard)
// =======================

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _username = "";
  List<RoundHistory> _history = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _username = prefs.getString('current_user') ?? "Golfer";
      List<String> rawHistory = prefs.getStringList('history_$_username') ?? [];
      _history = rawHistory
          .map((e) => RoundHistory.fromJson(jsonDecode(e)))
          .toList()
          .reversed
          .toList();
    });
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('current_user');
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const AuthScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Hi, $_username"),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
              setState(() {}); // 刷新可能更改的设置
            },
          ),
          IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const GolfMapScreen()),
                );
                _loadData();
              },
              child: Container(
                height: 120,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.green[900]!, Colors.green[600]!],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.withOpacity(0.4),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.play_circle_fill, size: 50, color: Colors.white),
                    SizedBox(width: 20),
                    Text(
                      "START NEW ROUND",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 30),
            const Text(
              "ROUND HISTORY",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: _history.isEmpty
                  ? const Center(
                      child: Text(
                        "No rounds played yet.",
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _history.length,
                      itemBuilder: (ctx, i) {
                        final round = _history[i];
                        return Card(
                          color: Colors.grey[900],
                          margin: const EdgeInsets.only(bottom: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(15),
                            title: Text(
                              round.courseName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: Colors.white,
                              ),
                            ),
                            subtitle: Text(
                              round.date,
                              style: const TextStyle(color: Colors.grey),
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white10,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                "${round.totalScore}",
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.greenAccent,
                                ),
                              ),
                            ),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    GolfMapScreen(replayData: round),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// =======================
// 6. 游戏/复盘主界面
// =======================

class GolfMapScreen extends StatefulWidget {
  final RoundHistory? replayData;
  const GolfMapScreen({super.key, this.replayData});
  @override
  State<GolfMapScreen> createState() => _GolfMapScreenState();
}

class _GolfMapScreenState extends State<GolfMapScreen> {
  // 18洞数据
  final List<GolfHole> _courseDatabase = [
    GolfHole(
      number: 1,
      par: 4,
      tee: const LatLng(51.253031, 6.610690),
      green: const LatLng(51.256435, 6.610896),
    ),
    GolfHole(
      number: 2,
      par: 4,
      tee: const LatLng(51.256303, 6.611343),
      green: const LatLng(51.253027, 6.613838),
    ),
    GolfHole(
      number: 3,
      par: 4,
      tee: const LatLng(51.253934, 6.613799),
      green: const LatLng(51.256955, 6.612713),
    ),
    GolfHole(
      number: 4,
      par: 4,
      tee: const LatLng(51.256230, 6.613031),
      green: const LatLng(51.253919, 6.614703),
    ),
    GolfHole(
      number: 5,
      par: 5,
      tee: const LatLng(51.253513, 6.613811),
      green: const LatLng(51.257468, 6.611944),
    ),
    GolfHole(
      number: 6,
      par: 3,
      tee: const LatLng(51.257525, 6.611174),
      green: const LatLng(51.256186, 6.609659),
    ),
    GolfHole(
      number: 7,
      par: 4,
      tee: const LatLng(51.256339, 6.608953),
      green: const LatLng(51.259878, 6.608542),
    ),
    GolfHole(
      number: 8,
      par: 3,
      tee: const LatLng(51.259387, 6.608203),
      green: const LatLng(51.259375, 6.606481),
    ),
    GolfHole(
      number: 9,
      par: 4,
      tee: const LatLng(51.259009, 6.607590),
      green: const LatLng(51.256032, 6.606043),
    ),
    GolfHole(
      number: 10,
      par: 3,
      tee: const LatLng(51.256458, 6.606498),
      green: const LatLng(51.257419, 6.606892),
    ),
    GolfHole(
      number: 11,
      par: 4,
      tee: const LatLng(51.256823, 6.607438),
      green: const LatLng(51.259129, 6.604306),
    ),
    GolfHole(
      number: 12,
      par: 3,
      tee: const LatLng(51.259052, 6.603608),
      green: const LatLng(51.260501, 6.601357),
    ),
    GolfHole(
      number: 13,
      par: 3,
      tee: const LatLng(51.260501, 6.601357),
      green: const LatLng(51.259186, 6.602760),
    ),
    GolfHole(
      number: 14,
      par: 5,
      tee: const LatLng(51.259147, 6.601981),
      green: const LatLng(51.255365, 6.601745),
    ),
    GolfHole(
      number: 15,
      par: 4,
      tee: const LatLng(51.255140, 6.603011),
      green: const LatLng(51.258660, 6.603824),
    ),
    GolfHole(
      number: 16,
      par: 4,
      tee: const LatLng(51.259015, 6.603646),
      green: const LatLng(51.256333, 6.605922),
    ),
    GolfHole(
      number: 17,
      par: 4,
      tee: const LatLng(51.255532, 6.606054),
      green: const LatLng(51.256139, 6.608421),
    ),
    GolfHole(
      number: 18,
      par: 4,
      tee: const LatLng(51.256022, 6.608926),
      green: const LatLng(51.252957, 6.609506),
    ),
  ];

  int _currentHoleIndex = 0;
  late LatLng _currentBallPos;
  LatLng? _manualDropPos;
  final MapController _mapController = MapController();

  List<ShotRecord> _allShotsHistory = [];
  List<HoleScore> _scorecard = [];
  int _currentShotNum = 1;
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

    if (widget.replayData != null) {
      _isReplayMode = true;
      _scorecard = widget.replayData!.scorecard;
      _allShotsHistory = widget.replayData!.shots;
      _loadHole(0);
    } else {
      _currentBallPos = _courseDatabase[0].tee;
      _selectedClub = _myBag[0];
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkSavedRound();
      });
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
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text("发现未完成比赛"),
          content: const Text("是否继续上次的比赛？"),
          actions: [
            TextButton(
              onPressed: () {
                _clearSavedData();
                _initNewRound();
                Navigator.pop(ctx);
              },
              child: const Text("新比赛", style: TextStyle(color: Colors.red)),
            ),
            ElevatedButton(
              onPressed: () {
                _loadSavedData();
                Navigator.pop(ctx);
              },
              child: const Text("继续"),
            ),
          ],
        ),
      );
    } else {
      _initNewRound();
    }
  }

  void _initNewRound() {
    _loadHole(0);
    setState(() {
      _scorecard.clear();
      _allShotsHistory.clear();
    });
  }

  Future<void> _saveRoundData() async {
    if (_isReplayMode) return;
    final prefs = await SharedPreferences.getInstance();
    prefs.setInt('current_round_hole', _currentHoleIndex);
    prefs.setInt('current_shot_num', _currentShotNum);
    prefs.setString(
      'scorecard',
      jsonEncode(_scorecard.map((e) => e.toJson()).toList()),
    );
    prefs.setString(
      'shots',
      jsonEncode(_allShotsHistory.map((e) => e.toJson()).toList()),
    );
    prefs.setDouble('ball_lat', _currentBallPos.latitude);
    prefs.setDouble('ball_lng', _currentBallPos.longitude);
  }

  Future<void> _loadSavedData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentHoleIndex = prefs.getInt('current_round_hole') ?? 0;
      _currentShotNum = prefs.getInt('current_shot_num') ?? 1;
      _currentBallPos = LatLng(
        prefs.getDouble('ball_lat') ?? _courseDatabase[0].tee.latitude,
        prefs.getDouble('ball_lng') ?? _courseDatabase[0].tee.longitude,
      );
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
    await prefs.remove('current_round_hole');
    await prefs.remove('current_shot_num');
    await prefs.remove('scorecard');
    await prefs.remove('shots');
    await prefs.remove('ball_lat');
    await prefs.remove('ball_lng');
  }

  Future<void> _finishAndArchiveRound() async {
    if (_isReplayMode) {
      Navigator.pop(context);
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    String username = prefs.getString('current_user') ?? "Golfer";
    RoundHistory history = RoundHistory(
      id: DateTime.now().toIso8601String(),
      date: DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now()),
      courseName: "Duvenhof Golf Club",
      scorecard: _scorecard,
      shots: _allShotsHistory,
    );
    List<String> historyList = prefs.getStringList('history_$username') ?? [];
    historyList.add(jsonEncode(history.toJson()));
    await prefs.setStringList('history_$username', historyList);
    await _clearSavedData();
    if (!mounted) return;
    Navigator.pop(context);
  }

  void _loadHole(int index) {
    setState(() {
      _currentHoleIndex = index;
      if (!_isReplayMode) {
        _currentBallPos = _courseDatabase[index].tee;
        _manualDropPos = null;
        _currentShotNum = 1;
        _selectedClub = _myBag[0];
        _aimAngle = 0.0;
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
    setState(() => _isGettingLocation = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) throw "No Permission";
      }
      Position position = await Geolocator.getCurrentPosition();
      LatLng gpsPos = LatLng(position.latitude, position.longitude);
      double distFromHoleCenter = _calculateDistance(
        gpsPos,
        _currentHole.center,
      );
      if (distFromHoleCenter > 500) {
        if (!mounted) return;
        _showGPSWarningDialog(gpsPos);
        return;
      }
      double dist = _calculateDistance(_currentBallPos, gpsPos);
      if (!mounted) return;
      _showShotConfirmationDialog(gpsPos, dist, isManual: false);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("GPS Error: $e")));
    } finally {
      if (mounted) setState(() => _isGettingLocation = false);
    }
  }

  Future<void> _setStartToCurrentGPS() async {
    setState(() => _isGettingLocation = true);
    try {
      Position position = await Geolocator.getCurrentPosition();
      LatLng gpsPos = LatLng(position.latitude, position.longitude);
      setState(() {
        _currentBallPos = gpsPos;
        _aimAngle = 0.0;
        _autoSelectClub();
      });
      _mapController.move(gpsPos, 18.0);
      _saveRoundData();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("发球点已更新")));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isGettingLocation = false);
    }
  }

  // --- UI Dialogs ---
  void _showHoleSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      builder: (ctx) => GridView.builder(
        padding: const EdgeInsets.all(20),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 5,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
        ),
        itemCount: _courseDatabase.length,
        itemBuilder: (c, i) => InkWell(
          onTap: () {
            Navigator.pop(ctx);
            _loadHole(i);
          },
          child: Container(
            decoration: BoxDecoration(
              color: _currentHoleIndex == i ? Colors.green : Colors.grey[800],
              borderRadius: BorderRadius.circular(10),
              border: _scorecard.any((s) => s.holeNumber == i + 1)
                  ? Border.all(color: Colors.yellow, width: 2)
                  : null,
            ),
            alignment: Alignment.center,
            child: Text(
              "${i + 1}",
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showGPSWarningDialog(LatLng gpsPos) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("⚠️ 定位异常", style: TextStyle(color: Colors.redAccent)),
        content: const Text("距离球洞过远 (>500m)"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("取消"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(ctx);
              double dist = _calculateDistance(_currentBallPos, gpsPos);
              _showShotConfirmationDialog(gpsPos, dist, isManual: false);
            },
            child: const Text("强制记录"),
          ),
        ],
      ),
    );
  }

  void _showShotHistoryDialog() {
    if (_isReplayMode) return;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          var currentHoleShots = _allShotsHistory
              .where((s) => s.holeNumber == _currentHole.number)
              .toList();
          return AlertDialog(
            backgroundColor: Colors.grey[900],
            title: Text("HOLE ${_currentHole.number} 记录"),
            content: SizedBox(
              width: double.maxFinite,
              height: 300,
              child: currentHoleShots.isEmpty
                  ? const Center(child: Text("暂无记录"))
                  : ListView.builder(
                      itemCount: currentHoleShots.length,
                      itemBuilder: (c, i) {
                        var shot = currentHoleShots[i];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.white,
                            child: Text("${shot.shotNumber}"),
                          ),
                          title: Text(
                            "${shot.clubUsed} - ${_formatDist(shot.distance)}",
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () {
                              setState(() {
                                _allShotsHistory.remove(shot);
                                if (_currentShotNum > 1) _currentShotNum--;
                              });
                              setDialogState(() {});
                              _saveRoundData();
                            },
                          ),
                        );
                      },
                    ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("关闭"),
              ),
            ],
          );
        },
      ),
    );
  }

  void _confirmManualDrop() {
    if (_manualDropPos == null) return;
    double dist = _calculateDistance(_currentBallPos, _manualDropPos!);
    _showShotConfirmationDialog(_manualDropPos!, dist, isManual: true);
  }

  void _showShotConfirmationDialog(
    LatLng landingPos,
    double distance, {
    required bool isManual,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        ClubStats tempClub = _selectedClub;
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: Colors.grey[900],
              title: Text(
                isManual ? "手工落点" : "GPS 落点",
                style: const TextStyle(color: Colors.white),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _formatDist(distance),
                    style: const TextStyle(
                      fontSize: 30,
                      color: Colors.greenAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text("确认球杆:", style: TextStyle(color: Colors.grey)),
                  DropdownButton<ClubStats>(
                    value: tempClub,
                    dropdownColor: Colors.grey[800],
                    style: const TextStyle(color: Colors.white, fontSize: 18),
                    items: _myBag
                        .map(
                          (c) =>
                              DropdownMenuItem(value: c, child: Text(c.name)),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => tempClub = v!),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text("取消"),
                ),
                ElevatedButton(
                  onPressed: () {
                    _recordShot(landingPos, distance, tempClub);
                    Navigator.pop(ctx);
                  },
                  child: const Text("确认"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _recordShot(LatLng landingPos, double distance, ClubStats club) {
    setState(() {
      _allShotsHistory.add(
        ShotRecord(
          _currentHole.number,
          _currentShotNum,
          _currentBallPos,
          landingPos,
          club.name,
          distance,
        ),
      );
      _currentBallPos = landingPos;
      _manualDropPos = null;
      _currentShotNum++;
      _aimAngle = 0.0;
      _autoSelectClub();
      _mapController.move(landingPos, 18.0);
    });
    _saveRoundData();
  }

  void _finishHoleDialog() {
    if (_isReplayMode) return;
    int putts = 2;
    int penalties = 0;
    var existingScore = _scorecard.firstWhere(
      (s) => s.holeNumber == _currentHole.number,
      orElse: () => HoleScore(
        holeNumber: 0,
        par: 0,
        shotsTaken: 0,
        putts: 2,
        penalties: 0,
      ),
    );
    if (existingScore.holeNumber != 0) {
      putts = existingScore.putts;
      penalties = existingScore.penalties;
    }
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.grey[900],
              title: Text("HOLE ${_currentHole.number} 结算"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildCounterRow(
                    "推杆 (Putts)",
                    putts,
                    (val) => setDialogState(() => putts = val),
                  ),
                  const SizedBox(height: 10),
                  _buildCounterRow(
                    "罚杆 (Penalties)",
                    penalties,
                    (val) => setDialogState(() => penalties = val),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _showShotHistoryDialog();
                  },
                  child: const Text(
                    "修改击球",
                    style: TextStyle(color: Colors.orange),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    _saveHoleScore(putts, penalties);
                    Navigator.pop(ctx);
                  },
                  child: const Text("保存并下一洞"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildCounterRow(String label, int value, Function(int) onChanged) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.white)),
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
              onPressed: () => value > 0 ? onChanged(value - 1) : null,
            ),
            Text(
              "$value",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline, color: Colors.green),
              onPressed: () => onChanged(value + 1),
            ),
          ],
        ),
      ],
    );
  }

  void _saveHoleScore(int putts, int penalties) {
    int shots = _currentShotNum > 0 ? _currentShotNum - 1 : 0;
    setState(() {
      _scorecard.removeWhere((s) => s.holeNumber == _currentHole.number);
      _scorecard.add(
        HoleScore(
          holeNumber: _currentHole.number,
          par: _currentHole.par,
          shotsTaken: shots,
          putts: putts,
          penalties: penalties,
        ),
      );
      if (_currentHoleIndex < _courseDatabase.length - 1) {
        _loadHole(_currentHoleIndex + 1);
      } else {
        _showFullScorecard();
      }
    });
    _saveRoundData();
  }

  void _showFullScorecard() {
    showDialog(
      context: context,
      builder: (ctx) {
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: NetworkImage(
                  "https://images.unsplash.com/photo-1593111774240-d529f12db4bb?q=80&w=1080",
                ),
                fit: BoxFit.cover,
              ),
            ),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                color: Colors.black.withOpacity(0.5),
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const SizedBox(height: 40),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "SCORECARD",
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                            color: Colors.white,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Table(
                          border: TableBorder(
                            horizontalInside: BorderSide(
                              color: Colors.white.withOpacity(0.2),
                            ),
                          ),
                          columnWidths: const {
                            0: FlexColumnWidth(0.8),
                            1: FlexColumnWidth(0.8),
                            2: FlexColumnWidth(1),
                            3: FlexColumnWidth(1),
                            4: FlexColumnWidth(1),
                            5: FlexColumnWidth(1.2),
                          },
                          defaultVerticalAlignment:
                              TableCellVerticalAlignment.middle,
                          children: [
                            const TableRow(
                              children: [
                                Text(
                                  "HOLE",
                                  style: TextStyle(color: Colors.grey),
                                ),
                                Text(
                                  "PAR",
                                  style: TextStyle(color: Colors.grey),
                                ),
                                Text(
                                  "SHOT",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.grey),
                                ),
                                Text(
                                  "PUTT",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.grey),
                                ),
                                Text(
                                  "PEN",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.grey),
                                ),
                                Text(
                                  "NET",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                            ..._scorecard.map(
                              (s) => TableRow(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    child: Text(
                                      "${s.holeNumber}",
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    "${s.par}",
                                    style: const TextStyle(
                                      color: Colors.white70,
                                    ),
                                  ),
                                  Text(
                                    "${s.shotsTaken}",
                                    textAlign: TextAlign.center,
                                  ),
                                  Text(
                                    "${s.putts}",
                                    textAlign: TextAlign.center,
                                  ),
                                  Text(
                                    "${s.penalties}",
                                    textAlign: TextAlign.center,
                                  ),
                                  _buildScoreCell(s),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (!_isReplayMode)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            padding: const EdgeInsets.all(15),
                          ),
                          onPressed: _finishAndArchiveRound,
                          child: const Text(
                            "FINISH ROUND & ARCHIVE",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildScoreCell(HoleScore s) {
    int score = s.totalScore;
    int par = s.par;
    Color bg = Colors.transparent;
    Color text = Colors.white;
    if (score < par) {
      bg = Colors.amber;
      text = Colors.black;
    } else if (score > par) {
      bg = Colors.white24;
    } else {
      text = Colors.greenAccent;
    }
    return Container(
      margin: const EdgeInsets.all(4),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(
        "$score",
        style: TextStyle(color: text, fontWeight: FontWeight.bold),
      ),
    );
  }

  // --- 算法 ---
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
    LatLng start,
    double distanceMeters,
    double bearingDegrees,
  ) {
    const double earthRadius = 6378137.0;
    final double radLat = vector.radians(start.latitude);
    final double radLon = vector.radians(start.longitude);
    final double radBearing = vector.radians(bearingDegrees);
    final double angularDist = distanceMeters / earthRadius;
    final double endLat = math.asin(
      math.sin(radLat) * math.cos(angularDist) +
          math.cos(radLat) * math.sin(angularDist) * math.cos(radBearing),
    );
    final double endLon = radLon +
        math.atan2(
          math.sin(radBearing) * math.sin(angularDist) * math.cos(radLat),
          math.cos(angularDist) - math.sin(radLat) * math.sin(endLat),
        );
    return LatLng(vector.degrees(endLat), vector.degrees(endLon));
  }

  List<LatLng> _calculateEllipsePoints(
    LatLng center,
    double width,
    double height,
    double rotation,
  ) {
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
      points.add(
        LatLng(
          center.latitude + vector.degrees(dLat),
          center.longitude + vector.degrees(dLon),
        ),
      );
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
    if (_isReplayMode) return;
    double tapBearing = _calculateBearing(_currentBallPos, point);
    double holeBearing = _calculateBearing(_currentBallPos, _currentHole.green);
    double diff = tapBearing - holeBearing;
    if (diff > 180) diff -= 360;
    if (diff < -180) diff += 360;
    setState(() {
      _aimAngle = diff;
    });
  }

  LatLng _calculateWindAdjustedLandingZone(
    LatLng start,
    double baseDistance,
    double bearingDegrees,
  ) {
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
      start,
      newDistance,
      bearingDegrees + bearingShift,
    );
  }

  void _showClubEditor() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "EDIT: ${_selectedClub.name}",
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text("Carry: ${_formatDist(_selectedClub.carry)}"),
                  Slider(
                    value: _selectedClub.carry,
                    min: 50,
                    max: 300,
                    divisions: 50,
                    activeColor: Colors.green,
                    onChanged: (val) {
                      setModalState(() => _selectedClub.carry = val);
                      setState(() {});
                    },
                  ),
                  Text("Spread: ${_formatDist(_selectedClub.sideError)}"),
                  Slider(
                    value: _selectedClub.sideError,
                    min: 0,
                    max: 100,
                    divisions: 100,
                    activeColor: Colors.blue,
                    onChanged: (val) {
                      setModalState(() => _selectedClub.sideError = val);
                      setState(() {});
                    },
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text("DONE"),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    double holeBearing = _calculateBearing(_currentBallPos, _currentHole.green);
    double currentShotBearing = holeBearing + _aimAngle;
    LatLng plannedPos = _calculateWindAdjustedLandingZone(
      _currentBallPos,
      _selectedClub.carry,
      currentShotBearing,
    );
    List<LatLng> ellipsePoints = _calculateEllipsePoints(
      plannedPos,
      _selectedClub.sideError,
      _selectedClub.depthError,
      90 - currentShotBearing,
    );
    double distanceToGreen = _calculateDistance(
      _currentBallPos,
      _currentHole.green,
    );

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: InkWell(
          onTap: _isReplayMode ? null : _showHoleSelector,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "HOLE ${_currentHole.number}",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              if (!_isReplayMode) const Icon(Icons.arrow_drop_down),
            ],
          ),
        ),
        leading: _isReplayMode
            ? const BackButton()
            : IconButton(
                icon: const Icon(Icons.list_alt),
                onPressed: _showFullScorecard,
              ),
        actions: [
          if (!_isReplayMode)
            IconButton(
              icon: const Icon(Icons.home, color: Colors.white),
              onPressed: () {
                _saveRoundData();
                Navigator.pop(context);
              },
            ),
          if (!_isReplayMode)
            IconButton(
              icon: const Icon(Icons.history, color: Colors.orangeAccent),
              onPressed: _showShotHistoryDialog,
            ),
          IconButton(
            icon: Icon(
              Icons.air,
              color: _showWindPanel ? Colors.blue : Colors.grey,
            ),
            onPressed: () => setState(() => _showWindPanel = !_showWindPanel),
          ),
          if (!_isReplayMode)
            IconButton(
              icon: const Icon(Icons.flag_circle, color: Colors.greenAccent),
              onPressed: _finishHoleDialog,
            ),
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
              onLongPress: _isReplayMode
                  ? null
                  : (tapPos, point) {
                      setState(() {
                        _manualDropPos = point;
                      });
                    },
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://mt1.google.com/vt/lyrs=y&x={x}&y={y}&z={z}',
              ),
              PolylineLayer(
                polylines: _allShotsHistory
                    .where((s) => s.holeNumber == _currentHole.number)
                    .map(
                      (s) => Polyline(
                        points: [s.from, s.to],
                        color: Colors.white,
                        strokeWidth: 3.0,
                      ),
                    )
                    .toList(),
              ),
              MarkerLayer(
                markers: _allShotsHistory
                    .where((s) => s.holeNumber == _currentHole.number)
                    .map(
                      (s) => Marker(
                        point: s.to,
                        child: const Icon(
                          Icons.circle,
                          color: Colors.white,
                          size: 8,
                        ),
                      ),
                    )
                    .toList(),
              ),
              if (!_isReplayMode) ...[
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: [_currentBallPos, plannedPos],
                      strokeWidth: 1.5,
                      color: Colors.blueAccent,
                    ),
                    Polyline(
                      points: [plannedPos, _currentHole.green],
                      strokeWidth: 1.5,
                      color: Colors.yellowAccent,
                      isDotted: true,
                    ),
                  ],
                ),
                PolygonLayer(
                  polygons: [
                    Polygon(
                      points: ellipsePoints,
                      color: Colors.blueAccent.withOpacity(0.3),
                      borderColor: Colors.blue,
                      isFilled: true,
                    ),
                  ],
                ),
              ],
              MarkerLayer(
                markers: [
                  Marker(
                    point: _currentHole.green,
                    child: const Icon(Icons.flag, color: Colors.red, size: 30),
                  ),
                  if (!_isReplayMode)
                    Marker(
                      point: _currentBallPos,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.black, width: 2),
                        ),
                        width: 16,
                        height: 16,
                      ),
                    ),
                  if (!_isReplayMode)
                    Marker(
                      point: plannedPos,
                      child: const Icon(
                        Icons.gps_fixed,
                        color: Colors.yellow,
                        size: 20,
                      ),
                    ),
                  if (_manualDropPos != null)
                    Marker(
                      point: _manualDropPos!,
                      child: const Icon(
                        Icons.location_on,
                        color: Colors.purpleAccent,
                        size: 40,
                      ),
                      alignment: Alignment.topCenter,
                    ),
                ],
              ),
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
                  child: Column(
                    children: [
                      Text(
                        "Wind: ${_windSpeed.toInt()} m/s",
                        style: const TextStyle(color: Colors.blueAccent),
                      ),
                      SizedBox(
                        height: 100,
                        child: RotatedBox(
                          quarterTurns: 3,
                          child: Slider(
                            value: _windSpeed,
                            min: 0,
                            max: 20,
                            onChanged: (v) => setState(() => _windSpeed = v),
                          ),
                        ),
                      ),
                      Text("Dir: ${_windDirection.toInt()}°"),
                      SizedBox(
                        width: 100,
                        child: Slider(
                          value: _windDirection,
                          min: 0,
                          max: 360,
                          divisions: 8,
                          onChanged: (v) => setState(() => _windDirection = v),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (!_isReplayMode)
            Positioned(
              bottom: 20,
              left: 10,
              right: 10,
              child: Column(
                children: [
                  if (_manualDropPos != null)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purpleAccent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: _confirmManualDrop,
                        icon: const Icon(Icons.touch_app),
                        label: const Text("🖐️ 确认手工落点"),
                      ),
                    )
                  else if (_currentShotNum == 1)
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blueGrey,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            onPressed: _isGettingLocation
                                ? null
                                : _setStartToCurrentGPS,
                            icon: _isGettingLocation
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.my_location),
                            label: const Text("从当前GPS开球"),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            onPressed: _isGettingLocation
                                ? null
                                : _recordLocationAsLandingPoint,
                            icon: const Icon(Icons.near_me),
                            label: const Text("📍 记录落点"),
                          ),
                        ),
                      ],
                    )
                  else
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: _isGettingLocation
                            ? null
                            : _recordLocationAsLandingPoint,
                        icon: _isGettingLocation
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.near_me),
                        label: Text(
                          _isGettingLocation ? "GPS 定位中..." : "📍 到达落点 (GPS记录)",
                        ),
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
                                  Text(
                                    "To Pin: ${_formatDist(distanceToGreen)}",
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    "Plays Like: ${_formatDist(_playsLikeDistance)}",
                                    style: const TextStyle(
                                      color: Colors.blue,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  DropdownButton<ClubStats>(
                                    value: _selectedClub,
                                    dropdownColor: Colors.grey[800],
                                    style: const TextStyle(
                                      color: Colors.greenAccent,
                                    ),
                                    underline: Container(),
                                    items: _myBag
                                        .map(
                                          (c) => DropdownMenuItem(
                                            value: c,
                                            child: Text(c.name),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (v) =>
                                        setState(() => _selectedClub = v!),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.edit,
                                      size: 16,
                                      color: Colors.grey,
                                    ),
                                    onPressed: _showClubEditor,
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              const Text(
                                "Aim",
                                style: TextStyle(color: Colors.grey),
                              ),
                              Expanded(
                                child: Slider(
                                  value: _aimAngle.clamp(-90.0, 90.0),
                                  min: -90.0,
                                  max: 90.0,
                                  activeColor: Colors.blue,
                                  onChanged: (v) =>
                                      setState(() => _aimAngle = v),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
