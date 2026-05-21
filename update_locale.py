import os
import re

files = [
    "landing-react/src/data/translations.js",
    "landing-react/src/components/passenger/PassengerHero.jsx",
    "landing-react/src/components/driver/DriverHero.jsx",
]

replacements = [
    # UK
    (r"Доступно в Празі", "Доступно у Львові"),
    (r"з аеропорту Вацлава Гавела", "з аеропорту Львів"),
    (r"Letiště Václava Havla", "Міжнародний аеропорт «Львів»"),
    (r"Praha 1, Staroměstské nám.", "Львів, Площа Ринок"),
    (r"🚕 Taxi Letiště Praha", "🚕 Taxi Аеропорт Львів"),
    (r"Летиште → Прага 1, 2 особи, 890 кч", "Аеропорт → Центр, 2 особи, 890 грн"),
    (r"3 роки в Празі", "3 роки у Львові"),
    (r"з аеропорту Праги", "з аеропорту Львова"),
    (r"Praha 1, Hotel Astoria", "Львів, Готель Асторія"),
    (r"у Прагу", "до Львова"),
    # CS
    (r"Dostupné v Praze", "Dostupné ve Lvově"),
    (r"letiště Václava Havla", "letiště Lvov"),
    (r"Letiště → Praha 1, 2 osoby, 890 Kč", "Letiště → Centrum, 2 osoby, 890 UAH"),
    (r"3 roky v Praze", "3 roky ve Lvově"),
    (r"z letiště Praha", "z letiště Lvov"),
    (r"do Prahy", "do Lvova"),
    # EN
    (r"Available in Prague", "Available in Lviv"),
    (r"Václav Havel Airport", "Lviv International Airport"),
    (r"Prague 1, Old Town Square", "Lviv, Rynok Square"),
    (r"Prague 1, Hotel Astoria", "Lviv, Hotel Astoria"),
    (r"Prague Airport", "Lviv Airport"),
    (r"Airport → Prague 1, 2 pax, 890 CZK", "Airport → Center, 2 pax, 890 UAH"),
    (r"3 years in Prague", "3 years in Lviv"),
    (r"flight to Prague", "flight to Lviv"),
    # Currency
    (r"890 Kč", "890 ₴"),
]

for file_path in files:
    full_path = os.path.join("/Users/tohqa/Боско/Diploma", file_path)
    if os.path.exists(full_path):
        with open(full_path, "r", encoding="utf-8") as f:
            content = f.read()

        for old, new in replacements:
            content = re.sub(old, new, content)

        with open(full_path, "w", encoding="utf-8") as f:
            f.write(content)
        print(f"Updated {file_path}")
    else:
        print(f"File not found: {file_path}")
