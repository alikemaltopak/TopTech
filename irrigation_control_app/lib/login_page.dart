import 'package:flutter/material.dart';
import 'package:irrigation_control_app/auth_service.dart';

class LoginPage extends StatefulWidget {
  final VoidCallback onLoggedIn;

  const LoginPage({super.key, required this.onLoggedIn});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  String _errorMessage = '';

  Future<void> _handleLogin() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final authService = AuthService();
      await authService.login(_emailController.text, _passwordController.text);

      // Giriş başarılıysa ana sayfaya geçişi tetikle
      widget.onLoggedIn();

    } catch (e) {
      // Giriş başarısızsa hata mesajını göster
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.green.shade700, Colors.blue.shade700],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32.0),
            child: Card(
              elevation: 10,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Yetkili Girişi',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade800,
                      ),
                    ),
                    const SizedBox(height: 30),
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'E-posta Adresi',
                        prefixIcon: const Icon(Icons.email),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 15),
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'Şifre',
                        prefixIcon: const Icon(Icons.lock),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (_errorMessage.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 15.0),
                        child: Text(
                          _errorMessage,
                          style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade600,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text(
                                'Giriş Yap',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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