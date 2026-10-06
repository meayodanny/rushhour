import 'package:flutter/widgets.dart';

class AppStrings {
  const AppStrings(this.locale);
  final Locale locale;

  bool get ru => locale.languageCode == 'ru';
  String get gameTitle => 'FLOWLINE';
  String get tagline => ru ? 'ГОРОД В ДВИЖЕНИИ' : 'A CITY IN MOTION';
  String get city => ru ? 'Ривергейт' : 'Rivergate';
  String get cityCaption => ru ? 'РЕКА · 2 МОСТА · ПЛОТНЫЙ ЦЕНТР' : 'RIVER · 2 BRIDGES · DENSE CORE';
  String get play => ru ? 'Играть' : 'Play';
  String get settings => ru ? 'Настройки' : 'Settings';
  String get tutorial => ru ? 'Обучение' : 'Tutorial';
  String get selectCity => ru ? 'ВЫБЕРИТЕ ГОРОД' : 'CHOOSE A CITY';
  String get start => ru ? 'Начать' : 'Start';
  String get back => ru ? 'Назад' : 'Back';
  String get sound => ru ? 'Звук' : 'Sound';
  String get soundCaption => ru ? 'Короткие сигналы города' : 'Short signals from the city';
  String get language => ru ? 'Язык' : 'Language';
  String get fit => ru ? 'Вписать карту' : 'Fit map';
  String get difficulty => ru ? 'РЕЖИМ' : 'MODE';
  String get normal => ru ? 'Обычный' : 'Normal';
  String get realism => ru ? 'Реализм' : 'Realism';
  String get infinite => ru ? 'Бесконечный' : 'Infinite';
  String get sandbox => ru ? 'Песочница' : 'Sandbox';
  String get score => ru ? 'ДОСТАВКИ' : 'DELIVERIES';
  String get day => ru ? 'День' : 'Day';
  String get pause => ru ? 'Пауза' : 'Pause';
  String get normalSpeed => ru ? 'Обычная скорость' : 'Normal speed';
  String get fastSpeed => ru ? 'Ускорение' : 'Fast speed';
  String get gameOver => ru ? 'СЕТЬ ОСТАНОВИЛАСЬ' : 'THE NETWORK STOPPED';
  String get gameOverBody => ru ? 'Один из районов ждал слишком долго.' : 'One neighborhood waited too long.';
  String get survived => ru ? 'ВРЕМЯ В СЕТИ' : 'TIME ONLINE';
  String get menu => ru ? 'В меню' : 'Menu';
  String get restart => ru ? 'Ещё раз' : 'Again';
  String get continueAd => ru ? 'Очистить очередь' : 'Clear queue';
  String get reward => ru ? 'СЕТЬ РАСТЁТ' : 'THE NETWORK GROWS';
  String get choose => ru ? 'Выберите одно улучшение' : 'Choose one upgrade';
  String get line => ru ? 'Новая линия' : 'New line';
  String get walker => ru ? 'Пеший курьер' : 'Walker';
  String get bike => ru ? 'Велокурьер' : 'Cyclist';
  String get car => ru ? 'Автокурьер' : 'Driver';
  String get ferry => ru ? 'Паром' : 'Ferry';
  String get house => ru ? 'Дом: лимит +4' : 'Home: limit +4';
  String get quitToMenu => ru ? 'Завершить и в меню' : 'End and return to menu';
  String get attribution => '© OpenStreetMap contributors';

  static AppStrings of(BuildContext context) => Localizations.of<AppStrings>(context, AppStrings)!;
}

class AppStringsDelegate extends LocalizationsDelegate<AppStrings> {
  const AppStringsDelegate();
  @override
  bool isSupported(Locale locale) => <String>['en', 'ru'].contains(locale.languageCode);
  @override
  Future<AppStrings> load(Locale locale) async => AppStrings(locale);
  @override
  bool shouldReload(covariant LocalizationsDelegate<AppStrings> old) => false;
}
