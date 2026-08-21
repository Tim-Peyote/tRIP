# TRip — implementation status

Последнее обновление: 2026-08-21

Движок: Godot 4.7.2 stable

Renderer: Forward+ / Metal 4.0 на Apple M1

## Milestone 0 — implemented

### Project foundation

- Рабочий `project.godot` с main scene, input actions, physics layers и shader globals.
- Git-репозиторий, `.gitignore` и `.gitattributes`.
- Верхнеуровневый SceneTree: frontend, session roots, UI, presentation и debug.
- Main Menu с живым shader-фоном, базовой навигацией и настройками.

### Autoload services

- `SceneRouter` — проверяемая смена PackedScene.
- `SaveService` — versioned JSON envelope и запись через temporary file.
- `SettingsService` — ConfigFile, defaults и применение аудиогромкости.
- `ContentDB` — рекурсивная регистрация content Resources и проверка уникальных ID.

### Data-driven contracts

- `ContentDefinition`
- `IngredientDefinition`
- `ItemDefinition`
- `EffectDefinition`
- `RecipeDefinition` / `RecipeStepDefinition`
- `HypothesisDefinition`
- `VisualProfile`
- `AudioProfile`

ID используют namespaces (`ingredient.*`, `item.*`, `recipe.*`, `effect.*`). Runtime-состояние вынесено в отдельные domain objects.

### Domain and components

- `ItemInstance`
- `CookingProcess` / `CookingProcessEvent`
- `RecipeResolver` / `RecipeResolution`
- `InteractableComponent`
- `NoiseEmitterComponent` / `GameplayNoiseEvent`

### Presentation and audio

- `PresentationSnapshot` отделяет gameplay state от экранного исполнения.
- `PresentationDirector` сглаживает стабильный набор shader global channels.
- `AudioDirector` переключает snapshots независимо от gameplay noise.
- Созданы 10 шин: Master, Music, UI, PlayerFoley, World, Ambience, Creatures, Interactions, Voice, Perception.
- Visual intensity сохраняется и уже влияет на shader главного меню.

### First content thread

- `ingredient.mooncap`
- `effect.spore_sight`
- `item.spore_sight_brew`
- `recipe.spore_sight_brew`

Эталонный процесс `grind → heat` проходит через настоящий RecipeResolver и выдаёт качество `PURE`.

## Verification

Smoke test:

```bash
/Applications/Godot.app/Contents/MacOS/Godot \
  --headless \
  --path /Users/shaman/Desktop/Projects/Godot/TRIP \
  res://core/tests/smoke_test.tscn
```

Ожидаемый результат: `TRip smoke test: PASS`.

Visual capture:

```bash
/Applications/Godot.app/Contents/MacOS/Godot \
  --path /Users/shaman/Desktop/Projects/Godot/TRIP \
  res://core/tests/visual_capture.tscn
```

Сцена сохраняет `/tmp/trip_visual_capture.png` и завершает процесс.

## Milestone 1 — playable foundation implemented

- `CharacterBody3D` controller с acceleration, gravity, sprint и crouch.
- Crouch меняет camera height и capsule; clearance ray не даёт встать под препятствием.
- Mouse look и InputMap gamepad defaults для обоих стиков и основных действий.
- Независимый camera rig и временный low-poly viewmodel рук.
- `InteractionOrchestrator`: raycast, focus, единый prompt, hold/cancel и inspect.
- `InventoryComponent` с mass/volume contract.
- Физическая сцена лунной шляпки получает имя и описание через `ContentDB`.
- Gameplay HUD: reticle, prompt, hold progress, inspect card, сумка и pause panel.
- Blockout убежища с физикой, светом, столом и первой точкой взаимодействия.
- Процедурный ambience играет через шину `Ambience`.
- Шаги создают отдельные `GameplayNoiseEvent`; звук не является источником AI-шума.
- Main Menu → Shelter → Pause → Main Menu работает без смены архитектурных контрактов.

Gameplay test проверяет физический raycast, data-driven prompt/inspection и перенос собранного предмета в сумку.

## Remaining Milestone 1 polish

- настроить ощущение acceleration, sprint и head bob на живом управлении;
- заменить blockout viewmodel на rigged руки и предмет в руке;
- добавить surface-based footstep cues и glyph switching;
- сделать полноценный режим осмотра с вращением предмета;
- провести десятиминутный playtest на motion comfort.

