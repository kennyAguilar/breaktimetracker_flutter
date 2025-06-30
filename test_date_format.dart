void main() {
  // Prueba del formato de fecha problemático
  String problematicDate = '2025-06-30T20:08:42.191748+00:00Z';

  print('Fecha original de Supabase: $problematicDate');

  // Método de limpieza implementado
  String cleanedDate = problematicDate;

  // 1. Remover 'Z' al final si existe y ya tiene zona horaria
  if (cleanedDate.contains('+') && cleanedDate.endsWith('Z')) {
    cleanedDate = cleanedDate.substring(0, cleanedDate.length - 1);
  }

  print('Fecha limpia: $cleanedDate');

  try {
    DateTime parsedDate = DateTime.parse(cleanedDate);
    print('✅ Fecha parseada exitosamente: $parsedDate');
    print('UTC: ${parsedDate.toUtc()}');
    print('ISO String: ${parsedDate.toIso8601String()}');
  } catch (e) {
    print('❌ Error parseando fecha: $e');

    // Fallback con regex
    String regexCleaned = problematicDate
        .replaceAll(RegExp(r'Z$'), '') // Remover Z final
        .replaceAll(
          RegExp(r'\+00:00Z$'),
          '+00:00',
        ); // Corregir formato inválido

    print('Fecha con regex: $regexCleaned');

    try {
      DateTime fallbackDate = DateTime.parse(regexCleaned);
      print('✅ Fecha con regex parseada: $fallbackDate');
    } catch (e2) {
      print('❌ Error con regex también: $e2');
    }
  }
}
