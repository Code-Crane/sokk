import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_error.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/brand_assets.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../discovery/presentation/discovery_visuals.dart';
import '../../discovery/domain/restaurant.dart';
import '../../discovery/providers/discovery_provider.dart';
import '../../notifications/providers/notification_provider.dart';
import '../data/matching_repository.dart';
import '../providers/matching_provider.dart';

class CreatePartyScreen extends ConsumerStatefulWidget {
  const CreatePartyScreen({
    this.restaurantId,
    super.key,
  });

  final String? restaurantId;

  @override
  ConsumerState<CreatePartyScreen> createState() => _CreatePartyScreenState();
}

class _CreatePartyScreenState extends ConsumerState<CreatePartyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _restaurantNameController = TextEditingController();
  final _addressController = TextEditingController();

  late DateTime _scheduledAt;
  int _maxParticipants = 4;
  bool _prefillApplied = false;
  String? _scheduleError;

  @override
  void initState() {
    super.initState();
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    _scheduledAt = DateTime(
      tomorrow.year,
      tomorrow.month,
      tomorrow.day,
      19,
      30,
    );
    _prefillApplied = widget.restaurantId == null;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _restaurantNameController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => DiscoveryTheme(
        child: Builder(builder: (context) => _buildForm(context)),
      );

  Widget _buildForm(BuildContext context) {
    final tokens = context.tokens;
    final restaurantState = widget.restaurantId == null
        ? null
        : ref.watch(restaurantDetailProvider(widget.restaurantId!));
    final restaurant = restaurantState?.valueOrNull;
    final createState = ref.watch(createPartyControllerProvider);
    _applyRestaurantPrefill(restaurant);

    return ColoredBox(
      color: MukkingBrand.background,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            key: const Key('create-party-scroll'),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
            children: [
              Text('모임 만들기',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontSize: 24, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              const Text('어디서, 언제 함께 먹을까요?'),
              const SizedBox(height: 20),
              if (restaurant != null)
                _RestaurantSummary(restaurant: restaurant)
              else if (restaurantState?.isLoading ?? false)
                const DiscoverySurface(
                  child: Row(children: [
                    SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2)),
                    SizedBox(width: 12),
                    Expanded(child: Text('선택한 식당을 불러오고 있어요.')),
                  ]),
                )
              else
                DiscoverySurface(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          restaurantState?.hasError == true
                              ? '식당 정보를 불러오지 못했어요.'
                              : '함께 먹을 식당을 정해주세요.',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 6),
                      const Text('모임 찾기에서 선택하거나 아래에 직접 입력할 수 있어요.'),
                      Wrap(spacing: 8, children: [
                        TextButton.icon(
                          onPressed: () => context.go(AppRoutes.discovery),
                          icon: const Icon(Icons.explore_outlined, size: 18),
                          label: const Text('식당 찾기'),
                        ),
                        if (restaurantState?.hasError == true)
                          TextButton(
                            onPressed: () => ref.invalidate(
                                restaurantDetailProvider(widget.restaurantId!)),
                            child: const Text('다시 시도'),
                          ),
                      ]),
                    ],
                  ),
                ),
              const SizedBox(height: 20),
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Keep the existing validators/controllers for preset data.
                    Offstage(
                      offstage: restaurant != null &&
                          _restaurantNameController.text.trim().isNotEmpty &&
                          _addressController.text.trim().isNotEmpty,
                      child: Column(children: [
                        TextFormField(
                          key: const Key('create-restaurant-name'),
                          controller: _restaurantNameController,
                          readOnly: restaurant != null,
                          decoration: const InputDecoration(
                              labelText: '식당명', errorMaxLines: 3),
                          validator: _requiredValidator('식당명을 입력해주세요.'),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          key: const Key('create-address'),
                          controller: _addressController,
                          readOnly: restaurant != null,
                          minLines: 1,
                          maxLines: 3,
                          decoration: const InputDecoration(
                              labelText: '주소', errorMaxLines: 3),
                          validator: _requiredValidator('주소를 입력해주세요.'),
                        ),
                        const SizedBox(height: 20),
                      ]),
                    ),
                    Text('언제 만날까요?',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 10),
                    LayoutBuilder(builder: (context, constraints) {
                      final date = _ScheduleButton(
                        key: const Key('create-date'),
                        icon: Icons.calendar_today_outlined,
                        label: '날짜',
                        value: _dateLabel,
                        onPressed: () => _pickDate(context),
                      );
                      final time = _ScheduleButton(
                        key: const Key('create-time'),
                        icon: Icons.schedule_rounded,
                        label: '시간',
                        value: _timeLabel,
                        onPressed: () => _pickTime(context),
                      );
                      if (constraints.maxWidth < 340 ||
                          MediaQuery.textScalerOf(context).scale(14) > 18) {
                        return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [date, const SizedBox(height: 10), time]);
                      }
                      return Row(children: [
                        Expanded(child: date),
                        const SizedBox(width: 10),
                        Expanded(child: time)
                      ]);
                    }),
                    if (_scheduleError != null) ...[
                      const SizedBox(height: 8),
                      Text(_scheduleError!,
                          key: const Key('create-schedule-error'),
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: tokens.danger)),
                    ],
                    const SizedBox(height: 22),
                    Text('몇 명이 함께 먹나요?',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<int>(
                      key: const Key('create-capacity'),
                      initialValue: _maxParticipants,
                      isExpanded: true,
                      decoration: const InputDecoration(
                          labelText: '총 정원',
                          helperText: '나를 포함한 인원 · 2~8명',
                          helperMaxLines: 3),
                      items: [
                        for (var count = 2; count <= 8; count += 1)
                          DropdownMenuItem(value: count, child: Text('$count명'))
                      ],
                      onChanged: (value) {
                        if (value != null) _maxParticipants = value;
                      },
                    ),
                    const SizedBox(height: 22),
                    Text('어떤 모임인가요?',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 10),
                    TextFormField(
                      key: const Key('create-intro'),
                      controller: _titleController,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(
                          labelText: '모임 소개',
                          hintText: '예: 퇴근 후 편하게 저녁 함께 먹어요',
                          helperText: '함께 먹을 분들에게 짧게 소개해주세요.',
                          helperMaxLines: 3,
                          errorMaxLines: 3),
                      maxLength: 80,
                      validator: _requiredValidator('모임 소개를 입력해주세요.'),
                    ),
                    if (createState.hasError) ...[
                      const SizedBox(height: 12),
                      Semantics(
                          liveRegion: true,
                          child: Text(_errorMessage(createState.error),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(color: tokens.danger))),
                    ],
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      key: const Key('create_party_submit_button'),
                      style: FilledButton.styleFrom(
                          backgroundColor: MukkingBrand.green,
                          foregroundColor: MukkingBrand.surface,
                          minimumSize: const Size(44, 52),
                          textStyle: Theme.of(context)
                              .textTheme
                              .labelLarge
                              ?.copyWith(
                                  fontSize: 16, fontWeight: FontWeight.w700),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16))),
                      onPressed: createState.isLoading
                          ? null
                          : () => _submit(restaurant),
                      icon: createState.isLoading
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.group_add_outlined),
                      label: Text(
                          createState.isLoading ? '모임 만드는 중...' : '모임 만들기'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _applyRestaurantPrefill(Restaurant? restaurant) {
    if (_prefillApplied || restaurant == null) return;
    _prefillApplied = true;
    _titleController.text = '${restaurant.name} 같이 가요';
    _restaurantNameController.text = restaurant.name;
    _addressController.text = restaurant.address;
  }

  String? Function(String?) _requiredValidator(String message) {
    return (value) => (value?.trim().isEmpty ?? true) ? message : null;
  }

  Future<void> _pickDate(BuildContext context) async {
    final date = await showDatePicker(
      context: context,
      initialDate: _scheduledAt,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null) return;
    setState(() {
      _scheduleError = null;
      _scheduledAt = DateTime(
        date.year,
        date.month,
        date.day,
        _scheduledAt.hour,
        _scheduledAt.minute,
      );
    });
  }

  Future<void> _pickTime(BuildContext context) async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_scheduledAt),
    );
    if (time == null) return;
    setState(() {
      _scheduleError = null;
      _scheduledAt = DateTime(
        _scheduledAt.year,
        _scheduledAt.month,
        _scheduledAt.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _submit(Restaurant? restaurant) async {
    if (ref.read(createPartyControllerProvider).isLoading) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!_scheduledAt.isAfter(DateTime.now())) {
      setState(() => _scheduleError = '현재보다 이후 날짜와 시간을 선택해주세요.');
      return;
    }

    final party = await ref.read(createPartyControllerProvider.notifier).create(
          CreatePartyInput(
            restaurantId: restaurant?.id,
            restaurantName: _restaurantNameController.text.trim(),
            address: _addressController.text.trim(),
            scheduledAt: _scheduledAt,
            maxParticipants: _maxParticipants,
            intro: _titleController.text.trim(),
          ),
        );

    if (party == null || !mounted) return;
    ref.invalidate(notificationsProvider);
    ref.invalidate(unreadNotificationCountProvider);
    ref.read(selectedPartyIdProvider.notifier).state = party.id;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('모임을 만들었어요.')),
    );
    context.go(AppRoutes.partyDetailPath(party.id));
  }

  String _errorMessage(Object? error) {
    return error is ApiError ? error.userMessage : '파티를 만들지 못했어요.';
  }

  String get _dateLabel =>
      '${_scheduledAt.year}.${_twoDigits(_scheduledAt.month)}.${_twoDigits(_scheduledAt.day)}';

  String get _timeLabel =>
      '${_twoDigits(_scheduledAt.hour)}:${_twoDigits(_scheduledAt.minute)}';

  String _twoDigits(int value) => value.toString().padLeft(2, '0');
}

