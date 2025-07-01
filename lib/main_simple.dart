import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:intl/intl.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar zonas horarias de forma segura
  try {
    tz.initializeTimeZones();
  } catch (e) {
    print("⚠️ Error inicializando zonas horarias: $e");
  }

  try {
    await dotenv.load(fileName: ".env");
    print("✅ Archivo .env cargado correctamente");

    final supabaseUrl = dotenv.env['SUPABASE_URL'];
    final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'];

    // Configurar la zona horaria de Chile de forma segura
    try {
      tz.setLocalLocation(tz.getLocation('America/Santiago'));
      print("🌎 Zona horaria configurada: America/Santiago");
    } catch (e) {
      try {
        tz.setLocalLocation(tz.getLocation('UTC'));
        print("⚠️ Usando UTC como zona horaria por defecto");
      } catch (e2) {
        print("❌ Error configurando zona horaria: $e2");
      }
    }

    if (supabaseUrl == null || supabaseAnonKey == null) {
      print("❌ Error: Variables de entorno no encontradas");
      print("SUPABASE_URL: ${supabaseUrl ?? 'NO ENCONTRADA'}");
      print("SUPABASE_ANON_KEY: ${supabaseAnonKey != null ? 'ENCONTRADA' : 'NO ENCONTRADA'}");
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
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.amber,
        primaryColor: Colors.amber,
        scaffoldBackgroundColor: const Color(0xFF1E293B),
        cardColor: const Color(0xFF334155),
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
    // Actualizar cada minuto
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

  Future<void> _fetchPersonalEnDescanso() async {
    try {
      final response = await Supabase.instance.client
          .from('descansos')
          .select('usuarios(nombre)')
          .eq('tipo', 'Pendiente');

      if (mounted) {
        final names = (response as List)
            .map((item) => item['usuarios']?['nombre'] as String? ?? 'Desconocido')
            .toList();
        setState(() {
          _personalEnDescanso = names;
        });
      }
    } catch (e) {
      print("Error al obtener personal en descanso: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E293B),
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.credit_card, color: Colors.amber),
            SizedBox(width: 8),
            Text('Lector de Tarjetas'),
          ],
        ),
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const SizedBox(height: 20),
            
            // Título
            const Text(
              'Deslice la tarjeta (Número de Rojo)',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w300,
                color: Colors.white70,
              ),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 30),
            
            // Input de tarjeta
            Card(
              elevation: 8,
              color: const Color(0xFF334155),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    TextField(
                      controller: _controller,
                      autofocus: true,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Deslice la tarjeta o ingrese código',
                        labelStyle: TextStyle(color: Colors.grey),
                        hintText: 'Esperando tarjeta...',
                        hintStyle: TextStyle(color: Colors.grey),
                        prefixIcon: Icon(Icons.credit_card, color: Colors.amber),
                        border: OutlineInputBorder(),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.amber, width: 2),
                        ),
                      ),
                      onSubmitted: _handleInput,
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Texto de ayuda
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.amber, size: 16),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Sin tarjeta: escriba su código (KA22, HP30, VS26, CB29...)',
                              style: TextStyle(color: Colors.amber, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 30),
            
            // Indicador de procesamiento
            if (_processing) ...[
              const CircularProgressIndicator(color: Colors.amber),
              const SizedBox(height: 16),
              const Text('Procesando...', style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 30),
            ],
            
            // Personal en descanso
            _buildPersonalEnDescanso(),
            
            const Spacer(),
            
            // Botón de prueba
            ElevatedButton.icon(
              onPressed: _processing ? null : _testConnection,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF64748B),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              ),
              icon: const Icon(Icons.wifi_tethering),
              label: const Text('Probar Conexión'),
            ),
            
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildPersonalEnDescanso() {
    return Card(
      elevation: 4,
      color: const Color(0xFF0F172A),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.person_outline, color: Colors.blue, size: 20),
                SizedBox(width: 8),
                Text(
                  'Personal en Descanso',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_personalEnDescanso.isEmpty)
              const Text(
                'Nadie se encuentra en descanso actualmente.',
                style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
              )
            else
              Wrap(
                spacing: 8.0,
                runSpacing: 8.0,
                children: _personalEnDescanso.map((name) => Chip(
                  avatar: const Icon(Icons.timer_outlined, color: Colors.black87, size: 18),
                  label: Text(name, style: const TextStyle(color: Colors.black87)),
                  backgroundColor: Colors.amber.shade400,
                )).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleInput(String rawValue) async {
    final code = rawValue.trim().replaceAll(RegExp(r'^;|\?\$'), '');
    _controller.clear();
    setState(() => _processing = true);

    try {
      final supabase = Supabase.instance.client;
      print("🔍 Buscando usuario con código: $code");

      // Buscar usuario por tarjeta
      List<Map<String, dynamic>> userResponse = await supabase
          .from('usuarios')
          .select('*')
          .eq('tarjeta', code);

      // Si no se encuentra por tarjeta, buscar por código
      if (userResponse.isEmpty) {
        userResponse = await supabase
            .from('usuarios')
            .select('*')
            .eq('codigo', code.toUpperCase());
      }

      if (userResponse.isEmpty) {
        _showMessage('Usuario no encontrado', false);
        return;
      }

      final user = userResponse.first;
      final userId = user['id'] as String;
      final userName = user['nombre'] as String;

      // Verificar si tiene descanso activo
      final descansosResponse = await supabase
          .from('descansos')
          .select('*')
          .eq('usuario_id', userId)
          .eq('tipo', 'Pendiente');

      if (descansosResponse.isNotEmpty) {
        // SALIDA DE DESCANSO
        final descansoActivo = descansosResponse.first;
        final success = await _cerrarDescanso(userId, descansoActivo);
        
        if (success['success']) {
          _showMessage('✅ $userName - Salida registrada (${success['mensaje']})', true);
        } else {
          _showMessage('❌ Error al registrar salida: ${success['mensaje']}', false);
        }
      } else {
        // ENTRADA A DESCANSO
        final now = DateTime.now().toUtc();
        
        await supabase.from('descansos').insert({
          'usuario_id': userId,
          'inicio': now.toIso8601String(),
          'tipo': 'Pendiente',
        });

        _showMessage('🟢 $userName - Entrada a descanso registrada', true);
      }
    } catch (e) {
      print("❌ Error: $e");
      _showMessage('❌ Error: $e', false);
    } finally {
      setState(() => _processing = false);
      _fetchPersonalEnDescanso();
    }
  }

  Future<Map<String, dynamic>> _cerrarDescanso(String usuarioId, Map<String, dynamic> descansoActivo) async {
    try {
      final inicioStr = descansoActivo['inicio'] as String;
      final inicio = DateTime.parse(inicioStr);
      final fin = DateTime.now().toUtc();
      final duracionMinutos = fin.difference(inicio).inMinutes.clamp(1, 9999);
      final tipo = duracionMinutos >= 30 ? 'COMIDA' : 'DESCANSO';

      // Insertar en tiempos_descanso
      await Supabase.instance.client.from('tiempos_descanso').insert({
        'usuario_id': usuarioId,
        'tipo': tipo,
        'fecha': DateFormat('yyyy-MM-dd').format(fin),
        'inicio': DateFormat('HH:mm:ss').format(inicio),
        'fin': DateFormat('HH:mm:ss').format(fin),
        'duracion_minutos': duracionMinutos,
      });

      // Eliminar de descansos
      await Supabase.instance.client
          .from('descansos')
          .delete()
          .eq('id', descansoActivo['id']);

      return {
        'success': true,
        'mensaje': '$tipo de $duracionMinutos min',
      };
    } catch (e) {
      return {
        'success': false,
        'mensaje': 'Error: $e',
      };
    }
  }

  Future<void> _testConnection() async {
    setState(() => _processing = true);

    try {
      final response = await Supabase.instance.client
          .from('usuarios')
          .select('*')
          .limit(1);

      _showMessage('✅ Conexión exitosa! ${response.length} registros', true);
    } catch (e) {
      _showMessage('❌ Error de conexión: $e', false);
    } finally {
      setState(() => _processing = false);
    }
  }

  void _showMessage(String message, bool isSuccess) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isSuccess ? Icons.check_circle : Icons.error,
              color: Colors.white,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isSuccess ? Colors.green : Colors.red,
        duration: Duration(seconds: isSuccess ? 3 : 5),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
