import 'package:flutter/material.dart';

class LanguageSwitcher extends StatefulWidget {
  final Locale currentLocale;
  final Future<void> Function(Locale) onLocaleChange;

  const LanguageSwitcher({
    super.key,
    required this.currentLocale,
    required this.onLocaleChange,
  });

  @override
  State<LanguageSwitcher> createState() => _LanguageSwitcherState();
}

class _LanguageSwitcherState extends State<LanguageSwitcher> {
  bool isSwitching = false;

  Future<void> _changeLocale(Locale locale) async {
    if (locale.languageCode == widget.currentLocale.languageCode) return;

    setState(() => isSwitching = true);
    await widget.onLocaleChange(locale);
    if (mounted) setState(() => isSwitching = false);
  }

  @override
  Widget build(BuildContext context) {
    final activeBorder = Border.all(color: Colors.white, width: 2);
    final inactiveBorder = Border.all(color: Colors.transparent, width: 2);

    return Row(
      children: [
        Tooltip(
          message: 'English',
          child: IconButton(
            onPressed: isSwitching
                ? null
                : () => _changeLocale(const Locale('en')),
            icon: Container(
              decoration: BoxDecoration(
                border: widget.currentLocale.languageCode == 'en'
                    ? activeBorder
                    : inactiveBorder,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Image.asset(
                'assets/flags/us.png',
                width: 32,
                height: 32,
                semanticLabel: 'English language',
              ),
            ),
          ),
        ),
        Tooltip(
          message: 'Lao',
          child: IconButton(
            onPressed: isSwitching
                ? null
                : () => _changeLocale(const Locale('la')),
            icon: Container(
              decoration: BoxDecoration(
                border: widget.currentLocale.languageCode == 'la'
                    ? activeBorder
                    : inactiveBorder,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Image.asset(
                'assets/flags/la.png',
                width: 32,
                height: 32,
                semanticLabel: 'Lao language',
              ),
            ),
          ),
        ),
        if (isSwitching)
          const Padding(
            padding: EdgeInsets.only(left: 8),
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
      ],
    );
  }
}
