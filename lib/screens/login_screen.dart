import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'date_selection_screen.dart'; // إضافة الاستيراد

// ════════════════════════════════════════════════════
// شاشة تسجيل الدخول — تحديد كلمة المرور أو إدخالها
// ════════════════════════════════════════════════════
class LoginScreen extends StatefulWidget {
  /// الشاشة الرئيسية التي تُفتح بعد نجاح تسجيل الدخول
  final Widget? homeScreen;

  /// اسم البائع
  final String? sellerName;

  /// نوع المتجر
  final String? storeType;

  /// اسم المتجر
  final String? storeName;

  const LoginScreen(
      {Key? key,
      this.homeScreen,
      this.sellerName,
      this.storeType,
      this.storeName})
      : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with WidgetsBindingObserver {
  static const String _passwordKey = 'app_password';

  bool _isPasswordSet = false;
  bool _isLoading = true;
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPassword();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _isLoggedIn) {
      setState(() => _isLoggedIn = false);
    }
  }

  Future<void> _checkPassword() async {
    final prefs = await SharedPreferences.getInstance();
    final storedPassword = prefs.getString(_passwordKey);
    setState(() {
      _isPasswordSet = storedPassword != null && storedPassword.isNotEmpty;
      _isLoading = false;
    });
  }

  void _onLoginSuccess() {
    setState(() => _isLoggedIn = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_isLoggedIn) {
      // الانتقال إلى DateSelectionScreen بعد تسجيل الدخول
      return DateSelectionScreen(
        storeType: widget.storeType ?? 'نوع المتجر',
        storeName: widget.storeName ?? 'اسم المتجر',
        sellerName: widget.sellerName,
      );
    }

    if (_isPasswordSet) {
      return _EnterPasswordScreen(
        onSuccess: _onLoginSuccess,
        passwordKey: _passwordKey,
      );
    } else {
      return _SetPasswordScreen(
        onSuccess: () async {
          await _checkPassword();
          _onLoginSuccess();
        },
        passwordKey: _passwordKey,
      );
    }
  }
}

// ════════════════════════════════════════════════════
// شاشة تعيين كلمة المرور لأول مرة
// ════════════════════════════════════════════════════
class _SetPasswordScreen extends StatefulWidget {
  final VoidCallback onSuccess;
  final String passwordKey;

  const _SetPasswordScreen(
      {required this.onSuccess, required this.passwordKey});

  @override
  State<_SetPasswordScreen> createState() => _SetPasswordScreenState();
}

class _SetPasswordScreenState extends State<_SetPasswordScreen> {
  final _passController = TextEditingController();
  final _confirmController = TextEditingController();
  final _passFocus = FocusNode();
  final _confirmFocus = FocusNode();

  bool _obscurePass = true;
  bool _obscureConfirm = true;
  String? _errorMsg;

