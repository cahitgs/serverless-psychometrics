# Serverless Psychometrics — Proje Planı (v2)

> **Makale türü:** BRM Tutorial Collection ("Tutorial" makale türü; koleksiyon rolling — Mart 2026 öncelik tarihi geçti, engel değil)
> **Çalışma başlığı:** *Serverless psychometrics: Building privacy-preserving and sustainable web applications with webR and Shinylive*
> **Tek cümlelik tez:** BRM'de yayımlanan sunuculu Shiny araçları zamanla erişilemez hale geliyor; psikometri uygulamaları R'ı kullanıcının tarayıcısında çalıştıran, sunucusuz, gizlilik-korumalı ve kalıcı uygulamalara dönüştürülebilir.
> **Revizyon:** 2026-07-27 — beyin fırtınası + 5 ajanlık literatür/teknik taraması + ilk çalışan prototip sonrası. v1'den değişenler bu dosyada işlendi.

---

## 0. Durum — bugün tamamlananlar (2026-07-27)

- [x] Ortam: R 4.4.1; shiny 1.13.0, **shinylive 0.5.0** (web assets 0.10.12 → **webR 0.6.0 / R 4.6.0**), httpuv 1.6.15, httr2 1.1.2, psych 2.5.6
- [x] Depo iskeleti oluşturuldu (§3'teki yapı)
- [x] **OmegaLite yazıldı** (`apps/omegalite/app.R`): tamamen base R + shiny; ω_t (tek faktör ML `factanal`), α, bootstrap %95 GA (sabit seed), madde-toplam r, silinirse-α/ω, CSV indirme. Chrome/Shinylive indirme düzeltmesi (Chromium #468227: `download` attribute strip) ve `shiny.maxRequestSize = 100 MB` eklendi.
- [x] **Doğrulama (psych ile çapraz):** α birebir eşit (fark 0); ω farkı 1.0e-4 (ML optimizasyon rutini farkı); madde istatistikleri makine hassasiyetinde eşit
- [x] **Export:** ilk 88 s (asset indirme dahil), sonraki 3 s; 189 dosya, **68.4 MB**; ek wasm paketi gerekmedi → bundle tamamen kendi kendine yeterli (CDN'siz)
- [x] **Headless Chrome uçtan uca test:** yükleme→CSV→analiz→sonuç; hazır olma 7.2 s (yerel), analiz 1.5 s (N=500×8, 2×200 bootstrap); **sonuçlar native R ile eşleşti, bootstrap GA'lar dahil (aynı RNG!)**; upload→analiz arasında **0 ağ isteği, 0 harici host** → §7.4 gizlilik kanıt yöntemi doğrulandı. Görsel: `figures/omegalite-e2e-test.png`
- [x] `paper/versions.txt` (TOP Level 2 sürüm kaydı)

**Bugünkü kararlar:** audit yıl aralığı **2015–2025**; makale **Quarto → Word (docx)**; OmegaLite çekirdeği bilinçli olarak **psych'siz** (webR garantisi + minimal pedagojik örnek + psych yereldeki doğrulama kıyası olarak kullanılıyor).

---

## 1. Stratejik bulgular (tarama sentezi)

- **Niş AÇIK.** ~25 ayrı aramada hiçbir psikoloji/metodoloji dergisinde webR/Shinylive tutorial'ı yok; **psikolojide Shiny link-rot denetimi hiç yapılmamış** → audit makalenin en özgün, en atıf çekecek bileşeni.
- **Çürütülecek kaynak:** Brun et al. 2025, PLOS Comp Biol "Ten quick tips" — Shinylive'ı tek cümlede "yeterince stabil/hızlı değil" diye geçiştiriyor. Benchmark bölümümüz bu iddiayı güncel sürümlerle veriyle yanıtlayacak (makalenin gizli kancası).
- **Müttefik önceller:** DataMap (F1000Research 2025; Shinylive+Pages, aynı gizlilik argümanı), Wasm-iCARE (JAMIA Open 2024; R→Python→Wasm — bizim yolun pahalı alternatifi), Perkel 2024 Nature webR haberi.
- **Dergi içi çıpalar:** Ellis et al. 2024 (BRM'nin kendi yeniden üretilebilirlik denetimi — "izleyen çalışma" konumlanması) + **Manolov 2026, BRM 58:71** — birkaç ay önce 6+ shinyapps.io linkiyle yayımlanmış tutorial; giriş için canlı kanıt (kohort dışı, anlatısal kullanım).
- **Metod şablonu:** Kern et al. 2020 NAR (2.396 araç, 133 gün günlük probing; %31 hep açık / %48.4 aralıklı / %20.6 hiç → tek seferlik kontrol ciddi hata yapar).
- **Yapı şablonu:** Rubo 2025 (IMRaD değil: Introduction → Software → ... → Conclusion) + Riesthuis 2025 (canlı uygulama + OSF + GitHub üçlü beyan kalıbı).
- **TOP Level 2 sanılandan sert:** "trusted repository" şart — Zenodo/OSF *zorunluluk*, süs değil. Open Practices Statement References'tan hemen önce; 7 maddelik Declarations bloğu (Code availability ayrı kalem).
- **OA maliyeti:** ~£2.690 / $4.090 — kurumsal anlaşma ERKEN kontrol edilmeli (kalıcılık tezini paywall arkasında savunmak ironik olur).
- **Kapak mektubu:** koleksiyon çağrısındaki iki konu maddesini ("step-by-step guides to software tools", "open science practices") aynen alıntıla; "bu makalenin tüm artefaktları DOI'lidir" öz-tutarlılık vurgusu.

---

## 2. AÇIK KARAR — Aşama C stratejisi (BiasDetectR henüz yok)

v1 "mevcut app.R'ı taşı" diyordu; uygulama taslak halinde. Seçenekler:

| Seçenek | Anlatı | Risk |
|---|---|---|
| **C1 — Diriltme + born-serverless (öneri)** | Audit'te bulunan, kodu açık **ölü bir BRM uygulamasını** Shinylive'da dirilt (gerçek migrasyon kanıtı — tezin kendisi) + BiasDetectR'ı "yeni araç sunucusuz doğar" örneği olarak yaz | Diriltilecek aday bulunamayabilir; ama başarısız deneme bile veridir (Trisovic 2022: R kodlarının %74'ü temiz ortamda çalışmıyor) |
| C2 — Önce sunuculu BiasDetectR, sonra port | v1 anlatısı korunur; migrasyon "kendi uygulamamız" üzerinden | Migrasyon kurgusal kaçar (aynı app.R zaten iki yerde çalışıyor); ekstra iş |
| C3 — Yalnız born-serverless BiasDetectR | En hızlı | "Mevcut araçlar dönüştürülebilir" iddiası örneksiz kalır |

Karar verilince §7 güncellenecek. (webR paket uygunluğu artık büyük engel değil: repo.r-wasm.org R-4.6 contrib **22.741 paket**; psych 2.6.5, lavaan 0.6-21, mirt 1.46.1, ggplot2 4.0.3, GPArotation, mnormt hepsi hazır binary.)

---

## 3. Depo yapısı

```
BRM-SHİNY/
├── serverless-psychometrics-PLAN.md
├── audit/            ← Aşama A (protocol.md, check_links.R, results.csv, probe logs)
├── apps/
│   ├── omegalite/    ← ✅ yazıldı
│   └── biasdetectr-live/
├── site/             ← shinylive::export çıktıları (elle düzenlenmez)
├── benchmark/        ← datasets/, equivalence.R, timings.csv
├── paper/            ← Quarto (→ docx); versions.txt ✅
└── figures/          ← omegalite-e2e-test.png ✅
```

---

## 4. Kurulum — ✅ tamam + kalıcılık notları

- [x] R ≥ 4.3, paketler, boş export doğrulaması (OmegaLite üzerinden fazlasıyla yapıldı)
- [x] Sürüm kaydı `paper/versions.txt`
- **Pinleme:** `shinylive::export(assets_version=...)` / `SHINYLIVE_ASSETS_VERSION`; shinylive 0.5.0 wasm binary'leri repo güncellendikçe TAZELER → bit-düzeyi tekrar üretilebilirlik için **export edilmiş bundle'ın kendisi arşivlenir** (Zenodo), yalnız kaynak değil.
- Paket uygunluğu artık repo indexinden toplu kontrol edilebilir (webr.r-wasm.org konsolu tek tek denemeye gerek yok); canlı doğrulama yine yapılır.

---

## 5. Aşama A — Link-rot denetimi (Kern-tarzı yükseltilmiş protokol)

### Örneklem
- Springer Link, BRM tam metin: `"shinyapps.io"` (birincil), `"shiny application"`, `"Shiny app"` (ikincil, elle elenir); **2015–2025**; canlı uygulama URL'si verilenler dahil, yalnız paket linki verenler hariç. Beklenen ~100–150 makale.
- Manolov 2026 kohort dışı, giriş anlatısında.

### Tasarım yükseltmeleri (v1'den farklar)
1. **Tekrarlı probing:** tek seferlik kontrol yerine **GitHub Actions ile günlük otomatik tarama, 14–28 gün** → durum: *hep açık / aralıklı / hiç* (Kern 2020). Bu yüzden URL toplama işi öne çekildi (bkz. §11 takvim) — pencere yazım süresine paralel akar.
2. **Dereceli sonuç değişkeni:** (i) URL çözülüyor (2XX) → (ii) gerçek uygulama render oluyor (uyku/hata sayfası değil) → (iii) girdi kabul ediyor → (iv) standart test girdisine makul çıktı veriyor; ayrıca (v) ölüyse kaynak kod kurtarılabilir mi (GitHub/CRAN/OSF/Zenodo/SWH) ve (vi) web arşivi kaydı var mı (Memento). "Ulaşılabilir ≠ işlevsel" ayrımı raporun belkemiği.
3. **⚠️ Tuzak (v1'den):** shinyapps.io uyku/saat doldu sayfası **HTTP 200 döndürür** → 200 dönen her link elle sınıflanır; soft-fail metin taraması eklenir.
4. **Öngörücüler:** yayın yılı, atıf sayısı, hosting türü (shinyapps free/paid, kurum sunucusu, diğer), kodun depolanmış olup olmadığı, BRM 2020 TOP politikası öncesi/sonrası.
5. **Başlık figürü:** yıl bazlı sağkalım eğrisi; Ősz 2019 (10.39 yıl) ve Hennessey & Ge 2013 (9.3 yıl) yarı ömürleri referans çizgisi → "Shiny uygulamaları genel web kaynaklarından hızlı mı ölüyor?"
6. **OSF ön-kayıt:** `audit/protocol.md` taramadan ÖNCE OSF'ye → "arama dizgileri sonuçtan sonra seçildi" itirazını peşinen kapatır (Ellis 2024 ile aynı dergi geleneği).
7. **Opsiyonel kollar (karara bağlı):** (a) **yazar kurtarma** — ölü uygulama yazarlarına e-posta (Kern'de %51.1 geri geldi; yanıt süresi riski → "gönderim anında sürüyor" diye raporlanabilir); (b) **statik-link kontrol kohortu** — aynı makalelerin OSF/GitHub linkleri (dinamik-içerik farkını izole eder; Sadatmoosavi 2026: dinamik içerik %41 vs statik %92 erişilebilir).
8. `check_links.R`: httr2; timeout/redirect politikası dokümante (Kern: 30 s, ≤50 redirect); redirect'ler ayrı kategori; ikinci kodlayıcı varsa uyum katsayısı.

### Görevler
- [ ] protocol.md yaz → OSF ön-kayıt
- [ ] Springer araması + URL çıkarımı → results.csv iskeleti
- [ ] check_links.R + GitHub Actions günlük probe → **hemen başlat**
- [ ] 200'leri elle sınıfla (dereceli ölçek)
- [ ] Sağkalım figürü + vurucu yüzde
- [ ] Ham veri OSF'ye

---

## 6. Aşama B — OmegaLite — büyük ölçüde ✅

Kalanlar:
- [ ] GitHub Pages'e deploy (repo + Actions); telefonda aç
- [ ] İndirmeyi gerçek Chrome + Firefox'ta elle doğrula (workaround kondu, headless test indirmeyi test etmedi)
- [ ] Makale ekran görüntüleri (yükleme → seçim → sonuç)
- Not: makalede `app.R` tam listing olarak basılacak (BRM aims & scope bunu açıkça teşvik ediyor; ~140 satır uygun boy)

---

## 7. Aşama C — BiasDetectR Live (§2 kararına göre revize edilecek)

### 7.1 Bağımlılık karar tablosu
Konsept aynı (makale çekirdeği); artık repo.r-wasm.org indexi + canlı doğrulamayla doldurulur. Tablo makine-okur biçimde depoya da girer (TOP L2).

### 7.2 DIF motoru (base R garantili — v1'den aynen)
- **Mantel–Haenszel:** `stats::mantelhaen.test()` + ETS delta (ΔMH = −2.35 × ln(αMH)) ve A/B/C sınıflaması
- **Lojistik regresyon DIF:** `stats::glm()` 3 model (toplam → +grup → +grup×puan), LRT (`anova(..., test="LRT")`), uniform/non-uniform, Nagelkerke ΔR²
- **Kapsam dışı (bilinçli):** IRT tabanlı DIF → karar rehberinde gerekçeli sınır (Riesthuis 2025 "aracın yapamadığını açıkça söyle" kalıbı bunu meşrulaştırıyor)

### 7.3 Diğer işlevler
- fileInput (maxRequestSize artırımı OmegaLite'tan kopyala), ggplot2 (webR'da hazır), downloadHandler (Chrome workaround'u kopyala), export + Pages

### 7.4 "Veri hiçbir yere gitmiyor" kanıtı — yöntem bugün OmegaLite'ta doğrulandı ✅
- [ ] Aynı puppeteer ağ-izleme testini BiasDetectR Live için tekrarla + DevTools ekran görüntüsü
- [ ] Kaynak kodda "harici çağrı yok" beyanı (Shinylive gizliliği otomatik garanti etmez — bizim garanti: açık kod + sıfır harici istek testi)

---

## 8. Aşama D — Eşdeğerlik ve performans

### 8.1 Eşdeğerlik
- N=500 / 5.000 / 50.000 + bilinen DIF'li simüle set; sunuculu vs Live birebir karşılaştırma
- İlk kanıt bugünden: OmegaLite'ta ω/α ve **bootstrap GA'lar** native R ile eşleşti (aynı RNG, aynı algoritma) — makalede "sadece nokta tahmin değil, stokastik prosedürler bile eşdeğer" cümlesi
- Yüzen nokta farkları için tolerans raporu (max |Δ|), "birebir" iddiası yerine

### 8.2 Performans matrisi
- N {500/5k/50k} × cihaz {laptop/orta segment telefon} × tarayıcı {Chrome/Firefox/Edge}; soğuk (önbelleksiz) + önbellekli ilk açılış AYRI; analiz süresi; 3 tekrar → medyan
- İlk veri: yerel soğuk 7.2 s, analiz 1.5 s (N=500)
- **PLOS CompBio'nun "30 MB'ta stabil değil" iddiasını doğrudan test eden ~30 MB senaryosu ekle**
- Bellek notu: wasm32 → 4 GB tavan (mobilde daha az); Pages'te COOP/COEP yok → PostMessage kanalı (çalışan R kesilemez) — sınırlılıklara

### 8.3 Uçak modu
- v1'deki gibi + nüans: analiz sırasında sunucusuzluk kanıtı ≠ ilk açılışın çevrimdışılığı; PWA graded menüsü karar rehberinde (baseline / manifest+SW ile kurulabilir; `shinylive-sw.js` ile çakışmamalı — implementasyon stretch)

---

## 9. Aşama E — Makale iskeleti (Rubo şablonuna göre; IMRaD değil)

| Bölüm | İçerik |
|-------|--------|
| Introduction | Üçlü huni: link-rot literatürü → biyoinformatik audit gelenegi → psikolojide boşluk; **kendi audit bulgumuz motivasyon alt-bölümü olarak burada**; Manolov 2026 canlı örnek |
| How it works | webR/WASM teknik olmayan anlatım + tek mimari şeması (sunuculu vs sunucusuz) |
| Step-by-step guide | export → yerel test (**file:// çalışmaz!**) → Pages → sürüm pinleme → Zenodo |
| Example 1: OmegaLite | tam kod listing + ekran görüntüleri |
| Example 2 (+3?): §2 kararına göre | migrasyon/diriltme + paket karar tablosu |
| Equivalence & performance | tablolar + uçak modu + PLOS CompBio yanıtı |
| Decision guide | ne zaman serverless / sunuculu (MCMC-Stan, dev veri, DB, gizli anahtar, kesintisiz uzun hesap → sunucu); PWA menüsü |
| Limitations | ilk yükleme (68 MB ölçtük), 4 GB bellek, kod+veri tamamen açık (gizli tutulamaz), paralellik yok, webR sürüm oynaklığı |
| Sustainability recommendations | **politika önerisi:** BRM için "Maintenance & Support statement" (Coelho 2024) + FAIR4RS + arşivleme kontrol listesi — audit'i katkıya çevirir |
| Conclusion | |

Biçim: APA 7; özet ≤250 kelime; kelime sınırı yok (emsaller 12–14k kelime, ~6 figür); Open Practices Statement References öncesi; 7 kalem Declarations (Ethics/Consent: "Not applicable").

### TOP Level 2 uyum (zorunluluk!)
- [ ] GitHub repo (lisans) + **her gönderim sürümünde release → Zenodo otomatik DOI**
- [ ] Zenodo deposit: kaynak + **export edilmiş site zip'i** (concept DOI makalede)
- [ ] Yeniden kurulum cümlesi makalede: "unzip → `httpuv::runStaticServer('site/')`; file:// çalışmaz"
- [ ] Audit ham verisi + protokol OSF; versions.txt Zenodo deposit'inin İÇİNDE
- [ ] Software Heritage Save Code Now + SWHID (ücretsiz üçüncü katman)
- [ ] Temiz makinede, çevrimdışı, arşiv zip'inden uygulamayı çalıştırma testi
- [ ] Kurumsal OA anlaşması kontrolü — ERKEN

---

## 10. Zaman çizelgesi (revize, 4 hafta — audit öne çekildi)

| Gün | İş |
|-----|-----|
| 1 | ✅ Kurulum + OmegaLite + export + e2e test (bugün) |
| 2–3 | **Audit protokolü + OSF ön-kayıt + Springer araması + probe'u BAŞLAT** (pencere paralel aksın) + OmegaLite Pages deploy |
| 4–5 | §2 kararı uygulanır: BiasDetectR bağımlılık tablosu + DIF motoru çekirdeği (motor UI'dan bağımsız yazılır, birim testli) |
| 6–8 | BiasDetectR Live tamamla + Pages; (C1 ise) diriltme adayını audit'ten seç + taşı |
| 9–10 | Eşdeğerlik + benchmark matrisi + uçak modu çekimleri |
| 11–12 | Probe verisi ara analiz + audit elle sınıflama + sağkalım figürü |
| 13–18 | Quarto taslak (probe penceresi kapanınca audit sayıları güncellenir) |
| 19–20 | İç okuma; Zenodo/OSF/SWH arşivleri; temiz makine testi; kapak mektubu; gönderim |

---

## 11. Riskler ve kararlar defteri

| Risk / Karar | Önlem |
|---|---|
| webR/shinylive hızla evriliyor; binary drift | assets_version pinleme + **export bundle'ı arşivle** + versions.txt |
| shinyapps uyku sayfası HTTP 200 | zorunlu elle doğrulama + soft-fail metin taraması + tekrarlı probing |
| "Shinylive stabil değil" algısı (PLOS CompBio 2025) | 30 MB senaryolu benchmark ile veriyle yanıt |
| Paket webR'da yok çıkarsa | repo indexi önden kontrol; base-R alternatifi; karar tablosuna işle (içerik olur) |
| Paralel yayın | Niş bugün itibarıyla boş (tarama kanıtlı); hız + rolling koleksiyon |
| IRT-DIF yok eleştirisi | Karar rehberinde gerekçeli sınır (Riesthuis kalıbı) |
| Rescue arm yanıtları gecikir | "Gönderim anında sürüyor" olarak raporla / revizyonda güncelle |
| OA bütçesi | Kurum anlaşması erken kontrol |

---

## 12. Çekirdek kaynakça (tarama çıktısı — tam liste `tasks/wbqlcadd8.output`)

Link-rot: Klein 2014 PLOS ONE; Zittrain 2014 Harv.L.Rev.; Hennessey & Ge 2013; Pew 2024; Sadatmoosavi 2026 AJIM. Araç denetimleri: Thireou 2007 → Veretnik 2008 → Schultheiss 2011 → Wren 2017 → Ősz 2019 → **Kern 2020 NAR (şablon)**; Mangul 2019; Escamilla 2022/2024; Trisovic 2022. BRM içi: **Ellis 2024**; **Manolov 2026**. Shiny: Kasprzak 2021 R Journal; Saia 2022; Schultheiss 2011 ten-rules. Sürdürülebilirlik: Coelho 2024; FAIR4RS (Barker 2022); Carver 2022; Jensen & Katz 2025; Hettrick 2014. Wasm: Perkel 2024 Nature; DataMap 2025; Wasm-iCARE 2024; JINet 2025; **Brun 2025 PLOS CompBio (çürütülecek)**. Yapı emsalleri: Rubo 2025; Riesthuis 2025; Efthimiou & Crompton 2025. Arşiv: Di Cosmo 2017 (SWH); Akhlaghi 2020.

---

## 13. Çalışma notları

- Kod ve commit mesajları İngilizce; plan ve iç notlar Türkçe.
- `site/` elle düzenlenmez — her zaman `shinylive::export()` çıktısı; kaynak `apps/` altında.
- Her tamamlanan görev bu dosyada işaretlenir.
