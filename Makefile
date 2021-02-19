# Jenkins needs this target even if it does nothing
change-version:
	stratio/bin/change-version.sh $(version)
