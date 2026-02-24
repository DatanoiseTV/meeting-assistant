import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/meeting.dart';
import '../../domain/repositories/meeting_repository.dart';

final meetingRepositoryProvider = Provider<MeetingRepository>((ref) {
  return MeetingRepository();
});

final meetingsProvider = StateNotifierProvider<MeetingsNotifier, List<Meeting>>(
  (ref) {
    final repository = ref.watch(meetingRepositoryProvider);
    return MeetingsNotifier(repository);
  },
);

class MeetingsNotifier extends StateNotifier<List<Meeting>> {
  final MeetingRepository _repository;

  MeetingsNotifier(this._repository) : super([]) {
    loadMeetings();
  }

  Future<void> loadMeetings() async {
    state = await _repository.getAllMeetings();
  }

  Future<void> addMeeting(Meeting meeting) async {
    await _repository.saveMeeting(meeting);
    await loadMeetings();
  }

  Future<void> updateMeeting(Meeting meeting) async {
    await _repository.updateMeeting(meeting);
    await loadMeetings();
  }

  Future<void> deleteMeeting(String id) async {
    await _repository.deleteMeeting(id);
    await loadMeetings();
  }
}
