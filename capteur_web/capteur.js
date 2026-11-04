// Capteur de visage de Nuit Blanche, dans le navigateur : même travail que l'ancien
// tracker.py (MediaPipe Face + Pose), mêmes nombres envoyés au jeu, mais par WebSocket local.
// Le navigateur est un programme signé : le Contrôle intelligent des applications ne bloque rien.
// Aucune image ne quitte cette page.

import { FilesetResolver, FaceLandmarker, PoseLandmarker, HandLandmarker } from "./vision_bundle.mjs";

// La langue du jeu arrive dans l'adresse (?lang=en) ; le français est la langue source.
const LANG_EN = new URLSearchParams(location.search).get("lang") === "en";
const EN = {
  "Capteur — Nuit Blanche": "Sensor — Nuit Blanche",
  "Capteur de Nuit Blanche": "Nuit Blanche sensor",
  "Ta webcam est lue ici, sur ce PC. Aucune image ne part : seuls des nombres (yeux, tête, expressions) vont au jeu. Laisse cette fenêtre ouverte pendant que tu joues ; tu peux la mettre derrière le jeu.":
    "Your webcam is read here, on this PC. No image leaves it: only numbers (eyes, head, expressions) go to the game. Leave this window open while you play; you can put it behind the game.",
  "Démarrage…": "Starting…",
  "Caméra": "Camera",
  "Masquer l'aperçu": "Hide preview",
  "Montrer l'aperçu": "Show preview",
  "images/s": "frames/s",
  "Caméra refusée : clique sur l'icône de caméra dans la barre d'adresse et autorise-la.": "Camera refused: click the camera icon in the address bar and allow it.",
  "Aucune caméra disponible.": "No camera available.",
  "Je ne vois pas ton visage : mets-toi face à la caméra, bien éclairé.": "I can't see your face: face the camera, with good lighting.",
  "Visage détecté ✓ — le jeu reçoit tes yeux": "Face detected ✓ — the game is receiving your eyes",
  "Visage détecté, j'attends le jeu…": "Face detected, waiting for the game…",
  "Le jeu est fermé : webcam éteinte. Tu peux fermer cette fenêtre.": "The game is closed: webcam off. You can close this window.",
  "Chargement du suivi du visage…": "Loading face tracking…",
  "Autorise la caméra (une seule fois) dans le message du navigateur…": "Allow the camera (just once) in the browser's message…",
  "Caméra allumée, je cherche ton visage…": "Camera on, looking for your face…",
  "Le capteur n'a pas pu démarrer : ": "The sensor couldn't start: ",
};
const T = (fr) => (LANG_EN && EN[fr]) || fr;
if (LANG_EN) {
  document.documentElement.lang = "en";
  document.title = T(document.title);
  for (const el of document.querySelectorAll("h1, .note, #etat, #apercu")) el.textContent = T(el.textContent.trim());
  document.getElementById("cameras").title = T("Caméra");
}

const PORT_JEU = 4244;
const LARGEUR_ANALYSE = 1280;   // au-delà, MediaPipe ralentit sans gagner en précision
// Un membre n'est « vu » que si MediaPipe en est sûr ET qu'il est dans l'image : hors champ,
// il invente des coudes et des poignets (souvent levés) avec une confiance trompeuse.
const VISIBLE = 0.8;
const BORD = 0.03;               // marge du cadre (fraction de l'image)
const IMAGES_POUR_VOIR = 4;      // vu 4 images de suite avant d'être suivi…
const IMAGES_POUR_PERDRE = 3;    // …et perdu après 3 images douteuses
const ATTENTE_JEU_MS = 6000;    // jeu fermé depuis ce temps : on éteint la webcam

