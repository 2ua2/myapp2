import 'package:flutter/material.dart';

class GeofenceScreen extends StatefulWidget {
  final String childName;

  const GeofenceScreen({
    super.key,
    this.childName = 'name',
  });

  @override
  State<GeofenceScreen> createState() => _GeofenceScreenState();
}

class _GeofenceScreenState extends State<GeofenceScreen> {
  final List<Map<String, dynamic>> _geofences = [];
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _radiusController = TextEditingController();

  List<String> _selectedDays = [];
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 17, minute: 0);

  // Text controllers for time input
  final TextEditingController _startHourController = TextEditingController();
  final TextEditingController _startMinuteController = TextEditingController();
  final TextEditingController _endHourController = TextEditingController();
  final TextEditingController _endMinuteController = TextEditingController();

  String _startPeriod = 'AM';
  String _endPeriod = 'PM';

  final List<Map<String, String>> _weekDays = [
    {'full': 'Sunday', 'short': 'Sun'},
    {'full': 'Monday', 'short': 'Mon'},
    {'full': 'Tuesday', 'short': 'Tue'},
    {'full': 'Wednesday', 'short': 'Wed'},
    {'full': 'Thursday', 'short': 'Thu'},
    {'full': 'Friday', 'short': 'Fri'},
    {'full': 'Saturday', 'short': 'Sat'},
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    _radiusController.dispose();
    _startHourController.dispose();
    _startMinuteController.dispose();
    _endHourController.dispose();
    _endMinuteController.dispose();
    super.dispose();
  }

  String _formatTimeFromControllers(String hour, String minute, String period) {
    if (hour.isEmpty || minute.isEmpty) {
      return '--:-- --';
    }
    return '$hour:$minute $period';
  }

  String _getStartTimeDisplay() {
    return _formatTimeFromControllers(
      _startHourController.text,
      _startMinuteController.text,
      _startPeriod,
    );
  }

  String _getEndTimeDisplay() {
    return _formatTimeFromControllers(
      _endHourController.text,
      _endMinuteController.text,
      _endPeriod,
    );
  }

  String _getDisplayDays() {
    if (_selectedDays.isEmpty) {
      return 'Select days';
    }
    if (_selectedDays.length == 7) {
      return 'All week';
    }
    return _selectedDays.map((day) {
      final dayData = _weekDays.firstWhere((d) => d['full'] == day);
      return dayData['short'];
    }).join(', ');
  }

  void _showDayPickerDropdown(BuildContext context, StateSetter setModalState) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text(
                'Select Active Days',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Select All / Deselect All
                    InkWell(
                      onTap: () {
                        setDialogState(() {
                          setModalState(() {
                            if (_selectedDays.length == 7) {
                              _selectedDays.clear();
                            } else {
                              _selectedDays = _weekDays
                                  .map((d) => d['full']!)
                                  .toList();
                            }
                          });
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _selectedDays.length == 7
                                  ? Icons.check_box
                                  : Icons.check_box_outline_blank,
                              color: const Color(0xFF2196F3),
                            ),
                            const SizedBox(width: 16),
                            const Text(
                              'Select All',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF2196F3),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                    // Individual Days
                    ..._weekDays.map((day) {
                      final isSelected = _selectedDays.contains(day['full']);
                      return InkWell(
                        onTap: () {
                          setDialogState(() {
                            setModalState(() {
                              if (isSelected) {
                                _selectedDays.remove(day['full']);
                              } else {
                                _selectedDays.add(day['full']!);
                              }
                            });
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isSelected
                                    ? Icons.check_box
                                    : Icons.check_box_outline_blank,
                                color: isSelected
                                    ? const Color(0xFF2196F3)
                                    : const Color(0xFF9E9E9E),
                              ),
                              const SizedBox(width: 16),
                              Text(
                                day['full']!,
                                style: TextStyle(
                                  fontSize: 16,
                                  color: isSelected
                                      ? const Color(0xFF212121)
                                      : const Color(0xFF757575),
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Done',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2196F3),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildDaySelector(StateSetter setModalState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Active Days',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF757575),
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => _showDayPickerDropdown(context, setModalState),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFFE0E0E0),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    _getDisplayDays(),
                    style: TextStyle(
                      fontSize: 15,
                      color: _selectedDays.isEmpty
                          ? const Color(0xFF9E9E9E)
                          : const Color(0xFF212121),
                      fontWeight: _selectedDays.isEmpty
                          ? FontWeight.normal
                          : FontWeight.w600,
                    ),
                  ),
                ),
                const Icon(
                  Icons.arrow_drop_down,
                  color: Color(0xFF757575),
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimeSelector(StateSetter setModalState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Time Window',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF757575),
          ),
        ),
        const SizedBox(height: 8),

        // Start Time
        const Text(
          'Start Time',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Color(0xFF757575),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            // Start Hour
            Expanded(
              flex: 2,
              child: TextField(
                controller: _startHourController,
                keyboardType: TextInputType.number,
                maxLength: 2,
                textAlign: TextAlign.center,
                textInputAction: TextInputAction.next,
                onChanged: (value) {
                  setModalState(() {});
                },
                decoration: InputDecoration(
                  hintText: '09',
                  counterText: '',
                  filled: true,
                  fillColor: const Color(0xFFF5F5F5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                ':',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF757575),
                ),
              ),
            ),
            // Start Minute
            Expanded(
              flex: 2,
              child: TextField(
                controller: _startMinuteController,
                keyboardType: TextInputType.number,
                maxLength: 2,
                textAlign: TextAlign.center,
                textInputAction: TextInputAction.next,
                onChanged: (value) {
                  setModalState(() {});
                },
                decoration: InputDecoration(
                  hintText: '00',
                  counterText: '',
                  filled: true,
                  fillColor: const Color(0xFFF5F5F5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Start AM/PM
            Expanded(
              flex: 2,
              child: GestureDetector(
                onTap: () {
                  setModalState(() {
                    _startPeriod = _startPeriod == 'AM' ? 'PM' : 'AM';
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2196F3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _startPeriod,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),

        // End Time
        const Text(
          'End Time',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Color(0xFF757575),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            // End Hour
            Expanded(
              flex: 2,
              child: TextField(
                controller: _endHourController,
                keyboardType: TextInputType.number,
                maxLength: 2,
                textAlign: TextAlign.center,
                textInputAction: TextInputAction.next,
                onChanged: (value) {
                  setModalState(() {});
                },
                decoration: InputDecoration(
                  hintText: '05',
                  counterText: '',
                  filled: true,
                  fillColor: const Color(0xFFF5F5F5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                ':',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF757575),
                ),
              ),
            ),
            // End Minute
            Expanded(
              flex: 2,
              child: TextField(
                controller: _endMinuteController,
                keyboardType: TextInputType.number,
                maxLength: 2,
                textAlign: TextAlign.center,
                textInputAction: TextInputAction.done,
                onChanged: (value) {
                  setModalState(() {});
                },
                decoration: InputDecoration(
                  hintText: '00',
                  counterText: '',
                  filled: true,
                  fillColor: const Color(0xFFF5F5F5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // End AM/PM
            Expanded(
              flex: 2,
              child: GestureDetector(
                onTap: () {
                  setModalState(() {
                    _endPeriod = _endPeriod == 'AM' ? 'PM' : 'AM';
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2196F3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _endPeriod,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 8),
        Row(
          children: [
            Icon(
              Icons.info_outline,
              size: 16,
              color: Colors.grey[500],
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Safe zone will only be active during this time',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showAddGeofenceDialog() {
    // Clear previous data
    _nameController.clear();
    _locationController.clear();
    _radiusController.clear();
    _startHourController.clear();
    _startMinuteController.clear();
    _endHourController.clear();
    _endMinuteController.clear();

    setState(() {
      _selectedDays.clear();
      _startPeriod = 'AM';
      _endPeriod = 'PM';
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: DraggableScrollableSheet(
                initialChildSize: 0.85,
                minChildSize: 0.5,
                maxChildSize: 0.95,
                builder: (context, scrollController) {
                  return Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(24),
                        topRight: Radius.circular(24),
                      ),
                    ),
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.all(20),
                      children: [
                        Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: const Color(0xFFBDBDBD),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Add New Safe Zone',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF212121),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Name
                        const Text(
                          'Name',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF757575),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _nameController,
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            hintText: 'e.g., Home, School',
                            filled: true,
                            fillColor: const Color(0xFFF5F5F5),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Location
                        const Text(
                          'Location',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF757575),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Opacity(
                          opacity: 0.5,
                          child: IgnorePointer(
                            child: TextField(
                              controller: _locationController,
                              decoration: InputDecoration(
                                hintText: 'select location',
                                hintStyle: const TextStyle(
                                  color: Color(0xFF9E9E9E),
                                ),
                                filled: true,
                                fillColor: const Color(0xFFE0E0E0),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                                suffixIcon: Container(
                                  margin: const EdgeInsets.all(8),
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.withValues(alpha:0.3),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.map,
                                    color: Colors.grey,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 8),

                        // Helper text
                        Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 16,
                              color: Colors.grey[500],
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Map selection will be available soon',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // Radius
                        const Text(
                          'Radius (meters)',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF757575),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _radiusController,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.done,
                          decoration: InputDecoration(
                            hintText: 'e.g., 100',
                            filled: true,
                            fillColor: const Color(0xFFF5F5F5),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        _buildDaySelector(setModalState),

                        const SizedBox(height: 20),

                        _buildTimeSelector(setModalState),

                        const SizedBox(height: 32),

                        // Save Button
                        ElevatedButton(
                          onPressed: () {
                            if (_nameController.text.isEmpty ||
                                _radiusController.text.isEmpty) {
                              ScaffoldMessenger.of(dialogContext).showSnackBar(
                                const SnackBar(
                                  content: Text('Please fill Name and Radius fields'),
                                  backgroundColor: Color(0xFFF44336),
                                ),
                              );
                              return;
                            }

                            if (_selectedDays.isEmpty) {
                              ScaffoldMessenger.of(dialogContext).showSnackBar(
                                const SnackBar(
                                  content: Text('Please select at least one day'),
                                  backgroundColor: Color(0xFFF44336),
                                ),
                              );
                              return;
                            }

                            // Validate time fields
                            if (_startHourController.text.isEmpty ||
                                _startMinuteController.text.isEmpty ||
                                _endHourController.text.isEmpty ||
                                _endMinuteController.text.isEmpty) {
                              ScaffoldMessenger.of(dialogContext).showSnackBar(
                                const SnackBar(
                                  content: Text('Please enter complete time'),
                                  backgroundColor: Color(0xFFF44336),
                                ),
                              );
                              return;
                            }

                            // Pad single digit inputs
                            if (_startHourController.text.length == 1) {
                              _startHourController.text = _startHourController.text.padLeft(2, '0');
                            }
                            if (_startMinuteController.text.length == 1) {
                              _startMinuteController.text = _startMinuteController.text.padLeft(2, '0');
                            }
                            if (_endHourController.text.length == 1) {
                              _endHourController.text = _endHourController.text.padLeft(2, '0');
                            }
                            if (_endMinuteController.text.length == 1) {
                              _endMinuteController.text = _endMinuteController.text.padLeft(2, '0');
                            }

                            // Validate hour range (01-12)
                            final startHour = int.tryParse(_startHourController.text) ?? 0;
                            final endHour = int.tryParse(_endHourController.text) ?? 0;
                            if (startHour < 1 || startHour > 12 || endHour < 1 || endHour > 12) {
                              ScaffoldMessenger.of(dialogContext).showSnackBar(
                                const SnackBar(
                                  content: Text('Hours must be between 01 and 12'),
                                  backgroundColor: Color(0xFFF44336),
                                ),
                              );
                              return;
                            }

                            // Validate minute range (00-59)
                            final startMinute = int.tryParse(_startMinuteController.text) ?? -1;
                            final endMinute = int.tryParse(_endMinuteController.text) ?? -1;
                            if (startMinute < 0 || startMinute > 59 || endMinute < 0 || endMinute > 59) {
                              ScaffoldMessenger.of(dialogContext).showSnackBar(
                                const SnackBar(
                                  content: Text('Minutes must be between 00 and 59'),
                                  backgroundColor: Color(0xFFF44336),
                                ),
                              );
                              return;
                            }

                            setState(() {
                              print('Adding geofence: Name=${_nameController.text}, Days=${_selectedDays.length}');
                              _geofences.add({
                                'name': _nameController.text,
                                'location': _locationController.text.isEmpty
                                    ? 'Location not set'
                                    : _locationController.text,
                                'radius': '${_radiusController.text}m',
                                'isActive': true,
                                'days': List<String>.from(_selectedDays),
                                'startTime': _getStartTimeDisplay(),
                                'endTime': _getEndTimeDisplay(),
                              });
                              print('Geofences count: ${_geofences.length}');
                            });

                            Navigator.pop(dialogContext);

                            // Show success message after a small delay to ensure context is valid
                            Future.delayed(const Duration(milliseconds: 100), () {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Safe zone added successfully'),
                                    backgroundColor: Color(0xFF4CAF50),
                                  ),
                                );
                              }
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2196F3),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Save Safe Zone',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Cancel Button
                        TextButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(
                              color: Color(0xFF757575),
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF212121)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Geofence Settings',
          style: TextStyle(
            color: Color(0xFF212121),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Child Info Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF2196F3).withValues(alpha:0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF2196F3),
                width: 2,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: const BoxDecoration(
                    color: Color(0xFF2196F3),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.child_care,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.childName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF212121),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_geofences.where((g) => g['isActive']).length} active safe zones',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _geofences.any((g) => g['isActive'])
                        ? const Color(0xFF4CAF50)
                        : Colors.grey,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _geofences.any((g) => g['isActive']) ? 'Protected' : 'No Protection',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Safe Zones List
          ..._geofences.asMap().entries.map((entry) {
            final index = entry.key;
            final geofence = entry.value;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: geofence['isActive']
                      ? const Color(0xFF4CAF50)
                      : const Color(0xFFE0E0E0),
                  width: 2,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: const Color(0xFF2196F3).withValues(alpha:0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.location_on,
                          color: Color(0xFF2196F3),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              geofence['name'],
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF212121),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: geofence['isActive']
                                        ? const Color(0xFF4CAF50)
                                        : Colors.grey,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  geofence['isActive'] ? 'Active' : 'Inactive',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: geofence['isActive']
                                        ? const Color(0xFF4CAF50)
                                        : Colors.grey,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: geofence['isActive'],
                        onChanged: (value) {
                          setState(() {
                            _geofences[index]['isActive'] = value;
                          });
                        },
                          activeThumbColor: const Color(0xFF4CAF50),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.place, size: 16, color: Color(0xFF757575)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          geofence['location'],
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF757575),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.radio_button_unchecked, size: 16, color: Color(0xFF757575)),
                      const SizedBox(width: 8),
                      Text(
                        'Radius: ${geofence['radius']}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF757575),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 16, color: Color(0xFF757575)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          geofence['days'].length == 7
                              ? 'All week'
                              : geofence['days']
                              .map((day) => _weekDays
                              .firstWhere((d) => d['full'] == day)['short'])
                              .join(', '),
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF757575),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.access_time, size: 16, color: Color(0xFF757575)),
                      const SizedBox(width: 8),
                      Text(
                        '${geofence['startTime']} - ${geofence['endTime']}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF757575),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }).toList(),

          // Add Safe Zone Button
          GestureDetector(
            onTap: _showAddGeofenceDialog,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF2196F3),
                  width: 2,
                  style: BorderStyle.solid,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2196F3).withValues(alpha:0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.add,
                      color: Color(0xFF2196F3),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Add Safe Zone',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2196F3),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }
}