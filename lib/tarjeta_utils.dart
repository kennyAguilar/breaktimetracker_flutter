// Utilidades para parsing de tarjetas de banda magnética
// =====================================================
//
// Este módulo contiene todas las funciones necesarias para parsear datos de tarjetas
// de banda magnética en diferentes formatos. Incluye validación, limpieza y extracción
// de información útil para el sistema de control de descansos.
//
// Características:
// - Soporte para múltiples formatos de tarjeta
// - Limpieza automática de caracteres especiales
// - Validación de formato
// - Extracción de códigos de empleado
// - Logging detallado para debugging
//
// Autor: Sistema BreakTimeTracker Flutter
// Fecha: Julio 2025

class TarjetaUtils {
  /// Parsea datos de tarjeta de banda magnética y extrae información útil.
  ///
  /// Esta función maneja múltiples formatos de tarjetas de banda magnética:
  /// - Formato Track 1: %B + datos + ?
  /// - Formato Track 2: ; + datos + ?
  /// - Formato mixto con múltiples tracks
  /// - Datos numéricos puros
  ///
  /// [rawData] - Datos crudos de la tarjeta leída por el lector
  ///
  /// Returns: Código limpio extraído de la tarjeta
  ///
  /// Examples:
  /// ```dart
  /// parseCardData("%B123456789^DOE/JOHN^2512101?") // "123456789"
  /// parseCardData(";123456789=2512101?")           // "123456789"
  /// parseCardData("123456789")                     // "123456789"
  /// ```
  static String parseCardData(String rawData) {
    if (rawData.isEmpty) {
      return "";
    }

    // Log de entrada para debugging
    print("🔍 parseCardData - Entrada: '$rawData'");

    // Limpiar espacios en blanco al inicio y final
    String cleanedData = rawData.trim();

    // Si está vacío después de limpiar, retornar vacío
    if (cleanedData.isEmpty) {
      print("⚠️ parseCardData - Datos vacíos después de limpiar");
      return "";
    }

    // Intentar diferentes patrones de parsing

    // Patrón 1: Track 1 (%B...^...^...?)
    RegExp track1Pattern = RegExp(r'%B(\d+)\^');
    RegExpMatch? track1Match = track1Pattern.firstMatch(cleanedData);
    if (track1Match != null) {
      String result = track1Match.group(1)!;
      print("✅ parseCardData - Patrón Track 1 encontrado: '$result'");
      return result;
    }

    // Patrón 2: Track 2 (;...=...?)
    RegExp track2Pattern = RegExp(r';(\d+)=');
    RegExpMatch? track2Match = track2Pattern.firstMatch(cleanedData);
    if (track2Match != null) {
      String result = track2Match.group(1)!;
      print("✅ parseCardData - Patrón Track 2 encontrado: '$result'");
      return result;
    }

    // Patrón 3: Secuencia numérica larga (más de 6 dígitos)
    RegExp numericPattern = RegExp(r'\d{6,}');
    RegExpMatch? numericMatch = numericPattern.firstMatch(cleanedData);
    if (numericMatch != null) {
      String result = numericMatch.group(0)!;
      print("✅ parseCardData - Secuencia numérica encontrada: '$result'");
      return result;
    }

    // Patrón 4: Limpiar caracteres especiales y quedarse con alfanuméricos
    String alphanumericOnly = cleanedData.replaceAll(
      RegExp(r'[^a-zA-Z0-9]'),
      '',
    );
    if (alphanumericOnly.isNotEmpty && alphanumericOnly.length >= 3) {
      String result = alphanumericOnly;
      print("✅ parseCardData - Datos alfanuméricos limpiados: '$result'");
      return result;
    }

    // Si no se encontró ningún patrón conocido, retornar datos originales limpiados
    print(
      "⚠️ parseCardData - No se encontró patrón conocido, retornando datos originales",
    );
    return cleanedData;
  }

  /// Valida si los datos de la tarjeta tienen un formato válido.
  ///
  /// [cardData] - Datos de la tarjeta a validar
  ///
  /// Returns: true si el formato es válido, false en caso contrario
  ///
  /// Examples:
  /// ```dart
  /// validateCardFormat("123456789") // true
  /// validateCardFormat("abc")       // false
  /// validateCardFormat("")          // false
  /// ```
  static bool validateCardFormat(String cardData) {
    if (cardData.isEmpty) {
      return false;
    }

    // Debe tener al menos 3 caracteres
    if (cardData.length < 3) {
      return false;
    }

    // Debe contener al menos algunos caracteres alfanuméricos
    if (!RegExp(r'[a-zA-Z0-9]').hasMatch(cardData)) {
      return false;
    }

    // No debe ser solo caracteres especiales
    if (RegExp(r'^[^a-zA-Z0-9]+$').hasMatch(cardData)) {
      return false;
    }

    return true;
  }

