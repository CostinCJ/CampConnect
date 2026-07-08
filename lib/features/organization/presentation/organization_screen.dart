import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import 'package:camp_connect/features/organization/domain/org_member.dart';
import 'package:camp_connect/features/organization/domain/organization.dart';
import 'package:camp_connect/l10n/app_localizations.g.dart';
import 'package:camp_connect/shared/providers/providers.dart';

/// Maps a lowercased org-management error message (from removeMember /
/// rotateInviteCode / joinOrganization callable failures) to a localized
/// message. Top-level for unit-testability, mirroring friendlyGuideAuthError
/// in guide_login_screen.
String friendlyOrgError(String errorMessageLowercase, AppL10n l10n) {
  final msg = errorMessageLowercase;
  if (msg.contains('not-org-owner')) return l10n.notOrgOwner;
  if (msg.contains('network') || msg.contains('unavailable')) {
    return l10n.networkError;
  }
  return l10n.somethingWentWrong;
}

/// "My organisation": every member sees the member list; the owner
/// additionally sees the invite code (copy + share), can rotate it, and can
/// remove non-owner guides.
class OrganizationScreen extends ConsumerWidget {
  const OrganizationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppL10n.of(context);
    final orgAsync = ref.watch(currentOrganizationProvider);
    final membersAsync = ref.watch(orgMembersProvider);
    final uid = ref.watch(appUserProvider).valueOrNull?.uid;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.myOrganization)),
      body: orgAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(child: Text(l10n.somethingWentWrong)),
        data: (org) {
          if (org == null || uid == null) {
            return Center(child: Text(l10n.somethingWentWrong));
          }
          final isOwner = org.ownerUid == uid;
          final members = membersAsync.valueOrNull ?? [];

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: ListTile(
                  leading: const Icon(Icons.business_outlined),
                  title: Text(org.name, style: theme.textTheme.titleMedium),
                ),
              ),
              if (isOwner) ...[
                const SizedBox(height: 12),
                _InviteCodeCard(org: org),
                const SizedBox(height: 12),
                _CodePrefixCard(org: org),
                const SizedBox(height: 12),
                _LogoCard(org: org),
              ],
              const SizedBox(height: 20),
              Text(l10n.members, style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Card(
                child: Column(
                  children: [
                    for (final member in members) ...[
                      if (member != members.first) const Divider(height: 1),
                      _MemberTile(
                        member: member,
                        isOwnerRow: member.uid == org.ownerUid,
                        canRemove: isOwner && member.uid != org.ownerUid,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _InviteCodeCard extends ConsumerWidget {
  const _InviteCodeCard({required this.org});

  final Organization org;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppL10n.of(context);

    Future<void> rotate() async {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.rotateInviteCodeAction),
          content: Text(l10n.rotateInviteCodeConfirm),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.rotateInviteCodeAction),
            ),
          ],
        ),
      );
      if (confirmed != true) return;

      try {
        await ref.read(organizationRepositoryProvider).rotateInviteCode();
        ref.invalidate(currentOrganizationProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(l10n.codeRotated)));
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(friendlyOrgError(e.toString().toLowerCase(), l10n)),
            ),
          );
        }
      }
    }

    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.vpn_key_outlined),
            title: Text(l10n.organizationInviteCode),
            subtitle: Text(org.inviteCode),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.copy),
                  onPressed: () async {
                    await Clipboard.setData(
                      ClipboardData(text: org.inviteCode),
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l10n.inviteCodeCopied)),
                      );
                    }
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.share_outlined),
                  tooltip: l10n.share,
                  onPressed: () => SharePlus.instance.share(
                    ShareParams(
                      text: l10n.shareInviteMessage(org.name, org.inviteCode),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.autorenew),
            title: Text(l10n.rotateInviteCodeAction),
            onTap: rotate,
          ),
        ],
      ),
    );
  }
}

class _CodePrefixCard extends ConsumerWidget {
  const _CodePrefixCard({required this.org});

  final Organization org;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppL10n.of(context);
    final theme = Theme.of(context);

    Future<void> edit() async {
      final controller = TextEditingController(text: org.effectiveCodePrefix);
      final newPrefix = await showDialog<String>(
        context: context,
        builder: (ctx) {
          String? errorText;
          return StatefulBuilder(
            builder: (ctx, setDialogState) => AlertDialog(
              title: Text(l10n.campCodePrefix),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.campCodePrefixDesc,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    textCapitalization: TextCapitalization.characters,
                    maxLength: 8,
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      errorText: errorText,
                      counterText: '',
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(l10n.cancel),
                ),
                FilledButton(
                  onPressed: () {
                    final value = controller.text.trim().toUpperCase();
                    if (!RegExp(r'^[A-Z0-9]{2,8}$').hasMatch(value)) {
                      setDialogState(
                        () => errorText = l10n.campCodePrefixInvalid,
                      );
                      return;
                    }
                    Navigator.pop(ctx, value);
                  },
                  child: Text(l10n.saveChanges),
                ),
              ],
            ),
          );
        },
      );

      if (newPrefix == null) return;
      try {
        await ref
            .read(organizationRepositoryProvider)
            .updateCodePrefix(org.id, newPrefix);
        ref.invalidate(currentOrganizationProvider);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(friendlyOrgError(e.toString().toLowerCase(), l10n)),
            ),
          );
        }
      }
    }

    return Card(
      child: ListTile(
        leading: const Icon(Icons.tag),
        title: Text(l10n.campCodePrefix),
        subtitle: Text('${org.effectiveCodePrefix}-XXXX'),
        trailing: IconButton(
          icon: const Icon(Icons.edit_outlined),
          onPressed: edit,
        ),
      ),
    );
  }
}

