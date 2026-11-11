import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models.dart';
import '../../l10n.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import 'transfer_screens.dart';

/// Student wallet: balance, add credit (transfer + receipt), refund request, payment history.
class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final canTopUp = app.role != UserRole.tutor;
    return Scaffold(
      appBar: AppBar(backgroundColor: AppColors.surface, surfaceTintColor: AppColors.surface, title: Text(context.tr('wallet'), style: const TextStyle(fontWeight: FontWeight.w800))),
      body: MaxWidth(
        max: 720,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: const LinearGradient(colors: [AppColors.ink, Color(0xFF243556)], begin: Alignment.topLeft, end: Alignment.bottomRight),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(context.tr('wallet_balance'), style: const TextStyle(color: Color(0xB3FFFFFF))),
              const SizedBox(height: 4),
              Text(money(app.walletBalance), style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w800)),
              const SizedBox(height: 14),
              Wrap(spacing: 10, runSpacing: 10, children: [
              if (canTopUp)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppColors.ink, minimumSize: const Size(0, 42)),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TopUpScreen())),
                  icon: const Icon(Icons.add_rounded),
                  label: Text(context.isAr ? 'شحن الرصيد' : 'Add credit'),
                ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Color(0x66FFFFFF)), minimumSize: const Size(0, 42)),
                onPressed: app.walletBalance <= 0
                    ? null
                    : () {
                        app.requestRefund();
                        toast(context, context.tr('refund_sent'));
                      },
                icon: const Icon(Icons.undo_rounded),
                label: Text(context.tr('request_refund')),
              ),
              ]),
            ]),
          ),
          if (canTopUp && app.topUps.isNotEmpty) ...[
            SectionTitle(context.isAr ? 'عمليات الشحن' : 'My top-ups'),
            for (final p in app.topUps) TopUpTile(p: p),
          ],
          SectionTitle(context.tr('transactions')),
          for (final tx in app.transactions)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AppCard(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(color: tx.amount >= 0 ? AppColors.successSoft : AppColors.surface, borderRadius: BorderRadius.circular(14)),
                    child: Icon(tx.amount >= 0 ? Icons.south_west_rounded : Icons.north_east_rounded, color: tx.amount >= 0 ? AppColors.success : AppColors.ink),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(tx.title.of(context), style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text('${tx.date.day}/${tx.date.month}/${tx.date.year} · ${tx.status.of(context)}', style: const TextStyle(color: AppColors.text3, fontSize: 12.5)),
                    ]),
                  ),
                  Text('${tx.amount >= 0 ? '+' : '-'}${money(double.parse(tx.amount.abs().toStringAsFixed(2)))}',
                      style: TextStyle(fontWeight: FontWeight.w800, color: tx.amount >= 0 ? AppColors.success : AppColors.ink)),
                ]),
              ),
            ),
        ]),
      ),
    );
  }
}
