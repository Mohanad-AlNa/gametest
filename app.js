/* ═══════════════════════════════════════════════════════════════════════════
   ECHO Game – Frontend (app.js)
   P2P Architecture: Host runs game logic in the browser.
   Guests connect via PeerJS (WebRTC DataChannels).
   No server required for gameplay – PeerJS signaling handles the handshake.
   ═══════════════════════════════════════════════════════════════════════════ */

'use strict';

// ─── Constants ───────────────────────────────────────────────────────────────
const TOTAL_ROUNDS  = 8;
const ANSWER_TIME   = 30; // seconds
const CODE_CHARS    = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
const PEER_PREFIX   = 'echogame-'; // prefix for host peer IDs

const CATEGORIES = [
  { ar: 'أشياء حمراء اللون',           en: 'Things that are red' },
  { ar: 'حيوانات لها أربعة أرجل',       en: 'Animals with four legs' },
  { ar: 'أشياء في المطبخ',              en: 'Things found in a kitchen' },
  { ar: 'أشياء تستطيع الطيران',         en: 'Things that can fly' },
  { ar: 'رياضات وألعاب',               en: 'Sports and games' },
  { ar: 'أشياء باردة',                  en: 'Things that are cold' },
  { ar: 'أشياء في الفصل الدراسي',       en: 'Things in a classroom' },
  { ar: 'أطعمة حلوة',                  en: 'Sweet foods' },
  { ar: 'آلات موسيقية',                en: 'Musical instruments' },
  { ar: 'أشياء على الشاطئ',            en: 'Things at the beach' },
  { ar: 'دول عربية',                   en: 'Arab countries' },
  { ar: 'أشياء كروية الشكل',            en: 'Round things' },
  { ar: 'أفلام مشهورة',                en: 'Famous movies' },
  { ar: 'أبطال خارقون',                en: 'Superheroes' },
  { ar: 'أشياء في الطبيعة',             en: 'Things in nature' },
  { ar: 'أشياء تصدر صوتاً',            en: 'Things that make sound' },
  { ar: 'أشياء في الفضاء الخارجي',      en: 'Things in outer space' },
  { ar: 'مدن عالمية مشهورة',            en: 'Famous world cities' },
  { ar: 'أنواع المركبات',               en: 'Types of vehicles' },
  { ar: 'أشياء بيضاء',                 en: 'Things that are white' },
  { ar: 'فواكه',                        en: 'Fruits' },
  { ar: 'شخصيات كرتونية',              en: 'Cartoon characters' },
  { ar: 'أشياء في الحفلات',             en: 'Things at a party' },
  { ar: 'أشياء تفعلها كل صباح',         en: 'Things you do every morning' },
  { ar: 'أشياء زرقاء',                  en: 'Things that are blue' },
  { ar: 'معالم سياحية مشهورة',          en: 'Famous landmarks' },
  { ar: 'أشياء في المستشفى',            en: 'Things in a hospital' },
  { ar: 'أشياء تفعلها في المدرسة',       en: 'Things you do at school' },
  { ar: 'أشياء ذات رائحة جميلة',        en: 'Things that smell good' },
  { ar: 'أشياء ثقيلة',                  en: 'Heavy things' },
];

// ─── Global state ─────────────────────────────────────────────────────────────
let peer       = null;   // PeerJS instance (this player's peer)
let hostConn   = null;   // Guest's connection to the host
let guestConns = {};     // Host's map: guestPeerId → DataConnection

let myPeerId  = '';      // This player's PeerJS ID
let myName    = '';
let lobbyCode = '';
let isHost    = false;

// Host-only game state
const lobby = {
  players:         [],   // { id, name, score, isHost }
  gameStatus:      'waiting',
  currentRound:    0,
  teamScore:       0,
  categories:      [],
  currentCategory: null,
  answers:         {},   // peerId → answer string
  timer:           null,
};

// Timer (client-side countdown)
let timerInterval = null;
const TIMER_CIRCLE_RADIUS = 52;
const CIRCUMFERENCE       = 2 * Math.PI * TIMER_CIRCLE_RADIUS; // ≈ 326.73

