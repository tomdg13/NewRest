// lib/widgets/inventory_form_fields.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/simple_translations.dart';

// Fast, optimized text field widget
class FastTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final TextInputType? keyboardType;
  final bool required;
  final int maxLines;
  final String langCode;

  const FastTextField({
    Key? key,
    required this.controller,
    required this.label,
    this.keyboardType,
    this.required = false,
    this.maxLines = 1,
    required this.langCode,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      inputFormatters: keyboardType == TextInputType.number
          ? [FilteringTextInputFormatter.digitsOnly]
          : keyboardType == const TextInputType.numberWithOptions(decimal: true)
          ? [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))]
          : null,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
      ),
      validator: required
          ? (value) {
              if (value == null || value.isEmpty) {
                return SimpleTranslations.get(langCode, 'field_required');
              }
              if (keyboardType == TextInputType.number &&
                  int.tryParse(value) == null) {
                return SimpleTranslations.get(langCode, 'enter_valid_number');
              }
              if (keyboardType ==
                      const TextInputType.numberWithOptions(decimal: true) &&
                  double.tryParse(value) == null) {
                return SimpleTranslations.get(langCode, 'enter_valid_price');
              }
              return null;
            }
          : null,
    );
  }
}

// Fast dropdown widget
class FastDropdown extends StatelessWidget {
  final String value;
  final String label;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  const FastDropdown({
    Key? key,
    required this.value,
    required this.label,
    required this.items,
    required this.onChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 4),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(4),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              items: items
                  .map(
                    (item) => DropdownMenuItem(value: item, child: Text(item)),
                  )
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}