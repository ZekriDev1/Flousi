import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../main.dart';
import '../utils/translations.dart';
import '../utils/notification_helper.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _fullName = '';
  String _avatarUrl = '';
  bool _notificationsEnabled = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      final data = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();
      
      if (data != null) {
        setState(() {
          _fullName = data['full_name'] ?? '';
          _avatarUrl = data['avatar_url'] ?? '';
          _notificationsEnabled = data['notifications_enabled'] ?? true;
        });
      }
    } catch (e) {
      debugPrint('Error loading profile: $e');
    }
  }

  Future<void> _updateProfile(String name, String avatar) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client.from('profiles').update({
        'full_name': name,
        'avatar_url': avatar,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', user.id);
      
      setState(() {
        _fullName = name;
        _avatarUrl = avatar;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_t('profile_updated'))));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    }
    setState(() => _isLoading = false);
  }

  Future<void> _updateNotificationPreference(bool enabled) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    setState(() => _notificationsEnabled = enabled);
    try {
      await Supabase.instance.client.from('profiles').update({
        'notifications_enabled': enabled,
      }).eq('id', user.id);
      
      if (enabled) {
        if (mounted) NotificationHelper.scheduleDailyReminder(context);
      } else {
        NotificationHelper.cancelAllNotifications();
      }
    } catch (e) {
      debugPrint('Error updating notifications: $e');
    }
  }

  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 50);
    
    if (image == null) return;

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);
    try {
      final file = File(image.path);
      final fileExt = image.path.split('.').last;
      final fileName = 'avatar.$fileExt';
      final filePath = '${user.id}/$fileName';

      await Supabase.instance.client.storage
          .from('avatars')
          .upload(filePath, file, fileOptions: const FileOptions(upsert: true));

      final String publicUrl = Supabase.instance.client.storage
          .from('avatars')
          .getPublicUrl(filePath);

      await _updateProfile(_fullName, publicUrl);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur upload: $e')));
    }
    setState(() => _isLoading = false);
  }

  void _showEditProfile() {
    final nameController = TextEditingController(text: _fullName);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(40))),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 24),
              Text(_t('edit_profile'), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF003D1B))),
              const SizedBox(height: 32),
              Center(
                child: GestureDetector(
                  onTap: _pickAndUploadImage,
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: const Color(0xFF003D1B).withOpacity(0.1),
                        backgroundImage: _avatarUrl.isNotEmpty ? NetworkImage(_avatarUrl) : null,
                        child: _avatarUrl.isEmpty ? const Icon(Icons.person, size: 50, color: Color(0xFF003D1B)) : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(color: Color(0xFFC5A059), shape: BoxShape.circle),
                          child: const Icon(Icons.camera_alt, size: 20, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: nameController,
                decoration: InputDecoration(hintText: _t('full_name'), filled: true, fillColor: Colors.grey.shade50, border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none)),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  _updateProfile(nameController.text, _avatarUrl);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF003D1B), minimumSize: const Size(double.infinity, 60), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), elevation: 0),
                child: Text(_t('save'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _t(String key) => FlousiTranslations.t(context, key);

  @override
  Widget build(BuildContext context) {
    final appState = FlousiApp.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF1FAF7),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_t('settings'), style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF003D1B))),
              const SizedBox(height: 8),
              Container(height: 3, width: 40, decoration: BoxDecoration(color: const Color(0xFFC5A059), borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 48),

              // SECTION: LANGUE
              _buildSectionHeader(_t('language')),
              _buildLanguageSelector(context),

              const SizedBox(height: 32),

              // SECTION: NOTIFICATIONS
              _buildSectionHeader(_t('notifications')),
              _buildSettingTile(
                icon: Icons.notifications_active_rounded,
                title: _t('reminders'),
                subtitle: "",
                trailing: Switch(
                  value: _notificationsEnabled, 
                  activeColor: const Color(0xFF003D1B),
                  onChanged: (val) => _updateNotificationPreference(val),
                ),
              ),

              const SizedBox(height: 48),

              // SECTION: COMPTE
              _buildSectionHeader(_t('profile')),
              GestureDetector(
                onTap: _showEditProfile,
                child: _buildSettingTile(
                  icon: Icons.person_outline_rounded,
                  title: _fullName.isEmpty ? _t('profile') : _fullName,
                  subtitle: _avatarUrl.isNotEmpty ? _t('custom_photo') : _t('no_photo'),
                  trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 24),
                ),
              ),

              const SizedBox(height: 48),

              // LOGOUT BUTTON
              ElevatedButton(
                onPressed: () async {
                  await Supabase.instance.client.auth.signOut();
                  appState.setLoggedIn(false);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade50,
                  foregroundColor: Colors.red,
                  minimumSize: const Size(double.infinity, 60),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  elevation: 0,
                ),
                child: Text(_t('logout'), style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: Colors.grey)),
    );
  }

  Widget _buildSettingTile({required IconData icon, required String title, required String subtitle, required Widget trailing}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFF003D1B).withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
            child: Icon(icon, color: const Color(0xFF003D1B), size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF263238))),
                if (subtitle.isNotEmpty) Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }

  Widget _buildLanguageSelector(BuildContext context) {
    final appState = FlousiApp.of(context);
    final currentLang = Localizations.localeOf(context).languageCode;

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          _buildLangButton("FR", currentLang == 'fr', () => appState.setLocale(const Locale('fr'))),
          _buildLangButton("EN", currentLang == 'en', () => appState.setLocale(const Locale('en'))),
          _buildLangButton("AR", currentLang == 'ar', () => appState.setLocale(const Locale('ar'))),
        ],
      ),
    );
  }

  Widget _buildLangButton(String label, bool isSelected, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          debugPrint('Changing language to: $label');
          onTap();
        },
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF003D1B) : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(color: isSelected ? Colors.white : Colors.grey, fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ),
      ),
    );
  }
}