let toastTimer;

// ─── DOM shortcuts ─────────────────────────────────────────────────────────────
const $ = id => document.getElementById(id);

// ─── Utilities ────────────────────────────────────────────────────────────────
function randomCode() {
  return Array.from({ length: 4 }, () =>
    CODE_CHARS[Math.floor(Math.random() * CODE_CHARS.length)]
  ).join('');
}

function shuffle(arr) {
  const a = [...arr];
  for (let i = a.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [a[i], a[j]] = [a[j], a[i]];
  }
  return a;
}

function escHtml(s) {
  return String(s)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

const AVATAR_COLORS = ['#7c3aed','#06b6d4','#10b981','#f59e0b',
                       '#f43f5e','#8b5cf6','#0ea5e9','#ec4899'];
const getColor   = i  => AVATAR_COLORS[i % AVATAR_COLORS.length];
const getInitial = nm => (nm || '?').charAt(0).toUpperCase();

// ─── PeerJS options ───────────────────────────────────────────────────────────
// When the app is served from a local IP + port (LAN self-hosting),
// use the bundled signaling server on the same host.
// Otherwise fall back to the public PeerJS cloud server.
function makePeerOptions() {
  const h = location.hostname;
  const isLocal =
    h === 'localhost' ||
    h === '127.0.0.1' ||
    /^10\.\d+\.\d+\.\d+$/.test(h) ||
    /^172\.(1[6-9]|2\d|3[01])\.\d+\.\d+$/.test(h) ||
    /^192\.168\.\d+\.\d+$/.test(h);

  if (isLocal && location.port) {
    return {
      host:   h,
      port:   parseInt(location.port, 10),
      path:   '/peerjs',
      secure: location.protocol === 'https:',
    };
  }
  return {}; // public PeerJS cloud
}

// ─── UI helpers ───────────────────────────────────────────────────────────────
function showScreen(id) {
  document.querySelectorAll('.screen').forEach(s => s.classList.remove('active'));
  const el = $(id);
  if (el) el.classList.add('active');
  window.scrollTo({ top: 0, behavior: 'smooth' });
}

function showToast(msg, type = '') {
  const t = $('toast');
  t.textContent = msg;
  t.className   = `toast ${type}`;
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => t.classList.add('hidden'), 3500);
}

// ─── Timer ────────────────────────────────────────────────────────────────────
function startTimer(seconds) {
  clearInterval(timerInterval);
  let left = seconds;
  const ring  = $('t-ring');
  const numEl = $('lbl-timer');

  function tick() {
    const offset = CIRCUMFERENCE * (1 - left / seconds);
    ring.setAttribute('stroke-dashoffset', String(offset));
    numEl.textContent = left;

    if (left <= 5)       { numEl.style.color = '#f43f5e'; ring.style.stroke = '#f43f5e'; }
    else if (left <= 10) { numEl.style.color = '#f59e0b'; ring.style.stroke = '#f59e0b'; }
    else                 { numEl.style.color = '';         ring.style.stroke = 'url(#timerGrad)'; }

    if (left > 0) left--;
    else clearInterval(timerInterval);
  }
  tick();
  timerInterval = setInterval(tick, 1000);
}

function stopTimer() {
  clearInterval(timerInterval);
}

// ─── Render players (lobby) ───────────────────────────────────────────────────
function renderPlayers(players) {
  const list = $('players-list');
  list.innerHTML = '';
  players.forEach((p, i) => {
    const card = document.createElement('div');
    card.className = 'player-card';
    card.innerHTML = `
      <div class="p-avatar" style="background:${getColor(i)}">${escHtml(getInitial(p.name))}</div>
      <div class="p-name">${escHtml(p.name)}</div>
      ${p.isHost ? '<span class="host-badge">👑 مضيف</span>' : ''}
    `;
    list.appendChild(card);
  });
}

// ─── Game event handlers (UI) ─────────────────────────────────────────────────
// All event handlers receive plain data objects (same shape as original Socket.io events).

