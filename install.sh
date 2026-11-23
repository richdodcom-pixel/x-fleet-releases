#!/usr/bin/env bash
# Установка X-Fleet одной командой (Ubuntu 22.04+/Debian 12+, amd64/arm64, systemd, root).
# X-Fleet one-command installer (Ubuntu 22.04+/Debian 12+, amd64/arm64, systemd, root).
#
#   bash install.sh                 — пошаговый мастер с вопросами (Enter — вариант по умолчанию)
#   bash install.sh --yes           — без вопросов: всё по умолчанию
#
# Параметры (все необязательные) / Options (all optional):
#   --lang ru|en                 язык установщика и меню x-fleet / installer and x-fleet menu language
#   --domain panel.example.com   свой домен панели и подписок (сертификат Let's Encrypt)
#   --https le|ip|self|none      HTTPS панели: свой домен | без домена (<IP>.sslip.io) | самоподписанный |
#                                без HTTPS (панель только через SSH-туннель)
#   --cert файл --key файл       свой сертификат (например, от certbot) вместо Let's Encrypt
#   --email you@example.com      e-mail для писем Let's Encrypt
#   --port 31234                 порт панели (по умолчанию — случайный)
#   --login имя                  логин администратора (по умолчанию — случайный)
#   --connections rec|xhttp|vision|none
#                                подключения на этом сервере: обе Reality (443 + 8443) | только XHTTP |
#                                только TCP+Vision | никаких (сервер только с панелью, ноды — отдельно)
#   --mask neighbor|self|<сайт>  маскировка Reality: сосед по подсети | свой сайт на этом сервере | чужой сайт
#   --sni <сайт>                 то же, что --mask <сайт> (старое имя)
#   --user имя                   первый пользователь (по умолчанию user)
#   --name имя                   имя этого сервера в приложениях клиентов, латиницей (по умолчанию — из домена)
#   --upgrade / --no-upgrade     обновить систему (apt upgrade) или нет; по умолчанию спросить (с --yes — нет)
#   --bbr / --no-bbr             включить BBR (быстрее TCP); по умолчанию — включить
#   --version v0.6.0             поставить эту версию (по умолчанию — последний основной выпуск)
#   --binary ./x-fleet           поставить из файла вместо скачивания;  --url … --sha256 …  — из адреса
#
# В конце печатаются адрес панели, логин и пароль (они же — в /root/x-fleet-admin.txt) и QR-код подписки.
# Управление потом — командой x-fleet (меню).
set -euo pipefail

DOMAIN=""; HTTPS_MODE=""; CERT=""; KEY=""; EMAIL=""; PORT=""; LOGIN=""; CONN=""; MASK=""; FIRST_USER=""; NODE_NAME=""
UPGRADE=""; BBR=""; BINARY=""; URL=""; SHA=""; ASSUME_YES=""; LNG=""
# Репозиторий выпусков подставляется при сборке выпуска (.github/workflows/release.yml).
REPO="${XFLEET_REPO:-richdodcom-pixel/x-fleet-releases}"
# Метку заменяет только присваивание выше; проверяем по её части, чтобы sed при сборке не задел и эту строку.
case "$REPO" in *_XFLEET_REPO_*) REPO="" ;; esac
# Какую версию ставить: пусто — последний основной выпуск. В предварительных выпусках здесь их метка.
PIN="${XFLEET_VERSION:-__XFLEET_VERSION__}"
case "$PIN" in *_XFLEET_VERSION_*) PIN="" ;; esac
AGENT_PORT=8444; SUB_PORT=2096
while [ $# -gt 0 ]; do
  case "$1" in
    --lang)   LNG="$2"; shift 2 ;;
    --domain) DOMAIN="$2"; shift 2 ;;
    --https)  HTTPS_MODE="$2"; shift 2 ;;
    --cert)   CERT="$2"; shift 2 ;;
    --key)    KEY="$2"; shift 2 ;;
    --email)  EMAIL="$2"; shift 2 ;;
    --port)   PORT="$2"; shift 2 ;;
    --login)  LOGIN="$2"; shift 2 ;;
    --connections) CONN="$2"; shift 2 ;;
    --mask)   MASK="$2"; shift 2 ;;
    --sni)    MASK="$2"; shift 2 ;;
    --user)   FIRST_USER="$2"; shift 2 ;;
    --name)   NODE_NAME="$2"; shift 2 ;;
    --upgrade) UPGRADE=1; shift ;;
    --no-upgrade) UPGRADE=0; shift ;;
    --bbr)    BBR=1; shift ;;
    --no-bbr) BBR=0; shift ;;
    --version) PIN="$2"; shift 2 ;;
    --binary) BINARY="$2"; shift 2 ;;
    --url)    URL="$2"; shift 2 ;;
    --sha256) SHA="$2"; shift 2 ;;
    -y|--yes) ASSUME_YES=1; shift ;;
    -h|--help) sed -n '2,/^set -euo/p' "$0" | sed '$d' | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "неизвестный параметр / unknown option: $1 (--help)" >&2; exit 2 ;;
  esac
done
case "$LNG" in ""|ru|en) ;; *) echo "--lang: ru или en / ru or en" >&2; exit 2 ;; esac

# L "по-русски" "in English" — фраза на выбранном языке.
L() { if [ "$LNG" = en ]; then printf '%s' "$2"; else printf '%s' "$1"; fi; }

# ---------- оформление
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  B=$'\033[1;38;2;64;150;255m'; G=$'\033[32m'; Y=$'\033[33m'; R=$'\033[31m'; D=$'\033[2m'; W=$'\033[1m'; N=$'\033[0m'
else
  B=""; G=""; Y=""; R=""; D=""; W=""; N=""