## Cooking/effect vertical thread — implemented

Рабочая цепочка:

```text
ingredient.mooncap
  → Mortar / grind
  → Cauldron / heat
  → RecipeResolver / PURE
  → item.spore_sight_brew
  → quick use
  → effect.spore_sight
  → screen perception + hidden world geometry
```

### Inventory

- Добавлены удаление предмета, расходники и сигнал использования.
- `ConsumableDefinition` хранит `effect_ids` и число доз.
- `B` показывает содержимое сумки, `1` применяет первый готовый состав.

### Physical cooking

- `CookingOrchestrator` владеет одним runtime `CookingProcess` и выбранным `RecipeDefinition`.
- `CookingToolComponent` конфигурирует физический инструмент данными: operation, ingredient, tags, amount, temperature, duration и required item.
- Ступка и котёл не имеют уникальной рецептурной логики.
- Неверный порядок отклоняется с объяснимым сообщением.
- Ступка действительно удаляет лунную шляпку из сумки.
- Resolver создаёт готовый предмет только для качества `WORKING` и выше.

### Effect execution

- `EffectOrchestrator` хранит активные эффекты и их длительность.
- Gameplay и presentation channels агрегируются отдельно.
- `PresentationSnapshot` управляет shader globals.
- Full-screen perception pass добавляет chroma separation, tracking, scanlines, noise и palette quantization.
- `spore_vision` открывает реальную world-space геометрию мицелия; shader не является gameplay truth.

### Verification

- `TRip smoke test: PASS`
- `TRip gameplay test: PASS`
- `TRip cooking/effect test: PASS`
- Обычное состояние и спорозрение проверены через GPU visual capture в Forward+/Metal.

## Tool/harvest/forest vertical thread — implemented

### Equipment

- `ToolDefinition` описывает capabilities и precision.
- `ToolbeltComponent` не зависит от конкретного ножа.
- `tool.field_knife` даёт `cut`, `separate_cap` и `separate_stem`.
- `Q` достаёт/убирает инструмент; состояние синхронизировано с viewmodel и HUD.

### Harvest decisions

- ПКМ циклически выбирает `cap / stem / whole / spores`.
- Prompt сообщает выбранную часть и отсутствие нужного инструмента.
- Чистый срез запрещён без подходящей capability.
- Вырвать целое растение можно руками, но качество падает до 55%.
- Runtime item сохраняет part, harvest damage, tool ID и quality.
- Сумка показывает часть и качество конкретного экземпляра.

### Recipe consequences

- Рецепт спорозрения требует `part_cap`, а не просто любой fungus.
- `CookingProcessEvent` переносит source quality.
- `RecipeResolver` учитывает технологическую точность и качество сырья.
- Аккуратно срезанная шляпка даёт `PURE`; повреждённый целый гриб — `UNSTABLE`.

### Observable station

- После `grind` в ступке появляется измельчённое сырьё.
- После `heat` меняются жидкость и анимированный пар котла.
- Визуал подписан на domain-события и не определяет результат рецепта.

### First forest chunk

- За физической дверью доступна отдельная low-poly поляна.
- Chunk содержит землю, коллизии деревьев, камни, свет и второй harvestable mooncap.
- Обратный portal возвращает игрока в убежище.
- Геометрический blockout заменён первым визуальным benchmark-проходом; это художественная база, а не финальный environment art.

### Verification

- `TRip smoke test: PASS`
- `TRip gameplay test: PASS` — включая переход на поляну.
- `TRip harvest quality test: PASS`
- `TRip cooking/effect test: PASS` — включая visual states станции.
- Поляна визуально проверена в Forward+/Metal.

## Expedition/knowledge vertical thread — implemented

### Field decisions

- `ToolbeltComponent` поддерживает набор инструментов и переключает их по stable content ID.
- `tool.spore_vial` даёт capability `collect_spores`; `Q` переключает нож и пробирку вместе с viewmodel.
- На поляне появилась `ingredient.false_mooncap` — опасный двойник с отдельным data definition, визуальным силуэтом и токсичными trait channels.
- Выбор `spores` реально требует пробирку, тогда как чистый срез шляпки требует нож.

