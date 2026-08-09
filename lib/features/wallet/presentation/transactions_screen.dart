import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:travla_customer_app/app/theme/app_colors.dart';
import 'package:travla_customer_app/core/network/api_failure.dart';
import 'package:travla_customer_app/features/wallet/data/wallet_repository.dart';
import 'package:travla_customer_app/features/wallet/domain/wallet_models.dart';
import 'package:url_launcher/url_launcher.dart';

enum _LedgerFilter { all, credits, debits }

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  static const _pendingReferenceKey = 'travla.pending_wallet_topup';

  _LedgerFilter _filter = _LedgerFilter.all;
  String? _pendingReference;
  bool _verifying = false;

  @override
  void initState() {
    super.initState();
    _restorePendingReference();
  }

  Future<void> _restorePendingReference() async {
    final preferences = await SharedPreferences.getInstance();
    final reference = preferences.getString(_pendingReferenceKey);
    if (mounted && reference != null && reference.isNotEmpty) {
      setState(() => _pendingReference = reference);
    }
  }

  Future<void> _savePendingReference(String? reference) async {
    final preferences = await SharedPreferences.getInstance();
    if (reference == null) {
      await preferences.remove(_pendingReferenceKey);
    } else {
      await preferences.setString(_pendingReferenceKey, reference);
    }
    if (mounted) setState(() => _pendingReference = reference);
  }

  @override
  Widget build(BuildContext context) {
    final workspace = ref.watch(walletWorkspaceProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Transactions')),
      body: workspace.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _WalletError(
          message: error is ApiFailure
              ? error.message
              : 'Your transactions could not be loaded.',
          onRetry: () => ref.invalidate(walletWorkspaceProvider),
        ),
        data: _buildWorkspace,
      ),
    );
  }

  Widget _buildWorkspace(WalletWorkspace workspace) {
    final transactions = workspace.transactions
        .where((transaction) {
          return switch (_filter) {
            _LedgerFilter.all => true,
            _LedgerFilter.credits => transaction.isCredit,
            _LedgerFilter.debits => !transaction.isCredit,
          };
        })
        .toList(growable: false);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(walletWorkspaceProvider);
        await ref.read(walletWorkspaceProvider.future);
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 36),
        children: [
          _BalancePanel(
            workspace: workspace,
            onFund: workspace.methods.canFund
                ? () => _showTopUpSheet(workspace.methods)
                : null,
          ),
          if (_pendingReference != null) ...[
            const SizedBox(height: 12),
            _PendingPaymentPanel(
              reference: _pendingReference!,
              isVerifying: _verifying,
              onVerify: _verifyPendingTopUp,
              onDismiss: () => _savePendingReference(null),
            ),
          ],
          if (workspace.methods.virtualAccount case final account?) ...[
            const SizedBox(height: 12),
            _VirtualAccountPanel(account: account),
          ],
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Activity',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
              ),
              Text(
                '${workspace.summary.totalCount} records',
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SegmentedButton<_LedgerFilter>(
            segments: const [
              ButtonSegment(value: _LedgerFilter.all, label: Text('All')),
              ButtonSegment(
                value: _LedgerFilter.credits,
                label: Text('Credits'),
              ),
              ButtonSegment(value: _LedgerFilter.debits, label: Text('Debits')),
            ],
            selected: {_filter},
            showSelectedIcon: false,
            onSelectionChanged: (selection) {
              setState(() => _filter = selection.first);
            },
          ),
          const SizedBox(height: 12),
          if (transactions.isEmpty)
            const _EmptyLedger()
          else
            ...transactions.map(_TransactionCard.new),
        ],
      ),
    );
  }

  Future<void> _showTopUpSheet(WalletMethods methods) async {
    final amount = TextEditingController();
    var selectedGateway =
        methods.defaultGateway ??
        (methods.gateways.isEmpty ? null : methods.gateways.first.name);
    var submitting = false;
    String? error;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          Future<void> submit() async {
            final value = int.tryParse(amount.text.replaceAll(',', '').trim());
            if (value == null || value < 100) {
              setSheetState(() => error = 'Enter at least ₦100.');
              return;
            }
            setSheetState(() {
              submitting = true;
              error = null;
            });
            try {
              final intent = await ref
                  .read(walletRepositoryProvider)
                  .initializeTopUp(
                    amountNaira: value,
                    gateway: selectedGateway,
                  );
              await _savePendingReference(intent.reference);
              final opened = await launchUrl(
                Uri.parse(intent.authorizationUrl),
                mode: LaunchMode.externalApplication,
              );
              if (!opened) {
                throw const ApiFailure('The secure payment page did not open.');
              }
              if (sheetContext.mounted) Navigator.pop(sheetContext);
            } on ApiFailure catch (failure) {
              if (sheetContext.mounted) {
                setSheetState(() => error = failure.message);
              }
            } finally {
              if (sheetContext.mounted) {
                setSheetState(() => submitting = false);
              }
            }
          }

          return Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              14,
              20,
              MediaQuery.viewInsetsOf(context).bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Fund your wallet',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Add funds securely. Travla verifies the payment before your balance changes.',
                  style: TextStyle(color: AppColors.muted, height: 1.45),
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: amount,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Amount',
                    prefixText: '₦ ',
                    hintText: '10,000',
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: [2000, 5000, 10000, 20000]
                      .map((preset) {
                        return ActionChip(
                          label: Text('₦${_formatWhole(preset)}'),
                          onPressed: () => amount.text = '$preset',
                        );
                      })
                      .toList(growable: false),
                ),
                if (methods.gateways.length > 1) ...[
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: selectedGateway,
                    decoration: const InputDecoration(
                      labelText: 'Payment gateway',
                    ),
                    items: methods.gateways
                        .map(
                          (gateway) => DropdownMenuItem(
                            value: gateway.name,
                            child: Text(gateway.label),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (value) {
                      setSheetState(() => selectedGateway = value);
                    },
                  ),
                ],
                if (error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    error!,
                    style: const TextStyle(
                      color: AppColors.danger,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: submitting ? null : submit,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(54),
                    backgroundColor: AppColors.orange,
                  ),
                  icon: submitting
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.lock_outline_rounded),
                  label: Text(
                    submitting ? 'Preparing checkout…' : 'Continue securely',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
    amount.dispose();
  }

  Future<void> _verifyPendingTopUp() async {
    final reference = _pendingReference;
    if (reference == null || _verifying) return;
    setState(() => _verifying = true);
    try {
      final verification = await ref
          .read(walletRepositoryProvider)
          .verifyTopUp(reference);
      if (!mounted) return;
      if (verification.isComplete) {
        await _savePendingReference(null);
        if (!mounted) return;
        ref.invalidate(walletWorkspaceProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment confirmed. Wallet updated.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Payment is ${verification.status.toLowerCase()}. Try again after completing checkout.',
            ),
          ),
        );
      }
    } on ApiFailure catch (failure) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(failure.message)));
      }
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }
}

