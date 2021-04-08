import 'package:flutter/material.dart';

class Language{
  final String homeScreenTitle;
  final String chatScreenTitle;

  Language({
    @required this.homeScreenTitle,
    @required this.chatScreenTitle
  });

  Locale getLocality(BuildContext context){
    return Localizations.localeOf(context);
  }

  String getSystemLanguage(BuildContext context){
    return Localizations.localeOf(context).toString();
  }

  String defaultLanguage = SupportedLanguages.en_US.toString();
}


enum SupportedLanguages{
  en_US,
  zh_CN
}