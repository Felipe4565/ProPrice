import 'package:flutter/material.dart';
import 'package:proprice/providers/app_settings.dart';
import 'package:provider/provider.dart';

import '../../theme/app_colors.dart';

class CurrencyPage extends StatefulWidget {
  const CurrencyPage({super.key});

  @override
  State<CurrencyPage> createState() => _CurrencyPageState();
}

class _CurrencyPageState extends State<CurrencyPage> {
  String _selectedCurrency = 'USD';
  final List<String> _currencies = ['USD', 'EUR', 'MXN', 'GBP'];

  @override
  Widget build(BuildContext context) {
    // On récupère l'instance des réglages pour lire les valeurs
    final appSettings = context.watch<AppSettings>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        // Avant : backgroundColor: forestGreen (bandeau vert plein).
        title: const Text("Valores y Divisa", style: TextStyle(color: AppColors.forest700)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.forest700, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- SECTION 1 : DIVISA ---
            _buildSectionHeader(Icons.attach_money, "Moneda principal"),
            const SizedBox(height: 10),
            Card(
              elevation: 0,
              color: AppColors.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Column(
                children: _currencies.map((currency) {
                  return RadioListTile<String>(
                    title: Text(currency, style: const TextStyle(fontWeight: FontWeight.w600)),
                    value: currency,
                    groupValue: _selectedCurrency,
                    activeColor: AppColors.forest500,
                    onChanged: (value) => setState(() => _selectedCurrency = value!),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 30),

            // --- SECTION 2 : BALANZA ---
            _buildSectionHeader(Icons.account_balance_wallet, "Preferencias de Balanza"),
            const SizedBox(height: 10),
            Card(
              elevation: 0,
              color: AppColors.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text("Ocultar saldo", style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text("Ocultar cifras en la pantalla principal"),
                    value: appSettings.hideBalance,
                    activeColor: AppColors.forest500,
                    activeTrackColor: AppColors.forest500.withValues(alpha: 0.3),
                    onChanged: (val) => context.read<AppSettings>().toggleHideBalance(val),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    title: const Text("Gráficos detallados", style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text("Ver fluctuaciones del mercado"),
                    value: appSettings.showDetailedCharts,
                    activeColor: AppColors.forest500,
                    activeTrackColor: AppColors.forest500.withValues(alpha: 0.3),
                    onChanged: (val) => context.read<AppSettings>().toggleShowDetailedCharts(val),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, color: AppColors.forest500, size: 20),
        const SizedBox(width: 8),
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            color: AppColors.forest500,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }
}