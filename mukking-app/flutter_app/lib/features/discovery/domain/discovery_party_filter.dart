import '../../matching/domain/matching_party.dart';

enum PartyDateFilter {
  all,
  today,
  tomorrow;

  String get label => switch (this) {
        PartyDateFilter.all => '전체',
        PartyDateFilter.today => '오늘',
        PartyDateFilter.tomorrow => '내일',
      };
}

enum PartyTimeSlot {
  all,
  morning,
  lunch,
  evening,
  night;

  String get label => switch (this) {
        PartyTimeSlot.all => '전체',
        PartyTimeSlot.morning => '아침',
        PartyTimeSlot.lunch => '점심',
        PartyTimeSlot.evening => '저녁',
        PartyTimeSlot.night => '밤',
      };
}

class DiscoveryPartyFilterState {
  const DiscoveryPartyFilterState({
    this.date = PartyDateFilter.all,
    this.timeSlot = PartyTimeSlot.all,
    this.availableSeatsOnly = false,
    this.recruitingOnly = false,
  });

  final PartyDateFilter date;
  final PartyTimeSlot timeSlot;
  final bool availableSeatsOnly;
  final bool recruitingOnly;

  bool get isActive => activeCount > 0;

  int get activeCount =>
      (date == PartyDateFilter.all ? 0 : 1) +
      (timeSlot == PartyTimeSlot.all ? 0 : 1) +
      (availableSeatsOnly ? 1 : 0) +
      (recruitingOnly ? 1 : 0);

  DiscoveryPartyFilterState copyWith({
    PartyDateFilter? date,
    PartyTimeSlot? timeSlot,
    bool? availableSeatsOnly,
    bool? recruitingOnly,
  }) {
    return DiscoveryPartyFilterState(
      date: date ?? this.date,
      timeSlot: timeSlot ?? this.timeSlot,
      availableSeatsOnly: availableSeatsOnly ?? this.availableSeatsOnly,
      recruitingOnly: recruitingOnly ?? this.recruitingOnly,
    );
  }
}

List<MatchingParty> filterDiscoveryParties(
  List<MatchingParty> parties,
  DiscoveryPartyFilterState filter, {
  DateTime? now,
}) {
  final localNow = (now ?? DateTime.now()).toLocal();
  final today = DateTime(localNow.year, localNow.month, localNow.day);

  return parties.where((party) {
    if (!hasLinkedRestaurant(party)) return false;
    final scheduledAt = party.scheduledAt.toLocal();
    if (!_matchesDate(scheduledAt, today, filter.date)) return false;
    if (!_matchesTimeSlot(scheduledAt.hour, filter.timeSlot)) return false;
    if (filter.availableSeatsOnly && !hasAvailablePartySeat(party)) {
      return false;
    }
    if (filter.recruitingOnly && !isRecruitingParty(party)) return false;
    return true;
  }).toList(growable: false);
}

bool hasLinkedRestaurant(MatchingParty party) {
  final restaurantId = party.restaurantId.trim();
  return restaurantId.isNotEmpty &&
      !restaurantId.startsWith('legacy-restaurant-');
}

bool hasAvailablePartySeat(MatchingParty party) {
  return party.currentMembers < party.maxMembers;
}

bool isRecruitingParty(MatchingParty party) {
  return switch (party.status) {
    MatchingPartyStatus.open ||
    MatchingPartyStatus.hot ||
    MatchingPartyStatus.urgent =>
      true,
    MatchingPartyStatus.full => false,
  };
}

bool _matchesDate(
  DateTime scheduledAt,
  DateTime today,
  PartyDateFilter filter,
) {
  if (filter == PartyDateFilter.all) return true;
  final scheduledDate =
      DateTime(scheduledAt.year, scheduledAt.month, scheduledAt.day);
  final target = filter == PartyDateFilter.today
      ? today
      : today.add(const Duration(days: 1));
  return scheduledDate == target;
}

bool _matchesTimeSlot(int hour, PartyTimeSlot filter) {
  return switch (filter) {
    PartyTimeSlot.all => true,
    PartyTimeSlot.morning => hour >= 5 && hour < 11,
    PartyTimeSlot.lunch => hour >= 11 && hour < 15,
    PartyTimeSlot.evening => hour >= 15 && hour < 21,
    PartyTimeSlot.night => hour >= 21 || hour < 5,
  };
}