  /// Extrae información completa de una tarjeta de banda magnética.
  ///
  /// [rawData] - Datos crudos de la tarjeta
  ///
  /// Returns: Map con información extraída:
  /// - parsedCode: Código limpio extraído
  /// - isValid: Si el formato es válido
  /// - trackInfo: Información sobre el track detectado
  /// - rawLength: Longitud de los datos originales
  /// - cleanLength: Longitud de los datos limpios
  ///
  /// Examples:
  /// ```dart
  /// getCardInfo("%B123456789^DOE/JOHN^2512101?")
  /// // {
  /// //   'parsedCode': '123456789',
  /// //   'isValid': true,
  /// //   'trackInfo': 'Track 1',
  /// //   'rawLength': 28,
  /// //   'cleanLength': 9
  /// // }
  /// ```
  static Map<String, dynamic> getCardInfo(String rawData) {
    if (rawData.isEmpty) {
      return {
        'parsedCode': '',
        'isValid': false,
        'trackInfo': 'No data',
        'rawLength': 0,
        'cleanLength': 0,
        'error': 'No data provided',
      };
    }

    // Parsear el código
    String parsedCode = parseCardData(rawData);

    // Validar formato
    bool isValid = validateCardFormat(parsedCode);

    // Detectar tipo de track
    String trackInfo = 'Unknown';
    if (rawData.contains('%B') && rawData.contains('^')) {
      trackInfo = 'Track 1 (ISO/IEC 7813)';
    } else if (rawData.contains(';') && rawData.contains('=')) {
      trackInfo = 'Track 2 (ISO/IEC 7813)';
    } else if (RegExp(r'^\d+$').hasMatch(rawData.trim())) {
      trackInfo = 'Numeric only';
    } else if (RegExp(r'\d{6,}').hasMatch(rawData)) {
      trackInfo = 'Contains long numeric sequence';
    } else {
      trackInfo = 'Custom format';
    }

    return {
      'parsedCode': parsedCode,
      'isValid': isValid,
      'trackInfo': trackInfo,
      'rawLength': rawData.length,
      'cleanLength': parsedCode.length,
      'hasTrack1': rawData.contains('%B'),
      'hasTrack2': rawData.contains(';'),
      'numericSequences':
          RegExp(r'\d{3,}').allMatches(rawData).map((m) => m.group(0)).toList(),
      'specialChars': RegExp(r'[^a-zA-Z0-9]').allMatches(rawData).length,
    };
  }

  /// Extrae específicamente el código de empleado de los datos de la tarjeta.
  ///
  /// Esta función está optimizada para extraer códigos de empleado usando
  /// patrones específicos de la organización.
  ///
  /// [cardData] - Datos de la tarjeta
  /// [fallbackPatterns] - Patrones adicionales a probar (opcional)
  ///
  /// Returns: Código de empleado extraído
  ///
  /// Examples:
  /// ```dart
  /// extractEmployeeCode("EMPL123456")    // "123456"
  /// extractEmployeeCode("E123456789")    // "123456789"
  /// ```
  static String extractEmployeeCode(
    String cardData, {
    List<String>? fallbackPatterns,
  }) {
    if (cardData.isEmpty) {
      return "";
    }

    // Primero usar el parser general
    String generalParsed = parseCardData(cardData);

    // Patrones específicos para códigos de empleado
    List<String> employeePatterns = [
      r'EMPL(\d+)', // EMPL123456
      r'EMP(\d+)', // EMP123456
      r'E(\d{6,})', // E123456789
      r'ID(\d+)', // ID123456
      r'USER(\d+)', // USER123456
      r'CARD(\d+)', // CARD123456
    ];

    // Agregar patrones adicionales si se proporcionan
    if (fallbackPatterns != null) {
      employeePatterns.addAll(fallbackPatterns);
    }

    // Probar patrones específicos
    for (String pattern in employeePatterns) {
      RegExp regex = RegExp(pattern, caseSensitive: false);
      RegExpMatch? match = regex.firstMatch(cardData.toUpperCase());
      if (match != null) {
        String result = match.group(1)!;
        print(
          "✅ extractEmployeeCode - Patrón '$pattern' encontrado: '$result'",
        );
        return result;
      }
    }

    // Si no se encontró patrón específico, usar resultado general
    print("ℹ️ extractEmployeeCode - Usando parser general: '$generalParsed'");
    return generalParsed;
  }

  /// Limpia los datos de la tarjeta eliminando caracteres problemáticos.
  ///
  /// [rawData] - Datos crudos de la tarjeta
  ///
  /// Returns: Datos limpios
  ///
  /// Examples:
  /// ```dart
  /// cleanCardData("  %B123^DOE?  ")  // "%B123^DOE?"
  /// cleanCardData("123\n456\r789")   // "123456789"
  /// ```
  static String cleanCardData(String rawData) {
    if (rawData.isEmpty) {
      return "";
    }

    // Eliminar espacios en blanco al inicio y final
    String cleaned = rawData.trim();

    // Eliminar saltos de línea y retornos de carro
    cleaned = cleaned.replaceAll(RegExp(r'[\r\n\t]'), '');

    // Eliminar caracteres de control (excepto los específicos de banda magnética)
    cleaned = cleaned.replaceAll(RegExp(r'[\x00-\x1F\x7F-\x9F]'), '');

    return cleaned;
  }

