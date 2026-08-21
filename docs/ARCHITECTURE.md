# TRip — architecture rules

## 1. Главный принцип

Архитектура следует возможностям Godot: сцены композируют поведение, Nodes живут там, где требуется SceneTree/lifecycle, Resources хранят редактируемые определения, а чистые `RefCounted`-классы выполняют расчёты без зависимости от мира.

Не строим один глобальный `GameManager`, глобальную шину всех событий или наследование вида `MagicRedPoisonMushroom extends Mushroom`. Расширение контента должно происходить преимущественно созданием `.tres`-ресурсов и композицией компонентов.

## 2. Слои

### Definitions — неизменяемые данные

Custom Resources:

- `IngredientDefinition`
- `RecipeDefinition`
- `EffectDefinition`
- `ItemDefinition`
- `BiomeDefinition`
- `EncounterDefinition`
- `QuestDefinition`
- `HypothesisDefinition`
- `AudioProfile`
- `VisualProfile`

Каждое определение имеет стабильный `StringName id`, теги, presentation-ссылки и параметры. В `.tres` не хранится runtime-состояние конкретного предмета.

### Domain — чистая логика

`RefCounted`/value objects:

- `ItemInstance`
- `IngredientState`
- `CookingProcess`
- `RecipeResolver`
- `EffectStack`
- `ExpeditionState`
- `ObjectiveState`
- `KnowledgeState`

Domain не ищет Nodes, не читает Input и не показывает UI. Его можно тестировать headless.

### Components — локальные способности сцены

Примеры:

- `InteractableComponent`
- `InventoryComponent`
- `HeatSourceComponent`
- `CookwareComponent`
- `NoiseEmitterComponent`
- `HealthComponent`
- `EffectReceiverComponent`
- `SaveableComponent`
- `ToolbeltComponent`
- `HarvestableIngredient`
- `CookingToolComponent`

Компонент отвечает за одну способность и сигнализирует о результате. Он не знает весь игровой цикл.

### Orchestrators — координация use case

- `GameFlowOrchestrator`: загрузка main menu, убежища и экспедиции.
- `ExpeditionDirector`: цель, время, фазы риска, успешный выход/провал.
- `InteractionOrchestrator`: соединяет намерение игрока с текущим interactable.
- `CookingOrchestrator`: последовательность действий станции и вызов resolver.
- `EffectOrchestrator`: применение результата к gameplay-компонентам.
- `WorldStateDirector`: состояние зон, изменения и условия появления проходов.
- `PresentationDirector`: визуальная и звуковая интерпретация общего состояния.
- `AudioDirector`: snapshots аудиошин, приоритет критичных cues и переходы ambience.
- `ObjectiveOrchestrator`: активная цель, гипотеза и наблюдаемый прогресс без управления HUD.
- `FrontendOrchestrator`: состояния главного меню, слотов сохранения и первого запуска.

Оркестратор принадлежит сцене/use case, а не autoload. Он может знать участников, но участники не должны знать оркестратор.

### Services — действительно глобальная инфраструктура

Только четыре autoload на старте:

- `SceneRouter`
- `SaveService`
- `SettingsService`
- `ContentDB`

У autoload нет игровой физики, противников, рецептурных правил и ссылок на конкретный уровень. Новая глобальная сущность добавляется только если переживает смену сцен, имеет один экземпляр и работает изолированно.

## 3. SceneTree верхнего уровня

```text
Main
├── GameFlowOrchestrator
├── Session
│   ├── WorldRoot
│   ├── ActorsRoot
│   │   └── Player
│   ├── GameplayOrchestrators
│   └── RuntimeObjects
├── UI
├── Presentation
│   ├── PresentationDirector
│   ├── AudioDirector
│   ├── WorldEnvironment
│   └── ScreenEffects
└── Debug
```

Уровень заменяется внутри `WorldRoot`; player/session не приходится спасать из удаляемой сцены специальными хаками.

## 4. Направление зависимостей

```text
Input → Player/Interaction → local Components → Domain calculation
                                      ↓
Definitions ← ContentDB          gameplay signals
                                      ↓
                             Orchestrators
                               ↙       ↘
                       World state   Presentation snapshot → UI/VFX/Audio
```

