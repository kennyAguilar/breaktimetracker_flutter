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
        // Tema dark personalizado
        brightness: Brightness.dark,
        primarySwatch: Colors.amber,
        primaryColor: Colors.amber,
        scaffoldBackgroundColor: const Color(0xFF1E293B),
        cardColor: const Color(0xFF334155),

        // AppBar theme
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0F172A),
          foregroundColor: Colors.white,
          elevation: 0,
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w500,
          ),
        ),

        // Card theme
        cardTheme: CardTheme(
          color: const Color(0xFF334155),
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),

        // Input decoration theme
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF475569),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade600),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.amber, width: 2),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade600),
          ),
          labelStyle: TextStyle(color: Colors.grey.shade400),
          hintStyle: TextStyle(color: Colors.grey.shade500),
        ),

        // Elevated button theme
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF64748B),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            elevation: 4,
          ),
        ),

        // SnackBar theme
        snackBarTheme: const SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
        ),

        // Text theme
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Colors.white),
          bodyMedium: TextStyle(color: Colors.white70),
          titleLarge: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      home: const CardEntryExitPage(),
      debugShowCheckedModeBanner: false, // Remover banner de debug
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

  Future<void> _handleInput(String rawValue) async {
    final raw = rawValue.trim();
    final code = raw.replaceAll(RegExp(r'^;|\?\$'), '');
    _controller.clear();
    setState(() => _processing = true);

    try {
      final supabase = Supabase.instance.client;
      print("🔍 Buscando usuario con código: $code");

      // 1) Buscar usuario por tarjeta primero
      List<Map<String, dynamic>> userResponse = await supabase
          .from('usuarios')
          .select('*')
          .eq('tarjeta', code);

      print("🆔 Búsqueda por tarjeta: ${userResponse.length} resultados");

      // Si no se encuentra por tarjeta, buscar por código
      if (userResponse.isEmpty) {
        userResponse = await supabase
            .from('usuarios')
            .select('*')
            .eq('codigo', code.toUpperCase());
        print("🔤 Búsqueda por código: ${userResponse.length} resultados");
      }

      if (userResponse.isEmpty) {
        if (mounted) {
          _showResponseMessage(context, 'Usuario no encontrado', isSuccess: false);
        }
        setState(() => _processing = false);
        return;
      }

      final user = userResponse.first;
      final userId = user['id'] as String;
      final userName = user['nombre'] as String;
      print("👤 Usuario encontrado: $userName (ID: $userId)");

      // 2) Verificar si tiene descanso activo
      final descansosResponse = await supabase
          .from('descansos')
          .select('*')
          .eq('usuario_id', userId)
          .eq('tipo', 'Pendiente');

      print("🔍 Descansos activos ('Pendiente') encontrados: ${descansosResponse.length}");

      if (descansosResponse.isNotEmpty) {
        // PROCESAR SALIDA DE DESCANSO
        final descansoActivo = descansosResponse.first;
        print("🚪 PROCESANDO SALIDA DE DESCANSO");
        print("   Usuario: $userName (ID: $userId)");
        print("   Descanso ID: ${descansoActivo['id']}");

        final success = await _cerrarDescansoUsuario(userId, descansoActivo);

        if (success['success']) {
          if (mounted) {
            _showResponseMessage(
              context,
              '✅ $userName - Salida registrada (${success['mensaje']})',
              isSuccess: true,
            );
          }
          print("🎉 SALIDA PROCESADA EXITOSAMENTE: ${success['mensaje']}");
        } else {
          if (mounted) {
            _showResponseMessage(
              context,
              '❌ Error al registrar salida de $userName: ${success['mensaje']}',
              isSuccess: false,
            );
          }
          print("❌ FALLO EN SALIDA: ${success['mensaje']}");
        }
      } else {
        // REGISTRAR ENTRADA A DESCANSO - SIMPLIFICADO
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
              isSuccess: true,
            );
          }
          print("✅ Entrada registrada exitosamente");
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

      String errorMessage = 'Error: $e';

      if (e.toString().contains('401')) {
        errorMessage = '🔑 Error 401: Clave API inválida o proyecto incorrecto';
      } else if (e.toString().contains('404') ||
          (e.toString().contains('relation') &&
              e.toString().contains('does not exist'))) {
        errorMessage = '🔍 Tabla no encontrada en la base de datos';
      } else if (e.toString().contains('permission')) {
        errorMessage = '🚫 Sin permisos: Revisar políticas RLS en Supabase';
      }

      if (mounted) {
        _showResponseMessage(context, errorMessage, isSuccess: false);
      }
    }

    setState(() => _processing = false);
    _fetchPersonalEnDescanso(); // Actualizar la lista después de cada operación
  }

  // SIMPLIFICAR función de cierre de descanso
  Future<Map<String, dynamic>> _cerrarDescansoUsuario(
    String usuarioId,
    Map<String, dynamic> descansoActivo,
  ) async {
    try {
      print("🔄 Iniciando proceso de cierre para usuario ID: $usuarioId");
      print("   Descanso a cerrar: ID ${descansoActivo['id']}");

      // SIMPLIFICADO: Cálculo de duración
      final inicioStr = descansoActivo['inicio'] as String;
      print("   📅 Fecha original: $inicioStr");

      // Limpiar formato de fecha problemático
      String fechaLimpia = inicioStr;
      if (fechaLimpia.contains('+00:00Z')) {
        fechaLimpia = fechaLimpia.replaceAll('+00:00Z', 'Z');
      } else if (fechaLimpia.contains('+00:00') && !fechaLimpia.endsWith('Z')) {
        fechaLimpia = fechaLimpia.replaceAll('+00:00', 'Z');
      } else if (!fechaLimpia.endsWith('Z') && !fechaLimpia.contains('+')) {
        fechaLimpia = '${fechaLimpia}Z';
      }

      print("   📅 Fecha limpia: $fechaLimpia");

      // SIMPLIFICADO: Usar hora del dispositivo directamente
      final inicio = DateTime.parse(fechaLimpia).toLocal(); // Convertir a hora local del dispositivo
      final fin = _getCurrentTime(); // Hora actual del dispositivo

      final duracionMinutos = fin.difference(inicio).inMinutes;
      final tipo = duracionMinutos >= 30 ? 'COMIDA' : 'DESCANSO';

      print("   ⏰ Inicio: ${_formatTime(inicio)}");
      print("   ⏰ Fin: ${_formatTime(fin)}");
      print("   ⏱️ Duración: $duracionMinutos minutos → $tipo");

      // Preparar datos para tiempos_descanso
      final tiempoData = {
        'usuario_id': usuarioId,
        'tipo': tipo,
        'fecha': DateFormat('yyyy-MM-dd').format(inicio), // Fecha local
        'inicio': DateFormat('HH:mm:ss').format(inicio), // Hora local de inicio
        'fin': DateFormat('HH:mm:ss').format(fin), // Hora local de fin
        'duracion_minutos': duracionMinutos,
      };

      // Paso 1: Insertar en tiempos_descanso
      print("   📝 Insertando tiempo de descanso...");
      await Supabase.instance.client
          .from('tiempos_descanso')
          .insert(tiempoData);

      print("   ✅ Tiempo insertado exitosamente");

      // Paso 2: Eliminar de descansos
      print("   🗑️ Eliminando descanso activo...");
      await Supabase.instance.client
          .from('descansos')
          .delete()
          .eq('id', descansoActivo['id']);

      print("   ✅ Descanso eliminado");

      // Paso 3: Verificación final
      final verificacionResponse = await Supabase.instance.client
          .from('descansos')
          .select('*')
          .eq('usuario_id', usuarioId);

      final descansosRestantes = verificacionResponse.length;
      print("   🔍 Verificación: $descansosRestantes descansos activos restantes");

      if (descansosRestantes > 0) {
        print("   ⚠️ PROBLEMA: Quedan descansos activos");
        for (var resto in verificacionResponse) {
          print("      - ID ${resto['id']}, Inicio: ${resto['inicio']}");
        }
      }

      final successMsg = "Descanso cerrado: $tipo de $duracionMinutos min";
      print("   ✅ ÉXITO: $successMsg");

      return {
        'success': true,
        'mensaje': successMsg,
        'tipo': tipo,
        'duracion_minutos': duracionMinutos,
        'descansos_restantes': descansosRestantes,
      };
    } catch (e) {
      final errorMsg = "Error cerrando descanso: $e";
      print("   ❌ ERROR CRÍTICO: $errorMsg");
      return {
        'success': false,
        'mensaje': errorMsg,
        'error': e.toString(),
      };
    }
  }

  void _showResponseMessage(BuildContext context, String message, {bool isSuccess = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        backgroundColor: isSuccess ? Colors.green.shade600 : Colors.red.shade600,
        duration: Duration(seconds: isSuccess ? 3 : 5),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Widget _buildPersonalEnDescanso(bool isDesktop, bool isTablet) {
    return Card(
      elevation: 6,
      color: const Color(0xFF334155),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: _personalEnDescanso.isEmpty
              ? Colors.green.withOpacity(0.3)
              : Colors.orange.withOpacity(0.5),
          width: 1,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(isDesktop ? 24 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _personalEnDescanso.isEmpty ? Icons.check_circle : Icons.coffee,
                  color: _personalEnDescanso.isEmpty ? Colors.green : Colors.orange,
                  size: isDesktop ? 24 : 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Personal en Descanso',
                  style: TextStyle(
                    fontSize: isDesktop ? 18 : 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: _personalEnDescanso.isEmpty
                        ? Colors.green.withOpacity(0.2)
                        : Colors.orange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _personalEnDescanso.isEmpty
                          ? Colors.green.withOpacity(0.5)
                          : Colors.orange.withOpacity(0.5),
                    ),
                  ),
                  child: Text(
                    '${_personalEnDescanso.length}',
                    style: TextStyle(
                      color: _personalEnDescanso.isEmpty ? Colors.green : Colors.orange,
                      fontWeight: FontWeight.bold,
                      fontSize: isDesktop ? 14 : 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_personalEnDescanso.isEmpty)
              Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.work,
                      size: isDesktop ? 48 : 36,
                      color: Colors.green.withOpacity(0.7),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Todo el personal está trabajando',
                      style: TextStyle(
                        color: Colors.green.shade300,
                        fontSize: isDesktop ? 16 : 14,
                        fontWeight: FontWeight.w400,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            else
              ...(_personalEnDescanso.map(
                (nombre) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(isDesktop ? 16 : 12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.orange.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.person,
                          color: Colors.orange.shade300,
                          size: isDesktop ? 20 : 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            nombre,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: isDesktop ? 16 : 14,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 600;
    final isDesktop = screenSize.width > 1200;

    // Calcular padding responsivo
    double horizontalPadding = 16.0;
    if (isTablet) horizontalPadding = screenSize.width * 0.1;
    if (isDesktop) horizontalPadding = screenSize.width * 0.15;

    // Calcular ancho máximo del contenido
    double maxWidth = double.infinity;
    if (isTablet) maxWidth = 600;
    if (isDesktop) maxWidth = 800;

    return Scaffold(
      backgroundColor: const Color(0xFF1E293B),
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.credit_card, color: Colors.amber),
            SizedBox(width: 8),
            Text('Lector de Tarjetas - Simplificado'),
          ],
        ),
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        centerTitle: !isDesktop,
      ),
      body: SizedBox(
        width: double.infinity,
        height: double.infinity,
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: isTablet ? 32 : 16,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Espaciado superior dinámico
                  SizedBox(height: isDesktop ? 60 : isTablet ? 40 : 20),

                  // Título principal
                  Text(
                    'Deslice la tarjeta (Número de Rojo)',
                    style: TextStyle(
                      fontSize: isDesktop ? 28 : isTablet ? 24 : 20,
                      fontWeight: FontWeight.w300,
                      color: Colors.white70,
                      letterSpacing: 0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  SizedBox(height: isDesktop ? 40 : isTablet ? 32 : 24),

                  // Card principal con el input
                  Card(
                    elevation: 8,
                    color: const Color(0xFF334155),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: Colors.amber.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(isDesktop ? 32 : isTablet ? 24 : 20),
                      child: Column(
                        children: [
                          TextField(
                            controller: _controller,
                            autofocus: true,
                            style: TextStyle(
                              fontSize: isDesktop ? 18 : isTablet ? 16 : 14,
                              color: Colors.white,
                            ),
                            decoration: InputDecoration(
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.amber.withOpacity(0.5),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Colors.amber,
                                  width: 2,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              labelText: 'Deslice la tarjeta o ingrese código',
                              labelStyle: TextStyle(
                                color: Colors.grey.shade400,
                                fontSize: isDesktop ? 14 : isTablet ? 13 : 12,
                              ),
                              hintText: 'Esperando tarjeta...',
                              hintStyle: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: isDesktop ? 14 : isTablet ? 13 : 12,
                              ),
                              prefixIcon: Icon(
                                Icons.credit_card,
                                color: Colors.amber.withOpacity(0.7),
                                size: isDesktop ? 24 : 20,
                              ),
                              filled: true,
                              fillColor: const Color(0xFF475569),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: isDesktop ? 20 : 16,
                                vertical: isDesktop ? 20 : 16,
                              ),
                            ),
                            onSubmitted: _handleInput,
                          ),

                          SizedBox(height: isDesktop ? 24 : 16),

                          // Texto de ayuda
                          Container(
                            padding: EdgeInsets.all(isDesktop ? 16 : 12),
                            decoration: BoxDecoration(
                              color: Colors.amber.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.amber.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  color: Colors.amber.shade300,
                                  size: isDesktop ? 20 : 18,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Versión simplificada - Usa hora del dispositivo',
                                    style: TextStyle(
                                      fontSize: isDesktop ? 14 : isTablet ? 13 : 12,
                                      color: Colors.amber.shade200,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: isDesktop ? 40 : isTablet ? 32 : 24),

                  // Indicador de procesamiento
                  if (_processing) ...[
                    Center(
                      child: Column(
                        children: [
                          SizedBox(
                            width: isDesktop ? 48 : isTablet ? 40 : 32,
                            height: isDesktop ? 48 : isTablet ? 40 : 32,
                            child: const CircularProgressIndicator(
                              color: Colors.amber,
                              strokeWidth: 3,
                            ),
                          ),
                          SizedBox(height: isDesktop ? 16 : 12),
                          Text(
                            'Procesando...',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: isDesktop ? 16 : isTablet ? 14 : 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: isDesktop ? 40 : isTablet ? 32 : 24),
                  ],

                  // Widget para mostrar personal en descanso
                  _buildPersonalEnDescanso(isDesktop, isTablet),

                  // Espaciado inferior
                  SizedBox(height: isDesktop ? 40 : isTablet ? 32 : 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
