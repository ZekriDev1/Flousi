import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'ai_assistant_screen.dart';
import 'budget_screen.dart';
import 'settings_screen.dart';
import 'all_transactions_screen.dart';
import '../utils/translations.dart';
import '../main.dart';
import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _userName = '';
  String _avatarUrl = '';
  int _selectedIndex = 0;
  bool _isLoading = true;
  bool _isPremium = false;
  final List<Map<String, dynamic>> _transactions = [];
  final List<Map<String, dynamic>> _notifications = [];
  StreamSubscription? _notificationSubscription;
  StreamSubscription? _transactionSubscription;
  StreamSubscription? _profileSubscription;
  Color get primaryColor => _netFlow < 0 ? const Color(0xFFD32F2F) : const Color(0xFF003D1B);
  Color get secondaryColor => _netFlow < 0 ? const Color(0xFFB71C1C) : const Color(0xFF04512A);
  Color get darkColor => _netFlow < 0 ? const Color(0xFF7F0000) : const Color(0xFF022C17);
  Color get surfaceColor => _netFlow < 0 ? const Color(0xFFFAF1F1) : const Color(0xFFF1FAF7);
  
  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _setupNotificationRealtime();
    _setupTransactionsRealtime();
    _setupProfileRealtime();
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    _transactionSubscription?.cancel();
    _profileSubscription?.cancel();
    super.dispose();
  }

  String _t(String key) => FlousiTranslations.t(context, key);

  String _formatNumber(double number) {
    String str = number.toStringAsFixed(2);
    List<String> parts = str.split('.');
    RegExp reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    parts[0] = parts[0].replaceAllMapped(reg, (Match m) => '${m[1]},');
    return parts.join('.');
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      try {
        final profile = await Supabase.instance.client
            .from('profiles')
            .select()
            .eq('id', user.id)
            .maybeSingle();
        if (profile != null) {
          _userName = profile['full_name'] ?? user.userMetadata?['full_name'] ?? _t('user');
          _avatarUrl = profile['avatar_url'] ?? '';
          _isPremium = profile['is_premium'] ?? false;
        } else {
          _userName = user.userMetadata?['full_name'] ?? _t('user');
          _avatarUrl = '';
        }
      } catch (e) {
        _userName = user.userMetadata?['full_name'] ?? _t('user');
        _avatarUrl = '';
      }
    } else {
      final prefs = await SharedPreferences.getInstance();
      _userName = prefs.getString('guest_name') ?? 'Invité';
    }
    await _loadTransactions();
    await _loadExistingNotifications();
    setState(() => _isLoading = false);
  }

  Future<void> _loadExistingNotifications() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final data = await Supabase.instance.client
            .from('notifications')
            .select()
            .eq('user_id', user.id)
            .order('created_at', ascending: false);
        setState(() {
          _notifications.clear();
          _notifications.addAll(List<Map<String, dynamic>>.from(data));
        });
      }
    } catch (e) {
      debugPrint('Error loading notifications: $e');
    }
  }

  void _setupNotificationRealtime() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    _notificationSubscription = Supabase.instance.client
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', user.id)
        .listen((List<Map<String, dynamic>> data) {
          if (data.isNotEmpty) {
            // Find new notifications that weren't in our current list
            for (var newNotif in data) {
              bool alreadyExists = _notifications.any((n) => n['id'] == newNotif['id']);
              if (!alreadyExists) {
                _showLocalNotification(newNotif);
              }
            }
            setState(() {
              _notifications.clear();
              _notifications.addAll(data);
              _notifications.sort((a, b) => b['created_at'].compareTo(a['created_at']));
            });
          }
        });
  }

  Future<void> _showLocalNotification(Map<String, dynamic> notif) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails('flousi_channel', 'Flousi Notifications',
            importance: Importance.max, priority: Priority.high, showWhen: true);
    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);
    
    await flutterLocalNotificationsPlugin.show(
      notif['id'].hashCode,
      notif['title'] ?? 'Nouvelle notification',
      notif['content'] ?? '',
      platformChannelSpecifics,
    );
  }

  void _setupTransactionsRealtime() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    _transactionSubscription = Supabase.instance.client
        .from('transactions')
        .stream(primaryKey: ['id'])
        .eq('user_id', user.id)
        .listen((List<Map<String, dynamic>> data) {
          setState(() {
            _transactions.clear();
            _transactions.addAll(data);
            _transactions.sort((a, b) => b['transaction_date'].compareTo(a['transaction_date']));
          });
        });
  }

  void _setupProfileRealtime() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    _profileSubscription = Supabase.instance.client
        .from('profiles')
        .stream(primaryKey: ['id'])
        .eq('id', user.id)
        .listen((List<Map<String, dynamic>> data) {
          if (data.isNotEmpty) {
            setState(() {
              _userName = data.first['full_name'] ?? _userName;
              _avatarUrl = data.first['avatar_url'] ?? _avatarUrl;
              _isPremium = data.first['is_premium'] ?? false;
            });
          }
        });
  }

  Future<void> _saveTransactions() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_transactions', json.encode(_transactions));
  }

  double get _totalIncome => _transactions
      .where((t) => t['is_income'] == true)
      .fold(0.0, (sum, item) => sum + (item['amount'] as num).toDouble());

  double get _totalSpent => _transactions
      .where((t) => t['is_income'] == false)
      .fold(0.0, (sum, item) => sum + (item['amount'] as num).toDouble());

  double get _netFlow => _totalIncome - _totalSpent;

  Future<void> _loadTransactions() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final data = await Supabase.instance.client
            .from('transactions')
            .select()
            .eq('user_id', user.id)
            .order('transaction_date', ascending: false);
        
        setState(() {
          _transactions.clear();
          _transactions.addAll(List<Map<String, dynamic>>.from(data));
        });
      } else {
        // Fallback for guests
        final prefs = await SharedPreferences.getInstance();
        final String? transactionsString = prefs.getString('user_transactions');
        if (transactionsString != null) {
          final List<dynamic> decodedData = json.decode(transactionsString);
          setState(() {
            _transactions.clear();
            _transactions.addAll(decodedData.map((item) => Map<String, dynamic>.from(item)).toList());
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading transactions: $e');
    }
  }

  Future<void> _addTransaction(String title, double amount, bool isIncome) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      try {
        await Supabase.instance.client.from('transactions').insert({
          'user_id': user.id,
          'title': title,
          'amount': amount,
          'is_income': isIncome,
          'transaction_date': DateTime.now().toIso8601String(),
        });
        await _loadTransactions();
      } catch (e) {
        debugPrint('Error adding transaction: $e');
      }
    } else {
      // Guest fallback
      setState(() {
        _transactions.insert(0, {
          'title': title,
          'amount': amount,
          'is_income': isIncome,
          'transaction_date': DateTime.now().toIso8601String(),
        });
      });
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_transactions', json.encode(_transactions));
    }
  }

  Future<void> _deleteTransaction(Map<String, dynamic> tx) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null && tx['id'] != null) {
      try {
        await Supabase.instance.client.from('transactions').delete().eq('id', tx['id']);
        await _loadTransactions();
      } catch (e) {
        debugPrint('Error deleting transaction: $e');
      }
    } else {
      setState(() {
        _transactions.remove(tx);
      });
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_transactions', json.encode(_transactions));
    }
  }

  void _showNotifications() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(32),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 32), decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(2))),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_t('notifications') ?? 'Notifications', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF263238))),
                Icon(Icons.done_all_rounded, color: primaryColor, size: 20),
              ],
            ),
            const SizedBox(height: 24),
            if (_notifications.isEmpty)
              Center(child: Padding(padding: const EdgeInsets.symmetric(vertical: 40), child: Text(_t('no_notifications'), style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))))
            else
              ..._notifications.map((notif) => _buildNotificationItem(
                    notif['title'] ?? 'Alerte',
                    notif['content'] ?? '',
                    _formatDate(notif['created_at']),
                    _getNotifIcon(notif['type']),
                    _getNotifColor(notif['type']),
                  )),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    final date = DateTime.parse(dateStr).toLocal();
    final now = DateTime.now();
    if (date.day == now.day && date.month == now.month && date.year == now.year) {
      return DateFormat('HH:mm').format(date);
    }
    return DateFormat('dd/MM HH:mm').format(date);
  }

  IconData _getNotifIcon(String? type) {
    switch (type) {
      case 'warning': return Icons.warning_amber_rounded;
      case 'success': return Icons.stars_rounded;
      case 'info': return Icons.info_outline_rounded;
      default: return Icons.notifications_rounded;
    }
  }

  Color _getNotifColor(String? type) {
    switch (type) {
      case 'warning': return Colors.orange;
      case 'success': return primaryColor;
      case 'info': return Colors.blue;
      default: return primaryColor;
    }
  }

  Widget _buildNotificationItem(String title, String desc, String time, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(24)),
      child: Row(
        children: [
          Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, color: color, size: 20)),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)), Text(desc, style: const TextStyle(color: Colors.grey, fontSize: 12))])),
          Text(time, style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  void _showTransactionDetail(Map<String, dynamic> tx) {
    final bool isInc = tx['is_income'] ?? false;
    final color = isInc ? const Color(0xFF2E7D32) : const Color(0xFFEF5350);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(32),
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(40))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 32), decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(2))),
            Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle), child: Icon(isInc ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded, color: color, size: 40)),
            const SizedBox(height: 24),
            Text(tx['title'], style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF263238))),
            Text(_formatDate(tx['transaction_date']), style: const TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.bold)),
            const SizedBox(height: 32),
            Text('${isInc ? '+' : '-'}${_formatNumber((tx['amount'] as num).toDouble())} MAD', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 48),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () { Navigator.pop(context); _deleteTransaction(tx); },
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red, width: 2), padding: const EdgeInsets.symmetric(vertical: 18), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                    child: Text(_t('delete'), style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(backgroundColor: primaryColor, padding: const EdgeInsets.symmetric(vertical: 18), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), elevation: 0),
                    child: Text(_t('close'), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showAddTransactionDialog() {
    final TextEditingController titleController = TextEditingController();
    String amountStr = "0";
    bool isIncome = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          void updateAmount(String char) {
            setModalState(() {
              if (char == "back") {
                if (amountStr.length > 1) amountStr = amountStr.substring(0, amountStr.length - 1);
                else amountStr = "0";
              } else if (char == ".") {
                if (!amountStr.contains(".")) amountStr += ".";
              } else {
                if (amountStr == "0") amountStr = char;
                else amountStr += char;
              }
            });
          }

          return AnimatedPadding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(40))),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 24), decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
                  Row(
                    children: [
                      _buildTypeToggle(_t('expenses'), !isIncome, const Color(0xFFEF5350), () => setModalState(() => isIncome = false)),
                      const SizedBox(width: 12),
                      _buildTypeToggle(_t('income'), isIncome, const Color(0xFF2E7D32), () => setModalState(() => isIncome = true)),
                    ],
                  ),
                  const SizedBox(height: 32),
                  Text(_formatNumber(double.tryParse(amountStr) ?? 0.0).split('.')[0], style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: isIncome ? const Color(0xFF2E7D32) : const Color(0xFFEF5350))),
                  const Text("MAD", style: TextStyle(color: Colors.grey, fontSize: 14, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 24),
                  TextField(
                    controller: titleController,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    decoration: InputDecoration(hintText: _t('title'), filled: true, fillColor: Colors.grey.shade100, border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none)),
                  ),
                  const SizedBox(height: 24),
                  GridView.count(
                    shrinkWrap: true, crossAxisCount: 3, childAspectRatio: 1.8, mainAxisSpacing: 10, crossAxisSpacing: 10,
                    children: [
                      ...["1", "2", "3", "4", "5", "6", "7", "8", "9", ".", "0"].map((n) => _buildKey(n, () => updateAmount(n))),
                      _buildKey("back", () => updateAmount("back"), isIcon: true),
                    ],
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: () {
                      final amount = double.tryParse(amountStr) ?? 0.0;
                      if (amount > 0) {
                        _addTransaction(titleController.text.isEmpty ? _t(isIncome ? 'income' : 'expenses') : titleController.text, amount, isIncome);
                        Navigator.pop(context);
                      }
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 64), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), elevation: 0),
                    child: Text(_t('save'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildKey(String label, VoidCallback onTap, {bool isIcon = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(20)),
        child: Center(child: isIcon ? const Icon(Icons.backspace_rounded, color: Colors.black54) : Text(label, style: const TextStyle(fontSize: 18, color: Colors.black87, fontWeight: FontWeight.bold))),
      ),
    );
  }

  Widget _buildTypeToggle(String label, bool isActive, Color activeColor, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(color: isActive ? activeColor : Colors.grey.shade100, borderRadius: BorderRadius.circular(20)),
          child: Text(label, textAlign: TextAlign.center, style: TextStyle(color: isActive ? Colors.white : Colors.grey, fontWeight: FontWeight.bold, fontSize: 14)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: surfaceColor,
      body: _isLoading 
          ? Center(child: CircularProgressIndicator(color: primaryColor))
          : IndexedStack(
              index: _selectedIndex,
              children: [
                _buildDashboard(),
                const BudgetScreen(),
                FlousiAIScreen(onBackPressed: () => setState(() => _selectedIndex = 0)),
                const SettingsScreen(),
              ],
            ),
      floatingActionButton: _selectedIndex == 0 ? FloatingActionButton.large(
        onPressed: _showAddTransactionDialog,
        backgroundColor: primaryColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: const Icon(Icons.add_rounded, color: Color(0xFFC5A059), size: 36),
      ) : null,
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildDashboard() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isTablet = constraints.maxWidth > 600;
        final double horizontalPadding = isTablet ? 48.0 : 28.0;

        return Stack(
          children: [
            Positioned.fill(child: Opacity(opacity: 0.04, child: _buildTiledZellij(primaryColor))),
            SafeArea(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildModernHeader(horizontalPadding),
                    _buildHeroBalanceCard(horizontalPadding, isTablet),
                    const SizedBox(height: 32),
                    _buildMiniSummary(horizontalPadding),
                    _buildRecentActivitySection(horizontalPadding),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildModernHeader(double padding) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: padding, vertical: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    image: _avatarUrl.isNotEmpty ? DecorationImage(image: NetworkImage(_avatarUrl), fit: BoxFit.cover) : null,
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
                  ),
                  child: _avatarUrl.isEmpty ? Icon(Icons.person_rounded, color: primaryColor, size: 28) : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_t('welcome'), style: TextStyle(color: Colors.grey.shade500, fontSize: 13, letterSpacing: 0.5, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(_userName, style: TextStyle(color: primaryColor, fontSize: 24, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: _showNotifications,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))]),
              child: Icon(Icons.notifications_active_rounded, color: primaryColor, size: 28),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroBalanceCard(double padding, bool isTablet) {
    final bool isDebt = _netFlow < 0;
    
    return Container(
      width: double.infinity,
      margin: EdgeInsets.symmetric(horizontal: padding),
      height: isTablet ? 280 : 240,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(36),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [primaryColor.withOpacity(0.8), secondaryColor, darkColor],
          stops: const [0.0, 0.5, 1.0],
        ),
        boxShadow: [BoxShadow(
          color: darkColor.withOpacity(0.45), 
          blurRadius: 30, 
          spreadRadius: 2, 
          offset: const Offset(0, 14)
        )],
        border: Border.all(color: Colors.white.withOpacity(0.08), width: 1.2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(36),
        child: Stack(
          children: [
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.white.withOpacity(0.08), Colors.transparent]),
                ),
              ),
            ),
            Positioned(top: -60, right: -60, child: Container(width: 220, height: 220, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.05)))),
            Positioned(bottom: -70, left: -50, child: Container(width: 180, height: 180, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.04)))),
            Padding(
              padding: const EdgeInsets.all(30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_t('total_balance'), style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 1.5)),
                          const SizedBox(height: 6),
                          Container(width: 42, height: 4, decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), gradient: const LinearGradient(colors: [Color(0xFFD4AF37), Color(0xFFFFE7A0)]))),
                        ],
                      ),
                      Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(0.08))), child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 22)),
                    ],
                  ),
                  const Spacer(),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(_formatNumber(_netFlow), style: const TextStyle(color: Colors.white, fontSize: 42, fontWeight: FontWeight.w800, height: 1, letterSpacing: -1.5)),
                        const SizedBox(width: 10),
                        Padding(padding: const EdgeInsets.only(bottom: 6), child: Text('MAD', style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: 1.5))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white.withOpacity(0.08))),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFFD4AF37), shape: BoxShape.circle)),
                        const SizedBox(width: 8),
                        Text(DateFormat('EEEE • HH:mm').format(DateTime.now()), style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
                      ],
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

  Widget _buildMiniSummary(double padding) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: padding),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildMiniDetail(_t('income'), '${_formatNumber(_totalIncome).split('.')[0]} MAD', const Color(0xFF2E7D32), Icons.keyboard_arrow_up_rounded),
          Container(width: 1, height: 40, color: Colors.grey.shade100),
          _buildMiniDetail(_t('expenses'), '${_formatNumber(_totalSpent).split('.')[0]} MAD', const Color(0xFFEF5350), Icons.keyboard_arrow_down_rounded),
        ],
      ),
    );
  }

  Widget _buildMiniDetail(String title, String value, Color color, IconData icon) {
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 4),
            Text(title, style: const TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildRecentActivitySection(double padding) {
    return Padding(
      padding: EdgeInsets.fromLTRB(padding, 40, padding, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_t('recent_activity'), style: TextStyle(color: primaryColor, fontSize: 22, fontWeight: FontWeight.bold)),
              GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => AllTransactionsScreen(transactions: _transactions))),
                child: Text(_t('view_all'), style: TextStyle(color: primaryColor, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (_transactions.isEmpty)
            Center(child: Padding(padding: const EdgeInsets.only(top: 40), child: Text(_t('no_transactions'), style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))))
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _transactions.length > 5 ? 5 : _transactions.length,
              itemBuilder: (context, index) {
                final tx = _transactions[index];
                return GestureDetector(onTap: () => _showTransactionDetail(tx), child: _buildModernTransactionItem(tx));
              },
            ),
        ],
      ),
    );
  }

  Widget _buildModernTransactionItem(Map<String, dynamic> tx) {
    final bool isInc = tx['is_income'] ?? false;
    final color = isInc ? const Color(0xFF2E7D32) : const Color(0xFFEF5350);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.01), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Row(
        children: [
          Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(16)), child: Icon(isInc ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded, color: color, size: 20)),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(tx['title'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF263238))), Text(_formatDate(tx['transaction_date']), style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold))])),
          Text('${isInc ? '+' : '-'}${_formatNumber((tx['amount'] as num).toDouble()).split('.')[0]}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
        ],
      ),
    );
  }

  Widget _buildTiledZellij(Color color) {
    return LayoutBuilder(builder: (context, constraints) => Wrap(children: List.generate(120, (_) => SvgPicture.asset('assets/zelij.svg', width: 80, height: 80, colorFilter: ColorFilter.mode(color, BlendMode.srcIn)))));
  }

  Widget _buildBottomNav() {
    return Container(
      height: 90,
      decoration: BoxDecoration(color: Colors.white, borderRadius: const BorderRadius.vertical(top: Radius.circular(40)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, -10))]),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildNavItem(0, Icons.grid_view_rounded, _t('home')),
          _buildNavItem(1, Icons.pie_chart_rounded, _t('goals')),
          _buildNavItem(2, Icons.auto_awesome_rounded, _t('ai')),
          _buildNavItem(3, Icons.settings_rounded, _t('settings')),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    bool isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(color: isSelected ? primaryColor.withOpacity(0.05) : Colors.transparent, borderRadius: BorderRadius.circular(20)),
        child: Column(
          mainAxisSize: MainAxisSize.min, 
          children: [
            Stack(
              children: [
                Icon(icon, color: isSelected ? primaryColor : Colors.grey.shade400, size: 24),
                if (index == 2 && !_isPremium)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(color: const Color(0xFFC5A059), shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1.5)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4), 
            Text(label, style: TextStyle(color: isSelected ? primaryColor : Colors.grey.shade400, fontSize: 10, fontWeight: FontWeight.bold))
          ]
        ),
      ),
    );
  }
}