Правила:

- родитель внедряет зависимости детям;
- sibling-сцены не ищут друг друга по абсолютным NodePath;
- прямой вызов используется для команды и ожидаемого результата;
- signal используется для уже произошедшего локального события;
- groups применяются для категорий/массового запроса, не как service locator;
- UI читает view model/snapshot и отправляет намерения, но не меняет domain напрямую;
- VFX и Audio никогда не являются источником gameplay truth.

## 5. Контракт ингредиента

```text
IngredientDefinition (shared Resource)
├── id, display_name, tags
├── mesh/icon/audio profile
├── processing responses
├── chemical/effect traits
└── spawn requirements

ItemInstance (runtime/save data)
├── definition_id
├── quantity
├── freshness
├── quality
├── processing_state
└── discovered_traits
```

Один definition можно использовать в растении мира, предмете сумки, содержимом котла и записи гербария. Конкретное состояние не записывается обратно в shared Resource.

Runtime `ItemInstance.processing_state` хранит наблюдаемое состояние конкретного образца:

```text
part: cap | stem | whole | spores
harvest_damage: 0.0 .. 1.0
tool_id: stable content id
quality: отдельное поле 0.0 .. 1.0
```

`ToolDefinition` объявляет capabilities (`cut`, `separate_cap`, `collect_spores`) и precision. Harvestable спрашивает capability у `ToolbeltComponent`, но не проверяет конкретный класс ножа. Поэтому новый инструмент расширяет доступные действия данными.

## 5.1 Контракт знаний и экспедиции

`InteractableComponent.request_inspection()` создаёт semantic event осмотра. Мир переводит его в stable definition ID, `KnowledgeOrchestrator` продвигает уровень знания, а HUD только отображает результат. Так осмотр может в будущем питать задания, звук и анимацию, не завися от панели интерфейса.

`ExpeditionObjectiveOrchestrator` принимает завершённые доменные события (`ItemInstance`, вход в радиус проявленной дорожной лаборатории), а не опрашивает инвентарь каждый кадр. `ExpeditionClock` публикует нормализованный progress и дискретную phase; chunk сам выбирает свою визуальную интерпретацию.

Шум остаётся отдельным gameplay-каналом:

```text
NoiseEmitterComponent → GameplayNoiseEvent → zone composition → ListenerCreature
AudioStreamPlayer     → Audio buses                         (presentation only)
```

Новый источник шума не должен знать классы существ, а новое существо не должно искать player глобально.

### Stealth perception contract

`PerceptionSensorComponent` владеет только sensing state: cone/range, physics line-of-sight, hearing radius и suspicion. Он получает target через `setup_target()` и не ищет игрока в группе. `ListenerCreature` интерпретирует sensing events как состояния движения, а `StealthOrchestrator` агрегирует несколько sensors для HUD.

```text
player signature ──→ vision query ──→ suspicion ──→ creature state
player/projectile ─→ noise event  ──┘         └──→ HUD threat view
```

`get_stealth_exposure()` — компактный контракт цели: поза и скорость меняют эффективную дальность и скорость обнаружения. Геометрия мира остаётся источником occlusion через physics query. Бросаемый камень создаёт обычный `GameplayNoiseEvent`, поэтому AI не содержит специального условия для конкретного предмета.

## 6. Контракт готовки

Инструмент принимает `CookingAction` и создаёт `ProcessEvent`:

```text
player action
  → tool validates local affordance
  → ProcessEvent(action, ingredient_id, amount, temperature, duration)
  → CookingProcess appends event and updates observable state
  → RecipeResolver evaluates constraints
  → ResultInstance + explanation tags
```

Это позволяет добавить новый котёл, рецепт или ингредиент без `if ingredient == ...` в центральном скрипте.

### Thermal vessel contract

`ThermalVesselState` — runtime domain объекта посуды. Он не читает input и не управляет Nodes:

```text
water_amount + heat_level + delta
                 ↓
temperature / peak_temperature
                 ↓
target_duration + overheat_duration + homogeneity
                 ↓
measured CookingProcessEvent → RecipeResolver
```

