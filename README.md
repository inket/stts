## stts ![](https://img.shields.io/badge/Swift-5-orange.svg)

stts is a macOS app for monitoring the status of cloud services.

<img src="https://i.imgur.com/OAK3hR0.png" width="218" height="324" />

With a click of the menubar icon, you can see the status of your favorite services. You can also be notified when a service goes down or gets restored.

stts is designed to be unobtrusive, only giving you the information you need and allowing you to access the status page with a single click.

stts can be downloaded from the Mac App Store [here](https://itunes.apple.com/app/stts/id1187772509?l=en&mt=12).

### Support the project

<a href="https://www.buymeacoffee.com/mahdibchatnia" target="_blank"><img src="https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png" alt="Buy Me A Coffee" height="48" width="173" ></a>

### Contribute

Most services can be added automatically with the included extract script:

```sh
# If you haven't already, clone the repo
git clone https://github.com/inket/stts.git
cd stts

# Install dependencies and run the extract script
bundle install
bundle exec ruby extract.rb <url>

# Example:
bundle exec ruby extract.rb https://status.notion.so/
```

For services that cannot be added with the script, feel free to create a issue.

#### Contact

[@inket](https://github.com/inket) / [@inket](https://twitter.com/inket) on Twitter / [mahdi.jp](https://mahdi.jp)