// Expressions transmises au jeu (noms MediaPipe / ARKit), comme tracker.py.
const EXPRESSIONS = new Set([
  "eyeBlinkLeft", "eyeBlinkRight", "eyeSquintLeft", "eyeSquintRight", "eyeWideLeft", "eyeWideRight",
  "eyeLookInLeft", "eyeLookOutLeft", "eyeLookUpLeft", "eyeLookDownLeft",
  "eyeLookInRight", "eyeLookOutRight", "eyeLookUpRight", "eyeLookDownRight",
  "jawOpen", "mouthSmileLeft", "mouthSmileRight", "mouthFrownLeft", "mouthFrownRight",
  "mouthPucker", "mouthFunnel", "cheekPuff", "browDownLeft", "browDownRight", "browInnerUp",
  "browOuterUpLeft", "browOuterUpRight", "tongueOut", "mouthLeft", "mouthRight",
  "noseSneerLeft", "noseSneerRight",
]);
// Repères (image retournée en miroir : « gauche » = gauche de l'écran).
const OEIL_A = { coin1: 33, coin2: 133, haut: 159, bas: 145, iris: 468, anneau: [469, 471] };
const OEIL_B = { coin1: 362, coin2: 263, haut: 386, bas: 374, iris: 473, anneau: [474, 476] };
// Corps : d'abord le côté DROIT de la personne, puis le gauche ; enfin le buste.
const SEGMENTS = [[12, 14], [14, 16], [11, 13], [13, 15], [24, 26], [26, 28], [23, 25], [25, 27]];

const $ = (id) => document.getElementById(id);
const video = $("video");
const toile = document.createElement("canvas");   // l'image en miroir, pour le visage
const ctx = toile.getContext("2d", { willReadFrequently: false });

let ws = null, jeuVu = 0, corpsActif = true, camerasListe = [], cameraIndex = 0;
let mainsDet = null;
let dernierVisage = null;   // repères du dernier visage vu (image en miroir), pour « Ma tête »
let visage = null, corpsDet = null, flux = null, dernierTemps = -1, dernierTs = -1;
let compte = 0, chrono = performance.now();
const debut = performance.now();

function etat(texte, classe = "") {
  const e = $("etat");
  e.textContent = T(texte);
  e.className = classe;
}

// ------------------------------------------------------------------ lien avec le jeu

function envoyer(msg) {
  if (ws && ws.readyState === WebSocket.OPEN) ws.send(JSON.stringify(msg));
}

function connecter() {
  ws = new WebSocket(`ws://127.0.0.1:${PORT_JEU}`);
  ws.onopen = () => { jeuVu = performance.now(); };
  ws.onmessage = async (ev) => {
    jeuVu = performance.now();
    let m;
    try { m = JSON.parse(ev.data); } catch { return; }
    if (m.cmd === "config") {
      corpsActif = !!m.corps;
    } else if (m.cmd === "camera_suivante" && camerasListe.length > 1) {
      await ouvrirCamera((cameraIndex + 1) % camerasListe.length);
    } else if (m.cmd === "photo") {
      prendrePhoto();
    } else if (m.cmd === "ping") {
      // le jeu est là
    }
  };
  ws.onclose = () => setTimeout(connecter, 1000);
  ws.onerror = () => {};
}

// ------------------------------------------------------------------ caméra

async function listerCameras() {
  const tous = await navigator.mediaDevices.enumerateDevices();
  camerasListe = tous.filter((d) => d.kind === "videoinput");
  const sel = $("cameras");
  sel.innerHTML = "";
  camerasListe.forEach((c, i) => {
    const o = document.createElement("option");
    o.value = i;
    o.textContent = c.label || `${T("Caméra")} ${i + 1}`;
    sel.appendChild(o);
  });
  sel.value = cameraIndex;
}

