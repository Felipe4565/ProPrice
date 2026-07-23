// lib/repositories/mock_market_repository.dart
import '../data/data.dart'; // Pour CandleData et generateMasterHistory
import 'market_repository.dart'; // Pour l'interface MarketRepository

class MockMarketRepository implements MarketRepository {
  @override
  Future<List<CandleData>> getHistory(String commodityName) async {
    // Simule une latence réseau
    await Future.delayed(const Duration(milliseconds: 500));
    
    // Appel à la fonction que nous avons définie dans data.dart
    return generateMasterHistory(commodityName); 
  }
}