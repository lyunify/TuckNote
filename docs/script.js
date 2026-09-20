'use strict';

// This preview is deliberately ephemeral. No note content leaves this page.
const initialNotes = [
  { title: 'Go on. Make this yours.', prompt: 'Type a thought here. Yes, you can edit this!', text: '', tasks: ['Try checking off this task', 'Add a little thought of your own'] },
  { title: 'What if…', prompt: 'A weekend project? A tiny spark? Write your idea…', text: '', tasks: ['Keep the idea simple', 'Make something just for fun'] },
  { title: 'The good little things', prompt: 'A good coffee? A little win? Add yours…', text: '', tasks: ['Send a friend a kind message', 'Step outside for five minutes'] },
  { title: 'What’s on your mind?', prompt: 'Your next little idea starts here…', text: '', tasks: [], personal: true }
];
let notes, selected = 0, pinned = false, hovered = false, focused = false, dismissed = false, welcomeOpen = true;
const zone = document.getElementById('notch-zone');
const notch = document.getElementById('notch');
const panel = document.getElementById('note-panel');
const pinButton = document.getElementById('pin-button');
const themeButton = document.getElementById('theme-button');
const noteText = document.getElementById('note-text');
const addThoughtButton = document.getElementById('add-thought');
const tasks = document.getElementById('tasks');
const status = document.getElementById('demo-status');
const touch = matchMedia('(hover: none)');
const demo = document.getElementById('demo');
const hint = document.getElementById('hover-hint');
const guideAction = document.getElementById('whisper-action');
const guideLead = document.getElementById('whisper-lead');
const guideLabel = document.getElementById('whisper-label');
let leaveTimer, celebrationTimer;
const completionMessage = document.getElementById('completion-message');

function clearCelebration() {
  clearTimeout(celebrationTimer);
  panel.classList.remove('is-celebrating');
  completionMessage.textContent = '';
}
function celebrate() {
  clearCelebration();
  completionMessage.textContent = 'Nice, all tucked away!';
  panel.classList.add('is-celebrating');
  celebrationTimer = setTimeout(clearCelebration, 3200);
}

function freshNotes() {
  return initialNotes.map(note => ({ ...note, tasks: note.tasks.map(text => ({ text, done: false })) }));
}
function updatePanel() {
  const open = !dismissed && (welcomeOpen || pinned || hovered || focused);
  const wasOpen = zone.classList.contains('is-open');
  if (!open && wasOpen) clearCelebration();
  zone.classList.toggle('is-open', open);
  panel.inert = !open;
  notch.setAttribute('aria-expanded', String(open));
  notch.setAttribute('aria-label', pinned ? 'Close note panel' : open ? 'Keep note panel open' : 'Open note panel');
  demo.classList.toggle('is-waiting', !open);
  updateGuide();
  hint.textContent = open ? 'Go on, try it!' : touch.matches ? 'Tap here' : 'Hover here';
  pinButton.setAttribute('aria-pressed', String(pinned));
  pinButton.setAttribute('aria-label', pinned ? 'Unpin note panel' : 'Keep note open');
  status.textContent = pinned ? 'Pinned open · click the notch to tuck it away.' : welcomeOpen ? 'Try adding a thought or checking a task.' : open ? focused ? 'Take your time. Click outside or use the handwritten prompt when you’re ready.' : 'Move away to tuck it, or click inside to keep writing.' : touch.matches ? 'Tap the glowing notch to open your note.' : 'Hover over the glowing notch to bring it back.';
}
function updateProgress() {
  const current = notes[selected];
  document.getElementById('task-progress').textContent = current.tasks.length
    ? `${current.tasks.filter(task => task.done).length} / ${current.tasks.length} done` : 'Your list starts here';
  document.getElementById('note-footer-hint').textContent = 'Enter to add a thought';
  addThoughtButton.disabled = !current.text.trim();
  updateGuide();
}
function renderNote() {
  clearCelebration();
  document.getElementById('add-status').textContent = '';
  const current = notes[selected];
  document.getElementById('note-heading').textContent = current.title;
  noteText.value = current.text;
  panel.classList.toggle('is-personal-note', Boolean(current.personal));
  noteText.placeholder = current.prompt;
  noteText.setAttribute('aria-label', current.personal ? 'Write your own note' : 'Write a demo note');
  tasks.replaceChildren();
  current.tasks.forEach(task => {
    const label = document.createElement('label');
    label.className = 'task';
    const checkbox = document.createElement('input');
    checkbox.type = 'checkbox';
    checkbox.checked = task.done;
    const text = document.createElement('span');
    text.textContent = task.text;
    checkbox.addEventListener('change', () => {
      task.done = checkbox.checked;
      updateProgress();
      if (checkbox.checked && current.tasks.every(item => item.done)) celebrate();
      else clearCelebration();
    });
    label.append(checkbox, text);
    tasks.append(label);
  });
  document.querySelectorAll('[data-note]').forEach(button => button.setAttribute('aria-pressed', String(Number(button.dataset.note) === selected)));
  updateProgress();
}

function addThought() {
  const text = noteText.value.trim();
  if (!text) return;
  notes[selected].tasks.push({ text, done: false, own: true });
  notes[selected].text = '';
  renderNote();
  noteText.focus({ preventScroll: true });
  tasks.scrollTop = tasks.scrollHeight;
  document.getElementById('add-status').textContent = `Added: ${text}`;
  updateGuide();
}
addThoughtButton.addEventListener('click', addThought);
noteText.addEventListener('keydown', event => {
  if (event.key === 'Enter' && !event.shiftKey && !event.isComposing) {
    event.preventDefault();
    addThought();
  }
});

