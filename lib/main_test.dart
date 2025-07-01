import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Cargar variables de entorno
    await dotenv.load(fileName: ".env");
    print("✅ Archivo .env cargado");

    final supabaseUrl = dotenv.env['SUPABASE_URL'];
    final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'];

    if (supabaseUrl != null && supabaseAnonKey != null) {
      print("🔗 Inicializando Supabase...");
      await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
      print("✅ Supabase inicializado");
    } else {
      print("❌ Variables de entorno faltantes");
    }
  } catch (e) {
    print("❌ Error de inicialización: $e");
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BreakTime Tracker - Test',
      theme: ThemeData.dark(),
      home: const TestPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class TestPage extends StatefulWidget {
  const TestPage({super.key});

  @override
  State<TestPage> createState() => _TestPageState();
}

class _TestPageState extends State<TestPage> {
  String _status = "Inicializando...";
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _testConnection();
  }

  Future<void> _testConnection() async {
    setState(() {
      _loading = true;
      _status = "Probando conexión...";
    });

    try {
      final client = Supabase.instance.client;

      // Probar consulta simple
      final response = await client
          .from('usuarios')
          .select('id, nombre')
          .limit(1);

      setState(() {
        _loading = false;
        _status =
            "✅ Conexión exitosa! Usuarios encontrados: ${response.length}";
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _status = "❌ Error: $e";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('BreakTime Test')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_loading)
                const CircularProgressIndicator()
              else
                const Icon(Icons.check_circle, size: 64, color: Colors.green),
              const SizedBox(height: 20),
              Text(
                _status,
                style: const TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: _loading ? null : _testConnection,
                child: const Text('Probar Conexión'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
