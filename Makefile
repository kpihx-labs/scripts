.PHONY: push

# Pushes the current branch and tags to the gitlab remote
push:
	@echo "--> Pushing to gitlab..."
	git push gitlab --all
	git push gitlab --tags
