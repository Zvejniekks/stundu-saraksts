# Atjauninājums 0.5

- Logrīks izvēlas aktuālo nedēļu, tad tuvāko nākotnes nedēļu, bet, ja tādas nav, pēdējo publicēto nedēļu. Vecajam sarakstam rāda datumu un atzīmi “Pēdējais saraksts”.
- Vecās nedēļas pārskatā rāda pirmo dienu ar stundām; datumi netiek pārcelti uz nākamo nedēļu. Vienā logrīkā netiek sajauktas vairāku dienu stundas.
- Bez interneta tiek izmantots pēdējais saglabātais saraksts, arī ja tas ir vecāks. Ja nav ne datu, ne interneta, paliek paskaidrojums.
- Dubultstundas aplikācijā sadalītas atsevišķās kartītēs. Katrā laiks tikai kreisajā malā, priekšmets un kabinets. Pa vidu kompakts starpbrīža uzraksts.
- Saglabāti 0.4 ātrdarbības uzlabojumi. Sarkanā laika līnija vēl nav pievienota.

Izpako `StunduSaraksts-v0.5.zip`, augšupielādē četras mapes un `project.yml` kā iepriekš. Atjaunini arī `.github/workflows/build.yml` no ZIP, lai būvējumā darbotos Swift testi. Kompilēšana un izvietojums īstā iPhone šajā vidē nav pārbaudīts.

Ja “Stundu Saraksts” vispār neparādās iPhone logrīku izvēlnē, tas ir atsevišķs paplašinājuma instalācijas jautājums; jaunās nedēļas trūkums nepaslēpj pašu logrīku no iPhone saraksta. AltStore instalācijā saglabā App Extensions un pēc instalēšanas atver aplikāciju.

# Kas mainīts 0.4

- Dienu pārslēgšanai vairs netiek atkārtoti pārrēķinātas visas skolas stundas. Izvēlētās grupas sarakstu sadala pa dienām vienreiz pēc datu, grupas vai pirmssvētku iestatījumu izmaiņām.
- Datumu formatētāji tiek izmantoti atkārtoti. Pirmssvētku laiku aprēķins uzreiz beidzas, ja nav izvēlēts attiecīgs datums.
- Dubultstundas blokā parādās katras stundas sākums un beigas, un starpbrīža ilgums. Stundas aktīvā atzīme neaptver starpbrīdi.
- Saglabāts iepriekšējais dizains, ikona un pareizie pirmdienas/piektdienas laiki.

Ātruma uzlabojums vēl nav izmērīts uz iPhone. Šeit nav Swift/Xcode; Swift testi un kompilācija jāpalaiž GitHub Actions. Sākotnējā interneta ielāde joprojām ir atkarīga no EduPage servera.

# Stundu Saraksts · 0.4

Atjauninājums esošajai iPhone aplikācijai (iOS 17+). Gaišs, atturīgs dizains ar lielu dienas virsrakstu, datumu pogām un ziliem akcentiem; sistēmas tumšais režīms arī atbalstīts. Pašreizējā stunda ir izcelta.

## Atjaunināšana no Windows

1. Izpako `StunduSaraksts-v0.4.zip` ar **Extract All / Izvilkt visu**.
2. Atver https://github.com/Zvejniekks/stundu-saraksts/upload/main.
3. **Ievelc mapes** `StunduSaraksts`, `Shared`, `StunduWidget`, `Tests` no izpakotās mapes tieši GitHub augšupielādes laukumā. Pievieno arī `project.yml`, `Package.swift`, `README.md`. Saglabā mapju struktūru. Īpaši svarīgi: `StunduSaraksts/Assets.xcassets` satur ikonu. Pats ZIP nav jāaugšupielādē.
4. **Commit changes**. Failā `.github/workflows/build.yml` vari ielikt ZIP esošo versiju, lai Actions pirms kompilēšanas palaistu Swift testus.
5. Kad **Actions → Build IPA** ir zaļš, lejupielādē `StunduSaraksts-ipa`, izpako un instalē IPA caur AltStore. Saglabā **App Extensions**, lai būtu pieejams logrīks.

## Laiki

1.–10. stundas laiki tagad ņemti no lietotāja atsūtītās skolas tabulas, kas sakrīt ar [skolas publicēto tabulu](https://valmierastehnikums.lv/wp-content/uploads/2024/10/MACIBU_STUNDU_LAIKI.pdf-2.pdf). Tie aizstāj kļūdainās EduPage laiku vērtības. Pirmdienai, otrdienai–ceturtdienai un piektdienai ir atsevišķi laiki. Dubultstunda beidzas tās pēdējās stundas beigās. Periodiem pēc 10. saglabājas avota laiki.

**Pirmssvētku diena:** izvēlies konkrēto dienu, atver iestatījumus augšējā labajā stūrī un ieslēdz `Pirmssvētku diena`. Izvēle tiek saglabāta tikai šim datumam. Aplikācija pati nemin, kad skola nosaka saīsinātu dienu.

Logrīks izmanto tos pašus parastos pirmdienas/piektdienas laikus. Tā grupa tiek iestatīta atsevišķi. Pirmssvētku datumam logrīka iestatījumos norādi `GGGG-MM-DD`; tas automātiski nesinhronizējas ar aplikāciju. iOS nosaka faktisko logrīka atsvaidzināšanas brīdi.

Iepriekšējās versijas kešatmiņa vairs netiek ielādēta, lai pēc atjauninājuma netiktu parādīti vecie laiki. Pirmajā palaišanas reizē vajadzīgs internets. Grupas izvēle saglabājas.

## Ikona

Ikona ir iekļauta `StunduSaraksts/Assets.xcassets/AppIcon.appiconset`, kopā ar visiem iPhone izmēriem un necaurspīdīgu 1024 × 1024 PNG. `project.yml` norāda šo katalogu kā AppIcon.

Radīta ar iebūvēto imagegen rīku. Uzvedne: “Minimal iOS school timetable app icon, full-bleed blue background, bold white calendar with three schedule bars, one icy-blue accent, no text, no logos, opaque, no rounded outer corners.” Izmēru varianti sagatavoti no tā paša ģenerētā attēla.

## Pārbaudes un ierobežojumi

- Pārbaudīti visi 40 laiku intervāli četrās tabulas kolonnās, datu paraugs un ikonas izmēri/formāts.
- Swift testi pārbauda pirmdienas/piektdienas laikus, dubultstundas un pirmssvētku datuma izolāciju, kā arī esošo datu parseri.
- Šajā vidē nav Xcode/Swift: Swift testi un jaunās versijas iOS kompilācija nav lokāli izpildīti. Palaid tos GitHub Actions; gala izskats un logrīks jāpārbauda iPhone.
- Rāda visas grupas apakšgrupas ar marķējumu. Skolas neoficiālais EduPage datu pieprasījumu formāts var mainīties.
- Vecās publicētās nedēļas netiek atkārtotas kā aktuālā nedēļa. Paziņojumi un bloķēšanas ekrāna logrīki nav ieviesti.
