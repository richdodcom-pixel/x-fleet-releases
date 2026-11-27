[English](README.en.md) | [العربية](README.ar.md) | [فارسی](README.fa.md) | [中文](README.zh.md) | [Español](README.es.md) | [Русский](README.md) | **Türkçe**

<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="media/logo-dark.svg">
    <img src="media/logo-light.svg" alt="X-Fleet" width="420">
  </picture>
</p>

# X-Fleet — kurulum

Burada X-Fleet'in hazır sürümleri bulunur (**Releases** sekmesi): Linux programı (amd64, arm64),
`install.sh` kurulum betiği ve `SHA256SUMS` sağlama toplamları. Aşağıda nasıl kurulacağı anlatılıyor.

X-Fleet, Xray VPN'i aynı anda birçok sunucuda yönetmek için bir paneldir. Tek komutla kurulur,
Docker ve ayrı bir veritabanı gerekmez.

> Kurulum programı ve panel arayüzü **İngilizce** ve **Rusça** olarak sunulur. Aşağıda menü ve düğme adları paneldeki gibi İngilizce verilmiştir.

## Gereksinimler

- **Ubuntu 22.04+** veya **Debian 12+** yüklü bir sunucu (VPS), amd64 ya da arm64 işlemci.
- SSH ile **root** erişimi.
- Tercihen sunucu IP'sine A kaydı olan kendi alan adınız (örneğin `panel.example.com`).
  Alan adı olmadan da olur: panel `1-2-3-4.sslip.io` gibi ücretsiz bir ad kullanır.
- Barındırma sağlayıcısında açık portlar (kendi güvenlik duvarı varsa onun kontrol panelinde):

| Port | Ne için |
|---|---|
| 80 | Let's Encrypt sertifika vermek için alan adını doğrular |
| rastgele (kurulum programı gösterir) | panele giriş |
| 8444 | düğümler panele bağlanır |
| 2096 | istemciler için abonelik bağlantıları |
| 443 ve 8443 | VPN'in kendisi (bu sunucu da VPN sağlıyorsa) |

Sunucuda `ufw` açıksa kurulum programı gerekli portları kendisi açar.

## 1. Panelin kurulumu

Sunucuya root olarak girin ve çalıştırın:

```bash
bash <(curl -fsSL https://github.com/richdodcom-pixel/x-fleet-releases/releases/latest/download/install.sh)
```

Kurulum sihirbazı açılır ve adım adım sorular sorar. Emin değilseniz Enter'a basın: varsayılan seçenek seçilir.

1. **Dil:** Rusça veya İngilizce.
2. **Sistem kontrolü ve paketler.** Kurulum programı sistemi güncellemeyi önerir (`apt upgrade`).
   Üzerinde zaten bir şey çalışan sunucuda reddedebilirsiniz.
3. **Adres ve HTTPS.** Alan adınızı yazın veya alan adsız seçeneği (sslip.io) seçin.
   Panel Let's Encrypt sertifikasını kendisi alır.
4. **Panel ayarları.** Port, gizli yol ve kullanıcı adı rastgele seçilir, parola otomatik oluşturulur.
5. **Bu sunucuda VPN.** Bu sunucuyu hemen ilk düğüm yapabilirsiniz:
   - 443 portunda VLESS Reality XHTTP (ana bağlantı);
   - 8443 portunda TCP + Vision (yedek).

   Burada ayrıca kamuflaj sitesi seçilir ve ilk kullanıcı oluşturulur.
6. **Başlatma ve kontrol.** Servisler başlar ve sunucu yeniden başlatıldığında kendiliğinden açılır.

Sonunda ekranda **panel adresi, kullanıcı adı ve parola** ile ilk kullanıcının abonelik QR kodu gösterilir.
Giriş bilgileri `/root/x-fleet-admin.txt` dosyasına kaydedilir. Tekrar görmek için:

```bash
cat /root/x-fleet-admin.txt
```

### Sorusuz kurulum

`--yes` ekleyin, her şey varsayılan olarak seçilir. Diğer parametreleri hemen verebilirsiniz:

```bash
bash <(curl -fsSL https://github.com/richdodcom-pixel/x-fleet-releases/releases/latest/download/install.sh) --yes --domain panel.example.com
```

