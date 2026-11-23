import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../data/backend.dart';
import '../../data/mock_data.dart';
import '../../l10n.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

/// Round E3 — child safety.
///  * ParentApprovalCard: a student under 18 shows this code to a parent, who approves the account.
///  * FamilyScreen: a parent's children — linked accounts (13–17) and child profiles (no login) —
///    with each child's lessons, tutors and chats, read-only.

class ParentApprovalCard extends StatelessWidget {
  const ParentApprovalCard({super.key});
  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final code = '${app.parentCode?['code'] ?? ''}';
    if (!app.waitingForParent || code.isEmpty) return const SizedBox.shrink();
    return AppCard(
      key: const Key('parent-approval'),
      color: AppColors.accentSoft,
      borderColor: AppColors.accent,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.family_restroom_rounded, color: AppColors.accent),
          const SizedBox(width: 10),
          Expanded(child: Text(context.tr('parent_needed_t'), style: const TextStyle(fontWeight: FontWeight.w800))),
        ]),
        const SizedBox(height: 6),
        Text(context.tr('parent_needed_b'), style: const TextStyle(color: AppColors.text2, height: 1.5)),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: SelectableText(code, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: 4), textDirection: TextDirection.ltr),
          ),
          IconButton(
            tooltip: context.tr('copy'),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: code));
              toast(context, context.tr('copied'));
            },
            icon: const Icon(Icons.copy_rounded),
          ),
          IconButton(tooltip: context.tr('refresh'), onPressed: app.refreshFamily, icon: const Icon(Icons.refresh_rounded)),
        ]),
      ]),
    );
  }
}

class FamilyScreen extends StatelessWidget {
  const FamilyScreen({super.key});

