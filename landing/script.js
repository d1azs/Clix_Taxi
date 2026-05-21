/* ═══════════════════════════════════════════════════════
   CLIX TAXI — Landing Page Scripts
   ═══════════════════════════════════════════════════════ */

// ── Localization Data ──
const translations = {
  uk: {
    // Role switcher
    role_passenger: "Пасажир",
    role_driver: "Водій",

    // Driver flow
    header_cta: "Завантажити",
    hero_badge: "Доступно в Празі",
    hero_title_1: "Більше поїздок з аеропорту.",
    hero_title_2: "Менше хаосу в Telegram.",
    hero_subtitle: "Clix Taxi — це прямі замовлення з аеропорту Вацлава Гавела без диспетчерів, черг та Telegram\u2011чатів. Один тап — і ти вже в дорозі.",
    store_label_apple: "Завантажити з",
    store_label_google: "Завантажити з",
    hero_stat_1: "менше простою",
    hero_stat_2: "прихованих комісій",
    hero_stat_3: "для прийняття замовлення",
    app_status: "Онлайн",
    order_label: "Нове замовлення",
    order_pickup: "Letiště Václava Havla",
    order_dropoff: "Praha 1, Staroměstské nám.",
    order_accept: "Прийняти ✓",
    notif_title: "Замовлення прийнято",
    notif_text: "Навігація запущена автоматично",
    problem_label: "Знайома ситуація?",
    problem_title: "Чому ти досі втрачаєш гроші під час простою?",
    problem_subtitle: "Стара система працює проти тебе. Ось що відбувається щодня.",
    problem_1_title: "Хаос у Telegram-чатах",
    problem_1_desc: "Сотні повідомлень на хвилину. Замовлення губиться в потоці спаму, мемів та суперечок водіїв.",
    problem_2_title: "Замовлення «зливають» своїм",
    problem_2_desc: "Диспетчер передає вигідні поїздки тим, хто платить більше або є «в колі». Ти стоїш у черзі годинами.",
    problem_3_title: "Високий % диспетчерам",
    problem_3_desc: "Частина твого заробітку йде посереднику, який просто переслав повідомлення в чат.",
    problem_4_title: "Порожні пробіги",
    problem_4_desc: "Їдеш в аеропорт на вдачу, але замовлення вже забрали. Час і пальне — даремно.",
    tg_chat_name: "🚕 Taxi Letiště Praha",
    tg_chat_count: "847 учасників",
    tg_msg_1: "Летиште → Прага 1, 2 особи, 890 кч. Хто візьме?",
    tg_msg_2: "Я!",
    tg_msg_3: "Я теж! Я ближче стою!",
    tg_msg_4: "Уже віддав Сергію. Наступного чекайте.",
    tg_msg_5: "Знову?! Я тут 2 години стою!",
    solution_label: "Рішення",
    solution_title_text: "Clix Taxi — твій",
    solution_title_gradient: "персональний диспетчер",
    solution_subtitle: "Прозоро, швидко, без посередників. Один додаток замість десяти Telegram-чатів.",
    comp_old_label: "❌ Як було",
    comp_old_1: "Чекаєш повідомлення в чаті",
    comp_old_2: "Пишеш «Я!» серед 20 водіїв",
    comp_old_3: "Чекаєш рішення диспетчера",
    comp_old_4: "Часто — відмова. Починай спочатку",
    comp_new_label: "✓ Як стало з Clix Taxi",
    comp_new_1: "Отримуєш push-сповіщення",
    comp_new_2: "Натискаєш «Прийняти» — 1 тап",
    comp_new_3: "Навігація запускається автоматично",
    sol_item_1_title: "Прямі замовлення",
    sol_item_1_desc: "Жоден диспетчер не вирішує, хто отримає поїздку",
    sol_item_2_title: "Прозора ціна",
    sol_item_2_desc: "Бачиш маршрут та повну вартість до прийняття",
    sol_item_3_title: "Миттєва реакція",
    sol_item_3_desc: "1 тап — замовлення твоє. Без конкуренції в чатах",
    features_label: "Можливості",
    features_title: "Все, що потрібно водію",
    features_subtitle: "Кожна фіча створена, щоб ти заробляв більше і витрачав менше часу на очікування.",
    feature_1_title: "Повна прозорість",
    feature_1_desc: "Бачиш кінцеву ціну, маршрут та кількість пасажирів ще до прийняття замовлення. Жодних сюрпризів.",
    feature_2_title: "Справедлива черга",
    feature_2_desc: "Алгоритм, а не людина-диспетчер. Замовлення розподіляються чесно на основі вашої позиції та рейтингу.",
    feature_3_title: "Нульові приховані комісії",
    feature_3_desc: "Ніяких прихованих відсотків. Ви знаєте точну суму, яку отримуєте за кожну поїздку.",
    feature_4_title: "Інтерактивна мапа",
    feature_4_desc: "Вбудована навігація з оптимальними маршрутами до аеропорту та назад. Все в одному інтерфейсі.",
    how_label: "Як це працює",
    how_title: "Почни за 3 прості кроки",
    how_subtitle: "Жодних довгих анкет чи верифікацій на тижні. Старт — за один день.",
    step_1_title: "Завантаж додаток",
    step_1_desc: "Безкоштовно завантаж Clix Taxi з App Store або Google Play та створи акаунт за 2 хвилини.",
    step_2_title: "Пройди верифікацію",
    step_2_desc: "Завантаж документи та фото авто. Швидка перевірка — і ти готовий приймати замовлення.",
    step_3_title: "Отримуй замовлення",
    step_3_desc: "Push-сповіщення з деталями поїздки. Один тап для прийняття — навігація стартує автоматично.",
    trust_label: "Відгуки",
    trust_title: "Водії, які вже працюють по-новому",
    trust_subtitle: "Реальні відгуки водіїв, які перейшли з Telegram-чатів на Clix Taxi.",
    review_1_text: "«Більше не сперечаюся в чатах за клієнта. Додаток сам дає найближчі поїздки. За перший тиждень заробив на 30% більше.»",
    review_1_name: "Андрій К.",
    review_1_role: "Водій, 3 роки в Празі",
    review_2_text: "«Нарешті чесна система. Не треба нікому «заносити», щоб отримати нормальне замовлення. Все прозоро і по-чесному.»",
    review_2_name: "Олександр М.",
    review_2_role: "Водій Uber/Bolt, 5 років",
    review_3_text: "«Раніше витрачав 40% часу на очікування в чатах. Тепер отримую push і одразу їду. Економлю і час, і пальне.»",
    review_3_name: "Вадим Р.",
    review_3_role: "Приватний перевізник",
    stat_1: "Активних водіїв",
    stat_2: "Менше простою",
    stat_3: "Середній рейтинг",
    stat_4: "Захист даних",
    download_label: "Завантажити додаток",
    download_title_text: "Готовий змінити",
    download_title_gradient: "правила гри",
    download_subtitle: "Почни заробляти з Clix Taxi вже сьогодні. Безкоштовно. Без прихованих умов.",
    qr_title: "Скануй QR-код",
    qr_desc: "Наведи камеру телефону для миттєвого завантаження додатку",
    footer_rights: "Усі права захищені.",
    footer_privacy: "Конфіденційність",
    footer_terms: "Умови використання",
    footer_contact: "Контакти",
    sticky_cta: "📲 Завантажити Clix Taxi",

    // Passenger flow
    p_hero_badge: "Доступно в Празі",
    p_hero_title_1: "Надійне таксі з аеропорту Праги",
    p_hero_title_2: "без черг та переплат.",
    p_hero_subtitle: "Фіксована ціна ще до поїздки. Водій чекає на виході з терміналу. Жодних сюрпризів — тільки комфорт.",
    p_hero_stat_1: "середній час подачі",
    p_hero_stat_2: "прихованих доплат",
    p_hero_stat_3: "рейтинг сервісу",
    p_app_status: "Пошук авто...",
    p_ride_label: "Ваша поїздка",
    p_ride_from: "Letiště Václava Havla",
    p_ride_to: "Praha 1, Hotel Astoria",
    p_ride_order: "Замовити 🚕",
    p_price_label: "Фіксована ціна",
    p_benefits_label: "Чому Clix?",
    p_benefits_title: "Комфорт від літака до готелю",
    p_benefits_subtitle: "Забудьте про черги, торги та мовні бар'єри. Все вже вирішено.",
    p_benefit_1_title: "Фіксована ціна",
    p_benefit_1_desc: "Ніяких сюрпризів та націнок за затори. Ви знаєте точну суму ще до поїздки — і не заплатите більше.",
    p_benefit_2_title: "Авто при виході з терміналу",
    p_benefit_2_desc: "Водій вже чекає. Не потрібно шукати паркінг, стояти в черзі до таксі або телефонувати.",
    p_benefit_3_title: "Без мовного бар'єру",
    p_benefit_3_desc: "Додаток працює українською, чеською та англійською. Маршрут задається автоматично — нічого пояснювати.",
    p_how_label: "Як це працює",
    p_how_title: "3 кроки до комфортної поїздки",
    p_how_subtitle: "Мінімум дій — максимум зручності. Від замовлення до поїздки за хвилину.",
    p_step_1_title: "Вкажіть маршрут",
    p_step_1_desc: "Оберіть точку посадки та призначення — або просто вкажіть адресу готелю.",
    p_step_2_title: "Отримайте та підтвердіть ціну",
    p_step_2_desc: "Побачте фіксовану вартість поїздки до підтвердження. Без сюрпризів і прихованих доплат.",
    p_step_3_title: "Сідайте в авто",
    p_step_3_desc: "Водій вже чекає при виході з терміналу. Їдьте з комфортом до місця призначення.",
    p_features_label: "Можливості",
    p_features_title: "Все для ідеальної поїздки",
    p_features_subtitle: "Продуктові можливості, які роблять кожну поїздку приємною.",
    p_feature_1_title: "Трекінг авто на мапі",
    p_feature_1_desc: "Бачите, де саме знаходиться ваш водій і коли він прибуде. Відстежуйте маршрут у реальному часі.",
    p_feature_2_title: "Оплата карткою або готівкою",
    p_feature_2_desc: "Обирайте зручний спосіб оплати. Картка, Apple Pay або готівка — як вам комфортніше.",
    p_feature_3_title: "Електронні чеки",
    p_feature_3_desc: "Отримуйте підтвердження оплати на email. Ідеально для відряджень та звітності.",
    p_feature_4_title: "Історія поїздок",
    p_feature_4_desc: "Усі ваші подорожі зберігаються. Повторіть маршрут одним натисканням або перегляньте деталі.",
    p_trust_label: "Безпека та довіра",
    p_trust_title: "Ваша безпека — наш пріоритет",
    p_trust_subtitle: "Кожен водій перевірений. Кожне авто — безпечне.",
    p_safety_1: "Усі авто не старші 7 років",
    p_safety_2: "Лише перевірені та ліцензовані водії",
    p_safety_3: "Страхування кожної поїздки",
    p_safety_4: "Підтримка 24/7 у додатку",
    p_review_1_text: "«Прилетіли вночі та хвилювались, чи буде таксі. Водій вже чекав біля виходу. Ціна — як домовлялись. Рекомендую!»",
    p_review_1_name: "Марина Т.",
    p_review_1_role: "Туристка з Києва",
    p_review_2_text: "«Використовую під час відряджень. Електронний чек приходить одразу — бухгалтерія задоволена. Дуже зручно.»",
    p_review_2_name: "Дмитро К.",
    p_review_2_role: "Менеджер, часто подорожує",
    p_review_3_text: "«Нарешті сервіс, де не треба торгуватись з таксистом. Фіксована ціна, чисте авто, ввічливий водій. Тепер тільки Clix.»",
    p_review_3_name: "Олена С.",
    p_review_3_role: "Подорожує з сім'єю",
    p_download_label: "Завантажити додаток",
    p_download_title: "Збережіть Clix Taxi перед польотом у Прагу",
    p_download_subtitle: "Замовте таксі заздалегідь або одразу після приземлення. Безкоштовно та без реєстрації.",
    p_qr_title: "Скануй QR-код",
    p_qr_desc: "Наведи камеру телефону для миттєвого завантаження",
  },

  cs: {
    // Role switcher
    role_passenger: "Cestující",
    role_driver: "Řidič",

    // Driver flow
    header_cta: "Stáhnout",
    hero_badge: "Dostupné v Praze",
    hero_title_1: "Více jízd z letiště.",
    hero_title_2: "Méně chaosu v Telegramu.",
    hero_subtitle: "Clix Taxi — přímé objednávky z letiště Václava Havla bez dispečerů, front a Telegram chatů. Jedno klepnutí — a jsi na cestě.",
    store_label_apple: "Stáhnout z",
    store_label_google: "Stáhnout z",
    hero_stat_1: "méně prostojů",
    hero_stat_2: "skrytých provizí",
    hero_stat_3: "pro přijetí objednávky",
    app_status: "Online",
    order_label: "Nová objednávka",
    order_pickup: "Letiště Václava Havla",
    order_dropoff: "Praha 1, Staroměstské nám.",
    order_accept: "Přijmout ✓",
    notif_title: "Objednávka přijata",
    notif_text: "Navigace spuštěna automaticky",
    problem_label: "Známá situace?",
    problem_title: "Proč stále ztrácíte peníze během prostojů?",
    problem_subtitle: "Starý systém pracuje proti vám. Toto se děje každý den.",
    problem_1_title: "Chaos v Telegram chatech",
    problem_1_desc: "Stovky zpráv za minutu. Objednávka se ztrácí v záplavě spamu a hádek řidičů.",
    problem_2_title: "Objednávky jdou «svým»",
    problem_2_desc: "Dispečer předává výhodné jízdy těm, kdo platí víc nebo jsou «v kruhu». Vy čekáte hodiny.",
    problem_3_title: "Vysoké % dispečerům",
    problem_3_desc: "Část vašeho výdělku jde prostředníkovi, který jen přeposlal zprávu do chatu.",
    problem_4_title: "Prázdné jízdy",
    problem_4_desc: "Jedete na letiště na štěstí, ale objednávku už vzali. Čas a benzín — zbytečně.",
    tg_chat_name: "🚕 Taxi Letiště Praha",
    tg_chat_count: "847 členů",
    tg_msg_1: "Letiště → Praha 1, 2 osoby, 890 Kč. Kdo vezme?",
    tg_msg_2: "Já!",
    tg_msg_3: "Já taky! Stojím blíž!",
    tg_msg_4: "Už dal Sergejovi. Na dalšího čekejte.",
    tg_msg_5: "Zase?! Stojím tu 2 hodiny!",
    solution_label: "Řešení",
    solution_title_text: "Clix Taxi — váš",
    solution_title_gradient: "osobní dispečer",
    solution_subtitle: "Transparentně, rychle, bez prostředníků. Jedna aplikace místo deseti Telegram chatů.",
    comp_old_label: "❌ Jak to bylo",
    comp_old_1: "Čekáte na zprávu v chatu",
    comp_old_2: "Píšete «Já!» mezi 20 řidiči",
    comp_old_3: "Čekáte na rozhodnutí dispečera",
    comp_old_4: "Často — odmítnutí. Začínáte znovu",
    comp_new_label: "✓ Jak je to s Clix Taxi",
    comp_new_1: "Dostanete push notifikaci",
    comp_new_2: "Klepnete «Přijmout» — 1 tap",
    comp_new_3: "Navigace se spustí automaticky",
    sol_item_1_title: "Přímé objednávky",
    sol_item_1_desc: "Žádný dispečer nerozhoduje, kdo dostane jízdu",
    sol_item_2_title: "Transparentní cena",
    sol_item_2_desc: "Vidíte trasu a plnou cenu před přijetím",
    sol_item_3_title: "Okamžitá reakce",
    sol_item_3_desc: "1 tap — objednávka je vaše. Bez konkurence v chatech",
    features_label: "Funkce",
    features_title: "Vše, co řidič potřebuje",
    features_subtitle: "Každá funkce je vytvořena tak, abyste vydělali více a čekali méně.",
    feature_1_title: "Plná transparentnost",
    feature_1_desc: "Vidíte konečnou cenu, trasu a počet cestujících ještě před přijetím objednávky.",
    feature_2_title: "Spravedlivá fronta",
    feature_2_desc: "Algoritmus, ne člověk-dispečer. Objednávky se rozdělují férově na základě pozice a hodnocení.",
    feature_3_title: "Nulové skryté provize",
    feature_3_desc: "Žádná skrytá procenta. Víte přesně, kolik za každou jízdu dostanete.",
    feature_4_title: "Interaktivní mapa",
    feature_4_desc: "Vestavěná navigace s optimálními trasami na letiště a zpět. Vše v jednom rozhraní.",
    how_label: "Jak to funguje",
    how_title: "Začněte ve 3 snadných krocích",
    how_subtitle: "Žádné dlouhé dotazníky ani týdenní verifikace. Start — za jeden den.",
    step_1_title: "Stáhněte aplikaci",
    step_1_desc: "Zdarma stáhněte Clix Taxi z App Store nebo Google Play a vytvořte si účet za 2 minuty.",
    step_2_title: "Projděte verifikací",
    step_2_desc: "Nahrajte dokumenty a foto vozu. Rychlá kontrola — a jste připraveni přijímat objednávky.",
    step_3_title: "Přijímejte objednávky",
    step_3_desc: "Push notifikace s detaily jízdy. Jedno klepnutí pro přijetí — navigace se spustí automaticky.",
    trust_label: "Recenze",
    trust_title: "Řidiči, kteří už pracují po novém",
    trust_subtitle: "Skutečné recenze řidičů, kteří přešli z Telegram chatů na Clix Taxi.",
    review_1_text: "«Už se nehádám v chatech o klienta. Aplikace sama přidělí nejbližší jízdy. Za první týden jsem vydělal o 30 % víc.»",
    review_1_name: "Andrij K.",
    review_1_role: "Řidič, 3 roky v Praze",
    review_2_text: "«Konečně férový systém. Nemusíte nikomu «přispívat», abyste dostali normální objednávku. Vše transparentně.»",
    review_2_name: "Oleksandr M.",
    review_2_role: "Řidič Uber/Bolt, 5 let",
    review_3_text: "«Dříve jsem trávil 40 % času čekáním v chatech. Teď dostanu push a hned jedu. Šetřím čas i benzín.»",
    review_3_name: "Vadim R.",
    review_3_role: "Soukromý přepravce",
    stat_1: "Aktivních řidičů",
    stat_2: "Méně prostojů",
    stat_3: "Průměrné hodnocení",
    stat_4: "Ochrana dat",
    download_label: "Stáhnout aplikaci",
    download_title_text: "Připraveni změnit",
    download_title_gradient: "pravidla hry",
    download_subtitle: "Začněte vydělávat s Clix Taxi už dnes. Zdarma. Bez skrytých podmínek.",
    qr_title: "Naskenujte QR kód",
    qr_desc: "Namiřte fotoaparát telefonu pro okamžité stažení aplikace",
    footer_rights: "Všechna práva vyhrazena.",
    footer_privacy: "Ochrana soukromí",
    footer_terms: "Podmínky použití",
    footer_contact: "Kontakty",
    sticky_cta: "📲 Stáhnout Clix Taxi",

    // Passenger flow
    p_hero_badge: "Dostupné v Praze",
    p_hero_title_1: "Spolehlivé taxi z letiště Praha",
    p_hero_title_2: "bez front a přeplatků.",
    p_hero_subtitle: "Pevná cena ještě před jízdou. Řidič čeká u východu z terminálu. Žádná překvapení — jen komfort.",
    p_hero_stat_1: "průměrná doba přistavení",
    p_hero_stat_2: "skrytých příplatků",
    p_hero_stat_3: "hodnocení služby",
    p_app_status: "Hledání vozu...",
    p_ride_label: "Vaše jízda",
    p_ride_from: "Letiště Václava Havla",
    p_ride_to: "Praha 1, Hotel Astoria",
    p_ride_order: "Objednat 🚕",
    p_price_label: "Pevná cena",
    p_benefits_label: "Proč Clix?",
    p_benefits_title: "Komfort od letadla do hotelu",
    p_benefits_subtitle: "Zapomeňte na fronty, smlouvání a jazykovou bariéru. Vše je vyřešeno.",
    p_benefit_1_title: "Pevná cena",
    p_benefit_1_desc: "Žádná překvapení ani příplatky za zácpy. Znáte přesnou částku ještě před jízdou — a nezaplatíte víc.",
    p_benefit_2_title: "Vůz u východu z terminálu",
    p_benefit_2_desc: "Řidič už čeká. Nemusíte hledat parkoviště, stát ve frontě nebo volat.",
    p_benefit_3_title: "Bez jazykové bariéry",
    p_benefit_3_desc: "Aplikace funguje česky, ukrajinsky i anglicky. Trasa se nastaví automaticky — nic nemusíte vysvětlovat.",
    p_how_label: "Jak to funguje",
    p_how_title: "3 kroky ke komfortní jízdě",
    p_how_subtitle: "Minimum úkonů — maximum pohodlí. Od objednávky k jízdě za minutu.",
    p_step_1_title: "Zadejte trasu",
    p_step_1_desc: "Vyberte místo nástupu a cíl — nebo jednoduše zadejte adresu hotelu.",
    p_step_2_title: "Potvrďte cenu",
    p_step_2_desc: "Uvidíte pevnou cenu jízdy před potvrzením. Bez překvapení a skrytých příplatků.",
    p_step_3_title: "Nastupte do vozu",
    p_step_3_desc: "Řidič už čeká u východu z terminálu. Jeďte s komfortem na místo určení.",
    p_features_label: "Funkce",
    p_features_title: "Vše pro ideální jízdu",
    p_features_subtitle: "Funkce, které dělají každou jízdu příjemnou.",
    p_feature_1_title: "Sledování vozu na mapě",
    p_feature_1_desc: "Vidíte, kde přesně se váš řidič nachází a kdy dorazí. Sledujte trasu v reálném čase.",
    p_feature_2_title: "Platba kartou nebo hotově",
    p_feature_2_desc: "Vyberte si pohodlný způsob platby. Karta, Apple Pay nebo hotovost — jak vám vyhovuje.",
    p_feature_3_title: "Elektronické účtenky",
    p_feature_3_desc: "Dostanete potvrzení platby na e-mail. Ideální pro služební cesty a vyúčtování.",
    p_feature_4_title: "Historie jízd",
    p_feature_4_desc: "Všechny vaše cesty jsou uloženy. Zopakujte trasu jedním klepnutím.",
    p_trust_label: "Bezpečnost a důvěra",
    p_trust_title: "Vaše bezpečnost je naší prioritou",
    p_trust_subtitle: "Každý řidič je ověřen. Každé vozidlo je bezpečné.",
    p_safety_1: "Všechna vozidla mladší 7 let",
    p_safety_2: "Pouze ověření a licencovaní řidiči",
    p_safety_3: "Pojištění každé jízdy",
    p_safety_4: "Podpora 24/7 v aplikaci",
    p_review_1_text: "«Přiletěli jsme v noci a měli obavy. Řidič už čekal u východu. Cena — jak bylo domluveno. Doporučuji!»",
    p_review_1_name: "Marina T.",
    p_review_1_role: "Turistka z Kyjeva",
    p_review_2_text: "«Používám při služebních cestách. Elektronická účtenka přijde hned — účetní je spokojená.»",
    p_review_2_name: "Dmytro K.",
    p_review_2_role: "Manažer, často cestuje",
    p_review_3_text: "«Konečně služba, kde se nemusíte dohadovat s taxikářem. Pevná cena, čisté auto, zdvořilý řidič.»",
    p_review_3_name: "Olena S.",
    p_review_3_role: "Cestuje s rodinou",
    p_download_label: "Stáhnout aplikaci",
    p_download_title: "Uložte si Clix Taxi před letem do Prahy",
    p_download_subtitle: "Objednejte si taxi předem nebo hned po přistání. Zdarma a bez registrace.",
    p_qr_title: "Naskenujte QR kód",
    p_qr_desc: "Namiřte fotoaparát pro okamžité stažení",
  },

  en: {
    // Role switcher
    role_passenger: "Passenger",
    role_driver: "Driver",

    // Driver flow
    header_cta: "Download",
    hero_badge: "Available in Prague",
    hero_title_1: "More airport rides.",
    hero_title_2: "Less Telegram chaos.",
    hero_subtitle: "Clix Taxi — direct orders from Václav Havel Airport without dispatchers, queues or Telegram chats. One tap — and you're on the road.",
    store_label_apple: "Download on the",
    store_label_google: "Get it on",
    hero_stat_1: "less downtime",
    hero_stat_2: "hidden fees",
    hero_stat_3: "to accept an order",
    app_status: "Online",
    order_label: "New order",
    order_pickup: "Václav Havel Airport",
    order_dropoff: "Prague 1, Old Town Square",
    order_accept: "Accept ✓",
    notif_title: "Order accepted",
    notif_text: "Navigation started automatically",
    problem_label: "Sound familiar?",
    problem_title: "Why are you still losing money during downtime?",
    problem_subtitle: "The old system works against you. Here's what happens every day.",
    problem_1_title: "Telegram chat chaos",
    problem_1_desc: "Hundreds of messages per minute. Orders get lost in a flood of spam, memes, and driver arguments.",
    problem_2_title: "Orders go to «insiders»",
    problem_2_desc: "Dispatchers give profitable rides to those who pay more or are «in the circle». You wait for hours.",
    problem_3_title: "High dispatcher fees",
    problem_3_desc: "Part of your earnings goes to a middleman who just forwarded a message to a chat.",
    problem_4_title: "Empty runs",
    problem_4_desc: "You drive to the airport hoping for a ride, but it's already taken. Time and fuel — wasted.",
    tg_chat_name: "🚕 Taxi Letiště Praha",
    tg_chat_count: "847 members",
    tg_msg_1: "Airport → Prague 1, 2 pax, 890 CZK. Who takes it?",
    tg_msg_2: "Me!",
    tg_msg_3: "Me too! I'm closer!",
    tg_msg_4: "Already gave it to Sergiy. Wait for the next one.",
    tg_msg_5: "Again?! I've been here for 2 hours!",
    solution_label: "Solution",
    solution_title_text: "Clix Taxi — your",
    solution_title_gradient: "personal dispatcher",
    solution_subtitle: "Transparent, fast, no middlemen. One app instead of ten Telegram chats.",
    comp_old_label: "❌ The old way",
    comp_old_1: "Wait for a message in the chat",
    comp_old_2: "Type «Me!» among 20 drivers",
    comp_old_3: "Wait for dispatcher's decision",
    comp_old_4: "Often — rejected. Start over",
    comp_new_label: "✓ The Clix Taxi way",
    comp_new_1: "Receive a push notification",
    comp_new_2: "Tap «Accept» — 1 tap",
    comp_new_3: "Navigation starts automatically",
    sol_item_1_title: "Direct orders",
    sol_item_1_desc: "No dispatcher decides who gets the ride",
    sol_item_2_title: "Transparent pricing",
    sol_item_2_desc: "See the route and full fare before accepting",
    sol_item_3_title: "Instant response",
    sol_item_3_desc: "1 tap — the order is yours. No chat competition",
    features_label: "Features",
    features_title: "Everything a driver needs",
    features_subtitle: "Every feature is built so you earn more and wait less.",
    feature_1_title: "Full transparency",
    feature_1_desc: "See the final price, route, and passenger count before accepting any order. No surprises.",
    feature_2_title: "Fair queue",
    feature_2_desc: "Algorithm, not a human dispatcher. Orders are distributed fairly based on your position and rating.",
    feature_3_title: "Zero hidden fees",
    feature_3_desc: "No hidden percentages. You know the exact amount you receive for every ride.",
    feature_4_title: "Interactive map",
    feature_4_desc: "Built-in navigation with optimal routes to and from the airport. Everything in one interface.",
    how_label: "How it works",
    how_title: "Get started in 3 easy steps",
    how_subtitle: "No lengthy forms or week-long verifications. Start in one day.",
    step_1_title: "Download the app",
    step_1_desc: "Download Clix Taxi for free from App Store or Google Play and create an account in 2 minutes.",
    step_2_title: "Get verified",
    step_2_desc: "Upload your documents and car photos. Quick check — and you're ready to accept orders.",
    step_3_title: "Receive orders",
    step_3_desc: "Push notifications with ride details. One tap to accept — navigation starts automatically.",
    trust_label: "Reviews",
    trust_title: "Drivers who already work the new way",
    trust_subtitle: "Real reviews from drivers who switched from Telegram chats to Clix Taxi.",
    review_1_text: "\"No more arguing in chats for a client. The app gives the nearest rides automatically. Earned 30% more in the first week.\"",
    review_1_name: "Andriy K.",
    review_1_role: "Driver, 3 years in Prague",
    review_2_text: "\"Finally a fair system. No need to bribe anyone to get a decent order. Everything is transparent and honest.\"",
    review_2_name: "Oleksandr M.",
    review_2_role: "Uber/Bolt driver, 5 years",
    review_3_text: "\"Used to spend 40% of my time waiting in chats. Now I get a push and go immediately. Saving time and fuel.\"",
    review_3_name: "Vadim R.",
    review_3_role: "Private carrier",
    stat_1: "Active drivers",
    stat_2: "Less downtime",
    stat_3: "Average rating",
    stat_4: "Data protection",
    download_label: "Download app",
    download_title_text: "Ready to change",
    download_title_gradient: "the game",
    download_subtitle: "Start earning with Clix Taxi today. Free. No hidden conditions.",
    qr_title: "Scan QR code",
    qr_desc: "Point your camera to instantly download the app",
    footer_rights: "All rights reserved.",
    footer_privacy: "Privacy Policy",
    footer_terms: "Terms of Service",
    footer_contact: "Contact",
    sticky_cta: "📲 Download Clix Taxi",

    // Passenger flow
    p_hero_badge: "Available in Prague",
    p_hero_title_1: "Reliable taxi from Prague Airport",
    p_hero_title_2: "no queues, no overpaying.",
    p_hero_subtitle: "Fixed price before the ride. Driver waits at the terminal exit. No surprises — just comfort.",
    p_hero_stat_1: "average pickup time",
    p_hero_stat_2: "hidden surcharges",
    p_hero_stat_3: "service rating",
    p_app_status: "Finding a car...",
    p_ride_label: "Your ride",
    p_ride_from: "Václav Havel Airport",
    p_ride_to: "Prague 1, Hotel Astoria",
    p_ride_order: "Order 🚕",
    p_price_label: "Fixed price",
    p_benefits_label: "Why Clix?",
    p_benefits_title: "Comfort from plane to hotel",
    p_benefits_subtitle: "Forget about queues, bargaining and language barriers. Everything is sorted.",
    p_benefit_1_title: "Fixed price",
    p_benefit_1_desc: "No surprises or surge pricing in traffic jams. You know the exact amount before the ride — and won't pay more.",
    p_benefit_2_title: "Car at the terminal exit",
    p_benefit_2_desc: "Your driver is already waiting. No need to find parking, stand in a taxi queue or make calls.",
    p_benefit_3_title: "No language barrier",
    p_benefit_3_desc: "The app works in English, Ukrainian and Czech. The route is set automatically — nothing to explain.",
    p_how_label: "How it works",
    p_how_title: "3 steps to a comfortable ride",
    p_how_subtitle: "Minimum actions — maximum comfort. From order to ride in one minute.",
    p_step_1_title: "Enter your route",
    p_step_1_desc: "Select pickup and destination — or simply enter your hotel address.",
    p_step_2_title: "Confirm the price",
    p_step_2_desc: "See the fixed ride cost before confirming. No surprises or hidden charges.",
    p_step_3_title: "Get in the car",
    p_step_3_desc: "Your driver is already waiting at the terminal exit. Ride comfortably to your destination.",
    p_features_label: "Features",
    p_features_title: "Everything for a perfect ride",
    p_features_subtitle: "Product features that make every ride enjoyable.",
    p_feature_1_title: "Car tracking on map",
    p_feature_1_desc: "See exactly where your driver is and when they'll arrive. Track the route in real time.",
    p_feature_2_title: "Pay by card or cash",
    p_feature_2_desc: "Choose your preferred payment method. Card, Apple Pay or cash — whatever suits you.",
    p_feature_3_title: "Digital receipts",
    p_feature_3_desc: "Receive payment confirmation by email. Perfect for business trips and expense reports.",
    p_feature_4_title: "Ride history",
    p_feature_4_desc: "All your trips are saved. Repeat a route with one tap or review details.",
    p_trust_label: "Safety & Trust",
    p_trust_title: "Your safety is our priority",
    p_trust_subtitle: "Every driver is verified. Every car is safe.",
    p_safety_1: "All cars are under 7 years old",
    p_safety_2: "Only verified and licensed drivers",
    p_safety_3: "Insurance on every ride",
    p_safety_4: "24/7 support in the app",
    p_review_1_text: "\"We arrived at night and worried about finding a taxi. The driver was already waiting at the exit. Price — as agreed. Highly recommend!\"",
    p_review_1_name: "Marina T.",
    p_review_1_role: "Tourist from Kyiv",
    p_review_2_text: "\"I use it for business trips. The digital receipt arrives instantly — accounting loves it. Very convenient.\"",
    p_review_2_name: "Dmytro K.",
    p_review_2_role: "Manager, frequent traveler",
    p_review_3_text: "\"Finally a service where you don't have to bargain with the driver. Fixed price, clean car, polite driver. Only Clix from now on.\"",
    p_review_3_name: "Olena S.",
    p_review_3_role: "Travels with family",
    p_download_label: "Download the app",
    p_download_title: "Save Clix Taxi before your flight to Prague",
    p_download_subtitle: "Order a taxi in advance or right after landing. Free and no registration required.",
    p_qr_title: "Scan QR code",
    p_qr_desc: "Point your camera to instantly download the app",
  }
};

