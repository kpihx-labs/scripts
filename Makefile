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

# Install hsh and homelab-bot service
install:
	./hsh install
	@mkdir -p $(HOME)/.config/systemd/user
	@cp $(CURDIR)/../sentinel/tg-homelab.service $(HOME)/.config/systemd/user/
	@systemctl --user daemon-reload
	@systemctl --user enable tg-homelab.service
	@systemctl --user restart tg-homelab.service
	@echo "✅ Installed hsh and Homelab Bot service."
