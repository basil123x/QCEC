import 'dart:convert';

import 'package:dio/dio.dart';

class Getimages {
  Future<List<String>> getImages(String folderId) async {
    try {
      var result = await Dio().get(
        "https://qcec.online/erp2025/aws/get_cloud.php?folder=$folderId&k=${DateTime.now().microsecondsSinceEpoch}",
      );

      var data = result.data;

      // لو البيانات String، نعمل decode
      if (data is String) {
        data = jsonDecode(data);
      }

      // نتأكد إن data['files'] موجودة وقابلة للتحويل لقائمة
      List<String> files = [];
      if (data != null && data['files'] != null) {
        files = List<String>.from(data['files']);
      }

      // الترتيب حسب الرقم في اسم الملف
      files.sort((a, b) {
        int numA = int.tryParse(a.split('/').last.split('.').first) ?? 0;
        int numB = int.tryParse(b.split('/').last.split('.').first) ?? 0;
        return numA.compareTo(numB);
      });

      return files;
    } catch (e) {
      print("Error in getImages: $e");
      return []; // لو حصل أي خطأ، نرجع قائمة فاضية بدل crash
    }
  }
}
