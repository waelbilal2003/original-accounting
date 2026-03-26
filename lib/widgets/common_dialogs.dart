// widgets/common_dialogs.dart
import 'package:flutter/material.dart';

// نافذة اختيار طريقة الدفع
void showCashOrDebtDialog({
  required BuildContext context,
  required String currentValue,
  required List<String> options,
  required ValueChanged<String> onSelected,
  required VoidCallback onCancel,
}) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text('اختر طريقة الدفع'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: options.map((option) {
              return ListTile(
                title: Text(option),
                leading: Radio<String>(
                  value: option,
                  groupValue: currentValue,
                  onChanged: (String? value) {
                    if (value != null) {
                      onSelected(value);
                      Navigator.of(context).pop();
                    }
                  },
                ),
                onTap: () {
                  onSelected(option);
                  Navigator.of(context).pop();
                },
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              onCancel();
              Navigator.of(context).pop();
            },
            child: const Text('إلغاء'),
          ),
        ],
      );
    },
  );
}

// أضف هذه الدالة في ملف common_dialogs.dart
Future<void> showAccountTypeDialog({
  required BuildContext context,
  required String currentValue,
  required List<String> options,
  required Function(String) onSelected,
  required Function() onCancel,
}) {
  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text(
          'اختر نوع الحساب',
          style: TextStyle(fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: options.map((option) {
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  title: Text(
                    option,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: option == currentValue
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color:
                          option == currentValue ? Colors.blue : Colors.black,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    onSelected(option);
                  },
                ),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onCancel();
            },
            child: const Text('إلغاء'),
          ),
        ],
      );
    },
  );
}

// نافذة اختيار الفوارغ
void showEmptiesDialog({
  required BuildContext context,
  required String currentValue,
  required List<String> options,
  required ValueChanged<String> onSelected,
  required VoidCallback onCancel,
}) {
  String tempValue = currentValue;
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('اختر حالة الفوارغ'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: options.map((option) {
                  return ListTile(
                    title: Text(option),
                    leading: Radio<String>(
                      value: option,
                      groupValue: tempValue,
                      onChanged: (String? value) {
                        if (value != null) {
                          setState(() => tempValue = value);
                          onSelected(value);
                          Future.delayed(const Duration(milliseconds: 200), () {
                            if (context.mounted) Navigator.of(context).pop();
                          });
                        }
                      },
                    ),
                    onTap: () {
                      setState(() => tempValue = option);
                      onSelected(option);
                      Future.delayed(const Duration(milliseconds: 200), () {
                        if (context.mounted) Navigator.of(context).pop();
                      });
                    },
                  );
                }).toList(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  onCancel();
                  Navigator.of(context).pop();
                },
                child: const Text('إلغاء'),
              ),
            ],
          );
        },
      );
    },
  );
}

// نافذة مشاركة الملف
void showFilePathDialog({
  required BuildContext context,
  required String filePath,
}) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('مسار الملف'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('يمكنك نسخ المسار أدناه:'),
          const SizedBox(height: 8),
          SelectableText(
            filePath,
            style: const TextStyle(fontSize: 12, color: Colors.blue),
          ),
          const SizedBox(height: 16),
          const Text(
            'يمكنك نقل الملف إلى الحاسوب عبر USB أو البلوتوث',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('موافق'),
        ),
      ],
    ),
  );
}

// نافذة تأكيد الحذف
Future<bool?> showDeleteConfirmationDialog({
  required BuildContext context,
  required String recordNumber,
}) {
  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('تأكيد الحذف'),
      content: Text('هل تريد حذف السجل رقم $recordNumber؟'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('إلغاء'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('حذف', style: TextStyle(color: Colors.red)),
        ),
      ],
    ),
  );
}