### Knowledge and objective

- Осмотр через общий `InteractableComponent` создаёт semantic inspection event, не UI-хак.
- `KnowledgeOrchestrator` хранит уровни `UNKNOWN → OBSERVED → COLLECTED → UNDERSTOOD`.
- Полевой гербарий открывается на `J` и подписан на knowledge events.
- Первая цель требует правильный вид и часть `cap`, собранные именно в лесной зоне.
- Ложная лунница даёт объяснимую ошибку, но не двигает цель.
- После правильного образца цель меняется на возвращение; обратный portal завершает вылазку.

### Risk pressure

- `ExpeditionClock` выдаёт нормализованное время и фазы `DAY / DUSK / NIGHT`.
- Forest chunk сам интерпретирует фазу через свет и интенсивность свечения спор.
- Первый `ListenerCreature` принимает только `GameplayNoiseEvent`, различает investigate/alert и идёт к источнику.
- Шаги игрока подключены к слуху существа на уровне композиции ShelterLevel.

### Verification

- `TRip expedition systems test: PASS` — проверены гербарий, пробирка, ложный/верный образец, возвращение, фазы времени и реакция AI на шум.
- Все четыре прежних headless-теста продолжают проходить.
- Поляна повторно проверена GPU capture: в кадре видны оба вида гриба, listener и новый objective/clock HUD.

## Stealth vertical thread — implemented

- `PerceptionSensorComponent` объединяет настраиваемый cone/range, physics line-of-sight, слух и suspicion.
- Стены, деревья и камни действительно перекрывают зрение через collision query.
- Стояние, движение, бег и crouch дают различную сигнатуру заметности.
- `ListenerCreature` перешёл на состояния `IDLE / INVESTIGATE / ALERT / CHASE / SEARCH`.
- `StealthOrchestrator` связывает player и sensors на уровне зоны и агрегирует угрозу для HUD.
- HUD показывает состояния `СКРЫТ / ПОДОЗРЕНИЕ / ТРЕВОГА / ОБНАРУЖЕН` и шкалу накопления.
- На `G` бросается физический камень; удар создаёт `GameplayNoiseEvent`, расходует ограниченный запас и переносит внимание существа.
- `TRip stealth test: PASS` проверяет прямую видимость, преследование, снижение exposure в crouch и отвлечение ударом камня.

## Physical cooking vertical thread — implemented

- `ThermalVesselState` моделирует воду, текущую и пиковую температуру, уровень огня, выдержку в целевом окне, передержку, число перемешиваний и однородность.
- Слабый огонь стабилизируется в рабочем диапазоне; сильный быстрее нагревает, но может необратимо испортить смесь.
- Готовка разбита на физические affordances: кувшин, ступка, котёл, заслонка очага, мешалка и чистая склянка.
- Игрок должен налить воду, перенести измельчённый образец, выбрать огонь, перемешать и самостоятельно решить момент розлива.
- Resolver оценивает реальные измерения процесса: stir count, homogeneity и overheat duration.
- HUD сообщает наблюдаемые признаки вместо скрытого progress bar: температура, однородность, нужный режим, серебристый пар и запах гари.
- Жидкость меняет цвет от температуры, слабый/сильный огонь меняет свет, пар усиливает читаемость готовности.
- `CookingStationAudio` процедурно создаёт пространственный треск огня и частоту пузырьков без зависимости gameplay от аудио.
- `TRip physical cooking test: PASS` проверяет чистый состав на слабом огне и провал от сильной передержки.

## Interactive inspection vertical thread — implemented

- `InspectionClueDefinition` задаёт stable observation ID, ракурс, допуск и нужный zoom.
- `InspectionSession` независимо от UI вычисляет найденные признаки по вращению и приближению.
- Полноэкранный `SampleInspectionView` использует отдельный SubViewport и собственный World3D.
- Модель можно непрерывно вращать мышью, пошагово на `A/D` и приближать колесом.
- Для настоящего и ложного гриба созданы разные inspect-модели и по три морфологических признака.
- Гербарий хранит конкретные clue IDs и показывает прогресс признаков каждого вида.
- Полный набор переводит вид в `UNDERSTOOD`, а не просто факт открытия карточки.
- `HypothesisOrchestrator` проверяет data-driven required observations; гипотеза настоящей лунной шляпки подтверждается тремя совместными признаками.
- Мир не ставится на паузу во время полевого осмотра: скрытность и время продолжают создавать риск.
- `TRip inspection test: PASS` проверяет модель, ракурсы, zoom, знания и подтверждение гипотезы.

