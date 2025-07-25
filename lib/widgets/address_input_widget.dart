
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:latlong2/latlong.dart';

class AddressInputWidget extends StatefulWidget {
  final String label;
  final String? value;
  final Function(String, LatLng?) onChanged;
  final bool isStart;

  const AddressInputWidget({
    super.key,
    required this.label,
    this.value,
    required this.onChanged,
    this.isStart = false,
  });

  @override
  State<AddressInputWidget> createState() => _AddressInputWidgetState();
}

class _AddressInputWidgetState extends State<AddressInputWidget> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  List<String> _suggestions = [];
  bool _showSuggestions = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _controller.text = widget.value ?? '';
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (_focusNode.hasFocus) {
      _showDefaultSuggestions();
    } else {
      setState(() {
        _showSuggestions = false;
      });
    }
  }

  void _showDefaultSuggestions() {
    setState(() {
      _suggestions = [
        'Aktueller Standort',
        'Punkt auf Karte wählen',
      ];
      _showSuggestions = true;
    });
  }

  Future<void> _useCurrentLocation() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Standortberechtigung prüfen
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        _showLocationError('Standortberechtigung erforderlich');
        return;
      }

      // Aktuellen Standort abrufen
      final Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      // Reverse Geocoding für Adresse
      try {
        final List<Placemark> placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );

        if (placemarks.isNotEmpty) {
          final placemark = placemarks.first;
          final address = _formatAddress(placemark);
          
          _controller.text = address;
          widget.onChanged(address, LatLng(position.latitude, position.longitude));
        } else {
          _controller.text = 'Aktueller Standort';
          widget.onChanged('Aktueller Standort', LatLng(position.latitude, position.longitude));
        }
      } catch (e) {
        // Fallback wenn Reverse Geocoding fehlschlägt
        _controller.text = 'Aktueller Standort';
        widget.onChanged('Aktueller Standort', LatLng(position.latitude, position.longitude));
      }

      setState(() {
        _showSuggestions = false;
        _focusNode.unfocus();
      });

    } catch (e) {
      _showLocationError('Standort konnte nicht ermittelt werden: ${e.toString()}');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _formatAddress(Placemark placemark) {
    final parts = <String>[];
    
    if (placemark.street != null && placemark.street!.isNotEmpty) {
      parts.add(placemark.street!);
    }
    if (placemark.subThoroughfare != null && placemark.subThoroughfare!.isNotEmpty) {
      if (parts.isNotEmpty) {
        parts[parts.length - 1] += ' ${placemark.subThoroughfare}';
      } else {
        parts.add(placemark.subThoroughfare!);
      }
    }
    if (placemark.locality != null && placemark.locality!.isNotEmpty) {
      parts.add(placemark.locality!);
    }
    
    return parts.join(', ');
  }

  void _showLocationError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _selectMapPoint() {
    // Diese Funktion wird von der übergeordneten Komponente behandelt
    widget.onChanged('Punkt auf Karte wählen', null);
    setState(() {
      _showSuggestions = false;
      _focusNode.unfocus();
    });
  }

  Widget _buildSuggestionTile(String suggestion) {
    IconData icon;
    VoidCallback onTap;

    if (suggestion == 'Aktueller Standort') {
      icon = Icons.my_location;
      onTap = _useCurrentLocation;
    } else if (suggestion == 'Punkt auf Karte wählen') {
      icon = Icons.place;
      onTap = _selectMapPoint;
    } else {
      icon = Icons.location_on;
      onTap = () {
        _controller.text = suggestion;
        widget.onChanged(suggestion, null);
        setState(() {
          _showSuggestions = false;
          _focusNode.unfocus();
        });
      };
    }

    return ListTile(
      leading: Icon(icon, size: 20),
      title: Text(suggestion),
      dense: true,
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _controller,
          focusNode: _focusNode,
          decoration: InputDecoration(
            labelText: widget.label,
            border: const OutlineInputBorder(),
            suffixIcon: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: Padding(
                      padding: EdgeInsets.all(12.0),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _controller.clear();
                      widget.onChanged('', null);
                    },
                  ),
          ),
          onChanged: (value) {
            widget.onChanged(value, null);
            // Hier könnte eine Suche über Nominatim implementiert werden
          },
          enabled: !_isLoading,
        ),
        if (_showSuggestions)
          Container(
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: _suggestions
                  .map((suggestion) => _buildSuggestionTile(suggestion))
                  .toList(),
            ),
          ),
      ],
    );
  }
}
