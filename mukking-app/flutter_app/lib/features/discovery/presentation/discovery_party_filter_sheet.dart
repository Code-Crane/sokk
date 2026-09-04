import 'package:flutter/material.dart';

import '../domain/discovery_party_filter.dart';

const discoveryPartyFilterSheetKey = Key('discovery-party-filter-sheet');
const applyPartyFiltersKey = Key('apply-party-filters');
const resetPartyFilterDraftKey = Key('reset-party-filter-draft');
const availableSeatsPartyFilterKey = Key('available-seats-party-filter');
const recruitingPartyFilterKey = Key('recruiting-party-filter');

Key partyDateFilterKey(PartyDateFilter value) =>
    ValueKey('party-date-${value.name}');

Key partyTimeSlotFilterKey(PartyTimeSlot value) =>
    ValueKey('party-time-${value.name}');

Future<DiscoveryPartyFilterState?> showDiscoveryPartyFilterSheet(
  BuildContext context, {
  required DiscoveryPartyFilterState initialFilter,
}) {
  return showModalBottomSheet<DiscoveryPartyFilterState>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _DiscoveryPartyFilterSheet(initialFilter: initialFilter),
  );
}

class _DiscoveryPartyFilterSheet extends StatefulWidget {
  const _DiscoveryPartyFilterSheet({required this.initialFilter});

  final DiscoveryPartyFilterState initialFilter;

  @override
  State<_DiscoveryPartyFilterSheet> createState() =>
      _DiscoveryPartyFilterSheetState();
}

class _DiscoveryPartyFilterSheetState
    extends State<_DiscoveryPartyFilterSheet> {
  late DiscoveryPartyFilterState _draft;

  @override
  void initState() {
    super.initState();
    _draft = widget.initialFilter;
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Material(
      key: discoveryPartyFilterSheetKey,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('모임 조건', style: textTheme.titleLarge),
            const SizedBox(height: 18),
            Text('날짜', style: textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final date in PartyDateFilter.values)
                  ChoiceChip(
                    key: partyDateFilterKey(date),
                    label: Text(date.label),
                    selected: _draft.date == date,
                    onSelected: (_) {
                      setState(() => _draft = _draft.copyWith(date: date));
                    },
                  ),
              ],
            ),
            const SizedBox(height: 18),
            Text('시간대', style: textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final timeSlot in PartyTimeSlot.values)
                  ChoiceChip(
                    key: partyTimeSlotFilterKey(timeSlot),
                    label: Text(timeSlot.label),
                    selected: _draft.timeSlot == timeSlot,
                    onSelected: (_) {
                      setState(
                        () => _draft = _draft.copyWith(timeSlot: timeSlot),
                      );
                    },
                  ),
              ],
            ),
            const SizedBox(height: 14),
            SwitchListTile.adaptive(
              key: availableSeatsPartyFilterKey,
              contentPadding: EdgeInsets.zero,
              value: _draft.availableSeatsOnly,
              title: const Text('남은 자리 있음'),
              onChanged: (value) {
                setState(
                  () => _draft = _draft.copyWith(availableSeatsOnly: value),
                );
              },
            ),
            SwitchListTile.adaptive(
              key: recruitingPartyFilterKey,
              contentPadding: EdgeInsets.zero,
              value: _draft.recruitingOnly,
              title: const Text('모집 중인 파티만'),
              onChanged: (value) {
                setState(
                  () => _draft = _draft.copyWith(recruitingOnly: value),
                );
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    key: resetPartyFilterDraftKey,
                    onPressed: () {
                      setState(
                        () => _draft = const DiscoveryPartyFilterState(),
                      );
                    },
                    child: const Text('초기화'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    key: applyPartyFiltersKey,
                    onPressed: () => Navigator.of(context).pop(_draft),
                    child: const Text('적용'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
