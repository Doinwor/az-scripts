// Импорт для работы внутри Android-приложения
import { Filesystem, Directory } from '@capacitor/filesystem';

document.addEventListener('DOMContentLoaded', () => {
    const scriptList = document.getElementById('script-list');
    const searchInput = document.getElementById('search-input');
    let allScripts = [];

    // Загружаем базу данных (scripts.json) из текущей папки
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
                const url = e.target.getAttribute('data-url');
                const name = e.target.getAttribute('data-id');
                
                e.target.innerText = 'Скачивание...';
                e.target.disabled = true;

                try {
                    const response = await fetch(url);
                    const blob = await response.blob();
                    
                    // Проверка: находимся ли мы в приложении или в браузере
                    if (window.Capacitor) {
                        // Если это APK-приложение (используем память телефона)
                        const reader = new FileReader();
                        reader.readAsDataURL(blob);
                        reader.onloadend = async () => {
                            const base64data = reader.result.split(',')[1];
                            await Filesystem.writeFile({
                                path: `${name}.lua`,
                                data: base64data,
                                directory: Directory.Documents
                            });
                            alert(`Файл ${name}.lua скачан в Documents!`);
                            e.target.innerText = 'Установить';
                            e.target.disabled = false;
                        };
                    } else {
                        // Если это обычный браузер (просто скачиваем файл)
                        const a = document.createElement('a');
                        a.href = URL.createObjectURL(blob);
                        a.download = `${name}.lua`;
                        a.click();
                        e.target.innerText = 'Установить';
                        e.target.disabled = false;
                    }
                } catch (error) {
                    console.error('Ошибка:', error);
                    alert('Ошибка скачивания файла.');
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