'use strict';

const express   = require('express');
const { createServer } = require('http');
const { Server } = require('socket.io');
const path      = require('path');

const app        = express();
const httpServer = createServer(app);
const io         = new Server(httpServer, { cors: { origin: '*' } });

app.use(express.static(__dirname));

// ─── Constants ──────────────────────────────────────────────────────────────
const TOTAL_ROUNDS  = 8;
const ANSWER_TIME   = 30; // seconds

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

// ─── Utilities ──────────────────────────────────────────────────────────────
function randomCode() {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  return Array.from({ length: 4 }, () => chars[Math.floor(Math.random() * chars.length)]).join('');
}

function uniqueCode() {
  let code;
  do { code = randomCode(); } while (lobbies.has(code));
  return code;
}

function shuffle(arr) {
  const a = [...arr];
  for (let i = a.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [a[i], a[j]] = [a[j], a[i]];
  }
  return a;
}

// ─── State ──────────────────────────────────────────────────────────────────
const lobbies = new Map(); // code → lobby

function makeLobby(code) {
  return {
    code,
    players:        [],   // { id, name, score, isHost }
    gameState:      'waiting',
    currentRound:   0,
    teamScore:      0,
    categories:     shuffle(CATEGORIES),
    currentCategory: null,
    answers:        {},   // socketId → string
    timer:          null,
  };
}

// ─── Broadcast helpers ────────────────────────────────────────────────────
function broadcastLobby(lobby) {
  io.to(lobby.code).emit('lobbyUpdate', {
    code:      lobby.code,
    players:   lobby.players.map(({ id, name, score, isHost }) => ({ id, name, score, isHost })),
    gameState: lobby.gameState,
    teamScore: lobby.teamScore,
  });
}

// ─── Game flow ────────────────────────────────────────────────────────────
function startRound(lobby) {
  lobby.currentRound++;
  lobby.answers   = {};
  lobby.gameState = 'playing';

  const cat = lobby.categories[(lobby.currentRound - 1) % lobby.categories.length];
  lobby.currentCategory = cat;

  clearLobbyTimer(lobby);
  // +1 s grace period: lets the client-side countdown reach 0 before the server reveals answers
  lobby.timer = setTimeout(() => revealAnswers(lobby), (ANSWER_TIME + 1) * 1000);

  io.to(lobby.code).emit('roundStart', {
    round:       lobby.currentRound,
    totalRounds: TOTAL_ROUNDS,
    category:    cat,
    timeLimit:   ANSWER_TIME,
    teamScore:   lobby.teamScore,
  });
}

function revealAnswers(lobby) {
  if (lobby.gameState !== 'playing') return;
  clearLobbyTimer(lobby);
  lobby.gameState = 'revealing';

  // Group answers (normalised: trimmed + lower-case)
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

  // Individual scores: each matched player earns (group-size) points
  matchGroups.forEach(([, ids]) => {
    ids.forEach(id => {
      const p = lobby.players.find(p => p.id === id);
      if (p) p.score += ids.length;
    });
  });

  const isLastRound = lobby.currentRound >= TOTAL_ROUNDS;

  io.to(lobby.code).emit('roundReveal', {
    category:     lobby.currentCategory,
    playerResults: lobby.players.map(p => ({
      id:      p.id,
      name:    p.name,
      answer:  lobby.answers[p.id] || null,
      matched: matchedIds.has(p.id),
      score:   p.score,
    })),
    matchGroups: matchGroups.map(([answer, ids]) => ({
      answer,
      playerNames: ids.map(id => lobby.players.find(p => p.id === id)?.name || '?'),
      count:       ids.length,
    })),
    roundScore,
    syncLevel,
    teamScore:   lobby.teamScore,
    round:       lobby.currentRound,
    totalRounds: TOTAL_ROUNDS,
    isLastRound,
  });

  if (isLastRound) setTimeout(() => endGame(lobby), 4000);
}

function endGame(lobby) {
  lobby.gameState = 'finished';
  const sorted = [...lobby.players].sort((a, b) => b.score - a.score);
  io.to(lobby.code).emit('gameEnd', {
    teamScore: lobby.teamScore,
    maxScore:  TOTAL_ROUNDS * 50,
    players:   sorted.map(({ name, score }) => ({ name, score })),
  });
  broadcastLobby(lobby);
}

function clearLobbyTimer(lobby) {
  if (lobby.timer) { clearTimeout(lobby.timer); lobby.timer = null; }
}

