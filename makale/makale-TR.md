# Sunucusuz psikometri: webR ve Shinylive ile gizlilik-korumalı ve sürdürülebilir web uygulamaları geliştirme

**Makale türü:** Tutorial (Behavior Research Methods, Tutorial Koleksiyonu)
**Taslak:** v0.1, 29.07.2026 — tam çalışma taslağı; gönderimden önce tamamlanacak kalemler **[YAPILACAK]** ile işaretlidir.
**Not:** Dergiye gönderilecek metin İngilizce versiyondur (`manuscript-EN.md`); bu Türkçe metin birebir okuma kopyasıdır.

---

## Özet

Etkileşimli Shiny uygulamaları, davranış bilimlerinde yöntem yeniliklerini yaymanın standart aracı hâline geldi; ancak dayandıkları sunucu mimarisinin üç yapısal zayıflığı var: barındırma sona erdiğinde uygulamalar ortadan kayboluyor, kullanıcılar çoğu zaman hassas olan verilerini üçüncü taraf sunuculara yüklemek zorunda kalıyor ve sunucunun bedelini süresiz olarak birilerinin ödemesi ve bakımını yapması gerekiyor. Bu öğretici, geniş bir psikometrik uygulama sınıfı için sunucunun tamamen kaldırılabileceğini gösteriyor. Tarayıcının içinde çalışan bir WebAssembly R derlemesi olan webR ile Shinylive dışa aktarma sistemi kullanıldığında, sıradan tek dosyalık bir Shiny uygulaması, herhangi bir statik sunucunun (ör. GitHub Pages) süresiz ve ücretsiz barındırabileceği bir statik dosya klasörüne dönüşüyor; tüm hesaplama kullanıcının kendi cihazında yapılıyor ve veri tarayıcıdan hiç çıkmıyor. Dışa aktarma, yerel test, dağıtım, sürüm sabitleme ve arşivlemeyi kapsayan adım adım bir kılavuz sunuyor ve bunu iki tam işlevsel uygulamayla gösteriyoruz: OmegaLite (güvenirlik analizi; bootstrap güven aralıklı McDonald omega) ve BiasDetectR Live (Mantel–Haenszel ve lojistik regresyonla değişen madde fonksiyonu, DIF). Her iki uygulama da yalnızca base R'a dayanıyor ve tarayıcı içi sonuçları native R ile makine hassasiyetinde örtüşüyor: DIF motoru difR paketini en fazla 2 × 10⁻¹⁵ mutlak farkla yeniden üretiyor; bootstrap güven aralıkları iki ortamda birebir aynı çıkıyor. Ölçümler, tarayıcının 50.000 katılımcı × 20 maddeyi 10 saniyenin altında — native R süresinin yaklaşık 1,2 katında — analiz ettiğini gösteriyor. Sunucu mimarisinin hangi durumlarda gerekli kalmaya devam ettiğine dair bir karar rehberi ve sürdürülebilir, gizlilik-korumalı dağıtım için bir kontrol listesiyle bitiriyoruz.

**Anahtar sözcükler:** Shiny; webR; WebAssembly; Shinylive; yeniden üretilebilirlik; açık bilim; değişen madde fonksiyonu; güvenirlik

---

## 1. Giriş

Son on yılda etkileşimli web uygulaması, davranış bilimleri metodolojisinin tercih ettiği yaygınlaştırma biçimlerinden biri oldu. Bir metodolog yeni bir güç analizi prosedürü, bir güvenirlik kestiricisi ya da bir DIF iş akışı geliştirdiğinde, makalenin yanında giderek daha sık bir Shiny uygulaması (Chang vd., 2024) yayımlanıyor; böylece okuyucular yöntemi kod yazmadan kullanabiliyor. Shiny'nin araştırmadaki yaygınlığı disiplinler arası belgelenmiş durumda (Kasprzak vd., 2021) ve *Behavior Research Methods* bu örüntünün en görünür olduğu dergilerden: yakın tarihli öğreticiler ve yöntem makaleleri okuyucuları düzenli olarak barındırılan uygulamalara yönlendiriyor — örneğin ROC analizleri için simülasyon tabanlı bir güç analizi uygulaması (Riesthuis vd., 2025) ya da shinyapps.io'da barındırılan en az altı tek-denekli-desen aracı (Manolov, 2026).

Bu yaygınlaştırma modelinin, yayın anında gözden kaçırılması kolay yapısal bir zayıflığı var: standart bir Shiny uygulaması bir *sunucu süreci*dir. R kodu okuyucunun makinesinde değil; aracı kullanmak isteyen biri olduğu sürece açık, fonlanmış ve bakımlı kalması gereken uzak bir bilgisayarda çalışır. Bu mimari üç ayrı sorun doğurur.

