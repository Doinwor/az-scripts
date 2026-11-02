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

        // Клик по избранному (не открывает модалку)
        card.querySelector('.fav-btn').addEventListener('click', (e) => {
            e.stopPropagation(); // Останавливаем всплытие
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

        // Клик по кнопке установки (не открывает модалку)
        card.querySelector('.install-btn').addEventListener('click', (e) => {
            e.stopPropagation(); // Останавливаем всплытие
            installScript(script.download_url, script.id, e.target);
        });

        // Клик по самой карточке открывает модалку
        card.addEventListener('click', () => {
            openModal(script);
        });

        return card;
    }

    // Открытие модального окна
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

    // Закрытие модалки
    closeModalBtn.addEventListener('click', () => {
        modal.classList.remove('active');
    });
    modal.addEventListener('click', (e) => {
        if (e.target === modal) modal.classList.remove('active'); // Клик по фону закрывает
    });

    // Установка из модалки
    modalInstallBtn.addEventListener('click', () => {
        if (currentModalScript) {
            installScript(currentModalScript.download_url, currentModalScript.id, modalInstallBtn);
        }
    });

    // Общая функция установки
    async function installScript(url, name, btnElement) {
        if (!gameFolderId && window.Capacitor) {
            const selected = await selectFolder();
            if (!selected) {
                showToast('Без выбора папки установка невозможна!', 'error');
                return;
            }
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
