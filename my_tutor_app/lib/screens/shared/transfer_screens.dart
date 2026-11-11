import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData, FilteringTextInputFormatter;
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../data/models.dart';
import '../../l10n.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

/// Paying by transfer: the student sends money to the Dars account (Sham Cash, Syriatel Cash,
/// MTN Cash or bank), writes the reference in the note, and uploads a screenshot of the transfer.
/// The admin checks it and confirms; the credit / booking is then confirmed automatically.

const transferMethodKeys = ['sham_cash', 'syriatel_cash', 'mtn_cash', 'bank'];

String methodTitle(String key, bool ar) => switch (key) {
      'sham_cash' => ar ? 'شام كاش' : 'Sham Cash',
      'syriatel_cash' => ar ? 'سيريتل كاش' : 'Syriatel Cash',
      'mtn_cash' => ar ? 'MTN كاش' : 'MTN Cash',
      'bank' || 'bank_transfer' => ar ? 'تحويل بنكي' : 'Bank transfer',
      _ => key,
    };

IconData methodIcon(String key) => key == 'bank' || key == 'bank_transfer' ? Icons.account_balance_rounded : Icons.phone_android_rounded;

/// The pay-to key of a payment method value ('bank_transfer' → 'bank').
String methodKeyOf(String method) => method == 'bank_transfer' ? 'bank' : method;

/// Method tiles: only the methods Dars has an account for.
class TransferMethodTiles extends StatelessWidget {
  final Map<String, String> accounts;
  final String? selected;
  final ValueChanged<String> onSelect;
  const TransferMethodTiles({super.key, required this.accounts, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final ar = context.isAr;
    final keys = transferMethodKeys.where((k) => (accounts[k] ?? '').isNotEmpty).toList();
    return Column(children: [
      for (final k in keys) ...[
        ChoiceTile(
          title: methodTitle(k, ar),
          subtitle: k == 'bank' ? (ar ? 'من حسابك المصرفي' : 'From your bank account') : (ar ? 'من محفظتك على الهاتف' : 'From your mobile wallet'),
          icon: methodIcon(k),
          color: k == 'bank' ? AppColors.info : AppColors.primary,
          selected: selected == k,
          onTap: () => onSelect(k),
        ),
        const SizedBox(height: 8),
      ],
    ]);
  }
}

/// Add credit to my Dars wallet: amount → method → transfer details → receipt.
class TopUpScreen extends StatefulWidget {
  const TopUpScreen({super.key, this.suggested});
  final double? suggested; // e.g. the amount missing for a booking
  @override
  State<TopUpScreen> createState() => _TopUpScreenState();
}

class _TopUpScreenState extends State<TopUpScreen> {
  late final TextEditingController _amount;
  String? _method;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final s = widget.suggested;
    _amount = TextEditingController(text: s == null ? '' : (s % 1 == 0 ? s.toInt().toString() : s.toStringAsFixed(2)));
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  double? get _value => double.tryParse(_amount.text.trim().replaceAll(',', '.'));

  Future<void> _continue(AppState app) async {
    final v = _value;
    final m = _method;
    if (v == null || v <= 0 || m == null) return;
    setState(() => _busy = true);
    final info = await app.requestTopUp(v, m);
    if (!mounted) return;
    setState(() => _busy = false);
    if (info != null) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => TransferScreen(info: info, topUp: true)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final ar = context.isAr;
    final hasMethods = transferMethodKeys.any((k) => (app.payTo[k] ?? '').isNotEmpty);
    final ok = (_value ?? 0) > 0 && _method != null && !_busy;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: AppColors.surface,
        title: Text(ar ? 'شحن الرصيد' : 'Add credit', style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: MaxWidth(
        max: 640,
        child: ListView(padding: const EdgeInsets.all(20), children: [
          Text(ar ? 'المبلغ (دولار)' : 'Amount (USD)', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 10),
          TextField(
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(prefixText: '\$ ', hintText: ar ? 'مثلاً 20' : 'e.g. 20'),
          ),
          const SizedBox(height: 10),
          Wrap(spacing: 8, children: [
            for (final q in const [10, 20, 50, 100])
              ActionChip(
                label: Text(money(q)),
                onPressed: () => setState(() => _amount.text = '$q'),
              ),
          ]),
          const SizedBox(height: 22),
          Text(ar ? 'طريقة الدفع' : 'Payment method', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 10),
          if (hasMethods)
            TransferMethodTiles(accounts: app.payTo, selected: _method, onSelect: (k) => setState(() => _method = k))
          else
            AppCard(
              color: AppColors.accentSoft,
              borderColor: AppColors.accentSoft,
              child: Text(
                ar ? 'الدفع بالتحويل قيد التجهيز. تواصل مع دعم درس لشحن رصيدك.' : 'Paying by transfer is being set up. Contact Dars support to add credit.',
                style: const TextStyle(height: 1.5),
              ),
            ),
        ]),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: ElevatedButton(
            onPressed: ok ? () => _continue(app) : null,
            child: _busy
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                : Text(ar ? 'متابعة' : 'Continue'),
          ),
        ),
      ),
    );
  }
}

