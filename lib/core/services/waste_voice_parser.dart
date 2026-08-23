import '../../data/models/submission_model.dart';

class ParsedWasteItem {
  final String subtipe;
  final WasteCategory kategori;
  final double beratKg;

  const ParsedWasteItem({
    required this.subtipe,
    required this.kategori,
    required this.beratKg,
  });
}

class WasteVoiceParseResult {
  final List<ParsedWasteItem> items;
  final bool isClear;

  const WasteVoiceParseResult({required this.items, required this.isClear});

  factory WasteVoiceParseResult.unclear() =>
      const WasteVoiceParseResult(items: [], isClear: false);
}

/// Extracts waste category/subtype/weight from an Indonesian voice
/// transcript such as "Saya setor 5 kilo botol plastik dan 2 kilo sisa sayur".
///
/// Kept behind an interface so this regex/keyword implementation can later
/// be swapped for the Sari gateway without touching callers.
abstract class WasteVoiceParser {
  WasteVoiceParseResult parse(String transcript);
}

class RegexWasteVoiceParser implements WasteVoiceParser {
  static final Map<String, MapEntry<WasteCategory, String>> _keywords = {
    'botol plastik': MapEntry(WasteCategory.anorganik, 'Botol Plastik PET'),
    'plastik pet': MapEntry(WasteCategory.anorganik, 'Botol Plastik PET'),
    'plastik': MapEntry(WasteCategory.anorganik, 'Plastik'),
    'kardus': MapEntry(WasteCategory.anorganik, 'Kardus & Kertas'),
    'kertas': MapEntry(WasteCategory.anorganik, 'Kardus & Kertas'),
    'logam': MapEntry(WasteCategory.anorganik, 'Logam & Kaleng'),
    'kaleng': MapEntry(WasteCategory.anorganik, 'Logam & Kaleng'),
    'kaca': MapEntry(WasteCategory.anorganik, 'Kaca'),
    'sisa sayur': MapEntry(WasteCategory.organik, 'Sisa Sayur & Buah'),
    'sisa buah': MapEntry(WasteCategory.organik, 'Sisa Sayur & Buah'),
    'sayur': MapEntry(WasteCategory.organik, 'Sisa Sayur & Buah'),
    'buah': MapEntry(WasteCategory.organik, 'Sisa Sayur & Buah'),
    'sisa makanan': MapEntry(WasteCategory.organik, 'Sisa Makanan'),
    'ampas kopi': MapEntry(WasteCategory.organik, 'Ampas Kopi'),
    'sisa dapur': MapEntry(WasteCategory.organik, 'Sampah Organik Dapur'),
  };

  static final RegExp _numberUnit = RegExp(
    r'(\d+(?:[.,]\d+)?)\s*(kilogram|kilo|kg|ons|gram)',
    caseSensitive: false,
  );

  @override
  WasteVoiceParseResult parse(String transcript) {
    final text = transcript.toLowerCase().trim();
    if (text.isEmpty) return WasteVoiceParseResult.unclear();

    final segments = text.split(RegExp(r'\bdan\b|,'));
    final items = <ParsedWasteItem>[];

    for (final segment in segments) {
      final match = _numberUnit.firstMatch(segment);
      if (match == null) continue;

      var value = double.tryParse(match.group(1)!.replaceAll(',', '.')) ?? 0;
      final unit = match.group(2)!.toLowerCase();
      if (unit == 'gram') {
        value = value * 0.001;
      } else if (unit == 'ons') {
        value = value * 0.1;
      }
      if (value <= 0) continue;

      String? matchedKeyword;
      for (final keyword in _keywords.keys) {
        if (segment.contains(keyword)) {
          if (matchedKeyword == null ||
              keyword.length > matchedKeyword.length) {
            matchedKeyword = keyword;
          }
        }
      }
      if (matchedKeyword == null) continue;

      final entry = _keywords[matchedKeyword]!;
      items.add(
        ParsedWasteItem(
          subtipe: entry.value,
          kategori: entry.key,
          beratKg: double.parse(value.toStringAsFixed(2)),
        ),
      );
    }

    return WasteVoiceParseResult(items: items, isClear: items.isNotEmpty);
  }
}
