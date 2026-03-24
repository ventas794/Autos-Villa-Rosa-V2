import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart'; // para AppColors y MainScreen

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  static const String _domain = '@autosvillarosa.com';

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // Construimos el email completo automáticamente
      String username = _userCtrl.text.trim();
      String email = username.contains('@') ? username : '$username$_domain';

      await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: _passCtrl.text.trim(),
      );
      // No necesitas Navigator aquí → el auth state listener en main.dart cambiará de pantalla
    } on AuthException catch (e) {
      _error = e.message.contains('Invalid login credentials')
          ? 'Usuario o contraseña incorrectos'
          : e.message;
    } catch (e) {
      _error = 'Error inesperado: $e';
    }

    if (mounted) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Autos Villa Rosa',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryBlue,
                  ),
                ),
                const SizedBox(height: 8),
                const Text('Inicia sesión', style: TextStyle(fontSize: 18)),
                const SizedBox(height: 48),

                // Campo de usuario (sin dominio visible)
                TextField(
                  controller: _userCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Usuario',
                    hintText: 'Ej: Alejandro',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                  textInputAction: TextInputAction.next,
                  autocorrect: false,
                  textCapitalization: TextCapitalization.none,
                ),

                const SizedBox(height: 16),

                // Campo de contraseña
                TextField(
                  controller: _passCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Contraseña',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock),
                  ),
                  obscureText: true,
                  textInputAction: TextInputAction.go,
                  onSubmitted: (_) => _login(),
                ),

                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ],

                const SizedBox(height: 32),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue,
                    ),
                    child: _loading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            'INGRESAR',
                            style: TextStyle(color: Colors.white, fontSize: 16),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