/// Pay a booking that is waiting for payment: choose the method, then the transfer screen.
class PayByTransferScreen extends StatefulWidget {
  const PayByTransferScreen({super.key, required this.paymentId, required this.amount});
  final String paymentId;
  final double amount;
  @override
  State<PayByTransferScreen> createState() => _PayByTransferScreenState();
}

class _PayByTransferScreenState extends State<PayByTransferScreen> {
  String? _method;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final ar = context.isAr;
    final hasMethods = transferMethodKeys.any((k) => (app.payTo[k] ?? '').isNotEmpty);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: AppColors.surface,
        title: Text(ar ? 'إكمال الدفع' : 'Complete payment', style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: MaxWidth(
        max: 640,
        child: ListView(padding: const EdgeInsets.all(20), children: [
          AppCard(
            child: Row(children: [
              Text(ar ? 'المبلغ المطلوب' : 'Amount to pay', style: const TextStyle(color: AppColors.text2)),
              const Spacer(),
              Text(money(widget.amount), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
            ]),
          ),
          const SizedBox(height: 18),
          Text(ar ? 'طريقة الدفع' : 'Payment method', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 10),
          if (hasMethods)
            TransferMethodTiles(accounts: app.payTo, selected: _method, onSelect: (k) => setState(() => _method = k))
          else
            Text(ar ? 'الدفع بالتحويل قيد التجهيز. تواصل مع دعم درس.' : 'Paying by transfer is being set up. Please contact Dars support.',
                style: const TextStyle(color: AppColors.text2)),
        ]),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: ElevatedButton(
            onPressed: _method == null || _busy
                ? null
                : () async {
                    setState(() => _busy = true);
                    final info = await app.transferFor(widget.paymentId, _method!);
                    if (!mounted) return;
                    setState(() => _busy = false);
                    if (info != null) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => TransferScreen(info: info)));
                  },
            child: Text(ar ? 'متابعة' : 'Continue'),
          ),
        ),
      ),
    );
  }
}

