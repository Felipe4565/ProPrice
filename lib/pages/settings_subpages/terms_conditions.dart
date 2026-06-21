import 'package:flutter/material.dart';

class TermsAndConditionsPage extends StatelessWidget {
  const TermsAndConditionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2EFE9),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B4332),
        elevation: 0,
        title: const Text(
          "Términos y Condiciones",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle("1. Introducción"),
            _buildParagraph(
                "Bienvenido a ProPrice. Al acceder y utilizar nuestra aplicación, aceptas estar sujeto a los siguientes términos y condiciones. Si no estás de acuerdo con alguno de estos términos, te rogamos que no utilices la aplicación."),
            
            _buildSectionTitle("2. Uso de la Aplicación"),
            _buildParagraph(
                "Te comprometes a utilizar ProPrice únicamente para fines legales y de manera que no infrinja los derechos de terceros ni restrinja o impida el uso y disfrute de la aplicación por parte de otros usuarios."),
            
            _buildSectionTitle("3. Propiedad Intelectual"),
            _buildParagraph(
                "Todo el contenido, marcas registradas, logotipos y software presentes en esta aplicación son propiedad exclusiva de ProPrice y están protegidos por las leyes de propiedad intelectual."),
            
            _buildSectionTitle("4. Limitación de Responsabilidad"),
            _buildParagraph(
                "ProPrice se proporciona 'tal cual', sin garantías de ningún tipo. No seremos responsables por daños directos, indirectos, incidentales o consecuentes derivados del uso de nuestra aplicación."),
            
            _buildSectionTitle("5. Modificaciones"),
            _buildParagraph(
                "Nos reservamos el derecho de modificar estos términos en cualquier momento. Los cambios entrarán en vigor inmediatamente después de su publicación en la aplicación."),
            
            const SizedBox(height: 30),
            const Divider(color: Color(0xFF1B4332)),
            const SizedBox(height: 10),
            Center(
              child: Text(
                "Última actualización: 28 de mayo de 2026",
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 10),
      child: Text(
        title,
        style: const TextStyle(
          color: Color(0xFF1B4332),
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
    );
  }

  Widget _buildParagraph(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.black87,
        fontSize: 15,
        height: 1.5,
      ),
      textAlign: TextAlign.justify,
    );
  }
}