const langMeta = {
  uk: { flag: "🇺🇦", code: "UKR", htmlLang: "uk" },
  cs: { flag: "🇨🇿", code: "CZE", htmlLang: "cs" },
  en: { flag: "🇬🇧", code: "ENG", htmlLang: "en" }
};

let currentLang = "uk";
let currentRole = "passenger"; // Default role

// ── Role Switching System ──
function switchRole(role) {
  currentRole = role;
  const driverFlow = document.getElementById("driver-flow");
  const passengerFlow = document.getElementById("passenger-flow");
  const roleSlider = document.getElementById("roleSlider");
  const rolePassenger = document.getElementById("rolePassenger");
  const roleDriver = document.getElementById("roleDriver");
  const body = document.body;

  // Step 1: Fade out current content
  const activeFlow = role === "driver" ? passengerFlow : driverFlow;
  const targetFlow = role === "driver" ? driverFlow : passengerFlow;

  activeFlow.classList.add("flow-hidden");

  // Step 2: After fade out, swap visibility and theme
  setTimeout(() => {
    activeFlow.style.display = "none";
    targetFlow.style.display = "block";

    // Theme switch
    if (role === "passenger") {
      body.classList.add("light-mode");
      document.querySelector('meta[name="theme-color"]').content = "#FFFFFF";
    } else {
      body.classList.remove("light-mode");
      document.querySelector('meta[name="theme-color"]').content = "#0F0A2A";
    }

    // Update slider position
    if (role === "driver") {
      roleSlider.classList.add("driver-active");
    } else {
      roleSlider.classList.remove("driver-active");
    }

    // Update active button states
    rolePassenger.classList.toggle("active", role === "passenger");
    roleDriver.classList.toggle("active", role === "driver");

    // Step 3: Fade in new content
    requestAnimationFrame(() => {
      targetFlow.classList.remove("flow-hidden");
    });

    // Re-observe reveal elements in newly shown flow
    reinitRevealObserver();

    // Save to localStorage
    localStorage.setItem("clix_role", role);

    // Scroll to top
    window.scrollTo({ top: 0, behavior: "instant" });

    // Update sticky CTA link based on role
    updateStickyCta();

  }, 150); // matches CSS opacity transition duration
}

