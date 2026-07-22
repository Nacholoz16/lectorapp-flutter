import 'package:flutter/material.dart';
import 'package:test_lectorapp/services/reading_service.dart';
// import '../services/book_service.dart'; // Descomentar cuando conectes la API
import '../widgets/user_card.dart';
import 'package:test_lectorapp/screens/book_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool isLoading = true;
  List<dynamic> feed = [];

  @override
  void initState() {
    super.initState();
    loadFeed();
  }

  // Reemplazo de tu loadFeed() de Angular
  Future<void> loadFeed() async {
    setState(() => isLoading = true);
    try {
      // LLAMADA REAL A TU API
      final data = await ReadingService().getGlobalFeed();
      setState(() {
        feed = data;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      print("Error cargando feed: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('LectorApp',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none),
            onPressed: () {},
          ),
        ],
      ),
      // Equivalente a <ion-content> + <ion-refresher>
      body: RefreshIndicator(
        onRefresh: loadFeed,
        child: isLoading
            ? _buildSkeleton()
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: feed.length,
                itemBuilder: (context, index) {
                  // Aquí irá tu app-user-card cuando lo migremos.
                  // Por ahora mostramos una tarjeta genérica.
                  return UserCard(
                    item: feed[index],
                    mode: 'feed',
                    onBookClick: () {
                      // ¡Aquí hacemos la navegación real!
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              BookDetailScreen(book: feed[index]),
                        ),
                      );
                    },
                  );
                },
              ),
      ),
    );
  }

  // Equivalente a tu <ion-skeleton-text>
  Widget _buildSkeleton() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 3,
      itemBuilder: (context, index) => Container(
        margin: const EdgeInsets.only(bottom: 20),
        height: 150,
        decoration: BoxDecoration(
          color: Theme.of(context).primaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
            child: CircularProgressIndicator(
                color: Theme.of(context).primaryColor)),
      ),
    );
  }
}
