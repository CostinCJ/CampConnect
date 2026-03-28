import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:camp_connect/core/l10n/app_localizations.dart';
import 'package:camp_connect/features/announcements/domain/announcement.dart';
import 'package:camp_connect/shared/providers/providers.dart';

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
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
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
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (_tabController.index == 0) {
            _showAnnouncementForm(context);
          } else {
            _showScheduleForm(context);
          }
        },
        child: const Icon(Icons.add),
      ),
      body: announcementsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(l10n.somethingWentWrong)),
        data: (all) {
          final announcements =
              all.where((a) => !a.isSchedule).toList();
          final scheduleItems =
              all.where((a) => a.isSchedule).toList();

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

// =============================================================================
// ANNOUNCEMENTS TAB
// =============================================================================

class _AnnouncementList extends ConsumerWidget {
  final List<Announcement> announcements;

  const _AnnouncementList({required this.announcements});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    if (announcements.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.campaign_outlined,
                size: 64, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(l10n.noAnnouncementsYet,
                style: theme.textTheme.titleMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
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
      BuildContext context, WidgetRef ref, Announcement announcement) {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteAnnouncement),
        content: Text(l10n.deleteAnnouncementConfirm),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(l10n.cancel)),
          FilledButton(
            onPressed: () {
              final campId = ref.read(activeCampIdProvider);
              if (campId != null) {
                ref
                    .read(announcementsRepositoryProvider)
                    .deleteAnnouncement(campId, announcement.id);
              }
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text(l10n.announcementDeleted)));
            },
            style:
                FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
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
    final l10n = AppLocalizations.of(context);

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
                    Icon(Icons.push_pin,
                        size: 16, color: theme.colorScheme.primary),
                    const SizedBox(width: 4),
                    Text(l10n.pinned,
                        style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w600)),
                  ],
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    onPressed: onEdit,
                    visualDensity: VisualDensity.compact,
                  ),
                  IconButton(
                    icon: Icon(Icons.delete_outline,
                        size: 20, color: theme.colorScheme.error),
                    onPressed: onDelete,
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(announcement.title,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(announcement.body,
                  style: theme.textTheme.bodyMedium,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 8),
              Text(l10n.relativeTime(announcement.timestamp),
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// ANNOUNCEMENT FORM (announcements only — no type selector)
// =============================================================================

class _AnnouncementFormSheet extends ConsumerStatefulWidget {
  final Announcement? existing;
  const _AnnouncementFormSheet({this.existing});

  @override
  ConsumerState<_AnnouncementFormSheet> createState() =>
      _AnnouncementFormSheetState();
}

class _AnnouncementFormSheetState extends ConsumerState<_AnnouncementFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleCtrl;
  late TextEditingController _bodyCtrl;
  bool _pinned = false;
  bool _isLoading = false;

  bool get isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.existing?.title ?? '');
    _bodyCtrl = TextEditingController(text: widget.existing?.body ?? '');
    _pinned = widget.existing?.pinned ?? false;
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
    final l10n = AppLocalizations.of(context);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20, right: 20, top: 20,
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
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                isEditing ? l10n.editAnnouncement : l10n.newAnnouncement,
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _titleCtrl,
                decoration: InputDecoration(
                  labelText: l10n.announcementTitle,
                  border: const OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? l10n.enterTitle : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _bodyCtrl,
                decoration: InputDecoration(
                  labelText: l10n.announcementBody,
                  border: const OutlineInputBorder(),
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
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _isLoading ? null : _submit,
                child: _isLoading
                    ? const SizedBox(
                        height: 20, width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(isEditing ? l10n.editAnnouncement : l10n.newAnnouncement),
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

    try {
      final campId = ref.read(activeCampIdProvider);
      if (campId == null) return;
      final repo = ref.read(announcementsRepositoryProvider);
      final user = ref.read(appUserProvider).valueOrNull;
      final l10n = AppLocalizations.of(context);

      if (isEditing) {
        final updated = widget.existing!.copyWith(
          title: _titleCtrl.text.trim(),
          body: _bodyCtrl.text.trim(),
          type: 'announcement',
          pinned: _pinned,
        );
        await repo.updateAnnouncement(campId, updated);
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(l10n.announcementUpdated)));
        }
      } else {
        final announcement = Announcement(
          id: '',
          title: _titleCtrl.text.trim(),
          body: _bodyCtrl.text.trim(),
          type: 'announcement',
          pinned: _pinned,
          createdBy: user?.uid ?? '',
          createdByName: user?.displayName ?? '',
          timestamp: DateTime.now(),
        );
        await repo.createAnnouncement(campId, announcement);
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(l10n.announcementCreated)));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context).somethingWentWrong)));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}