**Sorun 1: Araçlar ölür.** Bilimsel kayıttaki bağlantı çürümesi kapsamlı biçimde belgelenmiştir: web kaynaklarına atıf veren makalelerin kabaca beşte biri referans çürümesi yaşar (Klein vd., 2014); 2013'te var olan web sayfalarının %38'i on yıl sonra yok olmuştur (Pew Research Center, 2024); ve — burada en önemlisi — *dinamik, veritabanı-güdümlü içerik* statik sayfalardan çok daha hızlı çürür: yakın tarihli 20 yıllık bir analizde statik belgeler %92 oranında erişilebilir kalırken dinamik içerik yalnızca %41'de kalmıştır (Sadatmoosavi vd., 2026). Araştırma yazılımı özelinde biyoinformatik kendi web araçlarını defalarca denetlemiştir ve sonuçlar düşündürücüdür: on yılda yayımlanan 2.396 web aracından yalnızca %31'i tutarlı biçimde erişilebilirdi ve erişilebilirlik yeni araçlarda ~%90'dan on yıllık araçlarda ~%50'ye düşmekteydi (Kern vd., 2020; ayrıca bkz. Schultheiss vd., 2011; Wren vd., 2017; Ősz vd., 2019). Davranış bilimlerinde karşılaştırılabilir bir denetim yok; ancak bağışıklık beklemek için de bir neden yok: derginin kendi yeniden üretilebilirlik değerlendirmesi, politika aktif biçimde karşı koymadıkça araştırma ürünlerinin zamanla bozulduğunu bulmuştur (Ellis vd., 2024). Bu beklentilerle tutarlı olarak, bu öğreticiyi hazırlarken yaptığımız küçük bir erişilebilirlik yoklaması (Temmuz 2026; açık erişimli *Behavior Research Methods* makalelerinden, 2017–2025, çıkarılan 16 uygulama URL'si) yalnızca 4 URL'nin doğrudan yanıt verdiğini buldu; 10'u shinyapps.io'nun uykudaki ücretsiz katman uygulamasını gösteren "uyanma" ara sayfasını döndürdü, biri HTTP 404 verdi ve bir kurumsal Shiny sunucusu DNS'te artık yoktu. Ham yoklama verileri ekli depodadır. Önemli bir not: arşivlenmiş kaynak kodu, çalışan bir aracın işlevsel ikamesi değildir — büyük ölçekli bir yeniden çalıştırma çalışmasında yayımlanmış R betiklerinin %74'ü temiz bir ortamda çalışmadı (Trisovic vd., 2022); bizim iki ölü örnek uygulamamızdan birinin kaynak kodu da kamuya açık hiçbir yerde bulunamadı.

**Sorun 2: Veri yolculuk etmek zorunda.** Barındırılan bir uygulamada, kullanıcının analiz ettiği her veri seti başkasının bilgisayarına yüklenir. Birçok psikometrik kullanım için — klinik örneklemlerden madde yanıtları, okul kayıtları, personel seçme verileri — bu yalnızca bir rahatsızlık değildir; veri koruma kurallarını ya da etik protokolleri doğrudan ihlal edebilir. Hesaplamayı *kullanıcıya* taşımanın (verileri sunucuya taşımak yerine) gizlilik argümanı komşu alanlarda zaten yerleşiktir (Balasubramanian vd., 2024; Ge, 2025).

**Sorun 3: Birileri ödemek zorunda.** Barındırma, süreksiz fonlara yazılan sürekli bir maliyettir. Hibe önerileri bir web uygulamasını proje süresinin ötesinde yaşatmayı nadiren bütçeler (Saia vd., 2022; Coelho, 2024) ve akademide fiilî standart olan ücretsiz katmanlar bu uyumsuzluğa uygulamaları uyutarak, kısarak ve nihayet silerek yanıt verir.

### 1.1 Sunucusuz alternatif

Üç sorunun ortak tek nedeni — sunucu — olduğundan ortak tek çözümü de vardır: onu kaldırmak. Tüm modern tarayıcıların çalıştırdığı W3C standardı ikili format WebAssembly (Wasm), dil çalışma ortamlarının tamamının tarayıcı için derlenmesini mümkün kıldı; *Nature* bu gelişmeyi bilimsel hesaplama için sessizce dönüştürücü olarak ele aldı (Perkel, 2024). webR (Stagg vd., 2026) R'ın kendisinin Wasm derlemesidir; Shinylive bunun üzerine kurulur ve değiştirilmemiş bir Shiny uygulaması **sıfır sunucu hesaplamasıyla** çalışır: "uygulama", HTML, JavaScript, webR çalışma ortamı ve gereken R paketlerinden oluşan, herhangi bir statik dosya sunucusunun servis edebileceği bir klasöre dönüşür. İlk sayfa yüklemesinden sonra her hesaplama kullanıcının cihazında olur. Üç sorun aynı anda çözülür: ücretsiz bir sunucudaki statik dosyalar ihmalden ölmez; veri tarayıcıdan çıkmaz; sunucu faturası yoktur çünkü sunucu yoktur.

Bu yığını kullanan uygulama notları yaşam bilimlerinde görünmeye başladı (Ge, 2025) ve genel bir Shiny yeniden üretilebilirlik rehberi Shinylive'ı umut verici ama — yazarların 2024 dönemi testlerinde — "yeterince stabil ve hızlı değil" bir seçenek olarak anıyor (Brun vd., 2025). Bildiğimiz kadarıyla psikoloji ya da davranış bilimlerinde yöntem odaklı bir öğretici yok ve stabilite endişesi güncel sürümlerle yeniden sınanmayı hak ediyor. Bu öğretici iki boşluğu da dolduruyor. (a) Tarayıcı içi R'ın nasıl çalıştığını bir metodoloğun ihtiyaç duyduğu ayrıntı düzeyinde açıklıyoruz; (b) `app.R`'dan kalıcı, atıf verilebilir bir dağıtıma giden eksiksiz, test edilmiş bir iş akışı sunuyoruz; (c) bunu iki tam işlevsel psikometrik uygulamayla gösteriyoruz — bir güvenirlik aracı ve bir DIF aracı — ve tarayıcı içi sonuçlarını yerleşik native-R paketleri `psych` (Revelle, 2025) ve `difR` (Magis vd., 2010) ile makine hassasiyetinde doğruluyoruz; (d) 50.000 katılımcıya kadar ölçümlerle native'e yakın hız raporluyoruz ve "yeterince hızlı değil" itirazını doğrudan yanıtlıyoruz. Sunucusuz mimari evrensel olmadığı için bir karar rehberiyle bitiriyoruz: hangi uygulama sınıflarının hâlâ sunucuya ihtiyaç duyduğunu açıkça belirtiyoruz.

Her iki örnek uygulama şu anda canlıdır ve öyle kalacaktır:

- **OmegaLite** — https://cahitgs.github.io/serverless-psychometrics/omegalite/
- **BiasDetectR Live** — https://cahitgs.github.io/serverless-psychometrics/biasdetectr-live/

Kaynak kod, ölçüm verileri ve tüm analiz betikleri: https://github.com/cahitgs/serverless-psychometrics **[YAPILACAK: gönderimde Zenodo concept DOI eklenecek]**.

---

## 2. Bir R uygulaması sunucusuz nasıl çalışır?

Geleneksel bir Shiny dağıtımı uygulamayı ikiye böler: tarayıcı arayüzü çizer, uzak bir sunucu R kodunu çalıştırır ve sürekli bir WebSocket bağlantısı her kaydırıcı hareketini ve her sonucu ikisi arasında taşır (Şekil 1, sol). Shinylive bu mimariyi tarayıcının içine katlar (Şekil 1, sağ). C ve Fortran kaynaklarından WebAssembly'ye derlenen R yorumlayıcısının kendisi sayfanın parçası olarak bir kez indirilir, sonra bir web worker — R hesaplarken arayüzü yanıt verir tutan bir arka plan iş parçacığı — içinde başlatılır. Shiny'nin reaktif motoru bu tarayıcı içi R üzerinde değişmeden çalışır; bir service worker, Shiny'nin normalde sunucuya göndereceği HTTP isteklerini yakalayıp tarayıcı içi oturuma yönlendirir. `app.R`'ınızın bakış açısından hiçbir şey değişmemiştir: `fileInput()` dosya alır (diskten tarayıcının sanal dosya sistemine yerel olarak okunur), `renderPlot()` grafik çizer, `downloadHandler()` indirme üretir.

**[Şekil 1 buraya — mimari şema: sunuculu vs sunucusuz. YAPILACAK: çizilecek]**

Bu tasarımın araştırma uygulamaları için önemli üç özelliği:

1. **Dışa aktarım kendi kendine yeterlidir.** `shinylive::export()`, webR çalışma ortamını, Shinylive varlıklarını ve uygulamanızın kullandığı her R paketinin Wasm ikilisini tek klasöre kopyalar. Ölçtüğümüz dışa aktarımlar base-R bir uygulama için 189 dosya / 68,4 MB'dir. Çalışma anında hiçbir içerik dağıtım ağından (CDN) bir şey çekilmez — klasörün arşivlenmiş bir kopyasını onyıllar sonra da çalıştırılabilir kılan budur.

2. **Hesaplama, doğrulanabilir biçimde kullanıcının cihazında olur.** Sayfanın uygulama sunucusuna ihtiyacı olmadığından, tarayıcının geliştirici araçlarındaki Ağ sekmesi doğrudan bir gizlilik denetimi sağlar: uygulama yüklendikten sonra, yüklenen bir veri setini analiz etmek *sıfır* giden ağ isteği üretir. Bunu her iki örnek uygulama için araçsal olarak doğruladık (Bölüm 6.3).

3. **Sürümler donmuştur.** Dışa aktarılan paket, R'ın (bizim aktarımlarımızda 4.6.0), webR'ın (0.6.0) ve her paketin belirli sürümlerini içerir. Paket, yeniden üretilebilirlik artefaktının kendisidir: onu arşivlerseniz hesaplama ortamının tamamı korunur (krş. FAIR4RS ilkeleri; Barker vd., 2022).

Çalışma ortamı 32-bit WebAssembly'dir; bu, R'ın belleğini 4 GB ile sınırlar (tarayıcılar, özellikle mobil olanlar, daha azını verebilir). Tipik psikometrik veri setleri — binlerle onbinler arası katılımcı — için bu pratik bir kısıt değildir; ölçümlerimiz bunu göstermektedir.

---

## 3. Adım adım kılavuz: app.R'dan kalıcı uygulamaya

Bu bölüm eksiksiz, yeniden üretilebilir bir uygulamalı anlatımdır. Her komut yazıldığı gibi, Windows 11'de R 4.4.1, shinylive 0.5.0 (Shinylive web varlıkları 0.10.12; webR 0.6.0 / R 4.6.0 içerir) ile çalıştırılmıştır. Sürüm ayrıntıları depodaki `paper/versions.txt` dosyasındadır.

### 3.1 Uygulamayı her zamanki gibi yazın — tek tasarım kuralıyla

Bir Shinylive uygulaması sıradan bir Shiny uygulamasıdır. En belirleyici tasarım kararı bağımlılık ayak izidir. `library()` ile çağırdığınız her paketin WebAssembly ikilisi olmalıdır; webR deposu şu anda CRAN'in büyük çoğunluğunu derliyor (yazım anında 22.741 paket; `psych`, `lavaan`, `mirt` ve `ggplot2` dahil), dolayısıyla erişilebilirlik 2023–2024'teki kadar engel değil. Ama her bağımlılık, kullanıcının tarayıcısının ilk açılışta indirmesi gereken miktarı da şişirir. Her iki örnek uygulamamızın da izlediği önerimiz salt erişilebilirlikten daha katıdır: **istatistiksel çekirdekler için base R'ı tercih edin.** Base R, webR çalışma ortamının içinde ek indirme maliyeti olmadan gelir ve — Bölüm 4–6'nın gösterdiği gibi — klasik psikometri (güvenirlik katsayıları, Mantel–Haenszel, lojistik regresyon DIF) daha fazlasına ihtiyaç duymaz. Katkı paketi gerektiğinde, kod yazmadan önce `repo.r-wasm.org` paket dizininden erişilebilirliği kontrol edin.

Her Shinylive uygulamasına girmesi gereken iki küçük uyumluluk ayarı:

```r
# 1. Yükleme sınırını (varsayılan 5 MB) gerçekçi yanıt matrisleri için artırın
options(shiny.maxRequestSize = 100 * 1024^2)

# 2. Chromium hata kaydı 468227: Shinylive içinde dosya indirme, download
#    özniteliği kaldırılmazsa Chrome'da çalışmaz; başka yerde zararsızdır
download_btn <- downloadButton("download", "Download results (CSV)")
download_btn$attribs$download <- NULL
```

### 3.2 Dışa aktarın

```r
install.packages("shinylive")
shinylive::export(appdir = "apps/omegalite", destdir = "site/omegalite")
```

İlk dışa aktarım Shinylive varlıklarını indirir (bizim bağlantımızda yaklaşık 90 saniye); sonrakiler önbelleği kullanır ve saniyeler içinde biter (ölçülen: ilk 88,1 sn; sonraki 3,1 sn). Çok dosyalı uygulamalar çalışır: uygulama klasöründeki yardımcı dosyalar (ör. bizim `dif_engine.R`) otomatik paketlenir.

### 3.3 Yerelde test edin — HTTP üzerinden, asla file:// ile değil

```r
httpuv::runStaticServer("site/omegalite")
```

`index.html`'i doğrudan diskten açmak çalışmaz: WebAssembly ve service worker'lar bir HTTP origin'i gerektirir. Bu, en yaygın acemi hatasıdır. (Testlerimizden küçük bir gözlem: `httpuv` dahil bazı geliştirme sunucuları `.wasm` dosyalarını genel bir MIME türüyle servis eder; bu, akışlı derlemeyi devre dışı bırakıp ilk yüklemeyi biraz yavaşlatır; GitHub Pages gibi üretim sunucuları doğru türü gönderir.)

### 3.4 GitHub Pages'e dağıtın

Dışa aktarılan klasörü public bir GitHub deposuna commit'leyin ve standart bir `deploy-pages` workflow'u ekleyin (30 satırlık YAML dosyasının tamamı depomuzda: `.github/workflows/pages.yml`). Dağıtımımızdan iki pratik not: (a) workflow token'ı bir depoda Pages'i *ilk kez* etkinleştiremez — bir kereliğine `gh api -X POST repos/SAHIP/DEPO/pages -f build_type=workflow` çalıştırın ya da depo ayarlarındaki eşdeğer düğmeye tıklayın; (b) GitHub Pages özel HTTP başlıkları gönderemez, bu yüzden webR en hızlı iletişim kanalından (SharedArrayBuffer) otomatik olarak PostMessage'a düşer — her şey çalışır; tek sınırlama, süren bir hesaplamanın ortasında kesilememesidir.

Dağıtılmış OmegaLite'ın ev interneti üzerinden ölçülen soğuk yüklemesi: tamamen etkileşimli uygulamaya 16,4 sn (yerel sunucudan 7,2–10,7 sn). Sonraki açılışlar, tarayıcı çalışma ortamını önbelleklediği için daha hızlıdır.

### 3.5 Sürümleri sabitleyin ve paketi arşivleyin

Shinylive varlık sürümü açıkça sabitlenebilir (`shinylive::export(..., assets_version = "0.10.12")` ya da `SHINYLIVE_ASSETS_VERSION` ortam değişkeni). Paketteki wasm ikilileri dışa aktarma anındaki webR deposunu izlediğinden, bir uygulamayı sonradan *yeniden derlemek* sessizce farklı paket sürümleri üretebilir. Yeniden üretilebilirlik kuralı bu yüzden şudur: **yalnızca kaynağı değil, dışa aktarılmış paketin kendisini arşivleyin.** TOP Düzey 2'nin güvenilir-depo şartını karşılayan önerdiğimiz iki-artefaktlı arşiv:

1. Bir GitHub release'i etiketleyin; Zenodo–GitHub entegrasyonu kaynağı arşivler ve DOI üretir.
2. Dışa aktarılmış `site/` klasörünü zip olarak aynı Zenodo kaydına yükleyin.

Gelecekte herhangi biri, herhangi bir zamanda zip'i indirir, açar ve `httpuv::runStaticServer("site/omegalite")` çalıştırır — tek komut; Shiny sunucusu yok, indirme dışında internet bağımlılığı yok. İsteğe bağlı olarak, ISO-standardı kimlikli üçüncü bir kaynak-düzeyi koruma katmanı için Software Heritage'ın "Save Code Now" hizmetini tetikleyin (Di Cosmo & Zacchiroli, 2017).

### 3.6 Sık tuzaklar (hepsiyle bu projede karşılaşıldı ve çözüldü)

| Tuzak | Belirti | Çözüm |
|---|---|---|
| `file://` ile açmak | Boş sayfa / service-worker hatası | HTTP üzerinden servis edin (§3.3) |
| Chrome indirmeleri | İndirme düğmesi tepki vermiyor | `download` özniteliğini kaldırın (§3.1) |
| Yükleme sınırı | "Maximum upload size exceeded" | `shiny.maxRequestSize` artırın (§3.1) |
| İlk Pages dağıtımı düşer | `configure-pages` hatası | Bir kerelik Pages etkinleştirme (§3.4) |
| Paket webR'da yok | Aktarım ya da çalışma hatası | `repo.r-wasm.org`'u kontrol edin; base R'ı yeğleyin |
| Yeniden derlenen paket farklı | Paket sürümleri kayar | Dışa aktarılan paketi arşivleyin (§3.5) |
| Uzun hesaplamalar | R çalışırken arayüz tepkisiz | İlerleme gösterin (`withProgress`); modelleri ölçülü tutun; PostMessage altında kesme yok |

---

## 4. Örnek 1: OmegaLite — tarayıcıda güvenirlik analizi

OmegaLite (Şekil 2) bilerek minimaldir — yaklaşık 140 satır, yalnızca base R + shiny koduyla eksiksiz ve kullanışlı bir psikometrik araç; bir şablon olarak okunmak üzere tasarlanmıştır. Kullanıcı bir CSV yükler, madde sütunlarını seçer ve ana metrik olarak — alpha yerine omegayı yeğleme önerisine uyarak (McNeish, 2018) — bootstrap güven aralıklı McDonald omega-toplamı alır; yanında kıyas için Cronbach alpha, düzeltilmiş madde-toplam korelasyonları ve silinirse-alpha/omega tabloları vardır; hepsi CSV olarak indirilebilir.

**[Şekil 2 buraya — OmegaLite ekran görüntüsü: figures/omegalite-e2e-test.png]**

İstatistiksel çekirdek tek paragrafa sığar. Omega-toplam, `stats::factanal()` ile elde edilen tek faktörlü en çok olabilirlik çözümünden hesaplanır: standartlaştırılmış yükler λ ile ω_t = (Σλ)² / [(Σλ)² + Σ(1 − λ²)] (McDonald, 1999). Alpha kovaryans matrisinden hesaplanır. Güven aralıkları parametrik olmayan bootstrap kullanır (yüzdelik yöntemi, sabit tohum). Hiçbir katkı paketi işin içinde değildir — uygulamanın webR'da birebir aynı davranmasının garantisi tam da budur.

**Doğrulama.** Simüle tek faktörlü bir veri setinde (N = 500, 8 madde) OmegaLite'ın base-R uygulamaları `psych` paketiyle (v2.5.6) uyuşur: alpha, `psych::alpha`'nın ham alphasıyla birebir aynıdır (fark 0); düzeltilmiş madde-toplam korelasyonları ve silinirse-alpha makine hassasiyetinde eşittir (≤ 1,1 × 10⁻¹⁶); omega, `psych::omega`'nın tek faktörlü ω_t'sinden 1,0 × 10⁻⁴ farklıdır — fark tarayıcıdan değil, iki işlevin farklı ML optimizasyon rutinleri kullanmasından kaynaklanır. En önemlisi, *aynı veriyi* dağıtılmış tarayıcı uygulamasında çalıştırmak, native-R sonuçlarını bootstrap güven aralıkları dahil rapor hassasiyetinde basamağı basamağına yeniden üretir; çünkü webR aynı R'dır (4.6.0), aynı rastgele sayı üreteciyle: iki ortamda da ω_t = .868 [.851, .886], α = .865 [.846, .884].

---

## 5. Örnek 2: BiasDetectR Live — tarayıcıda DIF analizi

BiasDetectR Live (Şekil 3), bir demonun değil, araştırma düzeyinde bir analiz hattının tarayıcıya sığdığını gösterir. Uygulama, iki kategorili maddeler için en yaygın iki DIF prosedürünü, ikisini de saf base R ile uygular (`dif_engine.R`, 120 satır):

- **Mantel–Haenszel**, toplam puanla tabakalama (Holland & Thayer, 1988): ortak odds oranı α_MH, ETS delta metriği Δ_MH = −2,35 ln(α_MH), süreklilik düzeltmeli MH ki-karesi ve ETS A/B/C etki büyüklüğü sınıflaması (|Δ| < 1: A/önemsiz; 1–1,5: B/orta; ≥ 1,5: C/büyük).
- **Lojistik regresyon DIF** (Swaminathan & Rogers, 1990): üç iç içe model (toplam puan; + grup; + grup × puan), genel/uniform/non-uniform DIF için olabilirlik oranı testleri ve Jodoin ve Gierl (2001) eşikleriyle Nagelkerke ΔR² etki büyüklükleri.

Kullanıcı grup sütununu, odak grubu ve madde sütunlarını seçer; çıktı iki istatistik tablosu, ETS eşikleri referans çizgileriyle çizilmiş bir Δ_MH grafiği ve birleşik indirilebilir sonuç tablosudur. IRT tabanlı DIF yöntemleri (ör. Lord testi, IRT-LR) bilinçli olarak kapsam dışıdır: kestirim yükleri ve paket bağımlılıkları onları sunuculu dağıtıma daha uygun kılar — Bölüm 7'deki karar rehberinin somut bir örneği.

**[Şekil 3 buraya — BiasDetectR Live ekran görüntüsü: figures/biasdetectr-e2e-test.png]**

**difR ile doğrulama.** 20 maddelik, iki gruplu bir 2PL veri seti simüle ettik (N = 1.000; grup başına 500; impact yok) ve üç maddeye DIF ektik: madde 3'te odak grup aleyhine uniform DIF (+0,6 logit güçlük), madde 12'de odak grup lehine uniform DIF (−0,5) ve madde 7'de non-uniform DIF (ayırt edicilik × 0,4; güçlük +0,3). Motorumuz `difR` v6.1.0 ile (`difMH`, `difLogistic`, eş ayarlar, arındırma yok) 20 maddenin tamamında karşılaştırıldığında en büyük mutlak farklar şunlardı: α_MH, 0; MH ki-karesi, 1,8 × 10⁻¹⁵; Δ_MH, 0; lojistik LR istatistiği, 0; ΔR², 2,8 × 10⁻¹⁶ — baştan sona makine hassasiyeti ve ETS sınıflarında %100 uyum (tam tablo: `benchmark/equivalence_engine_vs_difR.csv`). Motor tam olarak ekilen üç maddeyi işaretler — 3 ve 12'yi doğru işaretli deltalarla Mantel–Haenszel, 7'yi non-uniform lojistik test (p = 3,1 × 10⁻⁷) — ve dağıtılmış tarayıcı uygulaması bu işaretlemeyi test edilen her örneklem büyüklüğünde yeniden üretir.

---

## 6. Eşdeğerlik, performans ve gizlilik denetimi

### 6.1 İstatistiksel eşdeğerlik

webR, R'ın *ta kendisi* olduğundan — aynı kaynak kodun farklı bir işlemci hedefi için derlenmişi — istatistiksel eşdeğerlik bir umut değil, mimari bir özelliktir. Yukarıdaki doğrulamalar bunu iki düzeyde ampirik olarak destekler: base-R motorlarımız ile yerleşik native paketler (`psych`, `difR`) arasında ve aynı kodun native ile tarayıcı içi çalıştırılması arasında; sabit tohumla stokastik prosedürler (bootstrap GA'ları) bile birebir tekrar eder. Yazarlara, eşdeğerliği bir iddia cümlesi olarak değil — bizim yaptığımız gibi — en-büyük-mutlak-fark tablosu olarak raporlamalarını öneriyoruz.

