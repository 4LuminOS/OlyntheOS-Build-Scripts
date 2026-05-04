package buildsteps

import (
	"fmt"
	"log"
	"os"
	"path/filepath"
	"strings"
)

const BaseDirectory = "../LuminOS-build"

func FileSystemSetup() {
	_, err := os.Stat(BaseDirectory)
	fmt.Printf("Error at line 14: %v \n", err)

	// Check if the base directory exists. If it does, yoink it (safely).
	if !os.IsNotExist(err) {
		fmt.Println("WARNING: Base build directory already exists, it will be deleted.")
		fmt.Print("Proceed? [y/n] default:[n]: ")
		var proceed string
		_, _ = fmt.Scanln(&proceed)
		switch strings.ToLower(proceed) {
		case "y":
			err := os.RemoveAll(BaseDirectory)
			if err != nil {
				log.Fatalf("Failed to remove existent base directory: %v", err)
			}
		default:
			fmt.Println("Aborted.")
			os.Exit(0)
		}
	}
	err = os.Mkdir(BaseDirectory, 0750)
	if err != nil {
		log.Fatalf("Failed to created base directory: %v", err)
	}
	// Create build subdirectories.
	workDirectory := filepath.Join(BaseDirectory, "work")
	chrootDirectory := filepath.Join(BaseDirectory, "chroot")
	isoDirectory := filepath.Join(BaseDirectory, "iso")
	aiBuildDirectory := filepath.Join(BaseDirectory, "ai_build")

	if err := os.Mkdir(workDirectory, 0750); err != nil {
		log.Fatalf("Failed creating work directory: %v", err)
	}
	if err := os.Mkdir(chrootDirectory, 0750); err != nil {
		log.Fatalf("Failed creating chroot directory: %v", err)
	}
	if err := os.Mkdir(isoDirectory, 0750); err != nil {
		log.Fatalf("Failed creating ISO directory: %v", err)
	}
	if err := os.Mkdir(aiBuildDirectory, 0750); err != nil {
		log.Fatalf("Failed creating AI build directory: %v", err)
	}
}
