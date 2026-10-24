import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'src/app_strings.dart';
import 'src/ddnet_presence_service.dart';
import 'src/friend_command_parser.dart';

void main() {
  runApp(const DDNetFriendsApp());
}

class DDNetFriendsApp extends StatelessWidget {
  const DDNetFriendsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DDNet Friends',
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
  static const _languageKey = 'app_language_v1';
  static const _refreshInterval = Duration(seconds: 30);

  final _presenceService = DDNetPresenceService(http.Client());
  AppLanguage _language = AppLanguage.es;
  List<String> _friends = [];
  Map<String, ServerPresence> _onlineFriends = {};
  DateTime? _lastUpdated;
  Timer? _refreshTimer;
  String? _error;
  bool _loading = true;
  bool _refreshing = false;
  bool _refreshPending = false;
  bool _activeExpanded = true;
  bool _inactiveExpanded = true;

  AppStrings get _strings => AppStrings(_language);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _restoreState();
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

  Future<void> _restoreState() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final savedLanguage = preferences.getString(_languageKey);
      final saved = preferences.getString(_friendsKey);
      final names = saved == null
          ? <String>[]
          : (jsonDecode(saved) as List<dynamic>).cast<String>();
      if (!mounted) return;
      setState(() {
        _language = AppLanguage.fromCode(savedLanguage);
        _friends = names;
        _loading = false;
      });
      _startForegroundRefresh();
      await _refreshPresence();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _strings.loadError(error);
      });
    }
  }

  Future<void> _setLanguage(AppLanguage language) async {
    setState(() {
      _language = language;
    });
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(_languageKey, language.code);
    } catch (_) {
      // Ignore persistence errors.
    }
    unawaited(_updateWidget());
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
      unawaited(_updateWidget());
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
      unawaited(_updateWidget());
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _strings.refreshError(error);
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

  Future<void> _updateWidget() async {
    try {
      final onlineCount = _onlineFriends.length;
      final totalCount = _friends.length;
      await HomeWidget.saveWidgetData<String>('title', 'DDNet Friends');
      await HomeWidget.saveWidgetData<String>(
        'message',
        _strings.widgetSummary(onlineCount, totalCount),
      );
      await HomeWidget.updateWidget(name: 'AppWidgetProvider');
    } catch (_) {
      // Ignore widget errors on unsupported platforms or tests.
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
    } on FormatException {
      _showMessage(_strings.emptyInputError);
      return;
    }

    final existing = _friends.map((name) => name.toLowerCase()).toSet();
    final additions =
        parsed.where((name) => existing.add(name.toLowerCase())).toList();
    final updated = [..._friends, ...additions];
    try {
      await _saveFriends(updated);
    } catch (error) {
      _showMessage(_strings.saveError(error));
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
      _showMessage(_strings.alreadyInListMessage);
      return;
    }
    _refreshPresence();
  }

  Future<void> _removeFriend(String name) async {
    final updated = _friends.where((friend) => friend != name).toList();
    try {
      await _saveFriends(updated);
    } catch (error) {
      _showMessage(_strings.saveError(error));
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
    final strings = _strings;
    final controller = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(strings.addFriendsButton),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(strings.addDialogDescription),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                minLines: 3,
                maxLines: 7,
                decoration: InputDecoration(
                  hintText: strings.addDialogHint,
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(strings.cancelButton),
          ),
          FilledButton(
            onPressed: () => _addFriends(controller.text),
            child: Text(strings.addButton),
          ),
        ],
      ),
    );
    controller.dispose();
  }

  Future<void> _showHowToAddDialog() async {
    final theme = Theme.of(context);
    final strings = _strings;

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(strings.howToAddButton),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(strings.howToIntro),
                const SizedBox(height: 12),
                Text(strings.howToStep1),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const SelectableText(
                    'add_friend "Dkz\'" "|*KoG*|"\n'
                    'add_friend "Floῳless" ""\n'
                    'add_friend "Serafim" ""\n'
                    'add_friend "Peoxx" ""\n'
                    'add_friend "Zer0" ""\n'
                    'add_friend "agusx30" ""',
                    style: TextStyle(fontFamily: 'monospace'),
                  ),
                ),
                const SizedBox(height: 16),
                Text(strings.howToStep2),
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
            child: Text(strings.doneButton),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = _strings;
    final activeFriends = _friends
        .where((name) => _onlineFriends.containsKey(name.toLowerCase()))
        .toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    final inactiveFriends = _friends
        .where((name) => !_onlineFriends.containsKey(name.toLowerCase()))
        .toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    return Scaffold(
      appBar: AppBar(
        title: const Text('DDNet Friends'),
        actions: [
          PopupMenuButton<AppLanguage>(
            tooltip: strings.languageTooltip,
            initialValue: _language,
            onSelected: _setLanguage,
            icon: const Icon(Icons.language),
            itemBuilder: (context) => AppLanguage.values
                .map(
                  (lang) => PopupMenuItem<AppLanguage>(
                    value: lang,
                    child: Row(
                      children: [
                        Icon(
                          lang == _language
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                          size: 18,
                          color: lang == _language
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 10),
                        Text(lang.label),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
          IconButton(
            tooltip: strings.donateTooltip,
            onPressed: () {
              launchUrl(Uri.parse('https://ko-fi.com/agusx30'));
            },
            icon: const Icon(Icons.favorite, color: Colors.pinkAccent),
          ),
          IconButton(
            tooltip: strings.refreshTooltip,
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
        padding: const EdgeInsets.only(left: 24),
        child: Wrap(
          alignment: WrapAlignment.end,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 10,
          runSpacing: 10,
          children: [
            FloatingActionButton.extended(
              heroTag: 'how_to',
              onPressed: _showHowToAddDialog,
              backgroundColor: theme.colorScheme.surfaceContainerHigh,
              foregroundColor: theme.colorScheme.onSurface,
              icon: const Icon(Icons.help_outline),
              label: Text(strings.howToAddButton),
            ),
            FloatingActionButton.extended(
              heroTag: 'add_friend',
              onPressed: _showAddDialog,
              icon: const Icon(Icons.person_add_alt_1),
              label: Text(strings.addFriendsButton),
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
                      strings: strings,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      _ErrorCard(message: _error!),
                    ],
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Text(
                          strings.yourFriendsHeader,
                          style: theme.textTheme.labelLarge,
                        ),
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
                      _EmptyFriendsCard(strings: strings)
                    else ...[
                      _CollapsibleGroupSection(
                        title: strings.activeFriendsHeader,
                        count: activeFriends.length,
                        isOnlineGroup: true,
                        expanded: _activeExpanded,
                        emptyMessage: strings.noActiveFriends,
                        onToggle: () {
                          setState(() {
                            _activeExpanded = !_activeExpanded;
                          });
                        },
                        children: activeFriends.map((name) {
                          final presence = _onlineFriends[name.toLowerCase()];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _FriendTile(
                              name: name,
                              presence: presence,
                              onRemove: () => _removeFriend(name),
                              strings: strings,
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 12),
                      _CollapsibleGroupSection(
                        title: strings.inactiveFriendsHeader,
                        count: inactiveFriends.length,
                        isOnlineGroup: false,
                        expanded: _inactiveExpanded,
                        emptyMessage: strings.noInactiveFriends,
                        onToggle: () {
                          setState(() {
                            _inactiveExpanded = !_inactiveExpanded;
                          });
                        },
                        children: inactiveFriends.map((name) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _FriendTile(
                              name: name,
                              presence: null,
                              onRemove: () => _removeFriend(name),
                              strings: strings,
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }
}

class _CollapsibleGroupSection extends StatelessWidget {
  const _CollapsibleGroupSection({
    required this.title,
    required this.count,
    required this.isOnlineGroup,
    required this.expanded,
    required this.emptyMessage,
    required this.onToggle,
    required this.children,
  });

  final String title;
  final int count;
  final bool isOnlineGroup;
  final bool expanded;
  final String emptyMessage;
  final VoidCallback onToggle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accentColor = isOnlineGroup
        ? const Color(0xFFB9F36A)
        : theme.colorScheme.onSurfaceVariant;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Icon(
                    Icons.circle,
                    size: 10,
                    color: accentColor,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    title,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: isOnlineGroup
                          ? accentColor
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '$count',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: accentColor,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    expanded ? Icons.expand_less : Icons.expand_more,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (expanded) ...[
          const SizedBox(height: 8),
          if (children.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Text(
                emptyMessage,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else
            ...children,
        ],
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.onlineCount,
    required this.totalCount,
    required this.lastUpdated,
    required this.refreshing,
    required this.strings,
  });

  final int onlineCount;
  final int totalCount;
  final DateTime? lastUpdated;
  final bool refreshing;
  final AppStrings strings;

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
                    strings.onlineSummary(totalCount),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    lastUpdated == null
                        ? (refreshing
                            ? strings.updatingStatus
                            : strings.noRecentData)
                        : strings.updatedAt(_formatTime(lastUpdated!)),
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
    required this.strings,
  });

  final String name;
  final ServerPresence? presence;
  final VoidCallback onRemove;
  final AppStrings strings;

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
          online ? serverDetails : strings.offlineInDDNet,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        isThreeLine: online,
        trailing: IconButton(
          tooltip: strings.removeTooltip,
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
  const _EmptyFriendsCard({required this.strings});

  final AppStrings strings;

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
            Text(strings.emptyFriendsTitle),
            const SizedBox(height: 4),
            Text(
              strings.emptyFriendsSubtitle,
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