### 6.2 Hız

Tablo 1, tam BiasDetectR hattının (Mantel–Haenszel + madde başına üç lojistik model, 20 madde) analiz sürelerini, native R (4.4.1, Windows dizüstü) ile aynı makinede başsız Chrome'daki dağıtılmış uygulamayı karşılaştırarak verir.

**Tablo 1. Analiz süresi, native R ve tarayıcı (saniye).**

| Katılımcı | Native R | Tarayıcı | Oran |
|---:|---:|---:|---:|
| 1.000 | 0,28 | 1,0 | 3,6× |
| 5.000 | 0,91 | 1,5 | 1,6× |
| 50.000 | 7,78 | 9,5 | 1,2× |

Küçük N'de tarayıcının sabit reaktif ek yükü baskındır; gerçekçi-büyük N'de ceza kabaca %20'ye düşer. Bir dizüstü tarayıcısında 50.000 × 20'lik DIF analizinin on saniyenin altında bitmesi, en azından bu yöntem sınıfı için, "gerçek veri için yeterince hızlı değil" itirazını (Brun vd., 2025) emekliye ayırmalıdır; OmegaLite'ın bootstrap'i (2 × 200 faktör analizi tekrarı, N = 500) tarayıcıda 1,5–1,6 sn'de biter. Asıl maliyet uygulamanın açılışıdır: yerel sunucudan 7–11 sn, açık internetten ölçülen soğuk yükleme 16,4 sn; bu sırada ~68 MB çalışma ortamı ve varlık indirilir (sonrasında önbelleklenir). **[YAPILACAK gönderimden önce: zamanlama matrisini orta segment bir telefonda ve Firefox/Edge'de tekrarla; hücre başına 3 tekrar, medyan raporla.]**

