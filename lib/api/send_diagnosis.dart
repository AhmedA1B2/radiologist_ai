import 'package:flutter/material.dart';
import 'package:radiologist_ai/api/crud.dart';
import 'package:radiologist_ai/api/links.dart';

Crud _crud = Crud();

class SendDiagnosis {
  Future<bool> addDiagnosi(
    BuildContext context,
    String patientId,
    String date,
    String pdfPath,
    String imagePath,
  ) async {
    
    if (patientId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter patient ID'),
        ),
      );

      return false;
    }

    try {
      final response = await _crud.postRequestWithFiles(
        linkAiResultAdd,
        {
          "patient_id": patientId,
          "date": date,
        },
        pdfPath,
        imagePath,
      );

      if (response != null &&
          response['status'] == "success") {

        return true;

      } else {

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save diagnosis'),
          ),
        );

        return false;
      }

    } catch (e) {

      print("catch error ====> $e");

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
        ),
      );

      return false;
    }
  }
}