## Full loop and persistence vertical thread — implemented

- Создан checkpoint-коммит `2479e5a` после успешного прогона восьми тестов.
- `GameLoopOrchestrator` связывает вылазку, возвращение, физическую готовку, отчёт, награду и следующую цель.
- После возвращения objective меняется на приготовление чистого настоя; случайная готовка до вылазки не завершает цикл.
- Экран результатов показывает качество, точность, время, число изученных признаков и конкретную награду.
- Награда физически открывает ранее заблокированный portal в отдельный chunk глубокой рощи.
- `SessionPersistenceOrchestrator` сохраняет inventory instances, knowledge/clues, objective, clock, cooking process/vessel, toolbelt, loop/unlocks, player transform и собранные world spawns.
- Autosave с debounce запускается после сбора, изменения знаний и ключевых переходов цикла; ручная запись выполняется при возврате в меню.
- Главное меню активирует Continue при наличии slot `0`; новая игра создаёт чистое сохранение, Continue восстанавливает session.
- Save schema поднята до версии 2, payload остаётся data-driven и не содержит NodePath.
- `TRip full cycle/persistence test: PASS` проходит полный цикл, создаёт новый уровень, загружает save и проверяет route unlock, инвентарь, знания, позицию и отсутствие повторного spawn.

## Visual benchmark foundation — implemented

- Лес получил отдельный `BiomeVisualProfile`: зелёный ambient, туман, фон и плавный переход из тёплого профиля убежища.
- Поляна собрана из переиспользуемых `GnarledTree`, рельефных моховых масс, ломаной тропы, упавшего дерева, камней и пространственных ориентиров.
- `VegetationScatter` детерминированно создаёт траву и папоротник через два `MultiMeshInstance3D`, без сотен отдельных Nodes.
- Напольная поверхность использует собственную low-resolution forest-floor texture с nearest filtering; геометрия, свет и VFX остаются отдельными слоями.
- Добавлены GPU-споры, локальное грибное свечение и более читаемый многосоставной силуэт Listener.
- Убежище получило балки, рейки, доски пола, полки, бутылки, сушёные травы и физический фонарь.
- Лунная шляпка получила жабры, кольцо и пятна; ложный вид — отличимые наросты.
- Временный viewmodel заменён на низкополигональные рукава, округлые кисти и пальцы. Полноценный rig и анимации остаются следующим art-pass.
- Обе сцены проверены GPU capture в Forward+/Metal, все девять headless-тестов проходят.

## Northern trail and mycologist search — implemented

- Между поляной и глубокой рощей добавлен отдельный протяжённый `ForestTrailChunk`; маршрут больше не сводится к одному квадрату и телепорту в соседнюю коробку.
- Северная тропа содержит собственный terrain layer, MultiMesh-растительность, туманные плоскости, GPU-споры, крупные ориентиры и два позиционных procedural audio emitter.
- Порталы получили геометрическую раму, светящиеся швы и локальный свет: выход из убежища и переходы читаются как пространственные объекты.
- После первого цикла открывается северная тропа, но путь в рощу проявляется только во время активного `effect.spore_sight`.
- Настой теперь запускает анимацию питья, усиливает screen-space волны/VHS/chroma, открывает world-space ступени и повышает заметность игрока для Listener.
- Два интерактивных следа начинают поиск пропавшего миколога. Второй виден только под спорозрением; найденные clue IDs сохраняются в `GameLoopOrchestrator`.
- Objective HUD последовательно ведёт игрока: северная тропа → первая зарубка → принять настой → найти споровую запись → войти в дышащий проход.
- Кувшин, пестик и мешалка получили короткие physical-action анимации; состояние и результат готовки по-прежнему определяет domain-модель.
- `TRip full cycle/persistence test` дополнительно проверяет следы миколога, проявление маршрута и восстановление narrative progress.

## Deep grove second expedition — implemented

