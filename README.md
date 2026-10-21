# ✈️ Telegram 2.0 (Flutter + Riverpod + Supabase)

Реактивный кроссплатформенный мессенджер с дизайном и UX в стиле **Telegram**. Проект разработан как демонстрация современной архитектуры Flutter для портфолио.

---

## 🌟 Ключевые фичи (Showstoppers)

1. **Optimistic UI (Оптимистичные обновления):**
   * Сообщения мгновенно появляются в ленте со статусом «ожидание» 🕒 без задержек сети.
   * При подтверждении сервером статус сменяется на отправлено ✓.
   * При прочтении собеседником отображаются двойные синие галочки ✓✓.

2. **Realtime-синхронизация (PostgreSQL CDC + WebSockets):**
   * Мгновенная доставка новых сообщений через каналы `supabase_realtime`.
   * Автоматическое обновление списка диалогов при поступлении новых сообщений.
   * Автоматический сброс счётчика непрочитанных при открытии чата.

3. **Стильный Telegram UI / UX:**
   * Аутентичная тёмная тема Telegram (`#0E1621`, `#17212B`, `#2B5278`).
   * Генерация цветных градиентных аватарок по хэшу имени (как в оригинальном Telegram).
   * Плавные баблы сообщений со встроенным временем и статусом доставки.
   * Поддержка изображений и BlurHash-плейсхолдеров (размытый цветной фон при загрузке фото).

4. **Чистая архитектура (Feature-First):**
   * **State Management:** Riverpod 3 (`AsyncNotifier`, `FamilyAsyncNotifier`) с автоматическим управлением жизненным циклом и подписками.
   * **Database & Auth:** Supabase (PostgreSQL + RLS политики + Storage + Triggers).
   * **Network / Cache:** Репозитории с разделением ответственности и DTO-моделями.

---

## 🏗 Архитектура проекта

```
lib/
├── core/
│   ├── constants/       # Цветовая палитра Telegram, ключи Supabase
│   ├── theme/           # Настройки Dark Theme
│   ├── services/        # Провайдеры SupabaseClient и аутентификации
│   └── utils/           # Форматирование дат (Вчера, 14:30) и хэши
├── features/
│   ├── auth/            # Вход, регистрация, валидация профиля
│   │   ├── controllers/ # AuthController (Riverpod AsyncNotifier)
│   │   ├── data/        # AuthRepository
│   │   └── presentation/# Экран входа в стиле Telegram
│   ├── chats/           # Список диалогов и поиск контактов
│   │   ├── controllers/ # ChatListController (с авто-инвалидацией по сокету)
│   │   ├── data/        # ChatRepository (прямые чаты, поиск по @username)
│   │   ├── models/      # ChatItem
│   │   └── presentation/# ChatListScreen, ChatTile, NewChatDialog
│   └── messages/        # Экран чата и отправка сообщений
│       ├── controllers/ # ChatMessagesController (Optimistic UI engine)
│       ├── data/        # MessageRepository (отправка, пагинация, Storage)
│       ├── models/      # Message, MessageStatus (pending, sent, read)
│       └── presentation/# ChatScreen, MessageBubble, ChatInputBar
└── main.dart            # Инициализация Supabase, AuthGate роутинг
```

---

## 🚀 Быстрый старт

### 1. Настройка Supabase
1. Создайте бесплатный проект на [Supabase](https://supabase.com).
2. Перейдите в раздел **SQL Editor** и выполните скрипт из файла [`supabase/schema.sql`](file:///Users/helltrilla/flutter/messenger/supabase/schema.sql).
3. В разделе **Storage** создайте публичный бакет `chat-media`.

### 2. Запуск приложения
Запустите проект с локальным файлом переменных `env.json` (который добавлен в `.gitignore`):
```bash
flutter run --dart-define-from-file=env.json
```
*(Пример структуры файла см. в `env.json.example`)*

---

## 🛠 Стек технологий

* **Flutter SDK:** 3.44+
* **Dart:** 3.12+
* **State Management:** `flutter_riverpod: ^3.4.3`
* **Backend:** `supabase_flutter: ^2.18.3`
* **Images & Cache:** `cached_network_image`, `flutter_blurhash`, `image_picker`
* **Code Style:** `flutter_lints` (0 warnings, 0 errors)