Физические объекты станции используют один `PhysicalCookingStationComponent` с ролями `add_water`, `transfer`, `cycle_heat`, `stir`, `bottle`. Они отправляют команды в `CookingOrchestrator`, но не вычисляют рецепт. `CookingStationVisuals`, температурный HUD и `CookingStationAudio` подписаны на один vessel state и не являются источником результата.

Несколько рецептов станции задаются массивом `RecipeDefinition`; выбор происходит по `primary_ingredient_id` первого события, а активный recipe ID сохраняется вместе с process/vessel. `ThermalVesselState` переносит ingredient tags, поэтому физический розлив оценивается тем же `RecipeResolver` для гриба, ягоды и будущих типов сырья.

Зональные угрозы оформляются локальными orchestrator-компонентами chunk-сцены. `SporeTideOrchestrator` знает только player contract, границы зоны, фазу и semantic effect channels; HUD, GPU particles, свет и audio independently интерпретируют его сигналы. Переполнение exposure меняет позицию игрока как gameplay consequence, но визуальная плотность спор не определяет расчёт.

Безопасные точки предоставляют минимальный spatial contract `get_protection_at(world_position)`. `SporeTideOrchestrator` агрегирует найденные shelter-компоненты и не проверяет имена сцен или тип геометрии. Narrative requirements также выражаются semantic state ID (`surge`) и effect channel, поэтому один `NarrativeClue` можно использовать для времени суток, погоды или других состояний мира.

Старый параметрический `perform_action()` остаётся полезным для инструментов и headless-тестов. Физический путь формирует тот же `CookingProcessEvent`, дополненный измеренными `stir_count`, `homogeneity` и `overheat_duration`; поэтому resolver не имеет отдельной ветки «игровой котёл».

## 7. Контракт эффектов

Gameplay и изображение разделены:

```text
EffectStack
├── gameplay channels: speed, perception, noise, toxicity, world_phase
└── presentation channels: blur, chroma, noise, wobble, audio_pitch, whispers
```

Каждый кадр `EffectOrchestrator` рассчитывает ограниченный snapshot. `PresentationDirector` сглаживает его и передаёт параметры материалам, Environment и Audio buses. Shader не запрашивает инвентарь или активные предметы.

## 8. Предлагаемая структура папок

```text
res://
├── addons/
├── app/
│   ├── main/
│   └── services/
├── core/
│   ├── domain/
│   ├── resources/
│   ├── components/
│   └── tests/
├── features/
│   ├── player/
│   ├── interaction/
│   ├── inventory/
│   ├── ingredients/
│   ├── cooking/
│   ├── effects/
│   ├── expedition/
│   ├── objectives/
│   ├── creatures/
│   ├── herbarium/
│   ├── frontend/
│   └── accessibility/
├── world/
│   ├── biomes/
│   ├── levels/
│   └── props/
├── presentation/
│   ├── materials/
│   ├── shaders/
│   ├── environments/
│   ├── audio/
│   └── ui/
├── content/
│   ├── ingredients/
│   ├── recipes/
│   ├── effects/
│   └── encounters/
└── tools/
    └── validators/
```

Ассеты, уникальные для одной feature-сцены, лежат рядом с ней. Общие presentation-ассеты лежат в соответствующем общем каталоге.

## 9. Save model

- Сохраняются стабильные ID и примитивные значения, а не NodePath/Resource UID как единственный ключ.
- Save имеет `schema_version` и последовательные migration-функции.
- Definition загружается по ID через `ContentDB`.
- Runtime instances получают собственные ID только когда это действительно нужно.
- Autosave пишется во временный файл и атомарно заменяет основной после успешной сериализации.

`SessionPersistenceOrchestrator` принадлежит активной session scene и собирает save payload из публичных контрактов систем. Он не сериализует Nodes целиком:

```text
Inventory ItemInstances + Knowledge clue IDs + Objective stage
+ Expedition clock + Cooking process/vessel + Toolbelt
+ GameLoop stage/unlocks + collected spawn IDs + player transform
                              ↓
                    SaveService schema envelope
```

