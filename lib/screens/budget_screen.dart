import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import '../utils/translations.dart';

class BudgetScreen extends StatefulWidget {
  const BudgetScreen({super.key});

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  final List<Map<String, dynamic>> _objectifs = [];
  bool _isLoading = true;
  StreamSubscription? _goalsSubscription;

  @override
  void initState() {
    super.initState();
    _loadObjectifs();
    _setupGoalsRealtime();
  }

  @override
  void dispose() {
    _goalsSubscription?.cancel();
    super.dispose();
  }

  String _t(String key) => FlousiTranslations.t(context, key);

  String _formatNumber(double number) {
    String str = number.toStringAsFixed(0);
    RegExp reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return str.replaceAllMapped(reg, (Match m) => '${m[1]},');
  }

  Future<void> _loadObjectifs() async {
    setState(() => _isLoading = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final data = await Supabase.instance.client
            .from('goals')
            .select()
            .eq('user_id', user.id)
            .order('created_at', ascending: false);
        setState(() {
          _objectifs.clear();
          _objectifs.addAll(List<Map<String, dynamic>>.from(data));
        });
      }
    } catch (e) {
      debugPrint('Error loading goals: $e');
    }
    setState(() => _isLoading = false);
  }

  void _setupGoalsRealtime() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    _goalsSubscription = Supabase.instance.client
        .from('goals')
        .stream(primaryKey: ['id'])
        .eq('user_id', user.id)
        .listen((List<Map<String, dynamic>> data) {
          setState(() {
            _objectifs.clear();
            _objectifs.addAll(data);
          });
        });
  }

  Future<void> _addObjectif(String title, double target, IconData icon) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      try {
        await Supabase.instance.client.from('goals').insert({
          'user_id': user.id,
          'title': title,
          'target_amount': target,
          'current_amount': 0.0,
          'icon': icon.codePoint.toString(),
          'color': const Color(0xFF003D1B).value.toString(),
        });
      } catch (e) {
        debugPrint('Error adding goal: $e');
      }
    }
  }

  Future<void> _updateSavings(Map<String, dynamic> obj, double amount) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null && obj['id'] != null) {
      try {
        final double newAmount = (obj['current_amount'] as num).toDouble() + amount;
        await Supabase.instance.client
            .from('goals')
            .update({'current_amount': newAmount})
            .eq('id', obj['id']);
      } catch (e) {
        debugPrint('Error updating goal: $e');
      }
    }
  }

  Future<void> _deleteObjectif(Map<String, dynamic> obj) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null && obj['id'] != null) {
      try {
        await Supabase.instance.client.from('goals').delete().eq('id', obj['id']);
      } catch (e) {
        debugPrint('Error deleting goal: $e');
      }
    }
  }

  void _showAddSavingsDialog(Map<String, dynamic> obj) {
    String amountStr = "0";
    
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

          return Container(
            padding: const EdgeInsets.all(32),
            decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(40))),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 24), decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
                Text(obj['title'], style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF003D1B))),
                const SizedBox(height: 32),
                Text(_formatNumber(double.tryParse(amountStr) ?? 0.0), style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Color(0xFF003D1B))),
                const Text("MAD", style: TextStyle(color: Colors.grey, fontSize: 14, fontWeight: FontWeight.bold)),
                const SizedBox(height: 32),
                GridView.count(
                  shrinkWrap: true, crossAxisCount: 3, childAspectRatio: 1.8, mainAxisSpacing: 10, crossAxisSpacing: 10,
                  children: [
                    ...["1", "2", "3", "4", "5", "6", "7", "8", "9", ".", "0"].map((n) => _buildKey(n, () => updateAmount(n))),
                    _buildKey("back", () => updateAmount("back"), isIcon: true),
                  ],
                ),
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () { Navigator.pop(context); _deleteObjectif(obj); },
                        style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red, width: 2), padding: const EdgeInsets.symmetric(vertical: 20), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                        child: Text(_t('delete'), style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          final amount = double.tryParse(amountStr) ?? 0.0;
                          if (amount > 0) { _updateSavings(obj, amount); Navigator.pop(context); }
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF003D1B), padding: const EdgeInsets.symmetric(vertical: 20), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), elevation: 0),
                        child: Text(_t('confirm'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
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

  void _showAddObjectifDialog() {
    final TextEditingController titleController = TextEditingController();
    String amountStr = "0";
    IconData selectedIcon = Icons.stars_rounded;

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

          return Container(
            padding: const EdgeInsets.all(32),
            decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(40))),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 24),
                Text(_t('new_goal'), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF003D1B))),
                const SizedBox(height: 32),
                TextField(
                  controller: titleController,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  decoration: InputDecoration(hintText: _t('title'), filled: true, fillColor: Colors.grey.shade50, border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none)),
                ),
                const SizedBox(height: 24),
                Center(
                  child: Column(
                    children: [
                      Text(_formatNumber(double.tryParse(amountStr) ?? 0.0), style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Color(0xFF003D1B))),
                      const Text("MAD", style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                GridView.count(
                  shrinkWrap: true, crossAxisCount: 3, childAspectRatio: 2.0, mainAxisSpacing: 10, crossAxisSpacing: 10,
                  children: [
                    ...["1", "2", "3", "4", "5", "6", "7", "8", "9", ".", "0"].map((n) => _buildKey(n, () => updateAmount(n))),
                    _buildKey("back", () => updateAmount("back"), isIcon: true),
                  ],
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () {
                    final target = double.tryParse(amountStr) ?? 0.0;
                    if (titleController.text.isNotEmpty && target > 0) { _addObjectif(titleController.text, target, selectedIcon); Navigator.pop(context); }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF003D1B), minimumSize: const Size(double.infinity, 70), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)), elevation: 0),
                  child: Text(_t('launch_goal'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1FAF7),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final bool isTablet = constraints.maxWidth > 600;
          final double horizontalPadding = isTablet ? 64.0 : 32.0;

          return Stack(
            children: [
              Positioned.fill(child: Opacity(opacity: 0.05, child: _buildTiledZellij(const Color(0xFF003D1B)))),
              SafeArea(
                child: _isLoading 
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF003D1B)))
                  : SingleChildScrollView(
                      padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_t('goals'), style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF003D1B))),
                          const SizedBox(height: 8),
                          Container(height: 3, width: 40, decoration: BoxDecoration(color: const Color(0xFFC5A059), borderRadius: BorderRadius.circular(2))),
                          const SizedBox(height: 32),
                          if (_objectifs.isEmpty)
                            Center(child: Padding(padding: const EdgeInsets.only(top: 40), child: Text(_t('no_goals'), style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))))
                          else
                            ..._objectifs.map((obj) => GestureDetector(onTap: () => _showAddSavingsDialog(obj), child: _buildObjectifCard(obj))),
                        ],
                      ),
                    ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddObjectifDialog,
        backgroundColor: const Color(0xFF003D1B),
        icon: const Icon(Icons.add_rounded, color: Color(0xFFC5A059)),
        label: Text(_t('new_goal').toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
      ),
    );
  }

  Widget _buildTiledZellij(Color color) {
    return LayoutBuilder(builder: (context, constraints) => Wrap(children: List.generate(80, (_) => SvgPicture.asset('assets/zelij.svg', width: 100, height: 100, colorFilter: ColorFilter.mode(color, BlendMode.srcIn)))));
  }

  Widget _buildObjectifCard(Map<String, dynamic> obj) {
    double progress = (obj['current_amount'] as num).toDouble() / (obj['target_amount'] as num).toDouble();
    if (progress > 1.0) progress = 1.0;
    
    const IconData icon = Icons.stars_rounded;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 15, offset: const Offset(0, 8))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFF003D1B).withOpacity(0.1), borderRadius: BorderRadius.circular(16)), child: Icon(icon, color: const Color(0xFF003D1B), size: 24)),
              const SizedBox(width: 16),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(obj['title'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Color(0xFF263238))), Text('${_formatNumber((obj['current_amount'] as num).toDouble())} / ${_formatNumber((obj['target_amount'] as num).toDouble())} MAD', style: const TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.bold))])),
              Text('${(progress * 100).toInt()}%', style: const TextStyle(color: Color(0xFF003D1B), fontWeight: FontWeight.bold, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 24),
          ClipRRect(borderRadius: BorderRadius.circular(10), child: LinearProgressIndicator(value: progress, minHeight: 10, backgroundColor: const Color(0xFF003D1B).withOpacity(0.1), valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF003D1B)))),
        ],
      ),
    );
  }
}
