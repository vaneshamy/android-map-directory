import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/activity_log_model.dart'; // INI IMPORT YANG HILANG
import '../services/activity_service.dart';

class ActivityHistoryScreen extends StatefulWidget {
  const ActivityHistoryScreen({Key? key}) : super(key: key);

  @override
  State<ActivityHistoryScreen> createState() => _ActivityHistoryScreenState();
}

class _ActivityHistoryScreenState extends State<ActivityHistoryScreen> {
  static const Color gold      = Color(0xFFC8A96B);
  static const Color darkBrown = Color(0xFF1A1614);
  static const Color bg        = Color(0xFFF8F5F0);

  final ActivityService _activityService = ActivityService();
  late Future<List<ActivityLogModel>> _logsFuture;

  @override
  void initState() {
    super.initState();
    _logsFuture = _activityService.getUserActivityLogs();
  }

  Future<void> _refresh() async {
    setState(() {
      _logsFuture = _activityService.getUserActivityLogs();
    });
    await _logsFuture;
  }

  // ── Format tanggal manual (Indonesia) ───────────────────────────
  String _formatDate(DateTime date) {
    const bulan = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
    ];
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0 && now.day == date.day) {
      final jam = date.hour.toString().padLeft(2, '0');
      final menit = date.minute.toString().padLeft(2, '0');
      return 'Hari ini, $jam:$menit';
    } else if (diff.inDays == 1 ||
        (diff.inDays == 0 && now.day != date.day)) {
      return 'Kemarin';
    }
    return '${date.day} ${bulan[date.month - 1]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));

    return Scaffold(
      backgroundColor: bg,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildHeader(),
          SliverToBoxAdapter(
            child: RefreshIndicator(
              color: gold,
              onRefresh: _refresh,
              child: FutureBuilder<List<ActivityLogModel>>(
                future: _logsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return _buildLoading();
                  }
                  if (snapshot.hasError) {
                    return _buildError();
                  }
                  final logs = snapshot.data ?? [];
                  if (logs.isEmpty) {
                    return _buildEmpty();
                  }
                  return _buildList(logs);
                },
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // HEADER
  // ══════════════════════════════════════════════════════════════
  SliverToBoxAdapter _buildHeader() {
    return SliverToBoxAdapter(
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF5EFE6),
          border: Border(
            bottom: BorderSide(color: Color(0xFFE7DDD0), width: 1),
          ),
        ),
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 8,
          bottom: 18,
          left: 20,
          right: 20,
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: const Color(0xFFE2D7C8)),
                ),
                child: const Icon(
                  Icons.arrow_back_rounded,
                  size: 18,
                  color: Color(0xFF6F6257),
                ),
              ),
            ),
            const Spacer(),
            Text(
              'Riwayat Kunjungan',
              style: GoogleFonts.cormorantGaramond(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: darkBrown,
              ),
            ),
            const Spacer(),
            const SizedBox(width: 38),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // LOADING
  // ══════════════════════════════════════════════════════════════
  Widget _buildLoading() {
    return const Padding(
      padding: EdgeInsets.only(top: 80),
      child: Center(
        child: CircularProgressIndicator(
          color: gold,
          strokeWidth: 2.5,
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // ERROR
  // ══════════════════════════════════════════════════════════════
  Widget _buildError() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 60, 24, 0),
      child: Column(
        children: [
          const Icon(Icons.wifi_off_rounded, size: 46, color: Color(0xFFB5AAA0)),
          const SizedBox(height: 14),
          Text(
            'Gagal memuat riwayat kunjungan.',
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(fontSize: 13, color: const Color(0xFF7A6F65)),
          ),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: _refresh,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: darkBrown,
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(
                'Coba Lagi',
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // EMPTY STATE
  // ══════════════════════════════════════════════════════════════
  Widget _buildEmpty() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 70, 32, 0),
      child: Column(
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: const BoxDecoration(
              color: Color(0xFFF4EFE8),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.history_rounded,
              size: 36,
              color: gold,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Belum Ada Riwayat',
            style: GoogleFonts.cormorantGaramond(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: darkBrown,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Riwayat museum yang Anda kunjungi (buka rute navigasi) akan muncul di sini.',
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(
              fontSize: 12.5,
              color: const Color(0xFF8A8178),
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // LIST
  // ══════════════════════════════════════════════════════════════
  Widget _buildList(List<ActivityLogModel> logs) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('✦', style: TextStyle(color: gold, fontSize: 8)),
              const SizedBox(width: 7),
              Text(
                '${logs.length} KUNJUNGAN',
                style: GoogleFonts.dmSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2,
                  color: const Color(0xFF7A6F65),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...logs.map((log) => _ActivityCard(
                log: log,
                dateLabel: _formatDate(log.createdAt),
              )),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// ACTIVITY CARD
// ══════════════════════════════════════════════════════════════
class _ActivityCard extends StatelessWidget {
  final ActivityLogModel log;
  final String dateLabel;

  const _ActivityCard({required this.log, required this.dateLabel});

  static const Color gold = Color(0xFFC8A96B);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEDE6DC)),
      ),
      child: Row(
        children: [
          // Thumbnail
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 58,
              height: 58,
              child: log.placeImageUrl != null && log.placeImageUrl!.isNotEmpty
                  ? Image.network(
                      log.placeImageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _thumbFallback(),
                    )
                  : _thumbFallback(),
            ),
          ),
          const SizedBox(width: 12),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  log.placeName ?? 'Tempat Tidak Diketahui',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmSans(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1A1614),
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    const Icon(Icons.navigation_rounded, size: 12, color: gold),
                    const SizedBox(width: 5),
                    Text(
                      'Rute dibuka • $dateLabel',
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        color: const Color(0xFF8A8178),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const Icon(
            Icons.chevron_right_rounded,
            size: 18,
            color: Color(0xFFB5AAA0),
          ),
        ],
      ),
    );
  }

  Widget _thumbFallback() {
    return Container(
      color: gold.withOpacity(0.15),
      child: const Center(
        child: Icon(Icons.museum_rounded, size: 22, color: gold),
      ),
    );
  }
}