// lib/widgets/city_picker_form_field.dart
import 'package:flutter/material.dart';
import '../core/location/city.dart';
import '../core/location/place_service.dart';

/// ===========================================================
/// 🌍 CityPickerFormField
/// ===========================================================
/// Campo de formulario con autocompletado de ciudades (Google Places)
/// Compatible con tu versión actual de PlaceService.
/// ===========================================================
class CityPickerFormField extends FormField<City?> {
  CityPickerFormField({
    super.key,
    super.initialValue,
    super.onSaved,
    super.validator,
    required void Function(City?) onChanged,
    String label = 'Ciudad y país',
  }) : super(
          builder: (state) {
            final controller =
                TextEditingController(text: state.value?.display ?? '');

            Future<void> openPicker(BuildContext context) async {
              final result = await showModalBottomSheet<_CitySuggestionResult>(
                context: context,
                backgroundColor: const Color(0xFF101010),
                isScrollControlled: true,
                builder: (_) => _CitySearchSheet(
                  initialText: controller.text,
                ),
              );

              if (result == null) return;

              final details =
                  await PlaceService.getCityDetails(result.placeId ?? '');
              if (details == null) return;

              final city = City(
                name: details.description,
                lat: details.lat,
                lng: details.lng,
                placeId: result.placeId,
              );

              controller.text = city.display;
              state.didChange(city);
              onChanged(city);
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  readOnly: true,
                  controller: controller,
                  onTap: () => openPicker(state.context),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: label,
                    labelStyle: const TextStyle(color: Colors.white70),
                    filled: true,
                    fillColor: const Color(0xFF111111),
                    enabledBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white24),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.blueAccent),
                    ),
                    suffixIcon:
                        const Icon(Icons.location_city, color: Colors.white70),
                  ),
                ),
                if (state.hasError)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      state.errorText!,
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  ),
              ],
            );
          },
        );
}

class _CitySearchSheet extends StatefulWidget {
  final String initialText;
  const _CitySearchSheet({required this.initialText});

  @override
  State<_CitySearchSheet> createState() => _CitySearchSheetState();
}

class _CitySearchSheetState extends State<_CitySearchSheet> {
  final _queryCtrl = TextEditingController();
  bool _loading = false;
  List<_SuggestionView> _suggestions = [];

  @override
  void initState() {
    super.initState();
    _queryCtrl.text = widget.initialText;
    if (widget.initialText.isNotEmpty) _fetch(widget.initialText);
  }

  Future<void> _fetch(String query) async {
    if (query.isEmpty) return;
    setState(() => _loading = true);
    final results = await PlaceService.fetchCitySuggestions(query);
    setState(() {
      _suggestions = results
          .map((e) => _SuggestionView(title: e.description, placeId: e.placeId))
          .toList();
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom, left: 16, right: 16, top: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 4,
            width: 44,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _queryCtrl,
            onChanged: _fetch,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: 'Escribe tu ciudad...',
              hintStyle: TextStyle(color: Colors.white54),
              prefixIcon: Icon(Icons.search, color: Colors.white70),
              filled: true,
              fillColor: Color(0xFF171717),
              enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white24)),
              focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.blueAccent)),
            ),
          ),
          const SizedBox(height: 12),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: CircularProgressIndicator(),
            ),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: _suggestions.length,
              separatorBuilder: (_, __) =>
                  const Divider(color: Colors.white12, height: 1),
              itemBuilder: (_, i) {
                final it = _suggestions[i];
                return ListTile(
                  onTap: () => Navigator.pop(
                      context,
                      _CitySuggestionResult(
                          placeId: it.placeId, name: it.title)),
                  title: Text(it.title,
                      style: const TextStyle(color: Colors.white)),
                  trailing:
                      const Icon(Icons.chevron_right, color: Colors.white54),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _SuggestionView {
  final String title;
  final String placeId;
  _SuggestionView({required this.title, required this.placeId});
}

class _CitySuggestionResult {
  final String? name;
  final String? placeId;
  _CitySuggestionResult({this.name, this.placeId});
}
