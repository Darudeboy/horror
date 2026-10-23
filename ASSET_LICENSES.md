# Лицензии ресурсов

## Политика проекта (CC0-only)

В проект допускаются **только**:

- **CC0 1.0** / Public Domain (или явный эквивалент без атрибуции и без ограничений на коммерческое использование)
- Собственные заглушки (примитивы Godot, процедурные материалы)

**Не допускаются:** CC-BY без отдельного решения, «free for personal use», ассеты без страницы лицензии, материалы с Google/Pinterest/Telegram, AI-картинки без явной коммерческой лицензии, «скачал из паблика».

При сомнении ресурс **не добавляется**.

### Шаблон записи

```
### <Имя ассета>
- Источник: <сайт>
- Автор / правообладатель: <имя>
- Лицензия: CC0 1.0
- URL лицензии / страницы: <https://...>
- URL скачивания: <https://...>
- Путь в проекте: `assets/...`
- Использование: <стены / пол / проп>
```

---

## Собственные заглушки

- Примитивы Godot (`BoxMesh`, `CapsuleMesh`, свет, `Label3D`)
- Материалы без текстур: `assets/materials/door_metal.tres`, `accent_sign.tres`, `printer_body.tres`
- Иконка `icon.svg` — оригинальная заглушка проекта
- Двери / люминесцентные корпуса / fallback-коллизии — собственные примитивы
- Звуки: Kenney Interface / RPG Audio / Impact Sounds (CC0) — см. ниже

---

## Сторонние ресурсы (CC0)

Все текстуры ниже — [ambientCG](https://ambientcg.com), лицензия **CC0 1.0**  
Общая лицензия: https://docs.ambientcg.com/license/  
Юридический текст CC0: https://creativecommons.org/publicdomain/zero/1.0/

### Plaster 001 (стены)
- Источник: ambientCG
- Автор / правообладатель: Lennart Demes / ambientCG
- Лицензия: CC0 1.0
- URL страницы: https://ambientcg.com/a/Plaster001
- URL скачивания: https://ambientcg.com/get?file=Plaster001_1K-JPG.zip
- Путь в проекте: `assets/textures/wall/Plaster001_1K-JPG_*.jpg`
- Материал: `assets/materials/wall_plaster.tres`
- Использование: стены офиса

### Carpet 008 (ковролин)
- Источник: ambientCG
- Автор / правообладатель: Lennart Demes / ambientCG
- Лицензия: CC0 1.0
- URL страницы: https://ambientcg.com/a/Carpet008
- URL скачивания: https://ambientcg.com/get?file=Carpet008_1K-JPG.zip
- Путь в проекте: `assets/textures/carpet/Carpet008_1K-JPG_*.jpg`
- Материал: `assets/materials/floor_carpet.tres` (оттенок затемнён albedo_color под тёмно-синий ковролин)
- Использование: основной пол

### Plaster 003 (потолок)
- Источник: ambientCG
- Автор / правообладатель: Lennart Demes / ambientCG
- Лицензия: CC0 1.0
- URL страницы: https://ambientcg.com/a/Plaster003
- URL скачивания: https://ambientcg.com/get?file=Plaster003_1K-JPG.zip
- Путь в проекте: `assets/textures/ceiling/Plaster003_1K-JPG_*.jpg`
- Материал: `assets/materials/ceiling_plaster.tres`
- Использование: потолок

### Tiles 074 (технический пол)
- Источник: ambientCG
- Автор / правообладатель: Lennart Demes / ambientCG
- Лицензия: CC0 1.0
- URL страницы: https://ambientcg.com/a/Tiles074
- URL скачивания: https://ambientcg.com/get?file=Tiles074_1K-JPG.zip
- Путь в проекте: `assets/textures/tech_floor/Tiles074_1K-JPG_*.jpg`
- Материал: `assets/materials/tech_floor_tiles.tres`
- Использование: пол серверной

### Kenney Furniture Kit (пропсы)
- Источник: Kenney.nl
- Автор / правообладатель: Kenney (www.kenney.nl)
- Лицензия: CC0 1.0
- URL лицензии: http://creativecommons.org/publicdomain/zero/1.0/
- URL набора: https://kenney.nl/assets/furniture-kit
- URL скачивания: https://kenney.nl/media/pages/assets/furniture-kit/440e0608a4-1677580847/kenney_furniture-kit.zip
- Копия лицензии в проекте: `assets/models/kenney/LICENSE.txt`
- Пути в проекте:
  - `assets/models/kenney/desk.glb`
  - `assets/models/kenney/chairDesk.glb`
  - `assets/models/kenney/computerScreen.glb`
  - `assets/models/kenney/computerKeyboard.glb`
- Использование: столы, стул, монитор/клавиатура на стартовом рабочем месте
- Примечание: атрибуция Kenney **не обязательна** по CC0; набор указан здесь для прозрачности

### CreativeTrio Printer
- Источник: Poly Pizza
- Автор: CreativeTrio
- Лицензия: Public Domain (CC0)
- URL: https://poly.pizza/m/77K2TCL5Lz
- Путь: `assets/models/props/printer.glb`
- Использование: визуал принтера в бухгалтерии

### Quaternius Ghost (compliance officer)
- Источник: Poly Pizza / Quaternius
- Автор: Quaternius
- Лицензия: Public Domain (CC0)
- URL: https://poly.pizza/m/Iip30bDHmu
- Путь: `assets/models/enemy/compliance_officer.glb`
- Использование: силуэт сотрудника службы соответствия (масштабирован)

### Barrier Single / Barrier Large (турникет)
- Источник: Poly Pizza
- Лицензия: Public Domain
- URL: https://poly.pizza/m/wCUxgt2jSP , https://poly.pizza/m/gLbBiYwt7l
- Путь: `assets/models/props/barrier_single.glb`, `barrier_large.glb`
- Использование: визуал турникета

### Pickup Key Card
- Источник: Poly Pizza
- Лицензия: Public Domain
- URL: https://poly.pizza/m/EDvCEBvs8k
- Путь: `assets/models/props/keycard.glb`
- Использование: визуал пропуска

### Kenney audio (шаги, двери, UI, тревога)
- Источник: Kenney.nl — Interface Sounds, RPG Audio, Impact Sounds
- Автор: Kenney
- Лицензия: CC0 1.0
- URL: https://kenney.nl/assets/interface-sounds , https://kenney.nl/assets/rpg-audio , https://kenney.nl/assets/impact-sounds
- Копии лицензий: `assets/audio/KENNEY_*_LICENSE.txt`
- Путь: `assets/audio/sfx/*.ogg`
- Использование: шаги, двери, подбор, сигнал, гибель, удар о стену
