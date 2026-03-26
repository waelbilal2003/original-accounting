import 'dart:io';
import 'package:flutter/material.dart';
import 'package:archive/archive_io.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../services/app_settings_service.dart';
import 'customer_preferences_screen.dart';
import 'supplier_preferences_screen.dart';
import '../services/customer_index_service.dart';
import '../services/supplier_index_service.dart';
import '../services/sales_storage_service.dart';
import '../services/purchase_storage_service.dart';
import '../services/box_storage_service.dart';
import 'settings_screen.dart';
import 'opening_balances_screen.dart';

class PreferencesScreen extends StatefulWidget {
  final String selectedDate;
  const PreferencesScreen({super.key, required this.selectedDate});

  @override
  State<PreferencesScreen> createState() => _PreferencesScreenState();
}

class _PreferencesScreenState extends State<PreferencesScreen> {
  final CustomerIndexService _customerIndexService = CustomerIndexService();
  final SupplierIndexService _supplierIndexService = SupplierIndexService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('التفصيلات'),
        backgroundColor: Colors.blueGrey[600],
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // الصف الأول
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: _buildMenuButton(
                        context,
                        icon: Icons.account_balance,
                        label: 'تفصيلات\nالحساب',
                        color: Colors.indigo[700]!,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AccountSummaryScreen(
                                selectedDate: widget.selectedDate,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildMenuButton(
                        context,
                        icon: Icons.people,
                        label: 'تفصيلات\nالزبائن',
                        color: Colors.teal[600]!,
                        onTap: () async {
                          final customers = await _customerIndexService
                              .getAllCustomersWithData();
                          if (!mounted) return;
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CustomerPreferencesListScreen(
                                selectedDate: widget.selectedDate,
                                customers: customers,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildMenuButton(
                        context,
                        icon: Icons.store,
                        label: 'تفصيلات\nالموردين',
                        color: Colors.brown[600]!,
                        onTap: () async {
                          final suppliers = await _supplierIndexService
                              .getAllSuppliersWithData();
                          if (!mounted) return;
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => SupplierPreferencesListScreen(
                                selectedDate: widget.selectedDate,
                                suppliers: suppliers,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // الصف الثاني
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: _buildMenuButton(
                        context,
                        icon: Icons.attach_money,
                        label: 'أرصدة\nالبداية',
                        color: Colors.deepOrange[700]!,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => OpeningBalancesScreen(
                                selectedDate: widget.selectedDate,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildMenuButton(
                        context,
                        icon: Icons.backup,
                        label: 'النسخ\nالاحتياطي',
                        color: const Color(0xFF0F4C5C),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const BackupScreen(),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildMenuButton(
                        context,
                        icon: Icons.settings,
                        label: 'إعدادات\nأخرى',
                        color: Colors.grey[700]!,
                        // في preferences_screen.dart، استبدل onTap لـ 'إعدادات أخرى' بـ:

                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => SettingsScreen(
                                  selectedDate: widget.selectedDate),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(16),
      shadowColor: color.withOpacity(0.5),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color,
                color.withOpacity(0.7),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 48,
                color: Colors.white,
              ),
              const SizedBox(height: 12),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── بطاقة رصيد زبون ──
class _CustomerBalanceCard extends StatefulWidget {
  final CustomerData customer;
  final Future<void> Function(double balance, String startDate) onSave;

  const _CustomerBalanceCard({required this.customer, required this.onSave});

  @override
  State<_CustomerBalanceCard> createState() => _CustomerBalanceCardState();
}

class _CustomerBalanceCardState extends State<_CustomerBalanceCard> {
  late TextEditingController _balanceController;
  late TextEditingController _startDateController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _balanceController = TextEditingController(
        text: widget.customer.balance == 0
            ? ''
            : widget.customer.balance.toStringAsFixed(2));
    _startDateController =
        TextEditingController(text: widget.customer.startDate);
  }

  @override
  void dispose() {
    _balanceController.dispose();
    _startDateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.person, color: Colors.teal[700], size: 20),
                const SizedBox(width: 8),
                Text(widget.customer.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15)),
                if (widget.customer.isBalanceLocked) ...[
                  const Spacer(),
                  Icon(Icons.lock, color: Colors.orange[700], size: 16),
                  const SizedBox(width: 4),
                  Text('مقفول',
                      style:
                          TextStyle(color: Colors.orange[700], fontSize: 12)),
                ],
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _balanceController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    enabled: !widget.customer.isBalanceLocked,
                    decoration: InputDecoration(
                      labelText: 'الرصيد الابتدائي',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      filled: widget.customer.isBalanceLocked,
                      fillColor: widget.customer.isBalanceLocked
                          ? Colors.grey[100]
                          : null,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _startDateController,
                    decoration: InputDecoration(
                      labelText: 'تاريخ البدء',
                      hintText: 'مثال: 2024/1/1',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _saving
                      ? null
                      : () async {
                          setState(() => _saving = true);
                          final balance =
                              double.tryParse(_balanceController.text) ?? 0;
                          await widget.onSave(
                              balance, _startDateController.text.trim());
                          setState(() => _saving = false);
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal[700],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('حفظ'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── بطاقة رصيد مورد ──
class _SupplierBalanceCard extends StatefulWidget {
  final SupplierData supplier;
  final Future<void> Function(double balance, String startDate) onSave;

  const _SupplierBalanceCard({required this.supplier, required this.onSave});

  @override
  State<_SupplierBalanceCard> createState() => _SupplierBalanceCardState();
}

class _SupplierBalanceCardState extends State<_SupplierBalanceCard> {
  late TextEditingController _balanceController;
  late TextEditingController _startDateController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _balanceController = TextEditingController(
        text: widget.supplier.balance == 0
            ? ''
            : widget.supplier.balance.toStringAsFixed(2));
    _startDateController =
        TextEditingController(text: widget.supplier.startDate);
  }

  @override
  void dispose() {
    _balanceController.dispose();
    _startDateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.store, color: Colors.brown[700], size: 20),
                const SizedBox(width: 8),
                Text(widget.supplier.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15)),
                if (widget.supplier.isBalanceLocked) ...[
                  const Spacer(),
                  Icon(Icons.lock, color: Colors.orange[700], size: 16),
                  const SizedBox(width: 4),
                  Text('مقفول',
                      style:
                          TextStyle(color: Colors.orange[700], fontSize: 12)),
                ],
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _balanceController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    enabled: !widget.supplier.isBalanceLocked,
                    decoration: InputDecoration(
                      labelText: 'الرصيد الابتدائي',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      filled: widget.supplier.isBalanceLocked,
                      fillColor: widget.supplier.isBalanceLocked
                          ? Colors.grey[100]
                          : null,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _startDateController,
                    decoration: InputDecoration(
                      labelText: 'تاريخ البدء',
                      hintText: 'مثال: 2024/1/1',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _saving
                      ? null
                      : () async {
                          setState(() => _saving = true);
                          final balance =
                              double.tryParse(_balanceController.text) ?? 0;
                          await widget.onSave(
                              balance, _startDateController.text.trim());
                          setState(() => _saving = false);
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.brown[700],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('حفظ'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---- قائمة اختيار الزبون ----
class CustomerPreferencesListScreen extends StatelessWidget {
  final String selectedDate;
  final Map<int, CustomerData> customers;

  const CustomerPreferencesListScreen(
      {super.key, required this.selectedDate, required this.customers});

  @override
  Widget build(BuildContext context) {
    final list = customers.values.toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('تفضيلات الزبائن'),
        backgroundColor: Colors.teal[600],
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: list.isEmpty
            ? const Center(
                child: Text('لا يوجد زبائن مسجلين.',
                    style: TextStyle(fontSize: 16, color: Colors.grey)))
            : Padding(
                padding: const EdgeInsets.all(12.0),
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 2.2,
                  ),
                  itemCount: list.length,
                  itemBuilder: (context, index) {
                    final customer = list[index];
                    return ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CustomerPreferencesScreen(
                              customer: customer,
                              selectedDate: selectedDate,
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal[700],
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        elevation: 3,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                      ),
                      child: Text(
                        customer.name,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.bold),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  },
                ),
              ),
      ),
    );
  }
}

// ---- قائمة اختيار المورد ----
class SupplierPreferencesListScreen extends StatelessWidget {
  final String selectedDate;
  final Map<int, SupplierData> suppliers;

  const SupplierPreferencesListScreen(
      {super.key, required this.selectedDate, required this.suppliers});

  @override
  Widget build(BuildContext context) {
    final list = suppliers.values.toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('تفضيلات الموردين'),
        backgroundColor: Colors.brown[600],
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: list.isEmpty
            ? const Center(
                child: Text('لا يوجد موردين مسجلين.',
                    style: TextStyle(fontSize: 16, color: Colors.grey)))
            : Padding(
                padding: const EdgeInsets.all(12.0),
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 2.2,
                  ),
                  itemCount: list.length,
                  itemBuilder: (context, index) {
                    final supplier = list[index];
                    return ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SupplierPreferencesScreen(
                              supplier: supplier,
                              selectedDate: selectedDate,
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.brown[700],
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        elevation: 3,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                      ),
                      child: Text(
                        supplier.name,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.bold),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  },
                ),
              ),
      ),
    );
  }
}

// ---- شاشة تفصيلات الحساب ----
class AccountSummaryScreen extends StatefulWidget {
  final String selectedDate;
  const AccountSummaryScreen({super.key, required this.selectedDate});

  @override
  State<AccountSummaryScreen> createState() => _AccountSummaryScreenState();
}

class _AccountSummaryScreenState extends State<AccountSummaryScreen> {
  final CustomerIndexService _customerIndexService = CustomerIndexService();
  final SupplierIndexService _supplierIndexService = SupplierIndexService();
  final SalesStorageService _salesStorageService = SalesStorageService();
  final PurchaseStorageService _purchasesStorageService =
      PurchaseStorageService();
  final BoxStorageService _boxStorageService = BoxStorageService();

  double _salesTotal = 0;
  double _purchasesTotal = 0;
  double _boxReceived = 0;
  double _expensesTotal = 0;
  double _customersBalance = 0;
  double _suppliersBalance = 0;
  double _openingBoxBalance = 0;

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      double sales = 0;
      double purchases = 0;
      double boxReceived = 0, boxPaid = 0;
      double expensesTotalPaid = 0, expensesTotalReceived = 0;

      final allBoxDates =
          await _boxStorageService.getAvailableDatesWithNumbers();
      for (var dateInfo in allBoxDates) {
        final doc =
            await _boxStorageService.loadBoxDocumentForDate(dateInfo['date']!);
        if (doc != null) {
          boxReceived +=
              double.tryParse(doc.totals['totalReceived'] ?? '0') ?? 0;
          boxPaid += double.tryParse(doc.totals['totalPaid'] ?? '0') ?? 0;
          for (var trans in doc.transactions) {
            if (trans.accountType == 'مصروف') {
              expensesTotalPaid += double.tryParse(trans.paid) ?? 0;
              expensesTotalReceived += double.tryParse(trans.received) ?? 0;
            }
          }
        }
      }
      final double expenses = expensesTotalPaid - expensesTotalReceived;

      final salesAllDates = await _salesStorageService.getAllAvailableDates();
      for (var date in salesAllDates) {
        final doc = await _salesStorageService.loadDocumentForDate(date);
        if (doc != null) {
          sales += double.tryParse(doc.totals['totalPayments'] ?? '0') ?? 0;
        }
      }

      final purchasesAllDates =
          await _purchasesStorageService.getAllAvailableDates();
      for (var date in purchasesAllDates) {
        final doc = await _purchasesStorageService.loadDocumentForDate(date);
        if (doc != null) {
          purchases += double.tryParse(doc.totals['totalPayments'] ?? '0') ?? 0;
        }
      }

      final double boxBalance = boxReceived - boxPaid;

      final settings = AppSettingsService();
      final openingBox = double.tryParse(
              await settings.getString('opening_box_balance') ?? '0') ??
          0;

      final customers = await _customerIndexService.getAllCustomersWithData();
      final suppliers = await _supplierIndexService.getAllSuppliersWithData();
      final custBalance = customers.values.fold(0.0, (s, c) => s + c.balance);
      final suppBalance = suppliers.values.fold(0.0, (s, c) => s + c.balance);

      if (mounted) {
        setState(() {
          _salesTotal = sales;
          _purchasesTotal = purchases;
          _boxReceived = boxBalance;
          _expensesTotal = expenses;
          _customersBalance = custBalance;
          _suppliersBalance = suppBalance;
          _openingBoxBalance = openingBox;

          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _cell(String label, String value,
      {Color bgColor = Colors.white,
      Color textColor = Colors.black87,
      bool isBold = false,
      Color? valueColor}) {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          border: Border.all(color: Colors.grey.shade300, width: 0.5),
        ),
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                color: textColor,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: valueColor ?? textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _twoColRow(Widget right, Widget left) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [right, left],
      ),
    );
  }

  Widget _sectionHeader(String title, Color color) {
    return Container(
      width: double.infinity,
      color: color,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        title,
        textAlign: TextAlign.center,
        style: const TextStyle(
            color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
      ),
    );
  }

  Widget _totalRow(String rightLabel, String rightVal, String leftLabel,
      String leftVal, Color color) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _cell(rightLabel, rightVal,
              bgColor: color.withOpacity(0.15),
              textColor: color,
              isBold: true,
              valueColor: color),
          _cell(leftLabel, leftVal,
              bgColor: color.withOpacity(0.15),
              textColor: color,
              isBold: true,
              valueColor: color),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double tradingX = _salesTotal - _purchasesTotal;
    final bool isTradingProfit = tradingX > 0;
    final bool isTradingEqual = tradingX == 0;

    double plRight = _expensesTotal +
        (isTradingProfit || isTradingEqual ? 0 : tradingX.abs());
    double plLeft = isTradingProfit ? tradingX : 0;
    double netResult = plLeft - plRight;
    final bool isNetProfit = netResult > 0;
    final bool isNetEqual = netResult == 0;

    final double totalBoxBalance = _openingBoxBalance + _boxReceived;
    double balanceRight = _customersBalance +
        totalBoxBalance +
        (isNetProfit || isNetEqual ? 0 : netResult.abs());
    double capital =
        balanceRight - _suppliersBalance - (isNetProfit ? netResult : 0);
    double balanceLeft =
        _suppliersBalance + capital + (isNetProfit ? netResult : 0);

    final Color tradingColor = Colors.blueGrey.shade700;
    final Color plColor = Colors.purple.shade700;
    final Color balColor = const Color.fromARGB(255, 37, 18, 105);

    return Scaffold(
      appBar: AppBar(
        title: const Text('تفصيلات الحساب'),
        backgroundColor: Colors.indigo[700],
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Directionality(
              textDirection: TextDirection.rtl,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _sectionHeader('حساب المتاجرة', tradingColor),
                    _twoColRow(
                      _cell('المشتريات', _purchasesTotal.toStringAsFixed(2)),
                      _cell('المبيعات', _salesTotal.toStringAsFixed(2)),
                    ),
                    if (!isTradingEqual)
                      _twoColRow(
                        isTradingProfit
                            ? _cell('ربح المتاجرة', tradingX.toStringAsFixed(2),
                                bgColor: Colors.green.shade50,
                                textColor: Colors.green.shade800,
                                isBold: true,
                                valueColor: Colors.green.shade800)
                            : _cell('', ''),
                        isTradingProfit
                            ? _cell('', '')
                            : _cell('خسارة المتاجرة',
                                tradingX.abs().toStringAsFixed(2),
                                bgColor: Colors.red.shade50,
                                textColor: Colors.red.shade800,
                                isBold: true,
                                valueColor: Colors.red.shade800),
                      ),
                    _totalRow(
                      'المجموع',
                      isTradingProfit
                          ? _salesTotal.toStringAsFixed(2)
                          : _purchasesTotal.toStringAsFixed(2),
                      'المجموع',
                      isTradingProfit
                          ? _salesTotal.toStringAsFixed(2)
                          : _purchasesTotal.toStringAsFixed(2),
                      tradingColor,
                    ),
                    const SizedBox(height: 7),
                    _sectionHeader('حساب الأرباح والخسائر', plColor),
                    _twoColRow(
                      _cell('المصروف', _expensesTotal.toStringAsFixed(2)),
                      isTradingProfit
                          ? _cell('الربح التجاري', tradingX.toStringAsFixed(2))
                          : _cell('', ''),
                    ),
                    if (!isTradingProfit && !isTradingEqual)
                      _twoColRow(
                        _cell('الخسارة التجارية',
                            tradingX.abs().toStringAsFixed(2)),
                        _cell('', ''),
                      ),
                    if (!isNetEqual)
                      _twoColRow(
                        isNetProfit
                            ? _cell('صافي الربح', netResult.toStringAsFixed(2),
                                bgColor: Colors.green.shade50,
                                textColor: Colors.green.shade800,
                                isBold: true,
                                valueColor: Colors.green.shade800)
                            : _cell('', ''),
                        isNetProfit
                            ? _cell('', '')
                            : _cell('صافي الخسارة',
                                netResult.abs().toStringAsFixed(2),
                                bgColor: Colors.red.shade50,
                                textColor: Colors.red.shade800,
                                isBold: true,
                                valueColor: Colors.red.shade800),
                      ),
                    _totalRow(
                      'المجموع',
                      (isNetProfit ? plLeft : plRight).toStringAsFixed(2),
                      'المجموع',
                      (isNetProfit ? plLeft : plRight).toStringAsFixed(2),
                      plColor,
                    ),
                    const SizedBox(height: 7),
                    _sectionHeader('الميزانية الختامية', balColor),
                    _twoColRow(
                      _cell('الزبائن', _customersBalance.toStringAsFixed(2)),
                      _cell('الموردين', _suppliersBalance.toStringAsFixed(2)),
                    ),
                    _twoColRow(
                      _cell('الصندوق', totalBoxBalance.toStringAsFixed(2)),
                      _cell('رأس المال', capital.toStringAsFixed(2)),
                    ),
                    if (!isNetEqual)
                      _twoColRow(
                        !isNetProfit
                            ? _cell('صافي الخسارة',
                                netResult.abs().toStringAsFixed(2),
                                bgColor: Colors.red.shade50,
                                textColor: Colors.red.shade800,
                                isBold: true,
                                valueColor: Colors.red.shade800)
                            : _cell('', ''),
                        isNetProfit
                            ? _cell('صافي الربح', netResult.toStringAsFixed(2),
                                bgColor: Colors.green.shade50,
                                textColor: Colors.green.shade800,
                                isBold: true,
                                valueColor: Colors.green.shade800)
                            : _cell('', ''),
                      ),
                    _totalRow(
                      'المجموع',
                      balanceRight.toStringAsFixed(2),
                      'المجموع',
                      balanceLeft.toStringAsFixed(2),
                      balColor,
                    ),
                    if ((balanceRight - balanceLeft).abs() > 0.01)
                      Container(
                        color: Colors.orange.shade100,
                        padding: const EdgeInsets.symmetric(
                            vertical: 6, horizontal: 8),
                        child: Text(
                          'الفرق: ${(balanceRight - balanceLeft).toStringAsFixed(2)}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: Colors.orange.shade900,
                              fontWeight: FontWeight.bold,
                              fontSize: 13),
                        ),
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}

// ════════════════════════════════════════════════════
// شاشة النسخ الاحتياطي
// ════════════════════════════════════════════════════

class _BackupInfo {
  final String path;
  final DateTime date;
  final int sizeBytes;

  _BackupInfo(
      {required this.path, required this.date, required this.sizeBytes});

  String _pad(int v) => v.toString().padLeft(2, '0');

  String get formattedDate =>
      '${date.year}/${_pad(date.month)}/${_pad(date.day)}  ${_pad(date.hour)}:${_pad(date.minute)}';

  String get formattedSize {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024)
      return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  String get fileName => path.split('/').last;
}

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  static const _folders = [
    'BoxJournals',
    'SalesJournals',
    'PurchasesJournals',
    'PaymentJournals',
    'AppData',
  ];
  static const _docFiles = [
    'customer_index.json',
    'supplier_index.json',
  ];

  bool _isBusy = false;
  String _statusMsg = '';
  bool _isSuccess = false;
  List<_BackupInfo> _backups = [];

  @override
  void initState() {
    super.initState();
    _loadBackups();
  }

  String _pad(int v) => v.toString().padLeft(2, '0');

  Future<String?> _getAppDataPath() async {
    try {
      final dir = await getExternalStorageDirectory();
      return dir?.path;
    } catch (_) {
      return null;
    }
  }

  Future<Directory> _getBackupFolder() async {
    final dir = Directory('/storage/emulated/0/Download/MarketLedger_Backups');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<void> _createBackup() async {
    if (_isBusy) return;
    setState(() {
      _isBusy = true;
      _isSuccess = false;
      _statusMsg = 'جارٍ النسخ الاحتياطي...';
    });

    try {
      final appPath = await _getAppDataPath();
      if (appPath == null) throw Exception('تعذّر الوصول إلى مجلد البيانات');

      final backupDir = await _getBackupFolder();
      final now = DateTime.now();
      final ts =
          '${now.year}-${_pad(now.month)}-${_pad(now.day)}_${_pad(now.hour)}-${_pad(now.minute)}-${_pad(now.second)}';
      final zipPath = '${backupDir.path}/backup_$ts.zip';

      final encoder = ZipFileEncoder()..create(zipPath);
      int count = 0;

      for (final folderName in _folders) {
        final folder = Directory('$appPath/$folderName');
        if (!await folder.exists()) continue;
        await for (final entity in folder.list(recursive: true)) {
          if (entity is File) {
            encoder.addFile(entity, entity.path.replaceFirst('$appPath/', ''));
            count++;
          }
        }
      }

      final docsDir = await getApplicationDocumentsDirectory();
      for (final fileName in _docFiles) {
        final file = File('${docsDir.path}/$fileName');
        if (await file.exists()) {
          encoder.addFile(file, 'AppDocs/$fileName');
          count++;
        }
      }

      encoder.close();

      if (count == 0) {
        File(zipPath).deleteSync();
        throw Exception('لم يتم العثور على ملفات بيانات');
      }

      setState(() {
        _isBusy = false;
        _isSuccess = true;
        _statusMsg = 'تم حفظ $count ملف بنجاح ✓';
      });

      await _loadBackups();

      if (mounted) {
        await Share.shareXFiles(
          [XFile(zipPath)],
          text: 'نسخة احتياطية – سجل السوق  $ts',
        );
      }
    } catch (e) {
      setState(() {
        _isBusy = false;
        _isSuccess = false;
        _statusMsg = 'خطأ: $e';
      });
    }
  }

  Future<void> _restoreFromFile() async {
    final confirm = await _confirmRestoreDialog();
    if (confirm != true) return;

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
      dialogTitle: 'اختر ملف النسخة الاحتياطية',
    );
    if (result == null || result.files.single.path == null) return;

    await _doRestore(result.files.single.path!);
  }

  Future<void> _restoreFromList(_BackupInfo backup) async {
    final confirm = await _confirmRestoreDialog();
    if (confirm != true) return;
    await _doRestore(backup.path);
  }

  Future<void> _doRestore(String zipPath) async {
    setState(() {
      _isBusy = true;
      _isSuccess = false;
      _statusMsg = 'جارٍ استرجاع البيانات...';
    });

    try {
      final appPath = await _getAppDataPath();
      if (appPath == null) throw Exception('تعذّر الوصول إلى مجلد البيانات');
      final docsDir = await getApplicationDocumentsDirectory();

      final bytes = File(zipPath).readAsBytesSync();
      final archive = ZipDecoder().decodeBytes(bytes);
      int count = 0;

      for (final file in archive) {
        if (!file.isFile) continue;
        final data = file.content as List<int>;
        final String targetPath;

        if (file.name.startsWith('AppDocs/')) {
          targetPath =
              '${docsDir.path}/${file.name.replaceFirst('AppDocs/', '')}';
        } else {
          targetPath = '$appPath/${file.name}';
        }

        final out = File(targetPath);
        await out.parent.create(recursive: true);
        await out.writeAsBytes(data);
        count++;
      }

      setState(() {
        _isBusy = false;
        _isSuccess = true;
        _statusMsg = 'تم استرجاع $count ملف بنجاح ✓';
      });

      if (mounted) {
        _showInfoDialog(
          'تم الاسترجاع ✓',
          'تم استرجاع $count ملف.\nأعد تشغيل التطبيق لرؤية البيانات.',
        );
      }
    } catch (e) {
      setState(() {
        _isBusy = false;
        _isSuccess = false;
        _statusMsg = 'خطأ في الاسترجاع: $e';
      });
    }
  }

  Future<void> _loadBackups() async {
    try {
      final dir = await _getBackupFolder();
      final List<_BackupInfo> list = [];
      await for (final f in dir.list()) {
        if (f is File && f.path.endsWith('.zip')) {
          final stat = await f.stat();
          list.add(_BackupInfo(
            path: f.path,
            date: stat.modified,
            sizeBytes: stat.size,
          ));
        }
      }
      list.sort((a, b) => b.date.compareTo(a.date));
      if (mounted) setState(() => _backups = list);
    } catch (_) {}
  }

  Future<void> _deleteBackup(_BackupInfo backup) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('حذف النسخة'),
        content: Text('حذف ${backup.fileName}؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await File(backup.path).delete();
      await _loadBackups();
    }
  }

  Future<bool?> _confirmRestoreDialog() => showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          icon: const Icon(Icons.warning_amber_rounded,
              color: Colors.orange, size: 44),
          title: const Text('تأكيد الاسترجاع', textAlign: TextAlign.center),
          content: const Text(
            'سيتم استبدال البيانات الحالية.\nهذا الإجراء لا يمكن التراجع عنه.',
            textAlign: TextAlign.center,
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              child:
                  const Text('متابعة', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );

  void _showInfoDialog(String title, String msg) => showDialog(
        context: context,
        builder: (_) => AlertDialog(
          icon: const Icon(Icons.check_circle, color: Colors.green, size: 48),
          title: Text(title, textAlign: TextAlign.center),
          content: Text(msg, textAlign: TextAlign.center),
          actions: [
            ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('حسناً'))
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFF0A1628),
        appBar: AppBar(
          title: const Text('النسخ الاحتياطي'),
          backgroundColor: const Color(0xFF0F4C5C),
          foregroundColor: Colors.white,
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const SizedBox(height: 8),
              _buildMainButton(),
              const SizedBox(height: 16),
              _buildRestoreFromFileButton(),
              if (_statusMsg.isNotEmpty) ...[
                const SizedBox(height: 16),
                _buildStatusBanner(),
              ],
              const SizedBox(height: 28),
              _buildBackupsList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainButton() {
    return Material(
      borderRadius: BorderRadius.circular(18),
      color: Colors.transparent,
      child: InkWell(
        onTap: _isBusy ? null : _createBackup,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0D9488), Color(0xFF0F766E)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0D9488).withOpacity(0.4),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isBusy)
                const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                      strokeWidth: 3, color: Colors.white),
                )
              else
                const Icon(Icons.backup_rounded, color: Colors.white, size: 32),
              const SizedBox(width: 16),
              Text(
                _isBusy ? 'جارٍ النسخ...' : 'نسخ احتياطي الآن',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRestoreFromFileButton() {
    return OutlinedButton.icon(
      onPressed: _isBusy ? null : _restoreFromFile,
      icon: const Icon(Icons.folder_open_rounded),
      label: const Text('استرجاع من ملف ZIP', style: TextStyle(fontSize: 16)),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.purpleAccent,
        side: const BorderSide(color: Colors.purpleAccent, width: 1.5),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 28),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  Widget _buildStatusBanner() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
      decoration: BoxDecoration(
        color: (_isSuccess ? Colors.green : Colors.red).withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (_isSuccess ? Colors.greenAccent : Colors.redAccent)
              .withOpacity(0.5),
        ),
      ),
      child: Row(
        children: [
          Icon(
            _isSuccess ? Icons.check_circle_outline : Icons.error_outline,
            color: _isSuccess ? Colors.greenAccent : Colors.redAccent,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _statusMsg,
              style: TextStyle(
                color: _isSuccess ? Colors.greenAccent : Colors.redAccent,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackupsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.history_rounded,
                color: Colors.tealAccent, size: 20),
            const SizedBox(width: 8),
            const Text(
              'النسخ المحفوظة',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            IconButton(
              onPressed: _loadBackups,
              icon: const Icon(Icons.refresh_rounded,
                  color: Colors.tealAccent, size: 20),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              tooltip: 'تحديث',
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (_backups.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Column(
              children: [
                Icon(Icons.inbox_rounded,
                    color: Colors.white.withOpacity(0.25), size: 36),
                const SizedBox(height: 8),
                Text(
                  'لا توجد نسخ احتياطية محفوظة بعد',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.35), fontSize: 14),
                ),
              ],
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _backups.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) => _buildBackupTile(_backups[i], i == 0),
          ),
      ],
    );
  }

  Widget _buildBackupTile(_BackupInfo backup, bool isLatest) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isLatest
              ? Colors.tealAccent.withOpacity(0.35)
              : Colors.white.withOpacity(0.09),
          width: isLatest ? 1.5 : 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: (isLatest ? Colors.tealAccent : Colors.blueGrey)
                .withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.folder_zip_rounded,
              color: isLatest ? Colors.tealAccent : Colors.blueGrey[300],
              size: 22),
        ),
        title: Row(
          children: [
            Text(backup.formattedDate,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold)),
            if (isLatest) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.tealAccent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('الأحدث',
                    style: TextStyle(color: Colors.tealAccent, fontSize: 10)),
              ),
            ],
          ],
        ),
        subtitle: Text(backup.formattedSize,
            style:
                TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 12)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: () => _restoreFromList(backup),
              icon: const Icon(Icons.restore_rounded,
                  color: Colors.orangeAccent, size: 22),
              tooltip: 'استرجاع',
            ),
            IconButton(
              onPressed: () => Share.shareXFiles([XFile(backup.path)]),
              icon: const Icon(Icons.share_rounded,
                  color: Colors.lightBlueAccent, size: 22),
              tooltip: 'مشاركة',
            ),
            IconButton(
              onPressed: () => _deleteBackup(backup),
              icon: const Icon(Icons.delete_outline_rounded,
                  color: Colors.redAccent, size: 22),
              tooltip: 'حذف',
            ),
          ],
        ),
      ),
    );
  }
}
