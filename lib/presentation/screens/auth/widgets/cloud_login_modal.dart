import 'package:flutter/material.dart';
import 'package:bodego/data/models/google_sheets_config.dart';
import 'package:bodego/core/services/google_sheets_sync_service.dart';
import 'package:bodego/presentation/screens/pos/main_pos_screen.dart';

/// Modal para Iniciar Sesión en la Nube y Recuperar Negocio en BodeGo.
/// Permite a usuarios que perdieron o cambiaron de celular ingresar con su
/// Correo y Contraseña de Administrador para restaurar todo su inventario y datos.
class CloudLoginModal extends StatefulWidget {
  const CloudLoginModal({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const CloudLoginModal(),
    );
  }

  @override
  State<CloudLoginModal> createState() => _CloudLoginModalState();
}

class _CloudLoginModalState extends State<CloudLoginModal> {
  final GoogleSheetsSyncService _syncService = GoogleSheetsSyncService();

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _urlController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _showAdvancedUrl = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initUrl();
  }

  Future<void> _initUrl() async {
    final conf = await _syncService.getConfig();
    if (mounted) {
      // Solo mostrar en el controller si el usuario tiene una URL personalizada válida (que no sea el secreto Base64)
      if (conf.scriptUrl != GoogleSheetsConfig.cloudSecretKey &&
          !conf.scriptUrl.startsWith('aHR0') &&
          conf.scriptUrl.startsWith('http')) {
        _urlController.text = conf.scriptUrl;
      } else {
        _urlController.text = '';
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final rawUrl = _urlController.text.trim();

    if (email.isEmpty || !email.contains('@')) {
      setState(() => _errorMessage = 'Ingresa un correo electrónico válido');
      return;
    }

    if (password.isEmpty) {
      setState(() => _errorMessage = 'Ingresa tu contraseña de Administrador');
      return;
    }

    // Filtrar para que solo se pase URL personalizada si realmente es una URL HTTP(S) válida y no la clave Base64
    String? validCustomUrl;
    if (rawUrl.isNotEmpty &&
        rawUrl.startsWith('http') &&
        !rawUrl.startsWith('aHR0') &&
        !rawUrl.endsWith('==')) {
      validCustomUrl = rawUrl;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final res = await _syncService.loginBusiness(
      email: email,
      password: password,
      scriptUrl: validCustomUrl,
    );

    if (!mounted) return;

    if (res.success) {
      Navigator.pop(context); // Cerrar modal

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '¡Bienvenido de vuelta a ${res.businessName}!\nSe restauraron ${res.productsRestored} productos con éxito.',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.green[800],
          duration: const Duration(seconds: 3),
        ),
      );

      // Dirigir al Punto de Venta reemplazando toda la pila de navegación
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const MainPosScreen()),
        (route) => false,
      );
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = res.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.35),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 18),

            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4353FF).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.cloud_download_rounded, color: Color(0xFF4353FF), size: 26),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Iniciar Sesión',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                      ),
                      Text(
                        'Recupera tu negocio y catálogo desde la nube',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            if (_errorMessage != null)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: Colors.red, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),

            // Campo: Correo Electrónico
            const Text(
              'Correo del Administrador',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'ejemplo@bodego.pe',
                prefixIcon: const Icon(Icons.email_outlined, size: 20),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),

            const SizedBox(height: 14),

            // Campo: Contraseña
            const Text(
              'Contraseña',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Tu contraseña registrada',
                prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                suffixIcon: IconButton(
                  icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),

            const SizedBox(height: 10),

            // Opciones Avanzadas (URL del Script)
            InkWell(
              onTap: () => setState(() => _showAdvancedUrl = !_showAdvancedUrl),
              child: Row(
                children: [
                  Icon(
                    _showAdvancedUrl ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _showAdvancedUrl ? 'Ocultar servidor de nube' : 'Servidor de nube personalizado',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ),

            if (_showAdvancedUrl) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _urlController,
                style: const TextStyle(fontSize: 11),
                decoration: InputDecoration(
                  hintText: 'https://script.google.com/macros/s/.../exec',
                  prefixIcon: const Icon(Icons.cloud_outlined, size: 18),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ],

            const SizedBox(height: 22),

            // Botón Principal de Inicio de Sesión
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _handleLogin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4353FF),
                  foregroundColor: Colors.white,
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: _isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.cloud_download_rounded, color: Colors.white),
                label: Text(
                  _isLoading ? 'Restaurando Negocio...' : 'Iniciar Sesión y Restaurar Negocio',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ),

            const SizedBox(height: 10),
            Center(
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Cancelar',
                  style: TextStyle(color: isDark ? Colors.white60 : Colors.grey[700], fontSize: 13),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