fi
STEP=0; STEPS=9
step() { STEP=$((STEP + 1)); printf '\n%s[%d/%d]%s %s%s%s\n' "$B" "$STEP" "$STEPS" "$N" "$W" "$*" "$N"; }
ok()   { printf '      %s✓%s %s\n' "$G" "$N" "$*"; }
info() { printf '      %s%s%s\n' "$D" "$*" "$N"; }
warn() { printf '      %s⚠ %s%s\n' "$Y" "$*" "$N"; }
die()  { printf '\n%s✗ %s%s\n' "$R" "$*" "$N" >&2; exit 1; }
busy() { ss -tlnH "( sport = :$1 )" 2>/dev/null | grep -q .; }
logo() {
  local c=("38;2;22;119;255" "38;2;48;135;255" "38;2;74;151;255" "38;2;100;167;255" "38;2;126;183;255" "38;2;156;200;255") i=0
  while IFS= read -r l; do
    if [ -n "$B" ]; then printf '  \033[1;%sm%s\033[0m\n' "${c[$i]}" "$l"; else printf '  %s\n' "$l"; fi
    i=$((i + 1))
  done <<'LOGO'
██╗  ██╗      ███████╗██╗     ███████╗███████╗████████╗
╚██╗██╔╝      ██╔════╝██║     ██╔════╝██╔════╝╚══██╔══╝
 ╚███╔╝ █████╗█████╗  ██║     █████╗  █████╗     ██║
 ██╔██╗ ╚════╝██╔══╝  ██║     ██╔══╝  ██╔══╝     ██║
██╔╝ ██╗      ██║     ███████╗███████╗███████╗   ██║
╚═╝  ╚═╝      ╚═╝     ╚══════╝╚══════╝╚══════╝   ╚═╝
LOGO
}

# Вопросы — через /dev/tty: при `curl … | bash` stdin занят самим скриптом.
# Без терминала (или с --yes) вопросов нет: берётся вариант по умолчанию.
TTY=""
if [ -z "$ASSUME_YES" ] && { : < /dev/tty; } 2>/dev/null; then TTY=1; fi
ask() { # ask "вопрос" "по умолчанию" → REPLY
  REPLY=""
  if [ -n "$TTY" ]; then
    printf '      %s' "$1" > /dev/tty
    IFS= read -r REPLY < /dev/tty || REPLY=""
  fi
  REPLY="$(printf '%s' "$REPLY" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
  [ -n "$REPLY" ] || REPLY="$2"
}
yesno() { # yesno "вопрос" y|n → 0 = да
  local def="$2" hint
  if [ "$def" = y ]; then hint="$(L '[Д/н]' '[Y/n]')"; else hint="$(L '[д/Н]' '[y/N]')"; fi
  ask "$1 $hint: " "$def"
  case "$REPLY" in y|Y|д|Д|да|Да|yes|Yes) return 0 ;; *) return 1 ;; esac
}
clean_domain() { printf '%s' "$1" | tr 'A-Z' 'a-z' | tr -d ' ' | sed 's#^https\?://##; s#/.*##'; }
valid_domain() { printf '%s' "$1" | grep -Eq '^([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,63}$'; }
resolved() { getent ahostsv4 "$1" 2>/dev/null | awk 'NR==1{print $1}' || true; }
who_listens() { ss -tlnpH "( sport = :$1 )" 2>/dev/null | grep -o 'users:(("[^"]*' | sed 's/users:(("//' | head -1; }

logo
echo
if [ -z "$LNG" ]; then
  if [ -n "$TTY" ]; then
    printf '      %sЯзык / Language%s\n        1) Русский\n        2) English\n' "$W" "$N" > /dev/tty
  fi
  ask "Выбор / Choice [1-2] (Enter — 1): " 1
  case "$REPLY" in 2|en|EN|e|E) LNG=en ;; *) LNG=ru ;; esac
fi
export XFLEET_LANG="$LNG" # язык для шагов x-fleet setup …
printf '  %s%s%s\n' "$D" "$(L 'панель управления VPN-серверами' 'VPN server management panel')" "$N"

# ========== 1. Система
step "$(L 'Проверка системы' 'System check')"
[ "$(id -u)" = 0 ] || die "$(L 'запустите под root (или через sudo)' 'run as root (or via sudo)')"
command -v systemctl >/dev/null && [ -d /run/systemd/system ] || die "$(L 'нужен systemd' 'systemd is required')"
case "$(uname -m)" in
  x86_64|amd64) ARCH=amd64 ;;
  aarch64|arm64) ARCH=arm64 ;;
  *) die "$(L "архитектура $(uname -m) не поддерживается (нужна x86_64 или arm64)" "architecture $(uname -m) is not supported (x86_64 or arm64 required)")" ;;
esac
OS="$(. /etc/os-release 2>/dev/null && echo "${PRETTY_NAME:-Linux}")"
MEM_MB="$(awk '/MemTotal/ {print int($2/1024)}' /proc/meminfo 2>/dev/null || echo 0)"
info "$(L "ОС: $OS · архитектура: $(uname -m) · память: ${MEM_MB} МБ · systemd: есть" "OS: $OS · architecture: $(uname -m) · memory: ${MEM_MB} MB · systemd: yes")"
[ "$MEM_MB" -ge 450 ] || warn "$(L 'памяти меньше 512 МБ — панель и VPN могут работать нестабильно' 'less than 512 MB of memory — the panel and VPN may be unstable')"
[ ! -f /etc/nodepanel/panel.yaml ] || die "$(L 'здесь стоит старая версия панели (nodepanel). Обновите её кнопкой «Обновить» в настройках панели или командой: x-fleet migrate' 'an old panel version (nodepanel) is installed here. Update it with the «Update» button in the panel settings or with: x-fleet migrate')"
if [ -f /etc/x-fleet/panel.yaml ]; then
  die "$(L 'X-Fleet уже установлен. Управление — командой x-fleet (меню). Переустановить: x-fleet uninstall, затем эта команда снова' 'X-Fleet is already installed. Manage it with the x-fleet command (menu). To reinstall: x-fleet uninstall, then run this command again')"
fi
ok "$(L 'система подходит' 'the system fits')"

# ========== 2. Пакеты
step "$(L 'Системные пакеты' 'System packages')"
NEED=()
for p in curl:curl ca-certificates:/etc/ssl/certs/ca-certificates.crt iproute2:ss; do
  pkg="${p%%:*}"; chk="${p#*:}"
  if [ -e "$chk" ] || command -v "$chk" >/dev/null 2>&1; then info "$(L 'уже есть' 'already present'): $pkg"; else NEED+=("$pkg"); fi
done
export DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=a
APT=(apt-get -y -q -o DPkg::Lock::Timeout=600 -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold)
APT_LOG=/var/log/x-fleet-install-apt.log
if [ -z "$UPGRADE" ]; then
  if [ -n "$TTY" ] && yesno "$(L 'Обновить систему (apt upgrade)? Дольше, но безопаснее' 'Upgrade the system (apt upgrade)? Slower, but safer')" n; then UPGRADE=1; else UPGRADE=0; fi
