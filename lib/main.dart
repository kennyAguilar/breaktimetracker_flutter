import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:intl/intl.dart';

// Asegúrate de tener un archivo `.env` en la raíz de tu proyecto con estas variables:
// SUPABASE_URL=https://ppyowdavsbkhvxzvaviy.supabase.co
// SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBweW93ZGF2c2JraHZ4enZhdml5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTA5MTU4NjMsImV4cCI6MjA2NjQ5MTg2M30.ZFfAvT5icazQ1yh_JFYbQ-xbMunPJ8Q4Y47SpWWID2s
// SECRET_KEY=SAAffKwZoAs0Qlwr
// TZ=America/Santiago

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar zonas horarias
  tz.initializeTimeZones();

  try {
    await dotenv.load(fileName: ".env");
    print("✅ Archivo .env cargado correctamente");

    final supabaseUrl = dotenv.env['SUPABASE_URL'];
    final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'];

    // Configurar la zona horaria de Chile (Santiago es la zona oficial)
    // Nota: America/Punta_Arenas no existe, usamos America/Santiago
    try {
      tz.setLocalLocation(tz.getLocation('America/Santiago'));
      print("🌎 Zona horaria configurada: America/Santiago (Chile)");
    } catch (e) {
      // Si falla, usar UTC como respaldo
      tz.setLocalLocation(tz.getLocation('UTC'));
      print("⚠️ Usando UTC como zona horaria por defecto");
      print("Error de zona horaria: $e");
    }

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

      // Probar la conexión
      // await testSupabaseConnection(); // Comentar por ahora para que la app inicie
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
      backgroundColor: const Color(0xFF1E293B), // Dark blue background
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.credit_card, color: Colors.amber),
            const SizedBox(width: 8),
            const Text('Lector de Tarjetas'),
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
                  SizedBox(
                    height:
                        isDesktop
                            ? 60
                            : isTablet
                            ? 40
                            : 20,
                  ),

                  // Título principal
                  Text(
                    'Deslice la tarjeta (Número de Rojo)',
                    style: TextStyle(
                      fontSize:
                          isDesktop
                              ? 28
                              : isTablet
                              ? 24
                              : 20,
                      fontWeight: FontWeight.w300,
                      color: Colors.white70,
                      letterSpacing: 0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  SizedBox(
                    height:
                        isDesktop
                            ? 40
                            : isTablet
                            ? 32
                            : 24,
                  ),

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
                      padding: EdgeInsets.all(
                        isDesktop
                            ? 32
                            : isTablet
                            ? 24
                            : 20,
                      ),
                      child: Column(
                        children: [
                          TextField(
                            controller: _controller,
                            autofocus: true,
                            style: TextStyle(
                              fontSize:
                                  isDesktop
                                      ? 18
                                      : isTablet
                                      ? 16
                                      : 14,
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
                                fontSize:
                                    isDesktop
                                        ? 16
                                        : isTablet
                                        ? 14
                                        : 12,
                              ),
                              hintText: 'Esperando tarjeta...',
                              hintStyle: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize:
                                    isDesktop
                                        ? 16
                                        : isTablet
                                        ? 14
                                        : 12,
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
                                  color: Colors.amber,
                                  size: isDesktop ? 20 : 16,
                                ),
                                SizedBox(width: isDesktop ? 12 : 8),
                                Expanded(
                                  child: Text(
                                    'Sin tarjeta: escriba su código (KA22, HP30, VS26, CB29...)',
                                    style: TextStyle(
                                      color: Colors.amber.shade200,
                                      fontSize:
                                          isDesktop
                                              ? 14
                                              : isTablet
                                              ? 12
                                              : 11,
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

                  SizedBox(
                    height:
                        isDesktop
                            ? 40
                            : isTablet
                            ? 32
                            : 24,
                  ),

                  // Indicador de procesamiento
                  if (_processing) ...[
                    Center(
                      child: Column(
                        children: [
                          SizedBox(
                            width:
                                isDesktop
                                    ? 48
                                    : isTablet
                                    ? 40
                                    : 32,
                            height:
                                isDesktop
                                    ? 48
                                    : isTablet
                                    ? 40
                                    : 32,
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
                              fontSize:
                                  isDesktop
                                      ? 16
                                      : isTablet
                                      ? 14
                                      : 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      height:
                          isDesktop
                              ? 40
                              : isTablet
                              ? 32
                              : 24,
                    ),
                  ],

                  // Widget para mostrar personal en descanso
                  _buildPersonalEnDescanso(isDesktop, isTablet),

                  SizedBox(
                    height:
                        isDesktop
                            ? 20
                            : isTablet
                            ? 16
                            : 12,
                  ),

                  // Botón de prueba de conexión
                  Center(
                    child: SizedBox(
                      width:
                          isDesktop
                              ? 300
                              : isTablet
                              ? 250
                              : double.infinity,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ElevatedButton.icon(
                            onPressed: _processing ? null : _testConnection,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF64748B),
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(
                                horizontal: isDesktop ? 24 : 20,
                                vertical: isDesktop ? 16 : 14,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              elevation: 4,
                            ),
                            icon: Icon(
                              Icons.wifi_tethering,
                              size: isDesktop ? 20 : 18,
                            ),
                            label: Text(
                              'Probar Conexión',
                              style: TextStyle(
                                fontSize:
                                    isDesktop
                                        ? 16
                                        : isTablet
                                        ? 14
                                        : 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Espaciado inferior
                  SizedBox(
                    height:
                        isDesktop
                            ? 60
                            : isTablet
                            ? 40
                            : 20,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Obtiene la fecha/hora actual en zona horaria de Chile
  tz.TZDateTime _getCurrentPuntaArenasTime() {
    final location = tz.getLocation('America/Santiago');
    return tz.TZDateTime.now(location);
  }

  /// Convierte un timestamp UTC a zona horaria de Chile
  tz.TZDateTime _convertToLocalTime(DateTime utcTime) {
    final location = tz.getLocation('America/Santiago');
    return tz.TZDateTime.from(utcTime, location);
  }

  /// Convierte zona horaria local a UTC para enviar a Supabase
  DateTime _convertToUTC(tz.TZDateTime localTime) {
    return localTime.toUtc();
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

      // 2) Verificar si tiene descanso activo
      final descansosResponse = await supabase
          .from('descansos')
          .select('*')
          .eq('usuario_id', userId)
          .eq(
            'tipo',
            'Pendiente',
          ); // <-- CORRECCIÓN: Buscar solo descansos activos

      print(
        "🔍 Descansos activos ('Pendiente') encontrados: ${descansosResponse.length}",
      );

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
        // REGISTRAR ENTRADA A DESCANSO
        print("🚪 PROCESANDO ENTRADA A DESCANSO");
        try {
          final horaLocalPuntaArenas = _getCurrentPuntaArenasTime();
          final horaUTC = _convertToUTC(horaLocalPuntaArenas);

          print(
            "🕐 Hora local (Punta Arenas): ${DateFormat('dd/MM/yyyy HH:mm:ss').format(horaLocalPuntaArenas)}",
          );
          print("🕐 Hora UTC para BD: ${horaUTC.toIso8601String()}");

          await supabase.from('descansos').insert({
            'usuario_id': userId,
            'inicio': horaUTC.toIso8601String(),
            'tipo': 'Pendiente',
          });

          if (mounted) {
            _showResponseMessage(
              context,
              '🟢 $userName - Entrada a descanso registrada a las ${DateFormat('HH:mm').format(horaLocalPuntaArenas)}',
              isSuccess: true,
            );
          }
          print("✅ Entrada registrada exitosamente");
        } catch (e) {
          print("❌ Error registrando entrada: $e");
          if (mounted) {
            _showResponseMessage(
              context,
              '❌ Error al registrar entrada: $e',
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

  /// Función para cerrar descanso de usuario (similar a la lógica de app.py)
  Future<Map<String, dynamic>> _cerrarDescansoUsuario(
    String usuarioId,
    Map<String, dynamic> descansoActivo,
  ) async {
    try {
      print("🔄 Iniciando proceso de cierre para usuario ID: $usuarioId");
      print("   Descanso a cerrar: ID ${descansoActivo['id']}");

      // Calcular duración
      final inicioStr = descansoActivo['inicio'] as String;
      print("   📅 Fecha original: $inicioStr");

      // Limpiar formato de fecha problemático (remover Z extra si tiene +00:00)
      String fechaLimpia = inicioStr;
      if (fechaLimpia.contains('+00:00Z')) {
        fechaLimpia = fechaLimpia.replaceAll('+00:00Z', 'Z');
      } else if (fechaLimpia.contains('+00:00') && !fechaLimpia.endsWith('Z')) {
        fechaLimpia = fechaLimpia.replaceAll('+00:00', 'Z');
      } else if (!fechaLimpia.endsWith('Z') && !fechaLimpia.contains('+')) {
        fechaLimpia = '${fechaLimpia}Z';
      }

      print("   📅 Fecha limpia: $fechaLimpia");

      final inicio = DateTime.parse(fechaLimpia);
      final inicioLocalTime = _convertToLocalTime(inicio);
      final finLocalTime = _getCurrentPuntaArenasTime();
      final fin = _convertToUTC(finLocalTime);

      final duracionMinutos =
          (finLocalTime.difference(inicioLocalTime).inMinutes).clamp(1, 9999);
      final tipo = duracionMinutos >= 30 ? 'COMIDA' : 'DESCANSO';

      print("   ⏰ Inicio UTC: ${inicio.toIso8601String()}");
      print(
        "   ⏰ Inicio Local: ${DateFormat('dd/MM/yyyy HH:mm:ss').format(inicioLocalTime)}",
      );
      print(
        "   ⏰ Fin Local: ${DateFormat('dd/MM/yyyy HH:mm:ss').format(finLocalTime)}",
      );
      print("   ⏰ Fin UTC: ${fin.toIso8601String()}");
      print("   ⏱️ Duración: $duracionMinutos min → $tipo");

      // Preparar datos para tiempos_descanso
      final tiempoData = {
        'usuario_id': usuarioId,
        'tipo': tipo,
        'fecha': DateFormat(
          'yyyy-MM-dd',
        ).format(inicioLocalTime), // Fecha local
        'inicio': DateFormat(
          'HH:mm:ss',
        ).format(inicioLocalTime), // Hora local de inicio
        'fin': DateFormat('HH:mm:ss').format(finLocalTime), // Hora local de fin
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
      print(
        "   🔍 Verificación: $descansosRestantes descansos activos restantes",
      );

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
      return {'success': false, 'mensaje': errorMsg, 'error': e.toString()};
    }
  }

  Widget _buildPersonalEnDescanso(bool isDesktop, bool isTablet) {
    return Card(
      elevation: 4,
      color: const Color(0xFF0F172A), // Un color de fondo más oscuro
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.blueGrey.shade700, width: 1),
      ),
      child: Padding(
        padding: EdgeInsets.all(isDesktop ? 20 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.person_outline,
                  color: Colors.blue.shade300,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Personal en Descanso',
                  style: TextStyle(
                    fontSize: isDesktop ? 18 : 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_personalEnDescanso.isEmpty)
              Text(
                'Nadie se encuentra en descanso actualmente.',
                style: TextStyle(
                  color: Colors.grey.shade400,
                  fontStyle: FontStyle.italic,
                ),
              )
            else
              Wrap(
                spacing: 8.0,
                runSpacing: 8.0,
                children:
                    _personalEnDescanso
                        .map(
                          (name) => Chip(
                            avatar: Icon(
                              Icons.timer_outlined,
                              color: Colors.grey.shade800,
                              size: 18,
                            ),
                            label: Text(
                              name,
                              style: const TextStyle(color: Colors.black87),
                            ),
                            backgroundColor: Colors.amber.shade400,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                          ),
                        )
                        .toList(),
              ),
          ],
        ),
      ),
    );
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
        _showResponseMessage(
          context,
          '✅ Conexión exitosa! Datos obtenidos: ${response.length} registros',
          isSuccess: true,
        );
      }
    } catch (e) {
      print("❌ Error en prueba de conexión: $e");

      if (mounted) {
        _showResponseMessage(
          context,
          '❌ Error de conexión: $e\n💡 Verifica la clave JWT (debe empezar con "eyJ")',
          isSuccess: false,
        );
      }
    }

    setState(() => _processing = false);
  }

  /// Función para mostrar mensajes responsivos y atractivos
  void _showResponseMessage(
    BuildContext context,
    String message, {
    required bool isSuccess,
  }) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 600;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Container(
          padding: EdgeInsets.symmetric(
            vertical: isTablet ? 12 : 8,
            horizontal: isTablet ? 16 : 12,
          ),
          child: Row(
            children: [
              Icon(
                isSuccess ? Icons.check_circle : Icons.error,
                color: Colors.white,
                size: isTablet ? 24 : 20,
              ),
              SizedBox(width: isTablet ? 12 : 8),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    fontSize: isTablet ? 16 : 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
        backgroundColor:
            isSuccess
                ? const Color(0xFF059669) // Green-600
                : const Color(0xFFDC2626), // Red-600
        duration: Duration(seconds: isSuccess ? 3 : 5),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: EdgeInsets.all(isTablet ? 20 : 16),
        elevation: 8,
      ),
    );
  }
}

// Función para probar la conexión a Supabase
Future<void> testSupabaseConnection() async {
  try {
    print("🔍 Probando conexión a Supabase...");

    // Intentar hacer una consulta simple a la tabla usuarios (no empleados)
    final response = await Supabase.instance.client
        .from('usuarios')
        .select('id, nombre')
        .limit(1);

    print("✅ Conexión exitosa a Supabase");
    print("📊 Respuesta de prueba: $response");

    // Probar también la tabla descansos
    try {
      final descansosResponse = await Supabase.instance.client
          .from('descansos')
          .select('*')
          .limit(1);
      print("✅ Tabla 'descansos' accesible");
      print("📊 Datos de descansos: $descansosResponse");
    } catch (e) {
      print("⚠️ Problema con tabla 'descansos': $e");
    }
  } catch (e) {
    print("❌ Error de conexión a Supabase: $e");
    print("🔧 Verificar:");
    print("   - URL de Supabase en .env");
    print("   - Clave ANON_KEY en .env");
    print("   - Configuración de RLS en la tabla 'usuarios'");
    print("   - Configuración de RLS en la tabla 'descansos'");
    print("   - Conectividad a Internet");

    // Análisis más detallado del error
    final errorStr = e.toString().toLowerCase();
    if (errorStr.contains('401')) {
      print(
        "💡 Error 401: Problema de autenticación. JWT válido pero políticas RLS pueden estar bloqueando.",
      );
    } else if (errorStr.contains('404') ||
        errorStr.contains('relation') && errorStr.contains('does not exist')) {
      print("💡 Error 404: La tabla 'usuarios' no existe en la base de datos.");
    } else if (errorStr.contains('permission')) {
      print(
        "💡 Error de permisos: Revisar políticas RLS - deben permitir SELECT anónimo.",
      );
    }
  }
}
