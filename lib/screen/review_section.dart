import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/review_model.dart';   
import '../services/review_service.dart'; 

class ReviewSection extends StatefulWidget {
  final String placeId;

  const ReviewSection({super.key, required this.placeId});

  @override
  State<ReviewSection> createState() => _ReviewSectionState();
}

class _ReviewSectionState extends State<ReviewSection> {
  static const Color gold = Color(0xFFC8A96B);
  static const Color darkBrown = Color(0xFF3E2723);

  final ReviewService _reviewService = ReviewService();
  final String? _currentUserId = Supabase.instance.client.auth.currentUser?.id;

  List<ReviewModel> _reviews = [];
  ReviewModel? _myReview;
  double _avgRating = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final results = await Future.wait([
      _reviewService.getReviewsByPlace(widget.placeId),
      _reviewService.getMyReview(widget.placeId),
      _reviewService.getAverageRating(widget.placeId),
    ]);
    if (!mounted) return;
    setState(() {
      _reviews = results[0] as List<ReviewModel>;
      _myReview = results[1] as ReviewModel?;
      _avgRating = results[2] as double;
      _isLoading = false;
    });
  }

  void _openReviewForm({ReviewModel? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ReviewFormSheet(
        placeId: widget.placeId,
        existing: existing,
        onSaved: _loadData,
      ),
    );
  }

  Future<void> _confirmDelete(ReviewModel review) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Hapus Ulasan',
            style: GoogleFonts.cormorantGaramond(
                fontWeight: FontWeight.bold, color: darkBrown)),
        content: Text('Apakah Anda yakin ingin menghapus ulasan ini?',
            style: GoogleFonts.dmSans(color: Colors.grey[700])),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Batal', style: GoogleFonts.dmSans(color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[700], foregroundColor: Colors.white),
            child: Text('Hapus', style: GoogleFonts.dmSans()),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final messenger = ScaffoldMessenger.of(context);
      try {
        await _reviewService.deleteReview(review.id);
        _loadData();
        messenger.showSnackBar(
          _snackBar('Ulasan berhasil dihapus', isError: false),
        );
      } catch (e) {
        messenger.showSnackBar(_snackBar('Gagal menghapus ulasan: $e'));
      }
    }
  }

  SnackBar _snackBar(String msg, {bool isError = true}) => SnackBar(
        content: Text(msg, style: GoogleFonts.dmSans()),
        backgroundColor: isError ? Colors.red[700] : darkBrown,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          avgRating: _avgRating,
          totalReview: _reviews.length,
          onTapAdd: _currentUserId != null && _myReview == null
              ? _openReviewForm
              : null,
        ),
        const SizedBox(height: 16),

        if (_isLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(color: gold),
            ),
          )
        else if (_reviews.isEmpty)
          _EmptyReviewPlaceholder(
            canReview: _currentUserId != null,
            onTap: () => _openReviewForm(),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _reviews.length,
            separatorBuilder: (_, __) => const Divider(height: 1, color: Colors.black12),
            itemBuilder: (_, i) {
              final r = _reviews[i];
              final isOwner = r.userId == _currentUserId;
              return _ReviewCard(
                review: r,
                isOwner: isOwner,
                onEdit: isOwner ? () => _openReviewForm(existing: r) : null,
                onDelete: isOwner ? () => _confirmDelete(r) : null,
              );
            },
          ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final double avgRating;
  final int totalReview;
  final VoidCallback? onTapAdd;

  const _SectionHeader({required this.avgRating, required this.totalReview, this.onTapAdd});

  static const Color gold = Color(0xFFC8A96B);
  static const Color darkBrown = Color(0xFF3E2723);

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              avgRating > 0 ? avgRating.toStringAsFixed(1) : '-',
              style: GoogleFonts.cormorantGaramond(
                  fontSize: 40, fontWeight: FontWeight.bold, color: darkBrown, height: 1),
            ),
            _StarRow(rating: avgRating.round(), size: 14),
            const SizedBox(height: 2),
            Text('$totalReview ulasan', style: GoogleFonts.dmSans(fontSize: 12, color: Colors.grey[500])),
          ],
        ),
        const Spacer(),
        if (onTapAdd != null)
          OutlinedButton.icon(
            onPressed: onTapAdd,
            icon: const Icon(Icons.rate_review_outlined, size: 16, color: gold),
            label: Text('Tulis Ulasan',
                style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: gold)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: gold),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
          ),
      ],
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final ReviewModel review;
  final bool isOwner;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _ReviewCard({required this.review, required this.isOwner, this.onEdit, this.onDelete});

  static const Color gold = Color(0xFFC8A96B);
  static const Color darkBrown = Color(0xFF3E2723);

  @override
  Widget build(BuildContext context) {
    final initials = (review.userName?.isNotEmpty == true) ? review.userName![0].toUpperCase() : '?';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: gold.withOpacity(0.15),
            backgroundImage: review.userAvatarUrl != null ? NetworkImage(review.userAvatarUrl!) : null,
            child: review.userAvatarUrl == null
                ? Text(initials, style: GoogleFonts.dmSans(color: gold, fontWeight: FontWeight.bold))
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Text(
                            review.userName ?? 'Pengunjung',
                            style: GoogleFonts.dmSans(fontWeight: FontWeight.w600, fontSize: 14, color: darkBrown),
                          ),
                          if (isOwner) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: gold.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text('Anda', style: GoogleFonts.dmSans(fontSize: 10, color: gold)),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (isOwner)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            onTap: onEdit,
                            child: const Icon(Icons.edit_outlined, size: 18, color: gold),
                          ),
                          const SizedBox(width: 10),
                          GestureDetector(
                            onTap: onDelete,
                            child: Icon(Icons.delete_outline, size: 18, color: Colors.red[400]),
                          ),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                _StarRow(rating: review.rating, size: 13),
                const SizedBox(height: 6),
                Text(
                  review.comment,
                  style: GoogleFonts.dmSans(fontSize: 13, color: darkBrown.withOpacity(0.75), height: 1.5),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatDate(review.createdAt ?? DateTime.now()),
                  style: GoogleFonts.dmSans(fontSize: 11, color: Colors.grey[400]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    const months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
    return '${dt.day} ${months[dt.month]} ${dt.year}';
  }
}

