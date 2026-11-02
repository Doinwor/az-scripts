/**
 * AZ Scripts - Каталог скриптов для Arizona RP Mobile (MonetLoader)
 * Vanilla ES6 JavaScript (Чистый JS без сборщиков, для GitHub Pages & Capacitor APK)
 */

// Подключение модульного SDK Firebase v10+ через официальный CDN
// @ts-ignore
import { initializeApp } from 'https://www.gstatic.com/firebasejs/11.0.1/firebase-app.js';
// @ts-ignore
import { 
  getDatabase, 
  ref, 
  onValue, 
  runTransaction 
} from 'https://www.gstatic.com/firebasejs/11.0.1/firebase-database.js';

(() => {
  'use strict';

  // --- Конфигурация Firebase ---
  const firebaseConfig = {
    apiKey: "AIzaSyCHZmCcwcd4rJ7Icw4WIK_DbuF4c1wkhtrk",
    authDomain: "az-scripts.firebaseapp.com",
    databaseURL: "https://az-scripts-default-rtdb.firebaseio.com",
    projectId: "az-scripts",
    storageBucket: "az-scripts.firebasestorage.app",
    messagingSenderId: "1057071984779",
    appId: "1:1057071984779:web:d008b2cc1e971707cfe48e"
  };

  // Инициализация Firebase Realtime Database
  let db = null;
  let isFirebaseReady = false;

  try {
    const firebaseApp = initializeApp(firebaseConfig);
    db = getDatabase(firebaseApp);
    isFirebaseReady = true;
    console.log('[Firebase RTDB] Успешно подключен');
  } catch (err) {
    console.warn('[Firebase RTDB] Режим автономной работы/кэша:', err);
  }

  // --- Конфигурация приложения ---
  const CONFIG = {
    SCRIPTS_JSON_URL: './scripts.json',
    STORAGE_KEYS: {
      FAVORITES: 'az_scripts_favs_v2',
      USER_VOTES: 'az_scripts_votes_v2',
      GAME_FOLDER: 'gameFolderId',
      ONBOARDING: 'az_onboarding_shown_v2',
      LOCAL_RATINGS: 'az_cached_ratings_v2'
    }
  };

  // Состояние приложения
  const state = {
    allScripts: [],
    filteredScripts: [],
    activeCategory: 'all',
    searchQuery: '',
    sortBy: 'popular',
    favorites: new Set(),
    ratings: {},
    userVotes: {},
    activeScriptModal: null,
    isCapacitor: false,
    loading: true
  };

  // ID папки игры для @daniele-rolli/capacitor-scoped-storage
  let gameFolderId = localStorage.getItem(CONFIG.STORAGE_KEYS.GAME_FOLDER) || null;

  let el = {};

  function initElements() {
    el = {
      feed: document.getElementById('scripts-feed'),
      categoryChips: document.getElementById('category-chips'),
      searchInput: document.getElementById('search-input'),
      searchClear: document.getElementById('search-clear'),
      sortSelect: document.getElementById('sort-select'),
      totalCount: document.getElementById('total-count'),
      envBadge: document.getElementById('env-badge'),
      envText: document.getElementById('env-text'),
      toastContainer: document.getElementById('toast-container'),
      favNavBadge: document.getElementById('fav-nav-badge'),
      
      // Bottom Sheet (Модальное окно скрипта)
      detailModal: document.getElementById('detail-modal'),
      detailDragHandle: document.getElementById('detail-drag-handle'),
      detailCloseBtn: document.getElementById('detail-close-btn'),
      detailBody: document.getElementById('detail-body'),
      detailActionsFooter: document.getElementById('detail-actions-footer'),
      
      // Модальное окно настроек / информации
      settingsModal: document.getElementById('settings-modal'),
      settingsCloseBtn: document.getElementById('settings-close-btn'),
      resetFolderBtn: document.getElementById('reset-folder-btn'),
      folderStatusText: document.getElementById('folder-status-text'),

      // Онбординг (Первый запуск)
      onboardingModal: document.getElementById('onboarding-modal'),
      onboardingPickFolderBtn: document.getElementById('onboarding-pick-folder-btn'),
      onboardingSkipBtn: document.getElementById('onboarding-skip-btn'),
      
      // Нижняя навигация
      navTabs: document.querySelectorAll('.nav-tab-btn')
    };
  }

  // Категории и оформление
  const CATEGORY_COLORS = {
    'Оптимизация': { color: '#ff6a3d', icon: '⚡' },
    'Хелперы': { color: '#38bdf8', icon: '🛡️' },
    'Бинды': { color: '#10b981', icon: '🎮' },
    'Чат': { color: '#a855f7', icon: '💬' },
    'default': { color: '#94a3b8', icon: '📦' }
  };

  // Начальные оценки для мгновенного отображения
  const INITIAL_SEED_RATINGS = {
    'central-cleaner': { up: 184, down: 7 },
    'arizona-helper': { up: 312, down: 11 },
    'binder-master': { up: 215, down: 9 },
    'auto-bazaar': { up: 124, down: 6 },
    'chat-plus': { up: 88, down: 4 },
    'time-weather': { up: 147, down: 5 }
  };

  // --- Инициализация приложения ---
  function init() {
    initElements();
    detectEnvironment();
    loadStoredData();
    initRealtimeRatingsListener();
    bindEvents();
    renderSkeletonLoaders();
    fetchScriptsCatalog();
    checkOnboarding();
  }

  // Определение среды (Capacitor WebView vs Обычный браузер)
  function detectEnvironment() {
    const hasCapacitor = typeof window.Capacitor !== 'undefined' &&
                         window.Capacitor.Plugins &&
                         Boolean(window.Capacitor.Plugins.ScopedStorage);
    
    state.isCapacitor = hasCapacitor;

    if (el.envText) {
      el.envText.textContent = hasCapacitor ? 'APK MonetLoader' : 'Web Браузер';
    }

    updateFolderStatusUI();
  }

  function updateFolderStatusUI() {
    if (el.folderStatusText) {
      if (gameFolderId) {
        el.folderStatusText.textContent = 'Папка игры выбрана и привязана';
        el.folderStatusText.style.color = 'var(--accent-emerald)';
      } else {
        el.folderStatusText.textContent = 'Папка еще не выбрана';
        el.folderStatusText.style.color = 'var(--text-subtle)';
      }
    }
  }

  // Онбординг (показывается только 1 раз при первом запуске)
  function checkOnboarding() {
    const isShown = localStorage.getItem(CONFIG.STORAGE_KEYS.ONBOARDING);
    if (!isShown && el.onboardingModal) {
      setTimeout(() => {
        el.onboardingModal.classList.add('open');
        document.body.style.overflow = 'hidden';
      }, 700);
    }
  }

  function closeOnboardingModal() {
    if (el.onboardingModal) {
      el.onboardingModal.classList.remove('open');
      document.body.style.overflow = '';
      localStorage.setItem(CONFIG.STORAGE_KEYS.ONBOARDING, 'true');
    }
  }

  // ==========================================================================
  // ВЫБОР ПАПКИ ИГРЫ (ScopedStorage.pickFolder с подсказкой Toast)
  // ==========================================================================
  async function selectGameFolder() {
    if (window.Capacitor && window.Capacitor.Plugins && window.Capacitor.Plugins.ScopedStorage) {
      // 1. Показываем красивый Toast с задержкой 3 секунды, как запрошено
      showToast("Ищем папку Android/media/com.arizona.game/monetloader...", "info", 3000);
      
      // Небольшая задержка перед вызовом проводника, чтобы игрок успел прочитать подсказку
      await new Promise(resolve => setTimeout(resolve, 800));

      try {
        const result = await window.Capacitor.Plugins.ScopedStorage.pickFolder();
        if (result && result.folder) {
          gameFolderId = result.folder.id;
          localStorage.setItem(CONFIG.STORAGE_KEYS.GAME_FOLDER, gameFolderId);
          updateFolderStatusUI();
          showToast("Папка игры успешно привязана!", "success");
          vibrate([20, 40]);
          return gameFolderId;
        } else {
          showToast("Папка игры не была выбрана", "error");
          return null;
        }
      } catch (err) {
        console.error("pickFolder error:", err);
        showToast("Ошибка выбора папки: " + (err.message || "отменено"), "error");
        return null;
      }
    } else {
      showToast("В браузере файлы скачиваются в папку Загрузки", "info");
      return null;
    }
  }

  // Загрузка данных из LocalStorage
  function loadStoredData() {
    try {
      const savedFavs = localStorage.getItem(CONFIG.STORAGE_KEYS.FAVORITES);
      if (savedFavs) {
        state.favorites = new Set(JSON.parse(savedFavs));
      }
      
      const savedVotes = localStorage.getItem(CONFIG.STORAGE_KEYS.USER_VOTES);
      if (savedVotes) {
        state.userVotes = JSON.parse(savedVotes);
      }

      const savedRatings = localStorage.getItem(CONFIG.STORAGE_KEYS.LOCAL_RATINGS);
      state.ratings = savedRatings ? JSON.parse(savedRatings) : { ...INITIAL_SEED_RATINGS };
    } catch (err) {
      console.warn('Ошибка LocalStorage:', err);
      state.ratings = { ...INITIAL_SEED_RATINGS };
    }
    updateFavoritesBadge();
  }

  function saveFavorites() {
    try {
      localStorage.setItem(CONFIG.STORAGE_KEYS.FAVORITES, JSON.stringify([...state.favorites]));
    } catch (err) {}
    updateFavoritesBadge();
  }

  function saveUserVotes() {
    try {
      localStorage.setItem(CONFIG.STORAGE_KEYS.USER_VOTES, JSON.stringify(state.userVotes));
    } catch (err) {}
  }

  function updateFavoritesBadge() {
    const count = state.favorites.size;
    if (el.favNavBadge) {
      el.favNavBadge.textContent = count;
      el.favNavBadge.style.display = count > 0 ? 'inline-block' : 'none';
    }
  }

  // Определение расширения файла (.lua, .zip, .luac и т.д.)
  function getScriptExtension(script) {
    const checkString = (str) => {
      if (!str || typeof str !== 'string') return null;
      const clean = str.split('?')[0].split('#')[0].toLowerCase();
      if (clean.endsWith('.luac') || clean.includes('.luac.')) return 'luac';
      if (clean.endsWith('.zip')) return 'zip';
      if (clean.endsWith('.lua')) return 'lua';
      const match = clean.match(/\.([a-z0-9]+)$/i);
      return match ? match[1].toLowerCase() : null;
    };

    return checkString(script.local_url) || checkString(script.download_url) || 'lua';
  }

  // ==========================================================================
  // СКАЧИВАНИЕ И УСТАНОВКА (ScopedStorage для APK + Fallback для браузера)
  // ==========================================================================
  async function installScript(script, buttonElement) {
    vibrate(40);
    const originalText = buttonElement.innerHTML;
    buttonElement.classList.add('loading');
    buttonElement.innerHTML = `
      <div class="spinner"></div>
      <span>Установка...</span>
    `;

    const ext = getScriptExtension(script);
    const targetFileName = `${script.id}.${ext}`;

    // 1. Проверяем, запущено ли приложение в Capacitor APK
    if (window.Capacitor && window.Capacitor.Plugins && window.Capacitor.Plugins.ScopedStorage) {
      try {
        // Если папка еще не выбрана, вызываем функцию выбора с подсказкой Toast
        if (!gameFolderId) {
          const pickedId = await selectGameFolder();
          if (!pickedId) {
            resetButton(buttonElement, originalText);
            return;
          }
        }

        // Скачиваем файл и сохраняем строго через FileReader base64
        const scriptUrl = script.download_url || script.local_url || `./scripts/${targetFileName}`;
        let response;
        try {
          response = await fetch(scriptUrl);
          if (!response.ok) throw new Error(`HTTP ${response.status}`);
        } catch (fetchErr) {
          if (script.local_url && script.local_url !== scriptUrl) {
            response = await fetch(script.local_url);
          } else {
            throw fetchErr;
          }
        }

        const blob = await response.blob();
        const reader = new FileReader();
        reader.readAsDataURL(blob);
        reader.onloadend = async () => {
          try {
            const base64data = reader.result.split(',')[1];
            await window.Capacitor.Plugins.ScopedStorage.writeFile({
              folder: { id: gameFolderId },
              path: targetFileName,
              data: base64data,
              encoding: 'base64',
              mimeType: 'application/octet-stream'
            });

            showToast(`Успешно установлено: ${targetFileName}!`, 'success');
            vibrate([30, 50, 30]);
          } catch (writeErr) {
            console.error('ScopedStorage write error:', writeErr);
            showToast('Ошибка записи файла: ' + (writeErr.message || 'нет доступа'), 'error');
            await downloadViaBrowser(script);
          } finally {
            resetButton(buttonElement, originalText);
          }
        };
      } catch (err) {
        console.error('ScopedStorage error:', err);
        showToast('Ошибка плагина: скачиваем файл через браузер...', 'info');
        await downloadViaBrowser(script);
        resetButton(buttonElement, originalText);
      }
    } else {
      // 2. Если открыто в обычном браузере — скачивание через Blob + <a> с download
      await downloadViaBrowser(script);
      resetButton(buttonElement, originalText);
    }
  }

  // Скачивание в браузере через fetch -> Blob -> createObjectURL -> a.download = `${script.id}.${extension}`
  async function downloadViaBrowser(script) {
    const ext = getScriptExtension(script);
    const fileName = `${script.id}.${ext}`;
    const primaryUrl = script.download_url || script.local_url || `./scripts/${fileName}`;
    const fallbackUrl = script.local_url || `./scripts/${fileName}`;

    let blob = null;

    try {
      // Скачиваем файл по ссылке (fetch) и получаем Blob
      const response = await fetch(primaryUrl);
      if (!response.ok) throw new Error(`HTTP ${response.status}`);
      blob = await response.blob();
    } catch (err) {
      console.warn('Ошибка fetch по основной ссылке:', err);
      // Если удаленный сервер заблокирован по CORS или недоступен, пробуем локальную копию
      try {
        if (fallbackUrl && fallbackUrl !== primaryUrl) {
          const fallbackResp = await fetch(fallbackUrl);
          if (fallbackResp.ok) {
            blob = await fallbackResp.blob();
          }
        }
      } catch (fallbackErr) {
        console.warn('Ошибка fetch локальной копии:', fallbackErr);
      }
    }

    if (blob) {
      // Создаем ссылку через URL.createObjectURL(blob)
      const objectUrl = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = objectUrl;
      // Задаем a.download = `${script.id}.${extension}`
      a.download = fileName;
      document.body.appendChild(a);
      // Программно нажимаем на ссылку
      a.click();
      setTimeout(() => {
        document.body.removeChild(a);
        URL.revokeObjectURL(objectUrl);
      }, 300);
      showToast(`Файл ${fileName} скачан в Загрузки!`, 'success');
    } else {
      // Прямой fallback если fetch заблокирован браузером
      const a = document.createElement('a');
      a.href = primaryUrl;
      a.download = fileName;
      a.target = '_blank';
      document.body.appendChild(a);
      a.click();
      document.body.removeChild(a);
      showToast(`Начато скачивание ${fileName}...`, 'info');
    }
  }

  function resetButton(btn, originalHtml) {
    setTimeout(() => {
      btn.classList.remove('loading');
      btn.innerHTML = originalHtml;
    }, 400);
  }

  // Функция "Поделиться" (navigator.share или копирование ссылки)
  function shareScript(script) {
    vibrate(25);
    const shareUrl = window.location.href.split('#')[0] + `#script-${script.id}`;
    const title = `Скрипт ${script.name || script.title} (Arizona RP Mobile)`;
    const text = `Скачать проверенный Lua-скрипт «${script.name}» для MonetLoader на Arizona RP Mobile:`;

    if (navigator.share) {
      navigator.share({
        title: title,
        text: text,
        url: shareUrl
      }).catch((err) => {
        if (err.name !== 'AbortError') {
          copyToClipboard(shareUrl, 'Ссылка на скрипт скопирована!');
        }
      });
    } else {
      copyToClipboard(shareUrl, 'Ссылка на скрипт скопирована в буфер обмена!');
    }
  }

  // ==========================================================================
  // FIREBASE REALTIME DATABASE: РЕЙТИНГ (ratings/{script_id})
  // ==========================================================================
  function initRealtimeRatingsListener() {
    if (!isFirebaseReady || !db) return;

    try {
      const ratingsRef = ref(db, 'ratings');
      onValue(ratingsRef, (snapshot) => {
        const val = snapshot.val();
        if (val && typeof val === 'object') {
          state.ratings = { ...state.ratings, ...val };
          try {
            localStorage.setItem(CONFIG.STORAGE_KEYS.LOCAL_RATINGS, JSON.stringify(state.ratings));
          } catch (e) {}

          updateAllCardRatingsUI();
          if (state.activeScriptModal) {
            updateModalRatingUI(state.activeScriptModal.id);
          }
        }
      }, (err) => {
        console.warn('Realtime ratings warning:', err);
      });
    } catch (err) {
      console.warn('Ошибка подключения рейтинга:', err);
    }
  }

  // Голосование (За / Против)
  async function voteScript(scriptId, voteType) {
    const previousVote = state.userVotes[scriptId] || null;
    let newVote = previousVote === voteType ? null : voteType;

    if (newVote) {
      state.userVotes[scriptId] = newVote;
    } else {
      delete state.userVotes[scriptId];
    }
    saveUserVotes();
    vibrate(25);

    applyLocalVoteUpdate(scriptId, previousVote, newVote);
    updateModalRatingUI(scriptId);
    updateAllCardRatingsUI();

    if (isFirebaseReady && db) {
      try {
        const scriptRatingRef = ref(db, `ratings/${scriptId}`);
        await runTransaction(scriptRatingRef, (currentData) => {
          const current = currentData || { up: 0, down: 0 };
          let up = Number(current.up) || 0;
          let down = Number(current.down) || 0;

          if (previousVote === 'up') up = Math.max(0, up - 1);
          if (previousVote === 'down') down = Math.max(0, down - 1);

          if (newVote === 'up') up += 1;
          if (newVote === 'down') down += 1;

          return { up, down };
        });

        showToast(newVote === 'up' ? 'Голос ЗА принят! 👍' : newVote === 'down' ? 'Голос ПРОТИВ принят 👎' : 'Голос отменен', 'success');
      } catch (err) {
        console.warn('Firebase vote error:', err);
      }
    }
  }

  function applyLocalVoteUpdate(scriptId, previousVote, newVote) {
    if (!state.ratings[scriptId]) {
      state.ratings[scriptId] = { up: 0, down: 0 };
    }
    let up = Number(state.ratings[scriptId].up) || 0;
    let down = Number(state.ratings[scriptId].down) || 0;

    if (previousVote === 'up') up = Math.max(0, up - 1);
    if (previousVote === 'down') down = Math.max(0, down - 1);

    if (newVote === 'up') up += 1;
    if (newVote === 'down') down += 1;

    state.ratings[scriptId] = { up, down };
  }

  function formatNumber(num) {
    const n = Math.max(0, Number(num) || 0);
    if (n >= 1000000) return (n / 1000000).toFixed(1).replace(/\.0$/, '') + 'M';
    if (n >= 10000) return (n / 1000).toFixed(1).replace(/\.0$/, '') + 'k';
    return n.toLocaleString('ru-RU');
  }

  function getRatingTheme(percentage, total) {
    if (total === 0) {
      return {
        badgeColor: '#38bdf8',
        badgeBg: 'rgba(56, 189, 248, 0.12)',
        badgeBorder: 'rgba(56, 189, 248, 0.3)',
        fillGradient: 'linear-gradient(90deg, #38bdf8, #60a5fa)',
        icon: '⭐',
        label: 'Новый скрипт',
        cardChipClass: 'rate-theme-new'
      };
    }
    if (percentage >= 75) {
      return {
        badgeColor: '#10b981',
        badgeBg: 'rgba(16, 185, 129, 0.12)',
        badgeBorder: 'rgba(16, 185, 129, 0.3)',
        fillGradient: 'linear-gradient(90deg, #10b981, #34d399)',
        icon: '👍',
        label: `${percentage}% рекомендуют`,
        cardChipClass: 'rate-theme-high'
      };
    }
    if (percentage >= 45) {
      return {
        badgeColor: '#f59e0b',
        badgeBg: 'rgba(245, 158, 11, 0.12)',
        badgeBorder: 'rgba(245, 158, 11, 0.3)',
        fillGradient: 'linear-gradient(90deg, #f59e0b, #fbbf24)',
        icon: '⚖️',
        label: `${percentage}% нейтрально`,
        cardChipClass: 'rate-theme-mid'
      };
    }
    return {
      badgeColor: '#ef4444',
      badgeBg: 'rgba(239, 68, 68, 0.12)',
      badgeBorder: 'rgba(239, 68, 68, 0.3)',
      fillGradient: 'linear-gradient(90deg, #ef4444, #f87171)',
      icon: '👎',
      label: `${percentage}% не рекомендуют`,
      cardChipClass: 'rate-theme-low'
    };
  }

  function getScriptRating(scriptId) {
    const r = state.ratings[scriptId] || INITIAL_SEED_RATINGS[scriptId] || { up: 0, down: 0 };
    const up = Math.max(0, Number(r.up) || 0);
    const down = Math.max(0, Number(r.down) || 0);
    const total = up + down;
    const percentage = total > 0 ? Math.round((up / total) * 100) : 100;
    return { up, down, total, percentage };
  }

  function updateAllCardRatingsUI() {
    state.allScripts.forEach(script => {
      const chip = document.getElementById(`card-rate-${script.id}`);
      if (chip) {
        const r = getScriptRating(script.id);
        const theme = getRatingTheme(r.percentage, r.total);
        chip.className = `card-rating-chip ${theme.cardChipClass}`;
        if (r.total === 0) {
          chip.innerHTML = `${theme.icon} <span>Новый</span>`;
        } else {
          chip.innerHTML = `${theme.icon} <span>${r.percentage}%</span> <span style="font-size:0.68rem; opacity:0.75;">(${formatNumber(r.up)})</span>`;
        }
      }
    });
  }

  function updateModalRatingUI(scriptId) {
    const ratingCard = document.getElementById('modal-ratings-card');
    if (!ratingCard) return;

    const r = getScriptRating(scriptId);
    const userVote = state.userVotes[scriptId] || null;
    const theme = getRatingTheme(r.percentage, r.total);

    const pill = ratingCard.querySelector('.ratings-score-pill');
    if (pill) {
      pill.textContent = theme.label;
      pill.style.color = theme.badgeColor;
      pill.style.backgroundColor = theme.badgeBg;
      pill.style.borderColor = theme.badgeBorder;
    }

    const btnUp = ratingCard.querySelector('.btn-rate.rate-up');
    if (btnUp) {
      btnUp.classList.toggle('active', userVote === 'up');
      const count = btnUp.querySelector('.rate-count');
      if (count) count.textContent = formatNumber(r.up);
    }

    const btnDown = ratingCard.querySelector('.btn-rate.rate-down');
    if (btnDown) {
      btnDown.classList.toggle('active', userVote === 'down');
      const count = btnDown.querySelector('.rate-count');
      if (count) count.textContent = formatNumber(r.down);
    }

    const fill = ratingCard.querySelector('.rating-progress-fill');
    if (fill) {
      fill.style.width = `${r.total === 0 ? 100 : r.percentage}%`;
      fill.style.background = theme.fillGradient;
    }

    const caption = ratingCard.querySelector('.rating-stats-caption');
    if (caption) {
      caption.innerHTML = `
        <span>👍 ${formatNumber(r.up)} за · 👎 ${formatNumber(r.down)} против</span>
        <span>Всего: ${formatNumber(r.total)}</span>
      `;
    }
  }



  // ==========================================================================
  // ЗАГРУЗКА И ОТОБРАЖЕНИЕ КАТАЛОГА (scripts.json)
  // ==========================================================================
  async function fetchScriptsCatalog() {
    state.loading = true;
    renderSkeletonLoaders();

    try {
      const response = await fetch(CONFIG.SCRIPTS_JSON_URL + '?t=' + Date.now());
      if (!response.ok) throw new Error('HTTP error ' + response.status);

      const data = await response.json();
      // Загружаем данные и сразу отфильтровываем скрытые скрипты
state.allScripts = Array.isArray(data) ? data.filter(script => !script.hidden) : [];
      state.loading = false;
      applyFiltersAndRender();
      updateCategoryCounts();
      updateAllCardRatingsUI();
    } catch (err) {
      console.warn('Ошибка загрузки scripts.json, используется резерв:', err);
      useOfflineFallbackCatalog();
    }
  }

  function useOfflineFallbackCatalog() {
    state.allScripts = [
      {
        id: "central-cleaner",
        name: "Central Cleaner & FPS Boost",
        author: "@chapochka",
        version: "2.4",
        category: "Оптимизация",
        description: "Очистка кэша текстур на Центральном Рынке и Автобазаре. Стабилизирует кадры на слабых устройствах.",
        download_url: "./scripts/central_cleaner.lua",
        color: "#ff6a3d",
        command: "/cleaner",
        telegram: "chapochka",
        isNew: false
      },
      {
        id: "arizona-helper",
        name: "Arizona State Helper Mobile",
        author: "@vlad_samp",
        version: "3.1",
        category: "Хелперы",
        description: "Многофункциональный хелпер для гос. структур (МВД, МЗ, Армия) и повседневной игры.",
        download_url: "./scripts/arizona_helper.lua",
        color: "#38bdf8",
        command: "/azhelp",
        telegram: "vlad_samp",
        isNew: true
      },
      {
        id: "binder-master",
        name: "Binder Master Touch",
        author: "@morty_dev",
        version: "1.8",
        category: "Бинды",
        description: "Сенсорные наэкранные кнопки для быстрого использования аптечки, маски и открытия авто.",
        download_url: "./scripts/binder_master.lua",
        color: "#10b981",
        command: "/bm",
        telegram: "morty_dev",
        isNew: false
      }
    ];
    state.loading = false;
    applyFiltersAndRender();
    updateCategoryCounts();
    updateAllCardRatingsUI();
  }

  function applyFiltersAndRender() {
    let list = [...state.allScripts];

    if (state.activeCategory === 'fav') {
      list = list.filter(item => state.favorites.has(item.id));
    } else if (state.activeCategory !== 'all') {
      list = list.filter(item => item.category === state.activeCategory);
    }

    if (state.searchQuery) {
      const q = state.searchQuery;
      list = list.filter(item => {
        return (
          (item.name && item.name.toLowerCase().includes(q)) ||
          (item.author && item.author.toLowerCase().includes(q)) ||
          (item.command && item.command.toLowerCase().includes(q)) ||
          (item.description && item.description.toLowerCase().includes(q))
        );
      });
    }

    if (state.sortBy === 'popular') {
      list.sort((a, b) => {
        const rateA = getScriptRating(a.id);
        const rateB = getScriptRating(b.id);
        return rateB.up - rateA.up;
      });
    } else if (state.sortBy === 'new') {
      list.sort((a, b) => String(b.version || '').localeCompare(String(a.version || '')));
    } else if (state.sortBy === 'name') {
      list.sort((a, b) => String(a.name || '').localeCompare(String(b.name || ''), 'ru'));
    }

    state.filteredScripts = list;
    renderScriptsFeed(list);
    
    if (el.totalCount) {
      el.totalCount.textContent = `${list.length} ${getNoun(list.length, 'скрипт', 'скрипта', 'скриптов')}`;
    }
  }

  function updateCategoryCounts() {
    const counts = { all: state.allScripts.length, fav: state.favorites.size };
    state.allScripts.forEach(s => {
      counts[s.category] = (counts[s.category] || 0) + 1;
    });

    document.querySelectorAll('.filter-chip').forEach(chip => {
      const cat = chip.dataset.category;
      const span = chip.querySelector('.chip-count');
      if (span && counts[cat] !== undefined) {
        span.textContent = counts[cat];
      }
    });
  }

  function renderSkeletonLoaders() {
    el.feed.innerHTML = `
      <div class="skeleton-card">
        <div class="skeleton-shimmer sk-banner"></div>
        <div class="skeleton-shimmer sk-title"></div>
        <div class="skeleton-shimmer sk-author"></div>
        <div class="skeleton-shimmer sk-text"></div>
        <div class="skeleton-shimmer sk-bar"></div>
      </div>
      <div class="skeleton-card">
        <div class="skeleton-shimmer sk-banner"></div>
        <div class="skeleton-shimmer sk-title"></div>
        <div class="skeleton-shimmer sk-author"></div>
        <div class="skeleton-shimmer sk-text"></div>
        <div class="skeleton-shimmer sk-bar"></div>
      </div>
    `;
  }

  function renderScriptsFeed(list) {
    if (list.length === 0) {
      el.feed.innerHTML = `
        <div class="empty-state">
          <div class="empty-icon">
            <svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <circle cx="11" cy="11" r="8"></circle>
              <line x1="21" y1="21" x2="16.65" y2="16.65"></line>
            </svg>
          </div>
          <h3>Скрипты не найдены</h3>
          <p>Попробуйте изменить поисковый запрос или фильтр</p>
        </div>
      `;
      return;
    }

    el.feed.innerHTML = '';
    const fragment = document.createDocumentFragment();

    list.forEach(script => {
      const card = createScriptCardElement(script);
      fragment.appendChild(card);
    });

    el.feed.appendChild(fragment);
  }

  function createScriptCardElement(script) {
    const categoryInfo = CATEGORY_COLORS[script.category] || CATEGORY_COLORS['default'];
    const accentColor = script.color || categoryInfo.color;
    const isFav = state.favorites.has(script.id);
    const rating = getScriptRating(script.id);
    const theme = getRatingTheme(rating.percentage, rating.total);

    const bannerBackground = (script.image && script.image.trim() !== '')
      ? `background-image: url('${script.image}'); background-size: cover; background-position: center;`
      : `background: linear-gradient(135deg, ${accentColor} 0%, #111827 100%);`;

    const card = document.createElement('article');
    card.className = 'script-card';
    card.dataset.id = script.id;

    card.innerHTML = `
      <div class="card-banner" style="${bannerBackground}">
        <div class="card-banner-overlay"></div>
        
        <!-- Яркий бейдж NEW, если isNew === true -->
        ${script.isNew ? `<span class="card-badge-new">NEW</span>` : ''}

        <span class="card-category-tag">${categoryInfo.icon} ${escapeHtml(script.category || 'Скрипт')}</span>
        <div class="card-verified-tag" title="Проверено на безопасность">
          <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3">
            <polyline points="20 6 9 17 4 12"></polyline>
          </svg>
          <span>MonetLoader</span>
        </div>
      </div>

      <div class="card-body">
        <h2 class="card-title">${escapeHtml(script.name || script.title)}</h2>

        <div class="card-author-meta">
          <span>Автор: <b>${escapeHtml(script.author || 'Неизвестен')}</b></span>
          <span aria-hidden="true">·</span>
          <span>v${escapeHtml(script.version || '1.0')}</span>
        </div>

        <p class="card-summary">${escapeHtml(script.description || '')}</p>

        <div class="card-details-row">
          <div class="card-command-chip" data-cmd="${escapeHtml(script.command || '/help')}" title="Нажмите, чтобы скопировать команду">
            <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <polyline points="4 17 10 11 4 5"></polyline>
              <line x1="12" y1="19" x2="20" y2="19"></line>
            </svg>
            <span>${escapeHtml(script.command || '/help')}</span>
          </div>

          <div class="card-meta-metrics">
            <div class="card-rating-chip ${theme.cardChipClass}" id="card-rate-${script.id}" title="Рейтинг игроков">
              ${rating.total === 0 
                ? `${theme.icon} <span>Новый</span>` 
                : `${theme.icon} <span>${rating.percentage}%</span> <span style="font-size:0.68rem; opacity:0.75;">(${formatNumber(rating.up)})</span>`}
            </div>
          </div>
        </div>

        <div class="card-actions-strip">
          <button class="btn-fav-card ${isFav ? 'active' : ''}" data-action="toggle-fav" aria-label="В избранное">
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <path d="M20.84 4.61a5.5 5.5 0 0 0-7.78 0L12 5.67l-1.06-1.06a5.5 5.5 0 0 0-7.78 7.78l1.06 1.06L12 21.23l7.78-7.78 1.06-1.06a5.5 5.5 0 0 0 0-7.78z"></path>
            </svg>
          </button>
          
          <button class="btn-download-card" data-action="quick-install">
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2">
              <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"></path>
              <polyline points="7 10 12 15 17 10"></polyline>
              <line x1="12" y1="15" x2="12" y2="3"></line>
            </svg>
            <span>Установить</span>
          </button>
        </div>
      </div>
    `;

    card.addEventListener('click', (e) => {
      const isCmd = e.target.closest('.card-command-chip');
      const isFavBtn = e.target.closest('[data-action="toggle-fav"]');
      const isInstallBtn = e.target.closest('[data-action="quick-install"]');

      if (isCmd) {
        e.stopPropagation();
        const cmd = isCmd.dataset.cmd;
        copyToClipboard(cmd, `Команда ${cmd} скопирована!`);
        return;
      }

      if (isFavBtn) {
        e.stopPropagation();
        toggleFavorite(script.id, isFavBtn);
        return;
      }

      if (isInstallBtn) {
        e.stopPropagation();
        installScript(script, isInstallBtn);
        return;
      }

      openDetailModal(script);
    });

    return card;
  }

  function toggleFavorite(id, favBtn) {
    vibrate(25);
    if (state.favorites.has(id)) {
      state.favorites.delete(id);
      showToast('Удалено из избранного', 'info');
      if (favBtn) favBtn.classList.remove('active');
    } else {
      state.favorites.add(id);
      showToast('Добавлено в избранное ⭐', 'success');
      if (favBtn) favBtn.classList.add('active');
    }

    saveFavorites();
    updateCategoryCounts();

    if (state.activeCategory === 'fav') {
      applyFiltersAndRender();
    }
  }

  // ==========================================================================
  // BOTTOM SHEET (МОДАЛЬНОЕ ОКНО СКРИПТА С РЕЙТИНГОМ, СВЯЗЬЮ С АВТОРОМ И КОММЕНТАРИЯМИ)
  // ==========================================================================
  function openDetailModal(script) {
    state.activeScriptModal = script;
    const categoryInfo = CATEGORY_COLORS[script.category] || CATEGORY_COLORS['default'];
    const accentColor = script.color || categoryInfo.color;
    const isFav = state.favorites.has(script.id);
    const rating = getScriptRating(script.id);
    const userVote = state.userVotes[script.id] || null;
    const tgUsername = script.telegram ? String(script.telegram).replace(/^@/, '') : '';

    const heroBackground = (script.image && script.image.trim() !== '')
      ? `background-image: url('${script.image}'); background-size: cover; background-position: center;`
      : `background: linear-gradient(135deg, ${accentColor} 0%, #1e293b 100%);`;

    el.detailBody.innerHTML = `
      <div class="modal-header-hero" style="${heroBackground}">
        <div class="modal-header-tags">
          <span class="card-category-tag">${categoryInfo.icon} ${escapeHtml(script.category || 'Скрипт')}</span>
          <div class="card-verified-tag">
            <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3">
              <polyline points="20 6 9 17 4 12"></polyline>
            </svg>
            <span>Clean Lua</span>
          </div>
        </div>
        <h2 class="modal-title">${escapeHtml(script.name || script.title)}</h2>
        <div class="modal-author-row">
          <span>Автор скрипта: <b>${escapeHtml(script.author || 'Неизвестен')}</b></span>
        </div>
      </div>

      <div class="modal-specs-grid">
        <div class="spec-cell">
          <span>Версия</span>
          <strong>v${escapeHtml(script.version || '1.0')}</strong>
        </div>
        <div class="spec-cell">
          <span>Формат</span>
          <strong>.LUA</strong>
        </div>
        <div class="spec-cell">
          <span>Платформа</span>
          <strong>MonetLoader</strong>
        </div>
      </div>

      <!-- Кнопка связи с автором в Telegram (если указан) -->
      ${tgUsername ? `
        <a href="https://t.me/${escapeHtml(tgUsername)}" target="_blank" rel="noopener noreferrer" class="btn-author-telegram">
          <svg width="18" height="18" viewBox="0 0 24 24" fill="currentColor">
            <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm4.64 6.8c-.15 1.58-.8 5.42-1.13 7.19-.14.75-.42 1-.68 1.03-.58.05-1.02-.38-1.58-.75-.88-.58-1.38-.94-2.23-1.5-.99-.65-.35-1.01.22-1.59.15-.15 2.71-2.48 2.76-2.69a.2.2 0 0 0-.05-.18c-.06-.05-.14-.03-.21-.02-.09.02-1.49.95-4.22 2.79-.4.27-.76.41-1.08.4-.36-.01-1.04-.2-1.55-.37-.63-.2-1.12-.31-1.08-.66.02-.18.27-.36.75-.55 2.92-1.27 4.86-2.11 5.83-2.51 2.78-1.16 3.35-1.36 3.73-1.36.08 0 .27.02.39.12.1.08.13.19.14.27-.01.06.01.24 0 .38z"/>
          </svg>
          <span>Написать автору (@${escapeHtml(tgUsername)})</span>
        </a>
      ` : ''}

      <!-- Карточка рейтинга -->
      <div class="ratings-card" id="modal-ratings-card">
        <div class="ratings-header-row">
          <div class="ratings-title">
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2">
              <polygon points="12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2"></polygon>
            </svg>
            <span>Рейтинг игроков</span>
          </div>
          <span class="ratings-score-pill">${rating.percentage}% рекомендуют</span>
        </div>

        <div class="rating-actions-grid">
          <button class="btn-rate rate-up ${userVote === 'up' ? 'active' : ''}" id="rate-up-btn">
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <path d="M14 9V5a3 3 0 0 0-3-3l-4 9v11h11.28a2 2 0 0 0 2-1.7l1.38-9a2 2 0 0 0-2-2.3zM7 22H4a2 2 0 0 1-2-2v-7a2 2 0 0 1 2-2h3"></path>
            </svg>
            <span>За (<b class="rate-count">${rating.up}</b>)</span>
          </button>

          <button class="btn-rate rate-down ${userVote === 'down' ? 'active' : ''}" id="rate-down-btn">
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <path d="M10 15v4a3 3 0 0 0 3 3l4-9V2H5.72a2 2 0 0 0-2 1.7l-1.38 9a2 2 0 0 0 2 2.3zm7-13h3a2 2 0 0 1 2 2v7a2 2 0 0 1-2 2h-3"></path>
            </svg>
            <span>Против (<b class="rate-count">${rating.down}</b>)</span>
          </button>
        </div>

        <div class="rating-bar-wrap">
          <div class="rating-progress-track">
            <div class="rating-progress-fill" style="width: ${rating.percentage}%;"></div>
          </div>
          <div class="rating-stats-caption">
            <span>👍 ${rating.up} за · 👎 ${rating.down} против</span>
            <span>Всего: ${rating.total}</span>
          </div>
        </div>
      </div>

      <!-- Команда активации -->
      <div class="command-activation-box">
        <div class="cmd-info">
          <span class="cmd-label">Команда активации</span>
          <span class="cmd-text">${escapeHtml(script.command || '/help')}</span>
        </div>
        <button class="btn-cmd-copy" id="modal-copy-cmd-btn">
          <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <rect x="9" y="9" width="13" height="13" rx="2" ry="2"></rect>
            <path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"></path>
          </svg>
          <span>Скопировать</span>
        </button>
      </div>

      <!-- Описание -->
      <div style="margin-bottom: 8px;">
        <h3 class="modal-desc-heading">Описание скрипта</h3>
        <p class="modal-desc-text">${escapeHtml(script.description || '')}</p>
      </div>
    `;

    // Нижние кнопки действия модального окна (Избранное, Поделиться, Установить)
    el.detailActionsFooter.innerHTML = `
      <button class="btn-fav-large ${isFav ? 'active' : ''}" id="modal-fav-btn" aria-label="В избранное">
        <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <path d="M20.84 4.61a5.5 5.5 0 0 0-7.78 0L12 5.67l-1.06-1.06a5.5 5.5 0 0 0-7.78 7.78l1.06 1.06L12 21.23l7.78-7.78 1.06-1.06a5.5 5.5 0 0 0 0-7.78z"></path>
        </svg>
      </button>

      <button class="btn-share-large" id="modal-share-btn" aria-label="Поделиться">
        <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <circle cx="18" cy="5" r="3"></circle>
          <circle cx="6" cy="12" r="3"></circle>
          <circle cx="18" cy="19" r="3"></circle>
          <line x1="8.59" y1="13.51" x2="15.42" y2="17.49"></line>
          <line x1="15.41" y1="6.51" x2="8.59" y2="10.49"></line>
        </svg>
      </button>

      <button class="btn-install-primary" id="modal-install-btn">
        <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.3">
          <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"></path>
          <polyline points="7 10 12 15 17 10"></polyline>
          <line x1="12" y1="15" x2="12" y2="3"></line>
        </svg>
        <span>Установить в игру</span>
      </button>
    `;

    // Привязка событий внутри модального окна
    document.getElementById('rate-up-btn')?.addEventListener('click', () => voteScript(script.id, 'up'));
    document.getElementById('rate-down-btn')?.addEventListener('click', () => voteScript(script.id, 'down'));
    
    document.getElementById('modal-copy-cmd-btn')?.addEventListener('click', () => {
      copyToClipboard(script.command || '/help', 'Команда скопирована!');
    });

    document.getElementById('modal-fav-btn')?.addEventListener('click', function() {
      toggleFavorite(script.id, this);
    });

    // Кнопка поделиться
    document.getElementById('modal-share-btn')?.addEventListener('click', () => {
      shareScript(script);
    });

    document.getElementById('modal-install-btn')?.addEventListener('click', function() {
      installScript(script, this);
    });

    updateModalRatingUI(script.id);

    el.detailModal.classList.add('open');
    document.body.style.overflow = 'hidden';
  }

  function closeDetailModal() {
    el.detailModal.classList.remove('open');
    document.body.style.overflow = '';
    state.activeScriptModal = null;
  }

  // --- Модальное окно настроек MonetLoader ---
  function openSettingsModal() {
    updateFolderStatusUI();
    el.settingsModal.classList.add('open');
    document.body.style.overflow = 'hidden';
  }

  function closeSettingsModal() {
    el.settingsModal.classList.remove('open');
    document.body.style.overflow = '';
  }

  // --- Жест свайпа вниз для закрытия Bottom Sheet ---
  function setupModalDragToClose() {
    let startY = 0;
    let currentY = 0;
    let isDragging = false;
    const sheet = el.detailModal.querySelector('.bottom-sheet');
    const handle = el.detailDragHandle;

    if (!handle || !sheet) return;

    handle.addEventListener('touchstart', (e) => {
      startY = e.touches[0].clientY;
      isDragging = true;
      sheet.style.transition = 'none';
    }, { passive: true });

    window.addEventListener('touchmove', (e) => {
      if (!isDragging) return;
      currentY = e.touches[0].clientY;
      const deltaY = currentY - startY;
      if (deltaY > 0) {
        sheet.style.transform = `translateY(${deltaY}px)`;
      }
    }, { passive: true });

    window.addEventListener('touchend', () => {
      if (!isDragging) return;
      isDragging = false;
      sheet.style.transition = '';
      if (currentY - startY > 90) {
        closeDetailModal();
      } else {
        sheet.style.transform = '';
      }
    });
  }

  // --- Навигация и фильтрация ---
  function bindEvents() {
    let debounceTimer;
    el.searchInput.addEventListener('input', (e) => {
      clearTimeout(debounceTimer);
      const val = e.target.value.trim();
      el.searchClear.style.display = val ? 'flex' : 'none';
      debounceTimer = setTimeout(() => {
        state.searchQuery = val.toLowerCase();
        applyFiltersAndRender();
      }, 150);
    });

    el.searchClear.addEventListener('click', () => {
      el.searchInput.value = '';
      el.searchClear.style.display = 'none';
      state.searchQuery = '';
      applyFiltersAndRender();
      el.searchInput.focus();
    });

    el.categoryChips.addEventListener('click', (e) => {
      const chip = e.target.closest('.filter-chip');
      if (!chip) return;
      
      const cat = chip.dataset.category;
      if (cat === state.activeCategory) return;
      
      document.querySelectorAll('.filter-chip').forEach(c => c.classList.remove('active'));
      chip.classList.add('active');
      
      state.activeCategory = cat;
      applyFiltersAndRender();
      vibrate(20);
    });

    el.sortSelect.addEventListener('change', (e) => {
      state.sortBy = e.target.value;
      applyFiltersAndRender();
    });

    if (el.envBadge) {
      el.envBadge.addEventListener('click', openSettingsModal);
    }
    if (el.detailCloseBtn) {
      el.detailCloseBtn.addEventListener('click', closeDetailModal);
    }
    if (el.detailModal) {
      el.detailModal.addEventListener('click', (e) => {
        if (e.target === el.detailModal) closeDetailModal();
      });
    }

    if (el.settingsCloseBtn) {
      el.settingsCloseBtn.addEventListener('click', closeSettingsModal);
    }
    if (el.settingsModal) {
      el.settingsModal.addEventListener('click', (e) => {
        if (e.target === el.settingsModal) closeSettingsModal();
      });
    }

    // Кнопка сброса папки игры
    if (el.resetFolderBtn) {
      el.resetFolderBtn.addEventListener('click', () => {
        localStorage.removeItem(CONFIG.STORAGE_KEYS.GAME_FOLDER);
        gameFolderId = null;
        updateFolderStatusUI();
        showToast('Выбор папки сброшен! Теперь можно выбрать папку заново.', 'info');
      });
    }

    // Онбординг события
    if (el.onboardingPickFolderBtn) {
      el.onboardingPickFolderBtn.addEventListener('click', async () => {
        closeOnboardingModal();
        await selectGameFolder();
      });
    }

    if (el.onboardingSkipBtn) {
      el.onboardingSkipBtn.addEventListener('click', () => {
        closeOnboardingModal();
      });
    }

    setupModalDragToClose();

    // Нижние вкладки навигации (480px панель)
    el.navTabs.forEach(tab => {
      tab.addEventListener('click', () => {
        const dest = tab.dataset.nav;

        // Если нажата вкладка "Папка игры" (guide) — открываем модальное окно настроек/папки
        if (dest === 'guide') {
          openSettingsModal();
          vibrate(20);
          return;
        }

        if (dest === 'catalog') {
          state.activeCategory = 'all';
          syncActiveChip('all');
          applyFiltersAndRender();
          window.scrollTo({ top: 0, behavior: 'smooth' });
        } else if (dest === 'favs') {
          state.activeCategory = 'fav';
          syncActiveChip('fav');
          applyFiltersAndRender();
          window.scrollTo({ top: 0, behavior: 'smooth' });
        }

        el.navTabs.forEach(t => t.classList.remove('active'));
        tab.classList.add('active');
        vibrate(20);
      });
    });

    document.addEventListener('keydown', (e) => {
      if (e.key === 'Escape') {
        closeDetailModal();
        closeSettingsModal();
        closeOnboardingModal();
      }
    });
  }

  function syncActiveChip(category) {
    document.querySelectorAll('.filter-chip').forEach(c => {
      c.classList.toggle('active', c.dataset.category === category);
    });
  }

  // --- Вспомогательные утилиты ---
  function copyToClipboard(text, msg) {
    if (navigator.clipboard && navigator.clipboard.writeText) {
      navigator.clipboard.writeText(text).then(() => {
        showToast(msg, 'success');
        vibrate(25);
      });
    } else {
      const ta = document.createElement('textarea');
      ta.value = text;
      ta.style.position = 'fixed';
      ta.style.left = '-9999px';
      document.body.appendChild(ta);
      ta.select();
      document.execCommand('copy');
      document.body.removeChild(ta);
      showToast(msg, 'success');
      vibrate(25);
    }
  }

  function vibrate(pattern) {
    if ('vibrate' in navigator) {
      try { navigator.vibrate(pattern); } catch (e) {}
    }
  }

  function getNoun(number, one, two, five) {
    let n = Math.abs(number);
    n %= 100;
    if (n >= 5 && n <= 20) return five;
    n %= 10;
    if (n === 1) return one;
    if (n >= 2 && n <= 4) return two;
    return five;
  }

  function escapeHtml(str) {
    if (!str) return '';
    return String(str)
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&#039;');
  }

  // Toast-уведомления
  function showToast(message, type = 'info', duration = 3000) {
    const toast = document.createElement('div');
    toast.className = `toast toast-${type}`;

    let iconSvg = '';
    if (type === 'success') {
      iconSvg = `<svg class="toast-icon" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><polyline points="20 6 9 17 4 12"></polyline></svg>`;
    } else if (type === 'error') {
      iconSvg = `<svg class="toast-icon" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><circle cx="12" cy="12" r="10"></circle><line x1="15" y1="9" x2="9" y2="15"></line><line x1="9" y1="9" x2="15" y2="15"></line></svg>`;
    } else {
      iconSvg = `<svg class="toast-icon" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><circle cx="12" cy="12" r="10"></circle><line x1="12" y1="16" x2="12" y2="12"></line><line x1="12" y1="8" x2="12.01" y2="8"></line></svg>`;
    }

    toast.innerHTML = `
      ${iconSvg}
      <div class="toast-msg">${escapeHtml(message)}</div>
    `;

    el.toastContainer.appendChild(toast);

    setTimeout(() => {
      toast.classList.add('toast-out');
      setTimeout(() => {
        if (toast.parentNode) toast.parentNode.removeChild(toast);
      }, 250);
    }, duration);
  }

  // Запуск
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();
