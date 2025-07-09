import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/intl.dart';

// Importar utilidades de parsing de tarjetas
import 'tarjeta_utils.dart';

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
  List<Map<String, dynamic>> _personalEnDescanso = [];
  Timer? _refreshTimer;
  Timer? _clockTimer;
  String _currentTime = DateFormat('HH:mm:ss').format(DateTime.now());

  @override
  void initState() {
    super.initState();
    _updateCurrentTime();
    _fetchPersonalEnDescanso();

    // Timer para actualizar personal en descanso cada minuto
    _refreshTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) {
        _fetchPersonalEnDescanso();
      }
    });

    // Timer para actualizar reloj cada segundo
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        _updateCurrentTime();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _refreshTimer?.cancel();
    _clockTimer?.cancel();
    super.dispose();
  }

  void _updateCurrentTime() {
    if (mounted) {
      setState(() {
        _currentTime = DateFormat('HH:mm:ss').format(DateTime.now());
      });
    }
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
          .select('id, inicio, usuarios(nombre)')
          .eq('tipo', 'Pendiente');

      if (mounted) {
        final personalData =
            (response as List).map((item) {
              final nombre =
                  item['usuarios']?['nombre'] as String? ?? 'Desconocido';
              final inicioStr = item['inicio'] as String?;

              // Calcular duración desde el inicio
              int duracionMinutos = 0;
              if (inicioStr != null) {
                try {
                  String fechaLimpia = inicioStr;
                  if (fechaLimpia.contains('+00:00Z')) {
                    fechaLimpia = fechaLimpia.replaceAll('+00:00Z', 'Z');
                  } else if (!fechaLimpia.endsWith('Z') &&
                      !fechaLimpia.contains('+')) {
                    fechaLimpia = '${fechaLimpia}Z';
                  }

                  final inicio = DateTime.parse(fechaLimpia).toLocal();
                  final ahora = DateTime.now();
                  duracionMinutos = ahora.difference(inicio).inMinutes;
                } catch (e) {
                  print('Error calculando duración: $e');
                }
              }

              return {
                'nombre': nombre,
                'duracion': duracionMinutos,
                'inicio': inicioStr,
              };
            }).toList();

        setState(() {
          _personalEnDescanso = personalData;
        });
      }
    } catch (e) {
      print("Error al obtener personal en descanso: $e");
    }
  }

  Future<void> _handleInput(String rawValue) async {
    final raw = rawValue.trim();

    // 🆕 USAR UTILIDADES DE PARSING DE TARJETAS
    print("🔍 === PROCESANDO ENTRADA DE TARJETA ===");
    print("📥 Datos originales: '$raw'");

    // Analizar con las utilidades de tarjeta
    final cardInfo = TarjetaUtils.getCardInfo(raw);
    final parsedCode = TarjetaUtils.parseCardData(raw);
    final isValidFormat = TarjetaUtils.validateCardFormat(parsedCode);

    print("📊 Información de tarjeta:");
    print("   - Tipo: ${cardInfo['trackInfo']}");
    print("   - Código parseado: '$parsedCode'");
    print("   - Formato válido: $isValidFormat");
    print(
      "   - Es banda magnética: ${cardInfo['hasTrack1'] || cardInfo['hasTrack2']}",
    );

    // Si no es válido, intentar limpieza adicional
    String finalCode = parsedCode;
    if (!isValidFormat || parsedCode.isEmpty) {
      final cleaned = TarjetaUtils.cleanCardData(raw);
      finalCode = TarjetaUtils.extractEmployeeCode(cleaned);
      print("🧹 Después de limpieza: '$finalCode'");
    }

    // Si aún no es válido, usar el método anterior como fallback
    if (finalCode.isEmpty || finalCode.length < 3) {
      finalCode = raw.replaceAll(RegExp(r'^;|\?\$'), '');
      print("🔄 Usando método fallback: '$finalCode'");
    }

    _controller.clear();
    setState(() => _processing = true);

    try {
      final supabase = Supabase.instance.client;
      print("🔍 Buscando usuario con código final: '$finalCode'");

      // 1) Buscar usuario por tarjeta primero
      List<Map<String, dynamic>> userResponse = await supabase
          .from('usuarios')
          .select('*')
          .eq('tarjeta', finalCode);

      print("🆔 Búsqueda por tarjeta: ${userResponse.length} resultados");

      // Si no se encuentra por tarjeta, buscar por código
      if (userResponse.isEmpty) {
        userResponse = await supabase
            .from('usuarios')
            .select('*')
            .eq('codigo', finalCode.toUpperCase());
        print("🔤 Búsqueda por código: ${userResponse.length} resultados");
      }

      if (userResponse.isEmpty) {
        if (mounted) {
          _showResponseMessage(
            context,
            'Usuario no encontrado con código: $finalCode',
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

      // ...resto del código de descansos... 2) Verificar si tiene descanso activo
      final descansosResponse = await supabase
          .from('descansos')
          .select('*')
          .eq('usuario_id', userId)
          .eq('tipo', 'Pendiente');

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

  // 🆕 FUNCIÓN PARA MOSTRAR DIÁLOGO DE PRUEBA DE TARJETAS
  void _showCardTestDialog() {
    final TextEditingController testController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF334155),
          title: const Text(
            '🧪 Prueba de Parsing de Tarjetas',
            style: TextStyle(color: Colors.white),
          ),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: testController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Datos de tarjeta',
                    labelStyle: TextStyle(color: Colors.grey.shade400),
                    hintText: 'Pega aquí los datos de la tarjeta...',
                    hintStyle: TextStyle(color: Colors.grey.shade500),
                    filled: true,
                    fillColor: const Color(0xFF475569),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Ejemplos de formatos soportados:',
                  style: TextStyle(
                    color: Colors.amber,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '• Track 1: %B123456789^DOE/JOHN^2512101?\n'
                  '• Track 2: ;123456789=2512101?\n'
                  '• Numérico: 123456789\n'
                  '• Con prefijo: EMPL123456',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                final testData = testController.text;
                if (testData.isNotEmpty) {
                  Navigator.of(context).pop();
                  _runCardTest(testData);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade600,
                foregroundColor: Colors.white,
              ),
              child: const Text('Probar'),
            ),
          ],
        );
      },
    );
  }

  // 🆕 FUNCIÓN PARA EJECUTAR PRUEBA DE TARJETA
  void _runCardTest(String testData) {
    print("\n🧪 === EJECUTANDO PRUEBA DE TARJETA ===");

    // Ejecutar debugging completo
    final debugInfo = TarjetaUtils.debugCardParsing(testData);

    // Mostrar resultados en un diálogo
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF334155),
          title: const Text(
            '📊 Resultados de Parsing',
            style: TextStyle(color: Colors.white),
          ),
          content: SizedBox(
            width: 500,
            height: 400,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTestResult('Datos originales:', testData),
                  _buildTestResult(
                    'Código parseado:',
                    debugInfo['parsedResult'] ?? 'Error',
                  ),
                  _buildTestResult(
                    'Formato válido:',
                    debugInfo['parsingSuccess']?.toString() ?? 'false',
                  ),
                  _buildTestResult(
                    'Tipo de tarjeta:',
                    debugInfo['cardInfo']?['trackInfo'] ?? 'Desconocido',
                  ),
                  _buildTestResult(
                    'Es banda magnética:',
                    debugInfo['isMagneticStripe']?.toString() ?? 'false',
                  ),
                  _buildTestResult(
                    'Longitud original:',
                    debugInfo['rawLength']?.toString() ?? '0',
                  ),
                  if (debugInfo['cardInfo'] != null) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Información detallada:',
                      style: TextStyle(
                        color: Colors.amber,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      debugInfo['cardInfo'].toString(),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cerrar'),
            ),
            if (debugInfo['parsedResult'] != null &&
                debugInfo['parsedResult'].isNotEmpty)
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _controller.text = debugInfo['parsedResult'];
                  _handleInput(debugInfo['parsedResult']);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Usar este código'),
              ),
          ],
        );
      },
    );
  }

  Widget _buildTestResult(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.amber,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
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
      final inicio =
          DateTime.parse(
            fechaLimpia,
          ).toLocal(); // Convertir a hora local del dispositivo
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

  void _showResponseMessage(
    BuildContext context,
    String message, {
    bool isSuccess = true,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        backgroundColor:
            isSuccess ? Colors.green.shade600 : Colors.red.shade600,
        duration: Duration(seconds: isSuccess ? 3 : 5),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Widget _buildPersonalEnDescanso(
    bool isXLDesktop,
    bool isDesktop,
    bool isTablet,
    bool isSmallMobile,
  ) {
    return Card(
      elevation: 6,
      color: const Color(0xFF334155),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color:
              _personalEnDescanso.isEmpty
                  ? Colors.green.withOpacity(0.3)
                  : Colors.orange.withOpacity(0.5),
          width: 1,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(
          isXLDesktop
              ? 28
              : isDesktop
              ? 24
              : isTablet
              ? 20
              : isSmallMobile
              ? 14
              : 16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _personalEnDescanso.isEmpty
                      ? Icons.check_circle
                      : Icons.coffee,
                  color:
                      _personalEnDescanso.isEmpty
                          ? Colors.green
                          : Colors.orange,
                  size:
                      isXLDesktop
                          ? 26
                          : isDesktop
                          ? 24
                          : isTablet
                          ? 22
                          : isSmallMobile
                          ? 18
                          : 20,
                ),
                SizedBox(width: isSmallMobile ? 6 : 8),
                Text(
                  'Personal en Descanso',
                  style: TextStyle(
                    fontSize:
                        isXLDesktop
                            ? 20
                            : isDesktop
                            ? 18
                            : isTablet
                            ? 17
                            : isSmallMobile
                            ? 15
                            : 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal:
                        isXLDesktop
                            ? 14
                            : isDesktop
                            ? 12
                            : isTablet
                            ? 11
                            : isSmallMobile
                            ? 8
                            : 10,
                    vertical:
                        isXLDesktop
                            ? 8
                            : isDesktop
                            ? 6
                            : isTablet
                            ? 5
                            : isSmallMobile
                            ? 3
                            : 4,
                  ),
                  decoration: BoxDecoration(
                    color:
                        _personalEnDescanso.isEmpty
                            ? Colors.green.withOpacity(0.2)
                            : Colors.orange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color:
                          _personalEnDescanso.isEmpty
                              ? Colors.green.withOpacity(0.5)
                              : Colors.orange.withOpacity(0.5),
                    ),
                  ),
                  child: Text(
                    '${_personalEnDescanso.length}',
                    style: TextStyle(
                      color:
                          _personalEnDescanso.isEmpty
                              ? Colors.green
                              : Colors.orange,
                      fontWeight: FontWeight.bold,
                      fontSize:
                          isXLDesktop
                              ? 16
                              : isDesktop
                              ? 14
                              : isTablet
                              ? 13
                              : isSmallMobile
                              ? 11
                              : 12,
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
                      size:
                          isXLDesktop
                              ? 52
                              : isDesktop
                              ? 48
                              : isTablet
                              ? 42
                              : isSmallMobile
                              ? 32
                              : 36,
                      color: Colors.green.withOpacity(0.7),
                    ),
                    SizedBox(
                      height:
                          isXLDesktop
                              ? 14
                              : isDesktop
                              ? 12
                              : isTablet
                              ? 10
                              : isSmallMobile
                              ? 6
                              : 8,
                    ),
                    Text(
                      'Todo el personal está trabajando',
                      style: TextStyle(
                        color: Colors.green.shade300,
                        fontSize:
                            isXLDesktop
                                ? 18
                                : isDesktop
                                ? 16
                                : isTablet
                                ? 15
                                : isSmallMobile
                                ? 13
                                : 14,
                        fontWeight: FontWeight.w400,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            else
              ...(_personalEnDescanso.map((persona) {
                final nombre = persona['nombre'] as String;
                final duracion = persona['duracion'] as int;

                // Determinar color según duración
                MaterialColor colorIndicador;
                String tipoDescanso;
                IconData icono;

                if (duracion >= 20) {
                  colorIndicador = Colors.blue;
                  tipoDescanso = 'COLACIÓN';
                  icono = Icons.restaurant;
                } else {
                  colorIndicador = Colors.orange;
                  tipoDescanso = 'DESCANSO';
                  icono = Icons.coffee;
                }

                return Padding(
                  padding: EdgeInsets.only(
                    bottom:
                        isXLDesktop
                            ? 12
                            : isDesktop
                            ? 10
                            : isTablet
                            ? 9
                            : isSmallMobile
                            ? 6
                            : 8,
                  ),
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(
                      isXLDesktop
                          ? 18
                          : isDesktop
                          ? 16
                          : isTablet
                          ? 14
                          : isSmallMobile
                          ? 10
                          : 12,
                    ),
                    decoration: BoxDecoration(
                      color: colorIndicador.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: colorIndicador.withOpacity(0.3),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(
                            isXLDesktop
                                ? 10
                                : isDesktop
                                ? 8
                                : isTablet
                                ? 7
                                : isSmallMobile
                                ? 5
                                : 6,
                          ),
                          decoration: BoxDecoration(
                            color: colorIndicador.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            icono,
                            color: colorIndicador.shade300,
                            size:
                                isXLDesktop
                                    ? 22
                                    : isDesktop
                                    ? 20
                                    : isTablet
                                    ? 18
                                    : isSmallMobile
                                    ? 14
                                    : 16,
                          ),
                        ),
                        SizedBox(
                          width:
                              isXLDesktop
                                  ? 14
                                  : isDesktop
                                  ? 12
                                  : isTablet
                                  ? 10
                                  : isSmallMobile
                                  ? 6
                                  : 8,
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                nombre,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize:
                                      isXLDesktop
                                          ? 18
                                          : isDesktop
                                          ? 16
                                          : isTablet
                                          ? 15
                                          : isSmallMobile
                                          ? 13
                                          : 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                tipoDescanso,
                                style: TextStyle(
                                  color: colorIndicador.shade300,
                                  fontSize:
                                      isXLDesktop
                                          ? 14
                                          : isDesktop
                                          ? 12
                                          : isTablet
                                          ? 11
                                          : isSmallMobile
                                          ? 9
                                          : 10,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal:
                                isXLDesktop
                                    ? 14
                                    : isDesktop
                                    ? 12
                                    : isTablet
                                    ? 10
                                    : isSmallMobile
                                    ? 6
                                    : 8,
                            vertical:
                                isXLDesktop
                                    ? 8
                                    : isDesktop
                                    ? 6
                                    : isTablet
                                    ? 5
                                    : isSmallMobile
                                    ? 3
                                    : 4,
                          ),
                          decoration: BoxDecoration(
                            color: colorIndicador.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: colorIndicador.withOpacity(0.4),
                            ),
                          ),
                          child: Text(
                            '${duracion}min',
                            style: TextStyle(
                              color: colorIndicador.shade200,
                              fontSize:
                                  isXLDesktop
                                      ? 16
                                      : isDesktop
                                      ? 14
                                      : isTablet
                                      ? 13
                                      : isSmallMobile
                                      ? 11
                                      : 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              })),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallMobile = screenSize.width < 360;
    final isMobile = screenSize.width <= 600;
    final isTablet = screenSize.width > 600 && screenSize.width <= 1200;
    final isDesktop = screenSize.width > 1200;
    final isXLDesktop = screenSize.width > 1600;

    // Calcular padding responsivo mejorado
    double horizontalPadding = 12.0;
    if (isSmallMobile) {
      horizontalPadding = 8.0;
    } else if (isMobile)
      horizontalPadding = 16.0;
    else if (isTablet)
      horizontalPadding = screenSize.width * 0.08;
    else if (isDesktop && !isXLDesktop)
      horizontalPadding = screenSize.width * 0.12;
    else if (isXLDesktop)
      horizontalPadding = screenSize.width * 0.15;

    // Calcular ancho máximo del contenido
    double maxWidth = double.infinity;
    if (isSmallMobile) {
      maxWidth = screenSize.width - (horizontalPadding * 2);
    } else if (isMobile)
      maxWidth = 500;
    else if (isTablet)
      maxWidth = 700;
    else if (isDesktop && !isXLDesktop)
      maxWidth = 900;
    else if (isXLDesktop)
      maxWidth = 1100;

    return Scaffold(
      backgroundColor: const Color(0xFF1E293B),
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.credit_card, color: Colors.amber),
            SizedBox(width: isSmallMobile ? 4 : 8),
            Expanded(
              child: Text(
                isDesktop
                    ? 'Lector de Tarjetas - Simplificado'
                    : isTablet
                    ? 'Lector de Tarjetas'
                    : isSmallMobile
                    ? 'Lector'
                    : 'Lector de Tarjetas',
                style: TextStyle(
                  fontSize:
                      isXLDesktop
                          ? 22
                          : isDesktop
                          ? 20
                          : isTablet
                          ? 18
                          : isSmallMobile
                          ? 14
                          : 16,
                ),
              ),
            ),
            // Reloj en tiempo real
            Container(
              padding: EdgeInsets.symmetric(
                horizontal:
                    isXLDesktop
                        ? 18
                        : isDesktop
                        ? 16
                        : isTablet
                        ? 14
                        : isSmallMobile
                        ? 8
                        : 12,
                vertical:
                    isXLDesktop
                        ? 10
                        : isDesktop
                        ? 8
                        : isTablet
                        ? 7
                        : isSmallMobile
                        ? 4
                        : 6,
              ),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.amber.withOpacity(0.5)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.access_time,
                    color: Colors.amber.shade300,
                    size:
                        isXLDesktop
                            ? 20
                            : isDesktop
                            ? 18
                            : isTablet
                            ? 17
                            : isSmallMobile
                            ? 14
                            : 16,
                  ),
                  SizedBox(width: isSmallMobile ? 4 : 6),
                  Text(
                    _currentTime,
                    style: TextStyle(
                      color: Colors.amber.shade200,
                      fontSize:
                          isXLDesktop
                              ? 18
                              : isDesktop
                              ? 16
                              : isTablet
                              ? 14
                              : isSmallMobile
                              ? 10
                              : 12,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        centerTitle: false,
      ),
      body: SizedBox(
        width: double.infinity,
        height: double.infinity,
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical:
                isXLDesktop
                    ? 40
                    : isDesktop
                    ? 32
                    : isTablet
                    ? 24
                    : isSmallMobile
                    ? 12
                    : 16,
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
                        isXLDesktop
                            ? 50
                            : isDesktop
                            ? 40
                            : isTablet
                            ? 24
                            : isSmallMobile
                            ? 12
                            : 16,
                  ),

                  // Título principal
                  Text(
                    'Deslice la tarjeta (Número de Rojo)',
                    style: TextStyle(
                      fontSize:
                          isXLDesktop
                              ? 32
                              : isDesktop
                              ? 28
                              : isTablet
                              ? 24
                              : isSmallMobile
                              ? 18
                              : 20,
                      fontWeight: FontWeight.w300,
                      color: Colors.white70,
                      letterSpacing: 0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  SizedBox(
                    height:
                        isXLDesktop
                            ? 40
                            : isDesktop
                            ? 32
                            : isTablet
                            ? 24
                            : isSmallMobile
                            ? 16
                            : 20,
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
                        isXLDesktop
                            ? 32
                            : isDesktop
                            ? 28
                            : isTablet
                            ? 22
                            : isSmallMobile
                            ? 16
                            : 18,
                      ),
                      child: Column(
                        children: [
                          TextField(
                            controller: _controller,
                            autofocus: true,
                            style: TextStyle(
                              fontSize:
                                  isXLDesktop
                                      ? 19
                                      : isDesktop
                                      ? 17
                                      : isTablet
                                      ? 15
                                      : isSmallMobile
                                      ? 13
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
                                    isXLDesktop
                                        ? 15
                                        : isDesktop
                                        ? 13
                                        : isTablet
                                        ? 12
                                        : isSmallMobile
                                        ? 10
                                        : 11,
                              ),
                              hintText: 'Esperando tarjeta...',
                              hintStyle: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize:
                                    isXLDesktop
                                        ? 15
                                        : isDesktop
                                        ? 13
                                        : isTablet
                                        ? 12
                                        : isSmallMobile
                                        ? 10
                                        : 11,
                              ),
                              prefixIcon: Icon(
                                Icons.credit_card,
                                color: Colors.amber.withOpacity(0.7),
                                size:
                                    isXLDesktop
                                        ? 26
                                        : isDesktop
                                        ? 24
                                        : isTablet
                                        ? 22
                                        : isSmallMobile
                                        ? 18
                                        : 20,
                              ),
                              filled: true,
                              fillColor: const Color(0xFF475569),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal:
                                    isXLDesktop
                                        ? 20
                                        : isDesktop
                                        ? 18
                                        : isTablet
                                        ? 16
                                        : isSmallMobile
                                        ? 12
                                        : 14,
                                vertical:
                                    isXLDesktop
                                        ? 20
                                        : isDesktop
                                        ? 18
                                        : isTablet
                                        ? 16
                                        : isSmallMobile
                                        ? 12
                                        : 14,
                              ),
                            ),
                            onSubmitted: _handleInput,
                          ),

                          SizedBox(
                            height:
                                isXLDesktop
                                    ? 24
                                    : isDesktop
                                    ? 20
                                    : isTablet
                                    ? 16
                                    : isSmallMobile
                                    ? 12
                                    : 14,
                          ),

                          // Texto de ayuda
                          Container(
                            padding: EdgeInsets.all(
                              isXLDesktop
                                  ? 18
                                  : isDesktop
                                  ? 16
                                  : isTablet
                                  ? 14
                                  : isSmallMobile
                                  ? 10
                                  : 12,
                            ),
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
                                  size:
                                      isXLDesktop
                                          ? 22
                                          : isDesktop
                                          ? 20
                                          : isTablet
                                          ? 19
                                          : isSmallMobile
                                          ? 16
                                          : 18,
                                ),
                                SizedBox(width: isSmallMobile ? 6 : 8),
                                Expanded(
                                  child: Text(
                                    'Versión simplificada - Usa hora del dispositivo',
                                    style: TextStyle(
                                      fontSize:
                                          isXLDesktop
                                              ? 15
                                              : isDesktop
                                              ? 13
                                              : isTablet
                                              ? 12
                                              : isSmallMobile
                                              ? 10
                                              : 11,
                                      color: Colors.amber.shade200,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // 🆕 BOTÓN DE PRUEBA DE PARSING (solo en modo debug)
                          if (kDebugMode) ...[
                            SizedBox(
                              height:
                                  isXLDesktop
                                      ? 16
                                      : isDesktop
                                      ? 14
                                      : isTablet
                                      ? 12
                                      : isSmallMobile
                                      ? 8
                                      : 10,
                            ),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _showCardTestDialog,
                                icon: const Icon(Icons.bug_report),
                                label: Text(
                                  isSmallMobile
                                      ? 'Test Parsing'
                                      : 'Probar Parsing de Tarjetas',
                                  style: TextStyle(
                                    fontSize:
                                        isXLDesktop
                                            ? 14
                                            : isDesktop
                                            ? 12
                                            : isTablet
                                            ? 11
                                            : isSmallMobile
                                            ? 9
                                            : 10,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue.shade600,
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.symmetric(
                                    vertical:
                                        isXLDesktop
                                            ? 12
                                            : isDesktop
                                            ? 10
                                            : isTablet
                                            ? 9
                                            : isSmallMobile
                                            ? 6
                                            : 8,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  SizedBox(
                    height:
                        isXLDesktop
                            ? 40
                            : isDesktop
                            ? 32
                            : isTablet
                            ? 24
                            : isSmallMobile
                            ? 16
                            : 20,
                  ),

                  // Indicador de procesamiento
                  if (_processing) ...[
                    Center(
                      child: Column(
                        children: [
                          SizedBox(
                            width:
                                isXLDesktop
                                    ? 56
                                    : isDesktop
                                    ? 48
                                    : isTablet
                                    ? 40
                                    : isSmallMobile
                                    ? 28
                                    : 32,
                            height:
                                isXLDesktop
                                    ? 56
                                    : isDesktop
                                    ? 48
                                    : isTablet
                                    ? 40
                                    : isSmallMobile
                                    ? 28
                                    : 32,
                            child: const CircularProgressIndicator(
                              color: Colors.amber,
                              strokeWidth: 3,
                            ),
                          ),
                          SizedBox(
                            height:
                                isXLDesktop
                                    ? 18
                                    : isDesktop
                                    ? 16
                                    : isTablet
                                    ? 14
                                    : isSmallMobile
                                    ? 10
                                    : 12,
                          ),
                          Text(
                            'Procesando...',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize:
                                  isXLDesktop
                                      ? 18
                                      : isDesktop
                                      ? 16
                                      : isTablet
                                      ? 14
                                      : isSmallMobile
                                      ? 11
                                      : 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      height:
                          isXLDesktop
                              ? 48
                              : isDesktop
                              ? 40
                              : isTablet
                              ? 32
                              : isSmallMobile
                              ? 20
                              : 24,
                    ),
                  ],

                  // Widget para mostrar personal en descanso
                  _buildPersonalEnDescanso(
                    isXLDesktop,
                    isDesktop,
                    isTablet,
                    isSmallMobile,
                  ),

                  // Espaciado inferior
                  SizedBox(
                    height:
                        isXLDesktop
                            ? 48
                            : isDesktop
                            ? 40
                            : isTablet
                            ? 32
                            : isSmallMobile
                            ? 16
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
}