fi
if [ "${#NEED[@]}" -gt 0 ] || [ "$UPGRADE" = 1 ]; then
  command -v apt-get >/dev/null || die "$(L "нет apt-get — поставьте вручную: ${NEED[*]}" "no apt-get — install manually: ${NEED[*]}")"
  info "$(L "apt update (если apt занят автообновлениями — жду до 10 минут; журнал: $APT_LOG)" "apt update (if apt is busy with auto-updates — waiting up to 10 minutes; log: $APT_LOG)")"
  "${APT[@]}" update >"$APT_LOG" 2>&1 || die "$(L "apt update не удался — подробности: $APT_LOG" "apt update failed — details: $APT_LOG")"
  if [ "${#NEED[@]}" -gt 0 ]; then
    "${APT[@]}" install "${NEED[@]}" >>"$APT_LOG" 2>&1 || die "$(L "не удалось поставить ${NEED[*]} — подробности: $APT_LOG" "could not install ${NEED[*]} — details: $APT_LOG")"
    ok "$(L 'поставлено' 'installed'): ${NEED[*]}"
  fi
  if [ "$UPGRADE" = 1 ]; then
    info "$(L 'apt upgrade — несколько минут…' 'apt upgrade — a few minutes…')"
    "${APT[@]}" upgrade >>"$APT_LOG" 2>&1 || die "$(L "apt upgrade не удался — подробности: $APT_LOG (можно повторить с --no-upgrade)" "apt upgrade failed — details: $APT_LOG (you can retry with --no-upgrade)")"
    ok "$(L 'система обновлена' 'system upgraded')"
  fi
fi
ok "$(L 'все нужные пакеты на месте' 'all required packages are in place')"
CUR_CC="$(cat /proc/sys/net/ipv4/tcp_congestion_control 2>/dev/null || echo ?)"
if [ "$CUR_CC" = bbr ]; then
  info "$(L 'BBR уже включён' 'BBR is already on')"
elif [ "${BBR:-1}" = 1 ]; then
  printf 'net.core.default_qdisc=fq\nnet.ipv4.tcp_congestion_control=bbr\n' > /etc/sysctl.d/99-x-fleet-bbr.conf
  sysctl --system >/dev/null 2>&1 || true
  if [ "$(cat /proc/sys/net/ipv4/tcp_congestion_control 2>/dev/null)" = bbr ]; then
    ok "$(L 'BBR включён (быстрее TCP; выключить: x-fleet bbr off)' 'BBR is on (faster TCP; turn off: x-fleet bbr off)')"
  else
    warn "$(L 'ядро не поддерживает BBR — работаем без него' 'the kernel does not support BBR — continuing without it')"
  fi
fi

# ========== 3. Скачивание
step "$(L 'Скачивание X-Fleet' 'Downloading X-Fleet')"
TMP="$(mktemp)"; trap 'rm -f "$TMP"' EXIT
if [ -n "$BINARY" ]; then
  cp "$BINARY" "$TMP"; info "$(L 'из файла' 'from file') $BINARY"
elif [ -n "$URL" ]; then
  info "$(L 'скачиваю' 'downloading') $URL"
  curl -fsSL -o "$TMP" "$URL" || die "$(L 'не удалось скачать' 'could not download') $URL"
elif [ -n "$REPO" ]; then
  if [ -n "$PIN" ]; then
    REL="https://github.com/$REPO/releases/download/$PIN"; info "$(L "скачиваю x-fleet-linux-$ARCH, версия $PIN" "downloading x-fleet-linux-$ARCH, version $PIN")"
  else
    REL="https://github.com/$REPO/releases/latest/download"; info "$(L "скачиваю x-fleet-linux-$ARCH из последнего выпуска" "downloading x-fleet-linux-$ARCH from the latest release")"
  fi
  curl -fsSL -o "$TMP" "$REL/x-fleet-linux-$ARCH" || die "$(L 'не удалось скачать' 'could not download') $REL/x-fleet-linux-$ARCH"
  SHA="$(curl -fsSL "$REL/SHA256SUMS" | awk -v f="x-fleet-linux-$ARCH" '$2==f || $2=="*"f {print $1}')"
  [ -n "$SHA" ] || die "$(L "в выпуске нет SHA256SUMS для $ARCH" "the release has no SHA256SUMS for $ARCH")"
else
  die "$(L 'укажите --binary <файл> или --url <адрес>' 'specify --binary <file> or --url <address>')"
fi
if [ -n "$SHA" ]; then
  [ "$(sha256sum "$TMP" | cut -d' ' -f1)" = "$SHA" ] || die "$(L 'контрольная сумма не совпала — файл повреждён или подменён' 'checksum mismatch — the file is damaged or tampered with')"
  ok "$(L 'SHA-256 совпадает' 'SHA-256 matches')"
fi
chmod 755 "$TMP"; VER="$("$TMP" version 2>/dev/null)" || die "$(L 'файл не запускается — не та архитектура?' 'the file does not run — wrong architecture?')"
ok "$VER"

# ========== 4. Установка
step "$(L 'Установка X-Fleet' 'Installing X-Fleet')"
install -m 0755 "$TMP" /usr/local/bin/x-fleet
mkdir -p /etc/x-fleet
echo "$LNG" > /etc/x-fleet/lang
info "$(L 'x-fleet — панель, нода и меню управления в одном файле: /usr/local/bin/x-fleet' 'x-fleet — panel, node and management menu in one file: /usr/local/bin/x-fleet')"
ok "$(L 'файлы на месте (меню: x-fleet)' 'files are in place (menu: x-fleet)')"

# ========== 5. Адрес и HTTPS
step "$(L 'Адрес сервера и HTTPS' 'Server address and HTTPS')"
IP="$(ip -4 route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="src") {print $(i+1); exit}}')"
case "$IP" in
  ""|10.*|172.1[6-9].*|172.2[0-9].*|172.3[01].*|192.168.*|100.6[4-9].*|100.[7-9][0-9].*|100.1[01][0-9].*|100.12[0-7].*)
    IP="$(curl -4 -fsS --max-time 10 https://api.ipify.org || true)" ;;
