import 'package:flutter/material.dart';

import '../../../core/utils/archive_sort.dart';
import '../../../core/utils/file_classifier.dart';
import '../../../core/utils/formatters.dart';
import '../../../providers/settings_provider.dart';

class ArchiveFilterBar extends StatelessWidget {
  const ArchiveFilterBar({super.key, required this.type, required this.sort,
    required this.layout, required this.onType, required this.onSort,
    required this.onToggleLayout, this.enabled = true});

  final MediaFileType? type;
  final ArchiveSort sort;
  final ArchiveLayout layout;
  final ValueChanged<MediaFileType?> onType;
  final ValueChanged<ArchiveSort> onSort;
  final VoidCallback onToggleLayout;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(children: [
      SizedBox(
        height: 48,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 4),
          children: [
            for (final value in <MediaFileType?>[null, ...MediaFileType.values])
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 7),
                child: FilterChip(
                  selected: value == type,
                  showCheckmark: false,
                  avatar: Icon(Formatters.typeIcon(value), size: 17,
                    color: value == type ? scheme.onSecondaryContainer
                      : scheme.onSurfaceVariant),
                  label: Text(value == null ? 'همه' :
                    Formatters.typeLabel(value, plural: true)),
                  onSelected: enabled ? (_) => onType(value) : null,
                ),
              ),
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 4),
        child: Row(children: [
          Expanded(child: Text('فایل‌های آرشیو',
            style: Theme.of(context).textTheme.titleSmall)),
          PopupMenuButton<ArchiveSort>(
            tooltip: 'مرتب‌سازی',
            enabled: enabled,
            initialValue: sort,
            onSelected: onSort,
            itemBuilder: (_) => [
              for (final value in ArchiveSort.values)
                PopupMenuItem(value: value, child: Row(children: [
                  Icon(value == sort ? Icons.check_circle_rounded :
                    Icons.circle_outlined, size: 18),
                  const SizedBox(width: 8), Text(value.label),
                ])),
            ],
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.sort_rounded, size: 19),
                const SizedBox(width: 4),
                Text(sort.label, style: Theme.of(context).textTheme.labelMedium),
              ]),
            ),
          ),
          IconButton(
            tooltip: layout == ArchiveLayout.list ? 'نمای شبکه‌ای' : 'نمای لیستی',
            onPressed: enabled ? onToggleLayout : null,
            icon: Icon(layout == ArchiveLayout.list
              ? Icons.grid_view_rounded : Icons.view_agenda_outlined),
          ),
        ]),
      ),
    ]);
  }
}
