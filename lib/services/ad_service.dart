import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdService extends ChangeNotifier {
  BannerAd? banner;
  InterstitialAd? _interstitial;
  RewardedAd? _rewarded;
  int _completedGames = 0;

  String get _bannerId => Platform.isAndroid ? 'ca-app-pub-3940256099942544/6300978111' : 'ca-app-pub-3940256099942544/2934735716';
  String get _interstitialId => Platform.isAndroid ? 'ca-app-pub-3940256099942544/1033173712' : 'ca-app-pub-3940256099942544/4411468910';
  String get _rewardedId => Platform.isAndroid ? 'ca-app-pub-3940256099942544/5224354917' : 'ca-app-pub-3940256099942544/1712485313';

  Future<void> initialize() async {
    await MobileAds.instance.initialize();
    late final BannerAd candidate;
    candidate = BannerAd(
      size: AdSize.banner,
      adUnitId: _bannerId,
      listener: BannerAdListener(
        onAdLoaded: (Ad ad) { banner = candidate; notifyListeners(); },
        onAdFailedToLoad: (Ad ad, LoadAdError _) { ad.dispose(); },
      ),
      request: const AdRequest(),
    )..load();
    _loadInterstitial();
    _loadRewarded();
  }

  void _loadInterstitial() => InterstitialAd.load(
    adUnitId: _interstitialId,
    request: const AdRequest(),
    adLoadCallback: InterstitialAdLoadCallback(
      onAdLoaded: (InterstitialAd ad) => _interstitial = ad,
      onAdFailedToLoad: (LoadAdError _) => _interstitial = null,
    ),
  );

  void _loadRewarded() => RewardedAd.load(
    adUnitId: _rewardedId,
    request: const AdRequest(),
    rewardedAdLoadCallback: RewardedAdLoadCallback(
      onAdLoaded: (RewardedAd ad) { _rewarded = ad; notifyListeners(); },
      onAdFailedToLoad: (LoadAdError _) => _rewarded = null,
    ),
  );

  void onGameFinished() {
    _completedGames++;
    if (_completedGames < 3 || (_completedGames - 3) % 4 != 0 || _interstitial == null) return;
    final ad = _interstitial!;
    _interstitial = null;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (InterstitialAd value) { value.dispose(); _loadInterstitial(); },
      onAdFailedToShowFullScreenContent: (InterstitialAd value, AdError _) { value.dispose(); _loadInterstitial(); },
    );
    ad.show();
  }

  bool get rewardedReady => _rewarded != null;

  void showRewarded(void Function() onEarned) {
    final ad = _rewarded;
    if (ad == null) return;
    _rewarded = null;
    notifyListeners();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (RewardedAd value) { value.dispose(); _loadRewarded(); },
      onAdFailedToShowFullScreenContent: (RewardedAd value, AdError _) { value.dispose(); _loadRewarded(); },
    );
    ad.show(onUserEarnedReward: (AdWithoutView _, RewardItem __) => onEarned());
  }

  @override
  void dispose() {
    banner?.dispose();
    _interstitial?.dispose();
    _rewarded?.dispose();
    super.dispose();
  }
}