Harvestable использует стабильный `spawn_id`; после загрузки собранные world instances удаляются, поэтому ресурс нельзя дублировать повторным входом. Тестовые сценарии используют отдельные слоты `90+` и не затрагивают пользовательский slot `0`.

`GameLoopOrchestrator` координирует макроэтапы `EXPEDITION → BREW → REWARD → DEEP_GROVE`. Он слушает завершённые события objective/cooking, формирует summary и unlock, но не рисует экран и не пишет файл самостоятельно. HUD и persistence подписываются на его typed signals.

Физическая `InvestigationBoard` является world-space adapter: она читает stable clue IDs и отправляет выбранный semantic plan ID обратно в `GameLoopOrchestrator`. Геометрия карточек, нитей и маркеров не является источником истины. Будущий chunk корневого колодца получает `root_well_plan` через setup-контракт и не ищет доску по NodePath.

`RootWellChunk` реализует этот входной контракт: semantic plan ID включает соответствующие visual/collision subtrees, а `RootPressureOrchestrator` независимо рассчитывает циклическую угрозу. Защитные мембраны предоставляют тот же минимальный spatial contract `get_protection_at(world_position)`, поэтому hazard не зависит от их mesh, материалов или NodePath. HUD подписан только на typed state/pressure/ward/area signals.

Поиск миколога расширяет тот же макроцикл stable clue IDs. `NarrativeClue` сообщает только факт обнаружения, `GameLoopOrchestrator` хранит прогресс и формирует следующую цель, а chunk управляет видимостью своей геометрии. Эффект спорозрения передаёт semantic gameplay channel: он одновременно проявляет маршрут, меняет stealth exposure и создаёт presentation snapshot, но shader сам не открывает проход.

## 10. UI architecture

- Каждый экран — самостоятельная сцена `Control` с typed input/output signals.
- `FrontendOrchestrator` управляет переходами Main Menu → Slot Select → First Run → Game, но не рисует кнопки.
- HUD получает компактный `HUDViewModel`: focus prompt, hands state, transient condition cues и краткое обновление цели.
- Гербарий читает `KnowledgeState`; он не открывает знания самостоятельно.
- Доска гипотез отправляет намерение выбрать цель в `ObjectiveOrchestrator`.
- Сумка отображает `InventoryComponent`, а перенос предмета выполняется его command API.
- Station UI отображает `CookingProcess`; фактические операции производят инструменты мира.
- Метод ввода отслеживается централизованно только для glyphs, а gameplay читает Input actions.

### Interactive inspection contract

`IngredientDefinition` содержит `inspect_scene` и массив `InspectionClueDefinition`. Каждый clue задаёт stable observation ID, текст наблюдения, нужный ракурс, допуск угла и минимальное приближение.

```text
Interactable semantic inspection
        ↓ definition_id
SampleInspectionView (SubViewport, own World3D)
        ↓ rotate / zoom
InspectionSession discovers clue IDs
        ↓
KnowledgeOrchestrator → HypothesisOrchestrator → Herbarium UI
```

`InspectionSession` — чистый `RefCounted`: обнаружение признаков можно тестировать без рендера. `SampleInspectionView` отвечает за 3D-модель и ввод, но не открывает знания напрямую. `KnowledgeOrchestrator` хранит найденные IDs, а `HypothesisOrchestrator` проверяет data-driven `required_observation_ids`. Поэтому новый вид, признак или гипотеза добавляются ресурсами без веток в HUD.

SubViewport имеет собственный `World3D`, чтобы модель исследования не наследовала геометрию, свет и физику активного уровня. Во время полевого осмотра мир не ставится на паузу: interactor временно отключается, но expedition clock и AI продолжают работать.

## 11. 3D presentation pipeline

```text
World state + Effect snapshot + Accessibility settings
                         ↓
              PresentationDirector
              ↙          ↓          ↘
       Environment   Materials   Screen effects
       fog/exposure  world cues  VHS/PS1 lens
```

