import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import 'login_screen.dart'; // Para volver al login tras cerrar sesión
import '../widgets/edit_book_modal.dart';
import '../services/theme_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _profile;

  @override
  void initState() {
    super.initState();
    _loadMyProfile();
  }

  Future<void> _loadMyProfile() async {
    setState(() => _isLoading = true);
    try {
      final currentUser = await AuthService().getCurrentUser();
      if (currentUser != null && currentUser['username'] != null) {
        final data = await UserService().getProfile(currentUser['username']);
        setState(() {
          _profile = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error cargando perfil: $e");
      setState(() => _isLoading = false);
    }
  }

  // Helper de colores igual a tu getStatusColor de TS
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'terminado':
        return const Color(0xFF2DD55B);
      case 'abandonado':
        return const Color(0xFFFF4961);
      case 'leyendo':
        return const Color(0xFF4995FF);
      default:
        return const Color(0xFFB3AFB6);
    }
  }

  void _onLogout() async {
    await AuthService().logout();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false, // Elimina todo el historial de navegación
      );
    }
  }

  // Reemplazo de tu ActionSheet de Temas
  void _onOpenThemeSheet() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(
                  title: Text('Selecciona un tema',
                      style: TextStyle(fontWeight: FontWeight.bold))),
              ListTile(
                  leading: const Icon(Icons.wb_sunny_outlined),
                  title: const Text('Claro (Batuvi)'),
                  onTap: () {
                    ThemeService().setTheme('light');
                    Navigator.pop(context);
                  }),
              ListTile(
                  leading: const Icon(Icons.nightlight_outlined),
                  title: const Text('Oscuro (Nativo)'),
                  onTap: () {
                    ThemeService().setTheme('dark');
                    Navigator.pop(context);
                  }),
              ListTile(
                  leading: const Icon(Icons.favorite_border),
                  title: const Text('Pink'),
                  onTap: () {
                    ThemeService().setTheme('pink');
                    Navigator.pop(context);
                  }),
              ListTile(
                  leading: const Icon(Icons.water_drop_outlined),
                  title: const Text('Light Blue'),
                  onTap: () {
                    ThemeService().setTheme('blue');
                    Navigator.pop(context);
                  }),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Biblioteca'),
        actions: [
          // Tu <ion-popover> convertido a menú nativo
          PopupMenuButton<String>(
            icon: const Icon(Icons.settings_outlined),
            onSelected: (value) {
              if (value == 'edit') print('Editar perfil');
              if (value == 'theme') _onOpenThemeSheet();
              if (value == 'logout') _onLogout();
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem(
                  value: 'edit',
                  child: ListTile(
                      leading: Icon(Icons.edit_outlined),
                      title: Text('Editar Perfil'),
                      contentPadding: EdgeInsets.zero)),
              const PopupMenuItem(
                  value: 'theme',
                  child: ListTile(
                      leading: Icon(Icons.palette_outlined),
                      title: Text('Apariencia'),
                      contentPadding: EdgeInsets.zero)),
              const PopupMenuItem(
                  value: 'logout',
                  child: ListTile(
                      leading: Icon(Icons.logout, color: Colors.red),
                      title: Text('Cerrar Sesión',
                          style: TextStyle(color: Colors.red)),
                      contentPadding: EdgeInsets.zero)),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child:
                  CircularProgressIndicator()) // Simplificado para no llenar el código de skeletons ahora
          : _profile == null
              ? const Center(child: Text('No se pudo cargar el perfil'))
              : _buildProfileContent(),
    );
  }

  Widget _buildProfileContent() {
    String avatarUrl = _profile!['avatar_url'] ??
        'https://api.dicebear.com/7.x/bottts/png?seed=${_profile!['username']}';
    if (avatarUrl.contains('/svg'))
      avatarUrl = avatarUrl.replaceAll('/svg', '/png');

    final library = _profile!['library'] as List<dynamic>? ?? [];
    final primaryColor = Theme.of(context).primaryColor;

    return RefreshIndicator(
      onRefresh: _loadMyProfile,
      color: primaryColor,
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 24),
        children: [
          // CABECERA PERFIL (Avatar con aro exterior)
          Center(
            child: Container(
              padding: const EdgeInsets.all(4), // Espacio para el aro
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border:
                    Border.all(color: primaryColor.withOpacity(0.3), width: 3),
              ),
              child: CircleAvatar(
                radius: 54,
                backgroundColor: primaryColor.withOpacity(0.1),
                backgroundImage: CachedNetworkImageProvider(avatarUrl),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            _profile!['username'] ?? '',
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 26, fontWeight: FontWeight.w800, fontFamily: 'Lora'),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40.0),
            child: Text(
              _profile!['bio'] ?? 'Sin biografía aún...',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.grey.shade600,
                  fontStyle: FontStyle.italic,
                  fontSize: 15),
            ),
          ),
          const SizedBox(height: 16),

          // Chip de perfil suave
          // Chip de perfil dinámico
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                // Si es público, usa un tinte del color del tema. Si es privado, un gris sutil.
                color: _profile!['is_profile_public'] == true
                    ? primaryColor.withOpacity(0.15)
                    : Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _profile!['is_profile_public'] == true
                        ? Icons.public_rounded
                        : Icons.lock_outline_rounded,
                    size: 16,
                    color: _profile!['is_profile_public'] == true
                        ? primaryColor
                        : Colors.grey[600],
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _profile!['is_profile_public'] == true
                        ? 'Perfil Público'
                        : 'Perfil Privado',
                    style: TextStyle(
                      color: _profile!['is_profile_public'] == true
                          ? primaryColor
                          : Colors.grey[600],
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 32),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Text('Mis Lecturas (${library.length})',
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Lora')),
          ),
          const SizedBox(height: 8),

          // LISTA DE LIBROS LITERARIA
          if (library.isEmpty)
            Padding(
              padding: const EdgeInsets.all(40.0),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.auto_stories_rounded,
                        size: 64, color: Colors.grey.withOpacity(0.3)),
                    const SizedBox(height: 16),
                    Text('Aún no has registrado lecturas.',
                        style: TextStyle(color: Colors.grey.shade500)),
                  ],
                ),
              ),
            )
          else
            ...library.map((log) => _buildBookCard(log)).toList(),
        ],
      ),
    );
  }

  // Tarjeta de libro en la biblioteca (equivalente a tu .book-card en SCSS)
  Widget _buildBookCard(Map<String, dynamic> log) {
    final primaryColor = Theme.of(context).primaryColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: () async {
        final result = await showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => EditBookModal(readingLog: log),
        );
        if (result != null &&
            (result['action'] == 'updated' || result['action'] == 'deleted')) {
          _loadMyProfile();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          border: Border(
              bottom: BorderSide(
                  color: (isDark ? Colors.white : Colors.black)
                      .withOpacity(0.05))),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Miniatura Flotante
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                      color: primaryColor.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4)),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  log['cover_image'] ??
                      log['cover_url'] ??
                      'https://via.placeholder.com/50x75',
                  width: 50,
                  height: 75,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Textos
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    log['title'] ?? '',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                        fontFamily: 'Lora',
                        height: 1.2),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(log['author'] ?? log['authors'] ?? '',
                      style:
                          TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                  const SizedBox(height: 8),

                  // Fila inferior: Estado y Estrellas
                  Row(
                    children: [
                      if (log['status'] != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: _getStatusColor(log['status'])
                                .withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            log['status'].toString().toUpperCase(),
                            style: TextStyle(
                                color: _getStatusColor(log['status']),
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5),
                          ),
                        ),
                      const Spacer(),
                      if (log['rating'] != null)
                        Row(
                          children: [
                            const Icon(Icons.star_rounded,
                                color: Color(0xFFFFD54F), size: 18),
                            const SizedBox(width: 4),
                            Text('${log['rating']}',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey.shade700)),
                          ],
                        ),
                      const SizedBox(width: 12),
                      if (log['is_log_public'] == false)
                        Icon(Icons.lock_outline_rounded,
                            size: 16, color: Colors.grey.shade400),
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
