# Схема этапов и флагов

## Этапы сценария (`GameState.stage`)

| ID | Смысл |
|----|--------|
| A_start | Старт, рабочий терминал |
| B_hr | После турникета / HR |
| C_print | Печать и питание |
| D_approvals | Согласования HR/бухгалтерия |
| E_security | Пост безопасности |
| F_finale | Турникет открыт |
| F_finished | Финал показан |

## Предметы

- `employee_badge` — пропуск (даёт `accounting_access`)
- `printed_application` — распечатанное заявление

## Доступ

- `accounting_access` — дверь бухгалтерии

## Флаги прогресса

| Флаг | Когда |
|------|--------|
| workday_started | Терминал на столе |
| exit_checked | Проверка турникета |
| hr_briefed | Первый визит в HR |
| printer_fault_triggered | Первый запуск принтера |
| power_restored | Электрощит |
| print_started / print_completed | Печать |
| hr_approved / accounting_approved / security_approved | Согласования |
| exit_unlocked | Все три согласования |
| enemy_activated | После старта печати |
| phone_ringing / phone_answered | Телефон (атмосфера) |
| poster_changed | После HR |
| security_door_open | Проход к безопасности |
| loop_corridor_completed | После 2 циклов коридора |
| game_finished | Кнопка лифта |

## Контрольные точки

`spawn`, `after_exit_check`, `after_power`, `after_hr`, `after_accounting`, `after_security`
