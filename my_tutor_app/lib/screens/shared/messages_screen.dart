import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models.dart';
import '../../l10n.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import 'chat_screen.dart';

class MessagesScreen extends StatelessWidget {
  const MessagesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final list = app.conversations;
    return SafeArea(
      child: MaxWidth(
        max: 760,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (MediaQuery.of(context).size.width < 900)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(context.tr('messages_title'), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
            ),
          Expanded(
            child: list.isEmpty
                ? EmptyState(icon: Icons.chat_bubble_outline_rounded, title: context.tr('no_messages'), body: context.tr('no_messages_b'))
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, indent: 84),
                    itemBuilder: (_, i) {
                      final c = list[i];
                      final last = c.last;
                      String preview = '';
                      if (last != null) {
                        preview = switch (last.type) {
                          MsgType.voice => '🎤 ${context.tr('voice_msg')}',
                          MsgType.file => '📎 ${context.tr('file_msg')}',
                          _ => last.text,
                        };
                        if (last.mine) preview = '${context.isAr ? 'أنت' : 'You'}: $preview';
                      }
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                        onTap: () {
                          app.openConversation(c);
                          Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(conversation: c)));
                        },
                        leading: Avatar(name: c.name, color: c.color, size: 52, online: c.online),
                        title: Row(children: [
                          Expanded(child: Text(c.name.of(context), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800))),
                          if (last != null) Text(ago(context, last.time), style: const TextStyle(color: AppColors.text3, fontSize: 12)),
                        ]),
                        subtitle: Row(children: [
                          Expanded(
                            child: Text(preview, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.unread > 0 ? AppColors.ink : AppColors.text2, fontWeight: c.unread > 0 ? FontWeight.w700 : FontWeight.w400)),
                          ),
                          if (c.unread > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(12)),
                              child: Text('${c.unread}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
                            ),
                        ]),
                      );
                    },
                  ),
          ),
        ]),
      ),
    );
  }
}
