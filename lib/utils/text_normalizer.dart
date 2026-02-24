const Map<String, String> _diacriticMap = {
  'a': 'a',
  'á': 'a',
  'à': 'a',
  'ä': 'a',
  'â': 'a',
  'ã': 'a',
  'å': 'a',
  'e': 'e',
  'é': 'e',
  'è': 'e',
  'ë': 'e',
  'ê': 'e',
  'i': 'i',
  'í': 'i',
  'ì': 'i',
  'ï': 'i',
  'î': 'i',
  'o': 'o',
  'ó': 'o',
  'ò': 'o',
  'ö': 'o',
  'ô': 'o',
  'õ': 'o',
  'u': 'u',
  'ú': 'u',
  'ù': 'u',
  'ü': 'u',
  'û': 'u',
  'ñ': 'n',
  'ç': 'c',
};

final RegExp _asciiWordChar = RegExp(r'[a-z0-9]');
final RegExp _spaceRun = RegExp(r'\s+');

String normalizeForSearch(String input) {
  final lowered = input.toLowerCase().trim();
  if (lowered.isEmpty) return '';

  final buffer = StringBuffer();
  var prevSpace = false;
  for (final rune in lowered.runes) {
    final char = String.fromCharCode(rune);
    final mapped = _diacriticMap[char] ?? char;
    final normalized = _asciiWordChar.hasMatch(mapped) ? mapped : ' ';
    if (normalized == ' ') {
      if (!prevSpace) {
        buffer.write(' ');
        prevSpace = true;
      }
      continue;
    }
    buffer.write(normalized);
    prevSpace = false;
  }

  return buffer.toString().replaceAll(_spaceRun, ' ').trim();
}