// ─── Socket handlers ──────────────────────────────────────────────────────
io.on('connection', socket => {

  // ── Create lobby ──────────────────────────────────────────────────────
  socket.on('createLobby', ({ playerName } = {}) => {
    const name = (playerName || '').trim().slice(0, 15);
    if (!name) return;

    const code  = uniqueCode();
    const lobby = makeLobby(code);
    lobby.players.push({ id: socket.id, name, score: 0, isHost: true });
    lobbies.set(code, lobby);

    socket.join(code);
    socket.lobbyCode = code;

    socket.emit('lobbyCreated', { code });
    broadcastLobby(lobby);
  });

  // ── Join lobby ────────────────────────────────────────────────────────
  socket.on('joinLobby', ({ playerName, code } = {}) => {
    const name = (playerName || '').trim().slice(0, 15);
    const uc   = (code || '').trim().toUpperCase();
    if (!name || !uc) return;

    const lobby = lobbies.get(uc);
    if (!lobby)                          { socket.emit('joinError', { message: 'الغرفة غير موجودة!' });         return; }
    if (lobby.gameState !== 'waiting')   { socket.emit('joinError', { message: 'اللعبة بدأت بالفعل!' });        return; }
    if (lobby.players.length >= 8)       { socket.emit('joinError', { message: 'الغرفة ممتلئة (8 لاعبين)!' }); return; }
    if (lobby.players.some(p => p.name.toLowerCase() === name.toLowerCase())) {
      socket.emit('joinError', { message: 'هذا الاسم محجوز! جرّب اسماً آخر.' }); return;
    }

    lobby.players.push({ id: socket.id, name, score: 0, isHost: false });
    socket.join(uc);
    socket.lobbyCode = uc;

    socket.emit('lobbyJoined', { code: uc });
    broadcastLobby(lobby);
  });

  // ── Start game ────────────────────────────────────────────────────────
  socket.on('startGame', () => {
    const lobby = lobbies.get(socket.lobbyCode);
    if (!lobby) return;
    const me = lobby.players.find(p => p.id === socket.id);
    if (!me?.isHost) return;
    if (lobby.players.length < 2) {
      socket.emit('joinError', { message: 'تحتاج لاعبَين على الأقل للبدء!' }); return;
    }
    startRound(lobby);
  });

  // ── Submit answer ─────────────────────────────────────────────────────
  socket.on('submitAnswer', ({ answer } = {}) => {
    const lobby = lobbies.get(socket.lobbyCode);
    if (!lobby || lobby.gameState !== 'playing') return;
    if (socket.id in lobby.answers) return; // already submitted

    lobby.answers[socket.id] = (answer || '').trim();

    const answered = Object.keys(lobby.answers).length;
    const total    = lobby.players.length;
    io.to(lobby.code).emit('playerAnswered', { answered, total });

    if (answered === total) revealAnswers(lobby);
  });

  // ── Next round (host) ─────────────────────────────────────────────────
  socket.on('nextRound', () => {
    const lobby = lobbies.get(socket.lobbyCode);
    if (!lobby || lobby.gameState !== 'revealing') return;
    const me = lobby.players.find(p => p.id === socket.id);
    if (!me?.isHost) return;
    startRound(lobby);
  });

  // ── Play again (host) ─────────────────────────────────────────────────
  socket.on('playAgain', () => {
    const lobby = lobbies.get(socket.lobbyCode);
    if (!lobby) return;
    const me = lobby.players.find(p => p.id === socket.id);
    if (!me?.isHost) return;

    lobby.currentRound = 0;
    lobby.teamScore    = 0;
    lobby.categories   = shuffle(CATEGORIES);
    lobby.players.forEach(p => { p.score = 0; });
    lobby.gameState    = 'waiting';
    broadcastLobby(lobby);
  });

  // ── Disconnect ────────────────────────────────────────────────────────
  socket.on('disconnect', () => {
    const code  = socket.lobbyCode;
    const lobby = code && lobbies.get(code);
    if (!lobby) return;

    lobby.players = lobby.players.filter(p => p.id !== socket.id);

    if (lobby.players.length === 0) {
      clearLobbyTimer(lobby);
      lobbies.delete(code);
      return;
    }

    // Transfer host if the host left
    if (!lobby.players.some(p => p.isHost)) {
      lobby.players[0].isHost = true;
    }

    broadcastLobby(lobby);
  });
});

// ─── Start ────────────────────────────────────────────────────────────────
const PORT = process.env.PORT || 3000;
httpServer.listen(PORT, () => {
  console.log(`🎮 ECHO Game Server running → http://localhost:${PORT}`);
});
