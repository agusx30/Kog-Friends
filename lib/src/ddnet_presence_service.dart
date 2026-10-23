import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class ServerPresence {
  const ServerPresence({
    required this.serverName,
    required this.mapName,
    required this.location,
  });

  final String serverName;
  final String mapName;
  final String location;
}

class DDNetPresenceService {
  DDNetPresenceService(this._client);

  static final _endpoint = Uri.parse(
    'https://master1.ddnet.org/ddnet/15/servers.json',
  );

  final http.Client _client;
  String? _etag;
  Map<String, ServerPresence>? _lastResult;

  Future<Map<String, ServerPresence>> findFriends(
    List<String> friendNames,
  ) async {
    if (friendNames.isEmpty) return const {};

    final headers = <String, String>{'Accept': 'application/json'};
    if (_etag != null) headers['If-None-Match'] = _etag!;

    final response = await _client
        .get(_endpoint, headers: headers)
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 304) {
      final cached = _lastResult;
      if (cached == null) {
        throw StateError(
          'El servidor devolvió 304 sin datos previos para reutilizar.',
        );
      }
      return _filterFriends(cached, friendNames);
    }
    if (response.statusCode != 200) {
      throw http.ClientException(
        'La lista de servidores respondió HTTP ${response.statusCode}.',
        _endpoint,
      );
    }
    final responseEtag = response.headers['etag'];
    if (responseEtag != null) _etag = responseEtag;

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic> ||
        decoded['servers'] is! List<dynamic>) {
      throw const FormatException(
        'La respuesta de servidores tiene un formato inesperado.',
      );
    }

    final presenceByName = <String, ServerPresence>{};
    for (final serverValue in decoded['servers'] as List<dynamic>) {
      if (serverValue is! Map<String, dynamic>) continue;

      final info = serverValue['info'];
      if (info is! Map<String, dynamic>) continue;
      final clients = info['clients'];
      if (clients is! List<dynamic>) continue;

      final map = info['map'];
      final mapName = map is Map<String, dynamic>
          ? map['name']?.toString() ?? 'Mapa desconocido'
          : 'Mapa desconocido';
      final serverName = info['name']?.toString() ?? 'Servidor DDNet';
      final location = serverValue['location']?.toString() ?? '';
      for (final clientValue in clients) {
        if (clientValue is! Map<String, dynamic>) continue;
        final playerName = clientValue['name'];
        if (playerName is! String || playerName.isEmpty) continue;
        presenceByName.putIfAbsent(
          playerName.toLowerCase(),
          () => ServerPresence(
            serverName: serverName,
            mapName: mapName,
            location: location,
          ),
        );
      }
    }

    _lastResult = presenceByName;
    return _filterFriends(presenceByName, friendNames);
  }

  Map<String, ServerPresence> _filterFriends(
    Map<String, ServerPresence> presenceByName,
    List<String> friendNames,
  ) {
    final matches = <String, ServerPresence>{};
    for (final friend in friendNames) {
      final presence = presenceByName[friend.toLowerCase()];
      if (presence != null) matches[friend.toLowerCase()] = presence;
    }
    return matches;
  }

  void close() => _client.close();
}
