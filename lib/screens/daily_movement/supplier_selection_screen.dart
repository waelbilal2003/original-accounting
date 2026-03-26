import 'package:flutter/material.dart';
import '../../services/supplier_index_service.dart';
import 'supplier_invoices_screen.dart';
import 'supplier_purchases_screen.dart';

class SupplierSelectionScreen extends StatefulWidget {
  final String selectedDate;
  final String storeName;
  final String reportType; // 'sales' or 'purchases'

  const SupplierSelectionScreen({
    Key? key,
    required this.selectedDate,
    required this.storeName,
    required this.reportType,
  }) : super(key: key);

  @override
  _SupplierSelectionScreenState createState() =>
      _SupplierSelectionScreenState();
}

class _SupplierSelectionScreenState extends State<SupplierSelectionScreen> {
  final SupplierIndexService _supplierIndexService = SupplierIndexService();
  final TextEditingController _searchController = TextEditingController();

  late Future<List<String>> _suppliersFuture;
  List<String> _allSuppliers = [];
  List<String> _filteredSuppliers = [];

  @override
  void initState() {
    super.initState();
    _suppliersFuture = _supplierIndexService.getAllSuppliers();
    _searchController.addListener(_filterSuppliers);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterSuppliers() {
    final query = _searchController.text;
    if (query.isEmpty) {
      setState(() {
        _filteredSuppliers = _allSuppliers;
      });
    } else {
      setState(() {
        _filteredSuppliers = _allSuppliers
            .where((supplier) =>
                supplier.toLowerCase().contains(query.toLowerCase()))
            .toList();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('اختر مورداً لعرض التفاصيل'),
          centerTitle: false,
          backgroundColor: widget.reportType == 'purchases'
              ? Colors.red[700]
              : Colors.teal[700],
          foregroundColor: Colors.white,
        ),
        body: FutureBuilder<List<String>>(
          future: _suppliersFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                  child: Text('خطأ في تحميل الموردين: ${snapshot.error}'));
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(
                child: Text('لا يوجد موردين مسجلين في الفهرس',
                    style: TextStyle(fontSize: 18, color: Colors.grey)),
              );
            }

            if (_allSuppliers.isEmpty) {
              _allSuppliers = snapshot.data!;
              _filteredSuppliers = _allSuppliers;
            }

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      labelText: 'ابحث عن مورد...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: _filteredSuppliers.length,
                    itemBuilder: (context, index) {
                      final supplierName = _filteredSuppliers[index];
                      return ListTile(
                        title: Text(supplierName,
                            style: const TextStyle(fontSize: 18)),
                        leading: Icon(
                          Icons.local_shipping,
                          color: widget.reportType == 'purchases'
                              ? Colors.red[700]
                              : Colors.teal,
                        ),
                        onTap: () {
                          FocusScope.of(context).unfocus();

                          // الشرط يضمن فتح شاشة واحدة فقط
                          if (widget.reportType == 'sales') {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => SupplierInvoicesScreen(
                                  selectedDate: widget.selectedDate,
                                  storeName: widget.storeName,
                                  supplierName: supplierName,
                                ),
                              ),
                            );
                          } else if (widget.reportType == 'purchases') {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => SupplierPurchasesScreen(
                                  selectedDate: widget.selectedDate,
                                  supplierName: supplierName,
                                ),
                              ),
                            );
                          }
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