- `VisualProfile` хранит авторские значения окружения и lens-эффектов для состояния мира.
- `BiomeVisualProfile` хранит фон, ambient и fog конкретной зоны; `BiomeVisualController` смешивает их при переходе через portal.
- Director смешивает профили по кривым; отдельные эффекты не перезаписывают shader parameters друг друга.
- World-space изменения (геометрия, видимость, коллизия) принадлежат `WorldStateDirector`.
- Shader Global Parameters используются для небольшого стабильного набора общих каналов восприятия.
- Массовая растительность строится кластерами/MultiMesh; уникальные интерактивные растения остаются сценами.
- `VegetationScatter` создаёт детерминированные MultiMesh-слои по seed, а деревья и крупные ориентиры остаются переиспользуемыми PackedScene.
- `BiomeDressingScatter` держит отдельные GPU-пулы для семейств силуэтов (conifer, broadleaf, snag, rock, log, terrain mass). Он получает session `world_seed`, но не перемещает authored landmarks, interactables или порталы.
- Seed хранится в `GameLoopOrchestrator` и применяется уровнем после new/load; одинаковый save восстанавливает декоративную композицию без сериализации тысяч transform.
- Presentation имеет scalable quality tiers и не определяет gameplay truth.

## 12. Audio pipeline

```text
Gameplay events ───────────────→ Noise system / creature hearing
       │
       └→ Audio cues → AudioDirector → buses/snapshots → speakers
World/biome/time → ambience zones ────┘
Effect snapshot → perception layers ──┘
```

- `AudioProfile` задаёт ambience layers, transitions, reverb и perception processing.
- 3D-звуки создаются локальными emitters и имеют ограничение voice count/pooling.
- `Area3D`-зоны задают ambience/reverb transitions; смена не происходит из player script.
- Критичные cues помечаются семантическим приоритетом, чтобы Director мог приглушить музыку/ambience.
- Music, Voice, UI, PlayerFoley, Ambience, Creatures, Interactions и Perception разведены по шинам.
- Громкость слышимого аудио не используется AI. `NoiseEmitterComponent` создаёт отдельное gameplay-событие с радиусом, тегом и источником.
- Субтитры/визуальные sound cues подписываются на семантическое событие, а не распознают проигрываемый файл.

## 13. Definition of done для новой механики

Механика считается готовой, когда:

- её domain-правила не зависят от конкретной сцены;
- контент добавляется без редактирования центрального условного оператора;
- обязательные зависимости видны через typed exports или setup method;
- неверная конфигурация даёт editor warning/validation error;
- есть минимум один позитивный и один негативный тест;
- сохранение/загрузка состояния определены;
- VFX можно ослабить или отключить без поломки gameplay;
- debug overlay показывает её ключевое состояние.

## 14. Архитектурные запреты

- Не добавлять autoload ради удобного доступа из любого места.
- Не использовать один EventBus для всех событий проекта.
- Не хранить runtime-состояние в общих `.tres` definitions.
- Не давать UI, shader или audio управлять gameplay truth.
- Не создавать глубокие иерархии наследования для предметов и растений.
- Не обращаться к `/root/...` из feature-кода.
- Не оптимизировать без profiler, но задавать performance budget заранее.
- Не строить систему, пока нет одного сквозного игрового примера её применения.

## 15. Performance budget vertical slice

Начальные цели, уточняемые после выбора минимального ПК:

- стабильные 60 FPS при 1080p;
- CPU frame ≤ 8 ms, GPU frame ≤ 12 ms в типовой лесной сцене;
- отсутствие регулярных allocations/заметных spikes в gameplay loop;
- ограниченный радиус динамических теней;
- MultiMeshInstance3D для массовой повторяющейся растительности;
- LOD/visibility ranges и occlusion culling для лесных кластеров;
- collision только там, где она влияет на перемещение/взаимодействие;
- визуальные пресеты управляют fog, shadows, internal resolution и post effects независимо.

## 16. World chunks and portals

