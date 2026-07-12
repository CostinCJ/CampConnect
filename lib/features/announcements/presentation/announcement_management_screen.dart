import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:camp_connect/l10n/app_localizations.g.dart';
import 'package:camp_connect/core/utils/relative_time.dart';
import 'package:camp_connect/features/announcements/domain/announcement.dart';
import 'package:camp_connect/features/announcements/domain/announcement_template.dart';
import 'package:camp_connect/shared/providers/providers.dart';
import 'package:camp_connect/shared/widgets/camp_ui.dart';

/// Guide view: Tab 1 = announcements only, Tab 2 = schedule/program builder.
class AnnouncementManagementScreen extends ConsumerStatefulWidget {
  const AnnouncementManagementScreen({super.key});

  @override
  ConsumerState<AnnouncementManagementScreen> createState() =>
      _AnnouncementManagementScreenState();
}

class _AnnouncementManagementScreenState
    extends ConsumerState<AnnouncementManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() => setState(() {}));
    // Make sure the org has its starter templates so the "Use a template"
    // picker is never empty, even if the manager was never opened.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final orgId = ref.read(appUserProvider).valueOrNull?.orgId;
      if (orgId != null) {
        ref
            .read(announcementTemplatesRepositoryProvider)
            .seedDefaultsIfEmpty(orgId)
            .ignore();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final campId = ref.watch(activeCampIdProvider);
    final announcementsAsync = ref.watch(announcementsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.announcementManagement),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: l10n.announcements),
            Tab(text: l10n.program),
          ],
        ),
      ),
      floatingActionButton: campId == null
          ? null
          : FloatingActionButton(
              onPressed: () {
                if (_tabController.index == 0) {
                  _showAnnouncementForm(context);
                } else {
                  _showScheduleForm(context);
                }
              },
              child: const Icon(Icons.add),
            ),
      body: campId == null
          ? _NoActiveSessionView(
              onCreatePressed: () => context.push('/guide/camp-sessions'),
            )
          : announcementsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text(l10n.somethingWentWrong)),
              data: (all) {
                final announcements = all.where((a) => !a.isSchedule).toList();
                final scheduleItems = all.where((a) => a.isSchedule).toList();

                return TabBarView(
                  controller: _tabController,
                  children: [
                    _AnnouncementList(announcements: announcements),
                    _ScheduleBuilder(scheduleItems: scheduleItems),
                  ],
                );
              },
            ),
    );
  }

  void _showAnnouncementForm(BuildContext context, {Announcement? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _AnnouncementFormSheet(existing: existing),
    );
  }

  void _showScheduleForm(BuildContext context, {Announcement? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _ScheduleFormSheet(existing: existing),
    );
  }
}

// NO ACTIVE CAMP SESSION (prevents publishing into the void)

class _NoActiveSessionView extends StatelessWidget {
  final VoidCallback onCreatePressed;

  const _NoActiveSessionView({required this.onCreatePressed});

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return EmptyState(
      icon: Icons.event_busy,
      title: l10n.noActiveSession,
      message: l10n.createSessionPrompt,
      action: FilledButton.icon(
        onPressed: onCreatePressed,
        icon: const Icon(Icons.add),
        label: Text(l10n.createSession),
      ),
    );
  }
}

// ANNOUNCEMENTS TAB

class _AnnouncementList extends ConsumerWidget {
  final List<Announcement> announcements;

  const _AnnouncementList({required this.announcements});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppL10n.of(context);

    if (announcements.isEmpty) {
      return EmptyState(
        icon: Icons.campaign_outlined,
        title: l10n.noAnnouncementsYet,
        action: FilledButton.tonalIcon(
          onPressed: () => showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
            builder: (_) =>
                const _AnnouncementFormSheet(startWithTemplatePicker: true),
          ),
          icon: const Icon(Icons.library_books_outlined),
          label: Text(l10n.useTemplate),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      itemCount: announcements.length,
      itemBuilder: (context, index) {
        final a = announcements[index];
        return _AnnouncementCard(
          announcement: a,
          onEdit: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              useSafeArea: true,
              builder: (ctx) => _AnnouncementFormSheet(existing: a),
            );
          },
          onDelete: () => _confirmDelete(context, ref, a),
        );
      },
    );
  }

  void _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Announcement announcement,
  ) {
    final l10n = AppL10n.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteAnnouncement),
        content: Text(l10n.deleteAnnouncementConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              final campId = ref.read(activeCampIdProvider);
              if (campId != null) {
                ref
                    .read(announcementsRepositoryProvider)
                    .deleteAnnouncement(campId, announcement.id);
              }
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(l10n.announcementDeleted)));
            },
            style: destructiveFilledStyle(Theme.of(context)),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
  }
}