esac
ask "$(L "Адрес в ссылках: ${IP:-не определён}. Верно? Enter — да, или введите другой IPv4: " "Address in links: ${IP:-unknown}. Correct? Enter — yes, or type another IPv4: ")" "$IP"
IP="$REPLY"
printf '%s' "$IP" | grep -Eq '^([0-9]{1,3}\.){3}[0-9]{1,3}$' || die "$(L "«$IP» — не IPv4-адрес" "«$IP» is not an IPv4 address")"
SSLIP="${IP//./-}.sslip.io"

[ -n "$CERT" ] && HTTPS_MODE=cert
[ -n "$DOMAIN" ] && [ -z "$HTTPS_MODE" ] && HTTPS_MODE=le
if [ -z "$HTTPS_MODE" ]; then
  # Сначала прямо спрашиваем домен: с номерным списком легко проскочить Enter'ом и получить адрес по IP.
  if [ -n "$TTY" ]; then
    if [ "$LNG" = en ]; then
      cat > /dev/tty <<TXT

      ${W}Panel and subscription domain${N} ${D}(an A record pointing to $IP; in Cloudflare — grey cloud)${N}
        • type your domain — a Let's Encrypt certificate for it
        • Enter — no domain: the address will be ${W}$SSLIP${N} (also a real certificate)
        • ? — other options: self-signed, your own certificate, no HTTPS
TXT
    else
      cat > /dev/tty <<TXT

      ${W}Домен панели и подписок${N} ${D}(A-запись на $IP; в Cloudflare — серое облако)${N}
        • введите свой домен — для него будет сертификат Let's Encrypt
        • Enter — без домена: адрес будет ${W}$SSLIP${N} (тоже с настоящим сертификатом)
        • ? — другие варианты: самоподписанный, свой сертификат, без HTTPS
TXT
    fi
  fi
  ask "$(L 'Домен (Enter — без домена, ? — другие варианты): ' 'Domain (Enter — no domain, ? — other options): ')" ""
  case "$REPLY" in
    "") HTTPS_MODE=ip ;;
    "?")
      if [ "$LNG" = en ]; then
        cat > /dev/tty <<TXT
        1) Let's Encrypt for your domain  — needs an A record pointing to $IP and open port 80
        2) Let's Encrypt without a domain — name $SSLIP, no browser warning
        3) Self-signed                    — the browser warns once; ${Y}VPN clients may reject the subscription${N}
        4) Your own certificate           — paths to files (for example, from certbot)
        5) No HTTPS                       — panel only via SSH tunnel (x-fleet private on)
TXT
      else
        cat > /dev/tty <<TXT
        1) Let's Encrypt для своего домена — нужна A-запись домена на $IP и открытый порт 80
        2) Let's Encrypt без домена        — имя $SSLIP, браузер не ругается
        3) Самоподписанный                 — браузер предупредит один раз; ${Y}клиенты VPN могут не принять подписку${N}
        4) Свой сертификат                 — пути к файлам (например, от certbot)
        5) Без HTTPS                       — панель только через SSH-туннель (x-fleet private on)
TXT
      fi
      ask "$(L 'Выбор [1-5] (Enter — 2): ' 'Choice [1-5] (Enter — 2): ')" 2
      case "$REPLY" in 1) HTTPS_MODE=le ;; 3) HTTPS_MODE=self ;; 4) HTTPS_MODE=cert ;; 5) HTTPS_MODE=none ;; *) HTTPS_MODE=ip ;; esac ;;
    *) DOMAIN="$(clean_domain "$REPLY")"; HTTPS_MODE=le ;;
  esac
fi
case "$HTTPS_MODE" in
  le)
    while :; do
      if [ -z "$DOMAIN" ]; then
        ask "$(L "Домен (например, vpn.example.com; Enter — назад к имени $SSLIP): " "Domain (for example, vpn.example.com; Enter — back to the name $SSLIP): ")" ""
        [ -n "$REPLY" ] || { HTTPS_MODE=ip; warn "$(L "домен не указан — адрес панели будет $SSLIP" "no domain given — the panel address will be $SSLIP")"; break; }
        DOMAIN="$(clean_domain "$REPLY")"
      fi
      valid_domain "$DOMAIN" || { warn "$(L "«$DOMAIN» не похоже на домен" "«$DOMAIN» does not look like a domain")"; DOMAIN=""; [ -n "$TTY" ] || die "$(L 'неверный --domain' 'invalid --domain')"; continue; }
      GOT="$(resolved "$DOMAIN")"
      if [ "$GOT" = "$IP" ]; then
        busy 80 && die "$(L "порт 80 занят ($(who_listens 80)) — он нужен для проверки Let's Encrypt" "port 80 is busy ($(who_listens 80)) — it is needed for the Let's Encrypt check")"
        ok "$(L "домен $DOMAIN указывает на этот сервер, порт 80 свободен" "domain $DOMAIN points to this server, port 80 is free")"
        if [ -z "$EMAIL" ] && [ -n "$TTY" ]; then ask "$(L "E-mail для писем Let's Encrypt о сертификате (Enter — без него): " "E-mail for Let's Encrypt certificate notices (Enter — none): ")" ""; EMAIL="$REPLY"; fi
        break
      fi
      warn "$(L "$DOMAIN указывает на '${GOT:-ничего}', а IP сервера $IP (в Cloudflare — серое облако, DNS обновляется до нескольких минут)" "$DOMAIN points to '${GOT:-nothing}', but the server IP is $IP (in Cloudflare — grey cloud; DNS updates take up to a few minutes)")"
      [ -n "$TTY" ] || die "$(L "поправьте A-запись домена $DOMAIN" "fix the A record of $DOMAIN")"
      ask "$(L "Enter — проверить снова, s — взять $SSLIP, или введите другой домен: " "Enter — check again, s — use $SSLIP, or type another domain: ")" ""
      case "$REPLY" in "") sleep 5 ;; s|S) DOMAIN=""; HTTPS_MODE=ip; break ;; *) DOMAIN="$(clean_domain "$REPLY")" ;; esac
    done ;;
