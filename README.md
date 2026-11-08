# Stundu Saraksts · 1.3

## Jaunums 1.3

**Bezsaiste.** Saraksts strādā arī skolā ar vāju vai bez interneta:
- telefonā tiek saglabātas pēdējās 6 atvērtās nedēļas, nedēļu saraksts un pēdējo divu nedēļu izmaiņas;
- ja EduPage nav sasniedzams, kļūdas vietā redzams “Bezsaistē · rādīti saglabātie dati no …”, un var pārslēgt arī uz citām saglabātajām nedēļām;
- vājā tīklā pieprasījums tiek atkārtots vienu reizi, un novecojusi EduPage sesija tiek atjaunota automātiski;
- bojāts saglabātais fails tiek izdzēsts, nevis aptur aplikāciju.

**Pieejamība.**
- Visi teksti seko iOS teksta izmēram (Dynamic Type). Pie ļoti liela teksta stundas laiks pārvietojas virs priekšmeta, un nedēļas izvēle pāriet jaunā rindā.
- VoiceOver katru stundu nolasa vienā teikumā, piemēram, “5. stunda, no 11:50 līdz 12:30, Programmēšana, mainīta, bija Angļu valoda, kabinets V115., bija 213.”.
- Zilā un oranžā krāsa ir pielāgota, lai teksta kontrasts būtu vismaz 4,5:1 gan gaišajā, gan tumšajā režīmā. Izmaiņas apzīmē arī ikona, ne tikai krāsa.
- Pogas un saites ir vismaz 44 punktus augstas.

**Testi.** Jauni testi bojātiem un nepilnīgiem EduPage datiem, bezsaistes krātuvei un tīkla atkārtošanai. UI testi palaiž aplikāciju simulatorā ar parauga datiem un veic Apple pieejamības auditu.


## Jaunums 1.2

- **Izmaiņas strādā visām dienām.** Agrāk izmaiņas ielādējās tikai no šodienas uz priekšu, tāpēc, piemēram, nedēļas nogalē pagājušās piektdienas izmaiņas nebija redzamas. Tagad tiek ielādētas visas piecas nedēļas dienas. Izlabota arī priekšmeta nolasīšana, ja nosaukumā ir domuzīme, piemēram, “Svešval. I (B2) - angļu val.”.
- **Pusdienas dienas logrīkā.** Vidējā logrīka augšā redzams pusdienu laiks, piemēram, “🍴 Pusdienas 12:10–12:40”. Stundu rindas paliek tādas pašas.
- **Pavilkiens starp dienām** nostrādā tikai ar skaidru, garu pavilkienu uz sāniem, nevis ritinot sarakstu.
- **Vairs nav kļūdas “Neizdevās atjaunot sarakstu. cancelled”.** iOS pārtrauca ielādi, kad ekrāns pārzīmējās vai aplikācija aizgāja fonā. Tagad ielāde turpinās līdz galam, un pārtraukšana netiek rādīta kā kļūda.
- **Versija** redzama iestatījumos, sadaļā “Par aplikāciju”.


## Jaunums 1.1

**Visa nedēļa.** Augšā ir pārslēgs “Diena / Visa nedēļa”. Nedēļas skatā redzamas visas piecas dienas vienā lapā: stundas numurs, sākuma laiks, priekšmets un kabinets. Dubultstundas ir apvienotas vienā rindā, izmaiņas ir oranžas, atceltās stundas pārsvītrotas, un šodiena ir iezīmēta zilā krāsā. Uzspiežot uz dienas nosaukuma, atveras tās dienas detalizētais skats.

**Paziņojums par jaunu nedēļu.** Iestatījumos ieslēdz “Paziņot par jaunu nedēļu”. Kad skola EduPage publicē jaunas nedēļas sarakstu, atnāk paziņojums. Pārbaude notiek, kad aplikāciju atver un iOS fona atjaunināšanas laikā. Paziņojumi tagad parādās arī tad, ja aplikācija ir atvērta.


## Jaunums 1.0

**Stundu izmaiņas.** Aplikācija ielādē EduPage aizvietošanas sarakstu tavai grupai. Izvēlētās dienas izmaiņas redzamas oranžā kartītē virs stundām, mainītā stunda ir atzīmēta ar “IZMAIŅA”, un atceltā stunda ir pārsvītrota ar “NENOTIEK”. Dienu pogās oranžs punkts norāda, ka tajā dienā ir izmaiņas.

**Izlabots saraksts.** Izmaiņas tiek iestrādātas pašās stundās: kartītē redzams jaunais priekšmets, skolotājs un kabinets, bet vecās vērtības ir pārsvītrotas zem tām. Atceltās stundas ir blāvākas, un tās netiek rādītas kā “Nākamā”.

**Izmaiņas logrīkos.** Visi trīs logrīki ņem vērā izmaiņas. Mainītās stundas ir oranžas, atceltās pārsvītrotas, un apakšā redzams, piemēram, “Šodien 2 izmaiņas”. Logrīks pārbauda izmaiņas ik pēc 30 minūtēm (cik bieži tieši, nosaka iOS).

**Paziņojumi.** Iestatījumos ieslēdz “Paziņot par stundu izmaiņām”. Aplikācija pārbauda šodienu un nākamo mācību dienu, kad to atver un iOS fona atjaunināšanas laikā, un paziņo tikai par jaunām izmaiņām. Cik bieži notiek fona pārbaude, izlemj iOS.

