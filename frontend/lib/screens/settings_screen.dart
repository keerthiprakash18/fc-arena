import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _darkMode = true;
  bool _notifications = true;
  bool _matchReminders = true;
  bool _soundEffects = false;
  String _language = 'English';

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _darkMode = prefs.getBool('dark_mode') ?? true;
      _notifications = prefs.getBool('notifications') ?? true;
      _matchReminders = prefs.getBool('match_reminders') ?? true;
      _soundEffects = prefs.getBool('sound_effects') ?? false;
      _language = prefs.getString('language') ?? 'English';
      _apiUrl = apiBaseUrl;
    });
  }

  String _apiUrl = '';

  /// Let the user repoint the app at a different backend at runtime.
  /// This is what makes a single web/APK build usable against localhost,
  /// a LAN address, or a deployed server.
  Future<void> _editServerUrl() async {
    final controller = TextEditingController(text: apiBaseUrl);
    String? probeResult;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          backgroundColor: FCColors.surface,
          title: const Text('Server URL', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Base URL of the FC ARENA API (include /api).',
                style: TextStyle(fontSize: 12, color: FCColors.white50),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: const InputDecoration(
                  hintText: 'https://example.com/api',
                  prefixIcon: Icon(Icons.dns_outlined, size: 20),
                ),
              ),
              if (probeResult != null) ...[
                const SizedBox(height: 12),
                Text(
                  probeResult!,
                  style: TextStyle(
                    fontSize: 12,
                    color: probeResult!.startsWith('Connected') ? FCColors.accent : FCColors.red,
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                final msg = await apiClient.checkConnection();
                setDialogState(() => probeResult = msg);
              },
              child: Text('TEST', style: TextStyle(color: FCColors.white50)),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _resetServerUrl();
              },
              child: const Text('RESET', style: TextStyle(color: FCColors.white50)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text('CANCEL', style: TextStyle(color: FCColors.white50)),
            ),
            ElevatedButton(
              onPressed: () async {
                final value = controller.text.trim();
                if (value.isEmpty) return;
                await setApiBaseUrl(value);
                if (mounted) setState(() => _apiUrl = apiBaseUrl);
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: FCColors.accent,
                foregroundColor: Colors.white,
              ),
              child: const Text('SAVE'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
  }

  Future<void> _resetServerUrl() async {
    await resetApiBaseUrl();
    if (mounted) setState(() => _apiUrl = apiBaseUrl);
  }

  Future<void> _save(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is bool) await prefs.setBool(key, value);
    if (value is String) await prefs.setString(key, value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FCColors.pitch,
      appBar: AppBar(
        backgroundColor: FCColors.surface,
        title: const Text('Settings', style: TextStyle(color: Colors.white)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionHeader('APPEARANCE'),
          _toggleTile(Icons.dark_mode, 'Dark Mode', 'Use dark theme', _darkMode, (v) {
            setState(() => _darkMode = v);
            _save('dark_mode', v);
          }),
          _divider(),
          _sectionHeader('SERVER'),
          _actionTile(
            Icons.dns_outlined,
            'API Server',
            _apiUrl.isEmpty ? apiBaseUrl : _apiUrl,
            hasCustomApiBaseUrl ? 'Custom' : 'Default',
            _editServerUrl,
          ),
          _divider(),
          _sectionHeader('NOTIFICATIONS'),
          _toggleTile(Icons.notifications, 'Push Notifications', 'Receive match updates', _notifications, (v) {
            setState(() => _notifications = v);
            _save('notifications', v);
          }),
          _toggleTile(Icons.alarm, 'Match Reminders', '15 min before match', _matchReminders, (v) {
            setState(() => _matchReminders = v);
            _save('match_reminders', v);
          }),
          _divider(),
          _sectionHeader('AUDIO'),
          _toggleTile(Icons.volume_up, 'Sound Effects', 'Goal and card sounds', _soundEffects, (v) {
            setState(() => _soundEffects = v);
            _save('sound_effects', v);
          }),
          _divider(),
          _sectionHeader('LANGUAGE'),
          _dropdownTile(Icons.language, 'Language', _language, ['English', 'Tamil', 'Hindi'], (v) {
            setState(() => _language = v!);
            _save('language', v);
          }),
          _divider(),
          _sectionHeader('ABOUT'),
          _infoTile(Icons.info_outline, 'Version', '1.0.0'),
          _infoTile(Icons.code, 'Build', '2026.09.10'),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(12)),
            child: Column(children: [
              Text('FC ARENA', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white.withValues(alpha: 0.8))),
              const SizedBox(height: 4),
              Text('Esports Tournament Platform', style: TextStyle(fontSize: 12, color: FCColors.white30)),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: FCColors.white30, letterSpacing: 2)),
    );
  }

  Widget _toggleTile(IconData icon, String title, String subtitle, bool value, ValueChanged<bool> onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(children: [
        Icon(icon, color: FCColors.accent, size: 22),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 15, color: Colors.white)),
          Text(subtitle, style: TextStyle(fontSize: 12, color: FCColors.white30)),
        ])),
        Switch(value: value, onChanged: onChanged, activeThumbColor: FCColors.accent),
      ]),
    );
  }

  Widget _dropdownTile(IconData icon, String title, String value, List<String> options, ValueChanged<String?> onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(children: [
        Icon(icon, color: FCColors.accent, size: 22),
        const SizedBox(width: 14),
        Expanded(child: Text(title, style: const TextStyle(fontSize: 15, color: Colors.white))),
        DropdownButton<String>(
          value: value,
          dropdownColor: FCColors.surface,
          style: const TextStyle(color: Colors.white),
          underline: const SizedBox(),
          items: options.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
          onChanged: onChanged,
        ),
      ]),
    );
  }

  Widget _actionTile(IconData icon, String title, String subtitle, String trailing, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(children: [
          Icon(icon, color: FCColors.accent, size: 22),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 15, color: Colors.white)),
            Text(subtitle, style: TextStyle(fontSize: 12, color: FCColors.white30), maxLines: 1, overflow: TextOverflow.ellipsis),
          ])),
          Text(trailing, style: TextStyle(fontSize: 12, color: FCColors.white50)),
          const SizedBox(width: 6),
          Icon(Icons.chevron_right, color: FCColors.white30, size: 20),
        ]),
      ),
    );
  }

  Widget _infoTile(IconData icon, String title, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(children: [
        Icon(icon, color: Colors.white54, size: 22),
        const SizedBox(width: 14),
        Expanded(child: Text(title, style: const TextStyle(fontSize: 15, color: Colors.white))),
        Text(value, style: TextStyle(fontSize: 14, color: FCColors.white50)),
      ]),
    );
  }

  Widget _divider() {
    return Divider(color: Colors.white.withValues(alpha: 0.08), height: 1);
  }
}