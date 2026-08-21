import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/profile_repository.dart';
import '../domain/profile_summary.dart';

final profileSummaryProvider = FutureProvider<ProfileSummary>((ref) {
  return ref.watch(profileRepositoryProvider).currentProfile();
});
