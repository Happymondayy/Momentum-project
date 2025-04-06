// daily_planner_page.dart
import 'package:flutter/material.dart';
import 'package:momentum_planner/Planner/task_list_screen.dart';
import 'calendar_screen.dart';
import 'progress_screen.dart';
import 'task_list_screen.dart';
import 'package:momentum_planner/Todolist/screens/todo_list_screen.dart';

class DailyPlannerPage extends StatefulWidget {
  const DailyPlannerPage({Key? key}) : super(key: key);

  @override
  State<DailyPlannerPage> createState() => _DailyPlannerPageState();
}

class _DailyPlannerPageState extends State<DailyPlannerPage> {
  bool isPlannerView = true; // true for planner, false for todo list
  TodoListScreenState? todoListScreenState; // Reference to TodoListScreen state

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            //CalendarScreen(),
            //ProgressScreen(),
            _buildHeaderWithToggle(),
            Expanded(
              child: isPlannerView
                  ? const TaskListScreen()
                  : TodoListScreen(
                isEmbedded: true,
                onStateCreated: (state) {
                  todoListScreenState = state;
                },
              ),
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
        // Show task creation UI depending on current view
        if (isPlannerView) {
          // Show simple planner task creation dialog (implementation not shown here)
          // For now, just a placeholder
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Planner task creation not implemented yet')),
          );
        } else {
          // Show the full todo task creation dialog from TodoListScreen
          if (todoListScreenState != null) {
            todoListScreenState!.showAddTaskDialog(context);
          }
        }
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
}