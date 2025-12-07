import 'package:latlong2/latlong.dart';

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
