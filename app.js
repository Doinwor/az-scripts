// 1. Подключаем Firebase прямо из интернета
import { initializeApp } from "https://www.gstatic.com/firebasejs/10.8.0/firebase-app.js";
import { getDatabase, ref, onValue, runTransaction } from "https://www.gstatic.com/firebasejs/10.8.0/firebase-database.js";

// 2. Твой конфиг из Firebase
const firebaseConfig = {
  apiKey: "AIzaSyCHZmCcwcd4rJ7Icw4WIK_DbuF4c1wkhtrk",
  authDomain: "az-scripts.firebaseapp.com",
  databaseURL: "https://az-scripts-default-rtdb.firebaseio.com",
  projectId: "az-scripts",
  storageBucket: "az-scripts.firebasestorage.app",
  messagingSenderId: "1057071984779",
  appId: "1:1057071984779:web:d008b2cc1e971707cfe48e",
  measurementId: "G-K6JF3J1C35"
};

const app = initializeApp(firebaseConfig);
const db = getDatabase(app);

document.addEventListener('DOMContentLoaded', () => {
    const scriptList = document.getElementById('script-list');
    const favoritesList = document.getElementById('favorites-list');
    const searchInput = document.getElementById('search-input');
    const pageTitle = document.getElementById('page-title');
    
    // Элементы модального окна
    const modal = document.getElementById('script-modal');
    const modalImage = document.getElementById('modal-image');
    const modalTitle = document.getElementById('modal-title');
    const modalAuthor = document.getElementById('modal-author');
    const modalDescription = document.getElementById('modal-description');
    const modalLoader = document.getElementById('modal-loader');
    const modalInstallBtn = document.getElementById('modal-install-btn');
    const closeModalBtn = document.getElementById('close-modal');

    let allScripts = [];
    let gameFolderId = localStorage.getItem('gameFolderId');
    let favorites = JSON.parse(localStorage.getItem('favorites') || '[]');
    let currentModalScript = null;

    function showToast(message, type = 'success') {
        const container = document.getElementById('toast-container');
        const toast = document.createElement('div');
        toast.className = `toast ${type}`;
        toast.innerText = message;
        container.appendChild(toast);
        setTimeout(() => { toast.style.animation = 'toastIn 0.3s reverse'; setTimeout(() => toast.remove(), 300); }, 3000);
    }

    fetch('scripts.json')
        .then(response => response.json())
        .then(data => {
            allScripts = data;
            renderCatalog(allScripts);
            renderFavorites();
        });

    // Подписка на изменения рейтинга в Firebase
    function listenRating(scriptId) {
        const scoreEl = document.getElementById(`score-${scriptId}`);
        const barEl = document.getElementById(`bar-${scriptId}`);
        if (!scoreEl || !barEl) return;

        const scriptRef = ref(db, 'ratings/' + scriptId);
        onValue(scriptRef, (snapshot) => {
            const data = snapshot.val() || { up: 0, down: 0 };
            const total = data.up + data.down;
            let score = 0;
            let percent = 50;

            if (total > 0) {
                score = ((data.up - data.down) / total * 100).toFixed(0);
                percent = (data.up / total) * 100;
            }

            scoreEl.innerText = score;
            scoreEl.style.color = score > 0 ? '#4ade80' : (score < 0 ? '#f87171' : '#888');
            barEl.style.width = `${percent}%`;
        });
    }

    // Голосование
    async function vote(scriptId, type) {
        const scriptRef = ref(db, 'ratings/' + scriptId);
        await runTransaction(scriptRef, (currentData) => {
            if (!currentData) currentData = { up: 0, down: 0 };
            if (type === 'up') currentData.up += 1;
            if (type === 'down') currentData.down += 1;
            return currentData;
        });
    }

    // Переключение вкладок
    document.querySelectorAll('.nav-item').forEach(item => {
        item.addEventListener('click', (e) => {
            e.preventDefault();
            document.querySelectorAll('.nav-item').forEach(nav => nav.classList.remove('active'));
            document.querySelectorAll('.view').forEach(view => view.classList.remove('active-view'));
            e.currentTarget.classList.add('active');
            const targetId = e.currentTarget.getAttribute('data-target');
            document.getElementById(targetId).classList.add('active-view');
            if(targetId === 'view-catalog') pageTitle.innerHTML = '<span>🛡️</span> Каталог';
            if(targetId === 'view-favorites') pageTitle.innerHTML = '<span>❤️</span> Избранное';
            if(targetId === 'view-settings') pageTitle.innerHTML = '<span>⚙️</span> Настройки';
        });
    });

    // Фильтры
    document.querySelectorAll('#category-filters .tag').forEach(tag => {
        tag.addEventListener('click', (e) => {
            document.querySelectorAll('#category-filters .tag').forEach(t => t.classList.remove('active'));
            e.target.classList.add('active');
            const category = e.target.getAttribute('data-category');
            if (category === 'all') renderCatalog(allScripts);
            else renderCatalog(allScripts.filter(s => s.category === category));
        });
    });

    // Настройки
    document.getElementById('reset-folder-btn').addEventListener('click', () => {
        localStorage.removeItem('gameFolderId');
        gameFolderId = null;
        showToast('Папка игры сброшена!', 'success');
    });

    function renderCatalog(scripts) {
        scriptList.innerHTML = ''; 
        if (scripts.length === 0) {
            scriptList.innerHTML = '<p style="text-align: center; color: #888;">Ничего не найдено.</p>';
            return;
        }
        scripts.forEach(script => scriptList.appendChild(createCard(script)));
    }

    function renderFavorites() {
        favoritesList.innerHTML = '';
        const favScripts = allScripts.filter(s => favorites.includes(s.id));
        if (favScripts.length === 0) {
            favoritesList.innerHTML = '<p style="text-align: center; color: #888;">Вы пока ничего не добавили в избранное.</p>';
            return;
        }
        favScripts.forEach(script => favoritesList.appendChild(createCard(script)));
    }

    function createCard(script) {
        const card = document.createElement('div');
        card.className = 'script-card';
        const isFav = favorites.includes(script.id);
        const bgImage = script.image ? `background-image: url('${script.image}');` : `background: ${script.color || '#2a2a35'};`;
        
        card.innerHTML = `
            <div class="card-image" style="${bgImage}">
                <span class="badge">✅ Проверено</span>
                <button class="fav-btn ${isFav ? 'active' : ''}" data-id="${script.id}">${isFav ? '❤️' : '🤍'}</button>
            </div>
            <div class="card-content">
                <h3 class="card-title">${script.name}</h3>
                <p class="card-author">Автор: <span>${script.author}</span></p>
                
                <!-- Блок рейтинга -->
                <div class="rating-row">
                    <div class="rating-buttons">
                        <button class="vote-btn" onclick="event.stopPropagation(); window.voteScript('${script.id}', 'up')">👍</button>
                        <button class="vote-btn" onclick="event.stopPropagation(); window.voteScript('${script.id}', 'down')">👎</button>
                    </div>
                    <div class="rating-bar-container">
                        <div class="rating-bar-bg">
                            <div class="rating-bar-fill" id="bar-${script.id}" style="width: 50%"></div>
                        </div>
                    </div>
                    <span class="rating-score" id="score-${script.id}">0</span>
                </div>

                <div class="card-tags">
                    <span class="mini-tag">${script.category}</span>
                    <span class="mini-tag">v${script.version}</span>
                </div>
                <div class="card-footer">
                    <span class="loader-type">${script.loader}</span>
                    <button class="install-btn" data-id="${script.id}" data-url="${script.download_url}">Установить</button>
                </div>
            </div>
        `;

        // Подписываемся на рейтинг для этой карточки
        setTimeout(() => listenRating(script.id), 0);

        card.querySelector('.fav-btn').addEventListener('click', (e) => {
            e.stopPropagation();
            const id = e.target.getAttribute('data-id');
            if (favorites.includes(id)) {
                favorites = favorites.filter(f => f !== id);
                e.target.classList.remove('active');
                e.target.innerText = '🤍';
            } else {
                favorites.push(id);
                e.target.classList.add('active');
                e.target.innerText = '❤️';
            }
            localStorage.setItem('favorites', JSON.stringify(favorites));
            renderFavorites();
        });

        card.querySelector('.install-btn').addEventListener('click', (e) => {
            e.stopPropagation();
            installScript(script.download_url, script.id, e.target);
        });

        card.addEventListener('click', () => openModal(script));
        return card;
    }

    // Делаем функцию голосования глобальной, чтобы onclick сработал
    window.voteScript = (id, type) => vote(id, type);

    function openModal(script) {
        currentModalScript = script;
        const bgImage = script.image ? `background-image: url('${script.image}');` : `background: ${script.color || '#2a2a35'};`;
        modalImage.style = bgImage;
        modalTitle.innerText = script.name;
        modalAuthor.innerText = script.author;
        modalDescription.innerText = script.description || "Описание отсутствует.";
        modalLoader.innerText = script.loader;
        modal.classList.add('active');
    }

    closeModalBtn.addEventListener('click', () => modal.classList.remove('active'));
    modal.addEventListener('click', (e) => { if (e.target === modal) modal.classList.remove('active'); });

    modalInstallBtn.addEventListener('click', () => {
        if (currentModalScript) installScript(currentModalScript.download_url, currentModalScript.id, modalInstallBtn);
    });

    async function installScript(url, name, btnElement) {
        if (!gameFolderId && window.Capacitor) {
            const selected = await selectFolder();
            if (!selected) { showToast('Без выбора папки установка невозможна!', 'error'); return; }
        }
        const originalText = btnElement.innerText;
        btnElement.innerText = 'Скачивание...';
        btnElement.disabled = true;

        try {
            const response = await fetch(url);
            const rawBlob = await response.blob();
            const blob = new Blob([rawBlob], { type: 'application/x-lua' });
            
            if (window.Capacitor) {
                const { ScopedStorage } = window.Capacitor.Plugins;
                const reader = new FileReader();
                reader.readAsDataURL(blob);
                reader.onloadend = async () => {
                    try {
                        const base64data = reader.result.split(',')[1];
                        await ScopedStorage.writeFile({
                            folder: { id: gameFolderId }, path: `${name}.lua`,
                            data: base64data, encoding: 'base64', mimeType: 'application/octet-stream'
                        });
                        showToast(`Файл ${name}.lua установлен!`, 'success');
                    } catch (err) {
                        showToast('Ошибка записи файла.', 'error');
                    } finally {
                        btnElement.innerText = originalText;
                        btnElement.disabled = false;
                    }
                };
            } else {
                const a = document.createElement('a');
                a.href = URL.createObjectURL(blob);
                a.download = `${name}.lua`;
                a.click();
                showToast(`Файл ${name}.lua скачан!`, 'success');
                btnElement.innerText = originalText;
                btnElement.disabled = false;
            }
        } catch (error) {
            showToast('Ошибка сети.', 'error');
            btnElement.innerText = originalText;
            btnElement.disabled = false;
        }
    }

    async function selectFolder() {
        try {
            const { ScopedStorage } = window.Capacitor.Plugins;
            const result = await ScopedStorage.pickFolder();
            if (result && result.folder && result.folder.id) {
                localStorage.setItem('gameFolderId', result.folder.id);
                gameFolderId = result.folder.id;
                showToast('Папка игры выбрана!', 'success');
                return true;
            }
        } catch (e) {
            showToast('Не удалось выбрать папку.', 'error');
        }
        return false;
    }

    searchInput.addEventListener('input', (e) => {
        const searchTerm = e.target.value.toLowerCase();
        const filtered = allScripts.filter(script => 
            script.name.toLowerCase().includes(searchTerm) || 
            script.author.toLowerCase().includes(searchTerm)
        );
        renderCatalog(filtered);
    });
});
