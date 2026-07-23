import '../data/data.dart'; // Pour importer CandleData

abstract class MarketRepository {
  // Le contrat : "Je promets de fournir une liste de bougies pour un actif donné"
  Future<List<CandleData>> getHistory(String commodityName);
}