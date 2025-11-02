import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';
import 'app_localizations_ur.dart';
import 'app_localizations_fa.dart';
import 'app_localizations_bn.dart';
import 'app_localizations_hi.dart';

/// Callers can lookup localized strings with Lookup.of(context).
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
    Locale('ur'),
    Locale('fa'),
    Locale('bn'),
    Locale('hi'),
  ];

  // Common
  String get appName;
  String get qcecFullName;
  String get home;
  String get projects;
  String get visits;
  String get monthlyVisits;
  String get todayVisits;
  String get camera;
  String get profile;
  String get settings;
  String get logout;
  String get login;
  String get password;
  String get username;
  String get loading;
  String get error;
  String get success;
  String get cancel;
  String get ok;
  String get retry;
  String get search;
  String get refresh;
  String get save;
  String get delete;
  String get edit;
  String get add;
  String get update;
  String get confirm;
  String get yes;
  String get no;

  // Dashboard
  String get welcome;
  String get quickActions;
  String get statistics;
  String get engineersStats;

  // Projects
  String get noProjects;
  String get searchProjects;
  String get projectsRefreshed;
  String get projectsRefreshFailed;
  String get activeProject;
  String get selectProject;
  String get projectDetails;
  String get customerName;
  String get customerPhone;
  String get contractorName;
  String get contractorPhone;
  String get engineerName;
  String get location;
  String get projectCode;

  // Visits
  String get noVisits;
  String get searchVisits;
  String get visitsRefreshed;
  String get visitsRefreshFailed;
  String get newVisit;
  String get visitDetails;
  String get visitDate;
  String get visitTime;
  String get visitNotes;
  String get visitPhotos;
  String get visitVideos;
  String get mediaCount;
  String get photosCount;
  String get videosCount;

  // Camera
  String get takePhoto;
  String get recordVideo;
  String get gallery;
  String get cameraPermission;
  String get storagePermission;

  // Profile & Settings
  String get userProfile;
  String get changeLanguage;
  String get darkMode;
  String get lightMode;
  String get aboutCompany;
  String get contactUs;
  String get deleteAccount;
  String get logoutConfirm;
  String get logoutMessage;
  String get languageChanged;
  String get themeChanged;

  // Languages
  String get arabic;
  String get english;
  String get urdu;
  String get persian;
  String get bengali;
  String get hindi;

  // Messages
  String get noInternetConnection;
  String get serverError;
  String get invalidCredentials;
  String get loginSuccess;
  String get loginFailed;
  String get logoutSuccess;
  String get dataLoaded;
  String get dataLoadFailed;
  String get photoSaved;
  String get videoSaved;
  String get mediaSaved;
  String get uploadSuccess;
  String get uploadFailed;
  String get reportSent;
  String get reportFailed;

  // Validation
  String get fieldRequired;
  String get invalidEmail;
  String get invalidPhone;
  String get passwordTooShort;
  String get passwordsNotMatch;

  // Date & Time
  String get today;
  String get yesterday;
  String get tomorrow;
  String get thisWeek;
  String get thisMonth;
  String get selectDate;
  String get selectTime;

  // Status
  String get pending;
  String get inProgress;
  String get completed;
  String get cancelled;
  String get approved;
  String get rejected;

  // Company Info
  String get companyName;
  String get companyDescription;
  String get companyAddress;
  String get companyPhone;
  String get companyEmail;
  String get companyWebsite;

  // Additional UI Elements
  String get enableDarkMode;
  String get enableLightMode;
  String get underDevelopment;
  String get openVisits;
  String get tuesday;
  String get lastVisit;
  String get notes;
  String get observations;
  String get position;
  String get consultant;
  String get projectType;
  String get projectLocation;
  String get surveyNumber;
  String get startDate;
  String get visitCount;
  String get allData;

  // New additions
  String get engineer;
  String get userType;
  String get welcomeToApp;
  String get qatarConsultingCenter;
  String get viewAllProjects;
  String get scheduleVisits;
  String get recordNewVisit;
  String get allStatistics;
  String get allProjects;
  String get allVisits;
  String get contractor;
  String get contractorNumber;
  String get projectNumber;
  String get description;
  String get visitNumber;
  String get lastVisitDate;
  String get status;
  String get hello;
  String get helloContent;
  String get pleaseEnterPhoneNumber;
  String get pleaseEnterPassword;
  String get writeYourPassword;
  String get phoneNumber;
  String get phoneNumberMustBe8Digits;
  String get noInternetTitle;
  String get noInternetMessage;
  String get checkConnection;
  String get connectionTips;
  String get turnOnWifi;
  String get checkNetworkSettings;
  String get restartRouter;
  String get stillNoConnection;
  String get aboutUs;
  String get sinceYear;
  String get aboutUsTitle;
  String get aboutUsContent;
  String get inTheBeginning;
  String get ourMissionContent;
  String get ourServices;
  String get buildingDesign;
  String get executionSupervision;
  String get technicalSolutions;
  String get qualityAndInnovation;
  String get deleteAccountTitle;
  String get deleteAccountPermanently;
  String get deleteAccountConfirmation;
  String get deleteAccountWarning;
  String get translating;
  String get translated;
  String get translatingNotes;
  String get contactUsTitle;
  String get weAreHereToServe;
  String get contactUsAnytime;
  String get phone;
  String get callUsDirect;
  String get email;
  String get emailUs;
  String get address;
  String get ourLocation;
  String get workingHours;
  String get officialHours;
  String get followUsOn;
  String get whatsapp;
  String get instagram;
  String get website;
  String get selectPhoneNumber;
  String get saturdayToThursday;
  String get morningShift;
  String get eveningShift;
  String get inquiryFromApp;
  String get noVisitsOnThisDate;
  String get learnAboutQCEC;
  String get contactMethods;
  String get contactInfo;
  String get disableAccountConfirmationMessage;
  String get warning;
  String get disableAccount;
  String get confirmDisable;
  String get typeDisableMyAccount;
  String get disableMyAccount;
  String get permanentDisable;
  String get disableNotConfirmed;
  String get disablingAccount;
  String get pleaseWaitDisablingAccount;
  String get accountDisabledSuccessfully;
  String get accountDisabledMessage;
  String get importantNotification;
  String get updatePrompt;
  String get updateNow;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
    'ar',
    'en',
    'ur',
    'fa',
    'bn',
    'hi',
  ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
    case 'ur':
      return AppLocalizationsUr();
    case 'fa':
      return AppLocalizationsFa();
    case 'bn':
      return AppLocalizationsBn();
    case 'hi':
      return AppLocalizationsHi();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue on GitHub with a '
    'reproducible sample app and the gen-l10n configuration that was used.',
  );
}
