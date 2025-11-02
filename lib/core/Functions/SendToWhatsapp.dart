import 'package:dio/dio.dart';

class Sendtowhatsapp {
  Future sendToWhatsVideo(mobile, String? videoUrl) async {
    await Future.delayed(Duration(seconds: 10));
    final response = await Dio().post(
      'https://www.wasenderapi.com/api/send-message',
      data: {"to": "+974$mobile", "videoUrl": videoUrl},
      options: Options(
        headers: {
          "Authorization":
              "Bearer c59e7748d6bd6d086bfae052e04027a71f9eb7083594b488d90dea00b02d1260",
          "Content-Type": "application/json",
        },
      ),
    );
    await Future.delayed(Duration(seconds: 10));

    if (response.statusCode == 200) {
      print("Whatsapp Video Sent Successfully");
    }
  }

  Future sendToWhatsDocs(mobile, String? visId, String? docxText) async {
    final response = await Dio().post(
      'https://www.wasenderapi.com/api/send-message',
      data: {
        "to": "+974$mobile",
        "documentUrl":
            "https://visitsqcecs.s3.ap-south-1.amazonaws.com/visits/Whatsapp/$visId/1.pdf",
        "text": docxText,
        "fileName": "This is PDF",
      },
      options: Options(
        headers: {
          "Authorization":
              "Bearer c59e7748d6bd6d086bfae052e04027a71f9eb7083594b488d90dea00b02d1260",
          "Content-Type": "application/json",
        },
      ),
    );

    if (response.statusCode == 200) {
      print("Whatsapp Sent Successfully");
      print(response.data);
    }
  }
}