| Parametre | Ne yapar |
|---|---|
| `--lang ru\|en` | kurulum programı ve menü dili |
| `--domain panel.example.com` | panel ve abonelikler için kendi alan adınız |
| `--https le\|ip\|self\|none` | HTTPS: kendi alan adı / alan adsız (sslip.io) / kendinden imzalı / HTTPS yok (yalnızca SSH tüneli) |
| `--cert dosya --key dosya` | Let's Encrypt yerine kendi sertifikanız |
| `--email you@example.com` | Let's Encrypt bildirimleri için e-posta |
| `--port 31234` | panel portu (varsayılan: rastgele) |
| `--login ad` | yönetici kullanıcı adı (varsayılan: rastgele) |
| `--connections rec\|xhttp\|vision\|none` | bu sunucuda VPN: iki bağlantı / yalnız XHTTP / yalnız Vision / yok |
| `--mask neighbor\|self\|<site>` | Reality kamuflajı: aynı alt ağdaki komşu site / sunucudaki kendi siteniz / belirtilen site |
| `--user ad` | ilk kullanıcı (varsayılan `user`) |
| `--name ad` | istemci uygulamalarındaki sunucu adı, Latin harfleriyle |
| `--upgrade` / `--no-upgrade` | sistemi güncelle veya güncelleme |
| `--bbr` / `--no-bbr` | TCP hızlandırmayı (BBR) aç veya kapat; varsayılan olarak açılır |
| `--version v0.7.1` | belirli bir sürümü kur |

Parametrelerin tam açıklaması:

```bash
bash <(curl -fsSL https://github.com/richdodcom-pixel/x-fleet-releases/releases/latest/download/install.sh) --help
```

## 2. İlk giriş

1. Kurulum programının gösterdiği adresi tarayıcıda açın, örneğin
   `https://panel.example.com:31234/AbCdEf123/`.
   Adres gizlidir: doğru yol olmadan panel açılmaz, tarayıcı botlar onu bulamaz.
2. `/root/x-fleet-admin.txt` dosyasındaki kullanıcı adı ve parolayla giriş yapın.
3. Hemen yapmanızı öneririz:
   - **Settings → Security**: parolayı değiştirin ve iki adımlı girişi açın;
   - **Settings → Notifications**: arızalardan haberdar olmak için Telegram'ı bağlayın;
   - **Settings → System**: zamanlanmış yedeklemeyi açın.

## 3. Düğüm ekleme (diğer VPN sunucuları)

**Düğüm** (node), istemcilerin VPN'e bağlandığı sunucudur. Panel düğümleri uzaktan yönetir.
Her yeni düğüm için bir **kurulum komutu** gerekir. Bunu panelin kendisi verir, GitHub'da yoktur:
komutta sizin panelinizin adresi ve tek kullanımlık bir anahtar bulunur.

### Adım 1. Komutu panelden alın

1. Paneli tarayıcıda açın ve giriş yapın.
2. Soldaki menüden **Nodes**'u seçin.
3. Mavi **Add node** düğmesine basın (sağ üstte).
4. Formu doldurun:

   | Alan | Ne yazılır |
   |---|---|
   | **Name** | Latin harfleriyle anlaşılır herhangi bir ad, örneğin `amsterdam-1` |
   | **Address (IP or domain)** | yeni sunucunun IP'si, örneğin `203.0.113.10`. İstemciler bunu abonelikte görür |
   | **Node domain (for camouflage)** | boş bırakılabilir. Bu sunucunun IP'sine A kaydı olan bir alan adınız varsa yazın, örneğin `nl1.example.com` |
   | **Country** ve **City** | boş bırakılabilir: panel bunları IP'den kendisi belirler. İstemciler örneğin `🇳🇱 Netherlands, Amsterdam` görür |
   | **Add inbounds from templates right away** | işaretli bırakın: düğümdeki bağlantılar kendiliğinden oluşturulur |

5. **Create**'e basın.
6. Uzun bir komut içeren **Install node** penceresi açılır. Komut `curl -fsSL https://…/node.sh | bash -s -- …` ile başlar.
   Komutun sağındaki **kopyala** simgesine basın.

Komut kabaca şöyle görünür (adres, token ve parmak izi sizde farklı olur):

```text
curl -fsSL https://panel.example.com:2096/install/Ab12Cd/node.sh | bash -s -- --panel panel.example.com:8444 --token 7f3a… --pin 9c1e…
```