async function ouvrirCamera(index) {
  if (flux) flux.getTracks().forEach((t) => t.stop());
  const choix = camerasListe[index];
  const contraintes = { width: { ideal: 1280 }, height: { ideal: 720 }, frameRate: { ideal: 30 } };
  if (choix && choix.deviceId) contraintes.deviceId = { exact: choix.deviceId };
  try {
    flux = await navigator.mediaDevices.getUserMedia({ video: contraintes, audio: false });
  } catch (e) {
    flux = null;
    const refus = e && (e.name === "NotAllowedError" || e.name === "SecurityError");
    etat(refus ? "Caméra refusée : clique sur l'icône de caméra dans la barre d'adresse et autorise-la."
               : "Aucune caméra disponible.", "alerte");
    envoyer({ etat: "pas_de_camera" });
    return false;
  }
  video.srcObject = flux;
  await video.play().catch(() => {});
  if (!camerasListe.length || !camerasListe[0].label) await listerCameras();
  const id = flux.getVideoTracks()[0].getSettings().deviceId;
  const trouve = camerasListe.findIndex((c) => c.deviceId === id);
  cameraIndex = trouve >= 0 ? trouve : index;
  $("cameras").value = cameraIndex;
  try { localStorage.setItem("camera", camerasListe[cameraIndex]?.deviceId || ""); } catch {}
  return true;
}

// ------------------------------------------------------------------ mesures (portage de tracker.py)

class UnEuro {   // lisse le tremblement sans retarder les grands mouvements
  constructor(mincutoff = 1.2, beta = 0.02, dcutoff = 1.0) {
    Object.assign(this, { mincutoff, beta, dcutoff, x: null, dx: 0, t: null });
  }
  static alpha(cutoff, dt) { const tau = 1 / (2 * Math.PI * cutoff); return 1 / (1 + tau / dt); }
  filtrer(x, t) {
    if (this.x === null) { this.x = x; this.t = t; return x; }
    const dt = Math.max(t - this.t, 1e-3);
    this.t = t;
    const dx = (x - this.x) / dt;
    const ad = UnEuro.alpha(this.dcutoff, dt);
    this.dx = ad * dx + (1 - ad) * this.dx;
    const a = UnEuro.alpha(this.mincutoff + this.beta * Math.abs(this.dx), dt);
    this.x = a * x + (1 - a) * this.x;
    return this.x;
  }
}
const filtres = Object.fromEntries(["gx", "gy", "tx", "ty", "roulis", "iris"].map((k) => [k, new UnEuro()]));

const sous = (a, b) => [a[0] - b[0], a[1] - b[1]];
const norme = (a) => Math.hypot(a[0], a[1]);
const scal = (a, b) => a[0] * b[0] + a[1] * b[1];
const milieu = (a, b) => [(a[0] + b[0]) / 2, (a[1] + b[1]) / 2];

function teteParReperes(p) {
  const g = p[234], d = p[454];
  const largeur = Math.max(norme(sous(d, g)), 1e-6);
  const m = milieu(g, d), nez = p[1], yeux = milieu(p[33], p[263]), menton = p[152];
  const tx = (nez[0] - m[0]) / largeur;
  const ty = (nez[1] - yeux[1]) / Math.max(menton[1] - yeux[1], 1e-6);
  const [a, b] = p[33][0] < p[263][0] ? [p[33], p[263]] : [p[263], p[33]];
  const roulis = Math.atan2(b[1] - a[1], b[0] - a[0]) * 180 / Math.PI;
  return [tx, ty, roulis];
}

function regardOeil(p, o) {
  const c1 = p[o.coin1], c2 = p[o.coin2];
  const axe = sous(c2, c1), longueur = norme(axe);
  if (longueur < 1e-6) return [0.5, 0.5];
  const ux = [axe[0] / longueur, axe[1] / longueur], uy = [-ux[1], ux[0]];
  const x = scal(sous(p[o.iris], c1), ux) / longueur;
  const mil = milieu(c1, c2);
  const h = scal(sous(p[o.haut], mil), uy), b = scal(sous(p[o.bas], mil), uy);
  const yi = scal(sous(p[o.iris], mil), uy);
  const y = Math.abs(b - h) > 1e-6 ? (yi - h) / (b - h) : 0.5;
  return [x, y];
}

