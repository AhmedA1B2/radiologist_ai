import 'dart:convert';
import 'package:http/http.dart' as http;

class Crud {

  // GET
  Future<dynamic> getRequest(String url) async {
    try {
      var response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        print("Error ===> ${response.statusCode} <===");
      }
    } catch (e) {
      print("Error(catch) ===> $e <===");
    }
  }

  // POST
  Future<dynamic> postRequest(
    String url,
    Map<String, String> data,
  ) async {
    try {
      var response = await http.post(
        Uri.parse(url),
        body: data,
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        print("Error ===> ${response.statusCode} <===");
      }
    } catch (e) {
      print("Error(catch) ===> $e <===");
    }
  }

  // MULTIPART
  Future<dynamic> postRequestWithFiles(
  String url,
  Map<String, String> data,
  String pdfPath,
  String imagePath,
) async {
  try {
    var request = http.MultipartRequest(
      'POST',
      Uri.parse(url),
    );

    // البيانات النصية
    request.fields.addAll(data);

    // PDF
    request.files.add(
      await http.MultipartFile.fromPath(
        'file',
        pdfPath,
      ),
    );

    // صورة الأشعة
    request.files.add(
      await http.MultipartFile.fromPath(
        'img',
        imagePath,
      ),
    );

    var streamedResponse = await request.send();

    var response = await http.Response.fromStream(
      streamedResponse,
    );

    print("Status Code: ${response.statusCode}");
    print("Response: ${response.body}");

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }

    return null;

  } catch (e) {
    print("Multipart Error ===> $e");
    return null;
  }
}

}