class _AnnouncementCard extends StatelessWidget {
  final Announcement announcement;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _AnnouncementCard({
    required this.announcement,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppL10n.of(context);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: announcement.pinned
              ? theme.colorScheme.primary.withValues(alpha: 0.5)
              : theme.colorScheme.outlineVariant,
          width: announcement.pinned ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (announcement.pinned) ...[
                    Icon(
                      Icons.push_pin,
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      l10n.pinned,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (announcement.isPrompt) ...[
                    Icon(Icons.lightbulb_outline,
                        size: 16, color: theme.colorScheme.tertiary),
                    const SizedBox(width: 4),
                    Text(
                      l10n.questionOfTheDay,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.tertiary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    onPressed: onEdit,
                    visualDensity: VisualDensity.compact,
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.delete_outline,
                      size: 20,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    onPressed: onDelete,
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                announcement.title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                announcement.body,
                style: theme.textTheme.bodyMedium,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Text(
                relativeTime(l10n, announcement.timestamp),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ANNOUNCEMENT FORM (announcements only — no type selector)

class _AnnouncementFormSheet extends ConsumerStatefulWidget {
  final Announcement? existing;

  /// When true (used from the empty-state shortcut) the template picker opens
  /// automatically so an unsure guide can start from a prewritten message.
  final bool startWithTemplatePicker;

  const _AnnouncementFormSheet({
    this.existing,
    this.startWithTemplatePicker = false,
  });

  @override
  ConsumerState<_AnnouncementFormSheet> createState() =>
      _AnnouncementFormSheetState();
}

class _AnnouncementFormSheetState
    extends ConsumerState<_AnnouncementFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleCtrl;
  late TextEditingController _bodyCtrl;
  bool _pinned = false;
  bool _isPrompt = false;
  bool _isLoading = false;

  bool get isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.existing?.title ?? '');
    _bodyCtrl = TextEditingController(text: widget.existing?.body ?? '');
    _pinned = widget.existing?.pinned ?? false;
    _isPrompt = widget.existing?.isPrompt ?? false;
    if (widget.startWithTemplatePicker) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _pickTemplate());
    }
  }

  Future<void> _pickTemplate() async {
    final selected = await showModalBottomSheet<AnnouncementTemplate>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const _TemplatePickerSheet(),
    );
    if (selected == null || !mounted) return;
    final lang = ref.read(settingsProvider).language;
    setState(() {
      _titleCtrl.text = selected.titleFor(lang);
      _bodyCtrl.text = selected.bodyFor(lang);
    });
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppL10n.of(context);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20,
        right: 20,
        top: 20,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurfaceVariant.withValues(
                      alpha: 0.3,
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                isEditing ? l10n.editAnnouncement : l10n.newAnnouncement,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: _pickTemplate,
                  icon: const Icon(Icons.library_books_outlined, size: 18),
                  label: Text(l10n.useTemplate),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _titleCtrl,
                decoration: InputDecoration(
                  labelText: l10n.announcementTitle,
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? l10n.enterTitle : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _bodyCtrl,
                decoration: InputDecoration(
                  labelText: l10n.announcementBody,
                  alignLabelWithHint: true,
                ),
                maxLines: 4,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? l10n.enterBody : null,
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                title: Text(l10n.pinnedAnnouncement),
                secondary: const Icon(Icons.push_pin),
                value: _pinned,
                onChanged: (v) => setState(() => _pinned = v),
                contentPadding: EdgeInsets.zero,
              ),
              SwitchListTile(
                title: Text(l10n.questionOfTheDay),
                subtitle: Text(l10n.questionOfTheDayToggleSubtitle),
                secondary: const Icon(Icons.lightbulb_outline),
                value: _isPrompt,
                onChanged: (v) => setState(() => _isPrompt = v),
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _isLoading ? null : _submit,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        isEditing ? l10n.saveChanges : l10n.postAnnouncement,
                      ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final l10n = AppL10n.of(context);

    try {
      final campId = ref.read(activeCampIdProvider);
      if (campId == null) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(l10n.noActiveSession)));
        }
        return;
      }
      final repo = ref.read(announcementsRepositoryProvider);
      final user = ref.read(appUserProvider).valueOrNull;

      if (isEditing) {
        final updated = widget.existing!.copyWith(
          title: _titleCtrl.text.trim(),
          body: _bodyCtrl.text.trim(),
          type: _isPrompt ? 'prompt' : 'announcement',
          pinned: _pinned,
        );
        await repo.updateAnnouncement(campId, updated);
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(l10n.announcementUpdated)));
        }
      } else {
        final announcement = Announcement(
          id: '',
          title: _titleCtrl.text.trim(),
          body: _bodyCtrl.text.trim(),
          type: _isPrompt ? 'prompt' : 'announcement',
          pinned: _pinned,
          createdBy: user?.uid ?? '',
          createdByName: user?.displayName ?? '',
          timestamp: DateTime.now(),
        );
        await repo.createAnnouncement(campId, announcement);
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(l10n.announcementCreated)));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppL10n.of(context).somethingWentWrong),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}

