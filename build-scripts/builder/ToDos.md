# TO-DOs
-  [x] Checks to ensure the system is appropriate for building
        - [x] OS
        - [x] Network
        - [x] Privelage
        - [x] Storage
- [x] Create Directories for build 
- [] Install Dependencies - up for grabs (Will give an updated list, as some may have been eliminated with the new libraries chosen down below)
        We should just use the os.exec function, simplifies everything greatly

- [] Bootstrapping Debian - up for grabs
        [Debootstrap using os.exec](https://wiki.debian.org/Debootstrap): Any other way would be far more complicated than it should ever be
- [] Download or Find the AI Models - On it
        -> [Direct Official Link Finder!](https://github.com/amirrezaDev1378/ollama-model-direct-download/blob/master/documents/docs/Getting%20Direct%20Links.md)
                We can hard-code the URLs, but that might be bad if they ever change anything (although it should be unlikely)
        -> [VPS Download Alternative (Terrible but still an option!)](https://github.com/Pyenb/Ollama-models?tab=readme-ov-file#download-links-)
                I don't want to get crap off-of some rando's VPS, Its still and option if we want to maintain a list of models ourselves

- [] Mount directories and post-install scripts
        -> [Syscall library way](https://pkg.go.dev/golang.org/x/sys/unix#Mount):  I quite like this one, sounds fun to experiment with
        -> [os.exec library way](https://pkg.go.dev/os/exec): The easier way but far less fun and far less idiomatic

- [] Build ISO
        -> [os.exec library way](https://pkg.go.dev/os/exec): The easy way may not be the most concurrency friendly
        -> [External ISO builder Library](https://github.com/kdomanski/iso9660): Looks easy enough, concurrency friendly and has a bunch of capabilities

- [] Concurrent Implementation of all of the above
        Ideally we should implement all of the above linearly (no concurrency!) to make it easier to debug,
        because goroutines are hellish when attempting to debug (true facts), especially when core functionality itself hasn't been added
        Resources for Concurrency because, doing things is hard, doing it concurrently is even harder!
                -> [Concurrency Patterns](https://github.com/lotusirous/go-concurrency-patterns)
                -> [Sync Package Spec (we should really just read the source its way easier!)](https://pkg.go.dev/sync)