  Future<void> _link(BuildContext context) async {
    final app = context.read<AppState>();
    final ctrl = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(context.tr('link_child_t'), style: const TextStyle(fontWeight: FontWeight.w800)),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(context.tr('link_child_b'), style: const TextStyle(color: AppColors.text2, height: 1.5)),
          const SizedBox(height: 10),
          TextField(
            key: const Key('link-code'),
            controller: ctrl,
            textCapitalization: TextCapitalization.characters,
            textDirection: TextDirection.ltr,
            decoration: const InputDecoration(hintText: 'ABCD2345'),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: Text(context.tr('cancel'))),
          TextButton(onPressed: () => Navigator.pop(d, ctrl.text), child: Text(context.tr('approve'))),
        ],
      ),
    );
    if (code != null && code.trim().isNotEmpty) await app.linkChildAccount(code);
  }

  Future<void> _editChild(BuildContext context, {Map<String, dynamic>? child}) async {
    final app = context.read<AppState>();
    final name = TextEditingController(text: '${child?['name'] ?? ''}');
    String level = '${child?['level_id'] ?? 'elementary'}';
    int? year = (child?['birth_year'] as num?)?.toInt();
    final now = DateTime.now().year;
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => StatefulBuilder(
        builder: (d, set) => AlertDialog(
          title: Text(context.tr(child == null ? 'add_child' : 'edit_child'), style: const TextStyle(fontWeight: FontWeight.w800)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(key: const Key('child-name'), controller: name, decoration: InputDecoration(hintText: context.tr('child_name'))),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: MockData.levels.any((l) => l.id == level) ? level : MockData.levels.first.id,
              items: [for (final l in MockData.levels) DropdownMenuItem(value: l.id, child: Text(l.name.of(context)))],
              onChanged: (v) => set(() => level = v ?? level),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<int>(
              value: year,
              hint: Text(context.tr('birth_year')),
              items: [for (var y = now - 3; y >= now - 20; y--) DropdownMenuItem(value: y, child: Text('$y'))],
              onChanged: (v) => set(() => year = v),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(d, false), child: Text(context.tr('cancel'))),
            TextButton(onPressed: () => Navigator.pop(d, name.text.trim().isNotEmpty), child: Text(context.tr('save'))),
          ],
        ),
      ),
    );
    if (ok == true) await app.saveChildProfile(id: child?['id'] as String?, name: name.text, level: level, birthYear: year);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    Widget tile(Map<String, dynamic> c, {required bool account}) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: AppCard(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChildActivityScreen(id: '${c['id']}', name: '${c['name']}'))),
            child: Row(children: [
              Icon(account ? Icons.phone_iphone_rounded : Icons.child_care_rounded, color: AppColors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${c['name']}', style: const TextStyle(fontWeight: FontWeight.w800)),
                  Text(context.tr(account ? 'child_account' : 'child_profile'), style: const TextStyle(color: AppColors.text2, fontSize: 12.5)),
                ]),
              ),
              PopupMenuButton<String>(
                onSelected: (v) async {
                  if (v == 'edit') await _editChild(context, child: c);
                  if (v == 'remove') account ? await app.unlinkChildAccount('${c['id']}') : await app.removeChildProfile('${c['id']}');
                },
                itemBuilder: (_) => [
                  if (!account) PopupMenuItem(value: 'edit', child: Text(context.tr('edit_child'))),
                  PopupMenuItem(value: 'remove', child: Text(context.tr(account ? 'unlink_child' : 'remove_child'))),
                ],
              ),
            ]),
          ),
        );
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: AppColors.surface,
        title: Text(context.tr('my_children'), style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: MaxWidth(
        max: 720,
        child: RefreshIndicator(
          onRefresh: app.refreshFamily,
          child: ListView(padding: const EdgeInsets.all(16), children: [
            Text(context.tr('my_children_b'), style: const TextStyle(color: AppColors.text2, height: 1.5)),
            const SizedBox(height: 14),
            for (final c in app.childAccounts) tile(c, account: true),
            for (final c in app.childProfiles) tile(c, account: false),
            if (app.childAccounts.isEmpty && app.childProfiles.isEmpty)
              Padding(padding: const EdgeInsets.symmetric(vertical: 24), child: Center(child: Text(context.tr('no_children'), style: const TextStyle(color: AppColors.text3)))),
            const SizedBox(height: 8),
            OutlinedButton.icon(key: const Key('add-child'), onPressed: () => _editChild(context), icon: const Icon(Icons.person_add_alt_rounded), label: Text(context.tr('add_child'))),
            const SizedBox(height: 8),
            OutlinedButton.icon(key: const Key('link-child'), onPressed: () => _link(context), icon: const Icon(Icons.key_rounded), label: Text(context.tr('link_child_t'))),
          ]),
        ),
      ),
    );
  }
}

/// One child's lessons and chats (read-only for the parent).
class ChildActivityScreen extends StatefulWidget {
  final String id;
  final String name;
  const ChildActivityScreen({super.key, required this.id, required this.name});
  @override
  State<ChildActivityScreen> createState() => _ChildActivityScreenState();
}

