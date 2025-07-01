import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/intl.dart';

// VERSIÓN SIMPLIFICADA - USA HORA DEL DISPOSITIVO
// El dispositivo estará fijo en Punta Arenas, configurado por la empresa
// y protegido con clave para evitar cambios no autorizados

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: ".env");
    print("✅ Archivo .env cargado correctamente");

    final supabaseUrl = dotenv.env['SUPABASE_URL'];
    final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'];

    if (supabaseUrl == null || supabaseAnonKey == null) {
      print("❌ Error: Variables de entorno no encontradas");
    } else {
      print("✅ Inicializando Supabase...");
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
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.amber,
        primaryColor: Colors.amber,
        scaffoldBackgroundColor: const Color(0xFF1E293B),
        // ... resto del tema igual
      ),
      home: const CardEntryExitPage(),
      debugShowCheckedModeBanner: false,
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
  List<String> _personalEnDescanso = [];
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _fetchPersonalEnDescanso();
    _refreshTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) {
        _fetchPersonalEnDescanso();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  // SIMPLIFICADO: Solo obtener hora actual del dispositivo
  DateTime _getCurrentTime() {
    return DateTime.now();
  }

  // SIMPLIFICADO: Formatear para mostrar al usuario
  String _formatTime(DateTime dateTime) {
    return DateFormat('dd/MM/yyyy HH:mm:ss').format(dateTime);
  }

  Future<void> _fetchPersonalEnDescanso() async {
    try {
      final response = await Supabase.instance.client
          .from('descansos')
          .select('usuarios(nombre)')
          .eq('tipo', 'Pendiente');

      if (mounted) {
        final names =
            (response as List)
                .map(
                  (item) =>
                      item['usuarios']?['nombre'] as String? ?? 'Desconocido',
                )
                .toList();
        setState(() {
          _personalEnDescanso = names;
        });
      }
    } catch (e) {
      print("Error al obtener personal en descanso: $e");
    }
  }

  Future<void> _handleInput(String rawValue) async {
    final raw = rawValue.trim();
    final code = raw.replaceAll(RegExp(r'^;|\?\$'), '');
    _controller.clear();
    setState(() => _processing = true);

    try {
      final supabase = Supabase.instance.client;
      print("🔍 Buscando usuario con código: $code");

      // Buscar usuario
      List<Map<String, dynamic>> userResponse = await supabase
          .from('usuarios')
          .select('*')
          .eq('tarjeta', code);

      if (userResponse.isEmpty) {
        userResponse = await supabase
            .from('usuarios')
            .select('*')
            .eq('codigo', code.toUpperCase());
      }

      if (userResponse.isEmpty) {
        if (mounted) {
          _showResponseMessage(
            context,
            'Usuario no encontrado',
            isSuccess: false,
          );
        }
        setState(() => _processing = false);
        return;
      }

      final user = userResponse.first;
      final userId = user['id'] as String;
      final userName = user['nombre'] as String;
      print("👤 Usuario encontrado: $userName (ID: $userId)");

      // Verificar descanso activo
      final descansosResponse = await supabase
          .from('descansos')
          .select('*')
          .eq('usuario_id', userId)
          .eq('tipo', 'Pendiente');

      if (descansosResponse.isNotEmpty) {
        // SALIDA DE DESCANSO
        final descansoActivo = descansosResponse.first;
        print("🚪 PROCESANDO SALIDA DE DESCANSO");

        final success = await _cerrarDescansoUsuario(userId, descansoActivo);

        if (success['success']) {
          if (mounted) {
            _showResponseMessage(
              context,
              '✅ $userName - Salida registrada (${success['mensaje']})',
              isSuccess: true,
            );
          }
        } else {
          if (mounted) {
            _showResponseMessage(
              context,
              '❌ Error al registrar salida de $userName: ${success['mensaje']}',
              isSuccess: false,
            );
          }
        }
      } else {
        // ENTRADA A DESCANSO - SIMPLIFICADO
        print("🚪 PROCESANDO ENTRADA A DESCANSO");
        try {
          final horaLocal = _getCurrentTime();
          final horaUTC = horaLocal.toUtc();

          print("🕐 Hora local (dispositivo): ${_formatTime(horaLocal)}");
          print("🕐 Hora UTC para BD: ${horaUTC.toIso8601String()}");

          await supabase.from('descansos').insert({
            'usuario_id': userId,
            'inicio': horaUTC.toIso8601String(),
            'tipo': 'Pendiente',
          });

          if (mounted) {
            _showResponseMessage(
              context,
              '🟢 $userName - Entrada a descanso registrada a las ${DateFormat('HH:mm').format(horaLocal)}',
            );
          }
        } catch (e) {
          print("❌ Error registrando entrada: $e");
          if (mounted) {
            _showResponseMessage(
              context,
              'Error al registrar entrada: $e',
              isSuccess: false,
            );
          }
        }
      }
    } catch (e) {
      print("❌ Error en _handleInput: $e");
      if (mounted) {
        _showResponseMessage(context, 'Error: $e', isSuccess: false);
      }
    }

    setState(() => _processing = false);
    _fetchPersonalEnDescanso();
  }

  // SIMPLIFICAR función de cierre de descanso
  Future<Map<String, dynamic>> _cerrarDescansoUsuario(
    String usuarioId,
    Map<String, dynamic> descansoActivo,
  ) async {
    try {
      print("🔄 Iniciando proceso de cierre para usuario ID: $usuarioId");

      // SIMPLIFICADO: Cálculo de duración
      final inicioStr = descansoActivo['inicio'] as String;

      // Limpiar formato de fecha
      String fechaLimpia = inicioStr;
      if (fechaLimpia.contains('+00:00Z')) {
        fechaLimpia = fechaLimpia.replaceAll('+00:00Z', 'Z');
      } else if (!fechaLimpia.endsWith('Z') && !fechaLimpia.contains('+')) {
        fechaLimpia = '${fechaLimpia}Z';
      }

      // SIMPLIFICADO: Usar hora del dispositivo
      final inicio =
          DateTime.parse(
            fechaLimpia,
          ).toLocal(); // Convertir a hora local del dispositivo
      final fin = _getCurrentTime(); // Hora actual del dispositivo
      final finUTC = fin.toUtc(); // Para guardar en BD

      final duracionMinutos = fin.difference(inicio).inMinutes;
      final tipo = duracionMinutos >= 30 ? 'COMIDA' : 'DESCANSO';

      print("   ⏰ Inicio: ${_formatTime(inicio)}");
      print("   ⏰ Fin: ${_formatTime(fin)}");
      print("   ⏱️ Duración: $duracionMinutos minutos → $tipo");

      // Datos para tiempos_descanso
      final tiempoData = {
        'usuario_id': usuarioId,
        'tipo': tipo,
        'fecha': DateFormat('yyyy-MM-dd').format(inicio),
        'inicio': DateFormat('HH:mm:ss').format(inicio),
        'fin': DateFormat('HH:mm:ss').format(fin),
        'duracion_minutos': duracionMinutos,
      };

      // Insertar y eliminar
      await Supabase.instance.client
          .from('tiempos_descanso')
          .insert(tiempoData);
      await Supabase.instance.client
          .from('descansos')
          .delete()
          .eq('id', descansoActivo['id']);

      final successMsg = "Descanso cerrado: $tipo de $duracionMinutos min";
      print("   ✅ ÉXITO: $successMsg");

      return {
        'success': true,
        'mensaje': successMsg,
        'tipo': tipo,
        'duracion_minutos': duracionMinutos,
      };
    } catch (e) {
      final errorMsg = "Error cerrando descanso: $e";
      print("   ❌ ERROR: $errorMsg");
      return {'success': false, 'mensaje': errorMsg};
    }
  }

  void _showResponseMessage(
    BuildContext context,
    String message, {
    bool isSuccess = true,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isSuccess ? Colors.green : Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ... mismo UI que antes
    return Scaffold(
      appBar: AppBar(title: const Text('BreakTime Tracker - Simplificado')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _controller,
              decoration: const InputDecoration(
                labelText: 'Deslice la tarjeta',
                hintText: 'Esperando tarjeta...',
              ),
              onSubmitted: _handleInput,
            ),
          ),
          if (_processing) const CircularProgressIndicator(),
          Expanded(
            child: ListView(
              children: [
                const ListTile(title: Text('Personal en Descanso:')),
                ..._personalEnDescanso.map(
                  (nombre) => ListTile(
                    leading: const Icon(Icons.person, color: Colors.amber),
                    title: Text(nombre),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
