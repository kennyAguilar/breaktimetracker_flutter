import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

// Asegúrate de tener un archivo `.env` en la raíz de tu proyecto con estas variables:
// SUPABASE_URL=https://ppyowdavsbkhvxzvaviy.supabase.co
// SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBweW93ZGF2c2JraHZ4enZhdml5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTA5MTU4NjMsImV4cCI6MjA2NjQ5MTg2M30.ZFfAvT5icazQ1yh_JFYbQ-xbMunPJ8Q4Y47SpWWID2s
// SECRET_KEY=SAAffKwZoAs0Qlwr
// TZ=America/Punta_Arenas

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: ".env");
    print("✅ Archivo .env cargado correctamente");

    final supabaseUrl = dotenv.env['SUPABASE_URL'];
    final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'];

    if (supabaseUrl == null || supabaseAnonKey == null) {
      print("❌ Error: Variables de entorno no encontradas");
      print("SUPABASE_URL: ${supabaseUrl ?? 'NO ENCONTRADA'}");
      print(
        "SUPABASE_ANON_KEY: ${supabaseAnonKey != null ? 'ENCONTRADA' : 'NO ENCONTRADA'}",
      );
    } else {
      print("✅ Inicializando Supabase...");
      print("URL: $supabaseUrl");
      print("Key: ${supabaseAnonKey.substring(0, 20)}...");

      await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
      print("✅ Supabase inicializado correctamente");
    }
  } catch (e) {
    print("❌ Error al inicializar: $e");
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BreakTime Tracker',
      theme: ThemeData.dark(),
      home: const CardEntryExitPage(),
    );
  }
}

class CardEntryExitPage extends StatefulWidget {
  const CardEntryExitPage({super.key});

  @override
  State<CardEntryExitPage> createState() => _CardEntryExitPageState();
}

