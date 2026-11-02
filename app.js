document.addEventListener('DOMContentLoaded', () => {
    const scriptList = document.getElementById('script-list');
    const favoritesList = document.getElementById('favorites-list');
    const searchInput = document.getElementById('search-input');
    const pageTitle = document.getElementById('page-title');
    
    let allScripts = [];
    let gameFolderId = localStorage.getItem('gameFolderId');
    
    // Загружаем избранное (или создаем пустой массив)
    let favorites = JSON.parse(localStorage.getItem('favorites') || '[]');

    // Функция для красивых уведомлений
    function showToast(message, type = 'success') {
        const container = document.getElementById('toast-container');
        const toast = document.createElement('div');
        toast.className = `toast ${type}`;
        toast.innerText = message;
        container.appendChild(toast);
        setTimeout(() => {
            toast.style.animation = 'toastIn 0.3s reverse';
            setTimeout(() => toast.remove(), 300);
        }, 3000);
    }

    // Загрузка базы
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
            // Убираем активный класс у всех
            document.querySelectorAll('.nav-item').forEach(nav => nav.classList.remove('active'));
            document.querySelectorAll('.view').forEach(view => view.classList.remove('active-view'));
            
            // Делаем активным нажатый
            e.currentTarget.classList.add('active');
            const targetId = e.currentTarget.getAttribute('data-target');
            document.getElementById(targetId).classList.add('active-view');

            // Меняем заголовок
            if(targetId === 'view-catalog') pageTitle.innerHTML = '<span>🛡️</span> Каталог';
            if(targetId === 'view-favorites') pageTitle.innerHTML = '<span>❤️</span> Избранное';
            if(targetId === 'view-settings') pageTitle.innerHTML = '<span>⚙️</span> Настройки';
        });
    });

    // Фильтрация по категориям
    document.querySelectorAll('#category-filters .tag').forEach(tag => {
        tag.addEventListener('click', (e) => {
            document.querySelectorAll('#category-filters .tag').forEach(t => t.classList.remove('active'));
            e.target.classList.add('active');
            
            const category = e.target.getAttribute('data-category');
            if (category === 'all') {
                renderCatalog(allScripts);
            } else {
                renderCatalog(allScripts.filter(s => s.category === category));
            }
        });
    });

    // Сброс папки в настройках
    document.getElementById('reset-folder-btn').addEventListener('click', () => {
        localStorage.removeItem('gameFolderId');
        gameFolderId = null;
        showToast('Папка игры сброшена!', 'success');
    });

    // Отрисовка каталога
    function renderCatalog(scripts) {
        scriptList.innerHTML = ''; 
        if (scripts.length === 0) {
            scriptList.innerHTML = '<p style="text-align: center; color: #888;">Ничего не найдено.</p>';
            return;
        }
        scripts.forEach(script => scriptList.appendChild(createCard(script)));
    }

    // Отрисовка избранного
    function renderFavorites() {
        favoritesList.innerHTML = '';
        const favScripts = allScripts.filter(s => favorites.includes(s.id));
        if (favScripts.length === 0) {
            favoritesList.innerHTML = '<p style="text-align: center; color: #888;">Вы пока ничего не добавили в избранное.</p>';
            return;
        }
        favScripts.forEach(script => favoritesList.appendChild(createCard(script)));
    }

    // Создание карточки
    function createCard(script) {
        const card = document.createElement('div');
        card.className = 'script-card';
        const isFav = favorites.includes(script.id);
        
        card.innerHTML = `
            <div class="card-image" style="background: ${script.color || '#2a2a35'};">
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

        // Логика кнопки избранного
        card.querySelector('.fav-btn').addEventListener('click', (e) => {
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
            renderFavorites(); // Обновляем вкладку избранного
        });

        // Логика кнопки установки
        card.querySelector('.install-btn').addEventListener('click', async (e) => {
            if (!gameFolderId && window.Capacitor) {
                const selected = await selectFolder();
                if (!selected) {
                    showToast('Без выбора папки установка невозможна!', 'error');
                    return;
                }
            }
            const url = e.target.getAttribute('data-url');
            const name = e.target.getAttribute('data-id');
            e.target.innerText = 'Скачивание...';
            e.target.disabled = true;

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
                            e.target.innerText = 'Установить';
                            e.target.disabled = false;
                        }
                    };
                } else {
                    const a = document.createElement('a');
                    a.href = URL.createObjectURL(blob);
                    a.download = `${name}.lua`;
                    a.click();
                    showToast(`Файл ${name}.lua скачан!`, 'success');
                    e.target.innerText = 'Установить';
                    e.target.disabled = false;
                }
            } catch (error) {
                showToast('Ошибка сети.', 'error');
                e.target.innerText = 'Установить';
                e.target.disabled = false;
            }
        });

        return card;
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

    // Поиск
    searchInput.addEventListener('input', (e) => {
        const searchTerm = e.target.value.toLowerCase();
        const filtered = allScripts.filter(script => 
            script.name.toLowerCase().includes(searchTerm) || 
            script.author.toLowerCase().includes(searchTerm)
        );
        renderCatalog(filtered);
    });
});