function updateStickyCta() {
  const stickyCta = document.querySelector("#stickyCta .btn");
  if (!stickyCta) return;

  if (currentRole === "passenger") {
    stickyCta.setAttribute("href", "#p-download");
  } else {
    stickyCta.setAttribute("href", "#download");
  }
}

// ── Initialize Role from URL param or localStorage ──
function initRole() {
  const params = new URLSearchParams(window.location.search);
  const urlRole = params.get("role");
  const savedRole = localStorage.getItem("clix_role");

  let initialRole = "passenger"; // default

  if (urlRole === "driver" || urlRole === "passenger") {
    initialRole = urlRole;
  } else if (savedRole === "driver" || savedRole === "passenger") {
    initialRole = savedRole;
  }

  // Set initial state immediately (no animation)
  const driverFlow = document.getElementById("driver-flow");
  const passengerFlow = document.getElementById("passenger-flow");
  const roleSlider = document.getElementById("roleSlider");
  const rolePassenger = document.getElementById("rolePassenger");
  const roleDriver = document.getElementById("roleDriver");

  if (initialRole === "driver") {
    passengerFlow.style.display = "none";
    driverFlow.style.display = "block";
    document.body.classList.remove("light-mode");
    document.querySelector('meta[name="theme-color"]').content = "#0F0A2A";
    roleSlider.classList.add("driver-active");
    rolePassenger.classList.remove("active");
    roleDriver.classList.add("active");
  } else {
    driverFlow.style.display = "none";
    passengerFlow.style.display = "block";
    document.body.classList.add("light-mode");
    document.querySelector('meta[name="theme-color"]').content = "#FFFFFF";
    roleSlider.classList.remove("driver-active");
    rolePassenger.classList.add("active");
    roleDriver.classList.remove("active");
  }

  currentRole = initialRole;
  localStorage.setItem("clix_role", initialRole);
  updateStickyCta();
}

