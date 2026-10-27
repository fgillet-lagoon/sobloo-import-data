// Point d'avancement Lagoon × So'Bloo (PPTX). Usage : cd outils && npm install && node build_deck.js <chemin de sortie .pptx>
// Charte : lagoon_theme.js (recréé d'après le skill fgillet-lagoon-light-ppt, dont les assets ne sont pas synchronisés).

const pptxgen = require('pptxgenjs');
const T = require('./lagoon_theme.js');
const { C, th, td, statusCell } = T;

const OUT = process.argv[2] || 'Point_avancement_reprise_Smile_SoBloo.pptx';
T.setAssetDir(__dirname + '/assets');
T.setProject("Reprise Smile → So'Bloo");
T.setTotal(6);

const pres = new pptxgen();
pres.layout = 'LAYOUT_WIDE';
pres.author = 'François Gillet';
pres.title = "Reprise Smile → So'Bloo : point d'avancement";

const slide = () => { const s = pres.addSlide(); s.background = { color: C.WHITE }; return s; };
const tableOpts = (y, colW, extra = {}) => ({ x: 0.6, y, w: 12.13, colW, border: { type: 'solid', pt: 0.5, color: 'D9DEE5' }, rowH: 0.42, margin: [3, 6, 3, 6], ...extra });

// 1. Couverture
T.cover(pres, {
  eyebrow: "Reprise Smile → So'Bloo",
  title: "Point d'avancement",
  subtitle: 'Cartographie de Smile, volumes, décisions et points à trancher',
  author: 'François Gillet', role: 'CTO Lagoon', date: '27 octobre 2026',
  coBrandLogo: __dirname + '/assets/sobloo_logo.png',
});

// 4. Volumes
{
  const s = slide();
  T.header(pres, s, 'Volumes à reprendre', 'Inventaire Smile du 27/10/2026');
  s.addTable([
    [th('Lot'), th('Dans Smile', { align: 'right' }), th('À reprendre', { align: 'right' }), th('Remarque')],
    [td('1. Comptes comptables', { bold: true }), td('157 comptes GL', { align: 'right' }), td('110 actifs', { align: 'right', bold: true }), td('Lien avec les catégories de rapport de vente à établir')],
    [td('2. Clients', { bold: true }), td('57 600 comptes', { align: 'right' }), td('26 264', { align: 'right', bold: true }), td('Clients ayant au moins un abonnement à reprendre. Dont 2 832 pros')],
    [td('3. Options', { bold: true }), td('736', { align: 'right' }), td('124 utilisées', { align: 'right', bold: true }), td('Hors réductions. Mélange vraies options (MultiEcran HD, Prioritaire, IP fixe…), choix de frais de mise en service et choix par défaut (No Static IP)')],
    [td('4. Articles', { bold: true }), td('252 plans', { align: 'right' }), td('≈ 68 utilisés', { align: 'right', bold: true }), td('Hors plans d\'état technique (active, locked, closed…)')],
    [td('5. Réductions', { bold: true }), td('122', { align: 'right' }), td('20 utilisées', { align: 'right', bold: true }), td('Appliquées à 7 217 abonnements. 77 % portent sur une réduction expirée dans Smile : encore facturée ?')],
    [td('6. Abonnements', { bold: true }), td('186 402', { align: 'right' }), td('50 371', { align: 'right', bold: true }), td('Active ou Suspended. Exclus : 107 649 clôturés, 25 950 Self Care, 2 338 commandes en cours')],
  ], tableOpts(1.65, [2.9, 2.0, 2.3, 4.93], { rowH: 0.62 }));
  T.footer(s, 2);
}

// 5. Décisions actées
{
  const s = slide();
  T.header(pres, s, 'Décisions Lagoon du 27/10', 'À reporter dans le fichier de cadrage');
  s.addTable([
    [th('Sujet'), th('Décision'), th('Conséquence')],
    [td('Clés de rapprochement', { bold: true }), td('usn du compte pour les clients, usn de l\'abonnement pour les abonnements'), td('Uniques et toujours renseignés ; pas d\'ID de contrat (non utilisé dans Smile)')],
    [td('RIB et mandats SEPA', { bold: true }), td('Hors périmètre : déjà gérés dans So\'Bloo'), td('L\'import clients ne doit pas les écraser')],
    [td('Abonnements Self Care', { bold: true }), td('Accès au portail client, pas un abonnement'), td('25 950 non repris ; accès limité et revendeur portés par le client')],
    [td('Plans active, locked, closed, inactive, freesusp', { bold: true }), td('États techniques, pas des offres'), td('Non importés comme articles ; servent à déduire l\'état Suspendu')],
    [td('Contentieux', { bold: true }), td('Statut de recouvrement : la disposition Smile fait foi, pas le type de compte'), td('949 comptes ; 92 repris car ils ont un abonnement actif. Le type de compte Contentieux n\'est pas repris')],
    [td('Procuration', { bold: true }), td('À migrer'), td('Un contact avec procuration pour les clients repris : 14 437')],
  ], tableOpts(1.55, [3.6, 3.9, 4.63], { rowH: 0.72 }));
  T.footer(s, 3);
}