### 6.3 Herkesin tekrarlayabileceği gizlilik denetimi

Dağıtılmış her iki uygulamayı kullanırken her ağ isteğini kaydeden başsız bir tarayıcı kurduk: sayfayı yükle, veri seti yükle, tam analizi çalıştır, sonuçları indir. OmegaLite'ta yükleme ile sonuçlar arasındaki ağ isteği sayısı **sıfırdı** ve iki uygulamanın oturumlarının hiçbir anında sayfanın kendi origin'i dışında hiçbir host ile iletişim kurulmadı — CDN yok, telemetri yok, üçüncü taraf yok. (BiasDetectR'da analiz adımı birkaç aynı-origin istek üretir — bunlar Shiny'nin grafik görüntüleridir; service worker tarafından *sayfanın içinde* üretilip servis edilir, hiçbir ağı geçmezler.) Okuyucular bu denetimi herhangi bir tarayıcıda tekrarlayabilir: geliştirici araçları → Ağ'ı açın, uygulamayı yükleyin, sonra veri yükleyip analiz edin — istek günlüğü boş kalır. Hassas veriyle çalışan tarayıcı tabanlı araçlar için bu tek-ekran-görüntülük denetimi standart bir şeffaflık pratiği olarak öneriyoruz. Uçak modu çeşitlemesi — uygulamayı yükle, bağlantıyı kes, analiz et — aynı özelliği fiziksel olarak gösterir; bunun *analiz-anı* bağımsızlığını belgelediğini, uygulamanın önbelleğe alınmış olmasını gerektiren çevrimdışı-açılışı belgelemediğini not edin. **[YAPILACAK: şekil için uçak modu ekran görüntüsü serisi.]**

