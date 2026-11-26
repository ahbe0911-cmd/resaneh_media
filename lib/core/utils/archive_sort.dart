enum ArchiveSort {
  newest('جدیدترین', 'm.created_at DESC, m.id DESC'),
  oldest('قدیمی‌ترین', 'm.created_at ASC, m.id ASC'),
  largest('حجیم‌ترین', 'm.file_size DESC, m.created_at DESC, m.id DESC'),
  title('عنوان (الفبایی)', 'm.title COLLATE NOCASE ASC, m.id ASC');

  const ArchiveSort(this.label, this.sqlOrder);
  final String label;
  // Closed enum; no user-provided text is interpolated into SQL.
  final String sqlOrder;
}
