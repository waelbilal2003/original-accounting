import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/sales_model.dart';
import '../../services/sales_storage_service.dart';
// استيراد خدمات الفهرس
import '../../services/material_index_service.dart';
import '../../services/packaging_index_service.dart';
import '../../services/customer_index_service.dart';
import '../../services/enhanced_index_service.dart';

import '../../widgets/table_builder.dart' as TableBuilder;
import '../../widgets/table_components.dart' as TableComponents;
import '../../widgets/common_dialogs.dart' as CommonDialogs;

import 'package:flutter/foundation.dart';

import 'dart:async';
import '../../widgets/suggestions_banner.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

class SalesScreen extends StatefulWidget {
  final String sellerName;
  final String selectedDate;
  final String storeName;

  const SalesScreen({
    Key? key,
    required this.sellerName,
    required this.selectedDate,
    required this.storeName,
  }) : super(key: key);

  @override
  _SalesScreenState createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  // خدمة التخزين
  final SalesStorageService _storageService = SalesStorageService();

  // خدمات الفهرس
  final MaterialIndexService _materialIndexService = MaterialIndexService();
  final PackagingIndexService _packagingIndexService = PackagingIndexService();
  final CustomerIndexService _customerIndexService = CustomerIndexService();
  // بيانات الحقول
  String dayName = '';

  // قائمة لتخزين صفوف الجدول
  List<List<TextEditingController>> rowControllers = [];
  List<List<FocusNode>> rowFocusNodes = [];
  List<String> cashOrDebtValues = [];
  List<String> emptiesValues = [];
  List<String> customerNames = [];
  List<String> sellerNames = []; // <-- تخزين اسم البائع لكل صف

  // متحكمات صف المجموع
  late TextEditingController totalCountController;
  late TextEditingController totalBaseController;
  late TextEditingController totalNetController;
  late TextEditingController totalGrandController;

  // قوائم الخيارات
  final List<String> cashOrDebtOptions = ['نقدي', 'دين'];
  final List<String> emptiesOptions = ['مع فوارغ', 'بدون فوارغ'];

  // متحكمات للتمرير
  final ScrollController _verticalScrollController = ScrollController();
  final ScrollController _horizontalScrollController = ScrollController();
  final _scrollController = ScrollController(); // للتمرير
  // حالة الحفظ
  bool _isSaving = false;
  bool _hasUnsavedChanges = false;

  // التواريخ المتاحة
  List<Map<String, String>> _availableRecords = [];
  bool _isLoadingRecords = false;

  String serialNumber = '';

  // متغيرات للاقتراحات
  List<String> _materialSuggestions = [];
  List<String> _packagingSuggestions = [];
  List<String> _supplierSuggestions = [];
  List<String> _customerSuggestions = [];

  // مؤشرات الصفوف النشطة للاقتراحات
  int? _activeMaterialRowIndex;
  int? _activePackagingRowIndex;
  int? _activeSupplierRowIndex;
  int? _activeCustomerRowIndex;
// متغير لتتبع ما إذا كان يجب عرض الاقتراحات على كامل الشاشة
  bool _showFullScreenSuggestions = false;
  String _currentSuggestionType = '';

  late ScrollController _horizontalSuggestionsController;
  bool _isAdmin = false;

  // أضف مع المتغيرات الأخرى
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

    // تهيئة متحكم الاقتراحات الأفقية
    _horizontalSuggestionsController = ScrollController();

    // إخفاء الاقتراحات عند التمرير
    _verticalScrollController.addListener(() {
      _hideAllSuggestionsImmediately();
    });

