/// ===============================================================
/// 🧩 StringUtils — Utilidades globales de texto
/// ===============================================================
/// - Normaliza texto (sin tildes ni ñ)
/// - Convierte nombres de países a códigos ISO-2
/// - Incluye helpers de capitalización y slugify
/// ===============================================================
library;

/// 🔠 Normaliza texto: quita tildes, acentos y espacios innecesarios
String normalizeText(String s) {
  const replacements = {
    'á': 'a',
    'à': 'a',
    'ä': 'a',
    'â': 'a',
    'é': 'e',
    'è': 'e',
    'ë': 'e',
    'ê': 'e',
    'í': 'i',
    'ì': 'i',
    'ï': 'i',
    'î': 'i',
    'ó': 'o',
    'ò': 'o',
    'ö': 'o',
    'ô': 'o',
    'ú': 'u',
    'ù': 'u',
    'ü': 'u',
    'û': 'u',
    'ñ': 'n'
  };

  final buffer = StringBuffer();
  for (final rune in s.trim().toLowerCase().runes) {
    final char = String.fromCharCode(rune);
    buffer.write(replacements[char] ?? char);
  }
  return buffer.toString();
}

/// 🌍 Convierte nombre o código de país a ISO-2 estándar
String? toIso2OrGuess(String? name) {
  if (name == null || name.isEmpty) return null;
  final n = normalizeText(name);

  const map = {
    'colombia': 'CO',
    'mexico': 'MX',
    'argentina': 'AR',
    'chile': 'CL',
    'peru': 'PE',
    'espana': 'ES',
    'ecuador': 'EC',
    'bolivia': 'BO',
    'uruguay': 'UY',
    'paraguay': 'PY',
    'venezuela': 'VE',
    'brasil': 'BR',
    'usa': 'US',
    'estados unidos': 'US',
    'canada': 'CA',
    'inglaterra': 'GB',
    'reino unido': 'GB',
    'francia': 'FR',
    'italia': 'IT',
    'alemania': 'DE',
    'japon': 'JP',
    'china': 'CN',
    'corea': 'KR',
    'india': 'IN',
    'australia': 'AU',
    'nueva zelanda': 'NZ',
    'portugal': 'PT',
    'suiza': 'CH',
    'turquia': 'TR',
    'rusia': 'RU',
    'arabia saudita': 'SA',
    'sudafrica': 'ZA',
  };

  for (final entry in map.entries) {
    if (n.contains(entry.key)) return entry.value;
  }

  // Si ya está en formato ISO o abreviado
  if (n.length == 2) return n.toUpperCase();

  return null;
}

/// 🔤 Capitaliza la primera letra de una cadena
String capitalize(String s) {
  if (s.isEmpty) return s;
  return s[0].toUpperCase() + s.substring(1);
}

/// 🧾 Crea un slug (para URLs o IDs legibles)
String slugify(String text) {
  final norm = normalizeText(text);
  return norm
      .replaceAll(RegExp(r'[^a-z0-9\s-]'), '')
      .replaceAll(RegExp(r'\s+'), '-')
      .replaceAll(RegExp(r'-+'), '-')
      .trim();
}
