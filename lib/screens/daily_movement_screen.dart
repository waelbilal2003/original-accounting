import 'package:flutter/material.dart';
import '../services/store_db_service.dart';
import 'daily_movement/purchases_screen.dart';
import 'daily_movement/sales_screen.dart';
import 'daily_movement/box_screen.dart';
import 'bait_screen.dart';
import 'daily_movement/invoice_type_selection_screen.dart';
import 'preferences_screen.dart';

class DailyMovementScreen extends StatefulWidget {
  final String selectedDate;
  final String storeType;
  final String sellerName;

  const DailyMovementScreen({
    super.key,
    required this.selectedDate,
    required this.storeType,
    required this.sellerName,
  });

  @override
  State<DailyMovementScreen> createState() => _DailyMovementScreenState();
}

class _DailyMovementScreenState extends State<DailyMovementScreen> {
  String _storeName = '';

  @override
  void initState() {
    super.initState();
    _loadStoreName();
  }

  Future<void> _loadStoreName() async {
    final storeDbService = StoreDbService();
    final savedStoreName = await storeDbService.getStoreName();
    setState(() {
      _storeName = savedStoreName ?? widget.storeType;
    });
  }

  void _handleBackButton() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.of(context).pop();
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('الحركة اليومية لتاريخ ${widget.selectedDate}',
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
          centerTitle: true,
          backgroundColor: Colors.green[600],
          foregroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _handleBackButton,
          ),
        ),
        body: Directionality(
          textDirection: TextDirection.rtl,
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(vertical: 2, horizontal: 24),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  boxShadow: [
                    BoxShadow(
                        color: Colors.grey.withOpacity(0.2),
                        spreadRadius: 1,
                        blurRadius: 3)
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7.0, vertical: 10.0),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isSmallScreen = constraints.maxWidth < 500;

                      if (isSmallScreen) {
                        return Column(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Expanded(
                              child: _buildMenuButton(
                                context,
                                icon: Icons.point_of_sale,
                                label: 'المبيعات',
                                color: Colors.orange[700]!,
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) => SalesScreen(
                                          sellerName: widget.sellerName,
                                          selectedDate: widget.selectedDate,
                                          storeName: _storeName),
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 12.0),
                            Expanded(
                              child: _buildMenuButton(
                                context,
                                icon: Icons.shopping_cart,
                                label: 'المشتريات',
                                color: Colors.red[700]!,
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) => PurchasesScreen(
                                          sellerName: widget.sellerName,
                                          selectedDate: widget.selectedDate,
                                          storeName: _storeName),
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 12.0),
                            Expanded(
                              child: _buildMenuButton(
                                context,
                                icon: Icons.receipt_long,
                                label: 'الفواتير',
                                color: Colors.blueGrey[600]!,
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          InvoiceTypeSelectionScreen(
                                        selectedDate: widget.selectedDate,
                                        storeName: _storeName,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 12.0),
                            Expanded(
                              child: _buildMenuButton(
                                context,
                                icon: Icons.analytics,
                                label: 'التفصيلات',
                                color: Colors.blueGrey[700]!,
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) => PreferencesScreen(
                                        selectedDate: widget.selectedDate,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 12.0),
                            Expanded(
                              child: _buildMenuButton(
                                context,
                                icon: Icons.account_balance,
                                label: 'الصندوق',
                                color: Colors.indigo[700]!,
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) => BoxScreen(
                                          sellerName: widget.sellerName,
                                          selectedDate: widget.selectedDate,
                                          storeName: _storeName),
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 12.0),
                            Expanded(
                              child: _buildMenuButton(
                                context,
                                icon: Icons.inventory_2,
                                label: 'البايت',
                                color: Colors.teal[700]!,
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) => BaitScreen(
                                        selectedDate: widget.selectedDate,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        );
                      } else {
                        return Column(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Expanded(
                                    child: _buildMenuButton(
                                      context,
                                      icon: Icons.point_of_sale,
                                      label: 'المبيعات',
                                      color: Colors.orange[700]!,
                                      onTap: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (context) => SalesScreen(
                                                sellerName: widget.sellerName,
                                                selectedDate:
                                                    widget.selectedDate,
                                                storeName: _storeName),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 12.0),
                                  Expanded(
                                    child: _buildMenuButton(
                                      context,
                                      icon: Icons.shopping_cart,
                                      label: 'المشتريات',
                                      color: Colors.red[700]!,
                                      onTap: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                PurchasesScreen(
                                                    sellerName:
                                                        widget.sellerName,
                                                    selectedDate:
                                                        widget.selectedDate,
                                                    storeName: _storeName),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 12.0),
                                  Expanded(
                                    child: _buildMenuButton(
                                      context,
                                      icon: Icons.receipt_long,
                                      label: 'الفواتير',
                                      color: Colors.blueGrey[600]!,
                                      onTap: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                InvoiceTypeSelectionScreen(
                                              selectedDate: widget.selectedDate,
                                              storeName: _storeName,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12.0),
                            Expanded(
                              child: Row(
                                children: [
                                  Expanded(
                                    child: _buildMenuButton(
                                      context,
                                      icon: Icons.analytics,
                                      label: 'التفصيلات',
                                      color: Colors.blueGrey[700]!,
                                      onTap: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                PreferencesScreen(
                                              selectedDate: widget.selectedDate,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 12.0),
                                  Expanded(
                                    child: _buildMenuButton(
                                      context,
                                      icon: Icons.account_balance,
                                      label: 'الصندوق',
                                      color: Colors.indigo[700]!,
                                      onTap: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (context) => BoxScreen(
                                                sellerName: widget.sellerName,
                                                selectedDate:
                                                    widget.selectedDate,
                                                storeName: _storeName),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 12.0),
                                  Expanded(
                                    child: _buildMenuButton(
                                      context,
                                      icon: Icons.inventory_2,
                                      label: 'البايت',
                                      color: Colors.teal[700]!,
                                      onTap: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (context) => BaitScreen(
                                              selectedDate: widget.selectedDate,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuButton(BuildContext context,
      {required IconData icon,
      required String label,
      required Color color,
      VoidCallback? onTap}) {
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
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 42,
                color: Colors.white,
              ),
              const SizedBox(height: 12),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