> **Önemli:** komut tek kullanımlıktır ve **15 dakika** geçerlidir (bitiş zamanı pencerede yazar).
> Yetişemediniz veya pencereyi kapattınız mı? **Nodes**'u açın → düğüme tıklayın → **New install token**,
> yeni bir komut görünür.

**Diğer yol: panel sunucusundan.** Panelin kurulu olduğu sunucuya SSH ile girin ve çalıştırın:

```bash
x-fleet node-cmd
```

Program düğüm adını, IP'sini ve alan adını sorar (Enter: alan adı yok) ve hazır komutu yazdırır. Komut 30 dakika geçerlidir.

### Adım 2. Komutu yeni sunucuda çalıştırın

1. **Yeni sunucuya** (panel sunucusuna değil, gelecekteki düğüme) root olarak SSH ile girin:
   ```bash
   ssh root@203.0.113.10
   ```
2. Kopyaladığınız komutu yapıştırın (terminalde: sağ tık veya Ctrl+Shift+V / Cmd+V) ve Enter'a basın.
3. 1–2 dakika bekleyin. Düğüm kendisi:
   - programı panelinizden indirir ve sağlama toplamını doğrular;
   - panele güvenli bir kanal üzerinden bağlanır;
   - Xray'i indirip başlatır.

### Adım 3. Kontrol edin

Panele dönün → **Nodes**. Birkaç saniye içinde yeni düğümün durumu yeşile döner.
Şablonlardaki bağlantılar zaten oluşturulmuştur. Düğüm, dahil olduğu gruptaki kullanıcıların aboneliklerinde görünür
(**Squads** bölümü). Abonelik bağlantısını değiştirmek gerekmez: uygulama aboneliği yenilediğinde yeni sunucuyu alır.

### Olmadıysa

- **"install token expired":** yeni komut alın: düğüm sayfası → **New install token**.
- **Düğüm panele bağlanmıyor:** panel sunucusunda **8444** portu açık olmalıdır
  (ve **2096**, program buradan indirilir). Sağlayıcının güvenlik duvarını kontrol edin.
- **Yeni sunucuda zaten başka bir VPN çalışıyor** (örneğin 3x-ui) ve 443/8443 portları dolu: kurulum programı durur
  ve portu hangi programın tuttuğunu gösterir. Böylece eski VPN bozulmaz. Portları boşaltın veya panelde bu düğüme
  başka portlar verin.
- **Düğüm panelin kendi sunucusu:** hiçbir şey kurmanız gerekmez, panel kurulum sihirbazı bunu baştan önerir ("Bu sunucuda VPN" adımı).

## 4. Kullanıcılar ve abonelikler

**Users** → **New user**. Her kullanıcının uygulamaya eklenen bir abonelik bağlantısı vardır.
Abonelik sayfası bir QR kodu ve uygulama düğmeleri gösterir.

### İstemci uygulamaları

