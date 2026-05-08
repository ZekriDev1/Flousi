import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../utils/translations.dart';
import '../main.dart';

class FlousiAIScreen extends StatefulWidget {
  final VoidCallback? onBackPressed;
  const FlousiAIScreen({super.key, this.onBackPressed});

  @override
  State<FlousiAIScreen> createState() => _FlousiAIScreenState();
}

class _FlousiAIScreenState extends State<FlousiAIScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, String>> _messages = [];
  bool _isTyping = false;
  bool _isPremium = false;
  bool _checkingPremium = true;
  final ScrollController _scrollController = ScrollController();
  final InAppPurchase _iap = InAppPurchase.instance;
  late StreamSubscription<List<PurchaseDetails>> _subscription;
  
  // Gemini Configuration
  late final GenerativeModel _model;
  ChatSession? _chat;
  final String _apiKey = "AIzaSyBJ16hJmleTb6bVn0Qsz3brAcmaXLQEmWM";

  final String _premiumProductId = 'flousi_premium_monthly';

  @override
  void initState() {
    super.initState();
    _checkPremiumStatus();
    _loadChatHistory();
    _initGemini();
    _initIAP();
  }

  void _initIAP() {
    final purchaseUpdated = _iap.purchaseStream;
    _subscription = purchaseUpdated.listen((purchaseDetailsList) {
      _listenToPurchaseUpdated(purchaseDetailsList);
    }, onDone: () {
      _subscription.cancel();
    }, onError: (error) {
      debugPrint("IAP Error: $error");
    });
  }

  @override
  void dispose() {
    _subscription.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _listenToPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) {
    for (var purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        // Show loading or something
      } else {
        if (purchaseDetails.status == PurchaseStatus.error) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Erreur lors de l'achat")));
        } else if (purchaseDetails.status == PurchaseStatus.purchased || purchaseDetails.status == PurchaseStatus.restored) {
          _verifyAndUnlockPremium(purchaseDetails);
        }
        if (purchaseDetails.pendingCompletePurchase) {
          _iap.completePurchase(purchaseDetails);
        }
      }
    }
  }

  Future<void> _verifyAndUnlockPremium(PurchaseDetails purchaseDetails) async {
    // In a real app, you should verify the purchase with your server/Supabase Edge Function
    // For now, we update the profile directly after a successful Play Store response
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      await Supabase.instance.client.from('profiles').update({
        'is_premium': true,
        'premium_until': DateTime.now().add(const Duration(days: 30)).toIso8601String(),
      }).eq('id', user.id);
      
      setState(() { _isPremium = true; });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_t('premium_success'))));
    }
  }

  void _initGemini() {
    _model = GenerativeModel(
      model: 'gemini-1.5-flash-latest',
      apiKey: _apiKey,
      systemInstruction: Content.system(
        "You are Flousi AI, a premium Moroccan financial assistant. "
        "You help users manage their money and set goals. "
        "You can interact with the app using tools like 'add_goal'. "
        "Always recommend smart goals like 'Saving for a car' or 'Emergency fund'."
      ),
      tools: [
        Tool(functionDeclarations: [
          FunctionDeclaration(
            'add_goal',
            'Adds a new financial goal for the user',
            Schema.object(properties: {
              'title': Schema.string(description: 'Title of the goal'),
              'target_amount': Schema.number(description: 'Target amount in MAD'),
            }, requiredProperties: ['title', 'target_amount']),
          ),
          FunctionDeclaration(
            'add_transaction',
            'Adds a new transaction (income or expense)',
            Schema.object(properties: {
              'title': Schema.string(description: 'Title of transaction'),
              'amount': Schema.number(description: 'Amount in MAD'),
              'is_income': Schema.boolean(description: 'True if income, false if expense'),
            }, requiredProperties: ['title', 'amount', 'is_income']),
          ),
        ])
      ],
    );
    _chat = _model.startChat();
  }

  Future<void> _handleToolCall(Iterable<FunctionCall> calls) async {
    for (final call in calls) {
      if (call.name == 'add_goal') {
        final title = call.args['title'] as String;
        final target = (call.args['target_amount'] as num).toDouble();
        await _addGoalInternal(title, target);
      } else if (call.name == 'add_transaction') {
        final title = call.args['title'] as String;
        final amount = (call.args['amount'] as num).toDouble();
        final isIncome = call.args['is_income'] as bool;
        await _addTransactionInternal(title, amount, isIncome);
      }
    }
  }

  Future<void> _addGoalInternal(String title, double target) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      await Supabase.instance.client.from('goals').insert({
        'user_id': user.id,
        'title': title,
        'target_amount': target,
        'current_amount': 0.0,
        'icon': Icons.stars_rounded.codePoint.toString(),
      });
      _addBotMessage("Génial ! J'ai ajouté l'objectif '$title' avec un cible de $target MAD pour vous. 🎯");
    }
  }

  Future<void> _addTransactionInternal(String title, double amount, bool isIncome) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      await Supabase.instance.client.from('transactions').insert({
        'user_id': user.id,
        'title': title,
        'amount': amount,
        'is_income': isIncome,
        'transaction_date': DateTime.now().toIso8601String(),
      });
      _addBotMessage("C'est fait ! J'ai enregistré votre ${isIncome ? 'revenu' : 'dépense'} de $amount MAD pour '$title'. 💸");
    }
  }

  void _addBotMessage(String text) {
    setState(() { _messages.add({"role": "bot", "text": text}); });
    _saveChatHistory();
    _scrollToBottom();
  }

  Future<void> _checkPremiumStatus() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final data = await Supabase.instance.client
            .from('profiles')
            .select('is_premium, premium_until')
            .eq('id', user.id)
            .maybeSingle();
            
        if (data != null) {
          setState(() {
            _isPremium = data['is_premium'] ?? false;
            if (data['premium_until'] != null) {
              final expiry = DateTime.parse(data['premium_until']);
              if (expiry.isBefore(DateTime.now())) {
                _isPremium = false;
              }
            }
            _checkingPremium = false;
          });
        } else {
          setState(() => _checkingPremium = false);
        }
      } else {
        setState(() => _checkingPremium = false);
      }
    } catch (e) {
      debugPrint('Error checking premium: $e');
      setState(() => _checkingPremium = false);
    }
  }

  Future<void> _subscribeMonthly() async {
    final bool available = await _iap.isAvailable();
    if (!available) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Le Play Store n'est pas disponible actuellement.")));
      return;
    }

    const Set<String> ids = <String>{'flousi_premium_monthly'};
    final ProductDetailsResponse response = await _iap.queryProductDetails(ids);

    if (response.notFoundIDs.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Produit 'flousi_premium_monthly' non trouvé sur le Play Store.")));
      return;
    }

    if (response.productDetails.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Aucun détail de produit reçu.")));
      return;
    }

    final ProductDetails productDetails = response.productDetails.first;
    final PurchaseParam purchaseParam = PurchaseParam(productDetails: productDetails);
    
    // Launch the purchase flow
    _iap.buyNonConsumable(purchaseParam: purchaseParam);
  }

  String _t(String key) => FlousiTranslations.t(context, key);

  Future<void> _saveChatHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ai_chat_history', json.encode(_messages));
  }

  Future<void> _loadChatHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final String? history = prefs.getString('ai_chat_history');
    if (history != null) {
      final List<dynamic> decoded = json.decode(history);
      setState(() { _messages.addAll(decoded.map((m) => Map<String, String>.from(m)).toList()); });
      _scrollToBottom();
    } else {
      _addBotMessage(_t('welcome'));
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_scrollController.hasClients) _scrollController.animateTo(_scrollController.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    });
  }

  void _handleSend() async {
    if (_controller.text.trim().isEmpty) return;
    if (!_isPremium && _messages.where((m) => m['role'] == 'user').length >= 3) return;

    final userMessage = _controller.text;
    setState(() { 
      _messages.add({"role": "user", "text": userMessage}); 
      _controller.clear(); 
      _isTyping = true; 
    });
    
    _saveChatHistory(); 
    _scrollToBottom();

    if (_apiKey == "YOUR_GEMINI_API_KEY") {
      // Fallback if no API key
      await Future.delayed(const Duration(seconds: 1));
      setState(() { 
        _isTyping = false; 
        _messages.add({"role": "bot", "text": "Veuillez configurer votre clé API Gemini pour activer l'IA réelle. (Demo: ${userMessage})"}); 
      });
    } else {
      try {
        var content = Content.text(userMessage);
        var response = await _chat?.sendMessage(content);
        
        while (response?.functionCalls.isNotEmpty ?? false) {
          final calls = response!.functionCalls;
          await _handleToolCall(calls);
          
          // Send tool results back to Gemini if needed, but for now we just acknowledge
          // In a full implementation, you'd send FunctionResponse
          response = await _chat?.sendMessage(Content.text("Action effectuée avec succès. Continue."));
        }

        setState(() { 
          _isTyping = false; 
          if (response?.text != null) {
            _messages.add({"role": "bot", "text": response!.text!}); 
          }
        });
      } catch (e) {
        debugPrint("Gemini Error: $e");
        setState(() { 
          _isTyping = false; 
          _messages.add({"role": "bot", "text": "Désolé, j'ai rencontré une erreur technique. Vérifiez votre connexion ou votre clé API. (Error: $e)"}); 
        });
      }
    }
    
    _saveChatHistory(); 
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingPremium) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // We allow all users to enter the screen, but limit messages for non-premium

    return Scaffold(
      backgroundColor: const Color(0xFFF1FAF7),
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, title: Text(_t('ai'), style: const TextStyle(color: Color(0xFF003D1B), fontWeight: FontWeight.bold)), centerTitle: true),
      body: Column(
        children: [
          Expanded(child: ListView.builder(controller: _scrollController, padding: const EdgeInsets.all(24), itemCount: _messages.length, itemBuilder: (context, index) {
            final msg = _messages[index];
            return _buildMessageBubble(msg['text'] ?? '', msg['role'] == 'user');
          })),
          if (_isTyping) Padding(padding: const EdgeInsets.all(24), child: Row(children: [Text(_t('ai_thinking'), style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold))])),
          
          if (_messages.length <= 1) _buildQuickActions(),

          // Show paywall if limit reached, otherwise show input
          (!_checkingPremium && !_isPremium && _messages.where((m) => m['role'] == 'user').length >= 3)
            ? _buildEmbeddedPaywall()
            : _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    final actions = [
      "Suggère-moi un objectif financier",
      "Ajoute un objectif 'Nouvelle Voiture'",
      "Analyse mon budget",
    ];
    
    return Container(
      height: 45,
      margin: const EdgeInsets.only(bottom: 16),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        scrollDirection: Axis.horizontal,
        itemCount: actions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, contextIndex) => ActionChip(
          label: Text(actions[contextIndex], style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF003D1B))),
          backgroundColor: Colors.white,
          side: BorderSide(color: const Color(0xFF003D1B).withOpacity(0.1)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          onPressed: () {
            _controller.text = actions[contextIndex];
            _handleSend();
          },
        ),
      ),
    );
  }

  Widget _buildEmbeddedPaywall() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
      decoration: const BoxDecoration(
        color: Color(0xFF003D1B),
        borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 24), decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(2))),
          const Icon(Icons.auto_awesome_rounded, color: Color(0xFFC5A059), size: 32),
          const SizedBox(height: 16),
          Text(_t('ai_limit_reached') ?? 'Limite de messages atteinte', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(_t('ai_paywall_desc'), textAlign: TextAlign.center, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13)),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _subscribeMonthly,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFC5A059),
              foregroundColor: const Color(0xFF003D1B),
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            child: Text(_t('upgrade_premium'), style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildPaywall() {
    return Scaffold(
      backgroundColor: const Color(0xFF003D1B),
      body: Stack(
        children: [
          Positioned.fill(child: Opacity(opacity: 0.1, child: _buildTiledZellij(Colors.white))),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), shape: BoxShape.circle),
                    child: const Icon(Icons.auto_awesome_rounded, color: Color(0xFFC5A059), size: 64),
                  ),
                  const SizedBox(height: 32),
                  const Text('Flousi AI Premium', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Text(
                    _t('ai_paywall_desc'),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 16),
                  ),
                  const SizedBox(height: 48),
                  _buildFeatureRow(Icons.bolt_rounded, _t('ai_feature1')),
                  _buildFeatureRow(Icons.insights_rounded, _t('ai_feature2')),
                  _buildFeatureRow(Icons.security_rounded, _t('ai_feature3')),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: _subscribeMonthly,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFC5A059),
                      foregroundColor: const Color(0xFF003D1B),
                      minimumSize: const Size(double.infinity, 64),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    child: Text(_t('upgrade_premium'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: widget.onBackPressed ?? () => Navigator.pop(context),
                    child: Text(_t('later'), style: TextStyle(color: Colors.white.withOpacity(0.5))),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFC5A059), size: 24),
          const SizedBox(width: 16),
          Expanded(child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  Widget _buildTiledZellij(Color color) {
    return LayoutBuilder(
      builder: (context, constraints) => Wrap(
        children: List.generate(
          100,
          (_) => Icon(Icons.grid_3x3_rounded, color: color.withOpacity(0.1), size: 60),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(String text, bool isUser) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isUser ? const Color(0xFF003D1B) : Colors.white,
          borderRadius: BorderRadius.only(topLeft: const Radius.circular(24), topRight: const Radius.circular(24), bottomLeft: Radius.circular(isUser ? 24 : 4), bottomRight: Radius.circular(isUser ? 4 : 24)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Text(text, style: TextStyle(color: isUser ? Colors.white : const Color(0xFF263238), fontWeight: isUser ? FontWeight.bold : FontWeight.normal, fontSize: 15)),
      ),
    );
  }

  Widget _buildInputArea() {
    final int userMsgCount = _messages.where((m) => m['role'] == 'user').length;
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!_isPremium)
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text(
              '${3 - userMsgCount} ${_t('messages_left') ?? 'messages restants'}',
              style: TextStyle(color: const Color(0xFF003D1B).withOpacity(0.5), fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
        Container(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(40))),
          child: Row(
            children: [
              Expanded(child: Container(padding: const EdgeInsets.symmetric(horizontal: 24), decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(30)), child: TextField(controller: _controller, style: const TextStyle(fontWeight: FontWeight.bold), decoration: InputDecoration(hintText: _t('ask_ai'), border: InputBorder.none), onSubmitted: (_) => _handleSend()))),
              const SizedBox(width: 12),
              GestureDetector(onTap: _handleSend, child: Container(padding: const EdgeInsets.all(16), decoration: const BoxDecoration(color: Color(0xFF003D1B), shape: BoxShape.circle), child: const Icon(Icons.send_rounded, color: Colors.white, size: 24))),
            ],
          ),
        ),
      ],
    );
  }
}
