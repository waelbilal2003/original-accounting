import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:async';
import '../../models/purchase_model.dart';
import '../../services/purchase_storage_service.dart';
// استيراد خدمات الفهرس
import '../../services/material_index_service.dart';
import '../../services/packaging_index_service.dart';
import '../../services/supplier_index_service.dart';
import '../../widgets/table_builder.dart' as TableBuilder;
import '../../widgets/table_components.dart' as TableComponents;
import '../../widgets/common_dialogs.dart' as CommonDialogs;
import '../../services/enhanced_index_service.dart';
import '../../widgets/suggestions_banner.dart';
import '../../services/supplier_balance_tracker.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart';

class PurchasesScreen extends StatefulWidget {
  final String sellerName;
  final String selectedDate;
  final String storeName;

  const PurchasesScreen({
    Key? key,
    required this.sellerName,
    required this.selectedDate,
    required this.storeName,
  }) : super(key: key);

  @override
  _PurchasesScreenState createState() => _PurchasesScreenState();
}

class _PurchasesScreenState extends State<PurchasesScreen> {
  // خدمة التخزين
  final PurchaseStorageService _storageService = PurchaseStorageService();

  // خدمات الفهرس
  final MaterialIndexService _materialIndexService = MaterialIndexService();
  final PackagingIndexService _packagingIndexService = PackagingIndexService();
  final SupplierIndexService _supplierIndexService = SupplierIndexService();

  // بيانات الحقول
  String dayName = '';

  // قائمة لتخزين صفوف الجدول
  List<List<TextEditingController>> rowControllers = [];
  List<List<FocusNode>> rowFocusNodes = [];
  List<String> cashOrDebtValues = [];
  List<String> emptiesValues = [];
  List<String> sellerNames = []; // <-- تخزين اسم البائع لكل صف

  // متحكمات صف المجموع
  late TextEditingController totalCountController;
  late TextEditingController totalBaseController;
  late TextEditingController totalNetController;
  late TextEditingController totalGrandController;

  // قوائم الخيارات
  final List<String> cashOrDebtOptions = ['نقدي', 'دين'];

  // متحكمات للتمرير
  final ScrollController _verticalScrollController = ScrollController();
  final ScrollController _horizontalScrollController = ScrollController();
  final _scrollController = ScrollController(); // للتمرير
  // حالة الحفظ
  bool _isSaving = false;
  bool _hasUnsavedChanges = false;

  // التواريخ المتاحة
  List<Map<String, String>> _availableDates = [];
  bool _isLoadingDates = false;

  String serialNumber = '';
  // ignore: unused_field
  String? _currentJournalNumber;

  // متغيرات للاقتراحات
  List<String> _materialSuggestions = [];
  List<String> _packagingSuggestions = [];
  List<String> _supplierSuggestions = [];

  // مؤشرات الصفوف النشطة للاقتراحات
  int? _activeMaterialRowIndex;
  int? _activePackagingRowIndex;
  int? _activeSupplierRowIndex;

  // متحكمات التمرير الأفقي للاقتراحات
  final ScrollController _materialSuggestionsScrollController =
      ScrollController();
  final ScrollController _packagingSuggestionsScrollController =
      ScrollController();
  final ScrollController _supplierSuggestionsScrollController =
      ScrollController();
  bool _showFullScreenSuggestions = false;
  String _currentSuggestionType = '';
  late ScrollController
      _horizontalSuggestionsController; // في initState قم بتعريفه: _horizontalSuggestionsController = ScrollController();

  final SupplierBalanceTracker _balanceTracker = SupplierBalanceTracker();

  // متغير لتأخير حساب المجاميع (debouncing)
  Timer? _calculateTotalsDebouncer;
  Timer? _calculateRowDebouncer;
  bool _isCalculating = false;
  bool _isAdmin = false;

  double _grandTotal = 0.0;

  @override
  void initState() {
    super.initState();
    dayName = _extractDayName(widget.selectedDate);

    totalCountController = TextEditingController();
    totalBaseController = TextEditingController();
    totalNetController = TextEditingController();
    totalGrandController = TextEditingController();

    _resetTotalValues();

    // تهيئة المتحكم (هذا ما كان ينقصك)
    _horizontalSuggestionsController = ScrollController();

    _verticalScrollController.addListener(() {
      _hideAllSuggestionsImmediately();
    });

    _horizontalScrollController.addListener(() {
      _hideAllSuggestionsImmediately();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAdminStatus();
      _loadOrCreateJournal();
      _loadAvailableDates();
      _loadJournalNumber();
    });
  }

  @override
  void dispose() {
    _saveCurrentRecord(silent: true);
    for (var row in rowControllers) {
      for (var controller in row) {
        controller.dispose();
      }
    }
    for (var row in rowFocusNodes) {
      for (var node in row) {
        node.dispose();
      }
    }
    totalCountController.dispose();
    totalBaseController.dispose();
    totalNetController.dispose();
    totalGrandController.dispose();
    _verticalScrollController.dispose();
    _horizontalScrollController.dispose();
    _scrollController.dispose();
    _materialSuggestionsScrollController.dispose();
    _packagingSuggestionsScrollController.dispose();
    _supplierSuggestionsScrollController.dispose();

    // إغلاق المتحكم
    _horizontalSuggestionsController.dispose();

    _balanceTracker.dispose();
    _calculateTotalsDebouncer?.cancel();
    _calculateRowDebouncer?.cancel();
    super.dispose();
  }

