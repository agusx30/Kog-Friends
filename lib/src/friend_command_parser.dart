class FriendCommandParser {
  static final _addFriendPattern = RegExp(
    r'''^\s*add_friend\s+"((?:\\.|[^"])*)"\s+"((?:\\.|[^"])*)"\s*$''',
    caseSensitive: false,
  );

  static final _addPlayerPattern = RegExp(
    r'''^\s*add_player\s+(?:"((?:\\.|[^"])*)"|'((?:\\.|[^'])*)'|([^\s"'].*?))\s*$''',
    caseSensitive: false,
  );

  static List<String> parse(String input) {
    final names = <String>[];
    final seen = <String>{};
    final lines = input.split(RegExp(r'[\r\n]+'));

    for (var index = 0; index < lines.length; index++) {
      final line = lines[index].trim();
      if (line.isEmpty || line.startsWith('#') || line.startsWith('//')) {
        continue;
      }
      final addFriendMatch = _addFriendPattern.firstMatch(line);
      final addPlayerMatch = _addPlayerPattern.firstMatch(line);
      final rawName = addFriendMatch?.group(1) ??
          addPlayerMatch?.group(1) ??
          addPlayerMatch?.group(2) ??
          addPlayerMatch?.group(3) ??
          line; // Si no es un comando, tratar la línea entera como nombre
      final name = rawName.trim();
      final decodedName = _unescape(name);
      if (decodedName.isEmpty) {
        continue;
      }
      if (seen.add(decodedName.toLowerCase())) {
        names.add(decodedName);
      }
    }

    if (names.isEmpty) {
      throw const FormatException(
        'Escribí al menos un nombre o pegá un comando add_friend.',
      );
    }
    return names;
  }

  static String _unescape(String value) {
    return value.replaceAllMapped(
      RegExp(r'''\\(["'\\])'''),
      (match) => match.group(1)!,
    );
  }
}
