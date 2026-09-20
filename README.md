# Stundu Saraksts · 0.6

## Izmaiņas

- Aplikācijā vairs nav starpbrīžu uzrakstu vai atdalītāju. Dubultstundu stundas paliek atsevišķās kartītēs.
- Mazais logrīks rāda tikai vienu nākamo stundu (sākums vēl priekšā), tās laiku un kabinetu. Dubultstundas otrā daļa tiek uzskatīta par atsevišķu stundu.
- Vidējais logrīks rāda visu izvēlēto dienu, arī jau beigušās stundas. Lai viss ietilptu, saraksts sadalīts divās kolonnās — lasi kreiso no augšas uz leju, tad labo.
- Lielais logrīks rāda visu pirmdienas–piektdienas nedēļu vienā tabulā ar stundu numuriem. Priekšmetu nosaukumi saīsināti; pilnie nosaukumi ir pieejami aplikācijā un VoiceOver.
- Neviena dienas vai nedēļas stunda netiek atmesta ar fiksētu ierakstu limitu. Apakšgrupu paralēlās stundas redzamas vienā tabulas šūnā. Ļoti blīvos sarakstos teksts būs mazāks.
- Ja jaunā nedēļa nav pieejama, logrīki rāda pēdējo publicēto nedēļu ar atzīmi un datumiem. Mazais šajā gadījumā rāda vienu vēsturisku stundu kā “Pārskats”, nevis apgalvo, ka tā būs nākamā stunda.

## Uzstādīšana

Izpako `StunduSaraksts-v0.6.zip`. GitHub repozitorija sākumā caur **Add file → Upload files** ievelc mapes `StunduSaraksts`, `Shared`, `StunduWidget`, `Tests` un failu `project.yml`. Pēc Commit changes sagaidi Actions rezultātu, lejupielādē IPA un instalē caur AltStore, saglabājot App Extensions. Pēc atjauninājuma atver aplikāciju. Ja redzams vecais logrīks, noņem to un pievieno vēlreiz izvēlētajā izmērā.

ZIP satur arī `.github/workflows/build.yml` ar Swift testiem; atjaunini šo failu, lai tie palaistos Actions. Nemaini mapju struktūru un neaugšupielādē pašu ZIP tā satura vietā.

## Iestatījumi

Grupu logrīkam iestata atsevišķi (noklusējums: 31). Pirmssvētku datums ir `GGGG-MM-DD`. Pirmdienas, otrdienas–ceturtdienas un piektdienas laiki ir pēc lietotāja atsūtītās skolas tabulas. Logrīka atjaunošanu kontrolē iOS.

## Pārbaudes

Pievienoti Swift testi, kas pārbauda nākamās stundas atlasi, pilnas dienas saglabāšanu pēc pusdienlaika un visu nedēļas stundu saglabāšanu pēc dubultstundu sadalīšanas. Konfigurācija, datu piemērs un ZIP pārbaudīti lokāli. Šajā vidē nav Swift/Xcode, tādēļ Swift testi, iOS kompilēšana un reālais logrīku izkārtojums vēl jāpārbauda GitHub Actions un iPhone.