esac
case "$HTTPS_MODE" in
  ip)
    DOMAIN="$SSLIP"
    [ "$(resolved "$DOMAIN")" = "$IP" ] || die "$(L "имя $DOMAIN не находится в DNS — нет доступа к sslip.io? Выберите самоподписанный (--https self)" "name $DOMAIN does not resolve — no access to sslip.io? Choose self-signed (--https self)")"
    busy 80 && die "$(L "порт 80 занят — он нужен для проверки Let's Encrypt (или --https self)" "port 80 is busy — it is needed for the Let's Encrypt check (or --https self)")"
    ok "$(L "имя $DOMAIN указывает на этот сервер" "name $DOMAIN points to this server")" ;;
  cert)
    if [ -z "$CERT" ]; then
      ask "$(L 'Файл сертификата (fullchain.pem): ' 'Certificate file (fullchain.pem): ')" ""; CERT="$REPLY"
      ask "$(L 'Файл ключа (privkey.pem): ' 'Key file (privkey.pem): ')" ""; KEY="$REPLY"
    fi
    [ -r "$CERT" ] && [ -r "$KEY" ] || die "$(L 'не читаются файлы сертификата/ключа' 'cannot read the certificate/key files'): $CERT, $KEY"
    if [ -z "$DOMAIN" ]; then ask "$(L 'Имя из сертификата, по которому открывать панель: ' 'Name from the certificate to open the panel with: ')" ""; DOMAIN="$(clean_domain "$REPLY")"; fi
    valid_domain "$DOMAIN" || die "$(L 'нужно имя из сертификата (--domain)' 'a name from the certificate is required (--domain)')"
    ok "$(L 'свой сертификат' 'own certificate'): $CERT" ;;
  self) ok "$(L "самоподписанный сертификат на $IP" "self-signed certificate for $IP")" ;;
  none) ok "$(L 'без HTTPS: панель будет доступна только через SSH-туннель' 'no HTTPS: the panel will be reachable only via an SSH tunnel')" ;;
  le) ;;
  *) die "$(L '--https: le, ip, self или none' '--https: le, ip, self or none')" ;;
esac

# ========== 6. Настройки панели
step "$(L 'Настройки панели' 'Panel settings')"
[ -n "$PORT" ] || { PORT=$(( 20000 + RANDOM % 40000 )); while busy "$PORT"; do PORT=$(( 20000 + RANDOM % 40000 )); done; }
for p in "$PORT" "$AGENT_PORT" "$SUB_PORT"; do
  busy "$p" && die "$(L "порт $p занят — освободите его (или --port для панели)" "port $p is busy — free it (or use --port for the panel)")"
done
BASE="/$(head -c 24 /dev/urandom | base64 | tr -dc 'a-zA-Z0-9' | head -c 12)"
mkdir -p /etc/x-fleet /var/lib/x-fleet
chmod 700 /var/lib/x-fleet
LISTEN_HOST=0.0.0.0; [ "$HTTPS_MODE" = none ] && LISTEN_HOST=127.0.0.1
(
  umask 077
  {
    echo "data_dir: /var/lib/x-fleet"
    echo "listen: $LISTEN_HOST:$PORT"
    echo "base_path: $BASE"
    echo "agent_listen: :$AGENT_PORT"
    echo "sub_listen: :$SUB_PORT"
    case "$HTTPS_MODE" in
      le|ip) echo "tls_domain: $DOMAIN"; echo "acme_email: \"$EMAIL\"" ;;
      self)  echo "tls_self_signed: true"; echo "agent_public_addr: $IP:$AGENT_PORT"; echo "sub_public_url: https://$IP:$SUB_PORT" ;;
      cert)  echo "tls_cert_file: \"$CERT\""; echo "tls_key_file: \"$KEY\""; echo "agent_public_addr: $DOMAIN:$AGENT_PORT"; echo "sub_public_url: https://$DOMAIN:$SUB_PORT" ;;
      none)  echo "agent_public_addr: $IP:$AGENT_PORT"; echo "sub_public_url: http://$IP:$SUB_PORT" ;;
    esac
    [ -n "$REPO" ] && echo "update_repo: $REPO"
  } > /etc/x-fleet/panel.yaml
)
ok "$(L "порт панели: $PORT (случайный; сменить потом: x-fleet port НОМЕР)" "panel port: $PORT (random; change later: x-fleet port NUMBER)")"
ok "$(L "секретный путь: $BASE/ (любой другой адрес отвечает 404)" "secret path: $BASE/ (any other address answers 404)")"
CRED="$(/usr/local/bin/x-fleet setup admin ${LOGIN:+-login "$LOGIN"})" || die "$(L 'не удалось создать администратора' 'could not create the administrator')"
LOGIN="${CRED%%$'\t'*}"; PASS="${CRED#*$'\t'}"
ok "$(L 'база создана, логин и пароль администратора — случайные' 'database created, a random administrator login and password were generated')"

# ========== 7. Подключения
step "$(L 'VPN на этом сервере' 'VPN on this server')"
if [ -z "$CONN" ]; then
  if [ -n "$TTY" ]; then
    if [ "$LNG" = en ]; then
      cat > /dev/tty <<TXT
      ${W}Which connections to create?${N} ${D}Every extra port makes the server more noticeable — add others only when needed.${N}
        1) Recommended        — VLESS Reality: XHTTP on 443 (main) and TCP+Vision on 8443 (backup)  ${D}[default]${N}
        2) XHTTP only         — a single port 443
        3) TCP+Vision only    — a single port 443, the fastest
        4) None               — this server only runs the panel, VPN servers (nodes) are added later
TXT
    else
      cat > /dev/tty <<TXT
      ${W}Какие подключения создать?${N} ${D}Каждый лишний порт делает сервер заметнее — добавляйте другие, только когда нужно.${N}
        1) Рекомендуемые      — VLESS Reality: XHTTP на 443 (основное) и TCP+Vision на 8443 (запасное)  ${D}[по умолчанию]${N}
        2) Только XHTTP       — один порт 443
        3) Только TCP+Vision  — один порт 443, самое быстрое
        4) Никаких            — этот сервер только с панелью, VPN-серверы (ноды) добавлю потом
TXT
    fi
  fi
  ask "$(L 'Выбор [1-4] (Enter — 1): ' 'Choice [1-4] (Enter — 1): ')" 1
  case "$REPLY" in 2) CONN=xhttp ;; 3) CONN=vision ;; 4) CONN=none ;; *) CONN=rec ;; esac