class _ChildActivityScreenState extends State<ChildActivityScreen> {
  Map<String, dynamic>? _data;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final d = await context.read<AppState>().childActivity(widget.id);
    if (mounted) setState(() => _data = d ?? const {});
  }

  @override
  Widget build(BuildContext context) {
    final lessons = [for (final x in (_data?['lessons'] as List? ?? const [])) Map<String, dynamic>.from(x as Map)];
    final chats = [for (final x in (_data?['chats'] as List? ?? const [])) Map<String, dynamic>.from(x as Map)];
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: AppColors.surface,
        title: Text(widget.name, style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: _data == null
          ? const Center(child: CircularProgressIndicator())
          : MaxWidth(
              max: 720,
              child: RefreshIndicator(
                onRefresh: _load,
                child: ListView(padding: const EdgeInsets.all(16), children: [
                  Text(context.tr('nav_lessons'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                  const SizedBox(height: 8),
                  if (lessons.isEmpty) Text(context.tr('none'), style: const TextStyle(color: AppColors.text3)),
                  for (final l in lessons)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: AppCard(
                        child: Row(children: [
                          Icon(l['mode'] == 'in_person' ? Icons.home_work_rounded : Icons.videocam_rounded, color: AppColors.primary),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('${l['tutor_name']} · ${l['subject_id'] == null ? '' : MockData.subject('${l['subject_id']}').name.of(context)}',
                                  style: const TextStyle(fontWeight: FontWeight.w700)),
                              Text('${'${dayOf(context, Backend.time(l['starts_at']).toLocal())} ${timeOf(context, Backend.time(l['starts_at']).toLocal())}'} · ${l['duration_min']} ${context.tr('min')} · ${l['status']}',
                                  style: const TextStyle(color: AppColors.text2, fontSize: 12.5)),
                            ]),
                          ),
                        ]),
                      ),
                    ),
                  if (chats.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Text(context.tr('nav_messages'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                    const SizedBox(height: 8),
                    for (final c in chats)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: AppCard(
                          onTap: () => Navigator.push(context, MaterialPageRoute(
                            builder: (_) => ChildChatScreen(conversationId: '${c['id']}', title: '${widget.name} ↔ ${c['tutor_name']}'),
                          )),
                          child: Row(children: [
                            const Icon(Icons.chat_bubble_outline_rounded, color: AppColors.primary),
                            const SizedBox(width: 10),
                            Expanded(child: Text('${c['tutor_name']}', style: const TextStyle(fontWeight: FontWeight.w700))),
                            const Icon(Icons.chevron_right_rounded, color: AppColors.text3),
                          ]),
                        ),
                      ),
                  ],
                ]),
              ),
            ),
    );
  }
}

/// A linked child's chat with a tutor — the parent can read, not write.
class ChildChatScreen extends StatefulWidget {
  final String conversationId;
  final String title;
  const ChildChatScreen({super.key, required this.conversationId, required this.title});
  @override
  State<ChildChatScreen> createState() => _ChildChatScreenState();
}

class _ChildChatScreenState extends State<ChildChatScreen> {
  final List<Map<String, dynamic>> _msgs = [];
  bool _loading = true;
  bool _more = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final before = _msgs.isEmpty ? null : Backend.time(_msgs.last['created_at']);
    final rows = await context.read<AppState>().childChatMessages(widget.conversationId, before: before);
    if (!mounted) return;
    setState(() {
      _msgs.addAll(rows);
      _more = rows.length >= 50;
      _loading = false;
    });
  }

  String _body(BuildContext context, Map<String, dynamic> m) => switch ('${m['kind']}') {
        'voice' => '🎤',
        'image' => '📷',
        'file' => '📎',
        'call' => '📞 ${context.tr('call')}',
        _ => '${m['body'] ?? ''}',
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: AppColors.surface,
        title: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(children: [
              Container(
                width: double.infinity,
                color: AppColors.infoSoft,
                padding: const EdgeInsets.all(10),
                child: Text(context.tr('read_only_chat'), textAlign: TextAlign.center, style: const TextStyle(color: AppColors.info, fontSize: 12.5)),
              ),
              Expanded(
                child: ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(12),
                  itemCount: _msgs.length + (_more ? 1 : 0),
                  itemBuilder: (context, i) {
                    if (i == _msgs.length) {
                      return Center(child: TextButton(onPressed: _load, child: Text(context.tr('load_more'))));
                    }
                    final m = _msgs[i];
                    final child = m['from_child'] == true;
                    return Align(
                      alignment: child ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        constraints: const BoxConstraints(maxWidth: 420),
                        decoration: BoxDecoration(
                          color: child ? AppColors.primarySoft : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: m['blocked'] == true ? AppColors.danger : AppColors.line),
                        ),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(_body(context, m), style: const TextStyle(height: 1.4)),
                          Text(
                            '${'${dayOf(context, Backend.time(m['created_at']).toLocal())} ${timeOf(context, Backend.time(m['created_at']).toLocal())}'}${m['blocked'] == true ? ' · ${context.tr('hidden_contact')}' : ''}',
                            style: const TextStyle(color: AppColors.text3, fontSize: 11),
                          ),
                        ]),
                      ),
                    );
                  },
                ),
              ),
            ]),
    );
  }
}