const suiteVue = new Array(9).fill(0), suitePerdue = new Array(9).fill(0), suivi = new Array(9).fill(false);
const filtresCorps = Array.from({ length: 27 }, () => new UnEuro(1.0, 0.05));
let dernierCorps = null;

// Hystérésis : un membre ne s'allume pas sur une seule image chanceuse, ni ne s'éteint sur un raté.
function stabiliser(i, brut) {
  if (brut) { suiteVue[i]++; suitePerdue[i] = 0; } else { suitePerdue[i]++; suiteVue[i] = 0; }
  if (!suivi[i] && suiteVue[i] >= IMAGES_POUR_VOIR) suivi[i] = true;
  if (suivi[i] && suitePerdue[i] >= IMAGES_POUR_PERDRE) suivi[i] = false;
  return suivi[i];
}

function lireCorps(res, t) {
  if (!res || !res.worldLandmarks || !res.worldLandmarks.length) {
    for (let i = 0; i < 9; i++) stabiliser(i, false);
    dernierCorps = null;
    return null;
  }
  const w = res.worldLandmarks[0], im = res.landmarks[0];
  const v = (i) => [w[i].x, -w[i].y, -w[i].z];
  const dedans = (i) => im[i].x > BORD && im[i].x < 1 - BORD && im[i].y > BORD && im[i].y < 1 - BORD;
  const sur = (i) => Math.min(im[i].visibility ?? 0, im[i].presence ?? 1) > VISIBLE && dedans(i);
  const sortie = [];
  const pieces = SEGMENTS.map(([a, b]) => [v(a), v(b), sur(a) && sur(b)]);
  // L'avant-bras (ou le tibia) n'a de sens que si le haut du membre est vu.
  for (const k of [1, 3, 5, 7]) pieces[k][2] = pieces[k][2] && pieces[k - 1][2];
  const moy = (i, j) => v(i).map((x, k) => (x + v(j)[k]) / 2);
  pieces.push([moy(23, 24), moy(11, 12), sur(11) && sur(12) && Math.min(im[23].visibility ?? 0, im[24].visibility ?? 0) > 0.5]);
  pieces.forEach(([pa, pb, brut], i) => {
    let d = [pb[0] - pa[0], pb[1] - pa[1], pb[2] - pa[2]];
    const n = Math.hypot(...d);
    let ok = stabiliser(i, brut && n > 1e-6);
    if (n < 1e-6) { d = [0, 0, 0]; ok = false; } else d = d.map((x, k) => filtresCorps[i * 3 + k].filtrer(x / n, t));
    const m = Math.hypot(...d) || 1;
    sortie.push(+(d[0] / m).toFixed(3), +(d[1] / m).toFixed(3), +(d[2] / m).toFixed(3), ok ? 1 : 0);
  });
  dernierCorps = im;
  return sortie;
}

// ------------------------------------------------------------------ mains et doigts
// Par main (droite de la personne d'abord, puis gauche) : vue, direction de la main (poignet →
// base du majeur), normale de la paume, puis 3 angles de pliure par doigt (pouce → auriculaire),
// en radians. 22 nombres par main, 44 en tout.
const DOIGTS = [[1, 2, 3, 4], [5, 6, 7, 8], [9, 10, 11, 12], [13, 14, 15, 16], [17, 18, 19, 20]];
const filtresMains = Array.from({ length: 44 }, () => new UnEuro(1.5, 0.08));
const suiteMain = [0, 0], suiviMain = [false, false];

function angle(a, b) {
  const na = Math.hypot(...a), nb = Math.hypot(...b);
  if (na < 1e-9 || nb < 1e-9) return 0;
  return Math.acos(Math.max(-1, Math.min(1, (a[0] * b[0] + a[1] * b[1] + a[2] * b[2]) / (na * nb))));
}
const moins = (a, b) => [a[0] - b[0], a[1] - b[1], a[2] - b[2]];
const croix = (a, b) => [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]];
const unite = (a) => { const n = Math.hypot(...a) || 1; return a.map((x) => x / n); };