  String _extractDayName(String dateString) {
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

  // تحميل التواريخ المتاحة
  Future<void> _loadAvailableDates() async {
    if (_isLoadingDates) return;

    setState(() {
      _isLoadingDates = true;
    });

    try {
      final dates = await _storageService.getAvailableDatesWithNumbers();
      setState(() {
        _availableDates = dates;
        _isLoadingDates = false;
      });
      _loadGrandTotal(); // أضف هذا السطر
    } catch (e) {
      setState(() {
        _availableDates = [];
        _isLoadingDates = false;
      });
    }
  }

  // تحميل اليومية إذا كانت موجودة، أو إنشاء جديدة
  Future<void> _loadOrCreateJournal() async {
    final document =
        await _storageService.loadPurchaseDocument(widget.selectedDate);

    if (document != null && document.purchases.isNotEmpty) {
      // تحميل اليومية الموجودة
      _loadJournal(document);
    } else {
      // إنشاء يومية جديدة
      _createNewJournal();
    }
  }

  void _resetTotalValues() {
    totalCountController.text = '0';
    totalBaseController.text = '0.00';
    totalNetController.text = '0.00';
    totalGrandController.text = '0.00';
  }

  void _createNewJournal() {
    setState(() {
      rowControllers.clear();
      rowFocusNodes.clear();
      cashOrDebtValues.clear();
      emptiesValues.clear();
      sellerNames.clear(); // <-- تنظيف قائمة أسماء البائعين
      _resetTotalValues();
      _hasUnsavedChanges = false;
      _addNewRow();
    });
  }

  // تعديل _addNewRow لتحسين المستمعات
  void _addNewRow() {
    setState(() {
      final newSerialNumber = (rowControllers.length + 1).toString();

      List<TextEditingController> newControllers =
          List.generate(11, (index) => TextEditingController());

      List<FocusNode> newFocusNodes = List.generate(11, (index) => FocusNode());

      newControllers[0].text = newSerialNumber; // [0] الرقم المسلسل

      // إضافة مستمعات للتغيير باستخدام دالة مساعدة
      _addChangeListenersToControllers(newControllers, rowControllers.length);

      // تخزين اسم البائع للصف الجديد
      sellerNames.add(widget.sellerName);

      rowControllers.add(newControllers);
      rowFocusNodes.add(newFocusNodes);
      cashOrDebtValues.add('');
      emptiesValues.add('');
    });

    // تركيز الماوس على حقل المادة في السجل الجديد
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (rowFocusNodes.isNotEmpty) {
        final newRowIndex = rowFocusNodes.length - 1;
        FocusScope.of(context).requestFocus(rowFocusNodes[newRowIndex][1]);
      }
    });
  }

  // دالة مساعدة لإخفاء جميع الاقتراحات فوراً
  void _hideAllSuggestionsImmediately() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _materialSuggestions = [];
          _packagingSuggestions = [];
          _supplierSuggestions = [];
          _activeMaterialRowIndex = null;
          _activePackagingRowIndex = null;
          _activeSupplierRowIndex = null;
        });
      }
    });
  }

// دالة مساعدة لإضافة المستمعات
  void _addChangeListenersToControllers(
      List<TextEditingController> controllers, int rowIndex) {
    // حقل المادة
    controllers[1].addListener(() {
      _hasUnsavedChanges = true;
      _updateMaterialSuggestions(rowIndex);
    });

    // حقل العائدية
    controllers[2].addListener(() {
      _hasUnsavedChanges = true;
      _updateSupplierSuggestions(rowIndex);
    });

    // حقل العبوة
    controllers[4].addListener(() {
      _hasUnsavedChanges = true;
      _updatePackagingSuggestions(rowIndex);
    });

    // الحقول الرقمية مع التحديث التلقائي
    controllers[3].addListener(() {
      _hasUnsavedChanges = true;
      _calculateRowValues(rowIndex);
      _calculateAllTotals();
    });

    controllers[5].addListener(() {
      _hasUnsavedChanges = true;
      _validateStandingAndNet(rowIndex);
      _calculateRowValues(rowIndex);
      _calculateAllTotals();
    });

    controllers[6].addListener(() {
      _hasUnsavedChanges = true;
      _validateStandingAndNet(rowIndex);
      _calculateRowValues(rowIndex);
      _calculateAllTotals();
    });

    controllers[7].addListener(() {
      _hasUnsavedChanges = true;
      _calculateRowValues(rowIndex);
      _calculateAllTotals();
    });
  }

  // تحديث اقتراحات المادة
  void _updateMaterialSuggestions(int rowIndex) async {
    final query = rowControllers[rowIndex][1].text;
    if (query.length >= 1) {
      final suggestions =
          await getEnhancedSuggestions(_materialIndexService, query);
      setState(() {
        _materialSuggestions = suggestions;
        _activeMaterialRowIndex = rowIndex;
        _toggleFullScreenSuggestions(
            type: 'material', show: suggestions.isNotEmpty);
      });
    } else {
      // إخفاء الاقتراحات إذا كان الحقل فارغاً
      setState(() {
        _materialSuggestions = [];
        _activeMaterialRowIndex = null;
      });
    }
  }

// تحديث اقتراحات العبوة
  void _updatePackagingSuggestions(int rowIndex) async {
    final query = rowControllers[rowIndex][4].text;
    if (query.length >= 1) {
      final suggestions =
          await getEnhancedSuggestions(_packagingIndexService, query);
      setState(() {
        _packagingSuggestions = suggestions;
        _activePackagingRowIndex = rowIndex;
        _toggleFullScreenSuggestions(
            type: 'packaging', show: suggestions.isNotEmpty);
      });
    } else {
      // إخفاء الاقتراحات إذا كان الحقل فارغاً
      setState(() {
        _packagingSuggestions = [];
        _activePackagingRowIndex = null;
      });
    }
  }

// تحديث اقتراحات الموردين (العائدية)
  void _updateSupplierSuggestions(int rowIndex) async {
    final query = rowControllers[rowIndex][2].text;
    if (query.length >= 1) {
      final suggestions =
          await getEnhancedSuggestions(_supplierIndexService, query);
      setState(() {
        _supplierSuggestions = suggestions;
        _activeSupplierRowIndex = rowIndex;
        _toggleFullScreenSuggestions(
            type: 'supplier', show: suggestions.isNotEmpty);
      });
    } else {
      // إخفاء الاقتراحات إذا كان الحقل فارغاً
      setState(() {
        _supplierSuggestions = [];
        _activeSupplierRowIndex = null;
      });
    }
  }

// اختيار اقتراح للمادة - معدلة تماماً
  void _selectMaterialSuggestion(String suggestion, int rowIndex) {
    // إخفاء الاقتراحات أولاً وفوراً
    _hideAllSuggestionsImmediately();

    // ثم تعيين النص
    rowControllers[rowIndex][1].text = suggestion;
    _hasUnsavedChanges = true;

    // حفظ المادة في الفهرس إذا لم تكن موجودة (مع شرط الطول)
    if (suggestion.trim().length > 1) {
      _saveMaterialToIndex(suggestion);
    }

    // نقل التركيز إلى الحقل التالي بعد تأخير بسيط
    Future.delayed(const Duration(milliseconds: 50), () {
      if (mounted) {
        FocusScope.of(context).requestFocus(rowFocusNodes[rowIndex][2]);
      }
    });
  }

// اختيار اقتراح للعبوة - معدلة تماماً
  void _selectPackagingSuggestion(String suggestion, int rowIndex) {
    // إخفاء الاقتراحات أولاً وفوراً
    _hideAllSuggestionsImmediately();

    // ثم تعيين النص
    rowControllers[rowIndex][4].text = suggestion;
    _hasUnsavedChanges = true;

    // حفظ العبوة في الفهرس إذا لم تكن موجودة (مع شرط الطول)
    if (suggestion.trim().length > 1) {
      _savePackagingToIndex(suggestion);
    }

    // نقل التركيز إلى الحقل التالي بعد تأخير بسيط
    Future.delayed(const Duration(milliseconds: 50), () {
      if (mounted) {
        FocusScope.of(context).requestFocus(rowFocusNodes[rowIndex][5]);
      }
    });
  }

