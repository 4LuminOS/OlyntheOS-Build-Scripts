package checks

import (
	"log"
	"syscall"
)

// PrivilegeCheck checks the UID if the user running isn't root it returns a fatal error!
// should be checked before everything for efficiency
//
// PENDING CONCURRENCY IMPLEMENTATION
func PrivilegeCheck() (passed bool) {
	if syscall.Getuid() != 0 { // 0 is the root User ID
		log.Fatal("command must be run as Root")
		return false
	}
	return true

}
