import 'dart:math';
import 'dart:convert';
import 'package:http/http.dart' as http;

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/ui/ui_controller.dart';
import '../../../shared/widgets/glass_button.dart';
import '../../../core/utils/glass_container.dart';
import 'reset_password_screen.dart';





class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final TextEditingController _emailController = TextEditingController();

  String? _emailError;
  bool _isLoading = false;

  final supabase = Supabase.instance.client;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  String? _validateEmail(String value) {
    final email = value.trim();

    if (email.isEmpty) return 'Email required';

    final emailRegex =
        RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]+$');

    if (!emailRegex.hasMatch(email)) return 'Invalid email';

    return null;
  }

  // ================= SEND EMAIL =================

  Future<void> sendEmailOtp(String email, String otp) async {
    final response = await http.post(
      Uri.parse('https://api.emailjs.com/api/v1.0/email/send'),
      headers: {
        'origin': 'http://localhost',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'service_id': 'service_f85ep68',
        'template_id': 'template_k5107gp',
        'user_id': 'fNVSzm6rErLvCuZw2',
        'template_params': {
          'email': email,
          'code': otp,
        }
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Email failed: ${response.body}');
    }
  }

  // ================= SEND OTP =================

  Future<void> _sendReset() async {
    final email = _emailController.text.trim().toLowerCase();

    setState(() {
      _emailError = _validateEmail(email);
    });

    if (_emailError != null) return;

    try {
      setState(() => _isLoading = true);

      final otp = (100000 + Random().nextInt(900000)).toString();

      await supabase.from('otp_codes').insert({
        'email': email,
        'code': otp,
        'expires_at': DateTime.now()
            .add(const Duration(minutes: 5))
            .toIso8601String(),
      });

      await sendEmailOtp(email, otp);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Verification code sent 📩")),
      );

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ResetPasswordScreen(email: email),
        ),
      );

    } catch (e) {
      setState(() {
        _emailError = 'Failed to send code';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // ================= UI =================

 Widget _buildInput() {
  final theme = Theme.of(context);

  return GlassContainer(
    height: UIController.inputHeight,
    radius: UIController.inputRadius,
    border: Border.all(
      color: _emailError != null
          ? Colors.red
          : theme.dividerColor.withOpacity(0.2),
      width: 1.5,
    ),
    child: TextField(
      controller: _emailController,

      /// ✅ FIX TEXT COLOR
      style: TextStyle(
        color: theme.brightness == Brightness.dark
            ? Colors.white
            : Colors.black,
      ),

      onChanged: (_) {
        if (_emailError != null) {
          setState(() => _emailError = null);
        }
      },

      decoration: InputDecoration(
        border: InputBorder.none,
        hintText: 'Enter your email',

        /// ✅ FIX HINT
        hintStyle: TextStyle(
          color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
        ),

        /// ✅ FIX ICON
        prefixIcon: Icon(
          Icons.email,
          color: theme.iconTheme.color,
        ),

        contentPadding: const EdgeInsets.symmetric(vertical: 14),
      ),
    ),
  );
}

  Widget _buildErrorText() {
    return Row(
      children: [
        const Icon(Icons.error, color: Colors.red, size: 16),
        const SizedBox(width: 6),
        Text(
          _emailError!,
          style: const TextStyle(color: Colors.red),
        ),
      ],
    );
  }

  // ================= BUILD =================

 @override
Widget build(BuildContext context) {

  final theme = Theme.of(context);

  return Scaffold(
    backgroundColor: theme.scaffoldBackgroundColor,

    body: Container(
      /// 🔥 حذفنا gradient
      color: theme.scaffoldBackgroundColor,

      child: SafeArea(
        child: Stack(
          children: [

            /// 🔥 BACK BUTTON
            Positioned(
              top: 16,
              left: 24,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Icon(
                  Icons.arrow_back_ios,
                  color: theme.textTheme.bodyLarge?.color,
                  size: 22,
                ),
              ),
            ),

            /// 🔥 CONTENT
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [

                    Text(
                      'Reset Password',
                      style: TextStyle(
                        color: theme.textTheme.bodyLarge?.color,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 20),

                    _buildInput(),

                    const SizedBox(height: 10),
                    if (_emailError != null) _buildErrorText(),

                    const SizedBox(height: 25),

                    SizedBox(
                      width: 180,
                      child: GlassContainer(
                        height: UIController.buttonHeight,
                        radius: UIController.buttonRadius,
                        child: GestureDetector(
                          onTap: _isLoading ? null : _sendReset,
                          child: _isLoading
                              ? const Center(
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                )
                              : const GlassButton(text: 'Next'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          ],
        ),
      ),
    ),
  );
}
}