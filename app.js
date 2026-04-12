/* ═══════════════════════════════════════════════════════════════════════════
   ECHO Game – Frontend (app.js)
   ═══════════════════════════════════════════════════════════════════════════ */

'use strict';

// ─── State ───────────────────────────────────────────────────────────────────
const socket = io();
let myId      = null;
let myName    = '';
let lobbyCode = '';
let isHost    = false;

// Timer
let timerInterval         = null;
const TIMER_CIRCLE_RADIUS = 52;                             // matches SVG r="52"
const CIRCUMFERENCE       = 2 * Math.PI * TIMER_CIRCLE_RADIUS; // ≈ 326.73

// ─── DOM shortcuts ────────────────────────────────────────────────────────────
const $ = id => document.getElementById(id);
let toastTimer;

// ─── Helpers ──────────────────────────────────────────────────────────────────
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

// ─── Timer ────────────────────────────────────────────────────────────────────
function startTimer(seconds) {
  clearInterval(timerInterval);
  let left = seconds;

  const ring    = $('t-ring');
  const numEl   = $('lbl-timer');

  function tick() {
    const offset = CIRCUMFERENCE * (1 - left / seconds);
    ring.setAttribute('stroke-dashoffset', String(offset));
    numEl.textContent = left;

    if (left <= 5) {
      numEl.style.color = '#f43f5e';
      ring.style.stroke = '#f43f5e';
    } else if (left <= 10) {
      numEl.style.color = '#f59e0b';
      ring.style.stroke = '#f59e0b';
    } else {
      numEl.style.color = '';
      ring.style.stroke = 'url(#timerGrad)';
    }

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

// ─── Home buttons ─────────────────────────────────────────────────────────────
$('btn-create').addEventListener('click', () => {
  myName = $('inp-name').value.trim();
  if (!myName) { showToast('أدخل اسمك أولاً!', 'error'); return; }
  socket.emit('createLobby', { playerName: myName });
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
  socket.emit('joinLobby', { playerName: myName, code });
}

// ─── Lobby buttons ────────────────────────────────────────────────────────────
$('btn-copy').addEventListener('click', () => {
  navigator.clipboard.writeText(lobbyCode)
    .then(() => showToast('تم نسخ الكود 📋', 'success'))
    .catch(() => showToast(lobbyCode, 'success'));
});

$('btn-start').addEventListener('click', () => {
  socket.emit('startGame');
});

// ─── Playing buttons ──────────────────────────────────────────────────────────
$('btn-submit').addEventListener('click', doSubmitAnswer);
$('inp-answer').addEventListener('keydown', e => {
  if (e.key === 'Enter') doSubmitAnswer();
});

function doSubmitAnswer() {
  const ans = $('inp-answer').value.trim();
  if (!ans) { showToast('اكتب إجابتك أولاً!', 'error'); return; }
  socket.emit('submitAnswer', { answer: ans });
  $('answer-area').classList.add('hidden');
  $('answered-msg').classList.remove('hidden');
}

// ─── Reveal / Game-over buttons ───────────────────────────────────────────────
$('btn-next').addEventListener('click', () => { socket.emit('nextRound'); });
$('btn-again').addEventListener('click', () => { socket.emit('playAgain'); });

// ═══════════════════════════════════════════════════════════════════════════════
// Socket events
// ═══════════════════════════════════════════════════════════════════════════════

socket.on('connect', () => { myId = socket.id; });

// ── Lobby created (you are host) ─────────────────────────────────────────────
socket.on('lobbyCreated', ({ code }) => {
  lobbyCode = code;
  $('lbl-code').textContent = code;
  $('modal-join').classList.add('hidden');
  showScreen('s-lobby');
});

// ── Lobby joined (you are guest) ─────────────────────────────────────────────
socket.on('lobbyJoined', ({ code }) => {
  lobbyCode = code;
  $('lbl-code').textContent = code;
  $('modal-join').classList.add('hidden');
  showScreen('s-lobby');
});

// ── Join error ───────────────────────────────────────────────────────────────
socket.on('joinError', ({ message }) => {
  showToast(message, 'error');
});

// ── Lobby state update (player list, game state changes) ─────────────────────
socket.on('lobbyUpdate', ({ players, gameState }) => {
  const me = players.find(p => p.id === myId);
  isHost   = me?.isHost ?? false;

  renderPlayers(players);

  $('lobby-host-area').classList.toggle('hidden', !isHost);
  $('lobby-guest-area').classList.toggle('hidden', isHost);

  const startBtn = $('btn-start');
  startBtn.disabled = players.length < 2;

  if (gameState === 'waiting') showScreen('s-lobby');
});

// ── Round starts ─────────────────────────────────────────────────────────────
socket.on('roundStart', ({ round, totalRounds, category, timeLimit, teamScore }) => {
  stopTimer();
  showScreen('s-playing');

  $('lbl-round').textContent   = `الجولة ${round} / ${totalRounds}`;
  $('lbl-tscore').textContent  = `${teamScore} نقطة`;
  $('lbl-cat-ar').textContent  = category.ar;
  $('lbl-cat-en').textContent  = category.en;

  // Reset answer area
  $('inp-answer').value = '';
  $('answer-area').classList.remove('hidden');
  $('answered-msg').classList.add('hidden');
  $('prog-bar').style.width = '0%';
  $('prog-text').textContent = `0 من 0 لاعب أجاب`;

  // Reset timer ring
  $('t-ring').setAttribute('stroke-dashoffset', '0');
  $('t-ring').style.stroke   = 'url(#timerGrad)';
  $('lbl-timer').style.color = '';

  $('inp-answer').focus();
  startTimer(timeLimit);
});

// ── A player answered (progress update) ──────────────────────────────────────
socket.on('playerAnswered', ({ answered, total }) => {
  const pct = total > 0 ? (answered / total) * 100 : 0;
  $('prog-bar').style.width   = `${pct}%`;
  $('prog-text').textContent  = `${answered} من ${total} لاعب أجاب`;
});

// ── Round reveal ─────────────────────────────────────────────────────────────
socket.on('roundReveal', ({
  category, playerResults, matchGroups,
  roundScore, syncLevel, teamScore,
  round, totalRounds, isLastRound,
}) => {
  stopTimer();
  showScreen('s-reveal');

  // Sync banner
  const SYNC_CFG = {
    PERFECT: { cls: 'sync-perfect', text: '⚡ مزامنة كاملة! PERFECT SYNC!' },
    GREAT:   { cls: 'sync-great',   text: '🔥 تزامن رائع! Great Sync!'     },
    GOOD:    { cls: 'sync-good',    text: '👍 تزامن جيد! Good Sync!'        },
    LOW:     { cls: 'sync-low',     text: '💪 يمكنكم الأفضل! Keep Trying!' },
    MISS:    { cls: 'sync-miss',    text: '😅 لا تطابق! No Match!'          },
  };
  const cfg = SYNC_CFG[syncLevel] || SYNC_CFG.MISS;
  const banner = $('sync-banner');
  banner.className   = `sync-banner ${cfg.cls}`;
  banner.textContent = cfg.text;

  $('rev-cat').textContent         = category.ar;
  $('rev-round-score').textContent = roundScore > 0
    ? `+${roundScore} نقطة للفريق!`
    : 'لا نقاط هذه الجولة';
  $('rev-round-score').style.color = roundScore > 0
    ? 'var(--green)' : 'var(--w40)';

  // Answers board
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

  // Match groups
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

  // Team score
  $('ts-value').textContent = teamScore;

  // Host/guest controls
  $('rev-host-ctrl').classList.toggle('hidden', !isHost);
  $('rev-guest-ctrl').classList.toggle('hidden', isHost);

  if (isHost) {
    const btn = $('btn-next');
    if (isLastRound) {
      btn.textContent = '🏁 النتائج النهائية';
    } else {
      btn.textContent = `الجولة ${round + 1} / ${totalRounds} ▶`;
    }
  }
});

// ── Game over ─────────────────────────────────────────────────────────────────
socket.on('gameEnd', ({ teamScore, maxScore, players }) => {
  showScreen('s-gameover');

  // Result banner
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

  // Final score
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

  // Leaderboard
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
});

// ── Disconnect ────────────────────────────────────────────────────────────────
socket.on('disconnect', () => {
  showToast('انقطع الاتصال بالخادم… يُعاد الاتصال', 'error');
});
