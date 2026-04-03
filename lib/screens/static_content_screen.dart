import 'package:flutter/material.dart';
import 'package:sharecart/theme/app_theme.dart';

/// Screen that shows a title and static body text (e.g. Privacy Policy, Terms, FAQ).
class StaticContentScreen extends StatelessWidget {
  const StaticContentScreen({
    super.key,
    required this.title,
    required this.body,
  });

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: AppColors.onSurface,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Text(
          body,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.onSurface,
                height: 1.5,
              ),
        ),
      ),
    );
  }
}

/// Static content for in-app pages (no API).
class StaticContent {
  StaticContent._();

  static const String privacyPolicy = '''
Privacy Policy

Last updated: 2025

1. Information we collect
We collect the information you provide when you register (name, email) and when you use the app (lists, items, shared data).

2. How we use it
We use your data to run the app: sync lists, show shared carts, send notifications you allow, and improve our service.

3. Sharing
We do not sell your data. List content is shared only with people you invite or join via code.

4. Security
We use secure connections and store data responsibly. You can delete your account and data from the app or by contacting us.

5. Contact
For privacy questions, contact us at the email provided in the app or on our website.
''';

  static const String termsAndConditions = '''
Terms and Conditions

Last updated: 2025

1. Use of the app
By using Share Cart you agree to these terms. Use the app only for lawful purposes and do not misuse or harm the service or other users.

2. Account
You are responsible for keeping your account secure and for all activity under your account. Do not share your login with others.

3. Content
You own your lists and content. You give us permission to store and sync them to provide the service. Do not add content that is illegal, harmful, or infringes others’ rights.

4. Service
We aim to keep the service available but do not guarantee uninterrupted access. We may update or discontinue features with notice where possible.

5. Limitation of liability
The app is provided as is. We are not liable for indirect or consequential damages arising from your use of the service.

6. Changes
We may update these terms. Continued use after changes means you accept the new terms.
''';

  static const String faq = '''
Frequently Asked Questions

How do I create a list?
Sign in, then create a new list from the Lists tab. Give it a name and optional due date.

How do I share a list?
Open the list, tap Share, and share the 5-digit code or invite by email. Others can join with the code.

Can I use the app without an account?
You can join a list with a code as a guest. To create and manage your own lists, sign in or register.

How do I remove someone from my list?
Open the list, go to sharing/collaborators, and remove their access.

Where is my data stored?
Your data is stored on our servers and synced to your devices. We use it only to run the service as described in our Privacy Policy.

How do I delete my account?
Use the option in Account/Settings in the app, or contact us to request account and data deletion.
''';
}
