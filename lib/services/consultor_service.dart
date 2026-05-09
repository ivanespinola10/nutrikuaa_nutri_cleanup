import 'package:firebase_vertexai/firebase_vertexai.dart';

class NutrikuaaConsultant {
  late final GenerativeModel _model;
  // Agregamos una sesión de chat persistente
  late final ChatSession _chatSession;

  NutrikuaaConsultant() {
    _model = FirebaseVertexAI.instanceFor(location: 'us-central1')
        .generativeModel(
          model: 'gemini-2.5-flash-lite',
          systemInstruction: Content.system('''
        Rol: Eres el Consultor Virtual Senior de Nutrikuaa, experto en ISO 9001, 
        FSSC 22000 y Leyes Alimentarias de Paraguay.
        Reglas:
        1. Sé breve y directo en el chat.
        2. Cita normas (ISO 9001 Cláusula X).
        3. Si te saludan, sé amable pero profesional.
      '''),
        );
    // Iniciamos la sesión una sola vez al arrancar
    _chatSession = _model.startChat();
  }

  Future<String?> preguntar(String mensajeUsuario) async {
    try {
      // Enviamos mensaje a la sesión existente (mantiene el historial)
      final response = await _chatSession.sendMessage(
        Content.text(mensajeUsuario),
      );
      return response.text;
    } catch (e) {
      return "Error de conexión: $e";
    }
  }
}
