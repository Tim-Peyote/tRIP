# Изолированные регрессионные сборки

`legacy_expedition_fixture.tscn` сохраняет исторические порталы, колодец и фиксированные лесные участки для тестов старых механик. Это не игровая сцена и не родитель production-сессии.

Зависимости направлены только так:

- игровая `expedition_session.gd` → `SessionController`;
- тестовая `LegacyExpeditionFixture` → `SessionController`;
- сохранения и оболочка приложения → `SessionController`.

Игровые файлы не ссылаются на fixture. Исторические интеграционные тесты передают её в `TripMain.session_scene` явно. Новые сценарии проверяйте на `world/levels/expedition_session.tscn`; актуальное восстановление сессии проверяет `session_architecture_test.tscn`, полную сюжетную цепочку — `world_content_progression_test.tscn`.

Прототип перенесён сюда из игровой папки без удаления ассетов и покрытия регрессий. Не используйте его для художественного редактирования новой игры.