    _horizontalScrollController.addListener(() {
      _hideAllSuggestionsImmediately();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAdminStatus();
      _loadOrCreateRecord();
      _loadAvailableDates();
      _loadJournalNumber();
    });
  }

  @override
  void dispose() {
    // حفظ جميع التغييرات بما فيها حقل نقدي/دين عند الخروج
    if (_hasUnsavedChanges) {
      _saveCurrentRecord(silent: true);
    }

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

    _horizontalSuggestionsController.dispose();

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

  // تحميل السجل إذا كان موجوداً، أو إنشاء جديد
  Future<void> _loadOrCreateRecord() async {
    final document =
        await _storageService.loadSalesDocument(widget.selectedDate);

    if (document != null && document.sales.isNotEmpty) {
      // تحميل اليومية الموجودة
      _loadDocument(document);
    } else {
      // إنشاء يومية جديدة
      _createNewRecord();
    }
  }

  void _resetTotalValues() {
    totalCountController.text = '0';
    totalBaseController.text = '0.00';
    totalNetController.text = '0.00';
    totalGrandController.text = '0.00';
  }

  void _createNewRecord() {
    setState(() {
      // لا نحدد الرقم هنا، بل سيتم تعيينه عند الحفظ لأول مرة
      // الدالة _loadJournalNumber ستهتم بعرض الرقم الصحيح في الواجهة
      serialNumber = '1'; // عرض رقم افتراضي مؤقتاً

      rowControllers.clear();
      rowFocusNodes.clear();
      cashOrDebtValues.clear();
      emptiesValues.clear();
      customerNames.clear();
      sellerNames.clear();
      _resetTotalValues();
      _hasUnsavedChanges = false;
      _addNewRow();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (rowFocusNodes.isNotEmpty && rowFocusNodes[0].length > 0) {
        // التركيز على حقل المادة (index 0) بدلاً من العدد (index 1)
        FocusScope.of(context).requestFocus(rowFocusNodes[0][0]);
      }
    });
  }

  void _addNewRow() {
    setState(() {
      List<TextEditingController> newControllers =
          List.generate(8, (index) => TextEditingController());

      List<FocusNode> newFocusNodes = List.generate(8, (index) => FocusNode());

      // إضافة مستمعات للتغيير
      _addChangeListenersToControllers(newControllers, rowControllers.length);

      sellerNames.add(widget.sellerName);
      rowControllers.add(newControllers);
      rowFocusNodes.add(newFocusNodes);
      cashOrDebtValues.add('');
      emptiesValues.add('');
      customerNames.add('');
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (rowFocusNodes.isNotEmpty) {
        final newRowIndex = rowFocusNodes.length - 1;
        if (rowFocusNodes[newRowIndex].isNotEmpty) {
          // التركيز على حقل المادة (index 0) بدلاً من العدد (index 1)
          FocusScope.of(context).requestFocus(rowFocusNodes[newRowIndex][0]);
        }
      }
    });
  }

  void _addChangeListenersToControllers(
      List<TextEditingController> controllers, int rowIndex) {
    // المادة (index 0)
    controllers[0].addListener(() {
      _hasUnsavedChanges = true;
      _updateMaterialSuggestions(rowIndex);
    });

    // العدد (index 1)
    controllers[1].addListener(() {
      _hasUnsavedChanges = true;
      _calculateRowValues(rowIndex);
      _calculateAllTotals();
    });

    // العبوة (index 2)
    controllers[2].addListener(() {
      _hasUnsavedChanges = true;
      _updatePackagingSuggestions(rowIndex);
    });

    // القائم (index 3)
    controllers[3].addListener(() {
      _hasUnsavedChanges = true;
      _validateStandingAndNet(rowIndex);
      _calculateRowValues(rowIndex);
      _calculateAllTotals();
    });

    // الصافي (index 4)
    controllers[4].addListener(() {
      _hasUnsavedChanges = true;
      _validateStandingAndNet(rowIndex);
      _calculateRowValues(rowIndex);
      _calculateAllTotals();
    });

    // السعر (index 5)
    controllers[5].addListener(() {
      _hasUnsavedChanges = true;
      _calculateRowValues(rowIndex);
      _calculateAllTotals();
    });

    // اسم الزبون (index 7) — للاقتراحات
    controllers[7].addListener(() {
      _hasUnsavedChanges = true;
      _updateCustomerSuggestions(rowIndex);
    });
  }

  // تحديث اقتراحات المادة - مثل purchases_screen بالضبط
  void _updateMaterialSuggestions(int rowIndex) async {
    final query = rowControllers[rowIndex][0].text;
    if (query.length >= 3) {
      // تغيير من 1 إلى 3
      final suggestions =
          await getEnhancedSuggestions(_materialIndexService, query);
      if (mounted) {
        setState(() {
          _materialSuggestions = suggestions;
          _activeMaterialRowIndex = rowIndex;
          if (suggestions.isNotEmpty) {
            _toggleFullScreenSuggestions(type: 'material', show: true);
          } else {
            _toggleFullScreenSuggestions(type: 'material', show: false);
          }
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _materialSuggestions = [];
          _activeMaterialRowIndex = null;
          _toggleFullScreenSuggestions(type: 'material', show: false);
        });
      }
    }
  }

  // تحديث اقتراحات العبوة - مثل purchases_screen بالضبط
  void _updatePackagingSuggestions(int rowIndex) async {
    final query = rowControllers[rowIndex][2].text;
    if (query.length >= 3) {
      // تغيير من 1 إلى 3
      final suggestions =
          await getEnhancedSuggestions(_packagingIndexService, query);
      if (mounted) {
        setState(() {
          _packagingSuggestions = suggestions;
          _activePackagingRowIndex = rowIndex;
          if (suggestions.isNotEmpty) {
            _toggleFullScreenSuggestions(type: 'packaging', show: true);
          } else {
            _toggleFullScreenSuggestions(type: 'packaging', show: false);
          }
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _packagingSuggestions = [];
          _activePackagingRowIndex = null;
          _toggleFullScreenSuggestions(type: 'packaging', show: false);
        });
      }
    }
  }

  // 1. اختيار اقتراح للمادة
  void _selectMaterialSuggestion(String suggestion, int rowIndex) {
    // التأكد من أن الصف لا يزال موجوداً
    if (rowIndex >= rowControllers.length) return;

    // أولاً: إخفاء نافذة الاقتراحات
    _toggleFullScreenSuggestions(type: 'material', show: false);

    // ثانياً: تعيين النص في المتحكم مباشرة (لا حاجة لـ setState هنا)
    rowControllers[rowIndex][0].text = suggestion;

    // ثالثاً: تحديث حالة "التغييرات غير المحفوظة" (هنا نحتاج setState)
    setState(() {
      _hasUnsavedChanges = true;
    });

    // رابعاً: حفظ المادة في الفهرس
    if (suggestion.trim().length > 1) {
      _saveMaterialToIndex(suggestion);
    }

    // خامساً: نقل التركيز إلى حقل العدد (index 1) بعد تأخير بسيط
    Future.delayed(const Duration(milliseconds: 50), () {
      if (mounted && rowIndex < rowFocusNodes.length) {
        if (rowFocusNodes[rowIndex].length > 1) {
          FocusScope.of(context).requestFocus(rowFocusNodes[rowIndex][1]);
        }
      }
    });
  }

// 2. اختيار اقتراح للعبوة
  void _selectPackagingSuggestion(String suggestion, int rowIndex) {
    // التأكد من أن الصف لا يزال موجوداً
    if (rowIndex >= rowControllers.length) return;

    // أولاً: إخفاء نافذة الاقتراحات
    _toggleFullScreenSuggestions(type: 'packaging', show: false);

    // ثانياً: تعيين النص في المتحكم مباشرة
    rowControllers[rowIndex][2].text = suggestion;

    // ثالثاً: تحديث حالة "التغييرات غير المحفوظة"
    setState(() {
      _hasUnsavedChanges = true;
    });

    // رابعاً: حفظ العبوة في الفهرس
    if (suggestion.trim().length > 1) {
      _savePackagingToIndex(suggestion);
    }

    // خامساً: نقل التركيز إلى حقل القائم (index 3) بعد تأخير بسيط
    Future.delayed(const Duration(milliseconds: 50), () {
      if (mounted && rowIndex < rowFocusNodes.length) {
        if (rowFocusNodes[rowIndex].length > 3) {
          FocusScope.of(context).requestFocus(rowFocusNodes[rowIndex][3]);
        }
      }
    });
  }

// 4. اختيار اقتراح للزبون
  void _selectCustomerSuggestion(String suggestion, int rowIndex) {
    if (rowIndex >= rowControllers.length) return;

    _toggleFullScreenSuggestions(type: 'customer', show: false);

    rowControllers[rowIndex][7].text = suggestion;

    setState(() {
      customerNames[rowIndex] = suggestion; // ✅ حفظ الاسم فوراً
      _hasUnsavedChanges = true;
    });

    if (suggestion.trim().length > 1) {
      _saveCustomerToIndex(suggestion);
    }

    // بعد اختيار الزبون من الاقتراحات → إنشاء صف جديد مباشرة (بدون نافذة فوارغ)
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        _addNewRow();
        final newRowIndex = rowControllers.length - 1;
        if (newRowIndex < rowFocusNodes.length &&
            rowFocusNodes[newRowIndex].isNotEmpty) {
          FocusScope.of(context).requestFocus(rowFocusNodes[newRowIndex][0]);
          _scrollToField(newRowIndex, 0);
        }
      }
    });
  }

  // حفظ المادة في الفهرس
  void _saveMaterialToIndex(String material) {
    final trimmedMaterial = material.trim();
    if (trimmedMaterial.length >= 3) {
      _materialIndexService.saveMaterial(trimmedMaterial);
    }
  }

  // حفظ العبوة في الفهرس
  void _savePackagingToIndex(String packaging) {
    final trimmedPackaging = packaging.trim();
    if (trimmedPackaging.length >= 3) {
      _packagingIndexService.savePackaging(trimmedPackaging);
    }
  }

  // تعديل _validateStandingAndNet
  void _validateStandingAndNet(int rowIndex) {
    if (rowIndex >= rowControllers.length) return;
    final controllers = rowControllers[rowIndex];
    try {
      double standing = double.tryParse(controllers[3].text) ?? 0;
      double net = double.tryParse(controllers[4].text) ?? 0;
      if (standing < net) {
        controllers[4].text = standing.toStringAsFixed(2);
        _showInlineWarning(rowIndex, 'الصافي لا يمكن أن يكون أكبر من القائم');
        _calculateRowValues(rowIndex);
        _calculateAllTotals();
      }
    } catch (e) {}
  }

  // تحسين _calculateRowValues
  void _calculateRowValues(int rowIndex) {
    if (rowIndex >= rowControllers.length) return;
    final controllers = rowControllers[rowIndex];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          try {
            double count = (double.tryParse(controllers[1].text) ?? 0).abs();
            double net = (double.tryParse(controllers[4].text) ?? 0).abs();
            double price = (double.tryParse(controllers[5].text) ?? 0).abs();
            double baseValue = net > 0 ? net : count;
            double total = baseValue * price;
            controllers[6].text = total.toStringAsFixed(2);
          } catch (e) {
            controllers[6].text = '';
          }
        });
      }
    });
  }

  void _calculateAllTotals() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          double totalCount = 0, totalBase = 0, totalNet = 0, totalGrand = 0;
          for (var controllers in rowControllers) {
            try {
              totalCount += double.tryParse(controllers[1].text) ?? 0;
              totalBase += double.tryParse(controllers[3].text) ?? 0;
              totalNet += double.tryParse(controllers[4].text) ?? 0;
              totalGrand += double.tryParse(controllers[6].text) ?? 0;
            } catch (e) {}
          }
          totalCountController.text = totalCount.toStringAsFixed(0);
          totalBaseController.text = totalBase.toStringAsFixed(2);
          totalNetController.text = totalNet.toStringAsFixed(2);
          totalGrandController.text = totalGrand.toStringAsFixed(2);
        });
      }
    });
  }

  void _loadDocument(SalesDocument document) {
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
      customerNames.clear();
      sellerNames.clear();

      serialNumber = document.recordNumber;

      // تحميل السجلات من الوثيقة
      for (int i = 0; i < document.sales.length; i++) {
        var sale = document.sales[i];

        List<TextEditingController> newControllers = [
          TextEditingController(text: sale.material), // [0]
          TextEditingController(text: sale.count), // [1]
          TextEditingController(text: sale.packaging), // [2]
          TextEditingController(text: sale.standing), // [3]
          TextEditingController(text: sale.net), // [4]
          TextEditingController(text: sale.price), // [5]
          TextEditingController(text: sale.total), // [6]
          TextEditingController(), // [7] placeholder نقدي/دين
          TextEditingController(), // [8] placeholder الفوارغ
          TextEditingController(), // [9] placeholder اسم الزبون
        ];

        List<FocusNode> newFocusNodes =
            List.generate(8, (index) => FocusNode());

        // تخزين اسم البائع لهذا الصف
        sellerNames.add(sale.sellerName);

        // التحقق إذا كان السجل مملوكاً للبائع الحالي
        final bool isOwnedByCurrentSeller =
            sale.sellerName == widget.sellerName;

        // إضافة مستمعات للتغيير فقط إذا كان السجل مملوكاً للبائع الحالي
        if (isOwnedByCurrentSeller) {
          _addChangeListenersToControllers(newControllers, i);
        }

        rowControllers.add(newControllers);
        rowFocusNodes.add(newFocusNodes);
        cashOrDebtValues.add(sale.cashOrDebt);
        emptiesValues.add(sale.empties);
        customerNames.add(sale.customerName ?? '');
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
  }

  void _scrollToField(int rowIndex, int colIndex) {
    const double headerHeight = 32.0;
    const double rowHeight = 25.0;
    final double verticalPosition = (rowIndex * rowHeight);
    const double columnWidth = 60.0;
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
            TableComponents.buildTableHeaderCell('العدد'),
            TableComponents.buildTableHeaderCell('العبوة'),
            TableComponents.buildTableHeaderCell('القائم'),
            TableComponents.buildTableHeaderCell('الصافي'),
            TableComponents.buildTableHeaderCell('السعر'),
            TableComponents.buildTableHeaderCell('الإجمالي'),
            TableComponents.buildTableHeaderCell('نقدي أو دين'),
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
            _buildMaterialCell(rowControllers[i][0], rowFocusNodes[i][0], i, 0,
                isOwnedByCurrentSeller),
            _buildTableCell(rowControllers[i][1], rowFocusNodes[i][1], i, 1,
                isOwnedByCurrentSeller),
            _buildPackagingCell(rowControllers[i][2], rowFocusNodes[i][2], i, 2,
                isOwnedByCurrentSeller),
            _buildTableCell(rowControllers[i][3], rowFocusNodes[i][3], i, 3,
                isOwnedByCurrentSeller),
            _buildTableCell(rowControllers[i][4], rowFocusNodes[i][4], i, 4,
                isOwnedByCurrentSeller),
            _buildTableCell(rowControllers[i][5], rowFocusNodes[i][5], i, 5,
                isOwnedByCurrentSeller),
            TableComponents.buildTotalValueCell(rowControllers[i][6]),
            _buildCashOrDebtCell(i, 7, isOwnedByCurrentSeller),
          ],
        ),
      );
    }

    if (rowControllers.length >= 2) {
      contentRows.add(
        TableRow(
          decoration: BoxDecoration(color: Colors.yellow[50]),
          children: [
            _buildEmptyCell(),
            TableComponents.buildTotalCell(totalCountController),
            _buildEmptyCell(),
            TableComponents.buildTotalCell(totalBaseController),
            TableComponents.buildTotalCell(totalNetController),
            _buildEmptyCell(),
            TableComponents.buildTotalCell(totalGrandController),
            _buildEmptyCell(),
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

    // تحديد الحقول الرقمية فقط (العدد، القائم، الصافي، السعر)
    bool isNumericField =
        colIndex == 1 || colIndex == 3 || colIndex == 4 || colIndex == 5;

    // إضافة فلتر للأرقام فقط للحقول الرقمية
    List<TextInputFormatter>? inputFormatters;
    if (isNumericField) {
      inputFormatters = [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
        FilteringTextInputFormatter.deny(RegExp(r'^0\d+')),
        TableComponents.PositiveDecimalInputFormatter(),
      ];
    }

    Widget cell = TableBuilder.buildTableCell(
      controller: controller,
      focusNode: focusNode,
      enabled: enabled,
      isSerialField: false, // لا نجعل أي حقل تسلسلي
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

    if (!_canEditRow(rowIndex)) {
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
      isSerialField: false, // مهم: ليست تسلسلية
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

  void _handleFieldSubmitted(String value, int rowIndex, int colIndex) {
    if (!_canEditRow(rowIndex)) return;

    if (colIndex == 0) {
      // لا نحفظ الكلمات الأقل من 3 أحرف
      if (value.trim().length >= 3) {
        _saveMaterialToIndex(value);
      }
      if (_materialSuggestions.isNotEmpty) {
        _selectMaterialSuggestion(_materialSuggestions[0], rowIndex);
        return;
      }
      if (rowFocusNodes[rowIndex].length > 1) {
        FocusScope.of(context).requestFocus(rowFocusNodes[rowIndex][1]);
      }
    } else if (colIndex == 2) {
      // لا نحفظ الكلمات الأقل من 3 أحرف
      if (value.trim().length >= 3) {
        _savePackagingToIndex(value);
      }
      if (_packagingSuggestions.isNotEmpty) {
        _selectPackagingSuggestion(_packagingSuggestions[0], rowIndex);
        return;
      }
      if (rowFocusNodes[rowIndex].length > 3) {
        FocusScope.of(context).requestFocus(rowFocusNodes[rowIndex][3]);
      }
    } else if (colIndex == 5) {
      _showCashOrDebtDialog(rowIndex);
    } else if (colIndex == 7) {
      // ✅ حفظ اسم الزبون فقط إذا كان طوله 3 أحرف أو أكثر
      final customerName = rowControllers[rowIndex][7].text.trim();
      if (customerName.isNotEmpty) {
        setState(() {
          customerNames[rowIndex] = customerName;
          _hasUnsavedChanges = true;
        });
        if (customerName.length >= 3) {
          _saveCustomerToIndex(customerName);
        }
      }
      // ✅ إنشاء صف جديد مباشرة بدون نافذة فوارغ
      _addNewRow();
      if (rowControllers.isNotEmpty) {
        final newRowIndex = rowControllers.length - 1;
        Future.delayed(const Duration(milliseconds: 50), () {
          if (mounted && newRowIndex < rowFocusNodes.length) {
            if (rowFocusNodes[newRowIndex].isNotEmpty) {
              FocusScope.of(context)
                  .requestFocus(rowFocusNodes[newRowIndex][0]);
              _scrollToField(newRowIndex, 0);
            }
          }
        });
      }
    } else if (colIndex < 7 && rowFocusNodes[rowIndex].length > colIndex + 1) {
      FocusScope.of(context)
          .requestFocus(rowFocusNodes[rowIndex][colIndex + 1]);
    }
    _hideAllSuggestionsImmediately();
  }

  void _handleFieldChanged(String value, int rowIndex, int colIndex) {
    // التحقق إذا كان السجل مملوكاً للبائع الحالي
    if (!_canEditRow(rowIndex)) {
      return;
    }

    setState(() {
      _hasUnsavedChanges = true;

      // إزالة الترقيم التلقائي لحقل المادة
      // لا نقوم بتحديث أي شيء تلقائياً في حقل المادة

      // إذا بدأ المستخدم بالكتابة في حقل آخر، إخفاء اقتراحات الحقول الأخرى
      if (colIndex == 1 && _activeMaterialRowIndex != rowIndex) {
        _clearAllSuggestions();
      } else if (colIndex == 2 && _activeSupplierRowIndex != rowIndex) {
        _clearAllSuggestions();
      } else if (colIndex == 5 && _activePackagingRowIndex != rowIndex) {
        _clearAllSuggestions();
      } else if (colIndex == 10 && _activeCustomerRowIndex != rowIndex) {
        _clearAllSuggestions();
      }
    });
  }

  Widget _buildEmptyCell() {
    return Container(
      padding: const EdgeInsets.all(1),
      constraints: const BoxConstraints(minHeight: 25),
      child: TextField(
        controller: TextEditingController()..text = '',
        focusNode: FocusNode(),
        enabled: false,
        decoration: const InputDecoration(
          contentPadding: EdgeInsets.symmetric(horizontal: 2, vertical: 1),
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildCashOrDebtCell(
      int rowIndex, int colIndex, bool isOwnedByCurrentSeller) {
    Widget cell = TableBuilder.buildCashOrDebtCell(
      rowIndex: rowIndex,
      colIndex: colIndex,
      cashOrDebtValue: cashOrDebtValues[rowIndex],
      customerName: customerNames[rowIndex],
      customerController: rowControllers[rowIndex][7], // استخدام فهرس مناسب
      focusNode: rowFocusNodes[rowIndex][colIndex],
      hasUnsavedChanges: _hasUnsavedChanges,
      setHasUnsavedChanges: (value) =>
          setState(() => _hasUnsavedChanges = value),
      onTap: () => _showCashOrDebtDialog(rowIndex),
      scrollToField: _scrollToField,
      onCustomerNameChanged: (value) {
        setState(() {
          customerNames[rowIndex] = value;
          _hasUnsavedChanges = true;
        });
        _updateCustomerSuggestions(rowIndex);
      },
      onCustomerSubmitted: (value, rIndex, cIndex) {
        _handleFieldSubmitted(value, rIndex, cIndex);
      },
      isSalesScreen: true,
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
    // التحقق إذا كان السجل مملوكاً للبائع الحالي
    if (!_canEditRow(rowIndex)) return;

    CommonDialogs.showCashOrDebtDialog(
      context: context,
      currentValue: cashOrDebtValues[rowIndex],
      options: cashOrDebtOptions,
      onSelected: (value) {
        setState(() {
          cashOrDebtValues[rowIndex] = value;
          _hasUnsavedChanges = true;

          if (value == 'نقدي') {
            customerNames[rowIndex] = '';
            // إضافة صف جديد بعد اختيار نقدي
            _addNewRow();
            if (rowControllers.isNotEmpty) {
              final newRowIndex = rowControllers.length - 1;
              Future.delayed(const Duration(milliseconds: 100), () {
                if (mounted && newRowIndex < rowFocusNodes.length) {
                  // التركيز على حقل المادة في الصف الجديد
                  if (rowFocusNodes[newRowIndex].isNotEmpty) {
                    FocusScope.of(context)
                        .requestFocus(rowFocusNodes[newRowIndex][0]);
                    _scrollToField(newRowIndex, 0);
                  }
                }
              });
            }
          } else if (value == 'دين') {
            // تفريغ اسم الزبون القديم
            customerNames[rowIndex] = '';
            rowControllers[rowIndex][7].text = '';
            // التركيز على حقل اسم الزبون (index 7)
            Future.delayed(const Duration(milliseconds: 100), () {
              if (mounted && rowIndex < rowFocusNodes.length) {
                if (rowFocusNodes[rowIndex].length > 7) {
                  FocusScope.of(context)
                      .requestFocus(rowFocusNodes[rowIndex][7]);
                  _updateCustomerSuggestions(rowIndex);
                }
              }
            });
          }
        });
      },
      onCancel: () {
        // إلغاء - التركيز على حقل السعر (index 5)
        if (mounted && rowIndex < rowFocusNodes.length) {
          if (rowFocusNodes[rowIndex].length > 5) {
            FocusScope.of(context).requestFocus(rowFocusNodes[rowIndex][5]);
          }
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
                  if (_currentSuggestionType == 'customer')
                    _selectCustomerSuggestion(val, idx);
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
                    'المبيعات - ${widget.selectedDate}',
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
                            color: Colors.lightGreenAccent,
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
        backgroundColor: Colors.orange[700],
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
                    builder: (context) => SalesScreen(
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

              if (_isLoadingRecords) {
                items.add(
                  const PopupMenuItem<String>(
                    value: '',
                    enabled: false,
                    child: Center(child: Text('جاري التحميل...')),
                  ),
                );
              } else if (_availableRecords.isEmpty) {
                items.add(
                  const PopupMenuItem<String>(
                    value: '',
                    enabled: false,
                    child: Center(child: Text('لا توجد يوميات سابقة')),
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

                for (var record in _availableRecords) {
                  final date = record['date']!;
                  final journalNumber = record['journalNumber']!;

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
                              ? Colors.orange
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
      // التعديل هنا: إذا كان ارتفاع لوحة المفاتيح أكبر من 0، نعيد null لإخفاء الزر
      floatingActionButton: MediaQuery.of(context).viewInsets.bottom > 0
          ? null
          : Container(
              margin: const EdgeInsets.only(bottom: 16, right: 16),
              child: Material(
                color: Colors.orange[700],
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
      resizeToAvoidBottomInset: true,
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

    // 1. تجميع السجلات الحالية من الواجهة
    final List<Sale> allSalesFromUI = [];
    double tCount = 0, tStanding = 0, tNet = 0, tGrand = 0;

    for (int i = 0; i < rowControllers.length; i++) {
      final controllers = rowControllers[i];
      if (controllers[1].text.isNotEmpty || controllers[4].text.isNotEmpty) {
        if (_canEditRow(i)) {
          double s = double.tryParse(controllers[6].text) ?? 0;
          double n = double.tryParse(controllers[7].text) ?? 0;
          if (s < n) {
            controllers[7].text = s.toStringAsFixed(2);
            _calculateRowValues(i);
          }
        }

        final sale = Sale(
          serialNumber: (allSalesFromUI.length + 1).toString(),
          material: controllers[0].text,
          affiliation: '', // محذوف من الواجهة
          sValue: '', // محذوف من الواجهة
          count: controllers[1].text,
          packaging: controllers[2].text,
          standing: controllers[3].text,
          net: controllers[4].text,
          price: controllers[5].text,
          total: controllers[6].text,
          cashOrDebt: cashOrDebtValues[i],
          empties: '', // محذوف من الواجهة
          customerName:
              cashOrDebtValues[i] == 'دين' ? customerNames[i].trim() : null,
          sellerName: sellerNames[i],
        );

        allSalesFromUI.add(sale);
        tCount += double.tryParse(sale.count) ?? 0;
        tStanding += double.tryParse(sale.standing) ?? 0;
        tNet += double.tryParse(sale.net) ?? 0;
        tGrand += double.tryParse(sale.total) ?? 0;
      }
    }

    // 2. منطق تحديث الأرصدة الجديد (الإلغاء ثم التطبيق)
    Map<String, double> customerBalanceChanges = {};
    final existingDoc =
        await _storageService.loadSalesDocument(widget.selectedDate);

    // الخطوة أ: إلغاء أثر جميع ديون البائع القديمة في هذا اليوم
    if (existingDoc != null) {
      for (var oldSale in existingDoc.sales) {
        if (oldSale.sellerName == widget.sellerName &&
            oldSale.cashOrDebt == 'دين' &&
            oldSale.customerName != null &&
            oldSale.customerName!.isNotEmpty) {
          double oldAmount = double.tryParse(oldSale.total) ?? 0;
          customerBalanceChanges[oldSale.customerName!] =
              (customerBalanceChanges[oldSale.customerName!] ?? 0) - oldAmount;
        }
      }
    }

    // الخطوة ب: تطبيق أثر جميع ديون البائع الجديدة من الواجهة
    for (var newSale in allSalesFromUI) {
      if (newSale.sellerName == widget.sellerName &&
          newSale.cashOrDebt == 'دين' &&
          newSale.customerName != null &&
          newSale.customerName!.isNotEmpty) {
        double newAmount = double.tryParse(newSale.total) ?? 0;
        customerBalanceChanges[newSale.customerName!] =
            (customerBalanceChanges[newSale.customerName!] ?? 0) + newAmount;
      }
    }

    // 3. بناء الوثيقة النهائية للحفظ
    final documentToSave = SalesDocument(
      recordNumber: serialNumber,
      date: widget.selectedDate,
      sellerName: "Multiple Sellers", // الاسم العام للملف
      storeName: widget.storeName,
      dayName: dayName,
      sales: allSalesFromUI, // نرسل القائمة الكاملة من الواجهة
      totals: {
        'totalCount': tCount.toStringAsFixed(0),
        'totalBase': tStanding.toStringAsFixed(2),
        'totalNet': tNet.toStringAsFixed(2),
        'totalGrand': tGrand.toStringAsFixed(2),
      },
    );

    // 4. الحفظ في الملف وتحديث الأرصدة
    final success = await _storageService.saveSalesDocument(documentToSave);

    if (success) {
      // تطبيق التغييرات الصافية على أرصدة الزبائن
      for (var entry in customerBalanceChanges.entries) {
        if (entry.value != 0) {
          await _customerIndexService.updateCustomerBalance(
              entry.key, entry.value);
        }
      }
      setState(() => _hasUnsavedChanges = false);
      await _loadOrCreateRecord(); // إعادة تحميل لضمان التناسق
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

  // دالة مساعدة لإخفاء جميع الاقتراحات فوراً - مثل purchases_screen
  void _hideAllSuggestionsImmediately() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _materialSuggestions = [];
          _packagingSuggestions = [];
          _supplierSuggestions = [];
          _customerSuggestions = [];
          _activeMaterialRowIndex = null;
          _activePackagingRowIndex = null;
          _activeSupplierRowIndex = null;
          _activeCustomerRowIndex = null;
          _showFullScreenSuggestions = false;
          _currentSuggestionType = '';
        });
      }
    });
  }

// دالة مساعدة لإخفاء جميع الاقتراحات
  void _clearAllSuggestions() {
    if (_materialSuggestions.isNotEmpty ||
        _packagingSuggestions.isNotEmpty ||
        _supplierSuggestions.isNotEmpty ||
        _customerSuggestions.isNotEmpty) {
      if (mounted) {
        setState(() {
          _materialSuggestions = [];
          _packagingSuggestions = [];
          _supplierSuggestions = [];
          _customerSuggestions = [];
          _activeMaterialRowIndex = null;
          _activePackagingRowIndex = null;
          _activeSupplierRowIndex = null;
          _activeCustomerRowIndex = null;
        });
      }
    }
  }

  // دالة لتحميل التواريخ المتاحة (مشابهة للمشتريات)
  Future<void> _loadAvailableDates() async {
    if (_isLoadingRecords) return;

    setState(() {
      _isLoadingRecords = true;
    });

    try {
      final dates = await _storageService.getAvailableDatesWithNumbers();

      if (kDebugMode) {
        debugPrint('✅ تم تحميل ${dates.length} يومية مبيعات');
        for (var date in dates) {
          debugPrint(
              '   - تاريخ: ${date['date']}, رقم: ${date['journalNumber']}');
        }
      }

      setState(() {
        _availableRecords = dates;
        _isLoadingRecords = false;
      });
      _loadGrandTotal(); // أضف هذا السطر
    } catch (e) {
      setState(() {
        _availableRecords = [];
        _isLoadingRecords = false;
      });

      if (kDebugMode) {
        debugPrint('❌ خطأ في تحميل اليوميات: $e');
      }
    }
  }

  void _updateCustomerSuggestions(int rowIndex) async {
    if (rowControllers[rowIndex].length <= 7) return;

    final query = rowControllers[rowIndex][7].text;
    if (query.length >= 1 && cashOrDebtValues[rowIndex] == 'دين') {
      final suggestions =
          await getEnhancedSuggestions(_customerIndexService, query);
      if (mounted) {
        setState(() {
          _customerSuggestions = suggestions;
          _activeCustomerRowIndex = rowIndex;
          if (suggestions.isNotEmpty) {
            _toggleFullScreenSuggestions(type: 'customer', show: true);
          } else {
            _toggleFullScreenSuggestions(type: 'customer', show: false);
          }
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _customerSuggestions = [];
          _activeCustomerRowIndex = null;
          _toggleFullScreenSuggestions(type: 'customer', show: false);
        });
      }
    }
  }

  // حفظ الزبون في الفهرس
  void _saveCustomerToIndex(String customer) {
    final trimmedCustomer = customer.trim();
    if (trimmedCustomer.length >= 3) {
      _customerIndexService.saveCustomer(trimmedCustomer);
    }
  }

  void _toggleFullScreenSuggestions(
      {required String type, required bool show}) {
    if (mounted) {
      setState(() {
        _showFullScreenSuggestions = show;
        if (show) {
          _currentSuggestionType = type;
        } else {
          _currentSuggestionType = '';
        }
      });
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
      case 'customer':
        return _activeCustomerRowIndex ?? -1;
      default:
        return -1;
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
      case 'customer':
        return _customerSuggestions;
      default:
        return [];
    }
  }

  Future<void> _loadJournalNumber() async {
    try {
      final journalNumber =
          await _storageService.getJournalNumberForDate(widget.selectedDate);
      if (mounted) {
        setState(() {
          serialNumber = journalNumber;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          serialNumber = '1'; // الرقم الافتراضي في حالة الخطأ
        });
      }
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

// 2. تطبيق الحماية في الخلايا
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

  // --- دالة توليد PDF والمشاركة (SalesScreen) ---
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

      // حساب المجاميع
      double totalCount = 0;
      double totalBase = 0;
      double totalNet = 0;
      double totalGrand = 0;

      for (var controllers in rowControllers) {
        totalCount += double.tryParse(controllers[1].text) ?? 0;
        totalBase += double.tryParse(controllers[3].text) ?? 0;
        totalNet += double.tryParse(controllers[4].text) ?? 0;
        totalGrand += double.tryParse(controllers[6].text) ?? 0;
      }

      final PdfColor headerColor = PdfColor.fromInt(0xFFF57C00);
      final PdfColor headerTextColor = PdfColors.white;
      final PdfColor rowEvenColor = PdfColors.white;
      final PdfColor rowOddColor = PdfColor.fromInt(0xFFFFE0B2);
      final PdfColor borderColor = PdfColor.fromInt(0xFFE0E0E0);
      final PdfColor totalRowColor = PdfColor.fromInt(0xFFFFCC80);

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
                        child: pw.Text('يومية مبيعات رقم /$serialNumber/',
                            style: pw.TextStyle(
                                fontSize: 16, fontWeight: pw.FontWeight.bold))),
                    pw.Center(
                        child: pw.Text('تاريخ ${widget.selectedDate}',
                            style: const pw.TextStyle(
                                fontSize: 22, color: PdfColors.grey700))),
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
                        6: const pw.FlexColumnWidth(4), // المادة
                        7: const pw.FlexColumnWidth(2), // نقدي/دين
                      },
                      children: [
                        pw.TableRow(
                          decoration: pw.BoxDecoration(color: headerColor),
                          children: [
                            _buildPdfHeaderCell('الإجمالي', headerTextColor),
                            _buildPdfHeaderCell('السعر', headerTextColor),
                            _buildPdfHeaderCell('الصافي', headerTextColor),
                            _buildPdfHeaderCell('القائم', headerTextColor),
                            _buildPdfHeaderCell('العبوة', headerTextColor),
                            _buildPdfHeaderCell('العدد', headerTextColor),
                            _buildPdfHeaderCell('المادة', headerTextColor),
                            _buildPdfHeaderCell('نوع', headerTextColor),
                          ],
                        ),
                        ...rowControllers.asMap().entries.map((entry) {
                          final index = entry.key;
                          final controllers = entry.value;
                          if (controllers[1].text.isEmpty &&
                              controllers[4].text.isEmpty) {
                            return pw.TableRow(
                                children: List.filled(8, pw.SizedBox()));
                          }
                          final color =
                              index % 2 == 0 ? rowEvenColor : rowOddColor;
                          return pw.TableRow(
                            decoration: pw.BoxDecoration(color: color),
                            children: [
                              _buildPdfCell(controllers[6].text,
                                  isBold: true), // الإجمالي
                              _buildPdfCell(controllers[5].text), // السعر
                              _buildPdfCell(controllers[4].text), // الصافي
                              _buildPdfCell(controllers[3].text), // القائم
                              _buildPdfCell(controllers[2].text), // العبوة
                              _buildPdfCell(controllers[1].text), // العدد
                              _buildPdfCell(controllers[0].text), // المادة
                              _buildPdfCell(cashOrDebtValues[index]), // نوع
                            ],
                          );
                        }).toList(),
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
      final file = File("${output.path}/يومية_مبيعات_$safeDate.pdf");

      await file.writeAsBytes(await pdf.save());
      await Share.shareXFiles([XFile(file.path)],
          text: 'يومية مبيعات ${widget.selectedDate}');
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
    for (var dateInfo in _availableRecords) {
      final doc = await _storageService.loadSalesDocument(dateInfo['date']!);
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
