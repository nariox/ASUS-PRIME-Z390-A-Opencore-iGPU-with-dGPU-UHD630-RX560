# ASUS-PRIME-Z390-A-HACKINTOSH-OpenCore-iGPU-with-dGPU-UHD630-RX560


## Components
- M/B: ASUS PRIME Z390-A(BIOS Ver. 1005)
- CPU: Intel® Core™ i5-9400 Processor
- iGPU: Intel® UHD Graphics 630
- dGPU: AMD Radeon RX 560 4GB
- Lan: Intel® I219V, 1 x Gigabit LAN Controller
- WiFi/Bluetooth: BCM94360CS2
- Audio: Realtek® ALC S1220A 8-Channel High Definition Audio

## Comments
This Hackintosh build guide is NOT GUARANTEED 100% fully working in your conditions. This guide has been tested on MacOS Mojave 10.14.4-6 and 10.15.0-3 on an AMD dGPU.

As far as I have been able to test, everything works well except Thunderbolt devices stop working after sleep (but work on boot, tested with Thunderbolt Display and TB3->TB1 adapter).

Some ports in the back were disabled to keep ports within the 15 port limit.

Special Thanks to dhckdgjs (initial repository owner), CaseySJ(at tonymacx86.com) and Newlife(at x86.co.kr).

## Not tested
- FileVault.

## Not working
- Sleep can be buggy sometimes
- After sleep, Thunderbolt USB devices stop working(?)
-- Tested on Thunderbolt display: after sleep peripherals stop working (camera, audio, microphone, usb ports), but display itself still works (you can fix it by unplugging the thunderbolt display from the outlet and waiting a few seconds before replugging it, I think this forces MacOS to repopulate those devices).

## Procedure
1. Edit config.plist to have your own SmUUID and Serial Number
2. Copy to your EFI folder
3. Install MacOS 10.14.6
4. Done?

## Misc

If you need other detailed settings fot this ASUS PRIME Z390-A M/B, please check release file.(like as USBport)
Thanks.

## Screenshots


![Sys info_PCI](https://user-images.githubusercontent.com/35429874/61994177-59df8980-b0b2-11e9-857f-47d757fa7a0f.png)
![Sys info_USB](https://user-images.githubusercontent.com/35429874/61994187-6c59c300-b0b2-11e9-896a-8a3ac4609117.png)
![Sys info_Audio](https://user-images.githubusercontent.com/35429874/61994188-711e7700-b0b2-11e9-908f-1ffd44d945a8.png)
![Sys info_Bluetooth](https://user-images.githubusercontent.com/35429874/61994190-71b70d80-b0b2-11e9-8f2a-18757d28cd83.png)
![Sys info_Network](https://user-images.githubusercontent.com/35429874/61994191-71b70d80-b0b2-11e9-888d-b25cac1842a8.png)
![PRIME Z390-A - USB port map final](https://user-images.githubusercontent.com/35429874/61994465-821cb780-b0b5-11e9-9d00-b12ed9046afc.jpg)