class _LogoCard extends ConsumerStatefulWidget {
  const _LogoCard({required this.org});

  final Organization org;

  @override
  ConsumerState<_LogoCard> createState() => _LogoCardState();
}

class _LogoCardState extends ConsumerState<_LogoCard> {
  bool _busy = false;

  Future<void> _pickAndUpload() async {
    final l10n = AppL10n.of(context);
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );
    if (picked == null) return;

    setState(() => _busy = true);
    try {
      final url = await ref.read(imageUploadServiceProvider).uploadImage(
            imageFile: picked,
            storagePath: 'organizations/${widget.org.id}/logo.jpg',
          );
      await ref
          .read(organizationRepositoryProvider)
          .updateLogoUrl(widget.org.id, url);
      ref.invalidate(currentOrganizationProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(friendlyOrgError(e.toString().toLowerCase(), l10n)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove() async {
    final l10n = AppL10n.of(context);
    final url = widget.org.logoUrl;
    setState(() => _busy = true);
    try {
      if (url != null && url.isNotEmpty) {
        await ref.read(imageUploadServiceProvider).deleteImage(url);
      }
      await ref
          .read(organizationRepositoryProvider)
          .updateLogoUrl(widget.org.id, '');
      ref.invalidate(currentOrganizationProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(friendlyOrgError(e.toString().toLowerCase(), l10n)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final theme = Theme.of(context);
    final hasLogo =
        widget.org.logoUrl != null && widget.org.logoUrl!.isNotEmpty;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              clipBehavior: Clip.antiAlias,
              child: _busy
                  ? const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : hasLogo
                      ? CachedNetworkImage(
                          imageUrl: widget.org.logoUrl!,
                          fit: BoxFit.cover,
                          errorWidget: (_, _, _) =>
                              const Icon(Icons.image_not_supported_outlined),
                        )
                      : Icon(
                          Icons.image_outlined,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.campLogo, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(
                    l10n.campLogoHint,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Wrap (not Row) so the two actions flow onto a second line
                  // on narrow screens / long locale labels instead of
                  // overflowing to the right.
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      TextButton.icon(
                        onPressed: _busy ? null : _pickAndUpload,
                        icon: const Icon(Icons.upload_outlined, size: 18),
                        label: Text(hasLogo ? l10n.changeLogo : l10n.addLogo),
                      ),
                      if (hasLogo)
                        TextButton.icon(
                          onPressed: _busy ? null : _remove,
                          icon: Icon(
                            Icons.delete_outline,
                            size: 18,
                            color: theme.colorScheme.error,
                          ),
                          label: Text(
                            l10n.removeLogo,
                            style: TextStyle(color: theme.colorScheme.error),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MemberTile extends ConsumerWidget {
  const _MemberTile({
    required this.member,
    required this.isOwnerRow,
    required this.canRemove,
  });

  final OrgMember member;
  final bool isOwnerRow;
  final bool canRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppL10n.of(context);
    final theme = Theme.of(context);

    Future<void> remove() async {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.removeGuide),
          content: Text(l10n.removeGuideConfirm(member.displayName)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.error,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.removeGuide),
            ),
          ],
        ),
      );
      if (confirmed != true) return;

      try {
        await ref.read(organizationRepositoryProvider).removeMember(member.uid);
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(l10n.memberRemoved)));
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(friendlyOrgError(e.toString().toLowerCase(), l10n)),
            ),
          );
        }
      }
    }

    return ListTile(
      leading: Icon(
        isOwnerRow ? Icons.workspace_premium_outlined : Icons.person_outline,
      ),
      title: Text(member.displayName),
      subtitle: Text(
        [
          isOwnerRow ? l10n.ownerRole : l10n.guideRole,
          if (member.joinedAt != null)
            DateFormat.yMd(
              Localizations.localeOf(context).toString(),
            ).format(member.joinedAt!),
        ].join(' · '),
      ),
      trailing: canRemove
          ? IconButton(
              icon: const Icon(Icons.person_remove_outlined),
              tooltip: l10n.removeGuide,
              onPressed: remove,
            )
          : null,
    );
  }
}