// ── Bind Role Switcher Events ──
document.getElementById("rolePassenger").addEventListener("click", () => {
  if (currentRole !== "passenger") switchRole("passenger");
});

document.getElementById("roleDriver").addEventListener("click", () => {
  if (currentRole !== "driver") switchRole("driver");
});

// Initialize role before anything else
initRole();

// ── Language Switching ──
function switchLang(lang) {
  currentLang = lang;
  const data = translations[lang];
  const meta = langMeta[lang];

  // Update all elements with data-i18n
  document.querySelectorAll("[data-i18n]").forEach(el => {
    const key = el.getAttribute("data-i18n");
    if (data[key]) {
      el.textContent = data[key];
    }
  });

  // Update special composite titles (solution & download — driver)
  const solutionTitle = document.querySelector('[data-i18n="solution_title"]');
  if (solutionTitle) {
    solutionTitle.innerHTML = `${data.solution_title_text} <span class="gradient-text">${data.solution_title_gradient}</span>`;
  }

  const downloadTitle = document.querySelector('[data-i18n="download_title"]');
  if (downloadTitle) {
    downloadTitle.innerHTML = `${data.download_title_text} <span class="gradient-text">${data.download_title_gradient}</span>?`;
  }

  // Update special composite titles (passenger download)
  const pDownloadTitle = document.querySelector('[data-i18n="p_download_title"]');
  if (pDownloadTitle) {
    pDownloadTitle.innerHTML = `${data.p_download_title.replace('Clix Taxi', '<span class="p-highlight">Clix Taxi</span>')}`;
  }

  // Update header flag
  document.getElementById("currentFlag").textContent = meta.flag;
  document.getElementById("currentLangCode").textContent = meta.code;

  // Update html lang
  document.documentElement.lang = meta.htmlLang;

  // Update active state
  document.querySelectorAll(".lang-option").forEach(opt => {
    opt.classList.toggle("active", opt.getAttribute("data-lang") === lang);
  });

  // Close dropdown
  document.getElementById("langSwitcher").classList.remove("open");
}

