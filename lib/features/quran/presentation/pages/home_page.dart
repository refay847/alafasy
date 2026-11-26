import 'package:flutter/material.dart';

import '../../data/services/quran_audio_service.dart';
import '../../domain/entities/surah.dart';
import 'player_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.audioService,
    required this.surahs,
  });

  final QuranAudioService audioService;
  final List<Surah> surahs;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String searchQuery = '';

  List<Surah> get filteredSurahs {
    if (searchQuery.trim().isEmpty) {
      return widget.surahs;
    }

    final query = searchQuery.trim().toLowerCase();

    return widget.surahs.where((surah) {
      return surah.arabicName.contains(query) ||
          surah.englishName.toLowerCase().contains(query) ||
          surah.number.toString() == query;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'القرآن الكريم',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      body: Column(
        children: [
          _buildHeader(),
          _buildSearch(),

          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(
                16,
                8,
                16,
                100,
              ),
              itemCount: filteredSurahs.length,
              itemBuilder: (context, index) {
                final surah = filteredSurahs[index];

                return _SurahTile(
                  surah: surah,
                  onTap: () async {
                    await widget.audioService.playSurah(
                      surah.number - 1,
                    );

                    if (!context.mounted) return;

                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => PlayerPage(
                          audioService: widget.audioService,
                          surahs: widget.surahs,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFE7D7AF),
        ),
      ),
      child: Column(
        children: [
          const Text(
            'القرآن الكريم',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Color(0xFF8A6A24),
            ),
          ),

          const SizedBox(height: 8),

          Text(
            'بصوت الشيخ مشاري بن راشد العفاسي',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),

          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8E8),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              '١١٤ سورة',
              style: TextStyle(
                color: Color(0xFF8A6A24),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearch() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextField(
        textDirection: TextDirection.rtl,
        onChanged: (value) {
          setState(() {
            searchQuery = value;
          });
        },
        decoration: InputDecoration(
          hintText: 'ابحث عن سورة...',
          prefixIcon: const Icon(
            Icons.search,
            color: Color(0xFFC49A3A),
          ),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}

class _SurahTile extends StatelessWidget {
  const _SurahTile({
    required this.surah,
    required this.onTap,
  });

  final Surah surah;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(
          color: Color(0xFFEFE5CE),
        ),
      ),
      child: ListTile(
        onTap: onTap,

        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 8,
        ),

        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFFFF7E5),
            border: Border.all(
              color: const Color(0xFFD5B765),
            ),
          ),
          child: Center(
            child: Text(
              '${surah.number}',
              style: const TextStyle(
                color: Color(0xFF8A6A24),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),

        title: Text(
          surah.arabicName,
          textAlign: TextAlign.right,
          style: const TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.bold,
          ),
        ),

        subtitle: Text(
          surah.englishName,
          textAlign: TextAlign.right,
        ),

        trailing: const Icon(
          Icons.play_circle_outline,
          color: Color(0xFFC49A3A),
          size: 32,
        ),
      ),
    );
  }
}