// TEMPLATE PICKER (fills the announcement form from a saved template)

class _TemplatePickerSheet extends ConsumerWidget {
  const _TemplatePickerSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppL10n.of(context);
    final theme = Theme.of(context);
    final lang = ref.watch(settingsProvider).language;
    final templatesAsync = ref.watch(announcementTemplatesProvider);

    return SafeArea(
      child: templatesAsync.when(
        loading: () => const SizedBox(
          height: 120,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (_, _) => Padding(
          padding: const EdgeInsets.all(24),
          child: Text(l10n.somethingWentWrong),
        ),
        data: (templates) {
          if (templates.isEmpty) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Text(l10n.noTemplatesYet),
            );
          }
          return ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  l10n.useTemplate,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              ...templates.map(
                (template) => ListTile(
                  leading: const Icon(Icons.campaign_outlined),
                  title: Text(template.titleFor(lang)),
                  subtitle: Text(
                    template.bodyFor(lang),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => Navigator.of(context).pop(template),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// SCHEDULE / PROGRAM TAB

class _ScheduleBuilder extends ConsumerWidget {
  final List<Announcement> scheduleItems;

  const _ScheduleBuilder({required this.scheduleItems});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppL10n.of(context);

    if (scheduleItems.isEmpty) {
      return EmptyState(
        icon: Icons.calendar_month_outlined,
        title: l10n.noScheduleEntries,
      );
    }

    // Group by scheduledDate, sorted ascending
    final grouped = <DateTime, List<Announcement>>{};
    for (final item in scheduleItems) {
      final date = item.scheduledDate ?? item.timestamp;
      final dayKey = DateTime(date.year, date.month, date.day);
      grouped.putIfAbsent(dayKey, () => []).add(item);
    }

    // Sort each day's entries by startTime
    for (final entries in grouped.values) {
      entries.sort((a, b) => (a.startTime ?? '').compareTo(b.startTime ?? ''));
    }

    final sortedDays = grouped.keys.toList()..sort();
    final dateFormat = DateFormat(
      'EEEE, d MMMM yyyy',
      Localizations.localeOf(context).toString(),
    );

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      itemCount: sortedDays.length,
      itemBuilder: (context, index) {
        final day = sortedDays[index];
        final entries = grouped[day]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Day header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              margin: EdgeInsets.only(bottom: 8, top: index == 0 ? 0 : 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                dateFormat.format(day),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ),

            // Timeline entries for this day
            ...entries.map(
              (item) => _ScheduleEntryCard(
                entry: item,
                onEdit: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    useSafeArea: true,
                    builder: (ctx) => _ScheduleFormSheet(existing: item),
                  );
                },
                onDelete: () => _confirmDelete(context, ref, item),
              ),
            ),
          ],
        );
      },
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, Announcement entry) {
    final l10n = AppL10n.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteAnnouncement),
        content: Text(l10n.deleteAnnouncementConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              final campId = ref.read(activeCampIdProvider);
              if (campId != null) {
                ref
                    .read(announcementsRepositoryProvider)
                    .deleteAnnouncement(campId, entry.id);
              }
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l10n.scheduleEntryDeleted)),
              );
            },
            style: destructiveFilledStyle(Theme.of(context)),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
  }
}

