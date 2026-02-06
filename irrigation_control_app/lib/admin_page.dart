import 'package:flutter/material.dart';
import 'package:irrigation_control_app/auth_service.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  final AuthService _authService = AuthService();
  List<String> _userEmails = [];
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
      final emails = await _authService.getAllUserEmails();
      setState(() {
        _userEmails = emails;
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

  Future<void> _removeUser(String email) async {
    if (email == (await _authService.getEmail())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Oturumu açık olan kullanıcıyı silemezsiniz.')),
      );
      return;
    }
    //Admin hesabı
    if (email == 'admin@sirket.com') {
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
                await _authService.removeUser(email);
                Navigator.of(context).pop();
                _loadUsers(); // Listeyi yenile
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Kullanıcı başarıyla silindi.')),
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
          : _userEmails.isEmpty
              ? const Center(child: Text('Yetkili kullanıcı bulunamadı.'))
              : ListView.builder(
                  padding: const EdgeInsets.only(top: 20),
                  itemCount: _userEmails.length,
                  itemBuilder: (context, index) {
                    final email = _userEmails[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      child: ListTile(
                        leading: const Icon(Icons.person, color: Colors.blueGrey),
                        title: Text(email, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(email == 'admin@sirket.com' ? 'Ana Yönetici' : 'Kurulum Yetkilisi'),
                        trailing: IconButton(
                          icon: Icon(Icons.delete, color: email == 'admin@sirket.com' ? Colors.grey : Colors.red),
                          onPressed: email == 'admin@sirket.com' ? null : () => _removeUser(email),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}