import 'dart:convert';

void main() {
  // JWT proporcionado por el usuario
  const jwt =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBweW93ZGF2c2JraHZ4enZhdml5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTA5MTU4NjMsImV4cCI6MjA2NjQ5MTg2M30.ZFfAvT5icazQ1yh_JFYbQ-xbMunPJ8Q4Y47SpWWID2s';

  print('🔍 ANÁLISIS DE JWT - SUPABASE');
  print('=' * 50);

  try {
    // Dividir el JWT en sus partes
    final parts = jwt.split('.');

    if (parts.length != 3) {
      print('❌ ERROR: JWT inválido, debe tener 3 partes separadas por puntos');
      return;
    }

    print('✅ JWT tiene el formato correcto (3 partes)');
    print('');

    // Analizar el header
    print('📋 HEADER:');
    final headerDecoded = _decodeBase64(parts[0]);
    final headerJson = jsonDecode(headerDecoded);
    print('   Algoritmo: ${headerJson['alg']}');
    print('   Tipo: ${headerJson['typ']}');
    print('');

    // Analizar el payload
    print('📦 PAYLOAD:');
    final payloadDecoded = _decodeBase64(parts[1]);
    final payloadJson = jsonDecode(payloadDecoded);

    print('   Emisor (iss): ${payloadJson['iss']}');
    print('   Referencia (ref): ${payloadJson['ref']}');
    print('   Rol (role): ${payloadJson['role']}');

    // Analizar fechas
    if (payloadJson.containsKey('iat')) {
      final iat = payloadJson['iat'] as int;
      final issuedAt = DateTime.fromMillisecondsSinceEpoch(iat * 1000);
      print('   Emitido en (iat): $issuedAt');
    }

    if (payloadJson.containsKey('exp')) {
      final exp = payloadJson['exp'] as int;
      final expiresAt = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
      final now = DateTime.now();
      final isExpired = now.isAfter(expiresAt);

      print('   Expira en (exp): $expiresAt');
      print('   Fecha actual: $now');
      print('   ¿Expirado?: ${isExpired ? "❌ SÍ" : "✅ NO"}');

      if (!isExpired) {
        final timeLeft = expiresAt.difference(now);
        print(
          '   Tiempo restante: ${timeLeft.inDays} días, ${timeLeft.inHours % 24} horas',
        );
      }
    }

    print('');
    print('🔐 SIGNATURE:');
    print('   Longitud: ${parts[2].length} caracteres');
    print('   Primeros 20 chars: ${parts[2].substring(0, 20)}...');

    print('');
    print('🎯 DIAGNÓSTICO:');

    // Verificaciones específicas para Supabase
    if (payloadJson['iss'] == 'supabase') {
      print('   ✅ Emisor correcto (supabase)');
    } else {
      print('   ❌ Emisor incorrecto, debería ser "supabase"');
    }

    if (payloadJson['role'] == 'anon') {
      print('   ✅ Rol correcto (anon)');
    } else {
      print('   ❌ Rol incorrecto, debería ser "anon"');
    }

    final ref = payloadJson['ref'] as String;
    if (ref == 'ppyowdavsbkhvxzvaviy') {
      print('   ✅ Referencia del proyecto coincide con la URL');
    } else {
      print('   ⚠️  Referencia del proyecto: $ref');
    }

    print('');
    print('🌐 URL CONSTRUIDA:');
    print('   https://$ref.supabase.co');
  } catch (e) {
    print('❌ ERROR al analizar JWT: $e');
  }
}

String _decodeBase64(String base64) {
  // Base64 URL decode
  String normalized = base64.replaceAll('-', '+').replaceAll('_', '/');

  // Agregar padding si es necesario
  while (normalized.length % 4 != 0) {
    normalized += '=';
  }

  final bytes = base64Decode(normalized);
  return utf8.decode(bytes);
}
