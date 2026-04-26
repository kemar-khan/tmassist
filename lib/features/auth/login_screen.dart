// lib/features/auth/login_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/in_memory_store.dart';
import '../../models/user.dart';
import '../../utils/enums.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  AppUser? _selectedUser;
  String? _error;
  bool _isLoading = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Set a default selected user once the store is available.
    final store = context.read<InMemoryStore>();
    if (_selectedUser == null && store.users.isNotEmpty) {
      _selectedUser = store.users.first;
    }
  }

  void _handleLogin() async {
    setState(() {
      _error = null;
      _isLoading = true;
    });

    final user = _selectedUser;
    if (user == null) {
      setState(() {
        _error = 'Please select a user.';
        _isLoading = false;
      });
      return;
    }

    // Simulate network delay to match the thematic loading feel
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    final store = context.read<InMemoryStore>();
    store.loginAs(user);

    if (!mounted) return;

    if (user.role == UserRole.admin) {
      Navigator.pushReplacementNamed(context, '/admin');
    } else if (user.role == UserRole.technician) {
      Navigator.pushReplacementNamed(context, '/tech');
    } else if (user.role == UserRole.customer) {
      Navigator.pushReplacementNamed(context, '/customer');
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<InMemoryStore>();
    final users = store.users;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Top Section: TM Blue Curve
            Container(
              height: 300,
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Color(0xFF005CAB),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(80),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.router_rounded,
                    size: 100,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "TM Assist",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  Text(
                    "AI - Assisted Ticketing System",
                    style: TextStyle(color: Colors.white.withOpacity(0.8)),
                  ),
                ],
              ),
            ),

            // Bottom Section: Input Fields
            Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Sign In",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF005CAB),
                    ),
                  ),
                  const SizedBox(height: 30),

                  // User Dropdown (Replaces ID Input)
                  DropdownButtonFormField<AppUser>(
                    initialValue: _selectedUser,
                    items: users
                        .map(
                          (u) => DropdownMenuItem(
                            value: u,
                            child: Text('${u.name} (${u.role.displayName})'),
                          ),
                        )
                        .toList(),
                    onChanged: (val) => setState(() => _selectedUser = val),
                    decoration: InputDecoration(
                      labelText: "Select User",
                      prefixIcon: const Icon(
                        Icons.badge_outlined,
                        color: Colors.orange,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Password Input (Visual Only)
                  TextField(
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: "Password",
                      prefixIcon: const Icon(
                        Icons.lock_outline,
                        color: Colors.orange,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {},
                      child: const Text(
                        "Forgot Password?",
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Error message
                  if (_error != null) ...[
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                    const SizedBox(height: 12),
                  ],

                  // Login Button
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: (_isLoading || users.isEmpty)
                          ? null
                          : _handleLogin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF6600),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              "LOG IN",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("Don't have an account?"),
                      TextButton(
                        onPressed: () =>
                            Navigator.pushNamed(context, '/register'),
                        child: const Text(
                          "Register Now",
                          style: TextStyle(
                            color: Color(0xFF005CAB),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
