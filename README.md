# X-Fleet — выпуски

Здесь лежат только готовые файлы выпусков X-Fleet (панель управления серверами Xray):
программа для Linux (amd64, arm64), установщик `install.sh` и контрольные суммы `SHA256SUMS`.

## Установка панели

Сервер с Ubuntu 22.04+ / Debian 12+, systemd, вход под root:

```bash
wget -qO x-fleet.sh https://raw.githubusercontent.com/richdodcom-pixel/x-fleet-releases/main/install.sh && bash x-fleet.sh
```

В конце установщик покажет адрес панели, логин и пароль (они же — в `/root/nodepanel-admin.txt`).
Свой домен: `bash x-fleet.sh --domain panel.example.com`.
Сначала установщик обновляет систему (`apt update && apt upgrade`); пропустить: `bash x-fleet.sh --no-upgrade`.

Ноды ставятся командой, которую панель показывает при добавлении ноды.
Обновление панели — кнопкой «Обновить» в настройках (берёт последний выпуск отсюда).
