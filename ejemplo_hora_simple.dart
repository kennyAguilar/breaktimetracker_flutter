// Ejemplo de cómo sería usando hora del dispositivo directamente
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class EjemploHoraSimple {
  // Versión SIMPLE - usar hora del dispositivo
  DateTime _getHoraActual() {
    return DateTime.now(); // Hora local del dispositivo
  }

  // Para mostrar al usuario
  String _formatearHora(DateTime fecha) {
    return DateFormat('dd/MM/yyyy HH:mm:ss').format(fecha);
  }

  // Para enviar a Supabase (convertir a UTC)
  DateTime _convertirAUTC(DateTime horaLocal) {
    return horaLocal.toUtc();
  }

  // Ejemplo de uso en registro de entrada
  Future<void> registrarEntrada(String usuarioId) async {
    final horaLocal = _getHoraActual();
    final horaUTC = _convertirAUTC(horaLocal);

    print("Hora local dispositivo: ${_formatearHora(horaLocal)}");
    print("Hora UTC para BD: ${horaUTC.toIso8601String()}");

    // Insertar en BD
    await Supabase.instance.client.from('descansos').insert({
      'usuario_id': usuarioId,
      'inicio': horaUTC.toIso8601String(),
      'tipo': 'Pendiente',
    });
  }

  // Ejemplo de cálculo de duración
  int calcularDuracion(DateTime inicio, DateTime fin) {
    return fin.difference(inicio).inMinutes;
  }
}

// Ventajas del enfoque simple:
// ✅ Menos código
// ✅ Más fácil de entender
// ✅ Menos dependencias (no necesita timezone package)
// ✅ Hora automática del dispositivo

// Desventajas del enfoque simple:
// ❌ Depende de que todos los dispositivos estén bien configurados
// ❌ No hay control sobre la zona horaria
// ❌ Problemas si alguien viaja o cambia zona horaria
// ❌ Menos precisión empresarial
