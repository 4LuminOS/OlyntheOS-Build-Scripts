package main

import (
	"luminBuilder/buildSteps"
	"luminBuilder/checks"
	"os"
)

func main() {
	passed := checks.AllChecks()
	if passed != true {
		os.Exit(1)
	}

	// Build.
	buildsteps.FileSystemSetup()
}
