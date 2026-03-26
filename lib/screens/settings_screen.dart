import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/material_index_service.dart';
import '../services/packaging_index_service.dart';

class SettingsScreen extends StatefulWidget {
  final String selectedDate;

  const SettingsScreen({super.key, required this.selectedDate});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // خدمات الفهارس
  final MaterialIndexService _materialIndexService = MaterialIndexService();
  final PackagingIndexService _packagingIndexService = PackagingIndexService();

  // قوائم البيانات
  Map<int, String> _materialsWithNumbers = {};
  Map<int, String> _packagingsWithNumbers = {};

  // متغيرات لعرض القوائم
  bool _showMaterialList = false;
  bool _showPackagingList = false;

  // متغيرات للتحكم في التعديل والإضافة
  TextEditingController _addItemController = TextEditingController();
  FocusNode _addItemFocusNode = FocusNode();
  Map<String, TextEditingController> _itemControllers = {};
  Map<String, FocusNode> _itemFocusNodes = {};
  bool _isAddingNewItem = false;

  @override
  void initState() {
    super.initState();
    _loadMaterials();
    _loadPackagings();
  }

  @override
  void dispose() {
    _addItemController.dispose();
    _addItemFocusNode.dispose();
    _disposeItemControllers();
    super.dispose();
  }

  void _disposeItemControllers() {
    _itemControllers.values.forEach((controller) => controller.dispose());
    _itemFocusNodes.values.forEach((focusNode) => focusNode.dispose());
    _itemControllers.clear();
    _itemFocusNodes.clear();
  }

  Future<void> _loadMaterials() async {
    try {
      _materialsWithNumbers =
          await _materialIndexService.getAllMaterialsWithNumbers();
      _initializeMaterialControllers();
      if (mounted) setState(() {});
    } catch (e) {
      print('❌ خطأ في تحميل المواد: $e');
    }
  }

  Future<void> _loadPackagings() async {
    try {
      _packagingsWithNumbers =
          await _packagingIndexService.getAllPackagingsWithNumbers();
      _initializePackagingControllers();
      if (mounted) setState(() {});
    } catch (e) {
      print('❌ خطأ في تحميل العبوات: $e');
    }
  }

  void _initializeMaterialControllers() {
    // تنظيف المتحكمات القديمة
    final currentKeys = _itemControllers.keys.toList();
    for (var key in currentKeys) {
      if (!_materialsWithNumbers.values.contains(key) &&
          !_packagingsWithNumbers.values.contains(key)) {
        _itemControllers[key]?.dispose();
        _itemFocusNodes[key]?.dispose();
        _itemControllers.remove(key);
        _itemFocusNodes.remove(key);
      }
    }

    // إضافة متحكمات جديدة للمواد
    _materialsWithNumbers.forEach((id, name) {
      if (!_itemControllers.containsKey(name)) {
        _itemControllers[name] = TextEditingController(text: name);
        _itemFocusNodes[name] = FocusNode();
        _itemFocusNodes[name]!.addListener(() {
          if (!_itemFocusNodes[name]!.hasFocus) {
            _saveMaterialEdit(id, name);
          }
        });
      }
    });
  }

  void _initializePackagingControllers() {
    // إضافة متحكمات جديدة للعبوات
    _packagingsWithNumbers.forEach((id, name) {
      if (!_itemControllers.containsKey(name)) {
        _itemControllers[name] = TextEditingController(text: name);
        _itemFocusNodes[name] = FocusNode();
        _itemFocusNodes[name]!.addListener(() {
          if (!_itemFocusNodes[name]!.hasFocus) {
            _savePackagingEdit(id, name);
          }
        });
      }
    });
  }

  Future<void> _saveMaterialEdit(int id, String originalValue) async {
    final controller = _itemControllers[originalValue];
    if (controller == null) return;
    final newValue = controller.text.trim();
    if (newValue.isEmpty || newValue == originalValue) {
      controller.text = originalValue;
      return;
    }
    await _materialIndexService.removeMaterial(originalValue);
    await _materialIndexService.saveMaterial(newValue);
    await _loadMaterials();
  }

  Future<void> _savePackagingEdit(int id, String originalValue) async {
    final controller = _itemControllers[originalValue];
    if (controller == null) return;
    final newValue = controller.text.trim();
    if (newValue.isEmpty || newValue == originalValue) {
      controller.text = originalValue;
      return;
    }
    await _packagingIndexService.removePackaging(originalValue);
    await _packagingIndexService.savePackaging(newValue);
    await _loadPackagings();
  }