/// Where to send the money, the reference to write, and the "upload receipt" button.
class TransferScreen extends StatefulWidget {
  const TransferScreen({super.key, required this.info, this.topUp = false});
  final TransferInfo info;
  final bool topUp;
  @override
  State<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends State<TransferScreen> {
  bool _busy = false;
  bool _sent = false;

  Future<void> _upload(AppState app) async {
    XFile? f;
    try {
      f = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1600, imageQuality: 80);
    } catch (_) {
      if (mounted) toast(context, context.isAr ? 'تعذّر فتح المعرض' : 'Could not open the gallery', icon: Icons.error_outline);
      return;
    }
    if (f == null || !mounted) return;
    setState(() => _busy = true);
    final bytes = await f.readAsBytes();
    final ok = await app.submitReceipt(widget.info, bytes, f.name, f.mimeType);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _sent = ok;
    });
  }

  Widget _copyRow(BuildContext context, String label, String value, {bool big = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: const TextStyle(color: AppColors.text3, fontSize: 12.5)),
              const SizedBox(height: 2),
              SelectableText(value,
                  textDirection: TextDirection.ltr, style: TextStyle(fontWeight: FontWeight.w800, fontSize: big ? 22 : 17, letterSpacing: big ? 1.2 : 0)),
            ]),
          ),
          IconButton(
            tooltip: context.isAr ? 'نسخ' : 'Copy',
            icon: const Icon(Icons.copy_rounded, color: AppColors.primary),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: value));
              if (context.mounted) toast(context, context.isAr ? 'تم النسخ' : 'Copied');
            },
          ),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final ar = context.isAr;
    final i = widget.info;
    final amount = i.amount % 1 == 0 ? i.amount.toInt().toString() : i.amount.toStringAsFixed(2);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: AppColors.surface,
        title: Text(widget.topUp ? (ar ? 'شحن الرصيد' : 'Add credit') : (ar ? 'الدفع بالتحويل' : 'Pay by transfer'),
            style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: MaxWidth(
        max: 640,
        child: ListView(padding: const EdgeInsets.all(20), children: [
          if (_sent) ...[
            const SizedBox(height: 20),
            Center(
              child: Container(
                width: 96,
                height: 96,
                decoration: const BoxDecoration(color: AppColors.accentSoft, shape: BoxShape.circle),
                child: const Icon(Icons.hourglass_top_rounded, color: AppColors.accent, size: 54),
              ),
            ),
            const SizedBox(height: 18),
            Text(ar ? 'بانتظار التأكيد' : 'Waiting for confirmation', textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(
              widget.topUp
                  ? (ar ? 'وصلنا الإيصال. سيُضاف المبلغ إلى رصيدك بعد التحقق، وسيصلك إشعار.' : 'We got your receipt. The amount is added to your credit once checked — you will get a notification.')
                  : (ar ? 'وصلنا الإيصال. سيتأكد حجزك بعد التحقق، وسيصلك إشعار.' : 'We got your receipt. Your booking is confirmed once checked — you will get a notification.'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.text2, height: 1.6),
            ),
          ] else ...[
            Text(ar ? '١. حوّل المبلغ إلى حساب درس' : '1. Send the money to the Dars account', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 10),
            AppCard(
              child: Column(children: [
                Row(children: [
                  Icon(methodIcon(i.method), color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text(methodTitle(methodKeyOf(i.method), ar), style: const TextStyle(fontWeight: FontWeight.w800)),
                ]),
                const Divider(height: 20),
                _copyRow(context, ar ? 'رقم الحساب / المحفظة' : 'Account / wallet number', i.payTo),
                _copyRow(context, ar ? 'المبلغ (دولار)' : 'Amount (USD)', amount),
                _copyRow(context, ar ? 'رقم المرجع — اكتبه في ملاحظة التحويل' : 'Reference — write it in the transfer note', i.reference, big: true),
              ]),
            ),
            const SizedBox(height: 18),
            Text(ar ? '٢. ارفع صورة إيصال التحويل' : '2. Upload a screenshot of the transfer', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 6),
            Text(
              ar ? 'يجب أن تظهر في الصورة: المبلغ، والتاريخ، ورقم المرجع.' : 'The picture should show the amount, the date and the reference.',
              style: const TextStyle(color: AppColors.text2, height: 1.5),
            ),
          ],
        ]),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: _sent
              ? ElevatedButton(
                  onPressed: () {
                    if (!widget.topUp) app.goTab(3);
                    Navigator.of(context).popUntil((r) => r.isFirst);
                  },
                  child: Text(ar ? 'تم' : 'Done'),
                )
              : ElevatedButton.icon(
                  onPressed: _busy ? null : () => _upload(app),
                  icon: _busy
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                      : const Icon(Icons.upload_rounded),
                  label: Text(ar ? 'رفع الإيصال' : 'Upload receipt'),
                ),
        ),
      ),
    );
  }
}

/// One of my top-ups in the wallet list.
class TopUpTile extends StatelessWidget {
  const TopUpTile({super.key, required this.p});
  final PaymentInfo p;

  @override
  Widget build(BuildContext context) {
    final ar = context.isAr;
    final app = context.read<AppState>();
    final (String label, Color fg, Color bg) = switch (p.status) {
      'pending' => (ar ? 'بانتظار التحويل والإيصال' : 'Waiting for transfer & receipt', AppColors.accent, AppColors.accentSoft),
      'under_review' => (ar ? 'قيد المراجعة' : 'Being checked', AppColors.info, AppColors.infoSoft),
      'paid' => (ar ? 'أُضيف إلى رصيدك' : 'Added to your credit', AppColors.success, AppColors.successSoft),
      _ => (ar ? 'لم يُقبل' : 'Not accepted', AppColors.danger, AppColors.dangerSoft),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        onTap: p.status == 'pending'
            ? () async {
                final info = await app.transferFor(p.id, methodKeyOf(p.method));
                if (info != null && context.mounted) {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => TransferScreen(info: info, topUp: true)));
                }
              }
            : null,
        child: Row(children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
            child: Icon(methodIcon(p.method), color: fg),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${ar ? 'شحن رصيد' : 'Top-up'} · ${methodTitle(methodKeyOf(p.method), ar)}', style: const TextStyle(fontWeight: FontWeight.w700)),
              Text('${p.created.day}/${p.created.month}/${p.created.year} · ${p.reference}', style: const TextStyle(color: AppColors.text3, fontSize: 12.5)),
              const SizedBox(height: 4),
              Pill(label, bg: bg, fg: fg),
              if (p.status == 'failed' && p.failReason.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(p.failReason, style: const TextStyle(color: AppColors.danger, fontSize: 12.5)),
              ],
            ]),
          ),
          Text(money(p.amount), style: const TextStyle(fontWeight: FontWeight.w800)),
        ]),
      ),
    );
  }
}
