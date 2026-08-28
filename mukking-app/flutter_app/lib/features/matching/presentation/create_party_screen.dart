import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_error.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../widgets/mukking_card.dart';
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
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final restaurant = widget.restaurantId == null
        ? null
        : ref.watch(restaurantDetailProvider(widget.restaurantId!)).valueOrNull;
    final createState = ref.watch(createPartyControllerProvider);

    _applyRestaurantPrefill(restaurant);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
      children: [
        Text('파티 만들기', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 6),
        Text(
          restaurant == null
              ? '먹고 싶은 식당과 파티 조건을 입력해요.'
              : '${restaurant.name}에서 열 파티 정보를 미리 채웠어요.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 18),
        if (restaurant != null)
          _RestaurantSummary(restaurant: restaurant)
        else
          MukkingCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.explore_rounded, color: tokens.primary, size: 36),
                const SizedBox(height: 12),
                Text(
                  '식당부터 고르면 더 빠르게 만들 수 있어요',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  '발견 탭에서 식당을 선택하면 식당명과 주소가 자동으로 채워집니다.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: () => context.go(AppRoutes.discovery),
                  icon: const Icon(Icons.map_rounded),
                  label: const Text('식당 발견으로 이동'),
                ),
              ],
            ),
          ),
        const SizedBox(height: 16),
        MukkingCard(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('파티 정보', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: '파티 제목',
                    hintText: '예: 퇴근 후 같이 라멘 먹어요',
                  ),
                  maxLength: 80,
                  validator: _requiredValidator('파티 제목을 입력해주세요.'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _restaurantNameController,
                  readOnly: restaurant != null,
                  decoration: const InputDecoration(labelText: '식당명'),
                  validator: _requiredValidator('식당명을 입력해주세요.'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _addressController,
                  readOnly: restaurant != null,
                  decoration: const InputDecoration(labelText: '주소'),
                  validator: _requiredValidator('주소를 입력해주세요.'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickDate,
                        icon: const Icon(Icons.calendar_month_rounded),
                        label: Text(_dateLabel),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickTime,
                        icon: const Icon(Icons.schedule_rounded),
                        label: Text(_timeLabel),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: _maxParticipants,
                  decoration: const InputDecoration(labelText: '최대 모집 인원'),
                  items: [
                    for (var count = 2; count <= 8; count += 1)
                      DropdownMenuItem(value: count, child: Text('$count명')),
                  ],
                  onChanged: (value) {
                    if (value != null) _maxParticipants = value;
                  },
                ),
                if (createState.hasError) ...[
                  const SizedBox(height: 12),
                  Text(
                    _errorMessage(createState.error),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: tokens.danger,
                        ),
                  ),
                ],
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    key: const Key('create_party_submit_button'),
                    onPressed: createState.isLoading
                        ? null
                        : () => _submit(restaurant),
                    icon: const Icon(Icons.group_add_rounded),
                    label: Text(
                      createState.isLoading ? '파티 만드는 중...' : '파티 만들기',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
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

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _scheduledAt,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null) return;
    setState(() {
      _scheduledAt = DateTime(
        date.year,
        date.month,
        date.day,
        _scheduledAt.hour,
        _scheduledAt.minute,
      );
    });
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_scheduledAt),
    );
    if (time == null) return;
    setState(() {
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
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!_scheduledAt.isAfter(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('현재보다 이후 날짜와 시간을 선택해주세요.')),
      );
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
      const SnackBar(content: Text('파티를 만들었어요.')),
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
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return MukkingCard(
      backgroundColor: tokens.primary.withValues(alpha: 0.08),
      child: Row(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: tokens.rewardXp.withValues(alpha: 0.42),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Icon(
              Icons.restaurant_menu_rounded,
              color: tokens.textPrimary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  restaurant.name,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  '${restaurant.category} · ${restaurant.distanceLabel}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                Text(
                  restaurant.address,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
