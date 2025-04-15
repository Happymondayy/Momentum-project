import 'package:flutter/material.dart';
import 'package:momentum_planner/Planner_Todo/Planner_page.dart';
import 'package:momentum_planner/Planner_Todo/task_events.dart';
import 'package:intl/intl.dart'; // intl 패키지 추가

class TaskFormDialog extends StatefulWidget {
  final Function(Task) onSave;
  final DateTime selectedDate;

  const TaskFormDialog({
    Key? key,
    required this.onSave,
    required this.selectedDate,
  }) : super(key: key);

  @override
  _TaskFormDialogState createState() => _TaskFormDialogState();
}

class _TaskFormDialogState extends State<TaskFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _noteController = TextEditingController();
  final _locationController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  bool _hasNotification = false;
  String? _repeat;
  int _priority = 2; // Medium priority by default
  int _urgency = 2; // Medium urgency by default

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.selectedDate;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _noteController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectStartTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _startTime ?? TimeOfDay.now(),
    );

    if (picked != null) {
      setState(() {
        _startTime = picked;

        // If end time is before start time, update it
        if (_endTime != null) {
          final startMinutes = picked.hour * 60 + picked.minute;
          final endMinutes = _endTime!.hour * 60 + _endTime!.minute;

          if (endMinutes <= startMinutes) {
            _endTime = TimeOfDay(
              hour: (picked.hour + 1) % 24,
              minute: picked.minute,
            );
          }
        }
      });
    }
  }

  Future<void> _selectEndTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _endTime ?? (_startTime != null
          ? TimeOfDay(
        hour: (_startTime!.hour + 1) % 24,
        minute: _startTime!.minute,
      )
          : TimeOfDay.now()),
    );

    if (picked != null) {
      setState(() {
        _endTime = picked;
      });
    }
  }

  void _saveTask() {
    if (_formKey.currentState!.validate()) {
      final newTask = Task(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: _titleController.text,
        date: _selectedDate,
        startTime: _startTime,
        endTime: _endTime,
        note: _noteController.text.isEmpty ? null : _noteController.text,
        priority: _priority,
        urgency: _urgency,
        hasNotification: _hasNotification,
        repeat: _repeat,
        location: _locationController.text.isEmpty ? null : _locationController.text,
      );

      widget.onSave(newTask);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
        title: const Text('Add New Task'),
    content: SingleChildScrollView(
    child: Form(
    key: _formKey,
    child: Column(
    mainAxisSize: MainAxisSize.min,
    children: [
    TextFormField(
    controller: _titleController,
    decoration: const InputDecoration(
    labelText: 'Title *',
    border: OutlineInputBorder(),
    ),
    validator: (value) {
    if (value == null || value.isEmpty) {
    return 'Please enter a title';
    }
    return null;
    },
    ),
    const SizedBox(height: 16),

    // Date picker
    InkWell(
    onTap: () => _selectDate(context),
    child: InputDecorator(
    decoration: const InputDecoration(
    labelText: 'Date',
    border: OutlineInputBorder(),
    ),
    child: Text(
    DateFormat('yyyy-MM-dd').format(_selectedDate),
    ),
    ),
    ),
    const SizedBox(height: 16),

    // Time pickers
    Row(
    children: [
    Expanded(
    child: InkWell(
    onTap: () => _selectStartTime(context),
    child: InputDecorator(
    decoration: const InputDecoration(
    labelText: 'Start Time',
    border: OutlineInputBorder(),
    ),
    child: Text(
    _startTime != null
    ? '${_startTime!.format(context)}'
        : 'Select',
    ),
    ),
    ),
    ),
    const SizedBox(width: 16),
    Expanded(
    child: InkWell(
    onTap: () => _selectEndTime(context),
    child: InputDecorator(
    decoration: const InputDecoration(
    labelText: 'End Time',
    border: OutlineInputBorder(),
    ),
    child: Text(
    _endTime != null
    ? '${_endTime!.format(context)}'
        : 'Select',
    ),
    ),
    ),
    ),
    ],
    ),
    const SizedBox(height: 16),

    // Priority
    DropdownButtonFormField<int>(
    decoration: const InputDecoration(
    labelText: 'Priority *',
    border: OutlineInputBorder(),
    ),
    value: _priority,
    items: const [
    DropdownMenuItem(value: 1, child: Text('Low')),
    DropdownMenuItem(value: 2, child: Text('Medium')),
    DropdownMenuItem(value: 3, child: Text('High')),
    ],
    onChanged: (value) {
    setState(() {
    _priority = value!;
    });
    },
    validator: (value) {
    if (value == null) {
    return 'Please select a priority';
    }
    return null;
    },
    ),
    const SizedBox(height: 16),

    // Urgency
    DropdownButtonFormField<int>(
    decoration: const InputDecoration(
    labelText: 'Urgency *',
    border: OutlineInputBorder(),
    ),
    value: _urgency,
    items: const [
    DropdownMenuItem(value: 1, child: Text('Low')),
    DropdownMenuItem(value: 2, child: Text('Medium')),
    DropdownMenuItem(value: 3, child: Text('High')),
    ],
    onChanged: (value) {
    setState(() {
    _urgency = value!;
    });
    },
    validator: (value) {
    if (value == null) {
    return 'Please select urgency';
    }
    return null;
    },
    ),
    const SizedBox(height: 16),

    // Notification switch
    Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
    const Text('Enable Notification'),
    Switch(
    value: _hasNotification,
    onChanged: (value) {
    setState(() {
    _hasNotification = value;
    });
    },
    activeColor: Colors.purple,
    ),
    ],
    ),

    // Repeat option
    DropdownButtonFormField<String>(
    decoration: const InputDecoration(
    labelText: 'Repeat',
    border: OutlineInputBorder(),
    ),
    value: _repeat,
    items: const [
    DropdownMenuItem(value: null, child: Text('None')),
    DropdownMenuItem(value: 'daily', child: Text('Daily')),
    DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
    DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
    ],
    onChanged: (value) {
    setState(() {
    _repeat = value;
    });
    },
    ),
    const SizedBox(height: 16),

// Location
      TextFormField(
        controller: _locationController,
        decoration: const InputDecoration(
          labelText: 'Location',
          border: OutlineInputBorder(),
        ),
      ),
      const SizedBox(height: 16),

      // Notes
      TextFormField(
        controller: _noteController,
        decoration: const InputDecoration(
          labelText: 'Notes',
          border: OutlineInputBorder(),
        ),
        maxLines: 3,
      ),
    ],
    ),
    ),
    ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _saveTask,
          child: const Text('Save'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.purple,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}
