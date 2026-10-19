// Lets the app install and open offline: see https://github.com/petravanta/general/blob/main/STANDARDS.md#installing-on-a-phone
self.APP_SHELL = ["./", "manifest.webmanifest", "shared/theme.css", "icons/icon-192.png", "icons/icon.svg"];
importScripts('https://petravanta.github.io/general/shared/app-sw.js');