### 6.4 Ne ölüyor, ne kurtuluyor: bir kurtarılabilirlik notu

Yoklamamızdaki iki ölü uygulama, Bölüm 3.5'in arşivleme argümanını örnekler. 404 döndüren uygulamanın kamuya açık kaynak kodunu bulamadık (GitHub araması, Temmuz 2026) — araç da kod da yok; Trisovic vd. (2022)'nin yaygın olacağını öngördüğü sonuç. Kurumsal sunucusu DNS'ten silinen uygulamanın kaynağı ise public bir GitHub deposundan *kurtarılabilir* — ama bir depo çalışan bir araç değildir; onu canlandırmak bir tıklama değil, bir projedir. İkisi de arşivlenmiş statik paket olarak dağıtılmış olsaydı, "canlandırma" bir klasörü servis etmekten ibaret olurdu.

---

## 7. Karar rehberi: sunucu ne zaman kalmalı?

Sunucusuz dağıtım, belirli — geniş — bir uygulama sınıfı için doğru varsayılandır: kullanıcının sağladığı, makul boyutlu veri üzerinde çalışan, kendi kendine yeterli istatistik araçları. Şunlar gerektiğinde yanlış seçimdir:

- **Sırlar.** Paketteki tüm kod ve veri her kullanıcıya görünürdür. API anahtarları, tescilli madde bankaları ya da puanlama anahtarları korunamaz.
- **Veritabanları ve kalıcılık.** Tarayıcı uygulamaları rastgele veritabanı bağlantıları açamaz ve sunucu tarafında hiçbir şey kalıcı olmaz; çok kullanıcılı durum, boylamsal veri toplama ve yönetim panelleri bir backend ister.
- **Ağır ya da uzun süren kestirim.** MCMC (Stan tabanlı modeller), büyük IRT kalibrasyonları ya da dakikalarla ölçülen her şey: 4 GB bellek tavanı, çok-süreçli paralelliğin yokluğu ve PostMessage kanalında süren kodun kesilemeyişi sunucudan yana konuşur.
- **Çok büyük veri.** Veri wasm32 bellek tavanına yaklaştıkça (pratikte 4 GB'ın epey altı, özellikle mobilde) sunucu gerekli hâle gelir.
- **Garantili hesaplama gücü.** Kullanıcının cihazındaki performans, kullanıcının cihazının performansıdır; 2015 model bir telefon yavaş olacaktır.

Tersinden: klasik test kuramı istatistikleri, DIF taraması, makul ölçekli güç analizi ve simülasyon, etki büyüklüğü hesaplayıcıları, grafik ve tanı araçları ve öğretim gösterimleri — özünde metodolojik eşlikçi uygulama türünün tamamı — tarayıcıya rahatça sığar.

---

## 8. Sınırlılıklar

İlk indirme, kendi kendine yeterliliğin bedelidir: base-R bir uygulama için ~68 MB (kullanıcı başına bir kez, sonra önbellek), ağır bağımlılıklarla daha fazla — ayak izini yalın tutun. wasm32 çalışma ortamı belleği 4 GB ile sınırlar; tarayıcıya ve cihaza göre azalır. Uzun hesaplamalar uygulamanın reaktivitesini bloke eder (tarayıcı sekmesini değil). Ekosistem hızlı ilerliyor — webR on sekiz ayda üç minör sürüm çıkardı — bu yüzden §3.5'teki gibi sabitleyip arşivleyin; bu makaleyi destekleyen sürümlenmiş artefaktlar bizim dışa aktarılmış paketlerimizdir. Açıklık yapısaldır: sunucusuz bir uygulama hiçbir şeyi gizli tutamaz — bu, yeniden üretilebilirlik için bir özellik, tescilli ölçme araçları için bir kısıttır. Son olarak, ölçümlerimiz bir dizüstü ve bir tarayıcı motorunu kapsıyor; telefon ve çapraz-tarayıcı matrisi beklemede **[YAPILACAK §6.2]**.

---

## 9. Sonuç ve öneriler

Metodolojik web uygulaması yayımlayan yazarlar için asgari bir sürdürülebilir-dağıtım kontrol listesi öneriyoruz:

1. İstatistiksel çekirdekler için base R'ı yeğleyin; bağımlılık eklemeden önce `repo.r-wasm.org`'a bakın.
2. Shinylive ile dışa aktarın; yerelde HTTP üzerinden test edin; statik bir sunucuya dağıtın.
3. Varlık sürümünü sabitleyin; **dışa aktarılmış paketi** DOI ile arşivleyin (Zenodo), kaynağın yanında (GitHub release + Software Heritage).
4. Makalede hem canlı URL'yi hem arşiv DOI'sini basın.
5. Kullanıcı verisinin yerelde kaldığını gösteren tek-ekran-görüntülük ağ denetimini ekleyin.
6. Aracın bilinçli olarak ne yapmadığını ve daha ağır kullanım için sunuculu bir varyantın olup olmadığını makalede belirtin.

Dergiler bu pratiği, gönderimde etkileşimli bir aracın on yıl sonra nerede yaşayacağını sorarak pekiştirebilir — veri erişilebilirliği beyanlarına benzer bir "bakım ve destek beyanı" (Coelho, 2024); statik, arşivlenmiş, sunucusuz bir dağıtım bu beyanı neredeyse kendiliğinden karşılar. Bu öğreticinin daha geniş mesajı şudur: davranış bilimleri metodolojisinin büyük bölümü için kalıcılık, gizlilik ve sıfır maliyet artık kurumsal altyapı gerektiren çelişen hedefler değildir — tek bir dışa aktarma komutudur.

---

## Açık Uygulamalar Beyanı

Tüm kaynak kod (iki uygulama, DIF motoru, simülasyon ve ölçüm betikleri, erişilebilirlik yoklama araçları), simüle veri setleri, ölçüm sonuçları, sürüm kayıtları ve bu el yazması https://github.com/cahitgs/serverless-psychometrics adresinde açıktır. **[YAPILACAK gönderimde: dışa aktarılmış uygulama paketlerini içeren sürümlenmiş arşiv için Zenodo concept DOI; ölçüm ham verisinin OSF'ye yatırılması.]** Canlı uygulamalar Bölüm 1.1'deki URL'lerdedir. İnsan katılımcı verisi kullanılmamıştır; tüm veri setleri simüledir. Bu öğretici ön-kayıtlı değildir.

## Beyanlar

- **Finansman:** [YAPILACAK]
- **Çıkar çatışması:** Yazarlar çıkar çatışması beyan etmemektedir.
- **Etik onay:** Uygulanamaz (insan katılımcı yok; yalnızca simüle veri).
- **Katılım / yayın onamı:** Uygulanamaz.
- **Veri ve materyal erişilebilirliği:** Açık Uygulamalar Beyanı'na bakınız.
- **Kod erişilebilirliği:** Açık Uygulamalar Beyanı'na bakınız.
- **Yazar katkıları:** [YAPILACAK]
- **Yapay zekâ kullanım beyanı:** Kodun ve el yazması taslağının bölümleri bir büyük dil modeli (Claude, Anthropic) desteğiyle üretilmiş; tüm analizler yazarlarca çalıştırılmış, doğrulanmış ve onaylanmıştır. [Gönderimde dergi politikasına göre düzenlenecek.]

## Kaynakça

İngilizce versiyondaki kaynakça ile birebir aynıdır (bkz. `manuscript-EN.md`); Türkçe kopyada yinelenmemiştir.
