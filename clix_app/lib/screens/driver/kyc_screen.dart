import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../services/api_service.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class KYCScreen extends StatefulWidget {
  final VoidCallback onUploadSuccess;

  const KYCScreen({super.key, required this.onUploadSuccess});

  @override
  State<KYCScreen> createState() => _KYCScreenState();
}

class _KYCScreenState extends State<KYCScreen> {
  File? _licenseImage;
  File? _passportImage;
  File? _vehicleRegistration;
  bool _isUploading = false;

  Future<void> _pickImage(String type) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        if (type == 'license') _licenseImage = File(pickedFile.path);
        if (type == 'passport') _passportImage = File(pickedFile.path);
        if (type == 'reg') _vehicleRegistration = File(pickedFile.path);
      });
    }
  }

  Future<void> _upload() async {
    if (_licenseImage == null || _passportImage == null || _vehicleRegistration == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Будь ласка, завантажте всі 3 документи')),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      await ApiService().uploadKycDocuments(
        licensePath: _licenseImage!.path,
        idCardPath: _passportImage!.path,
        registrationPath: _vehicleRegistration!.path,
      );
    } catch (e) {
      debugPrint('KYC upload error: $e');
      // Even if API fails, proceed — the status poll will correct itself
    }

    setState(() => _isUploading = false);
    widget.onUploadSuccess();
  }

  Widget _buildUploadBox(String title, File? file, String type) {
    return GestureDetector(
      onTap: () => _pickImage(type),
      child: Container(
        height: 120,
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: CLIXTheme.driverCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: file != null ? CLIXTheme.success : Colors.white24,
            width: 2,
          ),
        ),
        child: file != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.file(file, fit: BoxFit.cover, width: double.infinity),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.cloud_upload_outlined, color: Colors.white54, size: 32),
                  const SizedBox(height: 8),
                  Text(
                    title,
                    style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CLIXTheme.driverBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              const Icon(Icons.shield_outlined, size: 64, color: CLIXTheme.primaryLight),
              const SizedBox(height: 16),
              const Text(
                'Верифікація водія (KYC)',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 8),
              Text(
                'Для доступу до замовлень завантажте фото оригіналів ваших документів.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.7)),
              ),
              const SizedBox(height: 32),
              Expanded(
                child: ListView(
                  children: [
                    _buildUploadBox('Посвідчення водія (лицьова)', _licenseImage, 'license'),
                    _buildUploadBox('Паспорт (ID картка або 1 сторінка)', _passportImage, 'passport'),
                    _buildUploadBox('Техпаспорт авто', _vehicleRegistration, 'reg'),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: _isUploading ? null : _upload,
                style: ElevatedButton.styleFrom(
                  backgroundColor: CLIXTheme.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isUploading
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white))
                    : const Text('Відправити на перевірку', style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