// ── Language Dropdown Toggle ──
document.getElementById("langToggle").addEventListener("click", (e) => {
  e.stopPropagation();
  document.getElementById("langSwitcher").classList.toggle("open");
});

// Close dropdown on outside click
document.addEventListener("click", (e) => {
  const switcher = document.getElementById("langSwitcher");
  if (!switcher.contains(e.target)) {
    switcher.classList.remove("open");
  }
});

// ── Header Scroll Effect ──
const header = document.getElementById("header");
const stickyCta = document.getElementById("stickyCta");

function handleScroll() {
  const scrollY = window.scrollY;

  // Header background
  if (scrollY > 50) {
    header.classList.add("scrolled");
  } else {
    header.classList.remove("scrolled");
  }

  // Sticky CTA (mobile)
  if (scrollY > 600) {
    stickyCta.classList.add("visible");
  } else {
    stickyCta.classList.remove("visible");
  }
}

window.addEventListener("scroll", handleScroll, { passive: true });
handleScroll();

// ── Scroll Reveal ──
let revealObserver;

function initRevealObserver() {
  revealObserver = new IntersectionObserver((entries) => {
    entries.forEach(entry => {
      if (entry.isIntersecting) {
        entry.target.classList.add("visible");
        revealObserver.unobserve(entry.target);
      }
    });
  }, {
    threshold: 0.1,
    rootMargin: "0px 0px -50px 0px"
  });

  document.querySelectorAll(".reveal").forEach(el => {
    // Only observe elements that are in visible flows
    const parentFlow = el.closest("#driver-flow, #passenger-flow");
    if (!parentFlow || parentFlow.style.display !== "none") {
      revealObserver.observe(el);
    }
  });
}