- Авторская зона собирается из самостоятельных chunk-сцен.
- Chunk содержит свою статическую геометрию, локальный свет, props и точки интереса, но не владеет player/session.
- `SimplePortal` сейчас обеспечивает проверяемый переход между убежищем и поляной внутри vertical slice.
- При разделении зон на отдельные PackedScene тот же portal contract будет передавать `scene_id + spawn_id` в `GameFlowOrchestrator`; gameplay-код двери не должен загружать сцену самостоятельно.

`SimplePortal` теперь считается legacy-контрактом прежнего vertical slice и при запуске реальной сессии отключается. Новая игра начинается непосредственно в Яви на terrain stream. `RoadLaboratoryOrchestrator` отделяет переносные cooking-узлы от старой геометрии комнаты, управляет первым ритуалом, метаморфозой, повторным проявлением около игрока и собственным persistence payload. Поэтому лаборатория является состоянием текущей экспедиции, а не отдельной комнатой или точкой телепорта.

Первый ритуал представлен обычным `InteractableComponent` на физическом cairn. После открытия действие `road_laboratory` (`L`) только просит orchestrator проявить/убрать лагерь; ввод не знает ни о cooking nodes, ни о сохранении. Радиус лагеря публикует завершённое событие возвращения для objective loop.
- Постоянные изменения chunk сохраняются стабильными object IDs, а не NodePath.

## 17. World content progression

`BiomeContentPack` является data-driven контрактом мира: ecology/geology, авторские `WorldMysteryDefinition`, локальные ingredient IDs, переходный recipe ID и следующий story phase. `WorldProgressionOrchestrator` соединяет эти definitions с процедурным terrain, журналом рецептов, cooking result и persistence, не создавая зависимость ресурсов от UI.

Каждый сгенерированный landmark получает `WorldMysteryPOI` с обычным `InteractableComponent` и соседний `GeneratedBiomeIngredient`. Scatter заранее резервирует вокруг landmark свободную композиционную зону, а heightfield формирует локальную поляну; POI поэтому является художественным ограничением генерации, а не объектом, случайно брошенным поверх леса.

Положение landmark определяется не независимым шансом каждого чанка. `ExpeditionTerrain` строит seed-зависимую извилистую долину маршрута, оставляет узкий проходимый просвет и размещает сюжетные возможности с cadence из `BiomeContentPack.landmark_period` на одной из её кромок. Seed меняет изгиб, сторону и точную позицию, но не может создать бесконечный участок без следующей возможности продвижения.

Успешно приготовленная формула записывается как освоенная, но переход происходит только после употребления полученного consumable. Acute effect channels управляют телесной ценой и presentation, а `story_phase_id` сохраняет самый глубокий подтверждённый слой после окончания эффекта и загрузки сохранения.

`WorldMysteryDefinition` также хранит правило локального события, инструкцию, последствие ошибки, длительность, давление и аудиовизуальный почерк. `WorldMysteryPOI` исполняет этот контракт в пространстве, а `WorldProgressionOrchestrator` переводит его состояние в нарратив, цель и persistence. Локальный ингредиент регистрируется как reveal-награда и недоступен до разрешения события. Поэтому поведение встречи не находится в terrain generator, а HUD не содержит условий отдельных биомов.

## 18. Biome hazard pipeline

`WorldPhaseDefinition.hazard_profile` ссылается на `BiomeHazardDefinition`: цикл calm/warning/active, правило counterplay, скорость давления, тексты, палитра, visual family и звуковая высота. `BiomeHazardOrchestrator` единолично исполняет цикл, оценивает движение игрока, хранит последнюю безопасную позицию и публикует унифицированные сигналы HUD. World-space частицы, procedural 3D tone и screen global являются presentation-потребителями и не определяют исход угрозы.

`RoadLaboratoryOrchestrator` публикует только функцию пространственной защиты; он не знает текущий биом и не управляет hazard state. Сохранение хранит давление, стадию цикла и безопасную точку. Старый save без этих полей мигрирует на уже восстановленную позицию игрока.

## 19. Art-directed ecology compositions

`BiomeContentPack` разделяет три масштаба наполнения: массовые семейства растительности/геологии, крупную `composition_family` и сюжетную `poi_family`. Поэтому биом не собирается одной россыпью случайных примитивов.

