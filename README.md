# Stundu Saraksts · 1.3

iPhone aplikācija un logrīki Valmieras tehnikuma stundu sarakstam no EduPage.

## Instalēšana

Kad zarā `main` nonāk izmaiņas, GitHub Actions palaiž testus, uzbūvē IPA un publicē to sadaļā Releases. Lejupielādē [jaunāko IPA](https://github.com/Zvejniekks/stundu-saraksts/releases/latest/download/StunduSaraksts.ipa) un instalē to ar AltStore, saglabājot App Extensions. Pēc instalēšanas atver aplikāciju. Ja logrīks nerāda izmaiņas, noņem to un pievieno vēlreiz.

## Testi

`swift test` (mape `Tests`) pārbauda saraksta nolasīšanu, stundu laikus un logrīku loģiku. UI testi (mape `UITests`) palaiž aplikāciju simulatorā ar parauga datiem un veic Apple pieejamības auditu. GitHub Actions abus palaiž pirms IPA būvēšanas. Logrīku izskatu iPhone testi nepārbauda.

## Izmaiņas

### 1.3

Saraksts strādā arī ar vāju internetu vai bez tā. Telefonā saglabājas pēdējās 6 atvērtās nedēļas, nedēļu saraksts un pēdējo divu nedēļu izmaiņas. Ja EduPage nav sasniedzams, kļūdas vietā redzams “Bezsaistē · rādīti saglabātie dati no …”, un var pārslēgties arī uz citām saglabātajām nedēļām. Vājā tīklā pieprasījums tiek atkārtots vienu reizi, un novecojusi EduPage sesija atjaunojas automātiski. Ja saglabātais fails ir bojāts, aplikācija to izdzēš un strādā tālāk.

Pieejamība:
- Visi teksti seko iOS teksta izmēram (Dynamic Type). Pie ļoti liela teksta stundas laiks pārvietojas virs priekšmeta, un nedēļas izvēle pāriet jaunā rindā.
- VoiceOver katru stundu nolasa vienā teikumā, piemēram, “5. stunda, no 11:50 līdz 12:30, Programmēšana, mainīta, bija Angļu valoda, kabinets V115., bija 213.”.
- Zilās un oranžās krāsas teksta kontrasts ir vismaz 4,5:1 gan gaišajā, gan tumšajā režīmā. Izmaiņas apzīmē arī ikona.
- Pogas un saites ir vismaz 44 punktus augstas.

Pievienoti testi bojātiem un nepilnīgiem EduPage datiem, bezsaistes krātuvei un tīkla atkārtošanai, kā arī UI testi.

### 1.2

- Izmaiņas ielādējas visām piecām nedēļas dienām. Agrāk tās ielādējās tikai no šodienas uz priekšu, tāpēc nedēļas nogalē pagājušās piektdienas izmaiņas nebija redzamas.
- Priekšmets tiek nolasīts pareizi arī tad, ja nosaukumā ir domuzīme, piemēram, “Svešval. I (B2) - angļu val.”.
- Vidējā logrīka augšā redzams pusdienu laiks, piemēram, “🍴 Pusdienas 12:10–12:40”. Stundu rindas nemainās.
- Diena pārslēdzas tikai ar skaidru, garu pavilkienu uz sāniem. Ritinot sarakstu, diena nepārslēdzas.
- Vairs neparādās kļūda “Neizdevās atjaunot sarakstu. cancelled”. iOS pārtrauca ielādi, kad ekrāns pārzīmējās vai aplikācija aizgāja fonā. Tagad ielāde turpinās līdz galam, un pārtraukums netiek rādīts kā kļūda.
- Versija redzama iestatījumos, sadaļā “Par aplikāciju”.

### 1.1

Augšā ir pārslēgs “Diena / Visa nedēļa”. Nedēļas skatā visas piecas dienas ir vienā lapā ar stundas numuru, sākuma laiku, priekšmetu un kabinetu. Dubultstundas ir apvienotas vienā rindā, izmaiņas ir oranžas, atceltās stundas pārsvītrotas, un šodiena ir iezīmēta zilā krāsā. Pieskaroties dienas nosaukumam, atveras tās dienas detalizētais skats.

Iestatījumos var ieslēgt “Paziņot par jaunu nedēļu”. Kad skola EduPage publicē jaunas nedēļas sarakstu, atnāk paziņojums. Aplikācija to pārbauda, kad to atver, un iOS fona atjaunināšanas laikā. Paziņojumi parādās arī tad, ja aplikācija ir atvērta.

### 1.0

Aplikācija ielādē EduPage aizvietošanas sarakstu tavai grupai. Izvēlētās dienas izmaiņas redzamas oranžā kartītē virs stundām. Mainītā stunda ir atzīmēta ar “IZMAIŅA”, atceltā ir pārsvītrota ar “NENOTIEK”, un oranžs punkts dienu pogās rāda, kurās dienās ir izmaiņas.

Izmaiņas ir iestrādātas pašās stundās: kartītē redzams jaunais priekšmets, skolotājs un kabinets, un zem tiem pārsvītrotas vecās vērtības. Atceltās stundas ir blāvākas un netiek rādītas kā “Nākamā”.

Visi trīs logrīki ņem vērā izmaiņas. Mainītās stundas ir oranžas, atceltās pārsvītrotas, un apakšā redzams, piemēram, “Šodien 2 izmaiņas”. Logrīks pārbauda izmaiņas ik pēc 30 minūtēm (cik bieži tieši, nosaka iOS).

Iestatījumos var ieslēgt “Paziņot par stundu izmaiņām”. Aplikācija pārbauda šodienu un nākamo mācību dienu, kad to atver un iOS fona atjaunināšanas laikā, un paziņo tikai par jaunām izmaiņām. Fona pārbaudes biežumu nosaka iOS.

Mainīts dizains. Augšā ir liels dienas nosaukums ar datumu; izvēlētā diena ir zila, šodiena iezīmēta. Zem dienām redzams stundu skaits un cik no tām ir mainītas. Kabinets ir krāsainā zīmītē. Šodienai augšā redzams “Tagad” ar atlikušajām minūtēm un progresa joslu vai “Nākamā” ar laiku līdz sākumam. Katram priekšmetam ir sava krāsa, beigušās stundas ir blāvākas, un dienas var pārslēgt, pavelkot pa kreisi vai pa labi.

### 0.9

Vidējais logrīks no 17:00 rāda nākamās mācību dienas stundas. Piektdien pēc 17:00 un nedēļas nogalē tas rāda pirmdienu, ja nākamā nedēļa ir publicēta; ja nav, paliek pēdējā publicētā nedēļa. Mazais logrīks no 17:00 arī ņem vērā nākamo nedēļu.

Aplikācija nedēļas nogalē atveras pirmdienā. Atgriežoties aplikācijā, dati atjaunojas, un jaunā dienā atveras šodiena. Atjaunojot sarakstu, izvēlētā nedēļa paliek atvērta. Citas nedēļas skatīšana vairs nepārraksta bezsaistes datus.

### 0.8

Dienas logrīkā priekšmeta nosaukums ir atsevišķā rindā, laiks un kabinets zem tā. Visiem nosaukumiem ir vienāds fonta izmērs, arī gariem. Pie 9–10 ierakstiem abas kolonnas izmanto vienu, kompaktāku izmēru. Krievu, angļu un vācu valodai un valodas, kultūras un izpausmes priekšmetam ir saprotami īsie nosaukumi. Pārējie nosaukumi netiek sadalīti vārdu fragmentos; ja nepietiek vietas, beigas aizstāj daudzpunkte.

Aplikācija ir kompaktāka. Lielais skolas nosaukuma un dienas virsraksta bloks un paskaidrojums “Apskati publicēto nedēļu…” ir noņemti. Augšā ir datums un nedēļas izvēle, zem tiem piecas dienu pogas, un atstarpes un kartīšu iekšējās malas ir mazākas. Skatāmās nedēļas datumi paliek redzami, lai vecu nedēļu nevarētu sajaukt ar šodienu.

Pusdienas ir izņemtas no visiem trim logrīkiem, bet aplikācijā tās paliek. Filtrs atpazīst tikai konkrētus pusdienu apzīmējumus, tāpēc priekšmets ar līdzīgu vārdu nosaukumā netiek izņemts.

- Mazais logrīks: nākamā mācību stunda.
- Vidējais logrīks: dienas stundas divās kolonnās; lasa kreiso kolonnu no augšas uz leju, tad labo. Pie 9 ierakstiem kreisajā ir 5 un labajā 4, pie 10 abās pa 5. Rindas ir izlīdzinātas arī pie nepāra skaita. Dubultstunda skaitās kā divas stundas, un paralēlo apakšgrupu ieraksti paliek atsevišķi.
- Lielais logrīks: piecu dienu tabula līdz pēdējam izmantotajam stundas numuram, arī 10. un 11.–13. stundai. Pusdienu šūnas ir tukšas, un stundu numuri netiek pārbīdīti. Nosaukumi ir saīsināti, un rindas sadala pieejamo augstumu.

Logrīkus nevar ritināt, tāpēc ļoti blīvā sarakstā nosaukumi kļūst īsāki un teksts mazāks; pilnos nosaukumus redz aplikācijā. Stundu skaitam logrīkos nav 8 vai 9 stundu limita.