function onLobbyUpdate({ players, gameState }) {
  const me = players.find(p => p.id === myPeerId);
  isHost = me?.isHost ?? false;

  renderPlayers(players);
  $('lobby-host-area').classList.toggle('hidden', !isHost);
  $('lobby-guest-area').classList.toggle('hidden', isHost);

  $('btn-start').disabled = players.length < 2;

  if (gameState === 'waiting') showScreen('s-lobby');
}

function onRoundStart({ round, totalRounds, category, timeLimit, teamScore }) {
  stopTimer();
  showScreen('s-playing');

  $('lbl-round').textContent  = `الجولة ${round} / ${totalRounds}`;
  $('lbl-tscore').textContent = `${teamScore} نقطة`;
  $('lbl-cat-ar').textContent = category.ar;
  $('lbl-cat-en').textContent = category.en;

  $('inp-answer').value = '';
  $('answer-area').classList.remove('hidden');
  $('answered-msg').classList.add('hidden');
  $('prog-bar').style.width  = '0%';
  $('prog-text').textContent = `0 من 0 لاعب أجاب`;

  $('t-ring').setAttribute('stroke-dashoffset', '0');
  $('t-ring').style.stroke   = 'url(#timerGrad)';
  $('lbl-timer').style.color = '';

  $('inp-answer').focus();
  startTimer(timeLimit);
}

function onPlayerAnswered({ answered, total }) {
  const pct = total > 0 ? (answered / total) * 100 : 0;
  $('prog-bar').style.width  = `${pct}%`;
  $('prog-text').textContent = `${answered} من ${total} لاعب أجاب`;
}

function onRoundReveal({
  category, playerResults, matchGroups,
  roundScore, syncLevel, teamScore,
  round, totalRounds, isLastRound,
}) {
  stopTimer();
  showScreen('s-reveal');

  const SYNC_CFG = {
    PERFECT: { cls: 'sync-perfect', text: '⚡ مزامنة كاملة! PERFECT SYNC!' },
    GREAT:   { cls: 'sync-great',   text: '🔥 تزامن رائع! Great Sync!'     },
    GOOD:    { cls: 'sync-good',    text: '👍 تزامن جيد! Good Sync!'        },
    LOW:     { cls: 'sync-low',     text: '💪 يمكنكم الأفضل! Keep Trying!' },
    MISS:    { cls: 'sync-miss',    text: '😅 لا تطابق! No Match!'          },
  };
  const cfg    = SYNC_CFG[syncLevel] || SYNC_CFG.MISS;
  const banner = $('sync-banner');
  banner.className   = `sync-banner ${cfg.cls}`;
  banner.textContent = cfg.text;

  $('rev-cat').textContent         = category.ar;
  $('rev-round-score').textContent = roundScore > 0
    ? `+${roundScore} نقطة للفريق!`
    : 'لا نقاط هذه الجولة';
  $('rev-round-score').style.color = roundScore > 0
    ? 'var(--green)' : 'var(--w40)';

  const board = $('answers-board');
  board.innerHTML = '';
  playerResults.forEach((r, i) => {
    const cell = document.createElement('div');
    cell.className = `answer-cell ${r.matched ? 'matched' : ''} ${!r.answer ? 'no-answer' : ''}`;
    cell.style.animationDelay = `${i * 0.07}s`;
    cell.innerHTML = `
      <div class="ac-name">${escHtml(r.name)}</div>
      <div class="ac-word">${r.answer ? escHtml(r.answer) : '—'}</div>
      ${r.matched ? '<div class="ac-icon">✅</div>' : ''}
    `;
    board.appendChild(cell);
  });

  const mgSec = $('matches-section');
  mgSec.innerHTML = '';
  if (matchGroups.length > 0) {
    const title = document.createElement('p');
    title.className   = 'matches-title';
    title.textContent = '🎯 الإجابات المتطابقة:';
    mgSec.appendChild(title);

    matchGroups.forEach(g => {
      const div = document.createElement('div');
      div.className = 'match-group';
      div.innerHTML = `
        <div class="mg-word">"${escHtml(g.answer)}"</div>
        <div class="mg-players">${g.playerNames.map(escHtml).join('، ')}</div>
      `;
      mgSec.appendChild(div);
    });
  }

  $('ts-value').textContent = teamScore;
  $('rev-host-ctrl').classList.toggle('hidden', !isHost);
  $('rev-guest-ctrl').classList.toggle('hidden', isHost);

  if (isHost) {
    $('btn-next').textContent = isLastRound
      ? '🏁 النتائج النهائية'
      : `الجولة ${round + 1} / ${totalRounds} ▶`;
  }
}