  Future<void> _addNewMaterial(String value) async {
    if (value.trim().isEmpty) return;
    try {
      await _materialIndexService.saveMaterial(value);
      await _loadMaterials();
      _addItemController.clear();
      setState(() => _isAddingNewItem = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم إضافة "$value" بنجاح'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ أثناء الإضافة: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _addNewPackaging(String value) async {
    if (value.trim().isEmpty) return;
    try {
      await _packagingIndexService.savePackaging(value);
      await _loadPackagings();
      _addItemController.clear();
      setState(() => _isAddingNewItem = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم إضافة "$value" بنجاح'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ أثناء الإضافة: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteMaterial(String material, int id) async {
    final confirm = await _showConfirmDialog(
      'تأكيد الحذف',
      'هل أنت متأكد من حذف المادة "$material"؟',
    );
    if (confirm) {
      await _materialIndexService.removeMaterial(material);
      await _loadMaterials();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم حذف "$material" بنجاح'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  Future<void> _deletePackaging(String packaging, int id) async {
    final confirm = await _showConfirmDialog(
      'تأكيد الحذف',
      'هل أنت متأكد من حذف العبوة "$packaging"؟',
    );
    if (confirm) {
      await _packagingIndexService.removePackaging(packaging);
      await _loadPackagings();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم حذف "$packaging" بنجاح'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  Future<bool> _showConfirmDialog(String title, String content) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(content),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('إلغاء'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('تأكيد'),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _showChangePasswordDialog() {
    final oldCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    final oldFocus = FocusNode();
    final newFocus = FocusNode();
    final confirmFocus = FocusNode();
    String? dialogError;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            Future<void> doChange() async {
              final prefs = await SharedPreferences.getInstance();
              final stored = prefs.getString('app_password') ?? '';
              if (oldCtrl.text.trim() != stored) {
                setDialogState(
                    () => dialogError = 'كلمة المرور القديمة غير صحيحة');
                return;
              }
              if (newCtrl.text.trim().length < 4) {
                setDialogState(
                    () => dialogError = 'كلمة المرور الجديدة 4 أحرف على الأقل');
                return;
              }
              if (newCtrl.text.trim() != confirmCtrl.text.trim()) {
                setDialogState(() =>
                    dialogError = 'كلمة المرور الجديدة وتأكيدها غير متطابقتين');
                return;
              }
              await prefs.setString('app_password', newCtrl.text.trim());
              Navigator.pop(ctx);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✅ تم تغيير كلمة المرور بنجاح'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            }

            return Directionality(
              textDirection: TextDirection.rtl,
              child: AlertDialog(
                titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                title: Row(
                  children: [
                    Icon(Icons.lock_reset, color: Colors.orange[700], size: 28),
                    const SizedBox(width: 12),
                    const Text(
                      'تغيير كلمة المرور',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                content: SizedBox(
                  width: MediaQuery.of(context).size.width * 0.8,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 8),
                      TextField(
                        controller: oldCtrl,
                        focusNode: oldFocus,
                        obscureText: true,
                        textInputAction: TextInputAction.next,
                        onSubmitted: (_) =>
                            FocusScope.of(ctx).requestFocus(newFocus),
                        decoration: InputDecoration(
                          labelText: 'كلمة المرور القديمة',
                          prefixIcon: const Icon(Icons.lock_outline),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: newCtrl,
                        focusNode: newFocus,
                        obscureText: true,
                        textInputAction: TextInputAction.next,
                        onSubmitted: (_) =>
                            FocusScope.of(ctx).requestFocus(confirmFocus),
                        decoration: InputDecoration(
                          labelText: 'كلمة المرور الجديدة',
                          prefixIcon: const Icon(Icons.lock),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: confirmCtrl,
                        focusNode: confirmFocus,
                        obscureText: true,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => doChange(),
                        decoration: InputDecoration(
                          labelText: 'تأكيد كلمة المرور الجديدة',
                          prefixIcon: const Icon(Icons.lock_reset),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                      ),
                      if (dialogError != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.red[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red[200]!),
                          ),
                          child: Text(
                            dialogError!,
                            style: const TextStyle(
                                color: Colors.red, fontSize: 13),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                actionsPadding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                    ),
                    child: const Text('إلغاء', style: TextStyle(fontSize: 16)),
                  ),
                  ElevatedButton(
                    onPressed: doChange,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange[700],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('تغيير',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMainButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      textDirection: TextDirection.rtl,
      children: [
        _buildIndexButton('فهرس المواد', Icons.shopping_basket, () {
          setState(() {
            _showMaterialList = true;
            _showPackagingList = false;
            _isAddingNewItem = false;
          });
          _loadMaterials();
        }),
        _buildIndexButton('فهرس العبوات', Icons.inventory_2, () {
          setState(() {
            _showMaterialList = false;
            _showPackagingList = true;
            _isAddingNewItem = false;
          });
          _loadPackagings();
        }),
        _buildIndexButton(
            'تغيير كلمة المرور', Icons.lock_reset, _showChangePasswordDialog),
      ],
    );
  }

  Widget _buildIndexButton(String text, IconData icon, VoidCallback onPressed) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        child: ElevatedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon, size: 24, color: Colors.blueGrey[800]),
          label: Text(
            text,
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.blueGrey[800]),
            textAlign: TextAlign.center,
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 4,
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentList() {
    if (_showMaterialList) return _buildMaterialList();
    if (_showPackagingList) return _buildPackagingList();
    return const SizedBox.shrink();
  }

  Widget _buildMaterialList() {
    List<MapEntry<int, String>> sortedEntries = _materialsWithNumbers.entries
        .toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return _buildEditableList(
      title: 'فهرس المواد',
      itemsMap: _materialsWithNumbers,
      sortedEntries: sortedEntries,
      onAdd: _addNewMaterial,
      onDelete: _deleteMaterial,
      hintText: 'أدخل اسم المادة الجديدة...',
    );
  }

  Widget _buildPackagingList() {
    List<MapEntry<int, String>> sortedEntries = _packagingsWithNumbers.entries
        .toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return _buildEditableList(
      title: 'فهرس العبوات',
      itemsMap: _packagingsWithNumbers,
      sortedEntries: sortedEntries,
      onAdd: _addNewPackaging,
      onDelete: _deletePackaging,
      hintText: 'أدخل اسم العبوة الجديدة...',
    );
  }

  Widget _buildEditableList({
    required String title,
    required Map<int, String> itemsMap,
    required List<MapEntry<int, String>> sortedEntries,
    required Function(String) onAdd,
    required Function(String, int) onDelete,
    required String hintText,
  }) {
    return Container(
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // رأس القائمة
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            textDirection: TextDirection.rtl,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              IconButton(
                icon: Icon(
                  _isAddingNewItem ? Icons.close : Icons.add_circle,
                  color: Colors.white,
                  size: 30,
                ),
                onPressed: () {
                  setState(() {
                    _isAddingNewItem = !_isAddingNewItem;
                    if (!_isAddingNewItem) {
                      _addItemController.clear();
                    } else {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _addItemFocusNode.requestFocus();
                      });
                    }
                  });
                },
              ),
            ],
          ),

          // حقل الإضافة
          if (_isAddingNewItem) ...[
            const SizedBox(height: 15),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                textDirection: TextDirection.rtl,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _addItemController,
                      focusNode: _addItemFocusNode,
                      textDirection: TextDirection.rtl,
                      decoration: InputDecoration(
                        hintText: hintText,
                        border: InputBorder.none,
                      ),
                      onSubmitted: (value) => onAdd(value),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.check_circle,
                        color: Colors.teal, size: 28),
                    onPressed: () {
                      if (_addItemController.text.trim().isNotEmpty) {
                        onAdd(_addItemController.text);
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 15),
          ],

          // رأس الجدول
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            child: Row(
              textDirection: TextDirection.rtl,
              children: [
                const SizedBox(width: 50),
                _buildHeaderCell('الرقم', 1),
                _buildHeaderCell('الاسم', 4),
              ],
            ),
          ),
          const Divider(color: Colors.white70, thickness: 1),

          // عرض الرسالة إذا كانت القائمة فارغة
          if (sortedEntries.isEmpty && !_isAddingNewItem)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 30),
              child: Column(
                children: [
                  Icon(Icons.inventory_2_outlined,
                      color: Colors.white.withOpacity(0.3), size: 50),
                  const SizedBox(height: 10),
                  Text(
                    'لا توجد سجلات حالياً.\nاضغط على زر (+) في الأعلى للإضافة.',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

          // عرض البيانات
          if (sortedEntries.isNotEmpty)
            ...sortedEntries.map((entry) {
              final id = entry.key;
              final item = entry.value;
              final controller =
                  _itemControllers[item] ?? TextEditingController(text: item);
              final focusNode = _itemFocusNodes[item] ?? FocusNode();

              return Container(
                margin: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                      color: Colors.white.withOpacity(0.1), width: 1),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6.0),
                  child: Row(
                    textDirection: TextDirection.rtl,
                    children: [
                      SizedBox(
                        width: 50,
                        child: Center(
                          child: IconButton(
                            icon: const Icon(Icons.delete_forever,
                                color: Colors.red, size: 20),
                            onPressed: () => onDelete(item, id),
                          ),
                        ),
                      ),
                      _buildDataCell(id.toString(), 1),
                      Expanded(
                        flex: 4,
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: TextField(
                            controller: controller,
                            focusNode: focusNode,
                            textDirection: TextDirection.rtl,
                            style: const TextStyle(
                                fontSize: 14, color: Colors.white),
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(vertical: 8),
                            ),
                            onSubmitted: (val) {
                              if (title == 'فهرس المواد') {
                                _saveMaterialEdit(id, item);
                              } else {
                                _savePackagingEdit(id, item);
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(String text, int flex) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildDataCell(String text, int flex) {
    return Expanded(
      flex: flex,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          text,
          style: const TextStyle(fontSize: 14, color: Colors.white),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blueGrey[400]!, Colors.blueGrey[700]!],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('الإعدادات'),
          backgroundColor: Colors.blueGrey[800],
          foregroundColor: Colors.white,
          centerTitle: true,
          elevation: 0,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              _buildMainButtons(),
              const SizedBox(height: 20),
              _buildCurrentList(),
            ],
          ),
        ),
      ),
    );
  }
}
