// filename: lib/screens/crop_disease_screen.dart

import 'dart:typed_data';
import 'dart:io' show File;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';

// --- Data Models ---
class Medicine {
  final String name;
  final String? mixingRatio;
  Medicine({required this.name, this.mixingRatio});

  factory Medicine.fromJson(Map<String, dynamic> json) {
    return Medicine(
      name: json['name'] ?? 'Unknown Medicine',
      mixingRatio: json['mixing_ratio'],
    );
  }
}

class DiseaseResult {
  final String diseaseName;
  final List<String> precautions;
  final List<String> remedies;
  final List<Medicine> medicines;
  DiseaseResult({
    required this.diseaseName,
    required this.precautions,
    required this.remedies,
    required this.medicines,
  });

  factory DiseaseResult.fromJson(Map<String, dynamic> json) {
    var medicinesList =
        (json['medicines'] as List<dynamic>?)
            ?.map((m) => Medicine.fromJson(m))
            .toList() ??
        [];
    return DiseaseResult(
      diseaseName: json['disease_name'] ?? 'Could not identify',
      precautions: List<String>.from(json['precautions'] ?? []),
      remedies: List<String>.from(json['remedies'] ?? []),
      medicines: medicinesList,
    );
  }

  bool get isHealthy => diseaseName.toLowerCase() == 'healthy';
}

// --- UI Screen ---
class CropDiseaseScreen extends StatefulWidget {
  const CropDiseaseScreen({super.key});

  @override
  State<CropDiseaseScreen> createState() => _CropDiseaseScreenState();
}

class _CropDiseaseScreenState extends State<CropDiseaseScreen> {
  File? _imageFile;
  Uint8List? _imageBytes;
  DiseaseResult? _result;
  String? _error;
  bool _loading = false;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );

    if (pickedFile != null) {
      if (kIsWeb) {
        final bytes = await pickedFile.readAsBytes();
        setState(() {
          _imageBytes = bytes;
          _imageFile = null;
          _result = null;
          _error = null;
        });
      } else {
        setState(() {
          _imageFile = File(pickedFile.path);
          _imageBytes = null;
          _result = null;
          _error = null;
        });
      }
    }
  }

  Future<void> _analyzeImage() async {
    if (_imageFile == null && _imageBytes == null) {
      setState(() => _error = "Please select an image first.");
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _result = null;
    });

    try {
      final Map<String, dynamic> response = kIsWeb
          ? await ApiService.detectDiseaseWeb(_imageBytes!)
          : await ApiService.detectDisease(_imageFile!);

      final result = DiseaseResult.fromJson(response);
      if (mounted) setState(() => _result = result);
    } catch (e) {
      if (mounted) setState(() => _error = "Analysis failed: ${e.toString()}");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _clearAll() {
    setState(() {
      _imageFile = null;
      _imageBytes = null;
      _result = null;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        title: Text(
          "🌿 AI Plant Disease Detector",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.green[800],
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                bool isWide = constraints.maxWidth > 768;
                return isWide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _buildUploaderColumn()),
                          const SizedBox(width: 24),
                          Expanded(child: _buildResultsColumn()),
                        ],
                      )
                    : Column(
                        children: [
                          _buildUploaderColumn(),
                          const SizedBox(height: 24),
                          _buildResultsColumn(),
                        ],
                      );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUploaderColumn() {
    return Column(
      children: [
        GestureDetector(
          onTap: _pickImage,
          child: Container(
            height: 300,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: _imageFile != null
                  ? Image.file(_imageFile!, fit: BoxFit.cover)
                  : _imageBytes != null
                  ? Image.memory(_imageBytes!, fit: BoxFit.cover)
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.cloud_upload_outlined,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "Click to select an image",
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.science_outlined),
                label: Text(
                  "Analyze Image",
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed:
                    (_loading || (_imageFile == null && _imageBytes == null))
                    ? null
                    : _analyzeImage,
              ),
            ),
            const SizedBox(width: 12),
            IconButton(
              icon: Icon(Icons.delete_outline, color: Colors.red.shade400),
              onPressed: _clearAll,
              tooltip: "Clear",
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildResultsColumn() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          _error!,
          style: GoogleFonts.poppins(
            color: Colors.red.shade800,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
      );
    }
    if (_result != null) return _buildResultCard(_result!);
    return Container(
      height: 300,
      alignment: Alignment.center,
      child: Text(
        "Results will be shown here",
        style: GoogleFonts.poppins(color: Colors.grey),
      ),
    );
  }

  Widget _buildResultCard(DiseaseResult result) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            result.diseaseName,
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: result.isHealthy
                  ? Colors.green.shade700
                  : Colors.orange.shade800,
            ),
          ),
          const Divider(height: 30),
          _buildInfoSection("🛡️ Precautions", result.precautions),
          if (result.remedies.isNotEmpty) ...[
            const SizedBox(height: 20),
            _buildInfoSection("🌿 Remedies", result.remedies),
          ],
          if (result.medicines.isNotEmpty) ...[
            const SizedBox(height: 20),
            _buildMedicineSection("💊 Medicines", result.medicines),
          ],
          // --- NEW BUTTONS ADDED HERE ---
          if (!result.isHealthy) ...[
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.shopping_cart_outlined, size: 18),
                    label: Text(
                      "Buy Medicine",
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                    ),
                    onPressed: () {
                      // TODO: Implement navigation to a shopping/medicine screen.
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.support_agent_outlined, size: 18),
                    label: Text(
                      "Contact Expert",
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                    ),
                    onPressed: () {
                      // TODO: Implement action to contact an expert (e.g., chat, call).
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.green.shade800,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.green.shade700),
                      ),
                      elevation: 2,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoSection(String title, List<String> items) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        ...items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 4.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.check_circle_outline, color: Colors.green, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(item, style: GoogleFonts.poppins(height: 1.5)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMedicineSection(String title, List<Medicine> medicines) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        ...medicines.map(
          (med) => Card(
            elevation: 0,
            color: Colors.blue.shade50,
            margin: const EdgeInsets.only(bottom: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            child: ListTile(
              title: Text(
                med.name,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w500,
                  color: Colors.blue.shade900,
                ),
              ),
              subtitle: med.mixingRatio != null
                  ? Text("Ratio: ${med.mixingRatio}")
                  : null,
            ),
          ),
        ),
      ],
    );
  }
}
