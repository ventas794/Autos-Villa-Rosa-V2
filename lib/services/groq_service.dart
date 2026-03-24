// lib/services/groq_service.dart
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart'; // ← Añadido para debugPrint

class GroqService {
  static Future<String> generarParrafoIA(Map<String, dynamic> cocheData) async {
    try {
      final apiKey = dotenv.env['GROQ_API_KEY'] ?? '';
      if (apiKey.isEmpty) {
        throw Exception('GROQ_API_KEY no encontrado en .env');
      }

      // Preparar datos (sin fecha_matriculacion)
      final marca = cocheData['marca']?.toString() ?? 'Desconocida';
      final modelo = cocheData['modelo']?.toString() ?? '';
      final cc = cocheData['cc']?.toString() ?? 'N/D';
      final cv = cocheData['cv']?.toString() ?? 'N/D';
      final km = cocheData['km']?.toString() ?? 'N/D';
      final combustible = cocheData['combustible']?.toString() ?? 'N/D';
      final transmision = cocheData['transmision']?.toString() ?? 'N/D';

      final caracteristicasList =
          cocheData['caracteristicas'] as List<dynamic>? ?? [];
      final caracteristicas = caracteristicasList.join(', ');

      // Prompt optimizado (sin fecha de matriculación ni ITV)
      final prompt = '''
Eres un redactor experto en anuncios de coches usados de calidad.
Escribe UN PÁRRAFO de 5-6 líneas (aprox. 90-130 palabras), muy atractivo, persuasivo y natural en español.
Datos del vehículo:
Marca y modelo: $marca $modelo
Motor: $cc cc, $cv CV, $combustible
Kilómetros: $km
Transmisión: $transmision
Características: $caracteristicas
Reglas obligatorias:
- Menciona los aspectos positivos (potencia, equilibrio, tipo de conduccion).
- Haz que el párrafo suene profesional, confiable y entusiasta, destacando por qué este coche es una gran oportunidad.
Escribe solo el párrafo, sin títulos, sin emojis, sin listas.
''';

      final response = await http.post(
        Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'llama-3.3-70b-versatile',
          'messages': [
            {'role': 'user', 'content': prompt},
          ],
          'temperature': 0.75,
          'max_tokens': 250,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'] as String;
        debugPrint(
            'Groq respondió: $content'); // ← Corregido: debugPrint en lugar de print
        return content.trim();
      } else {
        debugPrint(
            'Error Groq: ${response.statusCode} - ${response.body}'); // ← Corregido
        return fallbackParrafo();
      }
    } catch (e) {
      debugPrint('Excepción Groq: $e'); // ← Corregido
      return fallbackParrafo();
    }
  }

  static String fallbackParrafo() {
    return 'Vehículo en excelente estado general, con un motor equilibrado y equipamiento completo que garantiza comodidad y seguridad en cada trayecto.';
  }
}
