import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/discovery_provider.dart';

class SearchThisAreaButton extends ConsumerWidget {
  const SearchThisAreaButton({this.buttonKey, super.key});

  final Key? buttonKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(searchAreaProvider);
    if (!state.hasMovedMeaningfully && !state.isLoading) {
      return const SizedBox.shrink();
    }

    return Material(
      elevation: 3,
      borderRadius: BorderRadius.circular(999),
      child: FilledButton.tonalIcon(
        key: buttonKey,
        onPressed: state.isLoading
            ? null
            : () async {
                final succeeded = await ref
                    .read(searchAreaProvider.notifier)
                    .searchCurrentArea();
                if (!succeeded && context.mounted) {
                  final message = ref.read(searchAreaProvider).errorMessage;
                  if (message != null) {
                    ScaffoldMessenger.of(context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(
                        SnackBar(
                          content: Text(message),
                          action: SnackBarAction(
                            label: '다시 시도',
                            onPressed: () => ref
                                .read(searchAreaProvider.notifier)
                                .searchCurrentArea(),
                          ),
                        ),
                      );
                  }
                }
              },
        icon: state.isLoading
            ? const SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.refresh_rounded),
        label: Text(state.isLoading ? '검색 중' : '이 지역에서 다시 검색'),
      ),
    );
  }
}