class _CardEntryExitPageState extends State<CardEntryExitPage> {
  final TextEditingController _controller = TextEditingController();
  bool _processing = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lector de Tarjetas')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 20,
                  horizontal: 12,
                ),
                child: TextField(
                  controller: _controller,
                  autofocus: true,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Deslice la tarjeta o ingrese código',
                    hintText: 'Esperando tarjeta...',
                  ),
                  onSubmitted: _handleInput,
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (_processing) const CircularProgressIndicator(),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _testConnection,
              icon: const Icon(Icons.wifi_tethering),
              label: const Text('Probar Conexión'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleInput(String rawValue) async {
    final raw = rawValue.trim();
    final code = raw.replaceAll(RegExp(r'^;|\?\$'), '');
    _controller.clear();
    setState(() => _processing = true);

    try {
      final supabase = Supabase.instance.client;
      print("🔍 Buscando usuario con código: $code");

      // 1) Buscar usuario por tarjeta o código
      final userRes =
          await supabase
              .from('usuarios')
              .select('id,nombre')
              .or('tarjeta.eq.$code,codigo.eq.$code')
              .maybeSingle();

      print("📡 Respuesta de Supabase:");
      print("Data: $userRes");

      if (userRes == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Usuario no encontrado')),
          );
        }
        setState(() => _processing = false);
        return;
      }

      final user = userRes;
      final userId = user['id'] as String;
      print("✅ Usuario encontrado: ${user['nombre']} (ID: $userId)");

      // 2) Verificar si ya está en descanso (buscar TODOS los descansos activos)
      final descansosList = await supabase
          .from('descansos')
          .select('*')
          .eq('usuario_id', userId);

      print("🔍 Descansos activos encontrados: ${descansosList.length}");

      if (descansosList.isNotEmpty) {
        // Finalizar descanso usando la función _cerrarDescansoUsuario
        await _cerrarDescansoUsuario(userId, user['nombre']);
      } else {
        // Iniciar descanso
        await supabase.from('descansos').insert({
          'usuario_id': userId,
          'tipo': 'descanso',
          'inicio': DateTime.now().toUtc().toIso8601String(),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('🟢 Descanso iniciado para ${user['nombre']}'),
            ),
          );
        }
      }
    } catch (e) {
      print("❌ Error en _handleInput: $e");

      String errorMessage = 'Error: $e';

      if (e.toString().contains('401')) {
        errorMessage = '🔑 Error 401: Clave API inválida o proyecto incorrecto';
      } else if (e.toString().contains('404') ||
          e.toString().contains('relation') &&
              e.toString().contains('does not exist')) {
        errorMessage = '🔍 Tabla "usuarios" no encontrada en la base de datos';
      } else if (e.toString().contains('permission')) {
        errorMessage = '🚫 Sin permisos: Revisar políticas RLS en Supabase';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }

    setState(() => _processing = false);
  }

  Future<void> _testConnection() async {
    setState(() => _processing = true);

    try {
      final supabase = Supabase.instance.client;
      print("🧪 Probando conexión a Supabase...");

      // Prueba más básica: obtener información del servidor
      final response = await supabase.from('usuarios').select('*').limit(1);

      print("📊 Respuesta de prueba básica:");
      print("Data: $response");

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ Conexión exitosa! Datos obtenidos: ${response.length} registros',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      print("❌ Error en prueba de conexión: $e");

      String errorMessage = '❌ Error de conexión: $e';

      if (e.toString().contains('401')) {
        errorMessage =
            '🔑 Error 401: Clave API inválida\n\n'
                'La clave debe ser un JWT que empiece con "eyJ", no "sb_publishable_".\n' +
            'Busca en tu dashboard la clave "anon" o "public".';
      } else if (e.toString().contains('relation') &&
          e.toString().contains('does not exist')) {
        errorMessage =
            '🔍 La tabla "usuarios" no existe en la base de datos.\n'
            'Necesitas crear las tablas primero.';
      } else if (e.toString().contains('permission')) {
        errorMessage =
            '🚫 Sin permisos: Las políticas RLS bloquean el acceso.\n'
            'Configura las políticas de seguridad en Supabase.';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  errorMessage.split('\n').first,
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 4),
                Text('$e'),
                SizedBox(height: 8),
                Text(
                  '💡 Verifica que uses la clave JWT correcta (empieza con "eyJ")',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 10),
          ),
        );
      }
    }

    setState(() => _processing = false);
  }

  Future<void> _cerrarDescansoUsuario(String userId, String userName) async {
    try {
      final supabase = Supabase.instance.client;
      print("🔄 Cerrando descanso para usuario: $userName (ID: $userId)");

      // 1. Obtener todos los descansos activos del usuario
      final descansos = await supabase
          .from('descansos')
          .select('*')
          .eq('usuario_id', userId);

      if (descansos.isEmpty) {
        print("⚠️ No se encontraron descansos activos para cerrar");
        return;
      }

      print("📋 Procesando ${descansos.length} descanso(s) activo(s)");

      DateTime now = DateTime.now().toUtc();

      for (final descanso in descansos) {
        try {
          // 2. Parsear fecha de inicio con manejo robusto
          String inicioStr = descanso['inicio'] as String;

          // Limpiar el formato de fecha de Supabase
          // Remover 'Z' al final si existe y ya tiene zona horaria
          if (inicioStr.contains('+') && inicioStr.endsWith('Z')) {
            inicioStr = inicioStr.substring(0, inicioStr.length - 1);
          }

          DateTime inicio;
          try {
            inicio = DateTime.parse(inicioStr);
          } catch (e) {
            print("⚠️ Error parseando fecha '$inicioStr', usando regex...");
            // Fallback: limpiar con regex
            String cleanDate = inicioStr
                .replaceAll(RegExp(r'Z$'), '') // Remover Z final
                .replaceAll(
                  RegExp(r'\+00:00Z$'),
                  '+00:00',
                ); // Corregir formato inválido
            inicio = DateTime.parse(cleanDate);
          }

          print("🕐 Inicio del descanso: $inicio");

          // 3. Calcular duración
          Duration diferencia = now.difference(inicio);
          int duracionMinutos = diferencia.inMinutes;

          print("⏱️ Duración calculada: $duracionMinutos minutos");

          // 4. Determinar tipo de descanso (como en Python)
          String tipo;
          if (duracionMinutos >= 30) {
            tipo = 'COMIDA';
          } else {
            tipo = 'DESCANSO';
          }

          print("🏷️ Tipo de descanso determinado: $tipo");

          // 5. Insertar en tiempos_descanso
          final registroDescanso = {
            'usuario_id': userId,
            'tipo': tipo,
            'fecha':
                inicio
                    .toIso8601String()
                    .split('T')
                    .first, // Solo fecha YYYY-MM-DD
            'inicio': inicio.toIso8601String(),
            'fin': now.toIso8601String(),
            'duracion_minutos': duracionMinutos,
          };

          print("💾 Insertando registro: $registroDescanso");

          await supabase.from('tiempos_descanso').insert(registroDescanso);

          print("✅ Registro insertado en tiempos_descanso");

          // 6. Eliminar de descansos activos
          await supabase.from('descansos').delete().eq('id', descanso['id']);

          print("🗑️ Descanso eliminado de tabla 'descansos'");
        } catch (e) {
          print("❌ Error procesando descanso individual: $e");
          // Continuar con el siguiente descanso si hay error
        }
      }

      // 7. Mostrar mensaje de éxito
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Descanso finalizado para $userName'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }

      print("🎉 Proceso de cierre completado para $userName");
    } catch (e) {
      print("❌ Error en _cerrarDescansoUsuario: $e");

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error al finalizar descanso: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }
}