fi
case "$CONN" in rec|xhttp|vision|none) ;; *) die "$(L '--connections: rec, xhttp, vision или none' '--connections: rec, xhttp, vision or none')" ;; esac
TPL=(); case "$CONN" in rec) TPL=(-xhttp -vision) ;; xhttp) TPL=(-xhttp) ;; vision) TPL=(-vision) ;; esac
VPN_PORTS=(); case "$CONN" in rec) VPN_PORTS=(443 8443) ;; xhttp|vision) VPN_PORTS=(443) ;; esac
for p in "${VPN_PORTS[@]}"; do
  if busy "$p"; then
    WHO="$(who_listens "$p")"
    die "$(L "порт $p занят (${WHO:-неизвестная программа}) — похоже, здесь уже есть VPN. Выберите «Никаких» (--connections none) или освободите порт" "port $p is busy (${WHO:-unknown program}) — a VPN seems to run here already. Choose «None» (--connections none) or free the port")"
  fi
done

NODE_DOMAIN=""
if [ "$CONN" != none ]; then
  OWN_DOMAIN=""; case "$HTTPS_MODE" in le|cert) OWN_DOMAIN="$DOMAIN" ;; esac
  if [ -z "$MASK" ]; then
    DEF=1; [ -n "$OWN_DOMAIN" ] && DEF=3
    if [ -n "$TTY" ]; then
      if [ "$LNG" = en ]; then
        cat > /dev/tty <<TXT

      ${W}Which site should REALITY mimic?${N} ${D}From outside the server looks like an ordinary website.${N}
        1) Subnet neighbour    — I will find a real site next to the server, no domain needed
        2) Someone else's site — you type the address (checked: TLS 1.3 and HTTP/2)
        3) Your own domain     — a site with a Let's Encrypt certificate runs on this server${OWN_DOMAIN:+ (${OWN_DOMAIN})}
TXT
      else
        cat > /dev/tty <<TXT

      ${W}Под какой сайт маскировать Reality?${N} ${D}Снаружи сервер выглядит как обычный сайт.${N}
        1) Сосед по подсети — подберу сам настоящий сайт рядом с сервером, домен не нужен
        2) Чужой сайт       — вы вводите адрес (проверю: TLS 1.3 и HTTP/2)
        3) Свой домен       — на сервере поднимется свой сайт с сертификатом Let's Encrypt${OWN_DOMAIN:+ (${OWN_DOMAIN})}
TXT
      fi
    fi
    ask "$(L "Выбор [1-3] (Enter — $DEF): " "Choice [1-3] (Enter — $DEF): ")" "$DEF"
    case "$REPLY" in 2) MASK=ask ;; 3) MASK=self ;; *) MASK=neighbor ;; esac
  fi
  SNI=""
  case "$MASK" in
    neighbor)
      info "$(L "ищу сайты-соседи в подсети $IP/24 (TLS 1.3 + HTTP/2), до минуты…" "looking for neighbour sites in $IP/24 (TLS 1.3 + HTTP/2), up to a minute…")"
      FOUND="$(/usr/local/bin/x-fleet setup sni-scan "$IP" ${OWN_DOMAIN:+"$OWN_DOMAIN"} 2>/dev/null || true)"
      if [ -n "$FOUND" ]; then
        MS="$(L 'мс' 'ms')"
        printf '%s\n' "$FOUND" | head -5 | awk -F'\t' -v ms="$MS" '{printf "        %d) %-40s %s %s\n", NR, $1, $3, ms}'
        N_FOUND="$(printf '%s\n' "$FOUND" | head -5 | wc -l | tr -d ' ')"
        ask "$(L "Какой взять [1-$N_FOUND] (Enter — 1, самый быстрый): " "Which one [1-$N_FOUND] (Enter — 1, the fastest): ")" 1
        case "$REPLY" in [1-5]) SNI="$(printf '%s\n' "$FOUND" | sed -n "${REPLY}p" | cut -f1)" ;; esac
        [ -n "$SNI" ] || SNI="$(printf '%s\n' "$FOUND" | head -1 | cut -f1)"
      else
        warn "$(L 'подходящих соседей не нашлось' 'no suitable neighbours found')"
        MASK=ask; [ -n "$TTY" ] || MASK=self
      fi ;;
  esac
  case "$MASK" in
    neighbor|self) ;;
    *)
      while [ -z "$SNI" ]; do
        if [ "$MASK" = ask ]; then
          ask "$(L 'Сайт для маскировки (например, www.example.com; Enter — свой сайт): ' 'Site to mimic (for example, www.example.com; Enter — own site): ')" ""
          [ -n "$REPLY" ] || { MASK=self; break; }
          CAND="$(clean_domain "$REPLY")"
        else
          CAND="$(clean_domain "$MASK")"
        fi
        if ERR="$(/usr/local/bin/x-fleet setup sni-check "$CAND" 2>&1)"; then SNI="$CAND"; else warn "$ERR"; [ -n "$TTY" ] || die "$(L "сайт $CAND не подходит для маскировки" "site $CAND is not suitable for masking")"; MASK=ask; fi
      done ;;
  esac
  if [ -n "$SNI" ]; then
    ok "$(L 'маскировка под' 'masking as') $SNI"
  else
    MASK=self
    if [ -n "$OWN_DOMAIN" ]; then
      NODE_DOMAIN="$OWN_DOMAIN"
    else
      ask "$(L "Домен для своего сайта (A-запись на $IP; Enter — без домена, имя $SSLIP): " "Domain for your own site (A record to $IP; Enter — no domain, name $SSLIP): ")" ""
      NODE_DOMAIN="$(clean_domain "$REPLY")"
      [ -z "$NODE_DOMAIN" ] || valid_domain "$NODE_DOMAIN" || die "$(L "«$NODE_DOMAIN» не похоже на домен" "«$NODE_DOMAIN» does not look like a domain")"
      [ -z "$NODE_DOMAIN" ] || [ "$(resolved "$NODE_DOMAIN")" = "$IP" ] || die "$(L "$NODE_DOMAIN не указывает на $IP — поправьте A-запись" "$NODE_DOMAIN does not point to $IP — fix the A record")"
    fi
    ok "$(L "маскировка под свой сайт ${NODE_DOMAIN:-$SSLIP} (сертификат Let's Encrypt нода получит сама через порт 443)" "masking as your own site ${NODE_DOMAIN:-$SSLIP} (the node gets its Let's Encrypt certificate itself via port 443)")"
  fi
  if [ -z "$NODE_NAME" ]; then
    DEF_NAME="$(hostname -s 2>/dev/null | tr -cd 'a-zA-Z0-9-' | head -c 30 || true)"
    # имя хостера вида vm2273183 / vps-12345 / ip-10-0-0-1 клиентам ничего не говорит
    if [ -z "$DEF_NAME" ] || printf '%s' "$DEF_NAME" | grep -Eqi '^(vm|vds|vps|srv|server|host|node|ubuntu|debian|localhost|ip-)|[0-9]{4,}'; then
      case "$HTTPS_MODE" in le|cert) DEF_NAME="${DOMAIN%%.*}" ;; *) DEF_NAME="server1" ;; esac
    fi
    ask "$(L "Имя этого сервера в приложениях, латиницей (например germany; Enter — $DEF_NAME): " "Name of this server in client apps, Latin letters (for example germany; Enter — $DEF_NAME): ")" "$DEF_NAME"
    NODE_NAME="$(printf '%s' "$REPLY" | tr -cd 'a-zA-Z0-9._-' | head -c 40)"; [ -n "$NODE_NAME" ] || NODE_NAME="$DEF_NAME"
  fi
  [ -n "$FIRST_USER" ] || { ask "$(L 'Имя первого пользователя (Enter — user): ' 'First user name (Enter — user): ')" user; FIRST_USER="$REPLY"; }
  /usr/local/bin/x-fleet setup templates "${TPL[@]}" ${SNI:+-sni "$SNI"} >/dev/null || die "$(L 'не удалось создать шаблоны подключений' 'could not create connection templates')"
  PORT_W="$(L 'порт' 'port')"
  case "$CONN" in
    rec)    ok "VLESS + XHTTP + REALITY — $PORT_W 443"; ok "VLESS + TCP + REALITY + Vision — $PORT_W 8443" ;;
    xhttp)  ok "VLESS + XHTTP + REALITY — $PORT_W 443" ;;
    vision) ok "VLESS + TCP + REALITY + Vision — $PORT_W 443" ;;
  esac