function onGameEnd({ teamScore, maxScore, players }) {
  showScreen('s-gameover');

  const pct    = maxScore > 0 ? teamScore / maxScore : 0;
  const banner = $('result-banner');
  if (pct >= 0.7) {
    banner.className   = 'result-banner result-win';
    banner.textContent = '🏆 فريق عبقري! أنتم سادة المزامنة!';
  } else if (pct >= 0.4) {
    banner.className   = 'result-banner result-good';
    banner.textContent = '🌟 أداء رائع! فريق متناسق جداً!';
  } else {
    banner.className   = 'result-banner result-ok';
    banner.textContent = '😄 تجربة ممتعة! العبوا مجدداً وتحسّنوا!';
  }

  $('fs-value').textContent = teamScore;
  setTimeout(() => {
    $('fs-fill').style.width = `${Math.min(100, pct * 100)}%`;
  }, 120);

  const CAPTIONS = [
    [280, '🧠⚡ عباقرة مطلقون! 400 هو هدفكم القادم!'],
    [200, '🔥 فريق استثنائي بكل المقاييس!'],
    [150, '👍 أصدقاء بتفكير متناسق!'],
    [100, '😊 انتم في الطريق الصحيح!'],
    [  0, '💪 مش مشكلة، تدرّبوا أكثر وستتحسنون!'],
  ];
  const cap = CAPTIONS.find(([min]) => teamScore >= min);
  $('fs-caption').textContent = cap ? cap[1] : '';

  const lb     = $('leaderboard');
  lb.innerHTML = '';
  const MEDALS = ['🥇','🥈','🥉'];
  players.forEach((p, i) => {
    const row = document.createElement('div');
    row.className = 'lb-row';
    row.style.animationDelay = `${i * 0.08}s`;
    row.innerHTML = `
      <div class="lb-rank">${MEDALS[i] || (i + 1)}</div>
      <div class="lb-name">${escHtml(p.name)}</div>
      <div class="lb-score">${p.score}</div>
    `;
    lb.appendChild(row);
  });

  $('go-host-ctrl').classList.toggle('hidden', !isHost);
  $('go-guest-ctrl').classList.toggle('hidden', isHost);
}

function onJoinError({ message }) {
  showToast(message, 'error');
}

// ─── Unified event dispatcher ─────────────────────────────────────────────────
function handleEvent(type, data) {
  switch (type) {
    case 'lobbyUpdate':    onLobbyUpdate(data);    break;
    case 'roundStart':     onRoundStart(data);     break;
    case 'playerAnswered': onPlayerAnswered(data); break;
    case 'roundReveal':    onRoundReveal(data);    break;
    case 'gameEnd':        onGameEnd(data);        break;
    case 'joinError':      onJoinError(data);      break;
  }
}

// ─── Network helpers ──────────────────────────────────────────────────────────
function hostBroadcast(type, data) {
  const msg = JSON.stringify({ type, data });
  Object.values(guestConns).forEach(conn => {
    if (conn.open) conn.send(msg);
  });
}

// Emit to self (host) and all guests
function hostEmit(type, data) {
  handleEvent(type, data);
  hostBroadcast(type, data);
}

// Send to a single guest by peer ID
function hostEmitTo(peerId, type, data) {
  const conn = guestConns[peerId];
  if (conn && conn.open) conn.send(JSON.stringify({ type, data }));
}

// Guest sends a message to the host
function guestSend(type, data) {
  if (hostConn && hostConn.open) {
    hostConn.send(JSON.stringify({ type, data }));
  }
}