- Прежняя тестовая площадка 12×12 заменена зоной 30×30 с нижней чашей, наклонным подъёмом, верхней террасой и отдельными ветками исследования.
- Композицию держат гигантские грибы, древнее кольцо, светящийся подъём и лагерь на возвышении; земля использует общий forest material, а растительность — отдельный MultiMesh seed.
- В лагере есть палатка, лежанка, ящики, локальный свет и интерактивная свежая запись пропавшего миколога.
- Добавлен `ingredient.emberberry` и harvestable-сцена тлеющей ягоды с частями `berry / leaf / root / whole`, собственным свечением и двумя persistent spawn IDs.
- Вторая objective-цепь ведёт от входа в рощу к лагерю, затем к ягоде и возвращению в убежище.
- `GameLoopOrchestrator` сохраняет вход в рощу, лагерь, сбор ягоды и завершение второй вылазки.
- Убежище получило жилой угол и кладовую сразу; после первого цикла проявляется карта маршрутов, после второго — полка светящихся образцов.
- `TRip full cycle/persistence test` проходит обе экспедиции и проверяет восстановление лагеря, ягоды, инвентаря и финального objective state.
- Глубокая роща и развитое убежище проверены отдельными Forward+/Metal captures.

## Counteragent and spore tide — implemented

- `CookingOrchestrator` поддерживает массив `RecipeDefinition` и выбирает активный рецепт по `primary_ingredient_id`; центральная станция больше не привязана к одному грибу.
- Одна ступка автоматически выбирает доступный подходящий образец, а `ThermalVesselState` переносит ingredient tags через физический процесс и сохранение.
- Добавлены `recipe.emberberry_tonic`, `item.emberberry_tonic` и `effect.spore_quiet`.
- Эффекты получили data-driven `cancels_effect_ids`: спорозрение и контрагент взаимно исключаются без проверки конкретных ID в player/UI.
- Контрагент снижает stealth exposure, почти блокирует споровое заражение, закрывает mycelial route и включает приглушённый audio snapshot.
- `SporeTideOrchestrator` моделирует `CALM / RISING / SURGE`, нахождение игрока в зоне, накопление exposure, защиту препаратом и выброс ко входу при переполнении.
- Глубокая роща интерпретирует состояние прилива количеством GPU-спор и интенсивностью света; HUD показывает фазу и exposure.
- Спорозрение ускоряет заражение, создавая реальную цену за доступ к скрытой информации.
- `TRip counteragent/tide test: PASS` проверяет второй рецепт, отмену эффектов, исчезновение маршрута и разницу защищённого/незащищённого exposure.
- Полный persistence test теперь также готовит контрагент и восстанавливает новый preparation choice.

## Spore shelters and surge clue — implemented

- Добавлен переиспользуемый `SporeShelterZone` с радиусом и силой защиты; hazard вычисляет вклад ближайшего укрытия без знания его визуальной сцены.
- В глубокой роще размещены три крупных грибных навеса, создающих безопасную цепочку от нижней зоны к лагерю.
- Внутри укрытия exposure убывает даже при `SURGE`; HUD показывает конкретное название активного навеса.
- Прямая ветка к древнему кольцу остаётся открытой и быстрее, но не защищает от прилива.
- `NarrativeClue` получил общие requirements `requires_spore_vision + required_world_state`; недоступная находка выключает и visual, и collision.
- Координатный след миколога у кольца проявляется только при одновременных `effect.spore_sight` и `SporeTide.State.SURGE`.
- Найденный след сохраняется обычным stable clue ID и переводит цель на подготовку к корневому колодцу.
- `TRip counteragent/tide test` дополнительно проверяет снижение exposure в физическом укрытии и двухфакторное проявление следа.

## Next vertical thread

1. Заменить составную low-poly кисть на rigged first-person arms и анимации среза, измельчения, розлива и осмотра.
2. Добавить отдельные семейства грибных деревьев/кристаллов для глубокой рощи и корневого колодца.
3. Продолжить корневой колодец ниже ложного сердца и добавить встречу с микологом.
4. Расширить физический гербарий отдельными карточками изученных видов и образцов.
5. LOD/occlusion pass после профилирования нового плотного dressing.

## Physical investigation board — implemented

