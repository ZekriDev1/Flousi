import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import '../utils/translations.dart';

class AllTransactionsScreen extends StatelessWidget {
  final List<Map<String, dynamic>> transactions;

  const AllTransactionsScreen({super.key, required this.transactions});

  String _t(BuildContext context, String key) => FlousiTranslations.t(context, key);

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr).toLocal();
      return DateFormat('dd/MM/yyyy HH:mm').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  String _formatNumber(double number) {
    String str = number.toStringAsFixed(2);
    List<String> parts = str.split('.');
    RegExp reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    parts[0] = parts[0].replaceAllMapped(reg, (Match m) => '${m[1]},');
    return parts.join('.');
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF003D1B);
    
    return Scaffold(
      backgroundColor: const Color(0xFFF1FAF7),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: primaryColor, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(_t(context, 'history'), style: const TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 22)),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: 0.03,
              child: _buildTiledZellij(primaryColor),
            ),
          ),
          transactions.isEmpty
              ? _buildEmptyState(context, primaryColor)
              : ListView.builder(
                  padding: const EdgeInsets.all(24),
                  itemCount: transactions.length,
                  itemBuilder: (context, index) {
                    final tx = transactions[index];
                    final bool isInc = tx['is_income'] ?? false;
                    final color = isInc ? const Color(0xFF2E7D32) : const Color(0xFFEF5350);
                    
                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(16)),
                            child: Icon(isInc ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded, color: color, size: 20),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(tx['title'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF263238))),
                                Text(_formatDate(tx['transaction_date']), style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                          Text(
                            '${isInc ? '+' : '-'}${_formatNumber((tx['amount'] as num).toDouble()).split('.')[0]}',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, Color color) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_rounded, size: 80, color: color.withOpacity(0.1)),
          const SizedBox(height: 24),
          Text(_t(context, 'no_transactions'), style: const TextStyle(color: Colors.grey, fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildTiledZellij(Color color) {
    return Wrap(
      children: List.generate(
        100,
        (_) => SvgPicture.asset(
          'assets/zelij.svg',
          width: 80,
          height: 80,
          colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
        ),
      ),
    );
  }
}