// ─── Host: game logic ─────────────────────────────────────────────────────────
function makeLobbyPayload() {
  return {
    code:      lobbyCode,
    players:   lobby.players.map(({ id, name, score, isHost: ph }) =>
                 ({ id, name, score, isHost: ph })),
    gameState: lobby.gameStatus,
    teamScore: lobby.teamScore,
  };
}

function hostBroadcastLobby() {
  hostEmit('lobbyUpdate', makeLobbyPayload());
}

function hostStartRound() {
  lobby.currentRound++;
  lobby.answers    = {};
  lobby.gameStatus = 'playing';

  const cat = lobby.categories[(lobby.currentRound - 1) % lobby.categories.length];
  lobby.currentCategory = cat;

  if (lobby.timer) clearTimeout(lobby.timer);
  // +1 s grace period: lets the client-side countdown reach 0 before the host reveals
  lobby.timer = setTimeout(() => hostRevealAnswers(), (ANSWER_TIME + 1) * 1000);

  hostEmit('roundStart', {
    round:       lobby.currentRound,
    totalRounds: TOTAL_ROUNDS,
    category:    cat,
    timeLimit:   ANSWER_TIME,
    teamScore:   lobby.teamScore,
  });
}

function hostRevealAnswers() {
  if (lobby.gameStatus !== 'playing') return;
  if (lobby.timer) { clearTimeout(lobby.timer); lobby.timer = null; }
  lobby.gameStatus = 'revealing';

  const answerMap = {};
  lobby.players.forEach(p => {
    const ans = (lobby.answers[p.id] || '').trim().toLowerCase();
    if (ans) {
      answerMap[ans] = answerMap[ans] || [];
      answerMap[ans].push(p.id);
    }
  });

  const matchGroups = Object.entries(answerMap).filter(([, ids]) => ids.length > 1);
  const matchedIds  = new Set(matchGroups.flatMap(([, ids]) => ids));

  const total = lobby.players.length;
  const ratio = total > 0 ? matchedIds.size / total : 0;

  let roundScore, syncLevel;
  if (ratio === 1 && matchedIds.size > 0) { roundScore = 50; syncLevel = 'PERFECT'; }
  else if (ratio >= 0.75)                 { roundScore = 20; syncLevel = 'GREAT';   }
  else if (ratio >= 0.5)                  { roundScore = 10; syncLevel = 'GOOD';    }
  else if (ratio >= 0.25)                 { roundScore =  5; syncLevel = 'LOW';     }
  else                                    { roundScore =  0; syncLevel = 'MISS';    }

  lobby.teamScore += roundScore;

  matchGroups.forEach(([, ids]) => {
    ids.forEach(id => {
      const p = lobby.players.find(q => q.id === id);
      if (p) p.score += ids.length;
    });
  });

  const isLastRound = lobby.currentRound >= TOTAL_ROUNDS;

  hostEmit('roundReveal', {
    category:      lobby.currentCategory,
    playerResults: lobby.players.map(p => ({
      id:      p.id,
      name:    p.name,
      answer:  lobby.answers[p.id] || null,
      matched: matchedIds.has(p.id),
      score:   p.score,
    })),
    matchGroups: matchGroups.map(([answer, ids]) => ({
      answer,
      playerNames: ids.map(id => lobby.players.find(q => q.id === id)?.name || '?'),
      count:       ids.length,
    })),
    roundScore,
    syncLevel,
    teamScore:   lobby.teamScore,
    round:       lobby.currentRound,
    totalRounds: TOTAL_ROUNDS,
    isLastRound,
  });

  if (isLastRound) setTimeout(() => hostEndGame(), 4000);
}

function hostEndGame() {
  lobby.gameStatus = 'finished';
  const sorted = [...lobby.players].sort((a, b) => b.score - a.score);
  hostEmit('gameEnd', {
    teamScore: lobby.teamScore,
    maxScore:  TOTAL_ROUNDS * 50,
    players:   sorted.map(({ name, score }) => ({ name, score })),
  });
  hostBroadcastLobby();
}

