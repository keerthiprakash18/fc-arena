import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
    });
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