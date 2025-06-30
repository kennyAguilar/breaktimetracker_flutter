import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PersonalEnTurnoPage extends StatefulWidget {
  const PersonalEnTurnoPage({super.key});

  @override
  State<PersonalEnTurnoPage> createState() => _PersonalEnTurnoPageState();
}

class _PersonalEnTurnoPageState extends State<PersonalEnTurnoPage> {
  late Future<List<Map<String, dynamic>>> _futureBreaks;
  Timer? _refreshDataTimer;
  Timer? _updateUITimer;

  @override
  void initState() {
    super.initState();
    _futureBreaks = _fetchBreaks();
    // Refresh data from Supabase every 10 minutes
    _refreshDataTimer = Timer.periodic(const Duration(minutes: 10), (timer) {
      if (mounted) {
        setState(() {
          _futureBreaks = _fetchBreaks();
        });
      }
    });
    // Update UI every second to show countdown
    _updateUITimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _refreshDataTimer?.cancel();
    _updateUITimer?.cancel();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _fetchBreaks() async {
    final response = await Supabase.instance.client
        .from('descansos')
        .select('*, usuarios(nombre)')
        .eq('estado', 'Pendiente')
        .order('hora_inicio', ascending: true);

    return List<Map<String, dynamic>>.from(response as List);
  }

  String _formatDuration(Duration duration) {
    if (duration.isNegative) {
      return 'Finalizado';
    }
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    // HH:MM:SS format
    return '${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Personal en Descanso'),
        backgroundColor: const Color(0xFF003366),
        titleTextStyle: const TextStyle(color: Colors.white, fontSize: 20),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {
            _futureBreaks = _fetchBreaks();
          });
        },
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _futureBreaks,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Text('Error al cargar los datos: ${snapshot.error}'),
              );
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(
                child: Text('No hay personal en descanso en este momento.'),
              );
            }

            final breaks = snapshot.data!;

            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              scrollDirection: Axis.vertical,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(
                      label: Text(
                        'Nombre',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Hora de Inicio',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Tipo de Descanso',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Tiempo Restante',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                  rows:
                      breaks.map((breakData) {
                        final user = breakData['usuarios'];
                        final userName =
                            user != null ? user['nombre'] : 'Desconocido';
                        final horaInicio =
                            DateTime.parse(breakData['hora_inicio']).toLocal();
                        final tipoDescanso = breakData['tipo_descanso'];

                        final int duracionMinutes;
                        if (tipoDescanso == 'Corto') {
                          duracionMinutes = 15;
                        } else if (tipoDescanso == 'Largo') {
                          duracionMinutes = 30;
                        } else {
                          duracionMinutes = 0; // Default case
                        }

                        final duracionDescanso = Duration(
                          minutes: duracionMinutes,
                        );
                        final horaFin = horaInicio.add(duracionDescanso);
                        final tiempoRestante = horaFin.difference(
                          DateTime.now(),
                        );

                        return DataRow(
                          cells: [
                            DataCell(Text(userName)),
                            DataCell(
                              Text(
                                '${horaInicio.hour.toString().padLeft(2, '0')}:${horaInicio.minute.toString().padLeft(2, '0')}',
                              ),
                            ),
                            DataCell(Text(tipoDescanso)),
                            DataCell(Text(_formatDuration(tiempoRestante))),
                          ],
                        );
                      }).toList(),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
