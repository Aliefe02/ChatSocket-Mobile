# ChatSocket-Mobile

Mobile messaging application with Flutter.

## Changelog

### Version 0.1
- **Receiving unreceived messages**: Now retrieves unreceived messages when the application boots up (due to lack of socket).
- **Fix database query bug**: Resolved an issue where `getChatIdByUsername` wasn't using the currently logged-in user for querying.
- **Fix chat querying returning null**: Fixed the problem caused by incorrect column filtering (should be `id` instead of `chat_id`).

