import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme_presets.dart';
import '../../../core/theme/brand_assets.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../matching/providers/matching_provider.dart';
import '../domain/discovery_party_filter.dart';
import '../domain/restaurant.dart';

/// Scoped presentation only: saved themes, map styles and providers stay intact.
class DiscoveryTheme extends StatelessWidget {
  const DiscoveryTheme({required this.child, super.key});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    final tokens =
        (base.extension<MukkingThemeTokens>() ?? AppThemePresets.violet.tokens)
            .copyWith(
      primary: MukkingBrand.green,
      secondary: MukkingBrand.darkGreen,
      accent: MukkingBrand.orange,
      background: MukkingBrand.background,
      surface: MukkingBrand.surface,
      textPrimary: MukkingBrand.text,
      textSecondary: MukkingBrand.secondary,
      success: MukkingBrand.green,
      warning: MukkingBrand.orange,
      favorite: MukkingBrand.orange,
      partyHot: MukkingBrand.green,
      partyUrgent: MukkingBrand.orange,
      mapMarker: MukkingBrand.green,
    );
    final text = base.textTheme.apply(
      fontFamily: base.textTheme.bodyMedium?.fontFamily,
      bodyColor: MukkingBrand.text,
      displayColor: MukkingBrand.text,
    );
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(15),
      borderSide: const BorderSide(color: MukkingBrand.border),
    );
    return Theme(
      data: base.copyWith(
        scaffoldBackgroundColor: tokens.background,
        colorScheme: base.colorScheme.copyWith(
          primary: tokens.primary,
          onPrimary: tokens.surface,
          secondary: MukkingBrand.orange,
          secondaryContainer: MukkingBrand.mint,
          onSecondaryContainer: MukkingBrand.darkGreen,
          surface: tokens.surface,
          onSurface: tokens.textPrimary,
          outline: MukkingBrand.border,
          surfaceTint: Colors.transparent,
        ),
        textTheme: text.copyWith(
          titleLarge: text.titleLarge?.copyWith(fontSize: 20),
          labelLarge: text.labelLarge?.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        extensions: [
          ...base.extensions.values.where((e) => e is! MukkingThemeTokens),
          tokens,
        ],
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: tokens.surface,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          hintStyle: text.bodyMedium?.copyWith(color: tokens.textSecondary),
          border: border,
          enabledBorder: border,
          focusedBorder: border.copyWith(
              borderSide: BorderSide(color: tokens.primary, width: 1.5)),
        ),
        chipTheme: base.chipTheme.copyWith(
          backgroundColor: tokens.surface,
          selectedColor: MukkingBrand.green,
          checkmarkColor: Colors.white,
          labelStyle: text.labelLarge
              ?.copyWith(color: tokens.textPrimary, fontSize: 13),
          side: const BorderSide(color: MukkingBrand.border),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          showCheckmark: true,
        ),
        filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
          minimumSize: const Size(44, 44),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        )),
        outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(
          foregroundColor: tokens.textPrimary,
          minimumSize: const Size(44, 44),
          side: const BorderSide(color: MukkingBrand.border),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        )),
        textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
          foregroundColor: tokens.primary,
          minimumSize: const Size(44, 44),
        )),
        bottomSheetTheme: base.bottomSheetTheme.copyWith(
          backgroundColor: tokens.surface,
          surfaceTintColor: Colors.transparent,
        ),
      ),
      child: child,
    );
  }
}

class DiscoverySurface extends StatelessWidget {
  const DiscoverySurface(
      {required this.child,
      this.selected = false,
      this.padding = const EdgeInsets.all(14),
      super.key});
  final Widget child;
  final bool selected;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(
          color: MukkingBrand.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: selected ? MukkingBrand.orange : MukkingBrand.border,
              width: selected ? 1.5 : 1),
        ),
        child: child,
      );
}

/// Uses only a real API photo URL; the fallback is visibly an icon, not a photo.
class DiscoveryRestaurantImage extends StatelessWidget {
  const DiscoveryRestaurantImage(
      {required this.restaurant, this.size = 48, super.key});
  final Restaurant restaurant;
  final double size;

  @override
  Widget build(BuildContext context) {
    final uri = Uri.tryParse(restaurant.imageUrl.trim());
    final fallback = ColoredBox(
      color: MukkingBrand.mint,
      child: Center(
          child: Icon(Icons.restaurant_menu_rounded,
              color: MukkingBrand.green, size: size * .42)),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox.square(
        dimension: size,
        child: uri != null &&
                uri.hasAuthority &&
                (uri.scheme == 'https' || uri.scheme == 'http')
            ? Image.network(uri.toString(),
                fit: BoxFit.cover,
                semanticLabel: '${restaurant.name} 식당 사진',
                errorBuilder: (_, __, ___) => fallback,
                loadingBuilder: (_, child, progress) =>
                    progress == null ? child : fallback)
            : ExcludeSemantics(child: fallback),
      ),
    );
  }
}

/// Display summary from the existing shared feed, without per-card API calls.
class DiscoveryPartyPreview extends ConsumerWidget {
  const DiscoveryPartyPreview({required this.restaurantId, super.key});
  final String restaurantId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final parties = ref.watch(partiesByRestaurantProvider(restaurantId));
    return parties.when(
      data: (items) {
        final open = items
            .where((p) => isRecruitingParty(p) && hasAvailablePartySeat(p))
            .toList()
          ..sort((a, b) {
            final date = a.scheduledAt.compareTo(b.scheduledAt);
            return date == 0 ? a.id.compareTo(b.id) : date;
          });
        if (open.isEmpty) return _line(context, '현재 모집 중인 모임이 없어요.');
        final party = open.first;
        final date = party.scheduledAt.toLocal();
        final time =
            '${date.month}/${date.day} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
        return _line(context, '$time · ${party.memberLabel}',
            icon: Icons.schedule_rounded);
      },
      loading: () => _line(context, '모임 일정 확인 중'),
      error: (_, __) => _line(context, '모임 일정을 불러오지 못했어요.'),
    );
  }

  Widget _line(BuildContext context, String label,
          {IconData icon = Icons.groups_2_outlined}) =>
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: MukkingBrand.green),
          const SizedBox(width: 6),
          Expanded(
              child: Text(label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall)),
        ],
      );
}
