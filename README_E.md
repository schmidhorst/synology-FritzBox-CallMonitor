# Synology-FritzBox-CallMonitor
[![de](https://flagcdn.com/w20/de.png)](https://github.com/schmidhorst/synology-FritzBox-CallMonitor/tree/main)

Phone Call Monitor including HomeMatic Interface
# FritzBox CallMonitor package for Synology NAS
It's monitoring phone calls via the FritzBox DSL and optical fiber modems including HomeMatic Interface.
The list of calls will be available via web pages.
Additionally, optional beginn and end of each call is send the the HomeMatic smart home station CCU. 

Example of an calls list:

![user view](https://github.com/schmidhorst/synology-FritzBox-CallMonitor/blob/main/ScreenshotAnrufListe.png?raw=true)  

More Info is available [here](https://html-preview.github.io/?url=https://github.com/schmidhorst/synology-FritzBox-CallMonitor/blob/main/package/ui/help/enu/index.html), in the files, which are available after the package installation in the Synology help.

## [License](https://htmlpreview.github.io/?https://github.com/schmidhorst/synology-callmonitor/blob/main/package/ui/licence_enu.html)

## Disclaimer and Issue Tracker
You are using everything here at your own risk.
For issues please use the [issue tracker](https://github.com/schmidhorst/synology-callmonitor/issues) with German or English language

## Installation
* You need to activate the monitor in the FritzBox with #96\*5\* on an analog phone, DECT- or ISDN phone, which is connected to the FritzBox.
* Download the *.spk file from ["Releases"](https://github.com/schmidhorst/synology-FritzBox-CallMonitor/releases/), "Assets" to your computer. And use "Manual Install" in the Package Center of the Synology. During the Installation you will be asked for the required settings.

## Build Package
* If you want to build the package yourself from the source: Download all files. Update the version number in INFO.sh after changes. Set the file build.sh to executable and run that script to generate the *.spk file. This works on your Synology NAS and also e.g. in the Windows Subsystem Linux WSL. The Synology package development toolkit is only needed after changes in the help pages.


## Credits and References
- Thanks to [eiGelbGeek] (https://homematic-forum.de/forum/viewtopic.php?t=34876)
- Thanks to [toafez Tommes](https://github.com/toafez) and his [Demo Package](https://github.com/toafez/DSM7DemoSPK)
- Thanks to QTip and his explanation about the help integration [Integration einer Hilfe in DSM 5.1-](https://www.synology-wiki.de/index.php/Integration_einer_Hilfe_in_DSM_5.1-)

