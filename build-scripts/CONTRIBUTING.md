# Hi there! Welcome to LuminOS 😀👋

First, thanks so much for showing interest in what we do! We're a small, fast-moving crew building an OS that is stable, modern, that treats local, private AI as a core feature, without spying on you or slowing things down with telemetry or other annoying things. We're figuring things out, breaking things, and building something cool. Glad you're here!

## How we work

We don't really like heavy corporate red tape. If you want to contribute, here is the basic flow:

1. **Say Hi:** Drop into the `#about` channel on our [Discor Server](https://discord.gg/n3dtey36Ty). Tell us what you're good at (Go, Bash, Pytho, Linux configs, UI design, ...or just breaking things).
2. **Find a Task:** Check the GitHub Issues, that's how we mainly know what people are facing (on top of our discord server)
   * *Got your own idea?* Open an issue first so we can chat about it before you spend hours coding! :p
3. **Write Code:** Fork the repo, make a branch, and do your thing.
4. **Submit:** Send a Pull Request. Keep the description clear, tell us what you fixed or added, and **make sure the ISO still actually builds and boots** before you submit!

## What we need right now!! (But you're welcome even if you don't do any of that)

* **The ISO build-scripts (Go):** We are porting our bash build scripts into a concurrent Go application with a Bubble Tea TUI. If you write Go, this is priority #1.
* **The Interior (KDE & Rice):** We need perfect default configs for KDE Plasma (panel transparency, cursors, a space to integrate AI later, Web browser...).
* **The Installer (Calamares):** We need the Calamares installer configured so users can permanently install the Live ISO to their hard drives.
* **QA Testers:** Pull the repo, build the ISO, boot it, and try to crash it (it's quite easy to do so currently ngl). Open an issue with the logs when you do!
* **YOU:** We need you. As simple as that.

Hit up the core team on Discord if you get stuck or something. 
Happy code! ⭐
