// widgets/base_screen.dart
import 'package:flutter/material.dart';
import 'table_components.dart';

abstract class BaseTableScreen extends StatefulWidget {
  final String sellerName;
  final String selectedDate;
  final String storeName;
  final String screenType; // 'purchases' أو 'sales'

  const BaseTableScreen({
    Key? key,
    required this.sellerName,
    required this.selectedDate,
    required this.storeName,
    required this.screenType,
  }) : super(key: key);

  @override
  BaseTableScreenState createState();
}

abstract class BaseTableScreenState<T extends BaseTableScreen>
    extends State<T> {
  // قوائم الخيارات المشتركة
  final List<String> cashOrDebtOptions = ['نقدي', 'دين'];
  final List<String> emptiesOptions = ['مع فوارغ', 'بدون فوارغ'];

  // متحكمات للتمرير
  final ScrollController _verticalScrollController = ScrollController();
  final ScrollController _horizontalScrollController = ScrollController();

  ScrollController get verticalScrollController => _verticalScrollController;
  ScrollController get horizontalScrollController =>
      _horizontalScrollController;

  // حالة الحفظ
  bool _isSaving = false;
  bool _hasUnsavedChanges = false;

  bool get isSaving => _isSaving;
  bool get hasUnsavedChanges => _hasUnsavedChanges;

  set isSaving(bool value) => setState(() => _isSaving = value);
  set hasUnsavedChanges(bool value) =>
      setState(() => _hasUnsavedChanges = value);

  // دالة استخراج اسم اليوم
  String extractDayName(String dateString) {
    final days = [
      'الأحد',
      'الإثنين',
      'الثلاثاء',
      'الأربعاء',
      'الخميس',
      'الجمعة',
      'السبت'
    ];
    final now = DateTime.now();
    return days[now.weekday % 7];
  }

  // دالة للتمرير إلى الحقل المحدد
  void scrollToField(int rowIndex, int colIndex) {
    const double headerHeight = 32.0;
    const double rowHeight = 25.0;
    final double verticalPosition = (rowIndex * rowHeight);
    const double columnWidth = 60.0;
    final double horizontalPosition = colIndex * columnWidth;

    // التمرير العمودي
    final double verticalScrollOffset = verticalPosition;
    _verticalScrollController.animateTo(
      verticalScrollOffset + headerHeight,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );

    // التمرير الأفقي
    _horizontalScrollController.animateTo(
      horizontalPosition,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  // بناء واجهة الجدول مع رأس مثبت
  Widget buildTableWithStickyHeader({
    required Widget tableHeader,
    required Widget tableContent,
  }) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: CustomScrollView(
        controller: _verticalScrollController,
        slivers: [
          // الجزء العلوي المثبت (رأس الجدول)
          SliverPersistentHeader(
            pinned: true,
            floating: false,
            delegate: StickyTableHeaderDelegate(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  border: Border.all(color: Colors.grey),
                ),
                child: tableHeader,
              ),
            ),
          ),

          // محتوى الجدول (البيانات)
          SliverToBoxAdapter(
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                controller: _horizontalScrollController,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minWidth: MediaQuery.of(context).size.width,
                  ),
                  child: tableContent,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // بناء AppBar المشترك
  AppBar buildAppBar({
    required String serialNumber,
    required String dayName,
    required VoidCallback onSave,
    required VoidCallback onOpenRecord,
    required VoidCallback onShare,
    required Color backgroundColor,
    required Color progressColor,
  }) {
    return AppBar(
      title: Text(
        '${widget.screenType == 'purchases' ? 'يومية مشتريات' : 'يومية مبيعات'} رقم /$serialNumber/ ليوم $dayName تاريخ ${widget.selectedDate} لمحل ${widget.storeName} البائع ${widget.sellerName}',
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
      centerTitle: true,
      backgroundColor: backgroundColor,
      foregroundColor: Colors.white,
      actions: [
        // زر المشاركة
        IconButton(
          icon: const Icon(Icons.share),
          tooltip: 'مشاركة الملف',
          onPressed: onShare,
        ),
        // زر الحفظ مع إشارة التغييرات غير المحفوظة
        IconButton(
          icon: _isSaving
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                  ),
                )
              : Stack(
                  children: [
                    const Icon(Icons.save),
                    if (_hasUnsavedChanges)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 12,
                            minHeight: 12,
                          ),
                          child: const SizedBox(
                            width: 8,
                            height: 8,
                          ),
                        ),
                      ),
                  ],
                ),
          tooltip: _hasUnsavedChanges
              ? 'هناك تغييرات غير محفوظة - انقر للحفظ'
              : 'حفظ السجل',
          onPressed: _isSaving
              ? null
              : () {
                  onSave();
                  _hasUnsavedChanges = false;
                },
        ),
        // زر فتح سجل آخر
        IconButton(
          icon: const Icon(Icons.folder_open),
          tooltip: 'فتح سجل',
          onPressed: onOpenRecord,
        ),
      ],
    );
  }

  @override
  void dispose() {
    _verticalScrollController.dispose();
    _horizontalScrollController.dispose();
    super.dispose();
  }

  // دوال يجب تنفيذها في الفئات الفرعية
  Widget buildTableHeader();
  Widget buildTableContent();
  Future<void> saveCurrentRecord({bool silent = false});
  Future<void> showRecordSelectionDialog();
  Future<void> shareFile();
  Future<void> createNewRecordAutomatically();
  void createNewRecord(String recordNumber);
  Future<void> loadRecord(String recordNumber);
}
