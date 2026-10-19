import 'package:flutter/material.dart';
import 'package:radiologist_ai/api/crud.dart';
import 'package:radiologist_ai/api/links.dart';
import 'package:radiologist_ai/body_of_main_view/sidebar.dart';
import 'package:radiologist_ai/core/theme/app_colors.dart';
import 'package:radiologist_ai/main.dart';
import 'package:url_launcher/url_launcher.dart';

class DiagnosticRecord {
  final int diagnosisId;
  final int patientId;
  final String date;
  final String file;
  final String image;

  const DiagnosticRecord({
    required this.diagnosisId,
    required this.patientId,
    required this.date,
    required this.file,
    required this.image,
  });
}

class ViewDashboard extends StatefulWidget {
  const ViewDashboard({super.key});

  @override
  State<ViewDashboard> createState() => _ViewDashboardState();
}

class _ViewDashboardState extends State<ViewDashboard> {
  final TextEditingController _searchController = TextEditingController();

  ///////////////////////////////////////////
  //////////////////API//////////////////////
  ///////////////////////////////////////////
  final Crud _crud = Crud();

  bool isLoading = false;

  Future<void> getViewRecords() async {
    try {
      setState(() {
        isLoading = true;
      });

      var response = await _crud.postRequest(linkAiResultView, {});

      if (response['status'] == 'success') {
        final List data = response['data'];

        setState(() {
          _records.clear();

          for (var item in data) {
            _records.add(
              DiagnosticRecord(
                diagnosisId: int.parse(item['diagnosis_id'].toString()),
                patientId: int.parse(item['patient_id'].toString()),
                date: item['date'].toString(),
                file: item['file'].toString(),
                image: item['img'].toString(),
              ),
            );
          }
        });
      } else {
        setState(() {
          _records.clear();
        });
      }
    } catch (e) {
      debugPrint("getViewRecords error ====> $e");
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> deleteRecord(String diagnosisId) async {
    try {
      //
      var response = await _crud.postRequest(linkAiResultDelete, {
        "diagnosis_id": diagnosisId,
      });
      //

      if (response['status'] == "success") {
        setState(() {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Success')));
        });
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Fail')));
        return;
      }
    } catch (e) {
      print("catch error ====> $e");
    }
  }

  ///////////////////////////////////////////////////////
  ///

  final List<DiagnosticRecord> _records = [];

  String _searchText = '';

  List<DiagnosticRecord> get _filteredRecords {
    if (_searchText.trim().isEmpty) {
      return _records;
    }

    final query = _searchText.trim().toLowerCase();

    return _records.where((record) {
      return record.patientId.toString().contains(query) ||
          record.file.toLowerCase().contains(query);
    }).toList();
  }

  @override
  void initState() {
    super.initState();

    _searchController.addListener(() {
      setState(() {
        _searchText = _searchController.text;
      });
    });

    getViewRecords();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _deleteRecord(DiagnosticRecord record) {
    showDialog(
      context: context,
      builder: (context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: AppColors.slateGrey,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            title: const Text(
              'حذف التقرير',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Text(
              'هل أنت متأكد من أنك تريد حذف تقرير المريض رقم ${record.patientId}؟\n\nلا يمكن التراجع عن هذه العملية.',
              style: const TextStyle(
                color: AppColors.textSecondary,
                height: 1.6,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'إلغاء',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.red,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () {
                  deleteRecord(record.diagnosisId.toString());
                  Navigator.pop(context);

                  setState(() {
                    _records.remove(record);
                  });

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'تم حذف التقرير بنجاح',
                        textAlign: TextAlign.right,
                      ),
                    ),
                  );
                },
                child: const Text('حذف'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openPdf(DiagnosticRecord record) async {
    try {
      final Uri url = Uri.parse(record.file);

      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Open PDF error: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تعذر فتح ملف التقرير')));
    }
  }

  void _createNewReport() {
    thisIndex = 0;
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil("main_dashboard", (route) => false);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navyDark,
      body: Row(
        children: [
          Sidebar(),
          Expanded(
            flex: 7,
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: _buildMainContent(),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // MAIN CONTENT
  // =========================================================

  Widget _buildMainContent() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(35, 30, 35, 35),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight - 65),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),

                const SizedBox(height: 30),

                _buildTopSection(),

                const SizedBox(height: 28),

                _buildRecordsHeader(),

                const SizedBox(height: 18),

                _buildRecordsList(),
              ],
            ),
          ),
        );
      },
    );
  }

  // =========================================================
  // HEADER
  // =========================================================

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'سجلات التشخيص',
          style: TextStyle(
            color: Colors.black,
            fontSize: 34,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 8),

        Text(
          'عرض وإدارة تقارير التشخيص الطبي التي تم إنشاؤها بواسطة الذكاء الاصطناعي',
          style: TextStyle(color: Colors.blueGrey.shade300, fontSize: 16),
        ),
      ],
    );
  }

  // =========================================================
  // SEARCH + CREATE
  // =========================================================

  Widget _buildTopSection() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 62,
            decoration: BoxDecoration(
              color: AppColors.slateGrey,
              borderRadius: BorderRadius.circular(16),
            ),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white, fontSize: 16),
              decoration: InputDecoration(
                border: InputBorder.none,
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: AppColors.cyanAccent,
                  size: 28,
                ),
                suffixIcon: _searchText.isNotEmpty
                    ? IconButton(
                        onPressed: () {
                          _searchController.clear();
                        },
                        icon: const Icon(
                          Icons.close_rounded,
                          color: AppColors.textSecondary,
                        ),
                      )
                    : null,
                hintText: 'ابحث بالرقم الوطني أو اسم ملف التقرير...',
                hintStyle: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 15,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 18,
                ),
              ),
            ),
          ),
        ),

        const SizedBox(width: 18),

        SizedBox(
          height: 62,
          child: ElevatedButton.icon(
            onPressed: _createNewReport,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.cyanAccent,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 25),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            icon: const Icon(Icons.add_rounded, size: 25),
            label: const Text(
              'تقرير جديد',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  // =========================================================
  // LIST HEADER
  // =========================================================

  Widget _buildRecordsHeader() {
    return Row(
      children: [
        const Text(
          'التقارير السابقة',
          style: TextStyle(
            color: Colors.black,
            fontSize: 23,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(width: 12),

        Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.cyanAccent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '${_filteredRecords.length}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),

        const Spacer(),

        if (_searchText.isNotEmpty)
          Text(
            'نتائج البحث عن: $_searchText',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
      ],
    );
  }

  // =========================================================
  // RECORDS
  // =========================================================

  Widget _buildRecordsList() {
    final records = _filteredRecords;

    if (records.isEmpty) {
      return _buildEmptyState();
    }

    return Column(
      children: records.map((record) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _buildRecordCard(record),
        );
      }).toList(),
    );
  }

  // =========================================================
  // RECORD CARD
  // =========================================================

  Widget _buildRecordCard(DiagnosticRecord record) {
    return Container(
      constraints: const BoxConstraints(minHeight: 185),
      decoration: BoxDecoration(
        color: AppColors.slateGrey,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.04), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // الصورة
            _buildImagePreview(record),

            const SizedBox(width: 20),

            // المعلومات
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.cyanAccent.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Diagnosis #${record.diagnosisId}',
                          style: const TextStyle(
                            color: AppColors.cyanAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 15),

                  _buildInfoRow(
                    icon: Icons.badge_outlined,
                    title: 'الرقم الوطني',
                    value: record.patientId.toString(),
                  ),

                  const SizedBox(height: 10),

                  _buildInfoRow(
                    icon: Icons.calendar_today_outlined,
                    title: 'تاريخ التشخيص',
                    value: record.date,
                  ),

                  const SizedBox(height: 10),

                  _buildInfoRow(
                    icon: Icons.picture_as_pdf_outlined,
                    title: 'ملف التقرير',
                    value: record.file,
                  ),
                ],
              ),
            ),

            const SizedBox(width: 20),

            // Actions
            _buildActions(record),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // IMAGE PREVIEW
  // =========================================================

  Widget _buildImagePreview(DiagnosticRecord record) {
    return Container(
      width: 185,
      height: 150,
      decoration: BoxDecoration(
        color: AppColors.navyDark,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppColors.cyanAccent.withOpacity(0.35)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Image.network(
          record.image,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) {
              return child;
            }

            return const Center(
              child: CircularProgressIndicator(color: AppColors.cyanAccent),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            return const Center(
              child: Icon(
                Icons.image_not_supported_outlined,
                color: AppColors.textSecondary,
                size: 42,
              ),
            );
          },
        ),
      ),
    );
  }
  // =========================================================
  // INFO ROW
  // =========================================================

  Widget _buildInfoRow({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, color: AppColors.cyanAccent, size: 20),

        const SizedBox(width: 9),

        Text(
          '$title:',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),

        const SizedBox(width: 8),

        Expanded(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  // =========================================================
  // ACTION BUTTONS
  // =========================================================

  Widget _buildActions(DiagnosticRecord record) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 155,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: () => _openPdf(record),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.cyanAccent,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.picture_as_pdf_outlined, size: 21),
            label: const Text(
              'فتح التقرير',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),

        const SizedBox(height: 10),

        SizedBox(
          width: 155,
          height: 48,
          child: OutlinedButton.icon(
            onPressed: () => _deleteRecord(record),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.red,
              side: BorderSide(color: AppColors.red.withOpacity(0.6)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.delete_outline_rounded, size: 21),
            label: const Text(
              'حذف التقرير',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  // =========================================================
  // EMPTY STATE
  // =========================================================

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      height: 330,
      decoration: BoxDecoration(
        color: AppColors.slateGrey,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 75,
            height: 75,
            decoration: BoxDecoration(
              color: AppColors.cyanAccent.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.folder_open_outlined,
              color: AppColors.cyanAccent,
              size: 38,
            ),
          ),

          const SizedBox(height: 20),

          const Text(
            'لا توجد تقارير',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            _searchText.isEmpty
                ? 'لم يتم إنشاء أي تقرير تشخيصي حتى الآن'
                : 'لم يتم العثور على تقرير مطابق لعملية البحث',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
