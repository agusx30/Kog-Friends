import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kog_friends/src/ddnet_presence_service.dart';

void main() {
  group('DDNetPresenceService', () {
    test('matches friends case-insensitively across all servers', () async {
      final client = MockClient((request) async {
        return http.Response(
          '''
          {
            "servers": [
              {
                "community": "kog",
                "location": "eu:de",
                "info": {
                  "name": "KOG Solo",
                  "map": {"name": "TestMap"},
                  "clients": [{"name": "Player One", "is_player": true}]
                }
              },
              {
                "community": "ddnet",
                "info": {
                  "name": "DDNet Server",
                  "map": {"name": "Other"},
                  "clients": [{"name": "Player Two", "is_player": true}]
                }
              }
            ]
          }
          ''',
          200,
        );
      });
      final service = DDNetPresenceService(client);

      final result = await service.findFriends(['PLAYER ONE', 'Player Two']);

      expect(result.keys, ['player one', 'player two']);
      expect(result['player one']?.serverName, 'KOG Solo');
      expect(result['player two']?.serverName, 'DDNet Server');
      service.close();
    });

    test('uses the ETag cache after a not-modified response', () async {
      var requestCount = 0;
      final client = MockClient((request) async {
        requestCount++;
        if (requestCount == 1) {
          return http.Response(
            '{"servers":[{"community":"ddnet","info":{"name":"DDNet","map":{"name":"Map"},"clients":[{"name":"Friend"}]}}]}',
            200,
            headers: {'etag': '"test-etag"'},
          );
        }
        expect(request.headers['if-none-match'], '"test-etag"');
        return http.Response('', 304);
      });
      final service = DDNetPresenceService(client);

      final first = await service.findFriends(['Friend']);
      final second = await service.findFriends(['Friend']);

      expect(first.keys, ['friend']);
      expect(second.keys, ['friend']);
      expect(requestCount, 2);
      service.close();
    });

    test('throws an explicit error for unsuccessful server responses',
        () async {
      final service = DDNetPresenceService(
        MockClient((request) async => http.Response('unavailable', 503)),
      );

      await expectLater(
        service.findFriends(['Friend']),
        throwsA(isA<http.ClientException>()),
      );
      service.close();
    });
  });
}
