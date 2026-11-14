import 'dart:io';
import 'package:flutter/material.dart';
import 'package:bodego/core/services/app_version_service.dart';
import 'package:bodego/core/services/ota_update_service.dart';
import 'package:bodego/data/models/ota_update_info.dart';

/// Modal Bottom Sheet moderno para notificar e instalar actualizaciones OTA.
/// 
/// Cumple con las reglas de negocio:
/// - Avisos 1 y 2: No bloqueante con opción "Recordar más tarde".
/// - Aviso 3 o si [isMandatory]: Bloqueante (canPop: false), obligando a actualizar.
/// - Barra de progreso en tiempo real (bytes descargados y porcentaje).
/// - Al terminar, invoca el instalador nativo de Android.
class OtaUpdateModal extends StatefulWidget {
  final OtaCheckResult checkResult;

  const OtaUpdateModal({
    super.key,
    required this.checkResult,
  });

  /// Muestra el modal asegurando que si es mandatorio no se pueda descartar
  static Future<void> show(BuildContext context, OtaCheckResult result) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: !result.isMandatory,
      enableDrag: !result.isMandatory,
      backgroundColor: Colors.transparent,
      builder: (ctx) => OtaUpdateModal(checkResult: result),
    );
  }

  @override
  State<OtaUpdateModal> createState() => _OtaUpdateModalState();
}

enum _DownloadState { idle, downloading, completed, error }

class _OtaUpdateModalState extends State<OtaUpdateModal> {
  _DownloadState _state = _DownloadState.idle;
  double _progress = 0.0;
  int _downloadedBytes = 0;
  int _totalBytes = 0;
  String? _errorMessage;
  String? _downloadedFilePath;

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0.0 MB';
    final mb = bytes / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} MB';
  }

  Future<void> _startDownload() async {
    setState(() {
      _state = _DownloadState.downloading;
      _progress = 0.0;
      _errorMessage = null;
    });

    try {
      final file = await OtaUpdateService.downloadApk(
        widget.checkResult.updateInfo.downloadUrl,
        onProgress: (progress, downloaded, total) {
          if (mounted) {
            setState(() {
              _progress = progress;
              _downloadedBytes = downloaded;
              _totalBytes = total;
            });
          }
        },
      );

      if (mounted) {
        setState(() {
          _downloadedFilePath = file.path;
          _state = _DownloadState.completed;
        });

        // Intentamos abrir inmediatamente el instalador nativo de Android
        _triggerInstall(file.path);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _state = _DownloadState.error;
          _errorMessage = 'No se pudo completar la descarga. Verifica tu conexión.';
        });
      }
    }
  }

  Future<void> _triggerInstall(String path) async {
    try {
      await OtaUpdateService.installApk(path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al abrir instalador: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  void _handleDismiss() {
    OtaUpdateService.recordDismiss(widget.checkResult.updateInfo.latestVersion);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final sheetBg = isDark ? colorScheme.surface : colorScheme.background;
    final cardBg = isDark
        ? colorScheme.background
        : colorScheme.surface.withOpacity(0.45);
    final borderColor = colorScheme.onSurface.withOpacity(0.08);

    final info = widget.checkResult.updateInfo;
    final isMandatory = widget.checkResult.isMandatory;
    final currentVer = AppVersionService.versionName;
    final newVer = info.latestVersion;

    return PopScope(
      canPop: !isMandatory && _state != _DownloadState.downloading,
      child: Container(
        decoration: BoxDecoration(
          color: sheetBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.5 : 0.15),
              blurRadius: 28,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Manija superior (oculta si es mandatorio o descargando)
                if (!isMandatory && _state != _DownloadState.downloading)
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: colorScheme.onSurface.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  )
                else
                  const SizedBox(height: 12),

                // 2. Cabecera con Icono y Versiones
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            colorScheme.primary,
                            Color.lerp(colorScheme.primary, Colors.black, 0.2) ??
                                colorScheme.primary,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: colorScheme.primary.withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Icon(
                        _state == _DownloadState.completed
                            ? Icons.verified_rounded
                            : Icons.rocket_launch_rounded,
                        color: colorScheme.onPrimary,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Actualización OTA',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                              const Spacer(),
                              // Badge de Obligatoriedad o Conteo
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: isMandatory
                                      ? colorScheme.error.withOpacity(0.12)
                                      : colorScheme.primary.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  isMandatory
                                      ? '⚠️ OBLIGATORIA'
                                      : 'Aviso ${widget.checkResult.dismissCount} de 3',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                    color: isMandatory
                                        ? colorScheme.error
                                        : colorScheme.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          // Comparativa de versión
                          Row(
                            children: [
                              Text(
                                'v$currentVer',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: colorScheme.onSurface.withOpacity(0.55),
                                ),
                              ),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 6),
                                child: Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 14,
                                  color: colorScheme.primary,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 1.5,
                                ),
                                decoration: BoxDecoration(
                                  color: colorScheme.primary,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'v$newVer Nueva',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.onPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 3. Notas de la Versión (Changelog)
                if (info.releaseNotes.isNotEmpty &&
                    _state != _DownloadState.downloading) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.new_releases_rounded,
                              size: 16,
                              color: colorScheme.primary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Novedades y Mejoras:',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ...info.releaseNotes.map(
                          (note) => Padding(
                            padding: const EdgeInsets.only(bottom: 5),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '• ',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.primary,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    note,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      height: 1.3,
                                      color: colorScheme.onSurface
                                          .withOpacity(0.8),
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
                  const SizedBox(height: 16),
                ],

                // 4. Sección de Progreso o Error
                if (_state == _DownloadState.downloading) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Descargando paquete oficial...',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: colorScheme.onSurface,
                              ),
                            ),
                            Text(
                              '${(_progress * 100).toInt()}%',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        // Barra de progreso estilizada
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: _progress > 0 ? _progress : null,
                            minHeight: 10,
                            backgroundColor:
                                colorScheme.onSurface.withOpacity(0.1),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              colorScheme.primary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${_formatBytes(_downloadedBytes)} de ${_formatBytes(_totalBytes)}',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: colorScheme.onSurface.withOpacity(0.55),
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ] else if (_state == _DownloadState.completed) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00D084).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF00D084).withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: const [
                        Icon(
                          Icons.check_circle_rounded,
                          color: Color(0xFF00D084),
                          size: 22,
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Descarga lista. Toca el botón para abrir el instalador de Android.',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF00A86B),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ] else if (_state == _DownloadState.error) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorScheme.error.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      _errorMessage ?? 'Error al descargar la actualización',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: colorScheme.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // 5. Botones de Acción
                if (_state == _DownloadState.downloading) ...[
                  Center(
                    child: Text(
                      'Por favor, no cierres la aplicación mientras descarga.',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: colorScheme.onSurface.withOpacity(0.55),
                      ),
                    ),
                  ),
                ] else if (_state == _DownloadState.completed) ...[
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00D084),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.install_mobile_rounded),
                    label: const Text(
                      'Abrir Instalador de Android 📦',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    onPressed: () {
                      if (_downloadedFilePath != null) {
                        _triggerInstall(_downloadedFilePath!);
                      }
                    },
                  ),
                ] else ...[
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.download_rounded),
                    label: Text(
                      _state == _DownloadState.error
                          ? 'Reintentar Descarga 🚀'
                          : 'Descargar e Instalar v$newVer 🚀',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: _startDownload,
                  ),
                  if (!isMandatory) ...[
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _handleDismiss,
                      child: Text(
                        'Recordar más tarde',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