  /// Determina si los datos corresponden a una tarjeta de banda magnética.
  ///
  /// [data] - Datos a verificar
  ///
  /// Returns: true si parece ser formato de banda magnética
  ///
  /// Examples:
  /// ```dart
  /// isMagneticStripeFormat("%B123456789^DOE/JOHN^2512101?") // true
  /// isMagneticStripeFormat("123456789")                     // false
  /// ```
  static bool isMagneticStripeFormat(String data) {
    if (data.isEmpty) {
      return false;
    }

    // Indicadores de formato de banda magnética
    List<String> magneticIndicators = [
      r'%[A-Z]', // Inicio de Track 1
      r';\d+=', // Patrón de Track 2
      r'\^[A-Z/\s]+\^', // Nombre en Track 1
      r'=\d{4}', // Fecha de expiración en Track 2
      r'\?\s*$', // Terminador de track
    ];

    // Verificar si coincide con algún indicador
    for (String pattern in magneticIndicators) {
      if (RegExp(pattern).hasMatch(data)) {
        return true;
      }
    }

    return false;
  }

  /// Función de debugging para analizar el parsing de tarjetas.
  ///
  /// [rawData] - Datos crudos de la tarjeta
  ///
  /// Returns: Map con información detallada de debugging
  static Map<String, dynamic> debugCardParsing(String rawData) {
    print("\n🔍 === DEBUG CARD PARSING ===");
    print("📥 Datos de entrada: '$rawData'");
    print("📏 Longitud: ${rawData.length} caracteres");

    // Información básica
    Map<String, dynamic> debugInfo = {
      'rawData': rawData,
      'rawLength': rawData.length,
      'isEmpty': rawData.isEmpty,
      'hasWhitespace': RegExp(r'\s').hasMatch(rawData),
      'hasSpecialChars': RegExp(r'[^a-zA-Z0-9]').hasMatch(rawData),
    };

    if (rawData.isEmpty) {
      print("❌ Datos vacíos");
      return debugInfo;
    }

    // Análisis de caracteres
    print("🔤 Análisis de caracteres:");
    print("   - Contiene espacios: ${debugInfo['hasWhitespace']}");
    print(
      "   - Contiene caracteres especiales: ${debugInfo['hasSpecialChars']}",
    );
    print("   - Caracteres únicos: ${rawData.split('').toSet().length}");

    // Verificar formato de banda magnética
    bool isMagnetic = isMagneticStripeFormat(rawData);
    debugInfo['isMagneticStripe'] = isMagnetic;
    print("🧲 Es formato de banda magnética: $isMagnetic");

    // Probar parsing
    try {
      String parsedResult = parseCardData(rawData);
      debugInfo['parsedResult'] = parsedResult;
      debugInfo['parsingSuccess'] = true;
      print("✅ Resultado del parsing: '$parsedResult'");
    } catch (e) {
      debugInfo['parsedResult'] = "";
      debugInfo['parsingSuccess'] = false;
      debugInfo['parsingError'] = e.toString();
      print("❌ Error en parsing: $e");
    }

    // Obtener información completa
    try {
      Map<String, dynamic> cardInfo = getCardInfo(rawData);
      debugInfo['cardInfo'] = cardInfo;
      print("📊 Información de tarjeta: $cardInfo");
    } catch (e) {
      debugInfo['cardInfoError'] = e.toString();
      print("❌ Error obteniendo info de tarjeta: $e");
    }

    print("🔍 === FIN DEBUG ===\n");
    return debugInfo;
  }

  /// Función de prueba para verificar el funcionamiento del módulo.
  static void testCardParsing() {
    print("🧪 === PRUEBAS DE PARSING DE TARJETAS ===\n");

    // Casos de prueba
    List<String> testCases = [
      // Formato Track 1
      "%B123456789^DOE/JOHN^2512101?",
      "%B4111111111111111^DOE/JANE^25121015432112345678?",

      // Formato Track 2
      ";123456789=2512101?",
      ";4111111111111111=25121015432112345678?",

      // Formato mixto
      "%B123456789^DOE/JOHN^2512101?;123456789=2512101?",

      // Numérico puro
      "123456789",
      "4111111111111111",

      // Datos con prefijos
      "EMPL123456",
      "E123456789",
      "ID987654321",

      // Datos problemáticos
      "  123456789  ",
      "123\n456\r789",
      "abc123def456",
      "",
      "!@#\$%^&*()",
    ];

    for (int i = 0; i < testCases.length; i++) {
      String testData = testCases[i];
      print("📋 Prueba ${i + 1}: '$testData'");

      try {
        // Parsing básico
        String result = parseCardData(testData);
        print("   ✅ Resultado: '$result'");

        // Validación
        bool isValid = validateCardFormat(result);
        print("   📊 Válido: $isValid");

        // Información completa
        Map<String, dynamic> cardInfo = getCardInfo(testData);
        print("   📄 Tipo: ${cardInfo['trackInfo']}");
      } catch (e) {
        print("   ❌ Error: $e");
      }

      print("");
    }

    print("🧪 === FIN PRUEBAS ===\n");
  }
}
