import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_localizations.dart';
import '../../features/shop_setup/providers/shop_provider.dart';

final localizationProvider = StateNotifierProvider<LocalizationNotifier, AppLocalizations?>((ref) {
  final language = ref.watch(shopProvider.select((s) => s.shop?.language ?? 'en'));
  return LocalizationNotifier(language);
});

class LocalizationNotifier extends StateNotifier<AppLocalizations?> {
  final String languageCode;

  LocalizationNotifier(this.languageCode) : super(null) {
    _load();
  }

  Future<void> _load() async {
    final localizations = AppLocalizations(languageCode);
    await localizations.load();
    if (mounted) {
      state = localizations;
    }
  }
}
