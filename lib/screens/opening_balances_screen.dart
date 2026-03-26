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

  Map<int, CustomerData> _customers = {};
  Map<int, SupplierData> _suppliers = {};

  bool _isSaved = false;
  bool _isLoading = true;

  // تبويب نشط: 0=الصندوق، 1=الزبائن، 2=الموردين
  int _activeTab = 0;

  Map<String, TextEditingController> _customerBalanceControllers = {};
  Map<String, FocusNode> _customerBalanceFocusNodes = {};
  Map<String, TextEditingController> _customerStartDateControllers = {};
  Map<String, FocusNode> _customerStartDateFocusNodes = {};

  Map<String, TextEditingController> _supplierBalanceControllers = {};
  Map<String, FocusNode> _supplierBalanceFocusNodes = {};
  Map<String, TextEditingController> _supplierStartDateControllers = {};
  Map<String, FocusNode> _supplierStartDateFocusNodes = {};

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _boxBalanceController.dispose();
    _capitalController.dispose();

    _customerBalanceControllers.values.forEach((c) => c.dispose());
    _customerBalanceFocusNodes.values.forEach((n) => n.dispose());
    _customerStartDateControllers.values.forEach((c) => c.dispose());
    _customerStartDateFocusNodes.values.forEach((n) => n.dispose());

    _supplierBalanceControllers.values.forEach((c) => c.dispose());
    _supplierBalanceFocusNodes.values.forEach((n) => n.dispose());
    _supplierStartDateControllers.values.forEach((c) => c.dispose());
    _supplierStartDateFocusNodes.values.forEach((n) => n.dispose());

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
      _boxBalanceController.text = boxVal ?? '';
      _capitalController.text = capVal ?? '';
      _customers = customers;
      _suppliers = suppliers;
      _isLoading = false;
    });

    _initializeCustomerControllers();
    _initializeSupplierControllers();
  }

  void _initializeCustomerControllers() {
    // تنظيف الـ Controllers القديمة
    _customerBalanceControllers.values.forEach((c) => c.dispose());
    _customerBalanceFocusNodes.values.forEach((n) => n.dispose());
    _customerStartDateControllers.values.forEach((c) => c.dispose());
    _customerStartDateFocusNodes.values.forEach((n) => n.dispose());

    _customerBalanceControllers.clear();
    _customerBalanceFocusNodes.clear();
    _customerStartDateControllers.clear();
    _customerStartDateFocusNodes.clear();

    _customers.forEach((key, customer) {
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

      _customerStartDateControllers[customer.name] =
          TextEditingController(text: customer.startDate);
      _customerStartDateFocusNodes[customer.name] = FocusNode();
      _customerStartDateFocusNodes[customer.name]!.addListener(() {
        if (!_customerStartDateFocusNodes[customer.name]!.hasFocus) {
          _saveCustomerStartDate(customer.name);
        }
      });
    });
  }

  void _initializeSupplierControllers() {
    // تنظيف الـ Controllers القديمة
    _supplierBalanceControllers.values.forEach((c) => c.dispose());
    _supplierBalanceFocusNodes.values.forEach((n) => n.dispose());
    _supplierStartDateControllers.values.forEach((c) => c.dispose());
    _supplierStartDateFocusNodes.values.forEach((n) => n.dispose());

    _supplierBalanceControllers.clear();
    _supplierBalanceFocusNodes.clear();
    _supplierStartDateControllers.clear();
    _supplierStartDateFocusNodes.clear();

    _suppliers.forEach((key, supplier) {
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

      _supplierStartDateControllers[supplier.name] =
          TextEditingController(text: supplier.startDate);
      _supplierStartDateFocusNodes[supplier.name] = FocusNode();
      _supplierStartDateFocusNodes[supplier.name]!.addListener(() {
        if (!_supplierStartDateFocusNodes[supplier.name]!.hasFocus) {
          _saveSupplierStartDate(supplier.name);
        }
      });
    });
  }

  Future<void> _saveCustomerBalance(String customerName) async {
    final text = _customerBalanceControllers[customerName]?.text.trim() ?? '';
    final newBalance = double.tryParse(text) ?? 0.0;
    await _customerService.setInitialBalance(customerName, newBalance);
    await _loadAll();
  }

  Future<void> _saveCustomerStartDate(String customerName) async {
    final newStartDate =
        _customerStartDateControllers[customerName]?.text.trim() ?? '';
    await _customerService.updateCustomerStartDate(customerName, newStartDate);
    await _loadAll();
  }

  Future<void> _saveSupplierBalance(String supplierName) async {
    final text = _supplierBalanceControllers[supplierName]?.text.trim() ?? '';
    final newBalance = double.tryParse(text) ?? 0.0;
    await _supplierService.setInitialBalance(supplierName, newBalance);
    await _loadAll();
  }

  Future<void> _saveSupplierStartDate(String supplierName) async {
    final newStartDate =
        _supplierStartDateControllers[supplierName]?.text.trim() ?? '';
    await _supplierService.updateSupplierStartDate(supplierName, newStartDate);
    await _loadAll();
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
    final list = _customers.entries.toList();
    if (list.isEmpty) {
      return const Center(
        child: Text('لا يوجد زبائن مسجلين.',
            style: TextStyle(fontSize: 16, color: Colors.grey)),
      );
    }

    // حساب المجموع
    final totalBalance =
        _customers.values.fold(0.0, (sum, c) => sum + c.balance);

    return Column(
      children: [
        // شريط المجموع
        Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
        // رأس الجدول
        Container(
          color: Colors.grey[300],
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            children: const [
              Expanded(
                  flex: 2,
                  child: Text('الاسم',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 11))),
              Expanded(
                  flex: 3,
                  child: Text('الرصيد الابتدائي',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                      textAlign: TextAlign.center)),
              Expanded(
                  flex: 3,
                  child: Text('تاريخ البدء',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                      textAlign: TextAlign.center)),
            ],
          ),
        ),
        // قائمة الزبائن
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: list.length,
            itemBuilder: (context, index) {
              final entry = list[index];
              final customer = entry.value;
              final isEven = index % 2 == 0;

              return Container(
                color: isEven ? Colors.white : Colors.grey[50],
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(customer.name,
                          style: const TextStyle(fontSize: 13)),
                    ),
                    Expanded(
                      flex: 3,
                      child: _buildEditableCell(
                        controller: _customerBalanceControllers[customer.name],
                        focusNode: _customerBalanceFocusNodes[customer.name],
                        isNumeric: true,
                        onSubmitted: (val) {
                          FocusScope.of(context).requestFocus(
                              _customerStartDateFocusNodes[customer.name]);
                        },
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: _buildEditableCell(
                        controller:
                            _customerStartDateControllers[customer.name],
                        focusNode: _customerStartDateFocusNodes[customer.name],
                        isNumeric: false,
                        onSubmitted: (val) {
                          if (index < list.length - 1) {
                            final nextCustomer = list[index + 1].value;
                            FocusScope.of(context).requestFocus(
                                _customerBalanceFocusNodes[nextCustomer.name]);
                          }
                        },
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
    final list = _suppliers.entries.toList();
    if (list.isEmpty) {
      return const Center(
        child: Text('لا يوجد موردين مسجلين.',
            style: TextStyle(fontSize: 16, color: Colors.grey)),
      );
    }

    // حساب المجموع
    final totalBalance =
        _suppliers.values.fold(0.0, (sum, s) => sum + s.balance);

    return Column(
      children: [
        // شريط المجموع
        Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
        // رأس الجدول
        Container(
          color: Colors.grey[300],
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            children: const [
              Expanded(
                  flex: 2,
                  child: Text('الاسم',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 11))),
              Expanded(
                  flex: 3,
                  child: Text('الرصيد الابتدائي',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                      textAlign: TextAlign.center)),
              Expanded(
                  flex: 3,
                  child: Text('تاريخ البدء',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                      textAlign: TextAlign.center)),
            ],
          ),
        ),
        // قائمة الموردين
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: list.length,
            itemBuilder: (context, index) {
              final entry = list[index];
              final supplier = entry.value;
              final isEven = index % 2 == 0;

              return Container(
                color: isEven ? Colors.white : Colors.grey[50],
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(supplier.name,
                          style: const TextStyle(fontSize: 13)),
                    ),
                    Expanded(
                      flex: 3,
                      child: _buildEditableCell(
                        controller: _supplierBalanceControllers[supplier.name],
                        focusNode: _supplierBalanceFocusNodes[supplier.name],
                        isNumeric: true,
                        onSubmitted: (val) {
                          FocusScope.of(context).requestFocus(
                              _supplierStartDateFocusNodes[supplier.name]);
                        },
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: _buildEditableCell(
                        controller:
                            _supplierStartDateControllers[supplier.name],
                        focusNode: _supplierStartDateFocusNodes[supplier.name],
                        isNumeric: false,
                        onSubmitted: (val) {
                          if (index < list.length - 1) {
                            final nextSupplier = list[index + 1].value;
                            FocusScope.of(context).requestFocus(
                                _supplierBalanceFocusNodes[nextSupplier.name]);
                          }
                        },
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
