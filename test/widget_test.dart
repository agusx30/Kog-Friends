import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kog_friends/main.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('shows the empty friend list and online summary', (tester) async {
    await tester.pumpWidget(const KogFriendsApp());
    await tester.pumpAndSettle();

    expect(find.text('KOG Friends'), findsOneWidget);
    expect(find.text('0'), findsNWidgets(2));
    expect(find.text('de 0 amigos en línea'), findsOneWidget);
    expect(find.text('Todavía no agregaste amigos'), findsOneWidget);
  });

  testWidgets('opens the add-friends dialog with DDNet command guidance', (
    tester,
  ) async {
    await tester.pumpWidget(const KogFriendsApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Agregar amigos'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Se importa el nombre y se ignora el clan.'),
      findsOneWidget,
    );
    expect(
        find.textContaining('También se admite add_player.'), findsOneWidget);
    expect(find.text('add_friend "Nombre del jugador" "Clan"'), findsOneWidget);
  });

  testWidgets('opens the invite-help dialog with DDNet import instructions', (
    tester,
  ) async {
    await tester.pumpWidget(const KogFriendsApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cómo invitar?'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(
      find.text(r'%appdata%\Roaming\DDNet\settings_ddnet.cfg'),
      findsOneWidget,
    );
    expect(find.textContaining('add_friend "Dkz"'), findsOneWidget);
    expect(find.textContaining('add_friend "agusx30"'), findsOneWidget);
  });
}
