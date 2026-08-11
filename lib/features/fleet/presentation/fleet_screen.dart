import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:travla_customer_app/app/theme/app_colors.dart';
import 'package:travla_customer_app/core/network/api_failure.dart';
import 'package:travla_customer_app/features/fleet/data/fleet_repository.dart';
import 'package:travla_customer_app/features/fleet/domain/fleet_models.dart';

class FleetScreen extends ConsumerWidget {
  const FleetScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final home = ref.watch(fleetHomeProvider);

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(title: const Text('Fleet')),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.forest700,
        onPressed: () => context.push('/more/fleet/new'),
        icon: const Icon(Icons.add_business_outlined),
        label: const Text('New company'),
      ),
      body: RefreshIndicator(
        color: AppColors.forest700,
        onRefresh: () async {
          ref.invalidate(fleetHomeProvider);
          await ref.read(fleetHomeProvider.future).catchError((_) => const FleetHome(organisations: [], invites: []));
        },
        child: home.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => ListView(
            padding: const EdgeInsets.fromLTRB(16, 40, 16, 16),
            children: [
              Center(
                child: Text(error is ApiFailure ? error.message : 'Your fleet could not be loaded.',
                    textAlign: TextAlign.center),
              ),
            ],
          ),
          data: (data) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              if (data.invites.isNotEmpty) ...[
                const _Label('Invitations'),
                ...data.invites.map((i) => _InviteCard(invite: i)),
                const SizedBox(height: 16),
              ],
              const _Label('Your companies'),
              if (data.organisations.isEmpty)
                const _Empty()
              else
                ...data.organisations.map((o) => _OrgCard(org: o)),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrgCard extends StatelessWidget {
  const _OrgCard({required this.org});

  final FleetOrgRef org;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/more/fleet/${org.id}'),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(color: AppColors.forest50, borderRadius: BorderRadius.circular(13)),
                child: const Icon(Icons.corporate_fare_rounded, color: AppColors.forest700),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(org.name ?? 'Company', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (org.roleLabel != null) org.roleLabel!,
                        if (org.registrationNumber != null) org.registrationNumber!,
                      ].join(' · '),
                      style: const TextStyle(color: AppColors.muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (org.isOwner)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: AppColors.forest50, borderRadius: BorderRadius.circular(20)),
                  child: const Text('Owner', style: TextStyle(color: AppColors.forest700, fontSize: 10, fontWeight: FontWeight.w900)),
                ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _InviteCard extends ConsumerStatefulWidget {
  const _InviteCard({required this.invite});

  final FleetInvite invite;

  @override
  ConsumerState<_InviteCard> createState() => _InviteCardState();
}

class _InviteCardState extends ConsumerState<_InviteCard> {
  bool _busy = false;

  Future<void> _accept() async {
    setState(() => _busy = true);
    try {
      await ref.read(fleetRepositoryProvider).accept(widget.invite.id);
      ref.invalidate(fleetHomeProvider);
    } on ApiFailure catch (f) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(f.message)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.orangeSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFC9B7)),
      ),
      child: Row(
        children: [
          const Icon(Icons.mail_outline_rounded, color: AppColors.orangeDark),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.invite.name ?? 'A company', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5)),
                Text('Invited as ${widget.invite.roleLabel ?? 'member'}',
                    style: const TextStyle(color: AppColors.orangeDark, fontSize: 11.5)),
              ],
            ),
          ),
          FilledButton(
            onPressed: _busy ? null : _accept,
            style: FilledButton.styleFrom(backgroundColor: AppColors.orange, visualDensity: VisualDensity.compact),
            child: Text(_busy ? '…' : 'Accept'),
          ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: const Text(
        'You’re not part of a fleet company yet. Create one to manage vehicles, drivers and fuel by region.',
        textAlign: TextAlign.center,
        style: TextStyle(color: AppColors.muted, height: 1.5),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 0, 2, 10),
        child: Text(text.toUpperCase(),
            style: const TextStyle(color: AppColors.muted, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.1)),
      );
}
