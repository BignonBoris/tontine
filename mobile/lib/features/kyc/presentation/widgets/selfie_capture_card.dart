import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/core/theme/app_theme.dart';

class SelfieCaptureCard extends StatefulWidget {
  final File? initialImage;
  final Function(File) onImageCaptured;
  final VoidCallback? onImageRemoved;

  const SelfieCaptureCard({
    super.key,
    this.initialImage,
    required this.onImageCaptured,
    this.onImageRemoved,
  });

  @override
  State<SelfieCaptureCard> createState() => _SelfieCaptureCardState();
}

class _SelfieCaptureCardState extends State<SelfieCaptureCard> {
  final ImagePicker _picker = ImagePicker();
  File? _capturedImage;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _capturedImage = widget.initialImage;
  }

  Future<void> _takeSelfie() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        imageQuality: 80,
      );

      if (image != null) {
        final File file = File(image.path);
        setState(() {
          _capturedImage = file;
        });
        widget.onImageCaptured(file);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erreur lors de la prise du selfie", style: GoogleFonts.inter(color: Colors.white)),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _removeImage() {
    setState(() {
      _capturedImage = null;
    });
    if (widget.onImageRemoved != null) {
      widget.onImageRemoved!();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppTheme.borderColor.withOpacity(0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(
              Icons.face_retouching_natural_rounded,
              size: 48,
              color: AppTheme.primaryColor,
            ),
            const SizedBox(height: 16),
            Text(
              "Selfie de vérification",
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimaryColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "Assurez-vous que votre visage est bien visible et bien éclairé, sans lunettes de soleil ni chapeau.",
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: AppTheme.textSecondaryColor,
              ),
            ),
            const SizedBox(height: 24),
            if (_isLoading)
              const CircularProgressIndicator(color: AppTheme.primaryColor)
            else if (_capturedImage != null)
              Column(
                children: [
                  Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.primaryColor, width: 3),
                      image: DecorationImage(
                        image: FileImage(_capturedImage!),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton.icon(
                    onPressed: _removeImage,
                    icon: const Icon(Icons.refresh, color: AppTheme.errorColor),
                    label: Text(
                      "Reprendre le selfie",
                      style: GoogleFonts.inter(
                        color: AppTheme.errorColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                ],
              )
            else
              ElevatedButton.icon(
                onPressed: _takeSelfie,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  minimumSize: const Size(double.infinity, 52),
                ),
                icon: const Icon(Icons.camera_front, color: Colors.white),
                label: Text(
                  "Prendre un selfie",
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
