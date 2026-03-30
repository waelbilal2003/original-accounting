import 'package:flutter/material.dart';

class DateRangeFilterIcon extends StatefulWidget {
  final DateTime? from;
  final DateTime? to;
  final ValueChanged<DateTime?> onFromChanged;
  final ValueChanged<DateTime?> onToChanged;
  final VoidCallback onClear;
  final Color color;

  const DateRangeFilterIcon({
    Key? key,
    required this.from,
    required this.to,
    required this.onFromChanged,
    required this.onToChanged,
    required this.onClear,
    this.color = Colors.indigo,
  }) : super(key: key);

  @override
  _DateRangeFilterIconState createState() => _DateRangeFilterIconState();
}

class _DateRangeFilterIconState extends State<DateRangeFilterIcon> {
  bool get _isActive => widget.from != null || widget.to != null;

  void _showDialog() {
    showDialog(
      context: context,
      builder: (ctx) => _DateRangeDialog(
        initialFrom: widget.from,
        initialTo: widget.to,
        onApply: (from, to) {
          widget.onFromChanged(from);
          widget.onToChanged(to);
        },
        onClear: () {
          widget.onClear();
        },
        color: widget.color,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(Icons.date_range, color: widget.color),
          if (_isActive)
            Positioned(
              top: -4,
              left: -4,
              child: Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: Colors.orange,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
      tooltip: 'فلترة بالتاريخ',
      onPressed: _showDialog,
    );
  }
}

class _DateRangeDialog extends StatefulWidget {
  final DateTime? initialFrom;
  final DateTime? initialTo;
  final Function(DateTime? from, DateTime? to) onApply;
  final VoidCallback onClear;
  final Color color;

  const _DateRangeDialog({
    Key? key,
    this.initialFrom,
    this.initialTo,
    required this.onApply,
    required this.onClear,
    required this.color,
  }) : super(key: key);

  @override
  __DateRangeDialogState createState() => __DateRangeDialogState();
}

class __DateRangeDialogState extends State<_DateRangeDialog> {
  late DateTime tempFrom;
  late DateTime tempTo;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    tempFrom = widget.initialFrom ?? now;
    tempTo = widget.initialTo ?? now;
  }

  DateTime _clampDay(int y, int m, int d) {
    final max = DateUtils.getDaysInMonth(y, m);
    return DateTime(y, m, d > max ? max : d);
  }

  @override
  Widget build(BuildContext context) {
    const months = [
      'يناير',
      'فبراير',
      'مارس',
      'أبريل',
      'مايو',
      'يونيو',
      'يوليو',
      'أغسطس',
      'سبتمبر',
      'أكتوبر',
      'نوفمبر',
      'ديسمبر'
    ];

    Widget miniPicker({
      required String label,
      required String display,
      required VoidCallback onUp,
      required VoidCallback onDown,
      required Color color,
    }) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 10, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Column(
              children: [
                SizedBox(
                  height: 28,
                  width: 28,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    icon: Icon(Icons.arrow_drop_up,
                        size: 22, color: Colors.green[600]),
                    onPressed: onUp,
                  ),
                ),
                SizedBox(
                  height: 26,
                  child: Center(
                    child: Text(display,
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ),
                SizedBox(
                  height: 28,
                  width: 28,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    icon: Icon(Icons.arrow_drop_down,
                        size: 22, color: Colors.red[600]),
                    onPressed: onDown,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    Widget datePicker({
      required String sectionLabel,
      required DateTime date,
      required Color color,
      required void Function(DateTime) onChanged,
    }) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calendar_today, size: 13, color: color),
              const SizedBox(width: 4),
              Text(sectionLabel,
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.bold, color: color)),
              const SizedBox(width: 8),
              Text(
                '${date.year}/${date.month}/${date.day}',
                style: TextStyle(
                    fontSize: 12, color: color, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              miniPicker(
                label: 'اليوم',
                display: date.day.toString(),
                color: color,
                onUp: () =>
                    onChanged(_clampDay(date.year, date.month, date.day + 1)),
                onDown: () =>
                    onChanged(_clampDay(date.year, date.month, date.day - 1)),
              ),
              miniPicker(
                label: 'الشهر',
                display: months[date.month - 1],
                color: color,
                onUp: () {
                  final m = date.month < 12 ? date.month + 1 : 1;
                  onChanged(_clampDay(date.year, m, date.day));
                },
                onDown: () {
                  final m = date.month > 1 ? date.month - 1 : 12;
                  onChanged(_clampDay(date.year, m, date.day));
                },
              ),
              miniPicker(
                label: 'السنة',
                display: date.year.toString(),
                color: color,
                onUp: () =>
                    onChanged(_clampDay(date.year + 1, date.month, date.day)),
                onDown: () =>
                    onChanged(_clampDay(date.year - 1, date.month, date.day)),
              ),
            ],
          ),
        ],
      );
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titlePadding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        contentPadding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        title: Row(
          children: [
            Icon(Icons.date_range, color: widget.color),
            const SizedBox(width: 8),
            const Text('فلترة بالتاريخ',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: datePicker(
                    sectionLabel: 'من تاريخ',
                    date: tempFrom,
                    color: widget.color,
                    onChanged: (d) => setState(() => tempFrom = d),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: datePicker(
                    sectionLabel: 'إلى تاريخ',
                    date: tempTo,
                    color: widget.color,
                    onChanged: (d) => setState(() => tempTo = d),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () {
              widget.onClear();
              Navigator.pop(context);
            },
            child:
                const Text('مسح الفلتر', style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: widget.color),
            onPressed: () {
              if (tempFrom.isAfter(tempTo)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('تاريخ البداية يجب أن يكون قبل النهاية'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              widget.onApply(tempFrom, tempTo);
              Navigator.pop(context);
            },
            child: const Text('تطبيق', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class FilterChipWidget extends StatelessWidget {
  final DateTime? from;
  final DateTime? to;
  final VoidCallback onClear;
  final Color color;

  const FilterChipWidget({
    Key? key,
    required this.from,
    required this.to,
    required this.onClear,
    required this.color,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (from == null && to == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          border: Border.all(color: color),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.filter_alt, color: color, size: 16),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'الفلتر: '
                '${from != null ? '${from!.year}/${from!.month}/${from!.day}' : '—'}'
                ' ← '
                '${to != null ? '${to!.year}/${to!.month}/${to!.day}' : '—'}',
                style: TextStyle(color: color, fontSize: 12),
              ),
            ),
            GestureDetector(
              onTap: onClear,
              child: Icon(Icons.close, color: color, size: 16),
            ),
          ],
        ),
      ),
    );
  }
}