function lireMains(res, t) {
  const sortie = new Array(44).fill(0);
  const trouvees = [null, null];
  if (res && res.worldLandmarks) {
    res.worldLandmarks.forEach((wl, k) => {
      const im = res.landmarks[k];
      // Quelle main ? Le poignet le plus proche de celui que voit le suivi du corps (16 : droit, 15 : gauche) ;
      // à défaut, l'étiquette de MediaPipe (qui suppose une image en miroir : « Left » = main droite ici).
      let cote = (res.handednesses?.[k]?.[0]?.categoryName ?? res.handedness?.[k]?.[0]?.categoryName) === "Left" ? 0 : 1;
      if (dernierCorps) {
        const d = (i) => Math.hypot(dernierCorps[i].x - im[0].x, dernierCorps[i].y - im[0].y);
        cote = d(16) <= d(15) ? 0 : 1;
      }
      if (!trouvees[cote]) trouvees[cote] = { wl, im };
    });
  }
  for (let c = 0; c < 2; c++) {
    const m = trouvees[c];
    const vue = !!m && m.im.every((q) => q.x > 0 && q.x < 1 && q.y > 0 && q.y < 1);
    suiteMain[c] = vue ? suiteMain[c] + 1 : 0;
    suiviMain[c] = suiviMain[c] ? vue : suiteMain[c] >= 3;
    if (!suiviMain[c]) continue;
    const p = m.wl.map((q) => [q.x, -q.y, -q.z]);
    const base = c * 22;
    const f = (i, x) => filtresMains[base + i].filtrer(x, t);
    const dir = unite(moins(p[9], p[0]));
    let normale = unite(croix(moins(p[5], p[0]), moins(p[17], p[0])));
    if (c === 1) normale = normale.map((x) => -x);      // main gauche : la paume est de l'autre côté
    sortie[base] = 1;
    [...dir, ...normale].forEach((x, i) => { sortie[base + 1 + i] = +f(i, x).toFixed(3); });
    DOIGTS.forEach((doigt, d) => {
      const pts = [p[0], ...doigt.map((i) => p[i])];
      for (let j = 0; j < 3; j++) {
        const a = angle(moins(pts[j + 1], pts[j]), moins(pts[j + 2], pts[j + 1]));
        sortie[base + 7 + d * 3 + j] = +f(6 + d * 3 + j, a).toFixed(3);
      }
    });
  }
  return suiviMain[0] || suiviMain[1] ? sortie : null;
}

const r = (x, n) => +x.toFixed(n);

