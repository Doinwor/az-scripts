document.addEventListener('DOMContentLoaded', () => {
    const scriptList = document.getElementById('script-list');
    const searchInput = document.getElementById('search-input');
    let allScripts = [];

    let gameFolderId = localStorage.getItem('gameFolderId');

    fetch('scripts.json')
        .then(response => response.json())
        .then(data => {
            allScripts = data;
            renderScripts(allScripts);
        })
        .catch(error => {
            console.error('Ошибка загрузки базы:', error);
            scriptList.innerHTML = '<p style="color: red; text-align: center;">Ошибка загрузки базы данных.</p>';
        });

    async function selectFolder() {
        try {
            const { ScopedStorage } = window.Capacitor.Plugins;
            const result = await ScopedStorage.pickFolder();
            if (result && result.folder && result.folder.id) {
                localStorage.setItem('gameFolderId', result.folder.id);
                gameFolderId = result.folder.id;
                alert('Папка игры успешно выбрана!');
                return true;
            }
        } catch (e) {
            console.error('Ошибка выбора папки:', e);
            alert('Не удалось выбрать папку.');
        }
        return false;
    }

    function renderScripts(scripts) {
        scriptList.innerHTML = ''; 
        
        if (scripts.length === 0) {
            scriptList.innerHTML = '<p style="text-align: center; color: #888;">Ничего не найдено.</p>';
            return;
        }

        scripts.forEach(script => {
            const card = document.createElement('div');
            card.className = 'script-card';
            
            card.innerHTML = `
                <div class="card-image" style="background: ${script.color || '#2a2a35'};">
                    <span class="badge verified">✅ Проверено</span>
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
            scriptList.appendChild(card);
        });

        document.querySelectorAll('.install-btn').forEach(btn => {
            btn.addEventListener('click', async (e) => {
                if (!gameFolderId && window.Capacitor) {
                    const selected = await selectFolder();
                    if (!selected) {
                        alert('Без выбора папки monetloader установка невозможна!');
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
                    
                    // Указываем, что это скрипт Lua
                    const blob = new Blob([rawBlob], { type: 'application/x-lua' });
                    
                    if (window.Capacitor) {
                        const { ScopedStorage } = window.Capacitor.Plugins;
                        const reader = new FileReader();
                        
                        reader.readAsDataURL(blob);
                        reader.onloadend = async () => {
                            try {
                                const base64data = reader.result.split(',')[1];
                                
                                // Сохраняем с четким указанием mimeType
                                await ScopedStorage.writeFile({
                                    folder: { id: gameFolderId }, 
                                    path: `${name}.lua`,
                                    data: base64data,
                                    encoding: 'base64',
                                    mimeType: 'application/x-lua' // Принудительно указываем формат
                                });
                                alert(`Файл ${name}.lua успешно установлен в игру!`);
                            } catch (err) {
                                console.error('Ошибка записи файла:', err);
                                alert('Ошибка записи. Убедитесь, что выбрана папка monetloader.');
                            } finally {
                                e.target.innerText = 'Установить';
                                e.target.disabled = false;
                            }
                        };
                    } else {
                        // Для браузера на компьютере
                        const a = document.createElement('a');
                        a.href = URL.createObjectURL(blob);
                        a.download = `${name}.lua`;
                        a.click();
                        e.target.innerText = 'Установить';
                        e.target.disabled = false;
                    }
                } catch (error) {
                    console.error('Ошибка сети:', error);
                    alert('Ошибка скачивания. Проверь интернет.');
                    e.target.innerText = 'Установить';
                    e.target.disabled = false;
                }
            });
        });
    }

    searchInput.addEventListener('input', (e) => {
        const searchTerm = e.target.value.toLowerCase();
        const filtered = allScripts.filter(script => 
            script.name.toLowerCase().includes(searchTerm) || 
            script.author.toLowerCase().includes(searchTerm)
        );
        renderScripts(filtered);
    });
});
