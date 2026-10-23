# Ваш выход не согласован

Одиночная 3D-игра от первого лица (Godot 4, GDScript): корпоративный хоррор в пустом офисе.
Самостоятельный проект без чужих персонажей, логотипов и лора Backrooms.

## Движок

- Проверено на: **Godot 4.7.2.stable.official** (`ed1daf0bf`)
- Рендерер прототипа: **Compatibility / GL Compatibility**
- Платформа v1: Windows, клавиатура и мышь
- Путь установки (winget): `%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64.exe`

## Запуск

1. Установите Godot 4.2+ (стандартный редактор, не обязательно .NET).
2. Откройте папку проекта (`project.godot`) в Godot.
3. Главная сцена меню: `res://scenes/ui/main_menu.tscn`
4. Полная игра: «Новая игра» или сцена `res://scenes/main/main.tscn`
5. Тест фундамента (этап 1): `res://scenes/main/foundation_test.tscn`

Headless-проверки (если Godot в PATH):

```bash
godot --headless --path . --quit-after 1
godot --headless -s res://tests/test_game_state.gd
```

## Управление

| Клавиша | Действие |
|--------|----------|
| WASD | Движение |
| Мышь | Обзор |
| Shift | Бег |
| E | Взаимодействие |
| Tab | Журнал задач |
| Esc | Закрыть окно / пауза |
| F1 | Debug-панель (только debug-сборка) |

Без прыжка и приседания в v1.

## Структура

```
scenes/main/          — основная сцена и foundation_test
scenes/player/        — FPS-игрок
scenes/world/         — (уровень собирается LevelBuilder)
scenes/interactables/ — дверь, документ (тестовые сцены)
scenes/enemies/       — сотрудник службы соответствия
scenes/ui/            — меню, HUD, пауза
scripts/core/         — GameState, задачи, задачи, события
scripts/player/       — движение и камера
scripts/interactions/ — Interactable и объекты мира
scripts/ai/           — ИИ противника
resources/            — задачи/события (описания)
assets/               — материалы и аудио-заглушки
tests/                — headless smoke-тесты
```

Автозагрузки: `GameState`, `SettingsManager`, `AudioManager`, `SaveManager`.
`TaskManager` и `EventDirector` живут в игровой сцене.

## Сценарий (кратко)

1. Терминал на столе → проверить турникет → HR  
2. Пропуск коллеги → бухгалтерия → принтер (сбой питания) → щит в серверной → печать  
3. HR + бухгалтерия согласования → дверь к безопасности / плакат  
4. Короткий повторяющийся коридор → пост безопасности  
5. Три согласования → турникет → лифт → финал  

Флаги и предметы: см. `scripts/core/game_state.gd` и `docs/progress_flags.md`.

## Ассеты и авторские права

Политика: **только CC0 / public domain** + собственные примитивы. Список и URL — в [ASSET_LICENSES.md](ASSET_LICENSES.md).  
Сейчас: ambientCG (стены/ковролин/потолок/техпол), Kenney Furniture Kit (стол/стул/монитор). Монстр, турникет и принтер — собственные примитивы.

## Ограничения прототипа

- Слух врага: по радиусу до источника шума, **без** акустики через стены.
- Звук: без обязательных аудиофайлов; события шума для ИИ не зависят от громкости в настройках.
- Уровень: graybox + CC0-материалы, собирается скриптом `LevelBuilder`.
- Экспорт `.exe` не выполнялся (нет подтверждённого Godot + export templates).

## Проверки

| Проверка | Статус |
|----------|--------|
| Наличие файлов проекта и путей `res://` | OK (статически) |
| `godot --headless --quit-after` | OK |
| `tests/test_game_state.gd` | OK (`TEST_OK`) |
| Загрузка `main_menu.tscn` / `main.tscn` / `foundation_test.tscn` | OK (headless, без SCRIPT ERROR) |
| E не работает через стену | Заложено лучом + world collision; нужна ручная проверка в окне |
| Пауза блокирует управление | Заложено (`gameplay_paused` + `get_tree().paused`); нужна ручная проверка |
| Полное прохождение 15–25 мин | Требует плейтеста в редакторе |
| Экспорт Windows | Не выполнялся (нет проверки export templates) |

## Лицензии ассетов

См. [ASSET_LICENSES.md](ASSET_LICENSES.md). Сторонние платные ресурсы не используются.