function analyser() {
  if (!flux || video.readyState < 2 || video.currentTime === dernierTemps) return;
  dernierTemps = video.currentTime;
  const vw = video.videoWidth, vh = video.videoHeight;
  if (!vw || !vh) return;
  const echelle = Math.min(1, LARGEUR_ANALYSE / vw);
  const w = Math.round(vw * echelle), h = Math.round(vh * echelle);
  if (toile.width !== w || toile.height !== h) { toile.width = w; toile.height = h; }
  // Miroir : bouger à gauche fait bouger à gauche (comme tracker.py, qui retournait l'image).
  ctx.setTransform(-1, 0, 0, 1, w, 0);
  ctx.drawImage(video, 0, 0, w, h);
  const t = (performance.now() - debut) / 1000;
  let ts = Math.round(performance.now());
  if (ts <= dernierTs) ts = dernierTs + 1;
  dernierTs = ts;

  const res = visage.detectForVideo(toile, ts);
  // Le corps se lit sur l'image NON retournée : MediaPipe y nomme droite et gauche
  // comme la personne elle-même.
  const corps = corpsActif && corpsDet ? lireCorps(corpsDet.detectForVideo(video, ts), t) : null;
  const mains = corpsActif && mainsDet ? lireMains(mainsDet.detectForVideo(video, ts), t) : null;
  compte++;

  if (!res.faceLandmarks || !res.faceLandmarks.length) {
    envoyer({ etat: "pas_de_visage", t, corps, mains });
    etat("Je ne vois pas ton visage : mets-toi face à la caméra, bien éclairé.", "alerte");
    return;
  }
  const p = res.faceLandmarks[0].map((q) => [q.x * w, q.y * h]);
  dernierVisage = { p, w, h, quand: performance.now() };
  const bs = {};
  for (const c of res.faceBlendshapes[0].categories) {
    if (EXPRESSIONS.has(c.categoryName)) bs[c.categoryName] = r(c.score, 4);
  }
  const [tx, ty, roulis] = teteParReperes(p);
  const [ax, ay] = regardOeil(p, OEIL_A), [bx, by] = regardOeil(p, OEIL_B);
  const iris = (norme(sous(p[OEIL_A.anneau[0]], p[OEIL_A.anneau[1]])) + norme(sous(p[OEIL_B.anneau[0]], p[OEIL_B.anneau[1]]))) / 2;
  envoyer({
    etat: "ok", t: r(t, 3), bs,
    gx: r(filtres.gx.filtrer((ax + bx) / 2, t), 4),
    gy: r(filtres.gy.filtrer((ay + by) / 2, t), 4),
    tx: r(filtres.tx.filtrer(tx, t), 4),
    ty: r(filtres.ty.filtrer(ty, t), 4),
    roulis: r(filtres.roulis.filtrer(roulis, t), 2),
    camera: cameraIndex,
    iris_px: r(filtres.iris.filtrer(iris, t), 2),
    img_w: w, img_h: h, corps, mains,
  });
  etat(ws && ws.readyState === WebSocket.OPEN ? "Visage détecté ✓ — le jeu reçoit tes yeux" : "Visage détecté, j'attends le jeu…",
       ws && ws.readyState === WebSocket.OPEN ? "ok" : "");
}

// « Ma tête » : le visage découpé dans l'image en cours, remis à l'endroit (les autres te voient
// de face, pas en miroir), et la place des yeux et de la bouche dans la photo. Envoyé au jeu
// seulement, qui la garde sur ce PC.
function prendrePhoto() {
  const v = dernierVisage;
  if (!v || performance.now() - v.quand > 500) {
    envoyer({ photo_ratee: "Je ne vois pas ton visage : mets-toi bien en face, éclairé." });
    return;
  }
  const p = v.p;
  const xs = p.map((q) => q[0]), ys = p.map((q) => q[1]);
  const gauche = Math.min(...xs), droite = Math.max(...xs), haut = Math.min(...ys), bas = Math.max(...ys);
  const L = (droite - gauche) * 1.08, H = (bas - haut) * 1.12;
  const cx = (gauche + droite) / 2, cy = (haut + bas) / 2 - (bas - haut) * 0.02;
  const W = 192, Hs = 236;
  const sortie = document.createElement("canvas");
  sortie.width = W; sortie.height = Hs;
  const c2 = sortie.getContext("2d");
  c2.setTransform(-1, 0, 0, 1, W, 0);          // à l'endroit
  c2.drawImage(toile, cx - L / 2, cy - H / 2, L, H, 0, 0, W, Hs);
  // Repères dans la photo (0..1), x retourné comme l'image.
  const u = (q) => 1 - (q[0] - (cx - L / 2)) / L, w2 = (q) => (q[1] - (cy - H / 2)) / H;
  const oeil = (o) => { const m = milieu(p[o.coin1], p[o.coin2]); return [u(m), w2(m), norme(sous(p[o.coin1], p[o.coin2])) / L]; };
  let a = oeil(OEIL_A), b = oeil(OEIL_B);
  if (a[0] > b[0]) [a, b] = [b, a];
  const bouche = milieu(p[13], p[14]);
  const r3 = (x) => Math.round(Math.min(Math.max(x, 0), 1) * 1000) / 1000;
  const jpeg = sortie.toDataURL("image/jpeg", 0.85).split(",")[1];
  envoyer({
    photo: jpeg,
    reperes: { ax: r3(a[0]), ay: r3(a[1]), bx: r3(b[0]), by: r3(b[1]), ol: r3((a[2] + b[2]) / 2),
               mx: r3(u(bouche)), my: r3(w2(bouche)), ml: r3(norme(sous(p[61], p[291])) / L) },
  });
}