function hostHandleSubmitAnswer(peerId, answer) {
  if (lobby.gameStatus !== 'playing') return;
  if (peerId in lobby.answers) return; // already submitted

  lobby.answers[peerId] = (answer || '').trim();

  const answered = Object.keys(lobby.answers).length;
  const total    = lobby.players.length;
  hostEmit('playerAnswered', { answered, total });

  if (answered === total) hostRevealAnswers();
}

// Process a raw message received by the host from a guest connection
function hostHandleMessage(conn, rawMsg) {
  let msg;
  try { msg = JSON.parse(rawMsg); } catch { return; }
  const { type, data } = msg;

  switch (type) {
    case 'join': {
      const name = (data?.playerName || '').trim().slice(0, 15);
      if (!name) return;
      if (lobby.gameStatus !== 'waiting') {
        hostEmitTo(conn.peer, 'joinError', { message: 'اللعبة بدأت بالفعل!' }); return;
      }
      if (lobby.players.length >= 8) {
        hostEmitTo(conn.peer, 'joinError', { message: 'الغرفة ممتلئة (8 لاعبين)!' }); return;
      }
      if (lobby.players.some(p => p.name.toLowerCase() === name.toLowerCase())) {
        hostEmitTo(conn.peer, 'joinError', { message: 'هذا الاسم محجوز! جرّب اسماً آخر.' }); return;
      }
      lobby.players.push({ id: conn.peer, name, score: 0, isHost: false });
      conn.send(JSON.stringify({ type: 'lobbyJoined', data: { code: lobbyCode } }));
      hostBroadcastLobby();
      break;
    }
    case 'submitAnswer':
      hostHandleSubmitAnswer(conn.peer, data?.answer);
      break;
  }
}

// ─── PeerJS setup: Host ───────────────────────────────────────────────────────
function createHostPeer(code) {
  if (peer) peer.destroy();

  const peerId = PEER_PREFIX + code;
  peer = new Peer(peerId, makePeerOptions());

  peer.on('open', id => {
    myPeerId  = id;
    lobbyCode = code;

    // Initialise host-side lobby
    lobby.players         = [{ id: myPeerId, name: myName, score: 0, isHost: true }];
    lobby.gameStatus      = 'waiting';
    lobby.currentRound    = 0;
    lobby.teamScore       = 0;
    lobby.categories      = shuffle(CATEGORIES);
    lobby.answers         = {};
    if (lobby.timer) { clearTimeout(lobby.timer); lobby.timer = null; }
    guestConns = {};

    $('lbl-code').textContent = code;
    $('modal-join').classList.add('hidden');
    showScreen('s-lobby');
    hostBroadcastLobby();
  });

  peer.on('connection', conn => {
    guestConns[conn.peer] = conn;

    conn.on('data',  rawMsg => hostHandleMessage(conn, rawMsg));

    conn.on('close', () => {
      delete guestConns[conn.peer];
      lobby.players = lobby.players.filter(p => p.id !== conn.peer);
      if (lobby.players.length > 0) hostBroadcastLobby();
    });

    conn.on('error', err => console.error('Guest connection error:', err));
  });

  peer.on('error', err => {
    if (err.type === 'unavailable-id') {
      // Peer ID collision – try a fresh code
      peer.destroy();
      createHostPeer(randomCode());
    } else {
      showToast('خطأ في الاتصال: ' + err.message, 'error');
    }
  });
}

// ─── PeerJS setup: Guest ──────────────────────────────────────────────────────
function joinAsGuest(code) {
  if (peer) peer.destroy();

  peer = new Peer(makePeerOptions());

  peer.on('open', id => {
    myPeerId = id;

    const hostPeerId = PEER_PREFIX + code;
    hostConn = peer.connect(hostPeerId, { reliable: true });

    hostConn.on('open', () => {
      hostConn.send(JSON.stringify({ type: 'join', data: { playerName: myName } }));
    });

    hostConn.on('data', rawMsg => {
      let msg;
      try { msg = JSON.parse(rawMsg); } catch { return; }
      const { type, data } = msg;

      if (type === 'lobbyJoined') {
        lobbyCode = data.code;
        $('lbl-code').textContent = code.toUpperCase();
        $('modal-join').classList.add('hidden');
        showScreen('s-lobby');
      } else {
        handleEvent(type, data);
      }
    });

    hostConn.on('close', () => {
      showToast('انقطع الاتصال بالمضيف', 'error');
      showScreen('s-home');
    });

    hostConn.on('error', err => {
      showToast('خطأ في الاتصال: ' + err.message, 'error');
    });
  });

  peer.on('error', err => {
    if (err.type === 'peer-unavailable') {
      showToast('الغرفة غير موجودة!', 'error');
    } else {
      showToast('خطأ: ' + err.message, 'error');
    }
  });
}