zone.addEventListener('pointerenter', event => {
  if (event.pointerType === 'touch') return;
  clearTimeout(leaveTimer);
  welcomeOpen = false;
  hovered = true;
  dismissed = false;
  updatePanel();
});
zone.addEventListener('pointerleave', event => {
  if (event.pointerType === 'touch') return;
  clearTimeout(leaveTimer);
  leaveTimer = setTimeout(() => {
    welcomeOpen = false; hovered = false;
    // Keep keyboard and mouse editing focused even when the pointer drifts away.
    updatePanel();
  }, 650);
});
zone.addEventListener('focusin', () => {
  clearTimeout(leaveTimer);
  focused = panel.contains(document.activeElement) || document.activeElement.matches(':focus-visible');
  updatePanel();
});
zone.addEventListener('focusout', () => {
  setTimeout(() => {
    focused = panel.contains(document.activeElement) || (document.activeElement === guideAction && zone.classList.contains('is-open')) || (zone.contains(document.activeElement) && document.activeElement.matches(':focus-visible'));
    updatePanel();
  }, 0);
});
notch.addEventListener('click', () => {
  welcomeOpen = false;
  // Click latches a hover-open panel, and a second click tucks it away.
  if (pinned) { pinned = false; dismissed = true; }
  else { pinned = true; dismissed = false; }
  updatePanel();
});
pinButton.addEventListener('click', () => { welcomeOpen = false; pinned = !pinned; updatePanel(); });
themeButton.addEventListener('click', () => {
  const dark = panel.classList.toggle('dark');
  themeButton.setAttribute('aria-label', `Switch note panel to ${dark ? 'light' : 'dark'} theme`);
});
noteText.addEventListener('focus', updateGuide);
noteText.addEventListener('input', () => {
  notes[selected].text = noteText.value;
  updateProgress();
  updateGuide();
});
document.querySelectorAll('[data-note]').forEach(button => {
  button.addEventListener('click', () => {
    selected = Number(button.dataset.note);
    renderNote();
    if (notes[selected].personal) noteText.focus({ preventScroll: true });
  });
});
document.getElementById('try-demo').addEventListener('click', () => {
  welcomeOpen = false;
  pinned = false;
  focused = true;
  dismissed = false;
  updatePanel();
  document.getElementById('demo').scrollIntoView({ behavior: matchMedia('(prefers-reduced-motion: reduce)').matches ? 'instant' : 'smooth', block: 'center' });
  noteText.focus({ preventScroll: true });
});
document.getElementById('reset-demo').addEventListener('click', () => {
  clearTimeout(leaveTimer);
  notes = freshNotes();
  selected = 0; pinned = false; hovered = false; focused = false; dismissed = false; welcomeOpen = true;
  panel.classList.remove('dark');
  themeButton.setAttribute('aria-label', 'Switch note panel to dark theme');
  renderNote();
  document.getElementById('add-status').textContent = '';
  updatePanel();
});
document.addEventListener('keydown', event => {
  if (event.key !== 'Escape' || !zone.classList.contains('is-open')) return;
  welcomeOpen = false;
  pinned = false;
  dismissed = true;
  if (panel.contains(document.activeElement)) notch.focus({ preventScroll: true });
  updatePanel();
});
document.addEventListener('pointerdown', event => {
  // These controls manage the panel themselves; avoid closing it before their click.
  if (event.target.closest('#try-demo, #whisper-action, #reset-demo')) return;
  if (!zone.contains(event.target) && zone.classList.contains('is-open') && !pinned) {
    welcomeOpen = false;
    dismissed = true;
    if (zone.contains(document.activeElement)) document.activeElement.blur();
    updatePanel();
  }
});
touch.addEventListener('change', updatePanel);
notes = freshNotes();
renderNote();
updatePanel();

// One changing sentence guides the visitor through the real demo state.
function updateGuide() {
  const open = zone.classList.contains('is-open');
  const current = notes[selected];
  const hasThought = current.text.trim() || current.tasks.some(task => task.own || task.done);
  const action = !open ? 'open' : hasThought ? 'tuck' : 'write';
  const lead = !open ? 'Still here.' : hasThought ? 'Got it.' : 'Your turn.';
  const label = !open ? 'Find me at the notch' : hasThought ? 'Shall we tuck it away?' : 'What’s on your mind?';
  if (guideLead.textContent !== lead) guideLead.textContent = lead;
  if (guideLabel.textContent !== label) guideLabel.textContent = label;
  guideAction.dataset.action = action;
}
guideAction.addEventListener('click', () => {
  const action = guideAction.dataset.action;
  clearTimeout(leaveTimer);
  if (action === 'tuck') {
    welcomeOpen = false; pinned = false; hovered = false; focused = false; dismissed = true;
    if (panel.contains(document.activeElement)) document.activeElement.blur();
    updatePanel();
  } else if (action === 'open') {
    welcomeOpen = true; pinned = false; hovered = false; focused = false; dismissed = false;
    updatePanel();
  } else {
    selected = notes.findIndex(note => note.personal);
    renderNote();
    document.getElementById('try-demo').click();
  }
});