// Boucle par minuterie, pas par requestAnimationFrame : elle continue quand la fenêtre
// est derrière le jeu (le jeu lance le navigateur sans le ralentissement des fenêtres cachées).
function boucle() {
  try { analyser(); } catch (e) { console.error(e); }
  const maintenant = performance.now();
  if (maintenant - chrono >= 1000) {
    $("ips").textContent = `${Math.round(compte * 1000 / (maintenant - chrono))} ${T("images/s")}`;
    compte = 0;
    chrono = maintenant;
  }
  // Le jeu fermé depuis un moment : on éteint la webcam.
  if (flux && jeuVu && maintenant - jeuVu > ATTENTE_JEU_MS && !(ws && ws.readyState === WebSocket.OPEN)) {
    flux.getTracks().forEach((t) => t.stop());
    flux = null;
    etat("Le jeu est fermé : webcam éteinte. Tu peux fermer cette fenêtre.");
    window.close();
  }
  setTimeout(boucle, 10);
}

// ------------------------------------------------------------------ démarrage

async function demarrer() {
  connecter();
  $("apercu").onclick = () => {
    video.classList.toggle("cache");
    $("apercu").textContent = video.classList.contains("cache") ? T("Montrer l'aperçu") : T("Masquer l'aperçu");
  };
  $("cameras").onchange = (e) => ouvrirCamera(+e.target.value);
  etat("Chargement du suivi du visage…");
  const base = new URL("./wasm", location.href).href;
  const fichiers = await FilesetResolver.forVisionTasks(base);
  const creer = async (Classe, options) => {
    try {
      return await Classe.createFromOptions(fichiers, { ...options, baseOptions: { ...options.baseOptions, delegate: "GPU" } });
    } catch {
      return await Classe.createFromOptions(fichiers, { ...options, baseOptions: { ...options.baseOptions, delegate: "CPU" } });
    }
  };
  visage = await creer(FaceLandmarker, {
    baseOptions: { modelAssetPath: "face_landmarker.task" },
    runningMode: "VIDEO", numFaces: 1,
    outputFaceBlendshapes: true, outputFacialTransformationMatrixes: true,
  });
  corpsDet = await creer(PoseLandmarker, {
    baseOptions: { modelAssetPath: "pose_landmarker_lite.task" },
    runningMode: "VIDEO", numPoses: 1,
  });
  try {
    mainsDet = await creer(HandLandmarker, {
      baseOptions: { modelAssetPath: "hand_landmarker.task" },
      runningMode: "VIDEO", numHands: 2,
    });
  } catch (e) { console.error(e); }   // sans les doigts, le reste marche
  etat("Autorise la caméra (une seule fois) dans le message du navigateur…");
  envoyer({ etat: "recherche_camera" });
  await listerCameras();
  let memo = "";
  try { memo = localStorage.getItem("camera") || ""; } catch {}
  const i = camerasListe.findIndex((c) => c.deviceId && c.deviceId === memo);
  if (await ouvrirCamera(i >= 0 ? i : 0)) etat("Caméra allumée, je cherche ton visage…");
  boucle();
}

demarrer().catch((e) => {
  console.error(e);
  etat(T("Le capteur n'a pas pu démarrer : ") + (e && e.message ? e.message : e), "alerte");
});