class _StarRow extends StatelessWidget {
  final int rating;
  final double size;

  const _StarRow({required this.rating, this.size = 16});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        5,
        (i) => Icon(
          i < rating ? Icons.star_rounded : Icons.star_outline_rounded,
          color: const Color(0xFFC8A96B),
          size: size,
        ),
      ),
    );
  }
}

class _EmptyReviewPlaceholder extends StatelessWidget {
  final bool canReview;
  final VoidCallback onTap;

  const _EmptyReviewPlaceholder({required this.canReview, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Column(
          children: [
            Icon(Icons.chat_bubble_outline_rounded, size: 48, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text('Belum ada ulasan untuk museum ini.', style: GoogleFonts.dmSans(color: Colors.grey[500], fontSize: 14)),
            if (canReview) ...[
              const SizedBox(height: 12),
              TextButton(
                onPressed: onTap,
                child: Text(
                  'Jadilah yang pertama mengulas!',
                  style: GoogleFonts.dmSans(color: const Color(0xFFC8A96B), fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ReviewFormSheet extends StatefulWidget {
  final String placeId;
  final ReviewModel? existing;
  final VoidCallback onSaved;

  const _ReviewFormSheet({required this.placeId, this.existing, required this.onSaved});

  @override
  State<_ReviewFormSheet> createState() => _ReviewFormSheetState();
}

class _ReviewFormSheetState extends State<_ReviewFormSheet> {
  static const Color gold = Color(0xFFC8A96B);
  static const Color darkBrown = Color(0xFF3E2723);

  final _formKey = GlobalKey<FormState>();
  final _commentController = TextEditingController();
  final _reviewService = ReviewService();

  int _selectedRating = 0;
  bool _isSaving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _selectedRating = widget.existing!.rating;
      _commentController.text = widget.existing!.comment;
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selectedRating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Pilih bintang rating terlebih dahulu')));
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    // AMAN: Ambil referensi Navigator dan Messenger sebelum jeda async dimulai
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _isSaving = true);
    try {
      if (_isEditing) {
        await _reviewService.updateReview(
          reviewId: widget.existing!.id,
          rating: _selectedRating,
          comment: _commentController.text,
        );
      } else {
        await _reviewService.createReview(
          placeId: widget.placeId,
          rating: _selectedRating,
          comment: _commentController.text,
        );
      }

      // Pastikan widget masih aktif sebelum melakukan aksi UI
      if (!mounted) return;
      
      navigator.pop(); // Menutup bottom sheet dengan aman
      widget.onSaved(); // Memicu pembaruan data di halaman induk

      messenger.showSnackBar(SnackBar(
        content: Text(
            _isEditing ? 'Ulasan berhasil diperbarui' : 'Terima kasih atas ulasan Anda!',
            style: GoogleFonts.dmSans()),
        backgroundColor: darkBrown,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        // Menampilkan teks error asli dari database agar mudah di-debug
        messenger.showSnackBar(SnackBar(
          content: Text('Gagal menyimpan: ${e.toString()}', style: GoogleFonts.dmSans()),
          backgroundColor: Colors.red[700],
          duration: const Duration(seconds: 4),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(24, 20, 24, 24 + bottomInset),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(4)),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            _isEditing ? 'Edit Ulasan Anda' : 'Tulis Ulasan',
            style: GoogleFonts.cormorantGaramond(fontSize: 22, fontWeight: FontWeight.bold, color: darkBrown),
          ),
          const SizedBox(height: 4),
          Text('Bagikan pengalaman kunjungan Anda', style: GoogleFonts.dmSans(fontSize: 13, color: Colors.grey[500])),
          const SizedBox(height: 20),

          Text('Rating', style: GoogleFonts.dmSans(fontWeight: FontWeight.w600, color: darkBrown, fontSize: 14)),
          const SizedBox(height: 8),
          Row(
            children: List.generate(5, (i) {
              final star = i + 1;
              return GestureDetector(
                onTap: () => setState(() => _selectedRating = star),
                child: Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Icon(
                    star <= _selectedRating ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: gold,
                    size: 36,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 4),
          Text(
            _ratingLabel(_selectedRating),
            style: GoogleFonts.dmSans(fontSize: 12, color: gold, fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 16),

          Form(
            key: _formKey,
            child: TextFormField(
              controller: _commentController,
              maxLines: 4,
              maxLength: 500,
              style: GoogleFonts.dmSans(fontSize: 14, color: darkBrown),
              decoration: InputDecoration(
                hintText: 'Ceritakan pengalaman Anda di museum ini...',
                hintStyle: GoogleFonts.dmSans(color: Colors.grey[400], fontSize: 13),
                filled: true,
                fillColor: const Color(0xFFF8F5F0),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: gold, width: 1.5)),
                contentPadding: const EdgeInsets.all(14),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Komentar wajib diisi';
                if (v.trim().length < 10) return 'Komentar minimal 10 karakter';
                return null;
              },
            ),
          ),
          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: gold,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text(
                      _isEditing ? 'SIMPAN PERUBAHAN' : 'KIRIM ULASAN',
                      style: GoogleFonts.dmSans(fontWeight: FontWeight.bold, letterSpacing: 1.1),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  String _ratingLabel(int r) {
    switch (r) {
      case 1: return 'Sangat Mengecewakan';
      case 2: return 'Kurang Memuaskan';
      case 3: return 'Cukup Baik';
      case 4: return 'Memuaskan';
      case 5: return 'Luar Biasa!';
      default: return 'Pilih rating';
    }
  }
}