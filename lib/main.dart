import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'src/friend_command_parser.dart';
import 'src/kog_presence_service.dart';

void main() {
  runApp(const KogFriendsApp());
}

class KogFriendsApp extends StatelessWidget {
  const KogFriendsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KOG Friends',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF101318),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFB9F36A),
          brightness: Brightness.dark,
          surface: const Color(0xFF191E25),
        ),
        useMaterial3: true,
      ),
      home: const FriendsPage(),
    );
  }
}

class FriendsPage extends StatefulWidget {
  const FriendsPage({super.key});

  @override
  State<FriendsPage> createState() => _FriendsPageState();
}

class _FriendsPageState extends State<FriendsPage> with WidgetsBindingObserver {
  static const _friendsKey = 'friend_names_v1';
  static const _refreshInterval = Duration(seconds: 30);

  final _presenceService = KogPresenceService(http.Client());
  List<String> _friends = [];
  Map<String, ServerPresence> _onlineFriends = {};
  DateTime? _lastUpdated;
  Timer? _refreshTimer;
  String? _error;
  bool _loading = true;
  bool _refreshing = false;
  bool _refreshPending = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _restoreFriends();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    _presenceService.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startForegroundRefresh();
      _refreshPresence();
    } else {
      _refreshTimer?.cancel();
      _refreshTimer = null;
    }
  }

  Future<void> _restoreFriends() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final saved = preferences.getString(_friendsKey);
      final names = saved == null
          ? <String>[]
          : (jsonDecode(saved) as List<dynamic>).cast<String>();
      if (!mounted) return;
      setState(() {
        _friends = names;
        _loading = false;
      });
      _startForegroundRefresh();
      await _refreshPresence();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'No se pudo cargar la lista guardada: $error';
      });
    }
  }

  void _startForegroundRefresh() {
    _refreshTimer ??= Timer.periodic(_refreshInterval, (_) {
      _refreshPresence();
    });
  }

  Future<void> _refreshPresence() async {
    if (_loading) return;
    if (_refreshing) {
      _refreshPending = true;
      return;
    }
    if (_friends.isEmpty) {
      if (_onlineFriends.isNotEmpty) {
        setState(() {
          _onlineFriends = {};
        });
      }
      return;
    }
    final requestedFriends = List<String>.of(_friends);
    setState(() {
      _refreshing = true;
      _error = null;
    });
    try {
      final result = await _presenceService.findFriends(requestedFriends);
      if (!mounted) return;
      final currentNames = _friends.map((name) => name.toLowerCase()).toSet();
      setState(() {
        _onlineFriends = Map.fromEntries(
          result.entries.where((entry) => currentNames.contains(entry.key)),
        );
        _lastUpdated = DateTime.now();
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudo actualizar el estado: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _refreshing = false;
        });
        if (_refreshPending) {
          _refreshPending = false;
          unawaited(_refreshPresence());
        }
      }
    }
  }

  Future<void> _saveFriends(List<String> names) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_friendsKey, jsonEncode(names));
  }

  Future<void> _addFriends(String pastedCommands) async {
    late final List<String> parsed;
    try {
      parsed = FriendCommandParser.parse(pastedCommands);
    } on FormatException catch (error) {
      _showMessage(error.message.toString());
      return;
    }

    final existing = _friends.map((name) => name.toLowerCase()).toSet();
    final additions =
        parsed.where((name) => existing.add(name.toLowerCase())).toList();
    final updated = [..._friends, ...additions];
    try {
      await _saveFriends(updated);
    } catch (error) {
      _showMessage('No se pudo guardar la lista: $error');
      return;
    }

    if (!mounted) return;
    setState(() {
      _friends = updated;
      _onlineFriends = {};
      _lastUpdated = null;
    });
    Navigator.of(context).pop();
    if (additions.isEmpty) {
      _showMessage('Los amigos ya estaban en la lista.');
      return;
    }
    _refreshPresence();
  }

  Future<void> _removeFriend(String name) async {
    final updated = _friends.where((friend) => friend != name).toList();
    try {
      await _saveFriends(updated);
    } catch (error) {
      _showMessage('No se pudo guardar el cambio: $error');
      return;
    }
    if (!mounted) return;
    setState(() {
      _friends = updated;
      _onlineFriends.remove(name.toLowerCase());
    });
    _refreshPresence();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showAddDialog() async {
    final controller = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Agregar amigos'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Pegá los comandos add_friend copiados de DDNet. '
                'Se importa el nombre y se ignora el clan. '
                'También se admite add_player.',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                minLines: 3,
                maxLines: 7,
                decoration: const InputDecoration(
                  hintText: 'add_friend "Nombre del jugador" "Clan"',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => _addFriends(controller.text),
            child: const Text('Agregar'),
          ),
        ],
      ),
    );
    controller.dispose();
  }

  Future<void> _showInviteDialog() async {
    final theme = Theme.of(context);

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cómo invitar?'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Hay dos formas de importar amigos:'),
                const SizedBox(height: 12),
                const Text('1. Agrégalos uno por uno pegando un comando add_friend.'),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const SelectableText(
                    'add_friend "Dkz" "|*KoG*|"\n'
                    'add_friend "Floῳless" ""\n'
                    'add_friend "Serafim" ""\n'
                    'add_friend "Peoxx" ""\n'
                    'add_friend "Zer0" ""\n'
                    'add_friend "agusx30" ""',
                    style: TextStyle(fontFamily: 'monospace'),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  '2. O abrí %appdata%\\Roaming\\DDNet\\settings_ddnet.cfg '
                  'y copiá el bloque final con add_friend para importarlos todos a la vez.',
                ),
                const SizedBox(height: 8),
                SelectableText(
                  r'%appdata%\Roaming\DDNet\settings_ddnet.cfg',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Listo'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sortedFriends = [..._friends]..sort((a, b) {
        final aOnline = _onlineFriends.containsKey(a.toLowerCase());
        final bOnline = _onlineFriends.containsKey(b.toLowerCase());
        if (aOnline != bOnline) return aOnline ? -1 : 1;
        return a.toLowerCase().compareTo(b.toLowerCase());
      });

    return Scaffold(
      appBar: AppBar(
        title: const Text('KOG Friends'),
        actions: [
          IconButton(
            tooltip: 'Actualizar ahora',
            onPressed:
                _refreshing || _friends.isEmpty ? null : _refreshPresence,
            icon: _refreshing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(left: 32),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton.icon(
              onPressed: _showInviteDialog,
              icon: const Icon(Icons.help_outline),
              label: const Text('Cómo invitar?'),
              style: TextButton.styleFrom(
                backgroundColor: theme.colorScheme.surfaceContainerHigh,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
            const SizedBox(width: 8),
            FloatingActionButton.extended(
              onPressed: _showAddDialog,
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('Agregar amigos'),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _refreshPresence,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  children: [
                    _SummaryCard(
                      onlineCount: _onlineFriends.length,
                      totalCount: _friends.length,
                      lastUpdated: _lastUpdated,
                      refreshing: _refreshing,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      _ErrorCard(message: _error!),
                    ],
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Text('TUS AMIGOS', style: theme.textTheme.labelLarge),
                        const Spacer(),
                        Text(
                          '${_friends.length}',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (_friends.isEmpty)
                      const _EmptyFriendsCard()
                    else
                      ...sortedFriends.map((name) {
                        final presence = _onlineFriends[name.toLowerCase()];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _FriendTile(
                            name: name,
                            presence: presence,
                            onRemove: () => _removeFriend(name),
                          ),
                        );
                      }),
                  ],
                ),
              ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.onlineCount,
    required this.totalCount,
    required this.lastUpdated,
    required this.refreshing,
  });

  final int onlineCount;
  final int totalCount;
  final DateTime? lastUpdated;
  final bool refreshing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(18),
              ),
              child:
                  Icon(Icons.sports_esports, color: theme.colorScheme.primary),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$onlineCount',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    'de $totalCount amigos en línea',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    lastUpdated == null
                        ? (refreshing ? 'Actualizando…' : 'Sin datos recientes')
                        : 'Actualizado ${_formatTime(lastUpdated!)}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FriendTile extends StatelessWidget {
  const _FriendTile({
    required this.name,
    required this.presence,
    required this.onRemove,
  });

  final String name;
  final ServerPresence? presence;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final online = presence != null;
    final serverDetails = presence == null
        ? ''
        : '${presence!.serverName}\n${presence!.mapName}'
            '${presence!.location.isEmpty ? '' : ' · ${presence!.location}'}';
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: online
              ? const Color(0xFFB9F36A).withValues(alpha: 0.16)
              : theme.colorScheme.surface,
          child: Icon(
            online ? Icons.circle : Icons.person_outline,
            size: online ? 13 : 22,
            color: online ? const Color(0xFFB9F36A) : theme.colorScheme.outline,
          ),
        ),
        title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          online ? serverDetails : 'Sin conexión en KOG',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        isThreeLine: online,
        trailing: IconButton(
          tooltip: 'Quitar de la lista',
          onPressed: onRemove,
          icon: const Icon(Icons.close),
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.cloud_off_outlined),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }
}

class _EmptyFriendsCard extends StatelessWidget {
  const _EmptyFriendsCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
        child: Column(
          children: [
            Icon(
              Icons.group_outlined,
              size: 36,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            const Text('Todavía no agregaste amigos'),
            const SizedBox(height: 4),
            Text(
              'Pegá tus comandos add_friend para empezar.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

String _formatTime(DateTime time) {
  final local = time.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}
