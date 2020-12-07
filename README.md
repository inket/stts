## stts ![](https://img.shields.io/badge/Swift-5-orange.svg)

stts is a macOS app for monitoring the status of cloud services.

<img src="https://i.imgur.com/OAK3hR0.png" width="218" height="324" />

With a click of the menubar icon, you can see the status of your favorite services. You can also be notified when a service goes down or gets restored.

stts is designed to be unobtrusive, only giving you the information you need and allowing you to access the status page with a single click.

stts can be downloaded from the Mac App Store [here](https://itunes.apple.com/app/stts/id1187772509?l=en&mt=12).

### Contributing

Adding services is quite straightforward, and can be as easy as adding a few lines (especially if they're based on statuspage.io). For examples, check `stts/Services/` and `stts/Services/StatusPage`.

#### StatusPage

If you're adding a page which is based off https://statuspage.io, then you will subclass `StatusPageService`. To find `statusPageID` for a new service, go to `https://status.<company>.com/api` and [view the links](https://github.com/inket/stts/issues/21#issuecomment-273427769).

#### Contact

[@inket](https://github.com/inket) / [@inket](https://twitter.com/inket) on Twitter / [mahdi.jp](https://mahdi.jp)
