import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../compartido/api/laravel_api.dart';
import '../../compartido/diseno/sakai_widgets.dart';
import '../mi_bandeja/detalle_laravel_page.dart';
import '../recorrido/recorrido_api.dart';

class ConsultaQrPage extends StatefulWidget {
  const ConsultaQrPage({
    super.key,
    required this.api,
    this.puedeAdjuntar = false,
  });
  final ApiLaravel api;
  final bool puedeAdjuntar;
  @override
  State<ConsultaQrPage> createState() => _ConsultaQrPageState();
}

class _ConsultaQrPageState extends State<ConsultaQrPage>
    with WidgetsBindingObserver {
  final _enlace = TextEditingController();
  final _camara = MobileScannerController(
    autoStart: false,
    formats: const [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  bool _vista = false,
      _abriendo = false,
      _consultando = false,
      _ajustes = false;
  String? _error;
  int _generacion = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_vista) return;
    if (state != AppLifecycleState.resumed) {
      _generacion++;
      unawaited(_detener());
    } else if (_vista && !_consultando) {
      unawaited(_abrir(solicitar: false));
    }
  }

  Future<void> _detener() async {
    try {
      await _camara.stop();
    } on MobileScannerException {
      /* La cámara puede estar cerrada. */
    }
  }

  Future<void> _abrir({bool solicitar = true}) async {
    if (_abriendo || _consultando) return;
    final generacion = ++_generacion;
    setState(() {
      _abriendo = true;
      _error = null;
      _ajustes = false;
    });
    try {
      var permiso = await Permission.camera.status;
      if (!permiso.isGranted && solicitar && !permiso.isPermanentlyDenied) {
        permiso = await Permission.camera.request();
      }
      if (!mounted) return;
      if (!permiso.isGranted) {
        setState(() {
          _vista = false;
          _ajustes = permiso.isPermanentlyDenied || permiso.isRestricted;
          _error = 'Permite usar la cámara para escanear el QR. También puedes pegar el enlace de la hoja.';
        });
        return;
      }
      setState(() => _vista = true);
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted || generacion != _generacion) return;
      await _camara.start();
      if (!mounted || generacion != _generacion) await _detener();
    } on MobileScannerException {
      if (mounted) {
        setState(() {
          _vista = false;
          _error = 'No se pudo abrir la cámara. Vuelve a intentar.';
        });
      }
    } finally {
      if (mounted) setState(() => _abriendo = false);
    }
  }

  Future<void> _consultar(String texto) async {
    if (_consultando) return;
    setState(() {
      _consultando = true;
      _error = null;
    });
    _generacion++;
    await _detener();
    try {
      final referencia = referenciaQr(texto, widget.api.baseUrl);
      final documento = await widget.api.enviar('GET', 'hojas/$referencia');
      final hoja = documento['hoja'];
      if (documento['id'] is! String ||
          hoja is! Map ||
          hoja['id'] != referencia) {
        throw const ErrorLaravel(
          'La respuesta no corresponde a la hoja consultada.',
        );
      }
      if (!mounted) return;
      setState(() => _vista = false);
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => DetalleLaravelPage(
            api: widget.api,
            id: documento['id'] as String,
            puedeAdjuntar: widget.puedeAdjuntar,
          ),
        ),
      );
    } on ErrorLaravel catch (e) {
      if (mounted) {
        setState(() {
          _error = e.mensaje;
          _vista = false;
        });
      }
    } finally {
      if (mounted) setState(() => _consultando = false);
    }
  }

  @override
  void dispose() {
    _generacion++;
    WidgetsBinding.instance.removeObserver(this);
    _enlace.dispose();
    unawaited(_camara.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Localizar por QR')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        SakaiSection(
          title: 'QR de la hoja de ruta',
          icon: Icons.qr_code_scanner,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Enfoca el QR completo, con buena luz y sin reflejos. Abrir la hoja permite consultarla; confirma la recepción desde su detalle cuando corresponda.',
              ),
              const SizedBox(height: 16),
              if (_vista)
                SizedBox(
                  height: 300,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: MobileScanner(
                      controller: _camara,
                      onDetect: (captura) {
                        for (final codigo in captura.barcodes) {
                          final valor = codigo.rawValue;
                          if (valor != null && !_consultando && !_abriendo) {
                            unawaited(_consultar(valor));
                            break;
                          }
                        }
                      },
                      errorBuilder: (context, error) => const Center(
                        child: Text(
                          'Cámara no disponible. Comprueba el permiso y vuelve a intentar.',
                        ),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _abriendo || _consultando ? null : _abrir,
                icon: const Icon(Icons.camera_alt_outlined),
                label: const Text('Abrir cámara para escanear'),
              ),
              if (_ajustes)
                TextButton(
                  onPressed: () => openAppSettings(),
                  child: const Text('Abrir ajustes de permisos'),
                ),
              if (_abriendo || _consultando) const LinearProgressIndicator(),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              const SizedBox(height: 24),
              TextField(
                controller: _enlace,
                readOnly: _consultando,
                decoration: const InputDecoration(
                  labelText: 'Enlace o identificador de la hoja',
                  helperText: 'Puedes pegar el enlace que contiene el QR.',
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _consultando || _abriendo
                    ? null
                    : () => _consultar(_enlace.text),
                child: const Text('Abrir hoja'),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
