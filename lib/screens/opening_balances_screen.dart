import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/app_settings_service.dart';
import '../services/customer_index_service.dart';
import '../services/supplier_index_service.dart';

class OpeningBalancesScreen extends StatefulWidget {
  final String selectedDate;
  const OpeningBalancesScreen({super.key, this.selectedDate = ''});

  @override
  State<OpeningBalancesScreen> createState() => _OpeningBalancesScreenState();
}

class _OpeningBalancesScreenState extends State<OpeningBalancesScreen> {
  static const String _keyBoxBalance = 'opening_box_balance';
  static const String _keyCapital = 'opening_capital';

  final CustomerIndexService _customerService = CustomerIndexService();
  final SupplierIndexService _supplierService = SupplierIndexService();

  final TextEditingController _boxBalanceController = TextEditingController();
  final TextEditingController _capitalController = TextEditingController();

  // حقل إضافة زبون جديد
  final TextEditingController _addCustomerController = TextEditingController();
  final FocusNode _addCustomerFocusNode = FocusNode();

  // حقل إضافة مورد جديد
  final TextEditingController _addSupplierController = TextEditingController();
  final FocusNode _addSupplierFocusNode = FocusNode();

  Map<int, CustomerData> _customers = {};
  Map<int, SupplierData> _suppliers = {};

  bool _isSaved = false;
  bool _isLoading = true;

  // تبويب نشط: 0=الصندوق، 1=الزبائن، 2=الموردين
  int _activeTab = 0;

  // Controllers للزبائن
  Map<String, TextEditingController> _customerBalanceControllers = {};
  Map<String, FocusNode> _customerBalanceFocusNodes = {};
  Map<String, TextEditingController> _customerMobileControllers = {};
  Map<String, FocusNode> _customerMobileFocusNodes = {};

  // Controllers للموردين
  Map<String, TextEditingController> _supplierBalanceControllers = {};
  Map<String, FocusNode> _supplierBalanceFocusNodes = {};
  Map<String, TextEditingController> _supplierMobileControllers = {};
  Map<String, FocusNode> _supplierMobileFocusNodes = {};

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _boxBalanceController.dispose();
    _capitalController.dispose();
    _addCustomerController.dispose();
    _addCustomerFocusNode.dispose();
    _addSupplierController.dispose();
    _addSupplierFocusNode.dispose();

    _customerBalanceControllers.values.forEach((c) => c.dispose());
    _customerBalanceFocusNodes.values.forEach((n) => n.dispose());
    _customerMobileControllers.values.forEach((c) => c.dispose());
    _customerMobileFocusNodes.values.forEach((n) => n.dispose());

    _supplierBalanceControllers.values.forEach((c) => c.dispose());
    _supplierBalanceFocusNodes.values.forEach((n) => n.dispose());
    _supplierMobileControllers.values.forEach((c) => c.dispose());
    _supplierMobileFocusNodes.values.forEach((n) => n.dispose());

