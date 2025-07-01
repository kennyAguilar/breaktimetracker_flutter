import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: ".env");
    print("✅ Archivo .env cargado correctamente");

    final supabaseUrl = dotenv.env['SUPABASE_URL'];
    final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'];

    if (supabaseUrl == null || supabaseAnonKey == null) {
      print("❌ Error: Variables de entorno no encontradas");
      return;
    }

    print("🔗 Inicializando Supabase...");
    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
    print("✅ Supabase inicializado correctamente");

    await diagnosticoCompleto();
  } catch (e) {
    print("❌ Error en inicialización: $e");
  }
}

Future<void> diagnosticoCompleto() async {
  print('\n🔍 DIAGNÓSTICO COMPLETO DE SUPABASE');
  print('=' * 50);

  final client = Supabase.instance.client;

  // Test 1: Conexión básica
  print('\n1️⃣ PRUEBA DE CONEXIÓN BÁSICA');
  try {
    // Intentar una operación muy básica - obtener información de una tabla
    await client.from('usuarios').select('count').limit(0);
    print('✅ Conexión básica exitosa');
  } catch (e) {
    print('❌ Fallo en conexión básica: $e');
    // Continuar con las pruebas aunque falle la conexión básica
  }

  // Test 2: Verificar tabla usuarios
  print('\n2️⃣ VERIFICANDO TABLA "usuarios"');
  try {
    final response =
        await client
            .from('usuarios')
            .select('count')
            .single(); // Solo contar registros
    print('✅ Tabla "usuarios" accesible');
    print('📊 Respuesta: $response');
  } catch (e) {
    print('❌ Error con tabla "usuarios": $e');
    await _analizarError(e, 'usuarios');
  }

  // Test 3: Verificar tabla descansos
  print('\n3️⃣ VERIFICANDO TABLA "descansos"');
  try {
    final response = await client.from('descansos').select('count').single();
    print('✅ Tabla "descansos" accesible');
    print('📊 Respuesta: $response');
  } catch (e) {
    print('❌ Error con tabla "descansos": $e');
    await _analizarError(e, 'descansos');
  }

  // Test 4: Verificar tabla tiempos_descanso
  print('\n4️⃣ VERIFICANDO TABLA "tiempos_descanso"');
  try {
    final response =
        await client.from('tiempos_descanso').select('count').single();
    print('✅ Tabla "tiempos_descanso" accesible');
    print('📊 Respuesta: $response');
  } catch (e) {
    print('❌ Error con tabla "tiempos_descanso": $e');
    await _analizarError(e, 'tiempos_descanso');
  }

  // Test 5: Intentar consultas de ejemplo
  print('\n5️⃣ PRUEBAS DE CONSULTAS REALES');
  await _pruebaConsultasReales();

  print('\n✅ DIAGNÓSTICO COMPLETADO');
}

Future<void> _analizarError(dynamic e, String tabla) async {
  final errorStr = e.toString().toLowerCase();

  if (errorStr.contains('401')) {
    print('💡 Error 401: Problema de autenticación/autorización');
    print('   - Verificar que RLS esté configurado correctamente');
    print('   - La tabla "$tabla" puede requerir políticas específicas');
  } else if (errorStr.contains('404') ||
      (errorStr.contains('relation') && errorStr.contains('does not exist'))) {
    print('💡 Error 404: La tabla "$tabla" no existe');
    print('   - Crear la tabla en el editor de Supabase');
    print('   - Verificar que el nombre esté escrito correctamente');
  } else if (errorStr.contains('permission')) {
    print('💡 Error de permisos en tabla "$tabla"');
    print('   - Configurar política RLS para permitir SELECT público');
    print(
      '   - Ejemplo: CREATE POLICY "Enable read access for all users" ON $tabla FOR SELECT USING (true);',
    );
  } else {
    print('💡 Error desconocido: $e');
  }
}

Future<void> _pruebaConsultasReales() async {
  final client = Supabase.instance.client;

  // Intentar obtener usuarios
  try {
    final usuarios = await client
        .from('usuarios')
        .select('id, nombre, codigo, tarjeta')
        .limit(3);
    print('✅ Consulta usuarios exitosa: ${usuarios.length} registros');
    for (var usuario in usuarios) {
      print('   - ${usuario['nombre']} (${usuario['codigo']})');
    }
  } catch (e) {
    print('❌ Fallo consulta usuarios: $e');
  }

  // Intentar obtener descansos activos
  try {
    final descansos = await client
        .from('descansos')
        .select('usuarios(nombre)')
        .eq('tipo', 'Pendiente')
        .limit(5);
    print(
      '✅ Consulta descansos activos exitosa: ${descansos.length} registros',
    );
    for (var descanso in descansos) {
      final nombre = descanso['usuarios']?['nombre'] ?? 'Sin nombre';
      print('   - En descanso: $nombre');
    }
  } catch (e) {
    print('❌ Fallo consulta descansos: $e');
  }
}