// =============================================================================
// SCHEDULE / PROGRAM TAB
// =============================================================================

class _ScheduleBuilder extends ConsumerWidget {
  final List<Announcement> scheduleItems;

  const _ScheduleBuilder({required this.scheduleItems});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    if (scheduleItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.calendar_month_outlined,
                size: 64, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(l10n.noScheduleEntries,
                style: theme.textTheme.titleMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
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
    final dateFormat = DateFormat('EEEE, d MMMM yyyy');

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
            ...entries.map((item) => _ScheduleEntryCard(
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
                )),
          ],
        );
      },
    );
  }

  void _confirmDelete(
      BuildContext context, WidgetRef ref, Announcement entry) {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteAnnouncement),
        content: Text(l10n.deleteAnnouncementConfirm),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(l10n.cancel)),
          FilledButton(
            onPressed: () {
              final campId = ref.read(activeCampIdProvider);
              if (campId != null) {
                ref
                    .read(announcementsRepositoryProvider)
                    .deleteAnnouncement(campId, entry.id);
              }
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text(l10n.scheduleEntryDeleted)));
            },
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
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
                      Text('|',
                          style: TextStyle(
                              color: theme.colorScheme.onTertiaryContainer
                                  .withValues(alpha: 0.4))),
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
                    Text(entry.title,
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w600)),
                    if (entry.body.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(entry.body,
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                    ],
                  ],
                ),
              ),

              // Actions
              IconButton(
                icon: Icon(Icons.delete_outline,
                    size: 20, color: theme.colorScheme.error),
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

// =============================================================================
// SCHEDULE FORM (date + start time + end time + title + description)
// =============================================================================

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
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  String _formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final dateFormat = DateFormat('dd/MM/yyyy');

    // Get camp session dates for date range constraint
    final campSession = ref.watch(activeCampSessionProvider).valueOrNull;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20, right: 20, top: 20,
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
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                isEditing ? l10n.editScheduleEntry : l10n.newScheduleEntry,
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),

              // Date picker
              InkWell(
                onTap: () async {
                  final firstDate = campSession?.startDate ?? DateTime.now();
                  final lastDate = campSession?.endDate ??
                      DateTime.now().add(const Duration(days: 365));
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate ?? firstDate,
                    firstDate: firstDate,
                    lastDate: lastDate,
                  );
                  if (picked != null) setState(() => _selectedDate = picked);
                },
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: l10n.selectDate,
                    border: const OutlineInputBorder(),
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
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: _startTime ?? const TimeOfDay(hour: 9, minute: 0),
                        );
                        if (picked != null) setState(() => _startTime = picked);
                      },
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: l10n.startTimeLabel,
                          border: const OutlineInputBorder(),
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
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: _endTime ?? const TimeOfDay(hour: 10, minute: 0),
                        );
                        if (picked != null) setState(() => _endTime = picked);
                      },
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: l10n.endTimeLabel,
                          border: const OutlineInputBorder(),
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
                  border: const OutlineInputBorder(),
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
                  border: const OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 20),

              FilledButton(
                onPressed: _isLoading ? null : _submit,
                child: _isLoading
                    ? const SizedBox(
                        height: 20, width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(isEditing ? l10n.editScheduleEntry : l10n.newScheduleEntry),
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

    final l10n = AppLocalizations.of(context);

    if (_selectedDate == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.selectDateRequired)));
      return;
    }
    if (_startTime == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.selectTimeRequired)));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final campId = ref.read(activeCampIdProvider);
      if (campId == null) return;
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
        );
        await repo.updateAnnouncement(campId, updated);
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(l10n.scheduleEntryUpdated)));
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
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(l10n.scheduleEntryCreated)));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context).somethingWentWrong)));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
