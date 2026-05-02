package checks

import (
	"fmt"
	"log"

	"golang.org/x/sys/unix"
)

const neededSpace = 30 // 30 Gigabytes

// StorageCheck PENDING CONCURRENCY IMPLEMENTATION
func StorageCheck() (passed bool, err error) {
	var stat unix.Statfs_t
	err = unix.Statfs("/", &stat)

	if err != nil {
		log.Fatal(err)
	}
	// Available blocks * size per block = available space in bytes; divide by 10^9 for GB
	availableSpaceGB := (stat.Bavail * uint64(stat.Bsize)) / 1_000_000_000

	switch {
	case availableSpaceGB >= neededSpace:
		return true, nil
	default:
		return false, fmt.Errorf("not enough storage space (needed: %v GB) (have: %v GB)", neededSpace, availableSpaceGB)
	}
}
