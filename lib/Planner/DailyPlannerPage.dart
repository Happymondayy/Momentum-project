// daily_planner_page.dart
import 'package:flutter/material.dart';
import 'package:momentum_planner/Planner/task_list_screen.dart';
import 'calendar_screen.dart';
import 'progress_screen.dart';
import 'task_list_screen.dart';
import 'package:momentum_planner/Todolist/todo_list_screen.dart';

class DailyPlannerPage extends StatefulWidget {
  const DailyPlannerPage({Key? key}) : super(key: key);

  @override
  State<DailyPlannerPage> createState() => _DailyPlannerPageState();
}

class _DailyPlannerPageState extends State<DailyPlannerPage> {
  bool isPlannerView = true; // true for planner, false for todo list

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            CalendarScreen(),
            ProgressScreen(),
            _buildHeaderWithToggle(),
            Expanded(
              child: isPlannerView
                  ? const TaskListScreen()
                  : const TodoListScreen(),
            ),
          ],
        ),
      ),
      floatingActionButton: _buildFloatingActionButton(),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildHeaderWithToggle() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            isPlannerView ? 'My Today Tasks' : 'My Todo List',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          Switch(
            value: isPlannerView,
            onChanged: (value) {
              setState(() => isPlannerView = value);
            },
            activeTrackColor: const Color(0xFFD7D0FF),
            activeColor: const Color(0xFF9D8CFF),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingActionButton() {
    return FloatingActionButton(
      onPressed: () {
        // Show dialog to add new task/todo depending on current view
        _showAddItemDialog(context);
      },
      backgroundColor: const Color(0xFF9D8CFF),
      child: const Icon(Icons.add, color: Colors.white, size: 30),
    );
  }

  Widget _buildBottomNavigationBar() {
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      selectedItemColor: const Color(0xFF9D8CFF),
      unselectedItemColor: Colors.grey.shade400,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.calendar_month), label: ''),
        BottomNavigationBarItem(icon: Icon(Icons.view_list), label: ''),
        BottomNavigationBarItem(icon: Icon(Icons.article_outlined), label: ''),
        BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), label: ''),
      ],
    );
  }

  Future<void> _showAddItemDialog(BuildContext context) async {
    final TextEditingController titleController = TextEditingController();
    final TextEditingController descriptionController = TextEditingController();

    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(isPlannerView ? 'Add New Task' : 'Add New Todo'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  hintText: 'Title',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  hintText: 'Description',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                // Add task/todo logic here
                Navigator.pop(context);
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }
}