else
  /usr/local/bin/x-fleet setup templates -xhttp -vision >/dev/null || true
  ok "$(L 'VPN здесь не ставлю: ноды добавляются потом — в панели «Ноды» или командой x-fleet node-cmd' 'no VPN here: nodes are added later — in the panel «Nodes» or with x-fleet node-cmd')"
fi

# ========== 8. Службы
step "$(L 'Запуск служб: стартуют сами и возвращаются после перезагрузки' 'Starting services: they start by themselves and come back after a reboot')"
unit() { # unit имя описание команда
  cat > "/etc/systemd/system/$1.service" <<UNIT
[Unit]
Description=$2
After=network-online.target
Wants=network-online.target

[Service]
ExecStart=$3
Restart=always
RestartSec=3
LimitNOFILE=1048576
# Ограничения: служба не получает новых прав, не видит /home и /root, не меняет ядро.
NoNewPrivileges=true
PrivateTmp=true
ProtectHome=true
ProtectKernelTunables=true
ProtectKernelModules=true
ProtectKernelLogs=true
ProtectControlGroups=true
ProtectClock=true
RestrictSUIDSGID=true
RestrictNamespaces=true
LockPersonality=true

[Install]
WantedBy=multi-user.target
UNIT
}
unit x-fleet-panel "X-Fleet panel" "/usr/local/bin/x-fleet panel -config /etc/x-fleet/panel.yaml"
systemctl daemon-reload
systemctl enable --now x-fleet-panel >/dev/null 2>&1 || die "$(L 'панель не запустилась — смотрите: journalctl -u x-fleet-panel -n 50' 'the panel did not start — see: journalctl -u x-fleet-panel -n 50')"
if command -v ufw >/dev/null && ufw status 2>/dev/null | grep -q 'Status: active'; then
  for p in 80 "$PORT" "$AGENT_PORT" "$SUB_PORT" "${VPN_PORTS[@]}"; do ufw allow "$p/tcp" >/dev/null; done
  ok "$(L 'ufw: открыты порты' 'ufw: opened ports') 80, $PORT, $AGENT_PORT, $SUB_PORT ${VPN_PORTS[*]}"
else
  info "$(L 'ufw выключен или не установлен — правила не добавляю' 'ufw is off or not installed — adding no rules')"
fi

SCHEME=https; [ "$HTTPS_MODE" = none ] && SCHEME=http
HOST="$DOMAIN"; case "$HTTPS_MODE" in self|none) HOST="$IP" ;; esac
CURL=(curl -fsS --max-time 3 -o /dev/null); [ "$HTTPS_MODE" = self ] && CURL+=(-k)
HEALTH="$SCHEME://$HOST:$PORT$BASE/healthz"; [ "$HTTPS_MODE" = none ] && HEALTH="http://127.0.0.1:$PORT$BASE/healthz"
case "$HTTPS_MODE" in le|ip) info "$(L "получаю сертификат Let's Encrypt для $DOMAIN (до минуты)…" "getting a Let's Encrypt certificate for $DOMAIN (up to a minute)…")" ;; esac
PANEL_OK=""
for i in $(seq 1 90); do
  if "${CURL[@]}" "$HEALTH" 2>/dev/null; then PANEL_OK=1; break; fi
  [ $((i % 10)) -eq 0 ] && info "$(L "…ещё жду ($((i * 2)) с)" "…still waiting ($((i * 2)) s)")"
  sleep 2
