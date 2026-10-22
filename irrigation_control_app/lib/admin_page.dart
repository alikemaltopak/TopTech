import 'package:flutter/material.dart';
import 'package:irrigation_control_app/auth_service.dart';

class AdminPage extends StatefulWidget {
  final AuthService? authService;

  const AdminPage({super.key, this.authService});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  late final AuthService _authService = widget.authService ?? AuthService();
  List<AuthorizedUser> _users = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final users = await _authService.getAllUsers();
      setState(() {
        _users = users;
      });
    } catch (e) {
      // Hata yönetimi
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kullanıcılar yüklenirken hata oluştu: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _addUser() async {
    final TextEditingController emailController = TextEditingController();
    final TextEditingController passwordController = TextEditingController();

    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Yeni Kullanıcı Ekle'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'E-posta'),
              ),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Şifre'),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('İptal'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              child: const Text('Ekle'),
              onPressed: () async {
                try {
                  await _authService.addUser(emailController.text, passwordController.text);
                  Navigator.of(context).pop();
                  _loadUsers(); // Listeyi yenile
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Kullanıcı başarıyla eklendi.')),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _removeUser(AuthorizedUser user) async {
    final email = user.email;
    if (email == (await _authService.getEmail())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Oturumu açık olan kullanıcıyı silemezsiniz.')),
      );
      return;
    }
    // Yönetici hesapları buradan kaldırılamaz
    if (user.isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ana yönetici hesabı silinemez.')),
      );
      return;
    }

    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Kullanıcıyı Sil'),
          content: Text('$email kullanıcısını silmek istediğinizden emin misiniz?'),
          actions: <Widget>[
            TextButton(
              child: const Text('İptal'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Sil'),
              onPressed: () async {
                Navigator.of(context).pop();
                try {
                  await _authService.removeUser(email);
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
                  );
                  return;
                }
                _loadUsers(); // Listeyi yenile
                if (!mounted) return;
                ScaffoldMessenger.of(this.context).showSnackBar(
                  const SnackBar(content: Text('Kullanıcıya erişim kaldırıldı.')),
                );
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: _addUser,
        backgroundColor: Colors.green,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _users.isEmpty
              ? const Center(child: Text('Yetkili kullanıcı bulunamadı.'))
              : ListView.builder(
                  padding: const EdgeInsets.only(top: 20),
                  itemCount: _users.length,
                  itemBuilder: (context, index) {
                    final user = _users[index];
                    final email = user.email;
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      child: ListTile(
                        leading: const Icon(Icons.person, color: Colors.blueGrey),
                        title: Text(email, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(user.isAdmin ? 'Yönetici' : 'Kurulum Yetkilisi'),
                        trailing: IconButton(
                          icon: Icon(Icons.delete, color: user.isAdmin ? Colors.grey : Colors.red),
                          onPressed: user.isAdmin ? null : () => _removeUser(user),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}