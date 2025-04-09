# ChatSocket-Mobile


Mobile messagin application with Flutter


Changelog

- Version 0.1
 1 - Receiving unreceived messages (due to lack of socket) when application boots up.
 2 - Fix database query bug which is caused by getChatIdByUsername not using currently logged in user for querying.
 3 - Fix chat querying returning null caused by incorrect column filtering (chat_id -> id)
