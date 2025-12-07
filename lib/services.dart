import 'dart:convert';
import 'dart:math' as math;
import 'package:latlong2/latlong.dart';
import 'package:vector_math/vector_math.dart' as vector;
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';

class CourseRepository {
  static final List<GolfHole> duvenhofHoles = [
    GolfHole(number: 1, par: 4, tee: LatLng(51.253031, 6.610690), green: LatLng(51.256435, 6.610896)),
    GolfHole(number: 2, par: 4, tee: LatLng(51.256303, 6.611343), green: LatLng(51.253027, 6.613838)),
    GolfHole(number: 3, par: 4, tee: LatLng(51.253934, 6.613799), green: LatLng(51.256955, 6.612713)),
    GolfHole(number: 4, par: 4, tee: LatLng(51.256230, 6.613031), green: LatLng(51.253919, 6.614703)),
    GolfHole(number: 5, par: 5, tee: LatLng(51.253513, 6.613811), green: LatLng(51.257468, 6.611944)),
    GolfHole(number: 6, par: 3, tee: LatLng(51.257525, 6.611174), green: LatLng(51.256186, 6.609659)),
    GolfHole(number: 7, par: 4, tee: LatLng(51.256339, 6.608953), green: LatLng(51.259878, 6.608542)),
    GolfHole(number: 8, par: 3, tee: LatLng(51.259387, 6.608203), green: LatLng(51.259375, 6.606481)),
    GolfHole(number: 9, par: 4, tee: LatLng(51.259009, 6.607590), green: LatLng(51.256032, 6.606043)),
    GolfHole(number: 10, par: 3, tee: LatLng(51.256458, 6.606498), green: LatLng(51.257419, 6.606892)),
    GolfHole(number: 11, par: 4, tee: LatLng(51.256823, 6.607438), green: LatLng(51.259129, 6.604306)),
    GolfHole(number: 12, par: 3, tee: LatLng(51.259052, 6.603608), green: LatLng(51.260501, 6.601357)),
    GolfHole(number: 13, par: 3, tee: LatLng(51.260501, 6.601357), green: LatLng(51.259186, 6.602760)),
    GolfHole(number: 14, par: 5, tee: LatLng(51.259147, 6.601981), green: LatLng(51.255365, 6.601745)),
    GolfHole(number: 15, par: 4, tee: LatLng(51.255140, 6.603011), green: LatLng(51.258660, 6.603824)),
    GolfHole(number: 16, par: 4, tee: LatLng(51.259015, 6.603646), green: LatLng(51.256333, 6.605922)),
    GolfHole(number: 17, par: 4, tee: LatLng(51.255532, 6.606054), green: LatLng(51.256139, 6.608421)),
    GolfHole(number: 18, par: 4, tee: LatLng(51.256022, 6.608926), green: LatLng(51.252957, 6.609506)),
  ];

  static List<ClubStats> getDefaultBag() {
    return [
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
  }
}

class GolfMath {
  static const Distance _distance = Distance();
  
  static double dist(LatLng p1, LatLng p2) => _distance.as(LengthUnit.Meter, p1, p2);

  static double bearing(LatLng start, LatLng end) {
    final lat1 = vector.radians(start.latitude);
    final lat2 = vector.radians(end.latitude);
    final dLon = vector.radians(end.longitude - start.longitude);
    final y = math.sin(dLon) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) - math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
    return (vector.degrees(math.atan2(y, x)) + 360) % 360;
  }

  static LatLng destination(LatLng start, double distanceMeters, double bearingDegrees) {
    const double earthRadius = 6378137.0;
    final double radLat = vector.radians(start.latitude);
    final double radLon = vector.radians(start.longitude);
    final double radBearing = vector.radians(bearingDegrees);
    final double angularDist = distanceMeters / earthRadius;
    final double endLat = math.asin(math.sin(radLat) * math.cos(angularDist) + math.cos(radLat) * math.sin(angularDist) * math.cos(radBearing));
    final double endLon = radLon + math.atan2(math.sin(radBearing) * math.sin(angularDist) * math.cos(radLat), math.cos(angularDist) - math.sin(radLat) * math.sin(endLat));
    return LatLng(vector.degrees(endLat), vector.degrees(endLon));
  }

  static LatLng calculateWindShot(LatLng start, double baseDistance, double bearing, double windSpeed, double windDir) {
    double relativeWindAngle = (windDir - bearing + 180) % 360;
    double windRad = vector.radians(relativeWindAngle);
    double headWindComp = windSpeed * math.cos(windRad);
    double crossWindComp = windSpeed * math.sin(windRad);
    double distEffect = headWindComp * 0.01 * baseDistance; 
    double sideEffect = crossWindComp * 0.005 * baseDistance;
    double newDistance = baseDistance - distEffect;
    double bearingShift = vector.degrees(math.atan2(sideEffect, newDistance));
    return destination(start, newDistance, bearing + bearingShift);
  }

  static List<LatLng> getEllipsePoints(LatLng center, double width, double height, double rotation) {
    final List<LatLng> points = [];
    final double rotationRad = vector.radians(rotation);
    for (int i = 0; i <= 36; i++) {
      final double theta = (i / 36) * 2 * math.pi;
      final double dx = (width / 2) * math.cos(theta);
      final double dy = (height / 2) * math.sin(theta);
      final double rx = dx * math.cos(rotationRad) - dy * math.sin(rotationRad);
      final double ry = dx * math.sin(rotationRad) + dy * math.cos(rotationRad);
      final double dLat = ry / 6378137.0;
      final double dLon = rx / (6378137.0 * math.cos(vector.radians(center.latitude)));
      points.add(LatLng(center.latitude + vector.degrees(dLat), center.longitude + vector.degrees(dLon)));
    }
    return points;
  }
}

class StorageService {
  static Future<void> saveRound(String username, RoundHistory history) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> list = prefs.getStringList('history_$username') ?? [];
    list.add(jsonEncode(history.toJson()));
    await prefs.setStringList('history_$username', list);
  }

  static Future<List<RoundHistory>> loadHistory(String username) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> list = prefs.getStringList('history_$username') ?? [];
    return list.map((e) => RoundHistory.fromJson(jsonDecode(e))).toList().reversed.toList();
  }
  
  static Future<void> saveTempState(int holeIdx, int shotNum, List<HoleScore> card, List<ShotRecord> shots, LatLng ball) async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setInt('temp_hole', holeIdx);
    prefs.setInt('temp_shot', shotNum);
    prefs.setString('temp_card', jsonEncode(card.map((e) => e.toJson()).toList()));
    prefs.setString('temp_shots', jsonEncode(shots.map((e) => e.toJson()).toList()));
    prefs.setDouble('temp_lat', ball.latitude);
    prefs.setDouble('temp_lng', ball.longitude);
  }
  
  static Future<void> clearTempState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('temp_hole');
    await prefs.remove('temp_shot');
    await prefs.remove('temp_card');
    await prefs.remove('temp_shots');
    await prefs.remove('temp_lat');
    await prefs.remove('temp_lng');
  }
}
