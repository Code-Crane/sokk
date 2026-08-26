import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_tokens.dart';
import '../../../widgets/mukking_card.dart';
import '../providers/auth_provider.dart';

class AuthPlaceholderScreen extends ConsumerStatefulWidget {
  const AuthPlaceholderScreen({super.key});

  @override
  ConsumerState<AuthPlaceholderScreen> createState() =>
      _AuthPlaceholderScreenState();
}

class _AuthPlaceholderScreenState extends ConsumerState<AuthPlaceholderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final tokens = context.tokens;

    return MukkingCard(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('로그인', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(
              '찜과 파티 정보를 서버에서 불러오려면 로그인해주세요.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(labelText: '이메일'),
              validator: (value) {
                final email = value?.trim() ?? '';
                if (email.isEmpty || !email.contains('@')) {
                  return '이메일을 확인해주세요.';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _passwordController,
              obscureText: true,
              autofillHints: const [AutofillHints.password],
              decoration: const InputDecoration(labelText: '비밀번호'),
              validator: (value) {
                if ((value ?? '').isEmpty) return '비밀번호를 입력해주세요.';
                return null;
              },
              onFieldSubmitted: (_) => _submit(auth.isLoading),
            ),
            if (auth.message != null) ...[
              const SizedBox(height: 12),
              Text(
                auth.message!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: tokens.danger,
                    ),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: auth.isLoading ? null : () => _submit(false),
                child: Text(auth.isLoading ? '로그인 중...' : '로그인'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit(bool isLoading) async {
    if (isLoading || !(_formKey.currentState?.validate() ?? false)) return;
    await ref.read(authControllerProvider.notifier).login(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
  }
}
