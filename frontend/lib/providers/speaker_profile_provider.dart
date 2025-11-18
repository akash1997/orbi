import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/speaker_profile_service.dart';

final speakerProfileServiceProvider = Provider<SpeakerProfileService>((ref) {
  throw UnimplementedError('SpeakerProfileService must be overridden in main()');
});

final speakerProfilesProvider = FutureProvider<List<SpeakerProfile>>((ref) async {
  final service = ref.watch(speakerProfileServiceProvider);
  return await service.getAllProfiles();
});
