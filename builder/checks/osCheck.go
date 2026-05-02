package checks

import (
	"bytes"
	"fmt"
	"os"
)

// OsCheck PENDING CONCURRENCY IMPLEMENTATION
func OsCheck() (passed bool, err error) {
	out, err := os.ReadFile("/etc/os-release")
	if err != nil {
		return false, fmt.Errorf("failed to read /etc/os-release: %v", err)
	}

	switch {
	case bytes.Contains(out, []byte("Noble Numbat")): // Ubuntu 24.04 LTS
		return true, nil
	case bytes.Contains(out, []byte("Trixie")): // Debian 13
		return true, nil
	case bytes.Contains(out, []byte("Bookworm")): // Debian 12
		return true, nil
	default:
		return false, fmt.Errorf("builder cannot run on this operating system") // Neither of the Above
	}
}
