import 'package:dio/dio.dart';

class sendSMS {
  Future sendSms(mobile, msg, type) async {
    final response = await Dio().get(
      'https://messaging.ooredoo.qa/bms/soap/Messenger.asmx/HTTP_SendSms?customerID=7221&userName=qcec&userPassword=Qcec@8080&originator=QCEC&smsText=$msg&recipientPhone=974$mobile&messageType=Latin&defDate=&blink=false&flash=false&Private=false',
    );

    if (response.statusCode == 200) {
      print("Sms Sent Successfully");
      print(response.data);
    } else {
      print("There are Errors");
    }
  }
}