| Uygulama | Abonelik nasıl eklenir |
|---|---|
| **NOX** (önerilir, Android 7+) | [NOX.apk'yi indirin](https://github.com/richdodcom-pixel/nox-updates/releases/latest/download/NOX.apk). Abonelik sayfasındaki **NOX** düğmesi uygulamayı açar ve aboneliği ekler |
| Happ, Hiddify, INCY, v2RayTun, Streisand, v2rayNG, Clash Verge / FlClash | abonelik sayfasındaki uygulama düğmesi (veya abonelik bağlantısını uygulamaya yapıştırın) |
| sing-box ve diğer Clash / Mihomo istemcileri | abonelik bağlantısını yapıştırın: panel doğru biçimi kendisi verir |

## Sunucudan yönetim: `x-fleet` komutu

Sunucuda `x-fleet` yazın, menü açılır. Hızlı komutlar:

| Komut | Ne yapar |
|---|---|
| `x-fleet url` | panel adresini ve kullanıcı adını göster |
| `x-fleet password` | yeni yönetici parolası |
| `x-fleet 2fa off` | iki adımlı girişi kapat (telefonu kaybettiyseniz) |
| `x-fleet status` | servislerin durumu |
| `x-fleet restart` | servisleri yeniden başlat |
| `x-fleet log` | günlük |
| `x-fleet port 31234` | panel portunu değiştir |
| `x-fleet path` | yeni gizli panel yolu |
| `x-fleet https` | panel sertifikası |
| `x-fleet update` | X-Fleet'i güncelle |
| `x-fleet backup` | şimdi yedekle |
| `x-fleet check` | sunucu kontrolü |
| `x-fleet link ad` | kullanıcının QR kodlu abonelik bağlantısı |
| `x-fleet node-cmd` | yeni düğüm için kurulum komutu |

## Güncelleme

- **Panel:** **Settings → System → Panel update**. Veya sunucuda: `x-fleet update`.
  Önceki sürüm geri dönüş için saklanır.
- **Düğümler:** **Settings → Cores**: Xray'i ve ajanları tüm düğümlerde aynı anda güncelleyin.
  Veya tek tek, düğüm sayfasında. **Settings → System → Update all servers** tüm düğümleri tek tıkla günceller.

## Panel adresini veya alan adını değiştirme

**Settings → Network & certificates**. Burada port, gizli yol ve sertifika değiştirilir
(kendi alan adı, sslip.io veya kendinden imzalı).

- Panel yeni alan adı için sertifikayı geçişten **önce** alır. Let's Encrypt reddederse hiçbir şey değişmez
  ve ekranda nedeni gösterilir.
- Değişiklikten sonra paneli yeni adreste açın ve **10 dakika içinde** giriş yapın. Aksi halde önceki ayarlar kendiliğinden geri gelir
  ve erişimi kaybetmezsiniz.

## Bir şey çalışmıyorsa

- **Sertifika alınamıyor:**
  - alan adının A kaydının sunucu IP'sini gösterdiğini ve Cloudflare'de bulutun gri (yalnızca DNS) olduğunu kontrol edin;
  - sağlayıcıda 80 portunun açık olduğunu kontrol edin;
  - Let's Encrypt bir ad için haftada en fazla 5 sertifika verir. Sık yeniden kuruyorsanız bekleyin
    veya geçici olarak alan adsız seçeneği (sslip.io) seçin.
- **Adresi veya parolayı unuttunuz:** sunucuya girin ve `x-fleet url` veya `x-fleet password` çalıştırın.
- **Genel kontrol:** `x-fleet check`.

## Kaldırma

```bash
x-fleet uninstall
```

Komut servisleri durdurur; programı, ayarları ve verileri siler. Yedekler `/var/lib/x-fleet/backups` içinde kalır.

---

## Eski sürümlerden (nodepanel) güncelleyenler için

v0.5.0'dan önce programın adı `nodepanel` idi. Düğmeyle güncellerken her şey yeni adlara kendiliğinden taşınır:

| Eskiden | Şimdi |
|---|---|
| `/usr/local/bin/nodepanel` | `/usr/local/bin/x-fleet` (eski ad bağlantı olarak kalır) |
| `nodepanel-panel`, `nodepanel-node` servisleri | `x-fleet-panel`, `x-fleet-node` |
| `/etc/nodepanel`, `/var/lib/nodepanel`, `/var/lib/nodepanel-node` | `/etc/x-fleet`, `/var/lib/x-fleet`, `/var/lib/x-fleet-node` |
| `/root/nodepanel-admin.txt` | `/root/x-fleet-admin.txt` |

Yeni servis başlamazsa her şey eski haline döner. Elle tekrarlamak için: `x-fleet migrate`;
taşıma günlüğü: `journalctl -u x-fleet-migrate`.

## Projeye destek olun

X-Fleet ücretsizdir ve tek bir geliştirici tarafından boş zamanında geliştirilir. Panel işinize yaradıysa
gelişimini istediğiniz miktarla destekleyebilirsiniz. Bu gönüllüdür: tüm özellikler ücretsiz çalışır.

| Coin | Ağ | Adres |
|---|---|---|
| USDT | **TRON (TRC20)** | `TYWjc2oNwm32wcQUX5cDjQ2vWCCLuS1vkH` |
| USDT, TON | **TON** | `UQB6Fryf-lEQXMGQlOIdHu5QTk_lcOgeKL0m424k92hbiWhw` |

> ⚠️ Coinleri yalnızca belirtilen ağdan gönderin: başka ağlardan yapılan transferler kaybolur.
> Bu adreslerin QR kodları panelin kendisinde: menüdeki **Support** öğesi.

Teşekkürler! 💙