`ExpeditionTerrain` размещает экологические композиции в контролируемом ритме между сюжетными POI. Деревья, камни и подлесок используют разные шумовые поля и образуют рощи, просветы и каменные пояса. Композиции формируют запоминаемый силуэт: бурелом, грибной питомник, след миграции, ледяной орган, выжженный круг, зеркальный остров, корневой неф или парящий конкорданс.

`BiomeVisualProfile` хранит не только небо и туман, но и цвет, энергию и направление ключевого света. Кислотное свечение остаётся акцентом; форму читают направленный свет и тени.

Движение массовой экологии исполняется одним GPU shader, но амплитуда и скорость принадлежат `BiomeContentPack`. Генератор выбирает данные, presentation shader деформирует вершины, а gameplay никогда не использует визуальное качание как физическое состояние растения.

## 20. UI ownership and developer QA

Gameplay HUD владеет взаимоисключающими полевыми overlay: inventory, journal и inspection. Открытый overlay освобождает мышь и выключает `InteractionOrchestrator`; Escape сначала закрывает верхний overlay и только затем передаётся pause flow. Главное меню аналогично блокирует фоновые кнопки под settings modal.

`WorldPhaseDeveloperPanel` является только QA-адаптером над публичными контрактами phase, progression, hazard, laboratory, terrain, clock и persistence. Он не меняет их внутренние поля напрямую. Телепорты используют terrain height provider, laboratory test hooks проходят тот же lifecycle, а hazard reset публикует обычные state/exposure signals.

## 21. Fauna and narrative cast

`CreatureArchetypeDefinition` хранит экологическую и производственную character sheet: допустимые world phases, body plan, редкость и размер группы, сенсорные дистанции, природную основу, силуэт, палитру, обязательные анимации, поведенческие tell и изменение восприятия между слоями. `NPCArchetypeDefinition` отдельно хранит драматическую роль, persistence encounter, одежду по слоям, снаряжение, выражения, анимации, публичную цель, скрытую потребность и секрет. Оба типа обнаруживаются обычным `ContentDB`; центральная таблица персонажей в коде не требуется.

`BiomePopulationOrchestrator` читает только загруженные terrain chunks и текущий `WorldPhaseOrchestrator`. Seed и координата детерминированно выбирают совместимый вид и группу. Уход чанка освобождает популяцию, смена слоя переселяет активное окно, а developer hooks позволяют повторить раскладку и переключить плотность. `BiomeCreatureActor` является процедурным low-poly runtime-прототипом общего locomotion-контракта; финальные скелетные сцены заменят визуальную сборку, сохранив state machine и данные character sheet.

NPC не проходят через общий scatter. Их встречами владеет будущий authored encounter director, потому что сюжетный персонаж требует условий, проверки подлинности и последствий, а не одного spawn weight.

## 22. First-person body and locomotion

`FirstPersonController` остаётся единственным владельцем физического состояния: wish direction, аналоговая сила ввода, ускорение/торможение, forward-only sprint, crouch capsule, buffered jump, coyote time, floor snap, slope limit, low-step traversal, gravity, landing impulse и ограниченный push динамических тел. Камера, viewmodel и звук читают итоговую скорость и приземление, но не вычисляют движение самостоятельно.

`PlayerAvatarAnimator` является заменяемым presentation-адаптером. Он переводит физические состояния `idle/walk/run/jump/work` в клипы импортированного CC0-скелета и настраивает world body как shadow-only, чтобы голова модели не пересекала first-person camera. Смена FBX или переход на собственную модель не затрагивает контроллер. Отдельный camera-space viewmodel отвечает за инструменты и руки; его дыхание, инерция взгляда, походка, crouch/sprint lowering и landing response происходят из тех же locomotion channels.

Низкая ступень проверяется тремя физическими запросами: препятствие на текущей высоте, свободный объём над ним и наличие поверхности для приземления. Поэтому контроллер не телепортируется вверх по стене и не зависает на небольшом камне. Толчок `RigidBody3D` использует сохранённую скорость до `move_and_slide`, поскольку итоговая velocity уже обнулена контактом.