// ─── Home buttons ─────────────────────────────────────────────────────────────
$('btn-create').addEventListener('click', () => {
  myName = $('inp-name').value.trim();
  if (!myName) { showToast('أدخل اسمك أولاً!', 'error'); return; }
  isHost = true;
  createHostPeer(randomCode());
});

$('btn-join-show').addEventListener('click', () => {
  myName = $('inp-name').value.trim();
  if (!myName) { showToast('أدخل اسمك أولاً!', 'error'); return; }
  $('modal-join').classList.remove('hidden');
  $('inp-code').value = '';
  $('inp-code').focus();
});

$('inp-name').addEventListener('keydown', e => {
  if (e.key === 'Enter') $('btn-create').click();
});

// ─── Join modal ───────────────────────────────────────────────────────────────
$('btn-join-cancel').addEventListener('click', () => {
  $('modal-join').classList.add('hidden');
});

$('btn-join-confirm').addEventListener('click', doJoin);

$('inp-code').addEventListener('keydown', e => {
  if (e.key === 'Enter') doJoin();
});
$('inp-code').addEventListener('input', e => {
  e.target.value = e.target.value.toUpperCase();
});

function doJoin() {
  const code = $('inp-code').value.trim().toUpperCase();
  if (code.length !== 4) { showToast('الكود يجب أن يكون 4 أحرف', 'error'); return; }
  isHost = false;
  joinAsGuest(code);
}

// ─── Lobby buttons ────────────────────────────────────────────────────────────
$('btn-copy').addEventListener('click', () => {
  navigator.clipboard.writeText(lobbyCode)
    .then(() => showToast('تم نسخ الكود 📋', 'success'))
    .catch(()  => showToast(lobbyCode, 'success'));
});

$('btn-start').addEventListener('click', () => {
  if (!isHost) return;
  if (lobby.players.length < 2) {
    showToast('تحتاج لاعبَين على الأقل للبدء!', 'error'); return;
  }
  hostStartRound();
});

// ─── Playing buttons ──────────────────────────────────────────────────────────
$('btn-submit').addEventListener('click', doSubmitAnswer);
$('inp-answer').addEventListener('keydown', e => {
  if (e.key === 'Enter') doSubmitAnswer();
});

function doSubmitAnswer() {
  const ans = $('inp-answer').value.trim();
  if (!ans) { showToast('اكتب إجابتك أولاً!', 'error'); return; }

  if (isHost) {
    hostHandleSubmitAnswer(myPeerId, ans);
  } else {
    guestSend('submitAnswer', { answer: ans });
  }

  $('answer-area').classList.add('hidden');
  $('answered-msg').classList.remove('hidden');
}

// ─── Reveal / Game-over buttons ───────────────────────────────────────────────
$('btn-next').addEventListener('click', () => {
  if (!isHost || lobby.gameStatus !== 'revealing') return;
  hostStartRound();
});

$('btn-again').addEventListener('click', () => {
  if (!isHost) return;
  lobby.currentRound = 0;
  lobby.teamScore    = 0;
  lobby.categories   = shuffle(CATEGORIES);
  lobby.players.forEach(p => { p.score = 0; });
  lobby.gameStatus   = 'waiting';
  hostBroadcastLobby();
});

// ─── PWA: Service Worker registration ─────────────────────────────────────────
if ('serviceWorker' in navigator) {
  window.addEventListener('load', () => {
    navigator.serviceWorker.register('/sw.js').catch(() => {
      // SW registration may fail on non-HTTPS LAN – that is non-fatal
    });
  });
}
