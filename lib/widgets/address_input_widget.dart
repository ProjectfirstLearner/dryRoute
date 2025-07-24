
import 'package:flutter/material.dart';
import '../nominatim_service.dart';

class AddressInputWidget extends StatefulWidget {
  final String label;
  final TextEditingController controller;
  final Function(String) onAddressSelected;
  final Function() onSetLocationMode;
  final bool hasLocation;
  final VoidCallback? onCurrentLocation;

  const AddressInputWidget({
    super.key,
    required this.label,
    required this.controller,
    required this.onAddressSelected,
    required this.onSetLocationMode,
    required this.hasLocation,
    this.onCurrentLocation,
  });

  @override
  State<AddressInputWidget> createState() => _AddressInputWidgetState();
}

class _AddressInputWidgetState extends State<AddressInputWidget> {
  List<NominatimSuggestion> _suggestions = [];
  DateTime? _lastSuggest;
  final Duration _debounceDuration = const Duration(milliseconds: 350);
  bool _showSuggestions = false;

  void _debouncedSuggest(String value) async {
    _lastSuggest = DateTime.now();
    final captured = _lastSuggest;
    if (value.isEmpty) {
      if (mounted) setState(() {
        _suggestions = [];
        _showSuggestions = false;
      });
      return;
    }
    await Future.delayed(_debounceDuration);
    if (_lastSuggest != captured || !mounted) return;
    
    try {
      final suggestions = await NominatimService.search(value);
      if (_lastSuggest == captured && mounted) {
        setState(() {
          _suggestions = suggestions;
          _showSuggestions = suggestions.isNotEmpty;
        });
      }
    } catch (e) {
      if (mounted) setState(() {
        _suggestions = [];
        _showSuggestions = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: Theme.of(context).textTheme.labelMedium,
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: widget.hasLocation 
                  ? Theme.of(context).colorScheme.primary 
                  : Theme.of(context).colorScheme.outline.withOpacity(0.3),
            ),
          ),
          child: TextField(
            controller: widget.controller,
            decoration: InputDecoration(
              hintText: 'Adresse eingeben oder auswählen',
              hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.hasLocation)
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      child: Icon(
                        Icons.check_circle,
                        color: Theme.of(context).colorScheme.primary,
                        size: 20,
                      ),
                    ),
                  if (widget.onCurrentLocation != null)
                    IconButton(
                      icon: Icon(
                        Icons.my_location,
                        color: Theme.of(context).colorScheme.primary,
                        size: 20,
                      ),
                      onPressed: widget.onCurrentLocation,
                    ),
                  IconButton(
                    icon: Icon(
                      Icons.expand_more,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                      size: 20,
                    ),
                    onPressed: () => setState(() => _showSuggestions = !_showSuggestions),
                  ),
                ],
              ),
            ),
            onChanged: _debouncedSuggest,
            onTap: () => setState(() => _showSuggestions = true),
          ),
        ),
        
        if (_showSuggestions && _suggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ..._suggestions.take(5).map((s) => ListTile(
                  dense: true,
                  leading: Icon(
                    Icons.location_on_outlined,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
                  title: Text(
                    s.displayName,
                    style: Theme.of(context).textTheme.bodyMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () {
                    widget.onAddressSelected('${s.lat},${s.lon}');
                    widget.controller.text = s.displayName;
                    setState(() => _showSuggestions = false);
                  },
                )),
                Container(
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                      ),
                    ),
                  ),
                  child: ListTile(
                    dense: true,
                    leading: Icon(
                      Icons.touch_app,
                      color: Theme.of(context).colorScheme.primary,
                      size: 20,
                    ),
                    title: Text(
                      'Punkt auf Karte wählen',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    onTap: () {
                      widget.onSetLocationMode();
                      setState(() => _showSuggestions = false);
                    },
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