class _BalancePanel extends StatelessWidget {
  const _BalancePanel({required this.workspace, required this.onFund});

  final WalletWorkspace workspace;
  final VoidCallback? onFund;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.forest950, AppColors.forest700],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'AVAILABLE BALANCE',
              style: TextStyle(
                color: Color(0xFFBBD8CD),
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '₦${_formatMoney(workspace.wallet.balanceNaira)}',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _BalanceMetric(
                    label: 'Total funded',
                    value:
                        '₦${_formatMoney(workspace.summary.totalCreditNaira)}',
                    icon: Icons.south_west_rounded,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _BalanceMetric(
                    label: 'Services & debits',
                    value:
                        '₦${_formatMoney(workspace.summary.totalDebitNaira)}',
                    icon: Icons.north_east_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onFund,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.orange,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
              ),
              icon: const Icon(Icons.add_rounded),
              label: Text(
                onFund == null ? 'Wallet funding unavailable' : 'Fund wallet',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BalanceMetric extends StatelessWidget {
  const _BalanceMetric({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: .12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: const Color(0xFFBBD8CD)),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xFFBBD8CD), fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _PendingPaymentPanel extends StatelessWidget {
  const _PendingPaymentPanel({
    required this.reference,
    required this.isVerifying,
    required this.onVerify,
    required this.onDismiss,
  });

  final String reference;
  final bool isVerifying;
  final VoidCallback onVerify;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.orangeSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF7C5B5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.pending_actions_rounded, color: AppColors.orangeDark),
              SizedBox(width: 9),
              Expanded(
                child: Text(
                  'Payment checkout in progress',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            'Reference $reference. Confirm only after completing the secure payment page.',
            style: const TextStyle(color: AppColors.muted, fontSize: 12),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: isVerifying ? null : onVerify,
                  child: Text(isVerifying ? 'Checking…' : 'Verify payment'),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: isVerifying ? null : onDismiss,
                child: const Text('Dismiss'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _VirtualAccountPanel extends StatelessWidget {
  const _VirtualAccountPanel({required this.account});

  final WalletVirtualAccount account;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const CircleAvatar(
              backgroundColor: AppColors.forest100,
              foregroundColor: AppColors.forest700,
              child: Icon(Icons.account_balance_outlined),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Your Travla account',
                    style: TextStyle(fontSize: 11, color: AppColors.muted),
                  ),
                  Text(
                    account.accountNumber,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: .7,
                    ),
                  ),
                  Text(
                    '${account.bankName} · ${account.accountName}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Copy account number',
              onPressed: () async {
                await Clipboard.setData(
                  ClipboardData(text: account.accountNumber),
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Account number copied.')),
                  );
                }
              },
              icon: const Icon(Icons.copy_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

class _TransactionCard extends StatelessWidget {
  const _TransactionCard(this.transaction);

  final WalletTransaction transaction;

  @override
  Widget build(BuildContext context) {
    final credit = transaction.isCredit;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: credit
                  ? AppColors.forest100
                  : AppColors.orangeSoft,
              foregroundColor: credit
                  ? AppColors.forest700
                  : AppColors.orangeDark,
              child: Icon(
                credit ? Icons.south_west_rounded : Icons.north_east_rounded,
                size: 19,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    transaction.typeLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    transaction.description.isEmpty
                        ? transaction.reference
                        : transaction.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_formatDate(transaction.createdAt)} · Balance ₦${_formatMoney(transaction.balanceAfterNaira)}',
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${credit ? '+' : '−'}₦${_formatMoney(transaction.amountNaira)}',
                  style: TextStyle(
                    color: credit ? AppColors.forest700 : AppColors.ink,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  transaction.status.toUpperCase(),
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyLedger extends StatelessWidget {
  const _EmptyLedger();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 34),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: const Column(
        children: [
          Icon(Icons.receipt_long_outlined, color: AppColors.muted, size: 32),
          SizedBox(height: 10),
          Text(
            'No transactions in this view',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          SizedBox(height: 4),
          Text(
            'Wallet funding and every paid Travla service will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _WalletError extends StatelessWidget {
  const _WalletError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.account_balance_wallet_outlined, size: 42),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatMoney(String value) {
  final parts = value.replaceAll(',', '').split('.');
  final whole = int.tryParse(parts.first) ?? 0;
  final decimal = parts.length > 1
      ? parts[1].padRight(2, '0').substring(0, 2)
      : '00';
  return '${_formatWhole(whole)}.$decimal';
}

String _formatWhole(int value) {
  final digits = value.abs().toString();
  final output = StringBuffer();
  for (var index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) output.write(',');
    output.write(digits[index]);
  }
  return '${value < 0 ? '-' : ''}$output';
}

String _formatDate(DateTime? date) {
  if (date == null) return 'Date unavailable';
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[date.month - 1]} ${date.day}, ${date.year}';
}
