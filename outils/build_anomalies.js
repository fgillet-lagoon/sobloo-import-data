// Construit le classeur des anomalies à corriger dans Smile à partir des CSV de data/anomalies/.
// Usage : psql -X -f sql/anomalies_a_corriger.sql (depuis la racine), puis cd outils && node build_anomalies.js ../data/anomalies

// N'affiche que des comptages : les fichiers contiennent des données personnelles.
const fs = require('fs');
const path = require('path');
const ExcelJS = require('exceljs');

const DIR = process.argv[2];
const OUT = path.join(DIR, '2026-10-27_Anomalies_Smile_a_corriger.xlsx');
const BLUE = 'FF06539D', ORANGE = 'FFEB692E', LIGHT = 'FFF5F7FA';
const NUMERIC = new Set(['Comptes avec ce numéro', 'Abonnements actifs', 'dont suspendus', 'Nombre de chiffres']);

// Lecteur CSV RFC 4180 (guillemets, virgules et retours à la ligne dans les valeurs)
function parseCsv(text) {
  const rows = []; let row = [], field = '', quoted = false;
  for (let i = 0; i < text.length; i++) {
    const c = text[i];
    if (quoted) {
      if (c === '"' && text[i + 1] === '"') { field += '"'; i++; }
      else if (c === '"') quoted = false;
      else field += c;
    } else if (c === '"') quoted = true;
    else if (c === ',') { row.push(field); field = ''; }
    else if (c === '\n') { row.push(field); rows.push(row); row = []; field = ''; }
    else if (c !== '\r') field += c;
  }
  if (field !== '' || row.length) { row.push(field); rows.push(row); }
  return rows;
}

const ONGLETS = [
  { fichier: '1_conso_plus_doublons.csv', nom: '1 N° Conso+ en double',
    consigne: 'Le N° Conso+ est unique dans So\'Bloo : un même numéro sur plusieurs comptes bloque l\'import. Garder le numéro sur le bon compte, le retirer ou le corriger sur les autres.' },
  { fichier: '2_abonnements_plan_inactive.csv', nom: '2 Abonnements plan inactive',
    consigne: 'Abonnement actif dont le plan en cours est « inactive » : clôturer l\'abonnement ou lui remettre le bon plan.' },
  { fichier: '3_contentieux_abonnement_actif.csv', nom: '3 Contentieux actifs',
    consigne: 'Compte en contentieux (disposition) qui a encore des abonnements actifs : vérifier et clôturer ou suspendre les abonnements, ou corriger la disposition.' },
  { fichier: '4_telephones.csv', nom: '4 Téléphones',
    consigne: 'Un seul numéro par champ : 6 chiffres (NC), 8 (Polynésie) ou 10 (métropole). Les numéros à 12 chiffres contiennent sans doute deux numéros : garder le principal.' },
  { fichier: '5_ridet_format.csv', nom: '5 RIDET',
    consigne: 'Saisir le RIDET au format 1234567.001 (7 chiffres, point, 3 chiffres d\'établissement). La proposition est calculée à partir des chiffres saisis : à vérifier avant de la reporter.' },
  { fichier: '6_emails_invalides.csv', nom: '6 E-mails',
    consigne: 'E-mail au format invalide (Smile ne contrôle pas la saisie) : corriger ou vider le champ.' },
];

(async () => {
  const wb = new ExcelJS.Workbook();
  wb.creator = 'Lagoon';
  wb.created = new Date();

  // Onglet de présentation, rempli après lecture des CSV
  const lisez = wb.addWorksheet('Lisez-moi', { properties: { tabColor: { argb: ORANGE } } });

  const comptes = [];
  for (const o of ONGLETS) {
    const rows = parseCsv(fs.readFileSync(path.join(DIR, o.fichier), 'utf8'));
    const entete = [...rows[0], 'Corrigé (oui / non)', 'Commentaire'];
    const data = rows.slice(1).filter(r => r.length > 1 || r[0] !== '');
    comptes.push({ ...o, n: data.length });

    const ws = wb.addWorksheet(o.nom, { views: [{ state: 'frozen', ySplit: 2 }] });
    ws.mergeCells(1, 1, 1, entete.length);
    const c1 = ws.getCell(1, 1);
    c1.value = o.consigne;
    c1.font = { italic: true, color: { argb: 'FF2F2F2F' } };
    c1.alignment = { wrapText: true, vertical: 'middle' };
    ws.getRow(1).height = 36;

    const h = ws.getRow(2);
    h.values = entete;
    h.eachCell(c => {
      c.font = { bold: true, color: { argb: 'FFFFFFFF' } };
      c.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: BLUE } };
      c.alignment = { vertical: 'middle', wrapText: true };
    });
    h.height = 30;

    for (const r of data) {
      // Texte par défaut (usn, téléphones, RIDET : pas de zéro de tête perdu) ; nombres pour les comptages
      ws.addRow(entete.map((col, i) => (NUMERIC.has(col) && r[i] !== '' && r[i] !== undefined) ? Number(r[i]) : (r[i] ?? '')));
    }
    ws.autoFilter = { from: { row: 2, column: 1 }, to: { row: 2, column: entete.length } };
    entete.forEach((col, i) => {
      const max = Math.max(col.length, ...data.slice(0, 500).map(r => (r[i] || '').length));
      ws.getColumn(i + 1).width = Math.min(Math.max(max + 2, 12), col === 'usn des abonnements' ? 60 : 40);
    });
  }

  lisez.getColumn(1).width = 34; lisez.getColumn(2).width = 12; lisez.getColumn(3).width = 110;
  lisez.getCell('A1').value = 'Anomalies à corriger dans Smile avant la reprise vers So\'Bloo';
  lisez.getCell('A1').font = { bold: true, size: 16, color: { argb: BLUE } };
  const lignes = [
    `Extraction du ${new Date().toLocaleDateString('fr-FR')} depuis Smile (base lagoon.nc, réplique en lecture seule).`,
    'Périmètre : clients et abonnements à reprendre (abonnement Active ou Suspended, hors Self Care, hors plan inactive).',
    'Les corrections se font dans Smile, jamais dans ce fichier : il sera régénéré après corrections pour vérifier qu\'il ne reste rien.',
    'Colonnes « Corrigé » et « Commentaire » : pour le suivi par les opérateurs.',
    'Document confidentiel : il contient des données personnelles. Ne pas le diffuser hors de Lagoon ni le déposer sur un espace partagé externe.',
  ];
  lignes.forEach((t, i) => { lisez.getCell(`A${3 + i}`).value = t; lisez.mergeCells(`A${3 + i}:C${3 + i}`); });
  lisez.getCell('A7').font = { bold: true, color: { argb: ORANGE } };

  const hr = lisez.getRow(9);
  hr.values = ['Onglet', 'Lignes', 'Correction attendue'];
  hr.eachCell(c => { c.font = { bold: true, color: { argb: 'FFFFFFFF' } }; c.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: BLUE } }; });
  comptes.forEach((o, i) => {
    const r = lisez.getRow(10 + i);
    r.values = [o.nom, o.n, o.consigne];
    r.getCell(3).alignment = { wrapText: true, vertical: 'top' };
    r.getCell(1).alignment = { vertical: 'top' };
    r.getCell(2).alignment = { vertical: 'top' };
    if (i % 2 === 0) r.eachCell(c => { c.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: LIGHT } }; });
  });

  await wb.xlsx.writeFile(OUT);
  console.log('OK :', OUT);
  comptes.forEach(o => console.log(`  ${o.nom} : ${o.n} lignes`));
})();