- В убежище добавлена коллизионная world-space доска расследования, доступная через общий `InteractableComponent`.
- Зарубка, лагерная запись и координаты кольца материализуются отдельными карточками; красные нити появляются только после финальной находки.
- После получения контрагента и координат игрок выбирает один из двух планов: защищённый длинный спуск или короткий резонансный маршрут с повышенным вниманием грибницы.
- Выбор хранится как semantic ID `warded_descent / resonant_descent`, меняет objective и не зависит от конкретного визуального представления доски.
- Выбранная карточка отмечается world-space маркером, а повторное взаимодействие переключает план без отдельного меню.
- План входит в обычное сохранение `GameLoopOrchestrator`; full-cycle test проверяет запрет раннего выбора, смену objective и восстановление физического маркера.

## Root well third expedition — first phase implemented

- Под древним кольцом появился отдельный вертикальный chunk корневого колодца с входной площадкой, несколькими уровнями глубины, корневыми арками, частицами и пространственным пульсом.
- Вход закрыт до выбора на доске; начало спуска фиксирует решение, чтобы геометрию нельзя было переключить под игроком.
- `warded_descent` включает длинный трёхсекционный маршрут и две физические защитные мембраны; `resonant_descent` включает короткий открытый спуск и световые импульсы-навигацию.
- Новый `RootPressureOrchestrator` моделирует `REST / LISTENING / HUNTING`, учитывает movement exposure, выбранный план и spatial protection zones.
- При переполнении давление не убивает игрока, а возвращает на входную площадку, сохраняя знание и выбранный план.
- HUD показывает состояние корней, давление и название активной мембраны только внутри зоны колодца.
- Внизу находится интерактивный сигнал: миколог жив, но ложное сердце уже имитирует его голос; stable clue ID сохраняется и меняет objective.
- `TRip root well test: PASS` проверяет переключение visual/collision веток, защиту мембраны, рост давления на открытом пути и блокировку смены плана после входа.

## Seeded biome visual foundation — implemented

- Добавлен `BiomeDressingScatter`: один модуль строит отдельные MultiMesh-пулы хвойных, широколиственных, сухих стволов, камней и валежника.
- Поляна, северная тропа и глубокая роща получили разные density/palette profiles; authored landmarks и gameplay corridors остаются фиксированными.
- Декоративный layout зависит от сохранённого `world_seed`: новый забег получает другую композицию, загрузка возвращает прежнюю.
- Ландшафтный dressing расширен за физические границы маленьких gameplay-площадок, создавая несколько планов глубины и непрерывный лес вокруг маршрута.
- Environment получил procedural sky, SSAO, SSIL, glow и volumetric fog; лес использует тёплый направленный свет против холодного ambient/fog fill.
- Трава и папоротники используют собственные seeded MultiMesh-пулы; палитра и размеры исправлены так, чтобы подлесок поддерживал масштаб, а не выглядел россыпью одинаковых кубов.
- Старые симметричные капсульные руки убраны. Нож и флакон получили компактные локальные grip-модели; полноценный skeletal rig остаётся отдельной задачей.
- `TRip biome generation test: PASS` проверяет повторяемость одинакового seed и изменение композиционной сигнатуры при новом seed.

## Continuous authored landscape — implemented

- Отдельные плоские основания поляны, тропы, террасы и рампы отключены; экспедиционная зона теперь лежит на одной коллизионной heightfield-сетке.
- Рельеф сочетает seed-шум с художественными правилами: стабильная стартовая поляна, читаемый коридор маршрута, чаша глубокой рощи, возвышение лагеря, плавный подход и окружающий горный борт.
- Маршрут, холодная почва рощи и тёплая площадка лагеря окрашиваются прямо в вершинах общей сетки, без наложенных плит.
- Декоративные MultiMesh-объекты проецируются на высоту общего рельефа; генератор больше не создаёт собственные плоскости, холмы и скальные призмы, способные пересечь убежище.
- Плоские прямоугольные папоротники заменены объёмными низкополигональными кустами; поваленные стволы уменьшены до масштаба окружения.
- Forest profile использует цветной ambient fill, атмосферную перспективу и более светлую палитру почвы, поэтому передний, средний и дальний планы не проваливаются в чёрный.
- `TRip biome generation test: PASS` дополнительно фиксирует authored-высоты поляны, тропы, лагеря и непрерывность подъёма.
