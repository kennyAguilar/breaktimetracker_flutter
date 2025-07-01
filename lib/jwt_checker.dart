import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';

// Herramienta para verificar la validez del JWT de Supabase
void main() async {
  await dotenv.load(fileName: ".env");

  final supabaseUrl = dotenv.env['SUPABASE_URL'];
  final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'];

  print("🔍 Verificando JWT de Supabase...");
  print("URL: $supabaseUrl");

  if (supabaseAnonKey == null) {
    print("❌ ERROR: No se encontró SUPABASE_ANON_KEY en .env");
    return;
  }

  // Verificar formato básico del JWT
  final parts = supabaseAnonKey.split('.');
  if (parts.length != 3) {
    print(
      "❌ ERROR: JWT no tiene el formato correcto (debe tener 3 partes separadas por '.')",
    );
    return;
  }

  try {
    // Decodificar el header
    final headerDecoded = utf8.decode(base64Url.decode(_padBase64(parts[0])));
    final header = jsonDecode(headerDecoded);
    print("✅ Header JWT: $header");

    // Decodificar el payload
    final payloadDecoded = utf8.decode(base64Url.decode(_padBase64(parts[1])));
    final payload = jsonDecode(payloadDecoded);
    print("✅ Payload JWT: $payload");

    // Verificar campos importantes
    final iss = payload['iss'];
    final role = payload['role'];
    final exp = payload['exp'];
    final ref = payload['ref'];

    print("\n📋 Campos del JWT:");
    print("   Issuer (iss): $iss");
    print("   Role: $role");
    print("   Ref: $ref");
    print(
      "   Expires: ${exp != null ? DateTime.fromMillisecondsSinceEpoch(exp * 1000).toIso8601String() : 'No especificado'}",
    );

    // Verificar si el JWT ha expirado
    if (exp != null) {
      final expirationDate = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
      final now = DateTime.now();
      if (now.isAfter(expirationDate)) {
        print(
          "❌ ADVERTENCIA: El JWT ha expirado el ${expirationDate.toIso8601String()}",
        );
      } else {
        print("✅ JWT válido hasta: ${expirationDate.toIso8601String()}");
      }
    }

    // Verificar consistencia con URL
    if (supabaseUrl != null && ref != null) {
      if (supabaseUrl.contains(ref)) {
        print("✅ URL y referencia del JWT coinciden");
      } else {
        print(
          "⚠️ ADVERTENCIA: La URL ($supabaseUrl) no coincide con la referencia del JWT ($ref)",
        );
      }
    }
  } catch (e) {
    print("❌ ERROR decodificando JWT: $e");
    print("💡 Verifica que el JWT sea válido y no esté corrupto");
  }
}

String _padBase64(String base64) {
  // Agregar padding si es necesario
  final mod = base64.length % 4;
  if (mod != 0) {
    base64 += '=' * (4 - mod);
  }
  return base64;
}
