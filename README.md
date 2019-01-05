# DMD 5620 Emulator for the Macintosh

The AT&T / Teletype DMD 5620 terminal was a portrait display, programmable
windowing terminal produced in 1984. It came out of earlier research pioneered
by Rob Pike and Bart Locanthi Jr., of AT&T Bell Labs.

Several iterations of terminals based on Pike and Locanthi's work were produced.
The prototypes and early models were based around a Motorola 68000 CPU, and are
better known as *jerq* or *Blit* terminals. The commercialized version produced
jointly by the Teletype Corporation and AT&T in 1984 was called the **DMD 5620**,
and used a Western Electric WE32100 CPU.

The goal of this project is to provide a highly accurate emulation of the
DMD 5620 terminal.

[![Download from the Mac App Store](https://static.loomcom.com/3b2/5620/mac_app_store_badge.png)](https://geo.itunes.apple.com/us/app/dmd-5620/id1448142273?mt=12&app=apps)

## ChangeLog

### 1.5.0

* Added a new visual effect: You can optionally enable simulation of phosphor
  permanence on the screen. This makes the terminal much more realistic
  looking, at the expense of using more CPU to render the images.

### 1.4.1

* Fixed a bug that caused the app to crash when custom colors 
  were set using non-RGB colorspace.

### 1.4.0

* Added clipboard paste functionality, accessible from the
  "Edit" menu, or from the keyboard shortcut Command-V.

### 1.3.0

* Fixed a bug that prevented terminal settings from being saved on quit.
* Added a "Reset" menu item.

### 1.2.0

* Upgraded to `dmd_core` 0.6.3 to fix video RAM and DUART bugs.
* Fixed a timing bug in downloading programs to the terminal
  using `32ld` on 3B2 hosts.

## License

Copyright 2018, Seth J. Morabito \<web@loomcom.com>

Licensed under the MIT license.

## Additional Copyright

This project uses the `CocoaAsyncSocket` library
(https://github.com/robbiehanson/CocoaAsyncSocket).
`CocoaAsyncSocket` is copyright 2017, Duesty LLC and provided through
a BSD license.
