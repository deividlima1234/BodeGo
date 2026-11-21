import 'package:flutter/material.dart';
import 'package:bodego/presentation/widgets/bodego_logo.dart';
import 'package:bodego/core/services/app_version_service.dart';

/// Modal Bottom Sheet moderno e interactivo para visualizar los
/// Términos de Servicio, Políticas de Privacidad y Respaldo de EddamCore.
class LegalTermsModal extends StatefulWidget {
  final int initialTabIndex;

  const LegalTermsModal({
    super.key,
    this.initialTabIndex = 0,
  });

  /// Método estático conveniente para abrir el modal desde cualquier pantalla
  static Future<void> show(BuildContext context, {int initialTab = 0}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => LegalTermsModal(initialTabIndex: initialTab),
    );
  }

  @override
  State<LegalTermsModal> createState() => _LegalTermsModalState();
}

class _LegalTermsModalState extends State<LegalTermsModal>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 2),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;

    return Container(
      height: size.height * 0.88,
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 25,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        children: [
          // Tirador superior (drag handle)
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 44,
            height: 5,
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : Colors.grey[300],
              borderRadius: BorderRadius.circular(3),
            ),
          ),

          // Cabecera con Logo y Botón Cerrar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                const BodeGoLogoWidget(
                  size: 28,
                  withBackground: true,
                  borderRadius: 6,
                ),
                const SizedBox(width: 10),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'BodeGo Legal & Privacidad',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Tecnología e Innovación EddamCore',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                  tooltip: 'Cerrar',
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Barra de Pestañas
          TabBar(
            controller: _tabController,
            labelColor: const Color(0xFF4353FF),
            unselectedLabelColor: isDark ? Colors.white60 : Colors.grey[600],
            indicatorColor: const Color(0xFF4353FF),
            indicatorWeight: 3,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 13),
            tabs: const [
              Tab(
                icon: Icon(Icons.gavel_rounded, size: 20),
                text: 'Términos',
              ),
              Tab(
                icon: Icon(Icons.privacy_tip_outlined, size: 20),
                text: 'Privacidad',
              ),
              Tab(
                icon: Icon(Icons.verified_user_outlined, size: 20),
                text: 'EddamCore',
              ),
            ],
          ),

          // Contenido de las Pestañas
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildTermsTab(context),
                _buildPrivacyTab(context),
                _buildEddamCoreTab(context),
              ],
            ),
          ),

          // Botón inferior "Entendido y Aceptar"
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : Colors.white,
              border: Border(
                top: BorderSide(
                  color: isDark ? Colors.white12 : Colors.grey.withOpacity(0.2),
                ),
              ),
            ),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4353FF),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'He leído y Acepto los Términos',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // PESTAÑA 1: TÉRMINOS Y CONDICIONES
  // ==========================================
  Widget _buildTermsTab(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLegalHeaderBadge(
            title: 'Términos y Condiciones de Uso',
            subtitle:
                'Última actualización: Noviembre 2026 • Versión ${AppVersionService.versionName} Oficial',
            icon: Icons.article_outlined,
            color: const Color(0xFF4353FF),
          ),
          const SizedBox(height: 16),
          _buildLegalSection(
            number: '1',
            title: 'Aceptación y Licencia de Uso',
            body:
                'Al instalar y utilizar la aplicación BodeGo, usted adquiere una licencia de software comercial no exclusiva, intransferible y revocable, vinculada al identificador digital del dispositivo (Machine ID). La licencia habilita la operación de punto de venta, inventarios, cobros y arqueos en bodegas, minimarkets y comercios afines dentro del territorio nacional.',
          ),
          _buildLegalSection(
            number: '2',
            title: 'Naturaleza del Software y Operación Offline-First',
            body:
                'BodeGo opera bajo una arquitectura desconectada (Offline-First). El inventario, ventas, turnos de caja y libreta de fiados se procesan y almacenan en la memoria local del terminal mediante Isar Database. La aplicación garantiza operatividad total continua sin requerir conexión a internet ni depender de servidores centrales para cobrar o registrar productos.',
          ),
          _buildLegalSection(
            number: '3',
            title: 'Responsabilidad Contable y Comprobantes de Pago (SUNAT)',
            body:
                'BodeGo emite tickets de control interno y boletas operativas aptas para impresión térmica de 58mm y 80mm. La aplicación NO actúa como Proveedor de Servicios Electrónicos (PSE) ni Operador de Servicios Electrónicos (OSE) homologado ante la SUNAT. El titular del negocio o contribuyente registrado con RUC es el único y exclusivo responsable legal de la fijación de precios, la veracidad de sus ventas, la custodia de sus comprobantes y la declaración y pago de sus obligaciones tributarias conforme a su régimen fiscal (Nuevo RUS, Régimen MYPE Tributario o Régimen General).',
          ),
          _buildLegalSection(
            number: '4',
            title: 'Respaldo Cloud y Soberanía de la Información',
            body:
                'El módulo opcional de sincronización y respaldo se conecta directamente a una Hoja de Cálculo privada dentro del Google Drive personal del titular (arquitectura aislada por negocio). El comerciante mantiene el 100% de la propiedad y custodia de sus copias de seguridad. La seguridad física del dispositivo y de las credenciales de la cuenta de Google asociada es responsabilidad exclusiva del usuario.',
          ),
          _buildLegalSection(
            number: '5',
            title: 'Propiedad Intelectual y Restricciones',
            body:
                'La arquitectura del software, código fuente, algoritmos, interfaces vectoriales, logotipos y marcas asociadas a BodeGo y EddamCore son propiedad intelectual exclusiva de EddamCore Technologies. Queda terminantemente prohibida su descompilación, ingeniería inversa, distribución no autorizada o modificación de su lógica.',
          ),
          _buildLegalSection(
            number: '6',
            title: 'Limitación de Responsabilidad y Hardware',
            body:
                'EddamCore proporciona el software "tal cual". En ningún caso la empresa será responsable por daños indirectos, pérdida física de hardware, rotura de terminales móviles, extravío de claves de acceso o discrepancias de caja derivadas de omisiones u errores humanos del operador.',
          ),
        ],
      ),
    );
  }

  // ==========================================
  // PESTAÑA 2: POLÍTICA DE PRIVACIDAD
  // ==========================================
  Widget _buildPrivacyTab(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLegalHeaderBadge(
            title: 'Política de Privacidad y Datos',
            subtitle: 'Compromiso estricto de confidencialidad, soberanía local y Ley N° 29733',
            icon: Icons.shield_outlined,
            color: const Color(0xFF00D084),
          ),
          const SizedBox(height: 16),
          _buildLegalSection(
            number: '1',
            title: 'Principio de Privacidad Local (Cero Rastreo Comercial)',
            body:
                'En BodeGo creemos firmemente que la información de su negocio le pertenece únicamente a usted. No recopilamos, no comercializamos, no monetizamos ni compartimos su catálogo de productos, precios de costo, márgenes de ganancia, ventas diarias ni nombres de clientes fiados con ninguna corporación externa sin su consentimiento explícito.',
          ),
          _buildLegalSection(
            number: '2',
            title: 'Permisos del Dispositivo y Uso Estricto Justificado',
            body:
                'BodeGo solicita únicamente los permisos estrictamente indispensables para la operatividad del punto de venta:\n'
                '• Cámara del Dispositivo: Utilizada exclusivamente por el lector óptico para escanear códigos de barras (EAN-13, QR) al registrar o vender productos. No captura fotografías personales ni transmite video.\n'
                '• Bluetooth y Dispositivos Cercanos: Empleado exclusivamente para emparejar y enviar comandos de impresión ESC/POS a impresoras térmicas de tickets (58mm y 80mm).\n'
                '• Red Local y Wi-Fi: Utilizado por el servidor embebido (puerto 8080) para la vinculación P2P directa entre terminales de la misma tienda (dueño y cajeros) y para la sincronización con Google Drive.\n'
                '• Almacenamiento Local: Para guardar la base de datos interna y exportar reportes de cierre Z y arqueos de caja en formato PDF.',
          ),
          _buildLegalSection(
            number: '3',
            title: 'Criptografía de PINs de Cajeros y Control de Accesos',
            body:
                'El acceso a las funciones de cobro y turno está resguardado por PIN de 4 dígitos para cajeros y contraseña para el Administrador. Al sincronizar con la nube, cada PIN se almacena cifrado bajo el estándar criptográfico HMAC-SHA256 con salt aleatorio exclusivo del negocio (ENC:...), imposibilitando su lectura en texto plano aún abriendo la hoja de cálculo.',
          ),
          _buildLegalSection(
            number: '4',
            title: 'Seguridad en Google Sheets y Tokens de Negocio',
            body:
                'Toda petición de lectura, respaldo o actualización en Google Sheets viaja cifrada por HTTPS y firmada digitalmente con un Token Privado de Negocio (authToken + businessId). Las hojas de cálculo se configuran con advertencia de solo lectura en navegador para prevenir alteraciones accidentales fuera de la aplicación.',
          ),
          _buildLegalSection(
            number: '5',
            title: 'Cumplimiento Normativo (Ley N° 29733 de Perú)',
            body:
                'El tratamiento de los datos cumple con los principios de licitud, finalidad y proporcionalidad de la Ley N° 29733 (Ley de Protección de Datos Personales del Perú), garantizando al titular el pleno ejercicio de sus derechos de acceso, rectificación, cancelación y oposición (derechos ARCO).',
          ),
        ],
      ),
    );
  }

  // ==========================================
  // PESTAÑA 3: ACERCA DE EDDAMCORE
  // ==========================================
  Widget _buildEddamCoreTab(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF4353FF).withOpacity(0.12),
              border: Border.all(
                color: const Color(0xFF4353FF).withOpacity(0.3),
                width: 2,
              ),
            ),
            child: const Icon(
              Icons.rocket_launch_rounded,
              size: 40,
              color: Color(0xFF4353FF),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'BodeGo POS',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF00D084).withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Versión ${AppVersionService.versionName} Oficial',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Color(0xFF00D084),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? Colors.white12 : Colors.grey.withOpacity(0.2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.hub_rounded, size: 20, color: Color(0xFF4353FF)),
                    SizedBox(width: 8),
                    Text(
                      'Desarrollado y Respaldado por:',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'EddamCore Technologies',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Empresa de ingeniería y tecnología especializada en software de alta disponibilidad, sistemas comerciales offline-first e interfaces ultra fluidas para el sector comercio y retail.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isDark ? Colors.white70 : Colors.black87,
                    height: 1.4,
                  ),
                ),
                const Divider(height: 24),
                _buildContactRow(
                  icon: Icons.language_rounded,
                  label: 'Sitio Web Oficial:',
                  value: 'https://eddamcore.com',
                ),
                const SizedBox(height: 8),
                _buildContactRow(
                  icon: Icons.email_outlined,
                  label: 'Soporte y Consultas:',
                  value: 'contacto@eddamcore.com',
                ),
                const SizedBox(height: 8),
                _buildContactRow(
                  icon: Icons.location_on_outlined,
                  label: 'Sede Principal:',
                  value: 'Cusco, Perú',
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            '© 2026 EddamCore. Todos los derechos reservados.\nDiseñado con orgullo para los bodegueros y minimarkets del Perú.',
            style: TextStyle(
              fontSize: 11,
              height: 1.5,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  // --- Helpers de Diseño de Contenido Legal ---

  Widget _buildLegalHeaderBadge({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 10.5, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegalSection({
    required String number,
    required String title,
    required String body,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: const BoxDecoration(
                  color: Color(0xFF4353FF),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    number,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 32.0),
            child: Text(
              body,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.45,
                color: Colors.grey[700],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 11.5, color: Colors.grey),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Color(0xFF4353FF),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

