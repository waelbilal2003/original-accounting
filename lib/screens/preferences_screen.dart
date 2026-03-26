import 'package:flutter/material.dart';
import 'customer_preferences_screen.dart';
import 'supplier_preferences_screen.dart';
import '../services/customer_index_service.dart';
import '../services/supplier_index_service.dart';
import 'settings_screen.dart';
import 'opening_balances_screen.dart';
import 'account_summary_screen.dart';
import 'backup_screen_state.dart';

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
