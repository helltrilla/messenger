import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/errors/failure.dart';
import 'controllers/account_switcher_controller.dart';
import 'controllers/auth_controller.dart';

class LoginScreen extends ConsumerStatefulWidget {
  final bool isAddingAccount;

  const LoginScreen({super.key, this.isAddingAccount = false});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isSignUp = false;
  bool _isCodeSent = false;

  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _usernameController = TextEditingController();

  Timer? _resendTimer;
  int _resendCountdown = 0;

  @override
  void dispose() {
    _resendTimer?.cancel();
    _emailController.dispose();
    _codeController.dispose();
    _displayNameController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    setState(() {
      _resendCountdown = 60;
    });
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendCountdown > 1) {
        setState(() {
          _resendCountdown--;
        });
      } else {
        timer.cancel();
        setState(() {
          _resendCountdown = 0;
        });
      }
    });
  }

  Future<void> _requestCode() async {
    if (_formKey.currentState != null) {
      if (!_formKey.currentState!.validate()) return;
    } else {
      final email = _emailController.text.trim();
      if (email.isEmpty || !email.contains('@') || !email.contains('.')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Некорректный email для повторной отправки'),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }
    }

    final controller = ref.read(authControllerProvider.notifier);
    final success = await controller.sendOtp(
      email: _emailController.text.trim(),
      username: _isSignUp
          ? _usernameController.text.trim().replaceAll('@', '')
          : null,
      displayName: _isSignUp ? _displayNameController.text.trim() : null,
    );

    if (!mounted) return;

    if (success) {
      setState(() {
        _isCodeSent = true;
        _codeController.clear();
      });
      _startResendTimer();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Код подтверждения отправлен на ${_emailController.text.trim()}',
          ),
          backgroundColor: AppColors.primary,
        ),
      );
    } else {
      final state = ref.read(authControllerProvider);
      final error = state.error;
      final msg = error is Failure
          ? error.message
          : error?.toString() ?? 'Ошибка при отправке кода';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.redAccent),
      );
    }
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.replaceAll(RegExp(r'\D'), '') ?? '';
    if (text.isNotEmpty) {
      final code = text.length > 8 ? text.substring(0, 8) : text;
      _codeController.text = code;
      _codeController.selection = TextSelection.fromPosition(
        TextPosition(offset: code.length),
      );
      if (code.length == 8) {
        _verifyCode();
      }
    }
  }

  Future<void> _verifyCode() async {
    final code = _codeController.text.trim();
    if (code.length != 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Введите 8-значный проверочный код'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final controller = ref.read(authControllerProvider.notifier);
    final success = await controller.verifyOtp(
      email: _emailController.text.trim(),
      token: code,
    );

    if (!mounted) return;

    if (success) {
      TextInput.finishAutofillContext();
      await ref
          .read(accountSwitcherControllerProvider.notifier)
          .saveCurrentAccount();
      if (widget.isAddingAccount && mounted) {
        Navigator.of(context).pop();
      }
    } else {
      final state = ref.read(authControllerProvider);
      final error = state.error;
      final msg = error is Failure
          ? error.message
          : error?.toString() ?? 'Неверный или просроченный код';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.redAccent),
      );
    }
  }

  Widget _buildEmailInputView(bool isLoading) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.send_rounded,
              size: 48,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            _isSignUp ? 'Создать аккаунт' : 'Вход в Telegram 2.0',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _isSignUp
                ? 'Заполните данные для создания профиля'
                : 'Введите ваш email для получения 8-значного кода',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondaryDark,
            ),
          ),
          const SizedBox(height: 32),
          if (_isSignUp) ...[
            TextFormField(
              controller: _displayNameController,
              decoration: const InputDecoration(
                labelText: 'Имя',
                prefixIcon: Icon(Icons.person_outline),
              ),
              validator: (value) =>
                  value == null || value.trim().isEmpty ? 'Введите имя' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _usernameController,
              decoration: const InputDecoration(
                labelText: 'Юзернейм (@username)',
                prefixIcon: Icon(Icons.alternate_email),
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Введите юзернейм'
                  : null,
            ),
            const SizedBox(height: 16),
          ],
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.email_outlined),
            ),
            validator: (value) =>
                value == null || !value.contains('@') || !value.contains('.')
                ? 'Некорректный email'
                : null,
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: isLoading ? null : _requestCode,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Получить код',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: isLoading
                ? null
                : () {
                    setState(() {
                      _isSignUp = !_isSignUp;
                    });
                  },
            child: Text(
              _isSignUp
                  ? 'Уже есть аккаунт? Войти по коду'
                  : 'Нет аккаунта? Зарегистрироваться',
              style: const TextStyle(color: AppColors.accent),
            ),
          ),
          if (!_isSignUp)
            TextButton(
              onPressed: () {
                if (_emailController.text.trim().isNotEmpty) {
                  setState(() {
                    _isCodeSent = true;
                  });
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Сначала укажите email'),
                      backgroundColor: Colors.orangeAccent,
                    ),
                  );
                }
              },
              child: const Text(
                'Уже есть код? Ввести код',
                style: TextStyle(
                  color: AppColors.textSecondaryDark,
                  fontSize: 13,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCodeVerificationView(bool isLoading) {
    return AutofillGroup(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.4),
                width: 2,
              ),
            ),
            child: const Icon(
              Icons.mark_email_read_rounded,
              size: 44,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Код подтверждения',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Мы отправили 8-значный проверочный код на:\n${_emailController.text.trim()}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondaryDark,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 32),
          TextFormField(
            controller: _codeController,
            autofillHints: const [AutofillHints.oneTimeCode],
            enableInteractiveSelection: true,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(8),
            ],
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 26,
              letterSpacing: 8,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            autofocus: true,
            decoration: InputDecoration(
              counterText: '',
              hintText: '••••••••',
              hintStyle: TextStyle(
                fontSize: 24,
                letterSpacing: 8,
                color: AppColors.textSecondaryDark.withValues(alpha: 0.3),
              ),
              suffixIcon: IconButton(
                icon: const Icon(
                  Icons.content_paste_rounded,
                  color: AppColors.accent,
                ),
                tooltip: 'Вставить код',
                onPressed: isLoading ? null : _pasteFromClipboard,
              ),
            ),
            onChanged: (value) {
              if (value.trim().length == 8) {
                _verifyCode();
              }
            },
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: isLoading ? null : _verifyCode,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Подтвердить',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 20),
          if (_resendCountdown > 0)
            Text(
              'Отправить код повторно через $_resendCountdown с',
              style: const TextStyle(
                color: AppColors.textSecondaryDark,
                fontSize: 14,
              ),
            )
          else
            TextButton(
              onPressed: isLoading ? null : _requestCode,
              child: const Text(
                'Отправить код повторно',
                style: TextStyle(color: AppColors.accent),
              ),
            ),
          TextButton(
            onPressed: isLoading
                ? null
                : () {
                    setState(() {
                      _isCodeSent = false;
                    });
                  },
            child: const Text(
              'Изменить email',
              style: TextStyle(color: AppColors.textSecondaryDark),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final isLoading = authState.isLoading;

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      appBar: _isCodeSent
          ? AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white,
                ),
                onPressed: isLoading
                    ? null
                    : () {
                        setState(() {
                          _isCodeSent = false;
                        });
                      },
              ),
            )
          : (widget.isAddingAccount
                ? AppBar(
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    title: const Text(
                      'Добавить аккаунт',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    leading: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  )
                : null),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: _isCodeSent
                ? _buildCodeVerificationView(isLoading)
                : _buildEmailInputView(isLoading),
          ),
        ),
      ),
    );
  }
}
