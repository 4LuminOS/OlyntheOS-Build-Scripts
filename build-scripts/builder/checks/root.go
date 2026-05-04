package checks

import (
	"log"
)

// AllChecks Handles all checks and their errors,
// terminating the program if any errors occur and prints the error to stdout
func AllChecks() (passed bool) {

	privCheck := PrivilegeCheck()

	osPassed, osErr := OsCheck()
	if osErr != nil {
		log.Fatal(osErr)
	}

	netPassed, netErr := NetCheck()
	if netErr != nil {
		log.Fatal(netErr)
	}

	storagePassed, storageErr := StorageCheck()
	if storageErr != nil {
		log.Fatal(storageErr)
	}

	if privCheck && osPassed && netPassed && storagePassed == true {
		return true
	}
	return false

}