    super.dispose();
  }

  Future<void> _loadAll() async {
    final settings = AppSettingsService();
    final boxVal = await settings.getString(_keyBoxBalance);
    final capVal = await settings.getString(_keyCapital);
    final customers = await _customerService.getAllCustomersWithData();
    final suppliers = await _supplierService.getAllSuppliersWithData();

    setState(() {
      _isSaved = boxVal != null || capVal != null;
      // تبقى قيمة الصندوق ثابتة — لا تُحدَّث من مصادر أخرى
      if (_boxBalanceController.text.isEmpty) {
        _boxBalanceController.text = boxVal ?? '';
      }
      if (_capitalController.text.isEmpty) {
        _capitalController.text = capVal ?? '';
      }
      _customers = customers;
      _suppliers = suppliers;
      _isLoading = false;
    });

    _initializeCustomerControllers();
    _initializeSupplierControllers();
  }

  void _initializeCustomerControllers() {
    _customerBalanceControllers.values.forEach((c) => c.dispose());
    _customerBalanceFocusNodes.values.forEach((n) => n.dispose());
    _customerMobileControllers.values.forEach((c) => c.dispose());
    _customerMobileFocusNodes.values.forEach((n) => n.dispose());

    _customerBalanceControllers.clear();
    _customerBalanceFocusNodes.clear();
    _customerMobileControllers.clear();
    _customerMobileFocusNodes.clear();

    _customers.forEach((key, customer) {
      // رصيد
      _customerBalanceControllers[customer.name] = TextEditingController(
          text: customer.balance == 0.0
              ? ''
              : customer.balance.toStringAsFixed(2));
      _customerBalanceFocusNodes[customer.name] = FocusNode();
      _customerBalanceFocusNodes[customer.name]!.addListener(() {
        if (!_customerBalanceFocusNodes[customer.name]!.hasFocus) {
          _saveCustomerBalance(customer.name);
        }
      });

      // موبايل
      _customerMobileControllers[customer.name] =
          TextEditingController(text: customer.mobile);
      _customerMobileFocusNodes[customer.name] = FocusNode();
      _customerMobileFocusNodes[customer.name]!.addListener(() {
        if (!_customerMobileFocusNodes[customer.name]!.hasFocus) {
          _saveCustomerMobile(customer.name);
        }
      });
    });
  }

  void _initializeSupplierControllers() {
    _supplierBalanceControllers.values.forEach((c) => c.dispose());
    _supplierBalanceFocusNodes.values.forEach((n) => n.dispose());
    _supplierMobileControllers.values.forEach((c) => c.dispose());
    _supplierMobileFocusNodes.values.forEach((n) => n.dispose());

    _supplierBalanceControllers.clear();
    _supplierBalanceFocusNodes.clear();
    _supplierMobileControllers.clear();
    _supplierMobileFocusNodes.clear();

    _suppliers.forEach((key, supplier) {
      // رصيد
      _supplierBalanceControllers[supplier.name] = TextEditingController(
          text: supplier.balance == 0.0
              ? ''
              : supplier.balance.toStringAsFixed(2));
      _supplierBalanceFocusNodes[supplier.name] = FocusNode();
      _supplierBalanceFocusNodes[supplier.name]!.addListener(() {
        if (!_supplierBalanceFocusNodes[supplier.name]!.hasFocus) {
          _saveSupplierBalance(supplier.name);
        }
      });

      // موبايل
      _supplierMobileControllers[supplier.name] =
          TextEditingController(text: supplier.mobile);
      _supplierMobileFocusNodes[supplier.name] = FocusNode();
      _supplierMobileFocusNodes[supplier.name]!.addListener(() {
        if (!_supplierMobileFocusNodes[supplier.name]!.hasFocus) {
          _saveSupplierMobile(supplier.name);
        }
      });
    });
  }

  // ── حفظ بيانات الزبائن ──
  Future<void> _saveCustomerBalance(String customerName) async {
    final text = _customerBalanceControllers[customerName]?.text.trim() ?? '';
    final newBalance = double.tryParse(text) ?? 0.0;
    await _customerService.setInitialBalance(customerName, newBalance);
    if (mounted) setState(() {});
  }

  Future<void> _saveCustomerMobile(String customerName) async {
    final newMobile =
        _customerMobileControllers[customerName]?.text.trim() ?? '';
    await _customerService.updateCustomerMobile(customerName, newMobile);
  }

  Future<void> _addNewCustomer() async {
    final name = _addCustomerController.text.trim();
    if (name.isNotEmpty) {
      await _customerService.forceAddCustomer(
        name,
        startDate: widget.selectedDate,
      );
      _addCustomerController.clear();
      _addCustomerFocusNode.unfocus();
      final customers = await _customerService.getAllCustomersWithData();
      setState(() => _customers = customers);
      _initializeCustomerControllers();
    }
  }

  Future<void> _deleteCustomer(CustomerData customer) async {
    if (customer.balance != 0.0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            'لا يمكن حذف زبون رصيده غير صفر (${customer.balance.toStringAsFixed(2)})'),
        backgroundColor: Colors.orange,
      ));
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: Text('هل أنت متأكد من حذف الزبون "${customer.name}"؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('حذف')),
        ],
      ),
    );

    if (confirm == true) {
      await _customerService.removeCustomer(customer.name);
      final customers = await _customerService.getAllCustomersWithData();
      setState(() => _customers = customers);
      _initializeCustomerControllers();
    }
  }

  // ── حفظ بيانات الموردين ──
  Future<void> _saveSupplierBalance(String supplierName) async {
    final text = _supplierBalanceControllers[supplierName]?.text.trim() ?? '';
    final newBalance = double.tryParse(text) ?? 0.0;
    await _supplierService.setInitialBalance(supplierName, newBalance);
    if (mounted) setState(() {});
  }

  Future<void> _saveSupplierMobile(String supplierName) async {
    final newMobile =
        _supplierMobileControllers[supplierName]?.text.trim() ?? '';
    await _supplierService.updateSupplierMobile(supplierName, newMobile);
  }

  Future<void> _addNewSupplier() async {
    final name = _addSupplierController.text.trim();
    if (name.isNotEmpty) {
      await _supplierService.forceAddSupplier(
        name,
        startDate: widget.selectedDate,
      );
      _addSupplierController.clear();
      _addSupplierFocusNode.unfocus();
      final suppliers = await _supplierService.getAllSuppliersWithData();
      setState(() => _suppliers = suppliers);
      _initializeSupplierControllers();
    }
  }

  Future<void> _deleteSupplier(SupplierData supplier) async {
    if (supplier.balance != 0.0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            'لا يمكن حذف مورد رصيده غير صفر (${supplier.balance.toStringAsFixed(2)})'),
        backgroundColor: Colors.orange,
      ));
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: Text('هل أنت متأكد من حذف المورد "${supplier.name}"؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('حذف')),
        ],
      ),
    );

    if (confirm == true) {
      await _supplierService.removeSupplier(supplier.name);
      final suppliers = await _supplierService.getAllSuppliersWithData();
      setState(() => _suppliers = suppliers);
      _initializeSupplierControllers();
    }
  }

  Future<void> _saveBoxBalances() async {
    final boxText = _boxBalanceController.text.trim();
    final capText = _capitalController.text.trim();
    final boxVal = double.tryParse(boxText);
    final capVal = double.tryParse(capText);

    if (boxVal == null || capVal == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى إدخال أرقام صحيحة في الحقلين'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final settings = AppSettingsService();
    await settings.setString(_keyBoxBalance, boxText);
    await settings.setString(_keyCapital, capText);
    setState(() => _isSaved = true);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ تم حفظ أرصدة البداية بنجاح'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('أرصدة البداية'),
        backgroundColor: Colors.deepOrange[700],
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Directionality(
              textDirection: TextDirection.rtl,
              child: Column(
                children: [
                  // تبويبات
                  Container(
                    color: Colors.deepOrange[50],
                    child: Row(
                      children: [
                        _buildTabButton(0, 'الصندوق', Icons.inbox),
                        _buildTabButton(1, 'الزبائن', Icons.people),
                        _buildTabButton(2, 'الموردين', Icons.store),
                      ],
                    ),
                  ),
                  Expanded(
                    child: _activeTab == 0
                        ? _buildBoxTab()
                        : _activeTab == 1
                            ? _buildCustomersTab()
                            : _buildSuppliersTab(),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildTabButton(int index, String label, IconData icon) {
    final isActive = _activeTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _activeTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isActive ? Colors.deepOrange[700] : Colors.transparent,
            border: Border(
              bottom: BorderSide(
                color: isActive ? Colors.deepOrange[700]! : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  color: isActive ? Colors.white : Colors.deepOrange[700],
                  size: 20),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isActive ? Colors.white : Colors.deepOrange[700],
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── تبويب الصندوق ──
  // ملاحظة: قيمة الصندوق تُحفظ يدوياً فقط عبر زر الحفظ ولا تتأثر بأي مصدر خارجي
  Widget _buildBoxTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(Icons.account_balance_wallet,
              size: 64, color: Colors.deepOrange[700]),
          const SizedBox(height: 12),
          Text(
            'أرصدة البداية',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.deepOrange[800]),
          ),
          const SizedBox(height: 8),
          Text(
            _isSaved
                ? 'تم حفظ الأرصدة مسبقاً — يمكنك تعديلها وإعادة الحفظ'
                : 'أدخل أرصدة البداية مرة واحدة — ستبقى ثابتة',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
          const SizedBox(height: 40),
          Text('رصيد الصندوق الابتدائي',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepOrange[800])),
          const SizedBox(height: 8),
          TextField(
            controller: _boxBalanceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              hintText: '0.00',
              prefixIcon: const Icon(Icons.inbox),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    BorderSide(color: Colors.deepOrange[700]!, width: 2),
              ),
              filled: true,
              fillColor: Colors.deepOrange[50],
            ),
          ),
          const SizedBox(height: 28),
          Text('رأس المال الابتدائي',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepOrange[800])),
          const SizedBox(height: 8),
          TextField(
            controller: _capitalController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              hintText: '0.00',
              prefixIcon: const Icon(Icons.account_balance),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    BorderSide(color: Colors.deepOrange[700]!, width: 2),
              ),
              filled: true,
              fillColor: Colors.deepOrange[50],
            ),
          ),
          const SizedBox(height: 40),
          ElevatedButton.icon(
            onPressed: _saveBoxBalances,
            icon: const Icon(Icons.save, size: 24),
            label: Text(
              _isSaved ? 'تحديث الأرصدة' : 'حفظ الأرصدة',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepOrange[700],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 5,
            ),
          ),
          if (_isSaved) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.green.shade300),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, color: Colors.green[700], size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'الأرصدة محفوظة وتؤثر على الميزانية الختامية',
                    style: TextStyle(
                        color: Colors.green[800],
                        fontWeight: FontWeight.bold,
                        fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── تبويب الزبائن ──
  Widget _buildCustomersTab() {
    final list = _customers.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    final totalBalance =
        _customers.values.fold(0.0, (sum, c) => sum + c.balance);

    return Column(
      children: [
        // شريط المجموع + حقل الإضافة
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.teal[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.teal.shade200),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('المجموع: ',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.teal)),
                      Text(
                        totalBalance.toStringAsFixed(2),
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _addCustomerController,
                  focusNode: _addCustomerFocusNode,
                  decoration: const InputDecoration(
                    labelText: 'إضافة زبون جديد',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onSubmitted: (_) => _addNewCustomer(),
                ),
              ),
            ],
          ),
        ),
        // رأس الجدول
        Container(
          color: Colors.grey[300],
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: const Row(
            children: [
              Expanded(
                  flex: 2,
                  child: Text('الاسم',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 11))),
              Expanded(
                  flex: 3,
                  child: Text('الرصيد',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                      textAlign: TextAlign.center)),
              Expanded(
                  flex: 3,
                  child: Text('الموبايل',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                      textAlign: TextAlign.center)),
              Expanded(
                  flex: 2,
                  child: Text('تاريخ البدء',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                      textAlign: TextAlign.center)),
              SizedBox(width: 30),
            ],
          ),
        ),
        // قائمة الزبائن
        Expanded(
          child: list.isEmpty
              ? const Center(child: Text('لا يوجد زبائن مسجلين.'))
              : ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (context, index) {
                    final customer = list[index].value;
                    final isEven = index % 2 == 0;

                    return Container(
                      color: isEven ? Colors.white : Colors.grey[50],
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 1),
                      child: Row(
                        children: [
                          Expanded(
                              flex: 2,
                              child: Text(customer.name,
                                  style: const TextStyle(fontSize: 13))),
                          Expanded(
                              flex: 3,
                              child: _buildEditableCell(
                                controller:
                                    _customerBalanceControllers[customer.name],
                                focusNode:
                                    _customerBalanceFocusNodes[customer.name],
                                isNumeric: true,
                                onSubmitted: (val) {
                                  FocusScope.of(context).requestFocus(
                                      _customerMobileFocusNodes[customer.name]);
                                },
                              )),
                          Expanded(
                              flex: 3,
                              child: _buildEditableCell(
                                controller:
                                    _customerMobileControllers[customer.name],
                                focusNode:
                                    _customerMobileFocusNodes[customer.name],
                                isNumeric: true,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly
                                ],
                                onSubmitted: (val) {
                                  if (index < list.length - 1) {
                                    final nextCustomer = list[index + 1].value;
                                    FocusScope.of(context).requestFocus(
                                        _customerBalanceFocusNodes[
                                            nextCustomer.name]);
                                  } else {
                                    FocusScope.of(context)
                                        .requestFocus(_addCustomerFocusNode);
                                  }
                                },
                              )),
                          Expanded(
                              flex: 2,
                              child: Center(
                                  child: Text(customer.startDate,
                                      style: const TextStyle(
                                          fontSize: 10, color: Colors.black)))),
                          SizedBox(
                            width: 30,
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              iconSize: 18,
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteCustomer(customer),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // ── تبويب الموردين ──
  Widget _buildSuppliersTab() {
    final list = _suppliers.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    final totalBalance =
        _suppliers.values.fold(0.0, (sum, s) => sum + s.balance);

    return Column(
      children: [
        // شريط المجموع + حقل الإضافة
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.brown[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.brown.shade200),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('المجموع: ',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.brown)),
                      Text(
                        totalBalance.toStringAsFixed(2),
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _addSupplierController,
                  focusNode: _addSupplierFocusNode,
                  decoration: const InputDecoration(
                    labelText: 'إضافة مورد جديد',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onSubmitted: (_) => _addNewSupplier(),
                ),
              ),
            ],
          ),
        ),
        // رأس الجدول
        Container(
          color: Colors.grey[300],
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: const Row(
            children: [
              Expanded(
                  flex: 2,
                  child: Text('الاسم',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 11))),
              Expanded(
                  flex: 3,
                  child: Text('الرصيد',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                      textAlign: TextAlign.center)),
              Expanded(
                  flex: 3,
                  child: Text('الموبايل',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                      textAlign: TextAlign.center)),
              Expanded(
                  flex: 2,
                  child: Text('تاريخ البدء',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                      textAlign: TextAlign.center)),
              SizedBox(width: 30),
            ],
          ),
        ),
        // قائمة الموردين
        Expanded(
          child: list.isEmpty
              ? const Center(child: Text('لا يوجد موردين مسجلين.'))
              : ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (context, index) {
                    final supplier = list[index].value;
                    final isEven = index % 2 == 0;

                    return Container(
                      color: isEven ? Colors.white : Colors.grey[50],
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 1),
                      child: Row(
                        children: [
                          Expanded(
                              flex: 2,
                              child: Text(supplier.name,
                                  style: const TextStyle(fontSize: 13))),
                          Expanded(
                              flex: 3,
                              child: _buildEditableCell(
                                controller:
                                    _supplierBalanceControllers[supplier.name],
                                focusNode:
                                    _supplierBalanceFocusNodes[supplier.name],
                                isNumeric: true,
                                onSubmitted: (val) {
                                  FocusScope.of(context).requestFocus(
                                      _supplierMobileFocusNodes[supplier.name]);
                                },
                              )),
                          Expanded(
                              flex: 3,
                              child: _buildEditableCell(
                                controller:
                                    _supplierMobileControllers[supplier.name],
                                focusNode:
                                    _supplierMobileFocusNodes[supplier.name],
                                isNumeric: true,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly
                                ],
                                onSubmitted: (val) {
                                  if (index < list.length - 1) {
                                    final nextSupplier = list[index + 1].value;
                                    FocusScope.of(context).requestFocus(
                                        _supplierBalanceFocusNodes[
                                            nextSupplier.name]);
                                  } else {
                                    FocusScope.of(context)
                                        .requestFocus(_addSupplierFocusNode);
                                  }
                                },
                              )),
                          Expanded(
                              flex: 2,
                              child: Center(
                                  child: Text(supplier.startDate,
                                      style: const TextStyle(
                                          fontSize: 10, color: Colors.black)))),
                          SizedBox(
                            width: 30,
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              iconSize: 18,
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteSupplier(supplier),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildEditableCell({
    required TextEditingController? controller,
    required FocusNode? focusNode,
    bool isNumeric = false,
    List<TextInputFormatter>? inputFormatters,
    Function(String)? onSubmitted,
  }) {
    if (controller == null || focusNode == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2.0),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 13),
        keyboardType: isNumeric
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        inputFormatters: inputFormatters,
        onSubmitted: onSubmitted,
        decoration: const InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.symmetric(vertical: 2),
          border: UnderlineInputBorder(),
        ),
      ),
    );
  }
}
