.PHONY: push status backup-host backup-vault maintenance install

# Pushes the current branch and tags to the gitlab remote
push:
	@echo "--> Pushing to gitlab..."
	git push gitlab --all
	git push gitlab --tags

# Global health check
status:
	./hsh status

# Local backup of LXC 100 snapshot
backup-host:
	./hsh backup host

# Local encrypted backup of Vaultwarden
backup-vault:
	./hsh backup vault

# Trigger server-side maintenance
maintenance:
	./hsh maintenance

# Install hsh to ~/.local/bin/hsh
install:
	./hsh install
