# FritzBox CallMonitor Paket für Synology NAS
[English Version](README_E.md)

Dieses Paket monitort über die FritzBox laufende Telefonanrufe. 
Eine Liste der Anrufe ist über Webseiten verfügbar.
Zusätzlich kann optional der Begin und das Ende jeden Anrufs die Info an die [HomeMatic SmartHome-Zentrale CCU](https://homematic-ip.com/de/produkt/smart-home-zentrale-ccu3) übertragen werden. Dies kann z.B. zur optischen Anzeige von Anrufen genutzt werden. Es können verschiedene Adressbücher, z.B. die Kontakte aus der Synology via CardDAV geladen werden incl. automatischer Aktualisierung.
## [Lizenz](https://htmlpreview.github.io/?https://github.com/schmidhorst/synology-FritzBox-CallMonitor/blob/main/package/ui/licence_ger.html)

Beispiel-Anzeige:

![user view](https://github.com/schmidhorst/synology-FritzBox-CallMonitor/blob/main/ScreenshotAnrufListe.png?raw=true)  

Aus CardDav werden zur Nummer neben dem Namen auch die E-Mail und geg. eine Webseiten-URL extrahiert. Entsprechende Links werden zu in die Anruferliste eingeblendet und erleichtern die Kontaktaufnahme. Wenn ein Invers-Such-URL konfiguriert ist, kann auch so eine Suche per einfachem Klick ausgeführt werden. 

## Haftungsausschluss und Issue Tracker
Sie benutzen alles hier auf eigenes Risiko.
Für Probleme benutzen Sie bitte den [issue tracker](https://github.com/schmidhorst/synology-callmonitor/issues) mit deutscher oder englischer Sprache

# Installation
* Der Anrufmonitor der Fritzbox muss mittels Telefon (das an der Fritzbox angeschlossen ist), mit der Ziffernfolge #96\*5\* aktiviert werden. Dies funktionier mit einem Analog-Telefon, vermutlich auch DECT, möglicherweise aber nicht mit einem IP-Telefon.
* Laden Sie die *.spk-Datei von ["Releases"](https://github.com/schmidhorst/synology-callmonitor/releases), "Assets" auf Ihren Computer herunter und verwenden Sie "Manual Install" im Package Center. Während der Installation werden die notwendigen Einstellungen abgefragt.

## Danksagungen und Referenzen
- Dank an [eiGelbGeek](https://homematic-forum.de/forum/viewtopic.php?t=34876) für seinen CallMonitor.
- Dank an [toafez Tommes](https://github.com/toafez) und sein [Demo-Paket](https://github.com/toafez/DSM7DemoSPK)
- Dank an QTip und seine Erklärung zur [Integration einer Hilfe in DSM 5.1-](https://www.synology-wiki.de/index.php/Integration_einer_Hilfe_in_DSM_5.1-)