function reinitRevealObserver() {
  // Observe newly visible reveal elements
  const activeFlow = currentRole === "driver"
    ? document.getElementById("driver-flow")
    : document.getElementById("passenger-flow");

  if (!activeFlow) return;

  activeFlow.querySelectorAll(".reveal:not(.visible)").forEach(el => {
    revealObserver.observe(el);
  });
}

initRevealObserver();

// ── Smooth scroll for anchor links ──
document.querySelectorAll('a[href^="#"]').forEach(anchor => {
  anchor.addEventListener("click", function (e) {
    e.preventDefault();
    const target = document.querySelector(this.getAttribute("href"));
    if (target) {
      target.scrollIntoView({ behavior: "smooth", block: "start" });
    }
  });
});

// ── Counter Animation ──
function animateCounters() {
  const counters = document.querySelectorAll(".stat-number, .stat-value");
  counters.forEach(counter => {
    const text = counter.textContent;
    // Simple presence animation — just add a class
    counter.style.opacity = "1";
  });
}

const statsObserver = new IntersectionObserver((entries) => {
  entries.forEach(entry => {
    if (entry.isIntersecting) {
      animateCounters();
      statsObserver.unobserve(entry.target);
    }
  });
}, { threshold: 0.3 });

const trustStats = document.querySelector(".trust-stats");
if (trustStats) {
  statsObserver.observe(trustStats);
}

// ── Hover glow effect tracking (optional enhancement) ──
document.addEventListener("mousemove", (e) => {
  document.documentElement.style.setProperty("--mouse-x", e.clientX + "px");
  document.documentElement.style.setProperty("--mouse-y", e.clientY + "px");
});

// ── Order card pulse animation ──
const orderCard = document.querySelector(".app-order-card");
if (orderCard) {
  setInterval(() => {
    orderCard.style.boxShadow = "0 0 20px rgba(94,72,232,0.3)";
    setTimeout(() => {
      orderCard.style.boxShadow = "none";
    }, 1000);
  }, 3000);
}

// ── Passenger ride card pulse animation ──
const pRideCard = document.querySelector(".p-app-ride-card");
if (pRideCard) {
  setInterval(() => {
    pRideCard.style.boxShadow = "0 4px 24px rgba(94,72,232,0.2)";
    setTimeout(() => {
      pRideCard.style.boxShadow = "0 4px 16px rgba(0,0,0,0.06)";
    }, 1000);
  }, 3000);
}

console.log("🚕 Clix Taxi Landing — Dual Mode Loaded successfully");
