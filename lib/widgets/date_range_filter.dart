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
          // ✅ الأيقونة الرئيسية واضحة تماماً
          Icon(
            Icons.date_range,
            color: widget.color,
            size: 24,
          ),
          // ✅ نقطة التنبيه إذا كان الفلتر نشطاً
          if (_isActive)
            Positioned(
              top: -4,
              right: -4,
              child: Container(
                width: 12,
                height: 12,
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
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: color)), // Increased by 50%
          const SizedBox(height: 3), // Increased by 50%
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12), // Increased
              border: Border.all(
                  color: Colors.grey[300]!, width: 1.5), // Thicker border
            ),
            child: Column(
              children: [
                SizedBox(
                  height: 42, // Increased from 28
                  width: 42, // Increased from 28
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    icon: Icon(Icons.arrow_drop_up,
                        size: 33,
                        color: Colors.green[600]), // Increased from 22
                    onPressed: onUp,
                  ),
                ),
                SizedBox(
                  height: 39, // Increased from 26
                  child: Center(
                    child: Text(display,
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold)), // Increased from 12
                  ),
                ),
                SizedBox(
                  height: 42, // Increased from 28
                  width: 42, // Increased from 28
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    icon: Icon(Icons.arrow_drop_down,
                        size: 33, color: Colors.red[600]), // Increased from 22
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
              Icon(Icons.calendar_today,
                  size: 19.5, color: color), // Increased from 13
              const SizedBox(width: 6), // Increased from 4
              Text(sectionLabel,
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: color)), // Increased from 12
              const SizedBox(width: 12), // Increased from 8
              Text(
                '${date.year}/${date.month}/${date.day}',
                style: TextStyle(
                    fontSize: 18,
                    color: color,
                    fontWeight: FontWeight.bold), // Increased from 12
              ),
            ],
          ),
          const SizedBox(height: 9), // Increased from 6
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
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24)), // Increased from 16
        titlePadding:
            const EdgeInsets.fromLTRB(24, 24, 24, 12), // Increased by 50%
        contentPadding:
            const EdgeInsets.fromLTRB(24, 0, 24, 12), // Increased by 50%
        title: Row(
          children: [
            Icon(Icons.date_range,
                color: Colors.black, size: 27), // Increased from 18
            const SizedBox(width: 12), // Increased from 8
            const Text('فلترة بالتاريخ',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 22.5)), // Increased from 15
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
                    color: Colors.black,
                    onChanged: (d) => setState(() => tempFrom = d),
                  ),
                ),
                const SizedBox(width: 24), // Increased from 16
                Expanded(
                  child: datePicker(
                    sectionLabel: 'إلى تاريخ',
                    date: tempTo,
                    color: Colors.black,
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
            style: TextButton.styleFrom(
              textStyle: const TextStyle(fontSize: 16.5), // Increased
            ),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () {
              widget.onClear();
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(
              textStyle: const TextStyle(fontSize: 16.5), // Increased
            ),
            child:
                const Text('مسح الفلتر', style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.color,
              textStyle: const TextStyle(fontSize: 16.5), // Increased
              padding: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 12), // Larger padding
            ),
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
            child: const Text('تطبيق',
                style: TextStyle(color: Color.fromARGB(255, 231, 9, 9))),
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
      padding: const EdgeInsets.only(bottom: 12), // Increased from 8
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 18, vertical: 9), // Increased from 12,6
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          border: Border.all(color: color, width: 1.5), // Thicker border
          borderRadius: BorderRadius.circular(12), // Increased from 8
        ),
        child: Row(
          children: [
            Icon(Icons.filter_alt, color: color, size: 24), // Increased from 16
            const SizedBox(width: 9), // Increased from 6
            Expanded(
              child: Text(
                'الفلتر: '
                '${from != null ? '${from!.year}/${from!.month}/${from!.day}' : '—'}'
                ' ← '
                '${to != null ? '${to!.year}/${to!.month}/${to!.day}' : '—'}',
                style: TextStyle(
                    color: Colors.black, fontSize: 18), // Increased from 12
              ),
            ),
            GestureDetector(
              onTap: onClear,
              child: Icon(Icons.close,
                  color: color, size: 24), // Increased from 16
            ),
          ],
        ),
      ),
    );
  }
}