class _ScheduleEntryCard extends StatelessWidget {
  final Announcement entry;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ScheduleEntryCard({
    required this.entry,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Time column
              Container(
                width: 72,
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.tertiaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Text(
                      entry.startTime ?? '--:--',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onTertiaryContainer,
                      ),
                    ),
                    if (entry.endTime != null) ...[
                      Text(
                        '|',
                        style: TextStyle(
                          color: theme.colorScheme.onTertiaryContainer
                              .withValues(alpha: 0.4),
                        ),
                      ),
                      Text(
                        entry.endTime!,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onTertiaryContainer,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (entry.body.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        entry.body,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),

              // Actions
              IconButton(
                icon: Icon(
                  Icons.delete_outline,
                  size: 20,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                onPressed: onDelete,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// SCHEDULE FORM (date + start time + end time + title + description)

class _ScheduleFormSheet extends ConsumerStatefulWidget {
  final Announcement? existing;
  const _ScheduleFormSheet({this.existing});

  @override
  ConsumerState<_ScheduleFormSheet> createState() => _ScheduleFormSheetState();
}

class _ScheduleFormSheetState extends ConsumerState<_ScheduleFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleCtrl;
  late TextEditingController _descCtrl;
  DateTime? _selectedDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  bool _isLoading = false;

  bool get isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.existing?.title ?? '');
    _descCtrl = TextEditingController(text: widget.existing?.body ?? '');
    if (widget.existing != null) {
      _selectedDate = widget.existing!.scheduledDate;
      _startTime = _parseTime(widget.existing!.startTime);
      _endTime = _parseTime(widget.existing!.endTime);
    }
  }

  TimeOfDay? _parseTime(String? time) {
    if (time == null || !time.contains(':')) return null;
    final parts = time.split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }

  String _formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  /// Keyboard-first 24h picker: guides type 14:30 directly instead of
  /// dragging the clock dial (the dial stays one icon-tap away).
  Future<TimeOfDay?> _pickTime(TimeOfDay initial) {
    return showTimePicker(
      context: context,
      initialTime: initial,
      initialEntryMode: TimePickerEntryMode.input,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppL10n.of(context);
    final dateFormat = DateFormat(
      'dd/MM/yyyy',
      Localizations.localeOf(context).toString(),
    );

    // Get camp session dates for date range constraint
    final campSession = ref.watch(activeCampSessionProvider).valueOrNull;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20,
        right: 20,
        top: 20,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurfaceVariant.withValues(
                      alpha: 0.3,
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                isEditing ? l10n.editScheduleEntry : l10n.newScheduleEntry,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),

              // Date picker
              InkWell(
                onTap: () async {
                  final today = DateUtils.dateOnly(DateTime.now());
                  var firstDate = campSession?.startDate ?? today;
                  // A camp already in progress must not offer its past days.
                  if (firstDate.isBefore(today)) firstDate = today;
                  // Editing an old entry keeps its own (past) date reachable.
                  if (isEditing &&
                      _selectedDate != null &&
                      _selectedDate!.isBefore(firstDate)) {
                    firstDate = DateUtils.dateOnly(_selectedDate!);
                  }
                  final lastDate = campSession?.endDate ??
                      DateTime.now().add(const Duration(days: 365));
                  // A session that already ENDED leaves firstDate (clamped to
                  // today above) after lastDate (the session's end), which
                  // showDatePicker asserts on. Reopen the session's own range;
                  // the past-start check in _submit still blocks new entries.
                  if (lastDate.isBefore(firstDate)) {
                    firstDate = DateUtils.dateOnly(lastDate);
                  }
                  var initial = _selectedDate ?? today;
                  if (initial.isBefore(firstDate)) initial = firstDate;
                  if (initial.isAfter(lastDate)) initial = lastDate;
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: initial,
                    firstDate: firstDate,
                    lastDate: lastDate,
                  );
                  if (picked != null) setState(() => _selectedDate = picked);
                },
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: l10n.selectDate,
                    suffixIcon: const Icon(Icons.calendar_today),
                  ),
                  child: Text(
                    _selectedDate != null
                        ? dateFormat.format(_selectedDate!)
                        : '',
                    style: theme.textTheme.bodyLarge,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Time pickers row
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final picked = await _pickTime(
                            _startTime ?? const TimeOfDay(hour: 9, minute: 0));
                        if (picked != null) setState(() => _startTime = picked);
                      },
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: l10n.startTimeLabel,
                          suffixIcon: const Icon(Icons.access_time),
                        ),
                        child: Text(
                          _startTime != null ? _formatTime(_startTime!) : '',
                          style: theme.textTheme.bodyLarge,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final picked = await _pickTime(
                            _endTime ?? const TimeOfDay(hour: 10, minute: 0));
                        if (picked != null) setState(() => _endTime = picked);
                      },
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: l10n.endTimeLabel,
                          suffixIcon: const Icon(Icons.access_time),
                        ),
                        child: Text(
                          _endTime != null ? _formatTime(_endTime!) : '',
                          style: theme.textTheme.bodyLarge,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Activity name
              TextFormField(
                controller: _titleCtrl,
                decoration: InputDecoration(
                  labelText: l10n.activityName,
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? l10n.enterTitle : null,
              ),
              const SizedBox(height: 16),

              // Description (optional)
              TextFormField(
                controller: _descCtrl,
                decoration: InputDecoration(
                  labelText: l10n.activityDescription,
                  alignLabelWithHint: true,
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 20),

              FilledButton(
                onPressed: _isLoading ? null : _submit,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        isEditing
                            ? l10n.saveChanges
                            : l10n.addScheduleEntryAction,
                      ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final l10n = AppL10n.of(context);

    if (_selectedDate == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.selectDateRequired)));
      return;
    }
    if (_startTime == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.selectTimeRequired)));
      return;
    }
    final startDateTime = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _startTime!.hour,
      _startTime!.minute,
    );
    // Only NEW entries are blocked from starting in the past: editing
    // yesterday's activity (e.g. fixing a typo) must stay possible.
    if (!isEditing && startDateTime.isBefore(DateTime.now())) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.startTimeInPast)));
      return;
    }
    if (_endTime != null) {
      final startMinutes = _startTime!.hour * 60 + _startTime!.minute;
      final endMinutes = _endTime!.hour * 60 + _endTime!.minute;
      if (endMinutes <= startMinutes) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.endTimeBeforeStartTime)));
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      final campId = ref.read(activeCampIdProvider);
      if (campId == null) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(l10n.noActiveSession)));
        }
        return;
      }
      final repo = ref.read(announcementsRepositoryProvider);
      final user = ref.read(appUserProvider).valueOrNull;

      if (isEditing) {
        final updated = widget.existing!.copyWith(
          title: _titleCtrl.text.trim(),
          body: _descCtrl.text.trim(),
          type: 'schedule',
          scheduledDate: _selectedDate,
          startTime: _formatTime(_startTime!),
          endTime: _endTime != null ? _formatTime(_endTime!) : null,
          clearEndTime: _endTime == null,
        );
        await repo.updateAnnouncement(campId, updated);
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(l10n.scheduleEntryUpdated)));
        }
      } else {
        final entry = Announcement(
          id: '',
          title: _titleCtrl.text.trim(),
          body: _descCtrl.text.trim(),
          type: 'schedule',
          pinned: false,
          createdBy: user?.uid ?? '',
          createdByName: user?.displayName ?? '',
          timestamp: DateTime.now(),
          scheduledDate: _selectedDate,
          startTime: _formatTime(_startTime!),
          endTime: _endTime != null ? _formatTime(_endTime!) : null,
        );
        await repo.createAnnouncement(campId, entry);
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(l10n.scheduleEntryCreated)));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppL10n.of(context).somethingWentWrong),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
