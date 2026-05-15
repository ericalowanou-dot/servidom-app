import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../constants/app_colors.dart';
import '../../models/message_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';

class ChatArgs {
  const ChatArgs({
    required this.reservationId,
    required this.titre,
    this.autrePartie,
  });

  final int reservationId;
  final String titre;
  final String? autrePartie;
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.reservationId,
    required this.titre,
    this.autrePartie,
  });

  final int reservationId;
  final String titre;
  final String? autrePartie;

  static const routeName = '/chat';

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  late Future<List<MessageModel>> _messagesFuture;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _messagesFuture = context.read<ApiService>().getMessages(widget.reservationId);
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await context.read<ApiService>().sendMessage(reservationId: widget.reservationId, contenu: text);
      _input.clear();
      setState(_reload);
      await _messagesFuture;
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(toFrenchErrorMessage(e))));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String _formatTime(DateTime d) {
    return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final myId = context.watch<AuthProvider>().user?.id;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.titre, style: const TextStyle(fontSize: 16)),
            if (widget.autrePartie != null && widget.autrePartie!.isNotEmpty)
              Text(widget.autrePartie!, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal)),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: FutureBuilder<List<MessageModel>>(
              future: _messagesFuture,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(child: Text(toFrenchErrorMessage(snap.error!)));
                }
                final messages = snap.data ?? [];
                if (messages.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Aucun message. Envoyez le premier pour coordonner l’intervention.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                  );
                }
                WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
                return ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                  itemCount: messages.length,
                  itemBuilder: (context, i) {
                    final m = messages[i];
                    final mine = myId != null && m.senderId == myId;
                    return Align(
                      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.78),
                        decoration: BoxDecoration(
                          color: mine ? AppColors.primary : AppColors.surface,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(16),
                            topRight: const Radius.circular(16),
                            bottomLeft: Radius.circular(mine ? 16 : 4),
                            bottomRight: Radius.circular(mine ? 4 : 16),
                          ),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 4, offset: const Offset(0, 2)),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (!mine && m.senderNomComplet.isNotEmpty)
                              Text(
                                m.senderNomComplet,
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.secondary),
                              ),
                            Text(
                              m.contenu,
                              style: TextStyle(color: mine ? Colors.white : AppColors.textPrimary, height: 1.35),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _formatTime(m.createdAt),
                              style: TextStyle(fontSize: 10, color: mine ? Colors.white70 : AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Material(
            elevation: 8,
            color: AppColors.surface,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _input,
                        maxLines: 4,
                        minLines: 1,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          hintText: 'Votre message…',
                          filled: true,
                          fillColor: AppColors.background,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                        onSubmitted: (_) => _send(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: _sending ? null : _send,
                      icon: _sending
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.send_rounded),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
