import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:loteria_push/dominio/contralodor.dart';

import '../dominio/api_juego.dart';
import '../dominio/partida.dart';
import '../dominio/puerto_push.dart';

class JuegoVm extends ChangeNotifier {
  JuegoVm(this.controlador) {
    _sub = controlador.cambios.listen((_) {
      if (!_disposed) {
        notifyListeners();
      }
    });
  }

  final ControladorPartida controlador;
  late final StreamSubscription<void> _sub;

  Timer? _consulta;

  String? mensaje;
  bool ocupado = false;

  bool _disposed = false;

  Partida? get partida => controlador.partida;
  bool get avisosActivos => controlador.avisosActivos;
  PermisoPush get permiso => controlador.permiso;

  /// Con la app lista: ¿hay una partida guardada?
  Future<void> iniciar() async {
    if (_disposed) return;

    await controlador.leerPermiso();

    if (_disposed) return;

    if (await controlador.restaurar()) {
      if (_disposed) return;
      _vigilar();
    }

    if (!_disposed) {
      notifyListeners();
    }
  }

  /// Sin push, la app revisa cada 5 segundos.
  void _vigilar() {
    if (_disposed) return;

    _consulta?.cancel();

    if (controlador.avisosActivos) return;

    _consulta = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!_disposed) {
        controlador.sincronizar();
      }
    });
  }

  Future<void> unirse({
    required String sala,
    required String nombre,
    required bool pedirAvisos,
  }) async {
    if (_disposed) return;

    ocupado = true;
    mensaje = null;
    notifyListeners();

    try {
      if (pedirAvisos) {
        await controlador.pedirPermisoAvisos();
      }

      if (_disposed) return;

      await controlador.unirse(sala: sala, nombre: nombre);

      if (_disposed) return;

      _vigilar();
    } on ErrorApi catch (e) {
      if (_disposed) return;

      mensaje = e.mensaje;
    } finally {
      if (!_disposed) {
        ocupado = false;
        notifyListeners();
      }
    }
  }

  Future<void> alVolverALaApp() async {
    if (_disposed) return;

    await controlador.sincronizar();
  }

  Future<void> cantarLoteria() async {
    if (_disposed) return;

    try {
      final r = await controlador.reclamarLoteria();

      if (_disposed) return;

      mensaje = r.gano
          ? '¡Ganaste! 🎉'
          : 'Todavía no tienes Lotería... ¡paciencia!';
    } on ErrorApi catch (e) {
      if (_disposed) return;

      mensaje = e.mensaje;
    }

    if (!_disposed) {
      notifyListeners();
    }
  }

  Future<void> salir() async {
    if (_disposed) return;

    _consulta?.cancel();
    _consulta = null;

    await controlador.salir();
  }

  @override
  void dispose() {
    _disposed = true;

    _consulta?.cancel();
    _consulta = null;

    _sub.cancel();

    super.dispose();
  }
}

class CantorVm extends ChangeNotifier {
  CantorVm(this.api);

  final ApiJuego api;

  SalaCreada? sala;

  final List<String> cantadas = [];

  String? mensaje;

  Timer? _auto;

  bool _disposed = false;

  bool get automatico => _auto != null;

  /// Crear una sala nueva.
  Future<void> crear() async {
    if (_disposed) return;

    try {
      final nuevaSala = await api.crearSala();

      if (_disposed) return;

      sala = nuevaSala;
      mensaje = null;
    } on ErrorApi catch (e) {
      if (_disposed) return;

      mensaje = e.mensaje;
    }

    if (!_disposed) {
      notifyListeners();
    }
  }

  /// Cantar la siguiente carta.
  Future<void> cantar() async {
    if (_disposed) return;

    final s = sala;

    if (s == null) return;

    try {
      final c = await api.cantar(s.id, s.claveCantor);

      if (_disposed) return;

      cantadas.insert(0, '${c.n}. ${c.nombre}');
      mensaje = null;
    } on ErrorApi catch (e) {
      if (_disposed) return;

      mensaje = e.mensaje;

      if (e.codigo == 'SALA_TERMINADA' || e.codigo == 'SIN_CARTAS') {
        detenerAutomatico();
      }
    }

    if (!_disposed) {
      notifyListeners();
    }
  }

  /// Activar o desactivar el canto automático.
  void alternarAutomatico() {
    if (_disposed) return;

    if (automatico) {
      detenerAutomatico();
    } else {
      _auto = Timer.periodic(const Duration(seconds: 6), (_) {
        if (!_disposed) {
          cantar();
        }
      });
    }

    if (!_disposed) {
      notifyListeners();
    }
  }

  /// Detener el canto automático.
  void detenerAutomatico() {
    _auto?.cancel();
    _auto = null;
  }

  @override
  void dispose() {
    _disposed = true;

    detenerAutomatico();

    super.dispose();
  }
}
