import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../constants/app_colors.dart';
import '../../models/message_model.dart';
import '../../services/api_service.dart';
import 'chat_screen.dart';

class ConversationsScreen extends StatefulWidget {
  const ConversationsScreen({super.key});

  static const routeName = '/conversations';

  @override
  State<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends State<ConversationsScreen> {
  late Future<List<ConversationModel>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = context.read<ApiService>().getMesConversations();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Messages')),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          setState(_reload);
          await _future;
        },
        child: FutureBuilder<List<ConversationModel>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(
                    height: 200,
                    child: Center(child: Text(toFrenchErrorMessage(snap.error!))),
                  ),
                ],
              );
            }
            final list = snap.data ?? [];
            if (list.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 80),
                  Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        'Aucune conversation.\nLes messages sont disponibles après une réservation.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              );
            }
            return ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: list.length,
              itemBuilder: (context, i) {
                final c = list[i];
                final nonLus = c.nonLus ?? 0;
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                    child: Text(
                      c.autrePartie.isNotEmpty ? c.autrePartie[0].toUpperCase() : '?',
                      style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                    ),
                  ),
                  title: Text(c.serviceTitre ?? 'Réservation', style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    c.dernierMessage?.isNotEmpty == true
                        ? c.dernierMessage!
                        : 'Conversation avec ${c.autrePartie}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: nonLus > 0
                      ? CircleAvatar(
                          radius: 12,
                          backgroundColor: AppColors.secondary,
                          child: Text('$nonLus', style: const TextStyle(fontSize: 11, color: Colors.white)),
                        )
                      : null,
                  onTap: () {
                    Navigator.pushNamed(
                      context,
                      ChatScreen.routeName,
                      arguments: ChatArgs(
                        reservationId: c.reservationId,
                        titre: c.serviceTitre ?? 'Chat',
                        autrePartie: c.autrePartie,
                      ),
                    ).then((_) {
                      if (mounted) setState(_reload);
                    });
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}