**Dizains.** Augšā liels dienas nosaukums ar datumu, izvēlētā diena ir zila, šodiena iezīmēta. Zem dienām ir stundu skaits un cik no tām mainītas. Kabinets ir krāsainā zīmītē. Šodienai augšā redzams “Tagad” ar atlikušajām minūtēm un progresa joslu vai “Nākamā” ar laiku līdz sākumam. Katram priekšmetam ir sava krāsa, beigušās stundas ir blāvākas, un dienas var pārslēgt, pavelkot pa kreisi vai pa labi.


## Jaunums 0.9

Vidējais logrīks no 17:00 rāda nākamās mācību dienas stundas. Piektdien pēc 17:00 un nedēļas nogalē tas rāda pirmdienu, ja nākamā nedēļa ir publicēta; ja nav, paliek pēdējā publicētā nedēļa. Mazais logrīks no 17:00 arī ņem vērā nākamo nedēļu.

Aplikācijas labojumi: nedēļas nogalē atveras pirmdiena, nevis piektdiena. Atgriežoties aplikācijā, dati atjaunojas, un jaunā dienā tiek atvērta šodiena. Atjaunojot sarakstu, izvēlētā nedēļa paliek atvērta. Citas nedēļas skatīšana vairs nepārraksta bezsaistes datus.

## Lasāmāks dienas logrīks

Priekšmeta nosaukums tagad ir atsevišķā rindā, laiks un kabinets zem tā. Visiem nosaukumiem ir vienāds izmērs; garš nosaukums vairs nesamazina savu fontu. Pie 9–10 ierakstiem abas kolonnas izmanto vienotu kompaktāku izmēru. Krievu/angļu/vācu valodai un valodas, kultūras un izpausmes priekšmetam ir saprotami īsie nosaukumi. Neatpazītus nosaukumus nešķeļ vārdu fragmentos; ja nepietiek vietas, beigas saīsina ar daudzpunkti. Saglabāti arī 0.7 labojumi.

## Kompaktāks aplikācijas dizains

Noņemts lielais skolas nosaukuma/dienas virsraksta bloks un paskaidrojums “Apskati publicēto nedēļu…”. Augšā ir kompakts datums un nedēļas izvēle, zemāk piecas dienu pogas. Samazinātas atstarpes un stundu kartīšu iekšējās malas. Skatāmās nedēļas datumi joprojām ir redzami, tāpēc veca nedēļa nav paslēpta aiz šodienas nosaukuma.

## Logrīki

Pusdienas ir izņemtas no visiem trim logrīkiem. Pašā aplikācijā pusdienas paliek. Filtrs atpazīst konkrētus pusdienu apzīmējumus, nevis jebkuru priekšmetu, kura nosaukumā ir līdzīgs vārds.

- Mazais: tikai nākamā mācību stunda.
- Vidējais: visas izvēlētās dienas mācību stundas divās kolonnās. 9 ieraksti = 5 kreisajā, 4 labajā; 10 ieraksti = 5 un 5. Lasi kreiso kolonnu no augšas uz leju, tad labo. Kolonnu rindas izlīdzinātas arī pie nepāra skaita. Dubultstundas skaita kā divas stundas; paralēlo apakšgrupu ieraksti paliek atsevišķi.
- Lielais: piecu dienu tabula līdz pēdējam izmantotajam stundas numuram. Ja ir 10. stunda, tiek pievienota 10. rinda; ja 11.–13., arī tās. Pusdienu šūnas ir tukšas, stundu numuri netiek pārbīdīti. Nosaukumi saīsināti, rindas sadala pieejamo augstumu.

Ļoti blīvā sarakstā nosaukumi kļūst īsāki un teksts mazāks. Logrīkos nav ritināšanas; pilnos nosaukumus skaties aplikācijā. Pārskatā saglabājas visas stundas, netiek izmantots patvaļīgs 8 vai 9 stundu limits.

## Atjaunināšana

Izpako `StunduSaraksts-v1.0.zip`, GitHub augšupielādē mapes `StunduSaraksts`, `Shared`, `StunduWidget`, `Tests` un `project.yml`. GitHub Actions uzbūvē IPA. Lejupielādē [jaunāko IPA](https://github.com/Zvejniekks/stundu-saraksts/releases/latest/download/StunduSaraksts.ipa) un instalē AltStore ar saglabātiem App Extensions. Atver aplikāciju pēc instalēšanas; ja logrīks nerāda izmaiņas, noņem un pievieno to vēlreiz.

Atjaunini `.github/workflows/build.yml` no ZIP, lai Actions pirms būvēšanas palaistu Swift testus.

## Pārbaudes

0.9: pievienoti testi pārejai 17:00, piektdienas vakaram, nedēļas nogalei un aplikācijas sākuma dienai. Pievienoti testi 9/10 ierakstu sadalījumam, 10. un 13. stundas rindai, pusdienu izslēgšanai un sākotnējo numuru saglabāšanai. Iepriekšējie datu testi saglabāti. Šajā vidē nav Swift/Xcode — jaunā versija vēl jāsakompilē GitHub Actions un izskats jāpārbauda iPhone. Nav veikts reāla WidgetKit izkārtojuma renderējums.
