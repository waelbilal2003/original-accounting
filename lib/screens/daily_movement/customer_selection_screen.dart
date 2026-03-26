import 'package:flutter/material.dart';
import '../../services/customer_index_service.dart';
import 'invoices_screen.dart';

class CustomerSelectionScreen extends StatefulWidget {
  final String selectedDate;
  final String storeName;

  const CustomerSelectionScreen({
    Key? key,
    required this.selectedDate,
    required this.storeName,
  }) : super(key: key);

  @override
  _CustomerSelectionScreenState createState() =>
      _CustomerSelectionScreenState();
}

class _CustomerSelectionScreenState extends State<CustomerSelectionScreen> {
  final CustomerIndexService _customerIndexService = CustomerIndexService();
  final TextEditingController _searchController = TextEditingController();

  late Future<List<String>> _customersFuture;
  List<String> _allCustomers = [];
  List<String> _filteredCustomers = [];

  @override
  void initState() {
    super.initState();
    _customersFuture = _customerIndexService.getAllCustomers();
    _searchController.addListener(_filterCustomers);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterCustomers() {
    final query = _searchController.text;
    if (query.isEmpty) {
      setState(() {
        _filteredCustomers = _allCustomers;
      });
    } else {
      setState(() {
        _filteredCustomers = _allCustomers
            .where((customer) =>
                customer.toLowerCase().startsWith(query.toLowerCase()))
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
          title: const Text('اختر زبوناً لعرض الفاتورة'),
          centerTitle: false,
          backgroundColor: Colors.indigo[700],
          foregroundColor: Colors.white,
        ),
        body: FutureBuilder<List<String>>(
          future: _customersFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                  child: Text('خطأ في تحميل الزبائن: ${snapshot.error}'));
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(
                child: Text('لا يوجد زبائن مسجلين في الفهرس',
                    style: TextStyle(fontSize: 18, color: Colors.grey)),
              );
            }

            // تخزين القائمة الكاملة لأول مرة فقط
            if (_allCustomers.isEmpty) {
              _allCustomers = snapshot.data!;
              _filteredCustomers = _allCustomers;
            }

            // --- بداية الواجهة الجديدة مع حقل البحث ---
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      labelText: 'ابحث عن زبون...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: _filteredCustomers.length,
                    itemBuilder: (context, index) {
                      final customerName = _filteredCustomers[index];
                      return ListTile(
                        title: Text(customerName,
                            style: const TextStyle(fontSize: 18)),
                        leading: const Icon(Icons.person, color: Colors.indigo),
                        onTap: () {
                          // إخفاء لوحة المفاتيح عند الانتقال
                          FocusScope.of(context).unfocus();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => InvoicesScreen(
                                selectedDate: widget.selectedDate,
                                storeName: widget.storeName,
                                customerName: customerName,
                              ),
                            ),
                          );
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
