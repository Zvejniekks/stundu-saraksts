# Stundu Saraksts — pirmā versija (0.2)

iPhone aplikācija Valmieras tehnikuma publiskajam EduPage stundu sarakstam. iOS 17 vai jaunāks. Sākotnēji izvēlēta 31. grupa; grupu var mainīt un izvēle saglabājas.

## Ievietošana esošajā GitHub projektā no Windows

1. Izpako ZIP. Atver esošā repozitorija sākumu: https://github.com/Zvejniekks/stundu-saraksts
2. **Add file → Upload files**. Ievelc mapes `StunduSaraksts`, `Shared`, `StunduWidget`, `Tests` un failus `project.yml`, `Package.swift`, `README.md`. Augšupielādē saturu repozitorija saknē, nevis vēl vienu ārējo mapi. Apstiprini ar **Commit changes**.
3. Failā `.github/workflows/build.yml` ieliec ZIP esošo atjaunināto saturu. Tas pievieno datu apstrādes testus un pārbaudi, vai IPA satur logrīku. Esošais workflow arī kompilē jauno projektu, bet bez šiem papildu testiem.
4. Atver **Actions → Build IPA** un sagaidi zaļu rezultātu. Ja vajag, nospied **Run workflow**.
5. Lejupielādē `StunduSaraksts-ipa` artefaktu, izpako to un instalē iegūto `.ipa` caur AltStore Classic. Uz jautājumu par app extensions izvēlies **Keep App Extensions**, ja tas parādās.
6. Atver aplikāciju ar internetu. Pievieno sākuma ekrāna logrīku **Stundu Saraksts**. Ilgi nospiežot logrīku, izvēlies tā rediģēšanu un grupas numuru (sākotnēji `31`).

## Kas iekļauts

- Reāli dati no https://valteh.edupage.org/timetable/view.php bez lietotāja konta.
- Grupas izvēle un saglabāšana, publicēto nedēļu izvēlne, piecas dienas, priekšmeti, skolotāji, kabineti un apakšgrupu marķējumi.
- Pēdējās ielādētās nedēļas saglabāšana bezsaistē un datu ielādes laiks.
- Mazs, vidējs un liels sākuma ekrāna logrīks. Grupu katram logrīkam iestata atsevišķi; tā nav automātiski sinhronizēta ar aplikācijas izvēli. Nav vajadzīgs App Groups entitlement.
- Logrīks pieprasa atsvaidzināšanu aptuveni reizi stundā; faktisko atjaunošanas laiku nosaka iOS. Tas nav tūlītējs izmaiņu paziņojumu pakalpojums.

## Datu apstrādes robežas

Šī ir skolas neoficiāla aplikācija. Tiek izmantoti tie paši publiskie datu pieprasījumi, ko veic EduPage lapa. Tie nav garantēts, stabils publisks API un pēc EduPage izmaiņām var būt jāpielāgo.

Saraksts ir piesaistīts publicētās nedēļas datumiem. Logrīks neatkārto iepriekšējās nedēļas stundas, ja jaunā vēl nav publicēta. Aplikācijā joprojām var apskatīt agrāk publicētas nedēļas.

Avotā atrasti kļūdaini dienu laiki, piemēram, `50:50`, un nesamērīgi gari intervāli. Nezināmais laiks parādās kā `?`, blakus ir brīdinājums. Tiek saglabāta pati stunda un kārtas numurs; nepareizs beigu laiks netiek izmantots, lai izliktos, ka zinām pašlaik notiekošo stundu. Logrīks var izlaist jau sākušos stundu, ja tai nav ticama beigu laika. Pārbaudi laiku skolas sarakstā.

Apakšgrupu stundas tiek rādītas visas un ir marķētas; personiska apakšgrupas filtrēšana vēl nav ieviesta. Vairāku rotējošu nedēļu formāts netiek minēts — aplikācija šādā gadījumā rāda kļūdu. Paziņojumi par izmaiņām un bloķēšanas ekrāna logrīki šajā versijā nav iekļauti.

## Pārbaudes

Sagatavošanas laikā publiskajā datu avotā pārbaudīta `2.k. 31.grupa`, ID `-257`, un 61 saraksta ieraksts publicētajā nedēļā `507` (14.–18.09.2026.). No tiem 26 ir ievietoti nedēļas sarakstā, bet 35 nav piešķirta diena/laiks un tie netiek rādīti. Ieraksti ietver apakšgrupas un pusdienas.

`swift test` pārbauda parseri ar minimizētu šīs nedēļas datu paraugu: grupas atrašanu, laikus, datumu robežas un datu saglabāšanas formātu. Testi ir pievienoti GitHub Actions.

**Šajā sagatavošanas vidē nav Swift/Xcode, tāpēc Swift testi un iOS kompilēšana šeit nav izpildīti.** Tie jāizpilda GitHub Actions. Logrīka reģistrēšana un AltStore parakstīšana jāpārbauda iPhone. Ja build neizdodas, nokopē pirmo `error:` no Actions.

## Izstrāde

Xcode projektu ģenerē XcodeGen no `project.yml`. SwiftUI aplikācija un WidgetKit paplašinājums izmanto kopīgo `Shared/Timetable.swift`. Datu ielāde notiek tieši iPhone; atsevišķs serveris nav vajadzīgs. Gan aplikācijai, gan logrīkam ir sava datu kešatmiņa.
