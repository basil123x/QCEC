import 'dart:io';
import 'package:QCEC/core/Functions/GetImages.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:http_parser/http_parser.dart';

class Makepdf {
  Future<void> createPdfFromNetwork(
    String fileName,
    String folderName,
    BuildContext context,
    void Function(void Function())? setState,
  ) async {
    print(folderName);

    // ⬅️ اعمل Document مرة واحدة
    final pdf = pw.Document();

    List myImages = await Getimages().getImages(folderName);

    for (var url in myImages) {
      final response = await Dio().get<List<int>>(
        url,
        options: Options(responseType: ResponseType.bytes),
      );

      if (response.statusCode == 200) {
        final image = pw.MemoryImage(Uint8List.fromList(response.data!));
        pdf.addPage(
          pw.Page(
            build: (pw.Context context) {
              return pw.Center(child: pw.Image(image));
            },
          ),
        );
      }
    }

    // ⬅️ خزن الملف
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$fileName.pdf');
    await file.writeAsBytes(await pdf.save());

    // ⬅️ ارفع الملف
    await uploadSingleFilePDF(file.path, folderName);
  }

  Future<void> uploadSingleFilePDF(String filePath, String visitId) async {
    final dio = Dio();
    final file = File(filePath);
    String ext = file.path.split('.').last.toLowerCase();
    final fileName = '1.$ext';

    final formData = FormData.fromMap({
      'folder': "Whatsapp/$visitId",
      'pdf': await MultipartFile.fromFile(
        file.path,
        filename: fileName,
        contentType: MediaType('application', 'pdf'),
      ),
    });

    //besso
    final response = await dio.post(
      'http://qcec-qatar.com/erp2025/aws/cloud_pdf.php?k=${DateTime.now().millisecondsSinceEpoch}',
      data: formData,
      options: Options(headers: {"Content-Type": "multipart/form-data"}),
      onSendProgress: (sent, total) {
        final progress = total != 0 ? sent / total : 0.0;
        print(
          "📤 Uploading $fileName: ${(progress * 100).toStringAsFixed(1)}%",
        );
      },
    );
  }
}
