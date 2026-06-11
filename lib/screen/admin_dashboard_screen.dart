import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'login_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;
  List<Map<String, dynamic>> _museums = [];
  
  // --- TAMBAHKAN DUA BARIS INI ---
  List<Map<String, dynamic>> _categories = []; 
  String? _selectedCategoryId;

  // Variabel controller untuk Form Input CRUD
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _descController = TextEditingController();
  final _hoursController = TextEditingController();
  final _photoController = TextEditingController();
  final _latController = TextEditingController();
  final _lngController = TextEditingController();

  static const Color _gold = Color(0xFFC8A96B);
  static const Color _darkBrown = Color(0xFF3E2723);
  static const Color _bg = Color(0xFFF8F5F0);

  @override
  @override
  void initState() {
    super.initState();
    _fetchMuseums();
    _fetchCategories(); // <--- PANGGIL FUNGSI INI
  }

  // Fungsi baru untuk mengambil list kategori dari Supabase
  Future<void> _fetchCategories() async {
    try {
      final data = await _supabase.from('categories').select('id, name');
      setState(() {
        _categories = List<Map<String, dynamic>>.from(data);
      });
    } catch (e) {
      debugPrint('Gagal mengambil kategori: $e');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _descController.dispose();
    _hoursController.dispose();
    _photoController.dispose();
    _latController.dispose();
    _lngController.dispose();
    super.dispose();
  }

  // ================= CRUD OPERATIONS =================

  // 1. READ: Ambil data dari tabel places Supabase
  Future<void> _fetchMuseums() async {
    setState(() => _isLoading = true);
    try {
      final data = await _supabase
          .from('places')
          .select()
          .order('created_at', ascending: false);
      setState(() => _museums = List<Map<String, dynamic>>.from(data));
    } catch (e) {
      _showSnackBar('Gagal memuat data: $e', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // 2. CREATE & UPDATE: Simpan data baru atau ubah data lama
Future<void> _saveMuseum({String? id}) async {
    if (_nameController.text.isEmpty || _addressController.text.isEmpty) {
      _showSnackBar('Nama dan Alamat wajib diisi!', isError: true);
      return;
    }
    
    // Validasi apakah admin sudah memilih kategori
    if (_selectedCategoryId == null) {
      _showSnackBar('Silakan pilih kategori museum terlebih dahulu!', isError: true);
      return;
    }

    final museumData = {
      'name': _nameController.text.trim(),
      'address': _addressController.text.trim(),
      'description': _descController.text.trim(),
      'open_hours': _hoursController.text.trim(),
      'photo_url': _photoController.text.trim().isEmpty ? null : _photoController.text.trim(),
      'lat': double.tryParse(_latController.text) ?? -7.250445,
      'lng': double.tryParse(_lngController.text) ?? 112.768845,
      'category_id': _selectedCategoryId, // <--- ID Kategori diambil langsung dari dropdown yang dipilih admin
      'is_active': true,
    };

    try {
      if (id == null) {
        await _supabase.from('places').insert(museumData);
        _showSnackBar('Museum baru berhasil ditambahkan!');
      } else {
        await _supabase.from('places').update(museumData).eq('id', id);
        _showSnackBar('Data museum berhasil diperbarui!');
      }
      Navigator.pop(context);
      _fetchMuseums();
    } catch (e) {
      _showSnackBar('Gagal menyimpan: $e', isError: true);
    }
  }

  // 3. DELETE: Hapus baris data dari tabel places
  Future<void> _deleteMuseum(String id) async {
    try {
      await _supabase.from('places').delete().eq('id', id);
      _showSnackBar('Museum berhasil dihapus.');
      _fetchMuseums();
    } catch (e) {
      _showSnackBar('Gagal menghapus data: $e', isError: true);
    }
  }

  // ================= UI WINDOWS & DIALOGS =================

  void _showFormDialog({Map<String, dynamic>? museum}) {
    if (museum != null) {
      _nameController.text = museum['name'] ?? '';
      _addressController.text = museum['address'] ?? '';
      _descController.text = museum['description'] ?? '';
      _hoursController.text = museum['open_hours'] ?? '';
      _photoController.text = museum['photo_url'] ?? '';
      _latController.text = museum['lat']?.toString() ?? '';
      _lngController.text = museum['lng']?.toString() ?? '';
      _selectedCategoryId = museum['category_id']?.toString();
    } else {
      _nameController.clear();
      _addressController.clear();
      _descController.clear();
      _hoursController.clear();
      _photoController.clear();
      _latController.clear();
      _lngController.clear();
      _selectedCategoryId = _categories.isNotEmpty ? _categories[0]['id'] : null;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                museum == null ? 'Tambah Museum Baru' : 'Edit Data Museum',
                style: GoogleFonts.cormorantGaramond(fontSize: 24, fontWeight: FontWeight.bold, color: _darkBrown),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedCategoryId,
                hint: const Text('Pilih Kategori Museum'),
                decoration: const InputDecoration(
                  labelText: 'Kategori',
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFC8A96B))),
                ),
                items: _categories.map((cat) {
                  return DropdownMenuItem<String>(
                    value: cat['id'].toString(),
                    child: Text(cat['name'] ?? 'Tanpa Nama', style: GoogleFonts.dmSans()),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedCategoryId = value;
                  });
                },
              ),
              const SizedBox(height: 12),
              _buildFormTextField(_nameController, 'Nama Museum'),
              _buildFormTextField(_addressController, 'Alamat Lengkap'),
              _buildFormTextField(_descController, 'Deskripsi Sejarah / Informasi', maxLines: 3),
              _buildFormTextField(_hoursController, 'Jam Operasional (cth: 08:00 - 16:00)'),
              _buildFormTextField(_photoController, 'URL Foto Banner'),
              Row(
                children: [
                  Expanded(child: _buildFormTextField(_latController, 'Latitude', keyboardType: TextInputType.number)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildFormTextField(_lngController, 'Longitude', keyboardType: TextInputType.number)),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: _darkBrown, foregroundColor: Colors.white),
                  onPressed: () => _saveMuseum(id: museum?['id']),
                  child: Text('Simpan Perubahan', style: GoogleFonts.dmSans(fontWeight: FontWeight.bold)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormTextField(TextEditingController controller, String hint, {int maxLines = 1, TextInputType? keyboardType}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: hint,
          labelStyle: GoogleFonts.dmSans(color: _darkBrown.withOpacity(0.6), fontSize: 13),
          focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: _gold)),
        ),
      ),
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.dmSans(fontSize: 13)),
        backgroundColor: isError ? Colors.red[700] : _gold,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _logout() async {
    await _supabase.auth.signOut();
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  // ================= MAIN BUILD METHOD =================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: Text('Admin Panel - CRUD Museum', style: GoogleFonts.cormorantGaramond(fontWeight: FontWeight.bold)),
        backgroundColor: _darkBrown,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _fetchMuseums,
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: _logout,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _gold))
          : _museums.isEmpty
              ? Center(child: Text('Belum ada museum terdaftar.', style: GoogleFonts.dmSans(color: Colors.grey)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _museums.length,
                  itemBuilder: (context, index) {
                    final item = _museums[index];
                    return Card(
                      color: Colors.white,
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: _gold.withOpacity(0.2)),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(12),
                        leading: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: _gold.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: item['photo_url'] != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(item['photo_url'], fit: BoxFit.cover),
                                )
                              : const Icon(Icons.museum, color: _gold),
                        ),
                        title: Text(
                          item['name'] ?? 'Tanpa Nama',
                          style: GoogleFonts.dmSans(fontWeight: FontWeight.bold, color: _darkBrown),
                        ),
                        subtitle: Text(
                          item['address'] ?? '-',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.dmSans(fontSize: 12, color: Colors.grey[600]),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, color: Colors.blue),
                              onPressed: () => _showFormDialog(museum: item),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                              onPressed: () {
                                // Konfirmasi Hapus Data
                                showDialog(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Hapus Data'),
                                    content: const Text('Apakah Anda yakin ingin menghapus museum ini?'),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
                                      TextButton(
                                        onPressed: () {
                                          Navigator.pop(ctx);
                                          _deleteMuseum(item['id']);
                                        },
                                        child: const Text('Hapus', style: TextStyle(color: Colors.red)),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: _gold,
        foregroundColor: Colors.white,
        onPressed: () => _showFormDialog(),
        child: const Icon(Icons.add_rounded, size: 28),
      ),
    );
  }
}