  @override
  void dispose() {
    _passController.dispose();
    _confirmController.dispose();
    _passFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final pass = _passController.text.trim();
    final confirm = _confirmController.text.trim();

    if (pass.isEmpty) {
      setState(() => _errorMsg = 'يرجى إدخال كلمة المرور');
      return;
    }
    if (pass.length < 4) {
      setState(() => _errorMsg = 'كلمة المرور يجب أن تكون 4 أحرف على الأقل');
      return;
    }
    if (pass != confirm) {
      setState(() => _errorMsg = 'كلمة المرور وتأكيدها غير متطابقتين');
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(widget.passwordKey, pass);
    widget.onSuccess();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.green[50],
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Card(
              elevation: 6,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock_outline,
                        size: 64, color: Colors.green[700]),
                    const SizedBox(height: 12),
                    Text(
                      'تعيين كلمة المرور',
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.green[800]),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'سيتم استخدام هذه الكلمة لحماية التطبيق',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 28),
                    TextField(
                      controller: _passController,
                      focusNode: _passFocus,
                      obscureText: _obscurePass,
                      textInputAction: TextInputAction.next,
                      onSubmitted: (_) =>
                          FocusScope.of(context).requestFocus(_confirmFocus),
                      decoration: InputDecoration(
                        labelText: 'كلمة المرور',
                        prefixIcon: const Icon(Icons.lock),
                        suffixIcon: IconButton(
                          icon: Icon(_obscurePass
                              ? Icons.visibility_off
                              : Icons.visibility),
                          onPressed: () =>
                              setState(() => _obscurePass = !_obscurePass),
                        ),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _confirmController,
                      focusNode: _confirmFocus,
                      obscureText: _obscureConfirm,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _save(),
                      decoration: InputDecoration(
                        labelText: 'تأكيد كلمة المرور',
                        prefixIcon: const Icon(Icons.lock_reset),
                        suffixIcon: IconButton(
                          icon: Icon(_obscureConfirm
                              ? Icons.visibility_off
                              : Icons.visibility),
                          onPressed: () => setState(
                              () => _obscureConfirm = !_obscureConfirm),
                        ),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    if (_errorMsg != null) ...[
                      const SizedBox(height: 10),
                      Text(_errorMsg!,
                          style:
                              const TextStyle(color: Colors.red, fontSize: 13)),
                    ],
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _save,
                        icon: const Icon(Icons.save),
                        label: const Text('حفظ كلمة المرور',
                            style: TextStyle(fontSize: 16)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[700],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════
// شاشة إدخال كلمة المرور
// ════════════════════════════════════════════════════
class _EnterPasswordScreen extends StatefulWidget {
  final VoidCallback onSuccess;
  final String passwordKey;

  const _EnterPasswordScreen(
      {required this.onSuccess, required this.passwordKey});

  @override
  State<_EnterPasswordScreen> createState() => _EnterPasswordScreenState();
}

class _EnterPasswordScreenState extends State<_EnterPasswordScreen> {
  final _passController = TextEditingController();
  final _passFocus = FocusNode();

  bool _obscure = true;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => FocusScope.of(context).requestFocus(_passFocus));
  }

  @override
  void dispose() {
    _passController.dispose();
    _passFocus.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(widget.passwordKey) ?? '';
    if (_passController.text.trim() == stored) {
      widget.onSuccess();
    } else {
      setState(() => _errorMsg = 'كلمة المرور غير صحيحة');
      _passController.clear();
      FocusScope.of(context).requestFocus(_passFocus);
    }
  }

  void _showChangePasswordDialog() {
    final oldCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    final oldFocus = FocusNode();
    final newFocus = FocusNode();
    final confirmFocus = FocusNode();
    String? dialogError;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setDialogState) {
          Future<void> doChange() async {
            final prefs = await SharedPreferences.getInstance();
            final stored = prefs.getString(widget.passwordKey) ?? '';
            if (oldCtrl.text.trim() != stored) {
              setDialogState(
                  () => dialogError = 'كلمة المرور القديمة غير صحيحة');
              return;
            }
            if (newCtrl.text.trim().length < 4) {
              setDialogState(
                  () => dialogError = 'كلمة المرور الجديدة 4 أحرف على الأقل');
              return;
            }
            if (newCtrl.text.trim() != confirmCtrl.text.trim()) {
              setDialogState(() =>
                  dialogError = 'كلمة المرور الجديدة وتأكيدها غير متطابقتين');
              return;
            }
            await prefs.setString(widget.passwordKey, newCtrl.text.trim());
            Navigator.pop(ctx);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('✅ تم تغيير كلمة المرور بنجاح'),
                    backgroundColor: Colors.green),
              );
            }
          }

          return Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.lock_reset, color: Colors.orange[700]),
                  const SizedBox(width: 8),
                  const Text('تغيير كلمة المرور',
                      style: TextStyle(fontSize: 16)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: oldCtrl,
                    focusNode: oldFocus,
                    obscureText: true,
                    textInputAction: TextInputAction.next,
                    onSubmitted: (_) =>
                        FocusScope.of(ctx).requestFocus(newFocus),
                    decoration: InputDecoration(
                      labelText: 'كلمة المرور القديمة',
                      prefixIcon: const Icon(Icons.lock_outline),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: newCtrl,
                    focusNode: newFocus,
                    obscureText: true,
                    textInputAction: TextInputAction.next,
                    onSubmitted: (_) =>
                        FocusScope.of(ctx).requestFocus(confirmFocus),
                    decoration: InputDecoration(
                      labelText: 'كلمة المرور الجديدة',
                      prefixIcon: const Icon(Icons.lock),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: confirmCtrl,
                    focusNode: confirmFocus,
                    obscureText: true,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => doChange(),
                    decoration: InputDecoration(
                      labelText: 'تأكيد كلمة المرور ',
                      prefixIcon: const Icon(Icons.lock_reset),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  if (dialogError != null) ...[
                    const SizedBox(height: 8),
                    Text(dialogError!,
                        style:
                            const TextStyle(color: Colors.red, fontSize: 12)),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton(
                  onPressed: doChange,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange[700]),
                  child: const Text('تغيير',
                      style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          );
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.green[50],
        body: Column(
          children: [
            SafeArea(
              child: Align(
                alignment: Alignment.topLeft,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: TextButton.icon(
                    onPressed: _showChangePasswordDialog,
                    icon: Icon(Icons.lock_reset, color: Colors.green[700]),
                    label: Text('تغيير كلمة المرور',
                        style: TextStyle(color: Colors.green[700])),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(32),
                  child: Card(
                    elevation: 6,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.lock, size: 64, color: Colors.green[700]),
                          const SizedBox(height: 12),
                          Text(
                            'تسجيل الدخول',
                            style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.green[800]),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'أدخل كلمة المرور للمتابعة',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 13, color: Colors.grey[600]),
                          ),
                          const SizedBox(height: 28),
                          TextField(
                            controller: _passController,
                            focusNode: _passFocus,
                            obscureText: _obscure,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _login(),
                            decoration: InputDecoration(
                              labelText: 'كلمة المرور',
                              prefixIcon: const Icon(Icons.lock),
                              suffixIcon: IconButton(
                                icon: Icon(_obscure
                                    ? Icons.visibility_off
                                    : Icons.visibility),
                                onPressed: () =>
                                    setState(() => _obscure = !_obscure),
                              ),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                          if (_errorMsg != null) ...[
                            const SizedBox(height: 10),
                            Text(_errorMsg!,
                                style: const TextStyle(
                                    color: Colors.red, fontSize: 13)),
                          ],
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _login,
                              icon: const Icon(Icons.login),
                              label: const Text('دخول',
                                  style: TextStyle(fontSize: 16)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green[700],
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