done
if [ -z "$PANEL_OK" ]; then
  printf '\n%s✗ %s%s\n\n' "$R" "$(L 'панель не ответила за 3 минуты' 'the panel did not answer within 3 minutes')" "$N"
  echo "  $(L 'Служба' 'Service'): $(systemctl is-active x-fleet-panel)"
  # Строки «missing certificate» — это наши же попытки открыть панель; причина — в строке об ошибке сертификата.
  ACME_ERR="$(journalctl -u x-fleet-panel --no-pager -o cat 2>/dev/null | grep -v 'missing certificate' | grep -E 'level=ERROR|rateLimited|acme' | tail -3 || true)"
  echo "  $(L 'Последние строки журнала' 'Last log lines'):"
  if [ -n "$ACME_ERR" ]; then
    printf '%s\n' "$ACME_ERR" | sed 's/^/    │ /'
  else
    journalctl -u x-fleet-panel -n 25 --no-pager -o cat 2>/dev/null | grep -v 'missing certificate' | tail -15 | sed 's/^/    │ /' || true
  fi
  echo
  if printf '%s' "$ACME_ERR" | grep -q 'rateLimited'; then
    AFTER="$(printf '%s' "$ACME_ERR" | grep -o 'retry after [0-9-]* [0-9:]* UTC' | head -1 | sed 's/retry after //')"
    warn "$(L "Лимит Let's Encrypt: для $DOMAIN уже выдано 5 сертификатов за неделю. Новый — после ${AFTER:-7 дней}." "Let's Encrypt limit: 5 certificates for $DOMAIN were issued this week. The next one — after ${AFTER:-7 days}.")"
    info "$(L "Сейчас: x-fleet https → 1 → поддомен (например, panel.$DOMAIN; нужна A-запись) или → 2 (адрес по IP)." "Now: x-fleet https → 1 → a subdomain (for example, panel.$DOMAIN; needs an A record) or → 2 (address by IP).")"
    echo
  fi
  if [ "$LNG" = en ]; then
    echo "  Common causes:"
    echo "    • port 80 is closed at the hosting provider (firewall in the control panel) — Let's Encrypt cannot check the domain;"
    echo "    • Let's Encrypt limit on repeated certificates for one name (in the log: rateLimited) —"
    echo "      wait or use your own domain: --domain panel.example.com;"
    echo "    • the certificate is still being issued — wait a couple of minutes: x-fleet status"
    echo "  Sign-in details are saved in /root/x-fleet-admin.txt; server check: x-fleet check"
  else
    echo "  Частые причины:"
    echo "    • у хостера закрыт порт 80 (файрвол в личном кабинете) — Let's Encrypt не может проверить домен;"
    echo "    • лимит Let's Encrypt на частые сертификаты для одного имени (в журнале: rateLimited) —"
    echo "      подождать или указать свой домен: --domain panel.example.com;"
    echo "    • сертификат ещё выдаётся — подождите пару минут: x-fleet status"
    echo "  Данные для входа уже записаны в /root/x-fleet-admin.txt; проверка сервера: x-fleet check"
  fi
  printf '%s %s://%s:%s%s/\n%s %s\n%s %s\n' "$(L 'Панель: ' 'Panel:    ')" "$SCHEME" "$HOST" "$PORT" "$BASE" "$(L 'Логин:  ' 'Login:    ')" "$LOGIN" "$(L 'Пароль: ' 'Password: ')" "$PASS" > /root/x-fleet-admin.txt
  chmod 600 /root/x-fleet-admin.txt
  exit 1
fi
ok "$(L "панель отвечает на порту $PORT" "the panel answers on port $PORT")"

if [ "$CONN" != none ]; then
  /usr/local/bin/x-fleet setup local-node -name "$NODE_NAME" \
    -address "$IP" ${NODE_DOMAIN:+-domain "$NODE_DOMAIN"} >/dev/null || die "$(L 'не удалось зарегистрировать этот сервер как ноду' 'could not register this server as a node')"
  unit x-fleet-node "X-Fleet node agent" "/usr/local/bin/x-fleet node -config /etc/x-fleet/node.yaml"
  systemctl daemon-reload
  systemctl enable --now x-fleet-node >/dev/null 2>&1 || die "$(L 'нода не запустилась — смотрите: journalctl -u x-fleet-node -n 50' 'the node did not start — see: journalctl -u x-fleet-node -n 50')"
  info "$(L 'нода скачивает Xray и запускает подключения…' 'the node downloads Xray and starts the connections…')"
  UP=""
  for i in $(seq 1 60); do
    ALL=1; for p in "${VPN_PORTS[@]}"; do busy "$p" || ALL=""; done
    [ -n "$ALL" ] && { UP=1; break; }
    sleep 2
  done
  if [ -n "$UP" ]; then
    ok "$(L 'VPN работает: порты' 'VPN is running: ports') ${VPN_PORTS[*]}"
  else
    warn "$(L 'VPN ещё не поднялся за 2 минуты — проверьте позже: x-fleet check (журнал: x-fleet log)' 'the VPN is not up after 2 minutes — check later: x-fleet check (log: x-fleet log)')"
  fi
  SUB_URL="$(/usr/local/bin/x-fleet setup user "$FIRST_USER")" || die "$(L "не удалось создать пользователя $FIRST_USER" "could not create user $FIRST_USER")"
  ok "$(L "пользователь $FIRST_USER создан" "user $FIRST_USER created")"
fi

# ========== 9. Проверка
step "$(L 'Проверка' 'Check')"
if "${CURL[@]}" "$HEALTH"; then ok "$(L 'панель' 'panel'): $SCHEME://$HOST:$PORT$BASE/"; else warn "$(L 'панель не отвечает' 'the panel does not answer')"; fi
if [ -n "${SUB_URL:-}" ]; then
  SUBCURL=(curl -fsS --max-time 8 -o /dev/null); [ "$HTTPS_MODE" = self ] && SUBCURL+=(-k)
  if "${SUBCURL[@]}" "$SUB_URL"; then
    ok "$(L 'подписка открывается снаружи' 'the subscription opens from outside')"
  else
    warn "$(L "подписка не открылась — проверьте порт $SUB_PORT у хостера" "the subscription did not open — check port $SUB_PORT at the hosting provider")"
  fi
fi
if [ "$(cat /proc/sys/net/ipv4/tcp_congestion_control 2>/dev/null)" = bbr ]; then ok "$(L 'BBR включён' 'BBR is on')"; fi
if [ "$HTTPS_MODE" = self ]; then warn "$(L "самоподписанный сертификат: часть клиентов VPN не примет подписку — лучше домен или $SSLIP (x-fleet https)" "self-signed certificate: some VPN clients will reject the subscription — better a domain or $SSLIP (x-fleet https)")"; fi
if [ -f /var/run/reboot-required ]; then warn "$(L 'после обновления системы сервер просит перезагрузку: reboot — всё запустится само' 'the server asks for a reboot after the upgrade: reboot — everything starts by itself')"; fi

echo
/usr/local/bin/x-fleet setup card -password "$PASS" ${FIRST_USER:+-user "$FIRST_USER"} || true
if [ "$HTTPS_MODE" = none ]; then
  echo
  warn "$(L 'Панель открыта только через SSH-туннель. На своём компьютере:' 'The panel is reachable only via an SSH tunnel. On your computer:') ssh -L $PORT:127.0.0.1:$PORT root@$IP"
  info "$(L 'затем откройте' 'then open') http://localhost:$PORT$BASE/"
fi
