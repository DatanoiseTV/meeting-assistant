import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../entities/meeting.dart';

class MeetingRepository {
  static const String _meetingsKey = 'meetings';

  Future<List<Meeting>> getAllMeetings() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_meetingsKey);
    if (jsonString == null) return [];

    final List<dynamic> jsonList = jsonDecode(jsonString);
    return jsonList.map((e) => Meeting.fromJson(e)).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<Meeting?> getMeeting(String id) async {
    final meetings = await getAllMeetings();
    try {
      return meetings.firstWhere((m) => m.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveMeeting(Meeting meeting) async {
    final meetings = await getAllMeetings();
    final existingIndex = meetings.indexWhere((m) => m.id == meeting.id);

    if (existingIndex >= 0) {
      meetings[existingIndex] = meeting;
    } else {
      meetings.add(meeting);
    }

    await _saveMeetings(meetings);
  }

  Future<void> updateMeeting(Meeting meeting) async {
    final meetings = await getAllMeetings();
    final index = meetings.indexWhere((m) => m.id == meeting.id);

    if (index >= 0) {
      meetings[index] = meeting;
      await _saveMeetings(meetings);
    }
  }

  Future<void> deleteMeeting(String id) async {
    final meetings = await getAllMeetings();
    meetings.removeWhere((m) => m.id == id);
    await _saveMeetings(meetings);
  }

  Future<void> _saveMeetings(List<Meeting> meetings) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = meetings.map((e) => e.toJson()).toList();
    await prefs.setString(_meetingsKey, jsonEncode(jsonList));
  }
}