// 6. Onglet Clients
{
  const s = slide();
  T.header(pres, s, 'Onglet Clients : correspondance', '88 lignes du cadrage rapprochées des champs Smile (brouillon). Volumes sur les 26 264 clients à reprendre');
  const y = 1.75, h = 3.4, w = 3.85, g = 0.29;
  T.accentCard(s, pres, 0.6, y, w, h, 'Couvert par Smile',
    'Identité, e-mail (99 %)\nAdresse en texte libre\nRIDET : champ « ABN » (2 828)\nN° Conso+ (6 643)\nProcuration (14 437)\nLieu de naissance (6 560)\nAccès limité (51), revendeur (10)', C.GREEN);
  T.accentCard(s, pres, 0.6 + w + g, y, w, h, 'Absent de Smile',
    'Mobiles supplémentaires (champs vides)\nClient Chorus\nForme juridique, SIRET, APE, RCS\nCivilité (9 renseignées)\nHiérarchie parent / enfant', C.ORANGE);
  T.accentCard(s, pres, 0.6 + 2 * (w + g), y, w, h, 'Hors périmètre',
    'RIB (masqué dans Smile)\nRUM, date de signature, statut du mandat\nPrélèvement automatique\n\nDéjà gérés dans So\'Bloo depuis l\'import SEPA', C.GREY);
  T.footer(s, 4);
}

// 7. Qualité des données
{
  const s = slide();
  T.header(pres, s, 'À corriger dans Smile', 'Avant import, sur les 26 264 clients et 50 371 abonnements à reprendre');
  s.addTable([
    [th('Point à corriger'), th('Volume', { align: 'right' }), th('Pourquoi')],
    [td('N° Conso+ en double', { bold: true }), td('50', { align: 'right' }), td('Champ unique dans So\'Bloo : lignes bloquées à l\'import')],
    [td('Abonnements actifs sur le plan inactive', { bold: true }), td('68', { align: 'right' }), td('État de l\'abonnement incohérent')],
    [td('Comptes en contentieux avec abonnement actif', { bold: true }), td('92', { align: 'right' }), td('435 abonnements, dont 126 suspendus : un compte en contentieux ne devrait pas en avoir')],
    [td('Téléphones à 12 chiffres', { bold: true }), td('368', { align: 'right' }), td('Deux numéros saisis dans le même champ')],
    [td('RIDET au mauvais format', { bold: true }), td('2 165', { align: 'right' }), td('Sur 2 828 RIDET, seuls 663 respectent le format 1234567.001')],
    [td('E-mails au format invalide', { bold: true }), td('2', { align: 'right' }), td('Smile ne contrôle pas le format de l\'e-mail à la saisie')],
  ], tableOpts(1.55, [4.4, 1.5, 6.23], { rowH: 0.66 }));
  T.footer(s, 5);
}

// 8. Points à trancher
{
  const s = slide();
  T.header(pres, s, 'Points à trancher', 'Avant de valider l\'onglet Clients et de lancer le lot 6');
  const col = (x, title, items, accent) => {
    s.addText(title, { x, y: 1.7, w: 5.8, h: 0.45, fontFace: T.FONT, fontSize: 16, bold: true, color: C.BLUE, margin: 0 });
    T.accentLine(s, pres, x, 2.2);
    s.addText(items.map(t => ({ text: t, options: { bullet: { indent: 15 }, breakLine: true } })),
      { x, y: 2.4, w: 5.8, h: 4.3, fontFace: T.FONT, fontSize: 13, color: C.TEXT, valign: 'top', margin: 0, paraSpaceAfter: 10 });
  };
  col(0.6, 'Sobloo', [
    'Import clients sans écraser RIB et mandats SEPA',
    'Procuration : date et lieu de naissance du mandataire exigés, absents de Smile',
    'Catalogue : 1 service Smile = 1 famille d\'articles, 1 plan = 1 article ?',
    'Format des fichiers : CSV ou XLSX',
    'Date de bascule : dernière facturation Smile, première So\'Bloo ?',
  ]);
  col(6.9, 'Lagoon', [
    'Adresse de facturation : type 0 ou 1 (différentes pour 1 464 clients)',
    'Options : trier vraies options, choix de frais de mise en service et choix par défaut',
    'RIDET sans numéro d\'établissement',
    '65 « Compte Smile » avec abonnement actif : exclus ?',
    'Contentieux : quelle date reprendre ? (la disposition Smile n\'est pas datée)',
    'Contentieux sans abonnement actif : à reprendre pour le recouvrement ?',
    'Réductions expirées encore souscrites (5 653) : facturées ?',
  ]);
  T.footer(s, 6);
}

pres.writeFile({ fileName: OUT }).then(f => console.log('OK :', f));