// اختيار اقتراح للمورد (العائدية) - معدلة تماماً
  void _selectSupplierSuggestion(String suggestion, int rowIndex) {
    // إخفاء الاقتراحات أولاً وفوراً
    _hideAllSuggestionsImmediately();

    // ثم تعيين النص
    rowControllers[rowIndex][2].text = suggestion;
    _hasUnsavedChanges = true;

    // حفظ المورد في الفهرس إذا لم يكن موجوداً (مع شرط الطول)
    if (suggestion.trim().length > 1) {
      _saveSupplierToIndex(suggestion);
    }

    // نقل التركيز إلى الحقل التالي بعد تأخير بسيط
    Future.delayed(const Duration(milliseconds: 50), () {
      if (mounted) {
        FocusScope.of(context).requestFocus(rowFocusNodes[rowIndex][3]);
      }
    });
  }

  // حفظ المادة في الفهرس - معدلة لمنع تخزين حرف واحد
  void _saveMaterialToIndex(String material) {
    final trimmedMaterial = material.trim();
    // منع تخزين حرف واحد أو قيمة فارغة
    if (trimmedMaterial.length > 1) {
      _materialIndexService.saveMaterial(trimmedMaterial);
    }
  }

// حفظ العبوة في الفهرس - معدلة لمنع تخزين حرف واحد
  void _savePackagingToIndex(String packaging) {
    final trimmedPackaging = packaging.trim();
    // منع تخزين حرف واحد أو قيمة فارغة
    if (trimmedPackaging.length > 1) {
      _packagingIndexService.savePackaging(trimmedPackaging);
    }
  }

// حفظ المورد في الفهرس - معدلة لمنع تخزين حرف واحد
  void _saveSupplierToIndex(String supplier) {
    final trimmedSupplier = supplier.trim();
    if (trimmedSupplier.length > 1) {
      _supplierIndexService.saveSupplier(
        trimmedSupplier,
        startDate: widget.selectedDate,
      );
    }
  }

