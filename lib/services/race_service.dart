import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pacelifter/models/race.dart';

/// 레이스 일정 데이터를 관리하는 서비스
class RaceService {
  static const _racesKey = 'races_list';

  /// 모든 레이스 목록을 불러옵니다.
  Future<List<Race>> getRaces() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_racesKey);
    if (jsonString != null) {
      final List<dynamic> jsonList = jsonDecode(jsonString);
      return jsonList.map((json) => Race.fromJson(json)).toList();
    }
    return [];
  }

  /// 레이스 목록 전체를 저장합니다.
  Future<void> _saveRaces(List<Race> races) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = races.map((race) => race.toJson()).toList();
    await prefs.setString(_racesKey, jsonEncode(jsonList));
  }

  /// 새로운 레이스를 추가합니다.
  Future<void> addRace(Race race) async {
    final races = await getRaces();
    races.add(race);
    await _saveRaces(races);
  }

  /// 기존 레이스를 수정합니다.
  Future<void> updateRace(Race updatedRace) async {
    final races = await getRaces();
    final index = races.indexWhere((race) => race.id == updatedRace.id);
    if (index != -1) {
      races[index] = updatedRace;
      await _saveRaces(races);
    }
  }

  /// 레이스를 삭제합니다.
  Future<void> deleteRace(String raceId) async {
    final races = await getRaces();
    races.removeWhere((race) => race.id == raceId);
    await _saveRaces(races);
  }
}
