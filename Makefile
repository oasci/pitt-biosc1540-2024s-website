SHELL := /usr/bin/env bash
PYTHON_VERSION := 3.11
PYTHON_VERSION_CONDENSED := 311
PACKAGE_NAME := pitt-biosc-1540-2024-spring
REPO_PATH := $(shell git rev-parse --show-toplevel)
PACKAGE_PATH := $(REPO_PATH)/$(PACKAGE_NAME)
CONDA_NAME := $(PACKAGE_NAME)-dev
CONDA := conda run -n $(CONDA_NAME)
DOCS_URL := https://oasci.org/pitt-biosc-1540-2024-spring
ADDR := $(lsof -ti tcp:$(PORT))

###   ENVIRONMENT   ###

.PHONY: conda-create
conda-create:
	- conda deactivate
	conda remove -y -n $(CONDA_NAME) --all
	conda create -y -n $(CONDA_NAME)
	$(CONDA) conda install -y python=$(PYTHON_VERSION)
	$(CONDA) conda install -y conda-lock

# Default packages that we always need.
.PHONY: conda-setup
conda-setup:
	$(CONDA) conda install -y -c conda-forge poetry
	$(CONDA) conda install -y -c conda-forge pre-commit
	$(CONDA) conda install -y -c conda-forge tomli tomli-w
	$(CONDA) conda install -y -c conda-forge conda-poetry-liaison

# Conda-only packages specific to this project.
.PHONY: conda-dependencies
conda-dependencies:
	echo "No conda-only packages are required."

.PHONY: conda-lock
conda-lock:
	- rm $(REPO_PATH)/conda-lock.yml
	$(CONDA) conda env export --from-history | grep -v "^prefix" > environment.yml
	$(CONDA) conda-lock -f environment.yml -p linux-64 -p osx-64 -p win-64
	rm $(REPO_PATH)/environment.yml
	$(CONDA) cpl-deps $(REPO_PATH)/pyproject.toml --env_name $(CONDA_NAME)
	$(CONDA) cpl-clean --env_name $(CONDA_NAME)

.PHONY: from-conda-lock
from-conda-lock:
	$(CONDA) conda-lock install -n $(CONDA_NAME) $(REPO_PATH)/conda-lock.yml
	$(CONDA) cpl-clean --env_name $(CONDA_NAME)

.PHONY: pre-commit-install
pre-commit-install:
	$(CONDA) pre-commit install

# Reads `pyproject.toml`, solves environment, then writes lock file.
.PHONY: poetry-lock
poetry-lock:
	$(CONDA) poetry lock --no-interaction

.PHONY: install
install:
	$(CONDA) poetry install --no-interaction --no-root

.PHONY: refresh
refresh: conda-create from-conda-lock pre-commit-install install



###   FORMATTING   ###

.PHONY: validate
validate:
	- $(CONDA) pre-commit run --all-files

.PHONY: formatting
formatting:
	- $(CONDA) isort --settings-path pyproject.toml ./
	- $(CONDA) black --config pyproject.toml ./




###   LINTING   ###

.PHONY: check-codestyle
check-codestyle:
	$(CONDA) isort --diff --check-only $(PACKAGE_PATH)
	$(CONDA) black --diff --check --config pyproject.toml $(PACKAGE_PATH)
	- $(CONDA) pylint --rcfile pyproject.toml $(PACKAGE_PATH)

.PHONY: lint
lint: check-codestyle



###   CLEANING   ###

.PHONY: pycache-remove
pycache-remove:
	find . | grep -E "(__pycache__|\.pyc|\.pyo$$)" | xargs rm -rf

.PHONY: dsstore-remove
dsstore-remove:
	find . | grep -E ".DS_Store" | xargs rm -rf

.PHONY: mypycache-remove
mypycache-remove:
	find . | grep -E ".mypy_cache" | xargs rm -rf

.PHONY: ipynbcheckpoints-remove
ipynbcheckpoints-remove:
	find . | grep -E ".ipynb_checkpoints" | xargs rm -rf

.PHONY: pytestcache-remove
pytestcache-remove:
	find . | grep -E ".pytest_cache" | xargs rm -rf

.PHONY: build-remove
build-remove:
	rm -rf build/

.PHONY: cleanup
cleanup: pycache-remove dsstore-remove mypycache-remove ipynbcheckpoints-remove pytestcache-remove



###   MKDOCS   ###

.PHONY: serve
serve:
	# Ensure we have all files possible
	export SECRETS_GPG_ARMOR=0
	- $(CONDA) git secret hide -m 2>&1 || true  # Only encrpyt files that have been modified
	- $(CONDA) git secret reveal -fF 2>&1 || true  # Decrypt all files from the secret to ensure consistency

	echo "Served at http://127.0.0.1:8910/"
	$(CONDA) mkdocs serve -a localhost:8910

.PHONY: build
build:
	export SECRETS_GPG_ARMOR=0
	- $(CONDA) git secret hide -m 2>&1 || true  # Only encrpyt files that have been modified
	- $(CONDA) git secret reveal -fF 2>&1 || true  # Decrypt all files from the secret to ensure consistency

	$(CONDA) mkdocs build

.PHONY: open
open:
	xdg-open ./site/index.html 2>/dev/null

.PHONY: deploy
deploy:
	$(CONDA) mkdocs gh-deploy --force