// تعديل _validateStandingAndNet لإعادة الحساب بشكل صحيح
  void _validateStandingAndNet(int rowIndex) {
    if (rowIndex >= rowControllers.length) return;

    final controllers = rowControllers[rowIndex];

    try {
      double standing = double.tryParse(controllers[5].text) ?? 0;
      double net = double.tryParse(controllers[6].text) ?? 0;

      if (standing < net) {
        // إذا كان الصافي أكبر من القائم، نجعل الصافي يساوي القائم
        controllers[6].text = standing.toStringAsFixed(2);
        _showInlineWarning(rowIndex, 'الصافي لا يمكن أن يكون أكبر من القائم');

        // إعادة الحساب فوراً
        _calculateRowValues(rowIndex);
        _calculateAllTotals();
      } else if (standing == 0 && net > 0) {
        // إذا كان القائم صفر، يجب أن يكون الصافي صفر
        controllers[6].text = '0.00';
        _showInlineWarning(
            rowIndex, 'إذا كان القائم صفر، يجب أن يكون الصافي صفر');

        // إعادة الحساب فوراً
        _calculateRowValues(rowIndex);
        _calculateAllTotals();
      }
    } catch (e) {
      // تجاهل الأخطاء في التحليل
    }
  }

  void _calculateRowValues(int rowIndex) {
    if (rowIndex >= rowControllers.length) return;

    final controllers = rowControllers[rowIndex];

    // حساب فوري بدون تأخير للصف الواحد
    try {
      double count = (double.tryParse(controllers[3].text) ?? 0).abs();
      double net = (double.tryParse(controllers[6].text) ?? 0).abs();
      double price = (double.tryParse(controllers[7].text) ?? 0).abs();

      double baseValue = net > 0 ? net : count;
      double total = baseValue * price;

      final newTotal = total.toStringAsFixed(2);
      if (controllers[8].text != newTotal) {
        controllers[8].text = newTotal;
      }
    } catch (e) {
      if (controllers[8].text.isNotEmpty) {
        controllers[8].text = '';
      }
    }
  }

  void _calculateAllTotals() {
    // إلغاء أي حساب سابق منتظر
    _calculateTotalsDebouncer?.cancel();

    // تأخير الحساب لتجنب التكرار المتعدد
    _calculateTotalsDebouncer = Timer(const Duration(milliseconds: 50), () {
      if (!mounted || _isCalculating) return;

      _isCalculating = true;

      double totalCount = 0;
      double totalBase = 0;
      double totalNet = 0;
      double totalGrand = 0;

      for (var controllers in rowControllers) {
        try {
          totalCount += double.tryParse(controllers[3].text) ?? 0;
          totalBase += double.tryParse(controllers[5].text) ?? 0;
          totalNet += double.tryParse(controllers[6].text) ?? 0;
          totalGrand += double.tryParse(controllers[8].text) ?? 0;
        } catch (e) {
          // تجاهل الأخطاء
        }
      }

      // تحديث قيم المتحكمات
      totalCountController.text = totalCount.toStringAsFixed(0);
      totalBaseController.text = totalBase.toStringAsFixed(2);
      totalNetController.text = totalNet.toStringAsFixed(2);
      totalGrandController.text = totalGrand.toStringAsFixed(2);

      // إعادة بناء الواجهة لإظهار القيم الجديدة
      if (mounted) {
        setState(() {});
      }

      _isCalculating = false;
    });
  }

  void _loadJournal(PurchaseDocument document) {
    setState(() {
      // تنظيف المتحكمات القديمة
      for (var row in rowControllers) {
        for (var controller in row) {
          controller.dispose();
        }
      }
      for (var row in rowFocusNodes) {
        for (var node in row) {
          node.dispose();
        }
      }

      // إعادة تهيئة القوائم
      rowControllers.clear();
      rowFocusNodes.clear();
      cashOrDebtValues.clear();
      emptiesValues.clear();
      sellerNames.clear();

      // تحميل السجلات من الوثيقة
      for (int i = 0; i < document.purchases.length; i++) {
        var purchase = document.purchases[i];

        List<TextEditingController> newControllers = [
          TextEditingController(text: (i + 1).toString()), // [0] الرقم المسلسل
          TextEditingController(text: purchase.material), // [1] المادة
          TextEditingController(text: purchase.affiliation), // [2] المورد
          TextEditingController(text: purchase.count), // [3] العدد
          TextEditingController(text: purchase.packaging), // [4] العبوة
          TextEditingController(text: purchase.standing), // [5] القائم
          TextEditingController(text: purchase.net), // [6] الصافي
          TextEditingController(text: purchase.price), // [7] السعر
          TextEditingController(
              text: purchase
                  .total), // [8] الإجمالي ← يُحسب في _calculateRowValues
          TextEditingController(), // [9]
          TextEditingController(), // [10]
        ];

        List<FocusNode> newFocusNodes =
            List.generate(11, (index) => FocusNode());

        // تخزين اسم البائع لهذا الصف
        sellerNames.add(purchase.sellerName);

        // التحقق إذا كان السجل مملوكاً للبائع الحالي
        final bool isOwnedByCurrentSeller =
            purchase.sellerName == widget.sellerName;

        // إضافة مستمعات للتغيير فقط إذا كان السجل مملوكاً للبائع الحالي
        if (isOwnedByCurrentSeller) {
          _addChangeListenersToControllers(newControllers, i);
        }

        rowControllers.add(newControllers);
        rowFocusNodes.add(newFocusNodes);
        cashOrDebtValues.add(purchase.cashOrDebt);
      }

      // تحميل المجاميع
      if (document.totals.isNotEmpty) {
        totalCountController.text = document.totals['totalCount'] ?? '0';
        totalBaseController.text = document.totals['totalBase'] ?? '0.00';
        totalNetController.text = document.totals['totalNet'] ?? '0.00';
        totalGrandController.text = document.totals['totalGrand'] ?? '0.00';
      }

      _hasUnsavedChanges = false;
    });

    // إعادة حساب المجاميع من البيانات المحملة لضمان صحة الإجمالي
    _calculateAllTotals();
  }

  void _scrollToField(int rowIndex, int colIndex) {
    const double headerHeight = 32.0;
    const double rowHeight = 25.0;
    final double verticalPosition = (rowIndex * rowHeight);
    const double columnWidth = 80.0;
    final double horizontalPosition = colIndex * columnWidth;

    _verticalScrollController.animateTo(
      verticalPosition + headerHeight,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );

    _horizontalScrollController.animateTo(
      horizontalPosition,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Widget _buildTableHeader() {
    return Table(
      defaultColumnWidth: const FlexColumnWidth(),
      border: TableBorder.all(color: Colors.grey, width: 0.5),
      children: [
        TableRow(
          decoration: BoxDecoration(color: Colors.grey[200]),
          children: [
            TableComponents.buildTableHeaderCell('المادة'),
            TableComponents.buildTableHeaderCell('المورد'),
            TableComponents.buildTableHeaderCell('العدد'),
            TableComponents.buildTableHeaderCell('العبوة'),
            TableComponents.buildTableHeaderCell('القائم'),
            TableComponents.buildTableHeaderCell('الصافي'),
            TableComponents.buildTableHeaderCell('السعر'),
            TableComponents.buildTableHeaderCell('الإجمالي'),
            TableComponents.buildTableHeaderCell('نقدي او دين'),
          ],
        ),
      ],
    );
  }

  Widget _buildTableContent() {
    List<TableRow> contentRows = [];

    for (int i = 0; i < rowControllers.length; i++) {
      final bool isOwnedByCurrentSeller = sellerNames[i] == widget.sellerName;

      contentRows.add(
        TableRow(
          children: [
            _buildMaterialCell(rowControllers[i][1], rowFocusNodes[i][1], i, 1,
                isOwnedByCurrentSeller),
            _buildSupplierCell(rowControllers[i][2], rowFocusNodes[i][2], i, 2,
                isOwnedByCurrentSeller),
            _buildTableCell(rowControllers[i][3], rowFocusNodes[i][3], i, 3,
                isOwnedByCurrentSeller),
            _buildPackagingCell(rowControllers[i][4], rowFocusNodes[i][4], i, 4,
                isOwnedByCurrentSeller),
            _buildTableCell(rowControllers[i][5], rowFocusNodes[i][5], i, 5,
                isOwnedByCurrentSeller),
            _buildTableCell(rowControllers[i][6], rowFocusNodes[i][6], i, 6,
                isOwnedByCurrentSeller),
            _buildTableCell(rowControllers[i][7], rowFocusNodes[i][7], i, 7,
                isOwnedByCurrentSeller),
            TableComponents.buildTotalValueCell(rowControllers[i][8]),
            _buildCashOrDebtCell(i, 9, isOwnedByCurrentSeller),
          ],
        ),
      );
    }

    if (rowControllers.length >= 1) {
      contentRows.add(
        TableRow(
          decoration: BoxDecoration(color: Colors.yellow[50]),
          children: [
            _buildSummaryCell(''),
            _buildSummaryCell(''),
            _buildSummaryValueCell(totalCountController),
            _buildSummaryCell(''),
            _buildSummaryValueCell(totalBaseController),
            _buildSummaryValueCell(totalNetController),
            _buildSummaryCell(''),
            _buildSummaryValueCell(totalGrandController),
            _buildSummaryCell(''),
          ],
        ),
      );
    }

    return Table(
      defaultColumnWidth: const FlexColumnWidth(),
      border: TableBorder.all(color: Colors.grey, width: 0.5),
      children: contentRows,
    );
  }

  Widget _buildTableCell(TextEditingController controller, FocusNode focusNode,
      int rowIndex, int colIndex, bool isOwnedByCurrentSeller) {
    final bool enabled = _canEditRow(rowIndex);

    // تحديد الحقول الرقمية
    bool isNumericField =
        colIndex == 3 || colIndex == 5 || colIndex == 6 || colIndex == 7;

    // إضافة فلتر للأرقام فقط للحقول الرقمية
    List<TextInputFormatter>? inputFormatters;
    if (isNumericField) {
      inputFormatters = [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
        FilteringTextInputFormatter.deny(RegExp(r'^0\d+')),
        TableComponents.PositiveDecimalInputFormatter(),
      ];
    }

    return TableBuilder.buildTableCell(
      controller: controller,
      focusNode: focusNode,
      enabled: enabled,
      isSerialField: false,
      isNumericField: isNumericField,
      rowIndex: rowIndex,
      colIndex: colIndex,
      scrollToField: _scrollToField,
      onFieldSubmitted: (value, rIndex, cIndex) =>
          _handleFieldSubmitted(value, rIndex, cIndex),
      onFieldChanged: (value, rIndex, cIndex) =>
          _handleFieldChanged(value, rIndex, cIndex),
      inputFormatters: inputFormatters,
    );
  }

  Widget _buildSummaryCell(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
      constraints: const BoxConstraints(minHeight: 25),
      color: Colors.yellow[50],
      alignment: Alignment.center,
      child: Text(text,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildSummaryValueCell(TextEditingController controller) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
      constraints: const BoxConstraints(minHeight: 25),
      color: Colors.yellow[50],
      alignment: Alignment.center,
      child: Text(
        controller.text,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildMaterialCell(
      TextEditingController controller,
      FocusNode focusNode,
      int rowIndex,
      int colIndex,
      bool isOwnedByCurrentSeller) {
    return TableBuilder.buildTableCell(
      controller: controller,
      focusNode: focusNode,
      enabled: _canEditRow(rowIndex),
      isSerialField: false,
      isNumericField: false,
      rowIndex: rowIndex,
      colIndex: colIndex,
      scrollToField: _scrollToField,
      onFieldSubmitted: (value, rIndex, cIndex) =>
          _handleFieldSubmitted(value, rIndex, cIndex),
      onFieldChanged: (value, rIndex, cIndex) =>
          _handleFieldChanged(value, rIndex, cIndex),
    );
  }

  Widget _buildPackagingCell(
      TextEditingController controller,
      FocusNode focusNode,
      int rowIndex,
      int colIndex,
      bool isOwnedByCurrentSeller) {
    return TableBuilder.buildTableCell(
      controller: controller,
      focusNode: focusNode,
      enabled: _canEditRow(rowIndex),
      isSerialField: false,
      isNumericField: false,
      rowIndex: rowIndex,
      colIndex: colIndex,
      scrollToField: _scrollToField,
      onFieldSubmitted: (value, rIndex, cIndex) =>
          _handleFieldSubmitted(value, rIndex, cIndex),
      onFieldChanged: (value, rIndex, cIndex) =>
          _handleFieldChanged(value, rIndex, cIndex),
    );
  }

  Widget _buildSupplierCell(
      TextEditingController controller,
      FocusNode focusNode,
      int rowIndex,
      int colIndex,
      bool isOwnedByCurrentSeller) {
    return TableBuilder.buildTableCell(
      controller: controller,
      focusNode: focusNode,
      enabled: _canEditRow(rowIndex),
      isSerialField: false,
      isNumericField: false,
      rowIndex: rowIndex,
      colIndex: colIndex,
      scrollToField: _scrollToField,
      onFieldSubmitted: (value, rIndex, cIndex) =>
          _handleFieldSubmitted(value, rIndex, cIndex),
      onFieldChanged: (value, rIndex, cIndex) =>
          _handleFieldChanged(value, rIndex, cIndex),
    );
  }

  void _handleFieldSubmitted(String value, int rowIndex, int colIndex) {
    if (!_canEditRow(rowIndex)) return;

    if (colIndex == 1) {
      // حقل المادة
      if (_materialSuggestions.isNotEmpty) {
        _selectMaterialSuggestion(_materialSuggestions[0], rowIndex);
        return;
      }
      if (value.trim().length > 1) _saveMaterialToIndex(value);
      FocusScope.of(context).requestFocus(rowFocusNodes[rowIndex][2]);
    } else if (colIndex == 2) {
      // حقل المورد
      if (_supplierSuggestions.isNotEmpty) {
        _selectSupplierSuggestion(_supplierSuggestions[0], rowIndex);
        return;
      }
      if (value.trim().length > 1) _saveSupplierToIndex(value);
      FocusScope.of(context).requestFocus(rowFocusNodes[rowIndex][3]);
    } else if (colIndex == 3) {
      // حقل العدد
      FocusScope.of(context).requestFocus(rowFocusNodes[rowIndex][4]);
    } else if (colIndex == 4) {
      // حقل العبوة
      if (_packagingSuggestions.isNotEmpty) {
        _selectPackagingSuggestion(_packagingSuggestions[0], rowIndex);
        return;
      }
      if (value.trim().length > 1) _savePackagingToIndex(value);
      FocusScope.of(context).requestFocus(rowFocusNodes[rowIndex][5]);
    } else if (colIndex == 5) {
      // حقل القائم
      FocusScope.of(context).requestFocus(rowFocusNodes[rowIndex][6]);
    } else if (colIndex == 6) {
      // حقل الصافي
      FocusScope.of(context).requestFocus(rowFocusNodes[rowIndex][7]);
    } else if (colIndex == 7) {
      // حقل السعر - عرض نافذة نقدي/دين
      _showCashOrDebtDialog(rowIndex);
    } else if (colIndex == 8) {
      // نقدي او دين - إنشاء صف جديد
      _addNewRow();
      if (rowControllers.isNotEmpty) {
        final newRowIndex = rowControllers.length - 1;
        FocusScope.of(context).requestFocus(rowFocusNodes[newRowIndex][1]);
      }
    }
    _hideAllSuggestionsImmediately();
  }

  void _handleFieldChanged(String value, int rowIndex, int colIndex) {
    // التحقق إذا كان السجل مملوكاً للبائع الحالي
    if (!_canEditRow(rowIndex)) {
      return; // لا تفعل شيئاً إذا لم يكن السجل مملوكاً للبائع الحالي
    }

    setState(() {
      _hasUnsavedChanges = true;

      if (colIndex == 0) {
        // عند تغيير الرقم المسلسل، ترقيم كل السجلات
        for (int i = 0; i < rowControllers.length; i++) {
          rowControllers[i][0].text = (i + 1).toString();
        }
      }

      // إذا بدأ المستخدم بالكتابة في حقل آخر، إخفاء اقتراحات الحقول الأخرى
      if (colIndex == 1 && _activeMaterialRowIndex != rowIndex) {
        _clearAllSuggestions();
      } else if (colIndex == 2 && _activeSupplierRowIndex != rowIndex) {
        _clearAllSuggestions();
      } else if (colIndex == 4 && _activePackagingRowIndex != rowIndex) {
        _clearAllSuggestions();
      }
    });
  }

  Widget _buildCashOrDebtCell(
      int rowIndex, int colIndex, bool isOwnedByCurrentSeller) {
    Widget cell = TableBuilder.buildCashOrDebtCell(
      rowIndex: rowIndex,
      colIndex: colIndex,
      cashOrDebtValue: cashOrDebtValues[rowIndex],
      customerName: '',
      customerController: TextEditingController(),
      focusNode: rowFocusNodes[rowIndex][colIndex],
      hasUnsavedChanges: _hasUnsavedChanges,
      setHasUnsavedChanges: (value) =>
          setState(() => _hasUnsavedChanges = value),
      onTap: () => _showCashOrDebtDialog(rowIndex),
      scrollToField: _scrollToField,
      onCustomerNameChanged: (value) {},
      onCustomerSubmitted: (value, rIndex, cIndex) {},
      isSalesScreen: false,
    );

    if (!isOwnedByCurrentSeller) {
      return IgnorePointer(
        child: Opacity(
          opacity: 0.7,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey[100],
            ),
            child: cell,
          ),
        ),
      );
    }

    return cell;
  }

  void _showCashOrDebtDialog(int rowIndex) {
    if (!_canEditRow(rowIndex)) return;

    CommonDialogs.showCashOrDebtDialog(
      context: context,
      currentValue: cashOrDebtValues[rowIndex],
      options: cashOrDebtOptions,
      onSelected: (value) {
        setState(() {
          cashOrDebtValues[rowIndex] = value;
          _hasUnsavedChanges = true;
        });
        // بعد اختيار النوع، نقوم بإنشاء صف جديد
        _addNewRow();
        if (rowControllers.isNotEmpty) {
          final newRowIndex = rowControllers.length - 1;
          Future.delayed(const Duration(milliseconds: 100), () {
            if (mounted) {
              FocusScope.of(context)
                  .requestFocus(rowFocusNodes[newRowIndex][1]);
              _scrollToField(newRowIndex, 1);
            }
          });
        }
      },
      onCancel: () {
        // عند الإلغاء، نرجع التركيز لحقل السعر
        if (mounted && rowIndex < rowFocusNodes.length) {
          FocusScope.of(context).requestFocus(rowFocusNodes[rowIndex][7]);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (_showFullScreenSuggestions &&
                _getSuggestionsByType().isNotEmpty)
              SuggestionsBanner(
                suggestions: _getSuggestionsByType(),
                type: _currentSuggestionType,
                currentRowIndex: _getCurrentRowIndexByType(),
                scrollController: _horizontalSuggestionsController,
                onSelect: (val, idx) {
                  if (_currentSuggestionType == 'material')
                    _selectMaterialSuggestion(val, idx);
                  if (_currentSuggestionType == 'packaging')
                    _selectPackagingSuggestion(val, idx);
                  if (_currentSuggestionType == 'supplier')
                    _selectSupplierSuggestion(val, idx);
                },
                onClose: () =>
                    _toggleFullScreenSuggestions(type: '', show: false),
              ),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'المشتريات - ${widget.selectedDate}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14, height: 1.5),
                  ),
                  Directionality(
                    textDirection: TextDirection.rtl,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('الإجمالي الكلي: ',
                            style:
                                TextStyle(fontSize: 11, color: Colors.white70)),
                        Text(
                          _grandTotal.toStringAsFixed(2),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.lightBlueAccent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        centerTitle: false,
        backgroundColor: Colors.red[700],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'تصدير PDF',
            onPressed: () => _generateAndSharePdf(),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.calendar_month),
            tooltip: 'فتح يومية سابقة',
            onSelected: (selectedDate) async {
              if (selectedDate != widget.selectedDate) {
                if (_hasUnsavedChanges) {
                  final shouldSave = await _showUnsavedChangesDialog();
                  if (shouldSave) {
                    await _saveCurrentRecord(silent: true);
                  }
                }

                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PurchasesScreen(
                      sellerName: widget.sellerName,
                      selectedDate: selectedDate,
                      storeName: widget.storeName,
                    ),
                  ),
                );
              }
            },
            itemBuilder: (BuildContext context) {
              List<PopupMenuEntry<String>> items = [];

              if (_isLoadingDates) {
                items.add(
                  const PopupMenuItem<String>(
                    value: '',
                    enabled: false,
                    child: Text('جاري التحميل...'),
                  ),
                );
              } else if (_availableDates.isEmpty) {
                items.add(
                  const PopupMenuItem<String>(
                    value: '',
                    enabled: false,
                    child: Text('لا توجد يوميات سابقة'),
                  ),
                );
              } else {
                items.add(
                  const PopupMenuItem<String>(
                    value: '',
                    enabled: false,
                    child: Text(
                      'اليوميات المتاحة',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                );
                items.add(const PopupMenuDivider());

                for (var dateInfo in _availableDates) {
                  final date = dateInfo['date']!;
                  final journalNumber = dateInfo['journalNumber']!;

                  items.add(
                    PopupMenuItem<String>(
                      value: date,
                      child: Text(
                        'يومية رقم $journalNumber - تاريخ $date',
                        style: TextStyle(
                          fontWeight: date == widget.selectedDate
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: date == widget.selectedDate
                              ? Colors.red
                              : Colors.black,
                        ),
                      ),
                    ),
                  );
                }
              }

              return items;
            },
          ),
        ],
      ),
      body: _buildMainContent(),
      // إخفاء زر الإضافة عند ظهور لوحة المفاتيح
      floatingActionButton: MediaQuery.of(context).viewInsets.bottom > 0
          ? null
          : Container(
              margin: const EdgeInsets.only(bottom: 16, right: 16),
              child: Material(
                color: Colors.red[700],
                borderRadius: BorderRadius.circular(12),
                elevation: 8,
                child: InkWell(
                  onTap: _addNewRow,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 28, vertical: 16),
                    child: const Text(
                      'إضافة',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
              ),
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startDocked,
      resizeToAvoidBottomInset: true, // تغيير من false إلى true
    );
  }

  Widget _buildMainContent() {
    return _buildTableWithStickyHeader();
  }

  Widget _buildTableWithStickyHeader() {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: CustomScrollView(
        controller: _verticalScrollController,
        slivers: [
          SliverPersistentHeader(
            pinned: true,
            floating: false,
            delegate: _StickyTableHeaderDelegate(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  border: Border.all(color: Colors.grey),
                ),
                child: _buildTableHeader(),
              ),
            ),
          ),
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
                  child: _buildTableContent(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveCurrentRecord({bool silent = false}) async {
    if (_isSaving) return;

    setState(() => _isSaving = true);

    // 1. تجميع السجلات الحالية من الواجهة التي تخص البائع الحالي فقط
    final List<Purchase> currentSellerPurchasesFromUI = [];
    for (int i = 0; i < rowControllers.length; i++) {
      // فقط السجلات التي يملكها البائع الحالي هي التي يمكن تعديلها وحفظها
      if (sellerNames[i] == widget.sellerName) {
        final controllers = rowControllers[i];
        if (controllers[1].text.isNotEmpty || controllers[3].text.isNotEmpty) {
          double s = double.tryParse(controllers[5].text) ?? 0;
          double n = double.tryParse(controllers[6].text) ?? 0;
          if (s < n) {
            controllers[6].text = s.toStringAsFixed(2);
            _calculateRowValues(i);
          }

          final p = Purchase(
            material: controllers[1].text,
            affiliation: controllers[2].text.trim(),
            count: controllers[3].text,
            packaging: controllers[4].text,
            standing: controllers[5].text,
            net: controllers[6].text,
            price: controllers[7].text,
            total: controllers[8].text,
            cashOrDebt: cashOrDebtValues[i],
            sellerName: sellerNames[i],
          );
          currentSellerPurchasesFromUI.add(p);
        }
      }
    }

    // 2. منطق تحديث الأرصدة الجديد (الإلغاء ثم التطبيق)
    Map<String, double> supplierBalanceChanges = {};
    final existingDocument =
        await _storageService.loadPurchaseDocument(widget.selectedDate);

    // الخطوة أ: إلغاء أثر جميع ديون البائع القديمة في هذا اليوم
    if (existingDocument != null) {
      for (var oldPurchase in existingDocument.purchases) {
        if (oldPurchase.sellerName == widget.sellerName &&
            oldPurchase.cashOrDebt == 'دين' &&
            oldPurchase.affiliation.isNotEmpty) {
          double oldAmount = double.tryParse(oldPurchase.total) ?? 0;
          supplierBalanceChanges[oldPurchase.affiliation] =
              (supplierBalanceChanges[oldPurchase.affiliation] ?? 0) -
                  oldAmount;
        }
      }
    }

    // الخطوة ب: تطبيق أثر جميع ديون البائع الجديدة من الواجهة
    for (var newPurchase in currentSellerPurchasesFromUI) {
      if (newPurchase.cashOrDebt == 'دين' &&
          newPurchase.affiliation.isNotEmpty) {
        double newAmount = double.tryParse(newPurchase.total) ?? 0;
        supplierBalanceChanges[newPurchase.affiliation] =
            (supplierBalanceChanges[newPurchase.affiliation] ?? 0) + newAmount;
      }
    }

    // 3. بناء الوثيقة النهائية للحفظ
    // هذه الوثيقة تحتوي فقط على سجلات البائع الحالي ليتم دمجها في خدمة التخزين
    final documentToSave = PurchaseDocument(
      recordNumber: serialNumber,
      date: widget.selectedDate,
      sellerName: widget.sellerName, // إرسال اسم البائع الحالي
      storeName: widget.storeName,
      dayName: dayName,
      purchases: currentSellerPurchasesFromUI, // إرسال سجلات البائع الحالي فقط
      totals: {}, // سيتم حساب المجاميع النهائية في خدمة التخزين
    );

    // 4. الحفظ في الملف وتحديث الأرصدة
    // دالة savePurchaseDocument ستقوم بدمج هذه السجلات مع سجلات الباعة الآخرين
    final success = await _storageService.savePurchaseDocument(documentToSave);

    if (success) {
      // تطبيق التغييرات الصافية على أرصدة الموردين
      for (var entry in supplierBalanceChanges.entries) {
        if (entry.value != 0) {
          await _supplierIndexService.updateSupplierBalance(
              entry.key, entry.value);
        }
      }
      setState(() => _hasUnsavedChanges = false);
      await _loadOrCreateJournal(); // تحديث الواجهة والـ sellerNames
    }

    setState(() => _isSaving = false);
    if (!silent && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(success ? 'تم الحفظ بنجاح' : 'فشل الحفظ'),
          backgroundColor: success ? Colors.green : Colors.red));
    }
  }

  Future<bool> _showUnsavedChangesDialog() async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('تغييرات غير محفوظة'),
            content: const Text(
              'هناك تغييرات غير محفوظة. هل تريد حفظها قبل الانتقال؟',
              textAlign: TextAlign.center,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('تجاهل'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('حفظ'),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _showInlineWarning(int rowIndex, String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _loadJournalNumber() async {
    try {
      final journalNumber =
          await _storageService.getJournalNumberForDate(widget.selectedDate);
      setState(() {
        serialNumber = journalNumber;
        _currentJournalNumber = journalNumber;
      });
    } catch (e) {
      setState(() {
        serialNumber = '1'; // الرقم الافتراضي
        _currentJournalNumber = '1';
      });
    }
  }

  // دالة مساعدة لإخفاء جميع الاقتراحات
  void _clearAllSuggestions() {
    if (_materialSuggestions.isNotEmpty ||
        _packagingSuggestions.isNotEmpty ||
        _supplierSuggestions.isNotEmpty) {
      setState(() {
        _materialSuggestions = [];
        _packagingSuggestions = [];
        _supplierSuggestions = [];
        _activeMaterialRowIndex = null;
        _activePackagingRowIndex = null;
        _activeSupplierRowIndex = null;
      });
    }
  }

  void _toggleFullScreenSuggestions(
      {required String type, required bool show}) {
    if (mounted) {
      setState(() {
        _showFullScreenSuggestions = show;
        _currentSuggestionType = show ? type : '';
      });
    }
  }

  List<String> _getSuggestionsByType() {
    switch (_currentSuggestionType) {
      case 'material':
        return _materialSuggestions;
      case 'packaging':
        return _packagingSuggestions;
      case 'supplier':
        return _supplierSuggestions;

      default:
        return [];
    }
  }

  int _getCurrentRowIndexByType() {
    switch (_currentSuggestionType) {
      case 'material':
        return _activeMaterialRowIndex ?? -1;
      case 'packaging':
        return _activePackagingRowIndex ?? -1;
      case 'supplier':
        return _activeSupplierRowIndex ?? -1;

      default:
        return -1;
    }
  }

  Future<void> _checkAdminStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final adminSeller = prefs.getString('admin_seller');
    if (mounted) {
      setState(() {
        _isAdmin = (widget.sellerName == adminSeller);
      });
    }
  }

// 1. إضافة دالة التحقق من الصلاحية
  bool _canEditRow(int rowIndex) {
    if (rowIndex >= sellerNames.length) {
      return true; // صف جديد لم يحفظ بعد
    }
    if (_isAdmin) {
      return true; // الأدمن يمكنه تعديل أي شيء
    }
    // البائع العادي يعدل سجلاته فقط
    return sellerNames[rowIndex] == widget.sellerName;
  }

  // --- دالة توليد PDF والمشاركة (PurchasesScreen) ---
  Future<void> _generateAndSharePdf() async {
    try {
      final pdf = pw.Document();

      var arabicFont;
      try {
        final fontData =
            await rootBundle.load("assets/fonts/Cairo-Regular.ttf");
        arabicFont = pw.Font.ttf(fontData);
      } catch (e) {
        arabicFont = pw.Font.courier();
      }

      // حساب المجاميع من الصفوف الفعلية
      double totalCount = 0;
      double totalBase = 0;
      double totalNet = 0;
      double totalGrand = 0;

      for (var controllers in rowControllers) {
        totalCount += double.tryParse(controllers[3].text) ?? 0; // العدد
        totalBase += double.tryParse(controllers[5].text) ?? 0; // القائم
        totalNet += double.tryParse(controllers[6].text) ?? 0; // الصافي
        totalGrand += double.tryParse(controllers[8].text) ?? 0; // الإجمالي
      }

      final PdfColor headerColor = PdfColor.fromInt(0xFFD32F2F);
      final PdfColor headerTextColor = PdfColors.white;
      final PdfColor rowEvenColor = PdfColors.white;
      final PdfColor rowOddColor = PdfColor.fromInt(0xFFFFCDD2);
      final PdfColor borderColor = PdfColor.fromInt(0xFFE0E0E0);
      final PdfColor totalRowColor = PdfColor.fromInt(0xFFEF9A9A);

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          orientation: pw.PageOrientation.landscape,
          textDirection: pw.TextDirection.rtl,
          theme: pw.ThemeData.withFont(base: arabicFont, bold: arabicFont),
          build: (pw.Context context) {
            return [
              pw.Directionality(
                textDirection: pw.TextDirection.rtl,
                child: pw.Column(
                  children: [
                    pw.Center(
                        child: pw.Text('يومية مشتريات رقم /$serialNumber/',
                            style: pw.TextStyle(
                                fontSize: 16, fontWeight: pw.FontWeight.bold))),
                    pw.Center(
                        child: pw.Text(
                            'تاريخ ${widget.selectedDate} - البائع ${widget.sellerName}',
                            style: const pw.TextStyle(
                                fontSize: 12, color: PdfColors.grey700))),
                    pw.SizedBox(height: 10),
                    pw.Table(
                      border:
                          pw.TableBorder.all(color: borderColor, width: 0.5),
                      columnWidths: {
                        0: const pw.FlexColumnWidth(3), // الإجمالي
                        1: const pw.FlexColumnWidth(2), // السعر
                        2: const pw.FlexColumnWidth(2), // الصافي
                        3: const pw.FlexColumnWidth(2), // القائم
                        4: const pw.FlexColumnWidth(3), // العبوة
                        5: const pw.FlexColumnWidth(2), // العدد
                        6: const pw.FlexColumnWidth(3), // المورد
                        7: const pw.FlexColumnWidth(4), // المادة
                        8: const pw.FlexColumnWidth(2), // نوع
                      },
                      children: [
                        // رأس الجدول (معكوس)
                        pw.TableRow(
                          decoration: pw.BoxDecoration(color: headerColor),
                          children: [
                            _buildPdfHeaderCell('الإجمالي', headerTextColor),
                            _buildPdfHeaderCell('السعر', headerTextColor),
                            _buildPdfHeaderCell('الصافي', headerTextColor),
                            _buildPdfHeaderCell('القائم', headerTextColor),
                            _buildPdfHeaderCell('العبوة', headerTextColor),
                            _buildPdfHeaderCell('العدد', headerTextColor),
                            _buildPdfHeaderCell('المورد', headerTextColor),
                            _buildPdfHeaderCell('المادة', headerTextColor),
                            _buildPdfHeaderCell('نوع', headerTextColor),
                          ],
                        ),
                        // صفوف البيانات (معكوسة)
                        ...rowControllers.asMap().entries.map((entry) {
                          final index = entry.key;
                          final controllers = entry.value;
                          if (controllers[1].text.isEmpty &&
                              controllers[3].text.isEmpty) {
                            return pw.TableRow(
                                children: List.filled(9, pw.SizedBox()));
                          }
                          final color =
                              index % 2 == 0 ? rowEvenColor : rowOddColor;
                          return pw.TableRow(
                            decoration: pw.BoxDecoration(color: color),
                            children: [
                              _buildPdfCell(controllers[8].text,
                                  isBold: true), // الإجمالي
                              _buildPdfCell(controllers[7].text), // السعر
                              _buildPdfCell(controllers[6].text), // الصافي
                              _buildPdfCell(controllers[5].text), // القائم
                              _buildPdfCell(controllers[4].text), // العبوة
                              _buildPdfCell(controllers[3].text), // العدد
                              _buildPdfCell(controllers[2].text), // المورد
                              _buildPdfCell(controllers[1].text), // المادة
                              _buildPdfCell(cashOrDebtValues[index]), // نوع
                            ],
                          );
                        }).toList(),
                        // سطر المجاميع (معكوس)
                        pw.TableRow(
                          decoration: pw.BoxDecoration(color: totalRowColor),
                          children: [
                            _buildPdfCell(totalGrand.toStringAsFixed(2),
                                isBold: true),
                            _buildPdfCell(''),
                            _buildPdfCell(totalNet.toStringAsFixed(2),
                                isBold: true),
                            _buildPdfCell(totalBase.toStringAsFixed(2),
                                isBold: true),
                            _buildPdfCell(''),
                            _buildPdfCell(totalCount.toStringAsFixed(0),
                                isBold: true),
                            _buildPdfCell(''),
                            _buildPdfCell('المجموع', isBold: true),
                            _buildPdfCell(''),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ];
          },
        ),
      );

      final output = await getTemporaryDirectory();
      final safeDate = widget.selectedDate.replaceAll('/', '-');
      final file = File("${output.path}/يومية_مشتريات_$safeDate.pdf");

      await file.writeAsBytes(await pdf.save());
      await Share.shareXFiles([XFile(file.path)],
          text: 'يومية مشتريات ${widget.selectedDate}');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red));
    }
  }

  pw.Widget _buildPdfHeaderCell(String text, PdfColor color) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(4),
      alignment: pw.Alignment.center,
      child: pw.Text(text,
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(
              color: color, fontSize: 8, fontWeight: pw.FontWeight.bold)),
    );
  }

  pw.Widget _buildPdfCell(String text, {bool isBold = false}) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(4),
      alignment: pw.Alignment.center,
      child: pw.Text(text,
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(
              fontSize: 8,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal)),
    );
  }

  Future<void> _loadGrandTotal() async {
    double total = 0.0;
    for (var dateInfo in _availableDates) {
      final doc = await _storageService.loadPurchaseDocument(dateInfo['date']!);
      if (doc != null) {
        total += double.tryParse(doc.totals['totalGrand'] ?? '0') ?? 0;
      }
    }
    if (mounted) setState(() => _grandTotal = total);
  }
}

class _StickyTableHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;

  _StickyTableHeaderDelegate({required this.child});

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return SizedBox.expand(child: child);
  }

  @override
  double get maxExtent => 32.0;

  @override
  double get minExtent => 32.0;

  @override
  bool shouldRebuild(_StickyTableHeaderDelegate oldDelegate) {
    return child != oldDelegate.child;
  }
}
