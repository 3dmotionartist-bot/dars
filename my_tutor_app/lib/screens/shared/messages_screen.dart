import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models.dart';
import '../../l10n.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import 'chat_screen.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  String _q = ''; // Round G1: search chats by name

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final q = _q.trim().toLowerCase();
    final all = app.sortedConversations; // Round G3: pinned chats first
    final list = q.isEmpty
        ? all
        : all.where((c) => c.name.ar.toLowerCase().contains(q) || c.name.en.toLowerCase().contains(q)).toList();
    return SafeArea(
      child: MaxWidth(
        max: 760,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (MediaQuery.of(context).size.width < 900)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(context.tr('messages_title'), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
            ),
          if (app.chatsFromCache)
            Container(
              key: const Key('chats-offline'),
              margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                const Icon(Icons.cloud_off_rounded, size: 18, color: AppColors.text2),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.isAr ? 'لا يوجد اتصال — هذه آخر رسائل محفوظة على هاتفك' : 'No connection — these are the last messages saved on your phone',
                    style: const TextStyle(color: AppColors.text2, fontSize: 12.5),
                  ),
                ),
              ]),
            ),
          if (app.conversations.length > 3)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: TextField(
                key: const Key('chat-search'),
                onChanged: (v) => setState(() => _q = v),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search_rounded),
                  hintText: context.isAr ? 'ابحث بالاسم' : 'Search by name',
                  isDense: true,
                ),
              ),
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
                      if (last != null && last.deleted) {
                        preview = context.isAr ? 'تم حذف رسالة' : 'A message was deleted';
                      } else if (last != null) {
                        preview = switch (last.type) {
                          MsgType.voice => '🎤 ${context.tr('voice_msg')}',
                          MsgType.file => '📎 ${context.tr('file_msg')}',
                          MsgType.call => last.text.startsWith('meet')
                              ? '🔗 ${context.tr('meeting_link')}'
                              : '📞 ${context.tr(last.text.startsWith('video') ? 'video_call' : 'voice_call')}',
                          _ => last.text,
                        };
                        if (last.mine) preview = '${context.isAr ? 'أنت' : 'You'}: $preview';
                      }
                      final draft = app.draftOf(c).trim().replaceAll('\n', ' ');
                      final muted = app.isMuted(c);
                      final pinned = app.isPinned(c);
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                        onTap: () {
                          app.openConversation(c);
                          Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(conversation: c)));
                        },
                        onLongPress: c.id.isEmpty ? null : () => _chatMenu(context, app, c),
                        leading: Avatar(name: c.name, color: c.color, size: 52, online: c.online, photo: c.photo),
                        title: Row(children: [
                          Expanded(child: Text(c.name.of(context), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800))),
                          if (muted) const Padding(padding: EdgeInsetsDirectional.only(end: 4), child: Icon(Icons.notifications_off_outlined, size: 16, color: AppColors.text3)),
                          if (pinned) const Padding(padding: EdgeInsetsDirectional.only(end: 4), child: Icon(Icons.push_pin_rounded, size: 16, color: AppColors.text3)),
                          if (last != null) Text(ago(context, last.time), style: const TextStyle(color: AppColors.text3, fontSize: 12)),
                        ]),
                        subtitle: Row(children: [
                          Expanded(
                            child: draft.isNotEmpty
                                ? Text.rich(
                                    TextSpan(children: [
                                      TextSpan(text: context.isAr ? 'مسودة: ' : 'Draft: ', style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.w700)),
                                      TextSpan(text: draft),
                                    ]),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: AppColors.text2),
                                  )
                                : Text(preview, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.unread > 0 ? AppColors.ink : AppColors.text2, fontWeight: c.unread > 0 ? FontWeight.w700 : FontWeight.w400)),
                          ),
                          if (c.unread > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              // a muted chat still counts, in grey
                              decoration: BoxDecoration(color: muted ? AppColors.text3 : AppColors.primary, borderRadius: BorderRadius.circular(12)),
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

  /// Round G3: hold a chat to pin it or mute it.
  Future<void> _chatMenu(BuildContext context, AppState app, Conversation c) async {
    final ar = context.isAr;
    final pinned = app.isPinned(c);
    final muted = app.isMuted(c);
    final v = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            key: const Key('chat-pin'),
            leading: Icon(pinned ? Icons.push_pin_outlined : Icons.push_pin_rounded, color: AppColors.primary),
            title: Text(pinned ? (ar ? 'إلغاء التثبيت' : 'Unpin') : (ar ? 'تثبيت في الأعلى' : 'Pin to the top')),
            onTap: () => Navigator.pop(sheet, 'pin'),
          ),
          ListTile(
            key: const Key('chat-mute'),
            leading: Icon(muted ? Icons.notifications_active_outlined : Icons.notifications_off_outlined, color: AppColors.primary),
            title: Text(muted ? (ar ? 'إلغاء كتم الإشعارات' : 'Unmute') : (ar ? 'كتم الإشعارات' : 'Mute notifications')),
            onTap: () => Navigator.pop(sheet, 'mute'),
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (!context.mounted || v == null) return;
    if (v == 'mute') {
      app.toggleMute(c);
    } else if (!app.togglePin(c)) {
      toast(context, ar ? 'يمكن تثبيت ${AppState.maxPinned} محادثات فقط' : 'You can pin up to ${AppState.maxPinned} chats', icon: Icons.info_outline);
    }
  }
}