class _RestaurantSummary extends StatelessWidget {
  const _RestaurantSummary({required this.restaurant});
  final Restaurant restaurant;

  @override
  Widget build(BuildContext context) => DiscoverySurface(
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          DiscoveryRestaurantImage(restaurant: restaurant, size: 52),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('함께 먹을 식당',
                    style: Theme.of(context)
                        .textTheme
                        .labelMedium
                        ?.copyWith(color: MukkingBrand.green)),
                const SizedBox(height: 4),
                Text(restaurant.name,
                    style: Theme.of(context).textTheme.titleMedium),
                if (restaurant.category.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(restaurant.category,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: MukkingBrand.secondary,
                          )),
                ],
                if (restaurant.displayAddress.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(restaurant.displayAddress,
                      style: Theme.of(context).textTheme.bodyMedium),
                ],
              ])),
        ]),
      );
}

class _ScheduleButton extends StatelessWidget {
  const _ScheduleButton(
      {required this.icon,
      required this.label,
      required this.value,
      required this.onPressed,
      super.key});
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => OutlinedButton(
        style: OutlinedButton.styleFrom(
            backgroundColor: MukkingBrand.surface,
            foregroundColor: MukkingBrand.green,
            side: const BorderSide(color: MukkingBrand.border),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            padding: const EdgeInsets.all(14),
            minimumSize: const Size(44, 64)),
        onPressed: onPressed,
        child: Row(children: [
          Icon(icon, size: 20, color: MukkingBrand.green),
          const SizedBox(width: 10),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(label, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 3),
                Text(value,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
              ])),
        ]),
      );
}
