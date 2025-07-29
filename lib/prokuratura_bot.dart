import 'package:teledart/teledart.dart';
import 'package:teledart/telegram.dart';
import 'package:teledart/model.dart';
import 'package:dotenv/dotenv.dart';

void startBot() async {
  final env = DotEnv()..load();
  final botToken = env['BOT_TOKEN']!;
  final adminId = 1794743491;

  final telegram = Telegram(botToken);
  final me = await telegram.getMe();
  final teledart = TeleDart(botToken, Event(me.username!));

  final userStates = <int, Map<String, dynamic>>{};

  teledart.start();

  teledart.onCommand('start').listen((msg) {
    userStates[msg.chat.id] = {'step': 'name', 'data': {}};
    teledart.sendMessage(
      msg.chat.id,
      '👋 Salom! Murojaat/taklif yuborish uchun ism‑familiyangizni kiriting:',
    );
  });

  teledart.onMessage().listen((msg) async {
    final id = msg.chat.id;
    if (!userStates.containsKey(id)) return;

    final state = userStates[id]!;
    final step = state['step'] as String;

    // Xavfsiz convert qilish
    final data = (state['data'] as Map).cast<String, dynamic>();
    state['data'] = data; // yangilab qo‘yish kerak bo‘lishi mumkin

    switch (step) {
      case 'name':
        data['name'] = msg.text;
        state['step'] = 'address';
        await teledart.sendMessage(id, '📍 Manzilingizni kiriting:');
        break;

      case 'address':
        data['address'] = msg.text;
        state['step'] = 'phone';
        await teledart.sendMessage(id, '📞 Telefon raqamingizni kiriting:');
        break;

      case 'phone':

        // oddiy validatsiya: kamida 7ta raqam bo‘lishi kerak

        data['phone'] = msg.text.toString();
        state['step'] = 'message';
        await teledart.sendMessage(id, '💬 Murojaat/taklif matnini yozing:');
        break;

      case 'message':
        data['text'] = msg.text;
        state['step'] = 'await_file_choice';
        await teledart.sendMessage(
          id,
          '📎 Qo‘shimcha fayl yuborasizmi?',
          replyMarkup: InlineKeyboardMarkup(inlineKeyboard: [
            [
              InlineKeyboardButton(
                  text: '📎 Ha, bor', callbackData: 'add_files'),
              InlineKeyboardButton(text: '❌ Yo‘q', callbackData: 'no_files'),
            ]
          ]),
        );
        break;

      case 'await_file_choice':
        // foydalanuvchi fayl yuboradi yoki /done bosadi, hech narsa qilinmaydi
        break;

      case 'file':
        if (msg.document != null || msg.photo != null || msg.video != null) {
          await teledart.forwardMessage(adminId, msg.chat.id, msg.messageId);
        }
        break;
    }
  });

  teledart.onCommand('done').listen((msg) async {
    final id = msg.chat.id;
    final state = userStates[id];
    if (state == null) return;

    final d = state['data'] as Map<String, dynamic>;
    state['step'] = 'confirm';

    final summary = '''
📝 Kiritilgan ma’lumotlar:
👤 Ism: ${d['name'] ?? '❓'}
📍 Manzil: ${d['address'] ?? '❓'}
📞 Telefon: ${d['phone'] ?? '❓'}
💬 Murojaat: ${d['text'] ?? '❓'}
''';

    await teledart.sendMessage(id, summary);
    await teledart.sendMessage(
      id,
      '❓ Ma’lumotlar to‘g‘rimi?',
      replyMarkup: InlineKeyboardMarkup(inlineKeyboard: [
        [
          InlineKeyboardButton(
              text: '✅ Ha, to‘g‘ri', callbackData: 'confirm_yes'),
          InlineKeyboardButton(
              text: '♻️ Yo‘q, qayta kiritaman', callbackData: 'confirm_no'),
        ]
      ]),
    );
  });

  teledart.onCallbackQuery().listen((cb) async {
    final id = cb.from.id;
    final state = userStates[id];
    if (state == null) return;

    final d = state['data'] as Map<String, dynamic>;

    switch (cb.data) {
      case 'add_files':
        state['step'] = 'file';
        await teledart.sendMessage(
          id,
          '📎 Fayllarni yuboring. Tugatish uchun /done ni bosing.',
        );
        break;

      case 'no_files':
        state['step'] = 'confirm';
        final summary = '''
📝 Kiritilgan ma’lumotlar:
👤 Ism: ${d['name']}
📍 Manzil: ${d['address']}
📞 Telefon: ${d['phone']}
💬 Murojaat: ${d['text']}
''';
        await teledart.sendMessage(id, summary);
        await teledart.sendMessage(
          id,
          '❓ Ma’lumotlar to‘g‘rimi?',
          replyMarkup: InlineKeyboardMarkup(inlineKeyboard: [
            [
              InlineKeyboardButton(
                  text: '✅ Ha, to‘g‘ri', callbackData: 'confirm_yes'),
              InlineKeyboardButton(
                  text: '♻️ Yo‘q, qayta kiritaman', callbackData: 'confirm_no'),
            ]
          ]),
        );
        break;

      case 'confirm_yes':
        final finalSummary = '''
🆕 Yangi murojaat:
👤 Ism: ${d['name']}
📍 Manzil: ${d['address']}
📞 Telefon: ${d['phone']}
💬 Murojaat: ${d['text']}
''';
        await teledart.sendMessage(adminId, finalSummary);
        await teledart.sendMessage(id,
            '✅ Ma’lumotlaringiz yuborildi. /start bilan yana yuborishingiz mumkin.');
        userStates.remove(id);
        break;

      case 'confirm_no':
        await teledart.sendMessage(
            id, '♻️ Qayta boshlash uchun /start ni bosing.');
        userStates.remove(id);
        break;
    }

    await teledart.answerCallbackQuery(cb.id);
  });
}
