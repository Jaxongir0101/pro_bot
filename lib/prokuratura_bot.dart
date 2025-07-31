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
  final adminIds = [1794743491, 987654321]; // Admin Telegram ID lar

  final Map<int, List<dynamic>> adminReplyData = {};

  final userStates = <int, Map<String, dynamic>>{};
  teledart.start();

  final List<String> districts = [
    "Жиззах шаҳар",
    "Арнасой тумани",
    "Бахмал тумани",
    "Доʻстлик тумани",
    "Фориш тумани",
    "Гʻаллаорол тумани",
    "Мирзачоʻл тумани",
    "Пахтакор тумани",
    "Янгиобод тумани",
    "Зарбдор тумани",
    "Зафаробод тумани",
    "Зомин тумани",
    "Шароф Рашидов тумани",
  ];

  teledart.onCommand('start').listen((msg) async {
    final id = msg.chat.id;

    if (adminIds.contains(id)) {
      await teledart.sendMessage(
        id,
        '👋 Админ панелга хуш келибсиз.',
        replyMarkup: ReplyKeyboardMarkup(
          keyboard: [
            [KeyboardButton(text: '📨 Фойдаланувчига жавоб бериш')],
          ],
          resizeKeyboard: true,
          oneTimeKeyboard: false,
        ),
      );
    } else {
      userStates[msg.chat.id] = {'step': 'name', 'data': {}};
      teledart.sendMessage(
        msg.chat.id,
        '👋 Ассалом алекум! ҳурматли фуқаро, Ариза, таклиф ва мурожаатларни  юбориш учун исм‑фамилиянгизни киритинг:',
      );
    }
  });

  teledart.onCommand('reply').listen((msg) async {
    final id = msg.chat.id;

    if (!adminIds.contains(id)) {
      await teledart.sendMessage(id, '❌ Сизда бу буйруқ учун рухсат ёқ.');
      return;
    }

    // Adminni foydalanuvchi ID kiritish bosqichiga o‘tkazamiz
    userStates[id] = {'step': 'await_user_id'};
    adminReplyData[id] = [];

    await teledart.sendMessage(id,
        '👤 Жавоб юбормоқчи бўлган фуқаронинг Телеграм ИД сини киритинг:');
  });

  teledart.onMessage().listen((msg) async {
    final id = msg.chat.id;
    if (!userStates.containsKey(id)) return;

    final state = userStates[id]!;
    final step = state['step'];

    final data = (state['data'] as Map?)?.cast<String, dynamic>() ?? {};
    state['data'] = data;

    if (adminIds.contains(id)) {
      if (msg.text == '📨 Fuqaroga javob berish') {
        userStates[id] = {'step': 'await_user_id'};
        adminReplyData[id] = [];
        await teledart.sendMessage(
            id, '🆔 Фуқаронинг телеграм ИД сини киритинг:');
        return;
      }
      // Admin ID yuborgan bo‘lsa
      if (userStates[id]?['step'] == 'await_user_id') {
        print("await_user_id");
        final targetId = int.tryParse(msg.text ?? '');
        if (targetId != null) {
          try {
            userStates[id]!['step'] = 'replying';
            userStates[id]!['target'] = targetId;

            print("✅ targetId qabul qilindi: $targetId");

            await teledart.sendMessage(
              id,
              '✍️ Фуқарога матни ва медиа юборинг. Тугатиш учун "✅ Доне" тугмасини босинг.',
              replyMarkup: ReplyKeyboardMarkup(
                keyboard: [
                  [KeyboardButton(text: '✅ Done')],
                ],
                resizeKeyboard: true,
                oneTimeKeyboard: true,
              ),
            );
          } catch (e) {
            await teledart.sendMessage(
                id, '❌ Бу ИД бўйича фуқарога ёзиб бўлмади, қайта уруниб кўринг');
            print('❌ sendMessage xatolik: $e');
          }
        } else {
          await teledart.sendMessage(id, '❌ ИД нотўғри киритилаяпди.');
        }

        return;
      }

// Admin javob yozish jarayonida
      if (userStates[id]?['step'] == 'replying') {
        final target = userStates[id]!['target'];

        if (msg.text?.toLowerCase() == '✅ done' ||
            msg.text?.toLowerCase() == 'done') {
          for (var item in adminReplyData[id]!) {
            if (item is String) {
              await teledart.sendMessage(target, '✉️ Админдан:\n$item');
            } else if (item is Message) {
              if (item.photo != null) {
                await teledart.sendPhoto(
                  target,
                  item.photo!.last.fileId,
                  caption: '✉️ Админдан:',
                );
              } else if (item.document != null) {
                await teledart.sendDocument(
                  target,
                  item.document!.fileId,
                  caption: '✉️ Админдан:',
                );
              } else if (item.video != null) {
                await teledart.sendVideo(
                  target,
                  item.video!.fileId,
                  caption: '✉️ Админдан:',
                );
              } else {
                // Fallback: oddiy forward
                await teledart.forwardMessage(target, id, item.messageId);
              }
            }
          }

          await teledart.sendMessage(id, '✅ Жавоб юборилди.',
              replyMarkup: ReplyKeyboardRemove(removeKeyboard: true));

          userStates.remove(id);
          adminReplyData.remove(id);
        } else {
          // Media yoki matn qo‘shish
          if (msg.text != null) {
            adminReplyData[id]!.add(msg.text!);
          } else if (msg.photo != null ||
              msg.document != null ||
              msg.video != null) {
            adminReplyData[id]!.add(msg);
          }
        }
        return;
      }
    }

    switch (step) {
      case 'name':
        data['name'] = msg.text;
        state['step'] = 'region';

        await teledart.sendMessage(
          id,
          '📍 Яшаш ҳудудингизни танланг:',
          replyMarkup: ReplyKeyboardMarkup(
            keyboard: districts.map((d) => [KeyboardButton(text: d)]).toList(),
            resizeKeyboard: true,
            oneTimeKeyboard: true,
          ),
        );
        break;

      case 'region':
        if (!districts.contains(msg.text)) {
          await teledart.sendMessage(id, '❗ Илтимос, рўйхатдан танланг.');
          return;
        }

        data['region'] = msg.text;
        state['step'] = 'address';
        await teledart.sendMessage(
          id,
          '📍 Яшаш манзилингизни киритинг:',
          replyMarkup: ReplyKeyboardRemove(removeKeyboard: true),
        );
        break;

      case 'address':
        data['address'] = msg.text;
        state['step'] = 'phone';

        await teledart.sendMessage(
          id,
          '📞 Телефон рақамингизни киритинг ёки тугмадан фойдаланинг:',
          replyMarkup: ReplyKeyboardMarkup(
            keyboard: [
              [
                KeyboardButton(
                  text: '📲 Рақамни юбориш',
                  requestContact: true,
                )
              ]
            ],
            resizeKeyboard: true,
            oneTimeKeyboard: true,
          ),
        );
        break;

      case 'phone':
        String? phone;

        if (msg.contact != null) {
          phone = msg.contact!.phoneNumber;
        } else if (msg.text != null && msg.text!.length >= 7) {
          phone = msg.text!;
        }

        if (phone != null) {
          data['phone'] = phone;
          state['step'] = 'message';
          await teledart.sendMessage(
            id,
            '💬 Ариза, таклиф ёки мурожаатингизни киритинг:',
            replyMarkup: ReplyKeyboardRemove(removeKeyboard: true),
          );
        } else {
          await teledart.sendMessage(
            id,
            '📞Илтимос, рақамни ёзинг ёки 📲 тугмани босинг:',
          );
        }
        break;

      case 'message':
        data['text'] = msg.text;
        state['step'] = 'await_file_choice';
        await teledart.sendMessage(
          id,
          '📎 Қўшимча файл юборасизми?',
          replyMarkup: InlineKeyboardMarkup(inlineKeyboard: [
            [
              InlineKeyboardButton(
                  text: '📎 Ҳа, бор', callbackData: 'add_files'),
              InlineKeyboardButton(text: '❌ Ёқ', callbackData: 'no_files'),
            ]
          ]),
        );
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
📝 Киритилган маълумотлар:
👤 Исм: ${d['name']}
🏘 Ҳудуд: ${d['region']}
📍 Манзил: ${d['address']}
📞 Телефон: ${d['phone']}
💬 Мурожаат: ${d['text']}
''';

    await teledart.sendMessage(id, summary);
    await teledart.sendMessage(
      id,
      '❓ Маълумотлар тўғрими??',
      replyMarkup: InlineKeyboardMarkup(inlineKeyboard: [
        [
          InlineKeyboardButton(
              text: '✅ Ҳа, тўғри', callbackData: 'confirm_yes'),
          InlineKeyboardButton(
              text: '♻️ Ёқ, қайта киритаман', callbackData: 'confirm_no'),
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
        await teledart.sendMessage(id,
            '📎 Файлларни юборинг. Якунлаш учун /done буйруғини босинг..');
        break;

      case 'no_files':
        state['step'] = 'confirm';
        final summary = '''
📝 Киритилган маълумотлар:
👤 Исм: ${d['name']}
🏘 Ҳудуд: ${d['region']}
📍 Манзил: ${d['address']}
📞 Телефон: ${d['phone']}
💬 Мурожаат: ${d['text']}
''';
        await teledart.sendMessage(id, summary);
        await teledart.sendMessage(
          id,
          '❓ Маълумотлар тўғрими??',
      replyMarkup: InlineKeyboardMarkup(inlineKeyboard: [
        [
          InlineKeyboardButton(
              text: '✅ Ҳа, тўғри', callbackData: 'confirm_yes'),
          InlineKeyboardButton(
              text: '♻️ Ёқ, қайта киритаман', callbackData: 'confirm_no'),
        ]
          ]),
        );
        break;

      case 'confirm_yes':
        final finalSummary = '''
🆕 Янги мурожаат:
🆔 Телеграм ИД $id
👤 Исм: ${d['name']}
🏘 Ҳудуд: ${d['region']}
📍 Манзил: ${d['address']}
📞 Телефон: ${d['phone']}
💬 Мурожаат: ${d['text']}

✍️ Жавоб: /reply $id
''';

        await teledart.sendMessage(adminId, finalSummary);
        await teledart.sendMessage(id,
            '✅ Мурожаатингиз қабул қилинди. Белгиланган муддат ичида кўриб чиқилиб, муаулифга маълум қилинади.');
        userStates.remove(id);
        break;

      case 'confirm_no':
        await teledart.sendMessage(
            id, '♻️ Қайта бошлаш учун /start ни босинг.');
        userStates.remove(id);
        break;
    }

    await teledart.answerCallbackQuery(cb.id);
  });
}
