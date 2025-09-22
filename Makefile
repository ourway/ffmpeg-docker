# FFmpeg Docker Build Makefile
DOCKER_IMAGE_NAME ?= ffmpeg
DOCKER_TAG ?= latest
DOCKER_REGISTRY ?=
FULL_IMAGE_NAME = $(if $(DOCKER_REGISTRY),$(DOCKER_REGISTRY)/$(DOCKER_IMAGE_NAME),$(DOCKER_IMAGE_NAME))

# Build arguments
BUILD_ARGS =
MAKEFLAGS_ARG ?= -j$(shell nproc)

# Container runtime arguments
CONTAINER_NAME ?= ffmpeg-container
MOUNT_DIR ?= $(PWD)

.PHONY: help
help: ## Show this help message
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

.PHONY: build
build: ## Build the Docker image
	docker build \
		--build-arg MAKEFLAGS="$(MAKEFLAGS_ARG)" \
		-t $(FULL_IMAGE_NAME):$(DOCKER_TAG) \
		.

.PHONY: build-nocache
build-nocache: ## Build the Docker image without cache
	docker build \
		--no-cache \
		--build-arg MAKEFLAGS="$(MAKEFLAGS_ARG)" \
		-t $(FULL_IMAGE_NAME):$(DOCKER_TAG) \
		.

.PHONY: run
run: ## Run ffmpeg interactively with current directory mounted
	docker run --rm -it \
		-v $(MOUNT_DIR):/data \
		-w /data \
		$(FULL_IMAGE_NAME):$(DOCKER_TAG) \
		ffmpeg

.PHONY: shell
shell: ## Open a shell in the container
	docker run --rm -it \
		-v $(MOUNT_DIR):/data \
		-w /data \
		--entrypoint /bin/sh \
		$(FULL_IMAGE_NAME):$(DOCKER_TAG)

.PHONY: version
version: ## Show ffmpeg version info
	docker run --rm $(FULL_IMAGE_NAME):$(DOCKER_TAG) ffmpeg -version

.PHONY: codecs
codecs: ## List available codecs
	docker run --rm $(FULL_IMAGE_NAME):$(DOCKER_TAG) ffmpeg -codecs

.PHONY: formats
formats: ## List available formats
	docker run --rm $(FULL_IMAGE_NAME):$(DOCKER_TAG) ffmpeg -formats

.PHONY: push
push: ## Push image to registry (requires DOCKER_REGISTRY to be set)
	@if [ -z "$(DOCKER_REGISTRY)" ]; then \
		echo "Error: DOCKER_REGISTRY not set"; \
		exit 1; \
	fi
	docker push $(FULL_IMAGE_NAME):$(DOCKER_TAG)

.PHONY: tag
tag: ## Tag image with additional tag (usage: make tag NEW_TAG=v1.0.0)
	@if [ -z "$(NEW_TAG)" ]; then \
		echo "Error: NEW_TAG not set. Usage: make tag NEW_TAG=v1.0.0"; \
		exit 1; \
	fi
	docker tag $(FULL_IMAGE_NAME):$(DOCKER_TAG) $(FULL_IMAGE_NAME):$(NEW_TAG)

.PHONY: clean
clean: ## Remove the Docker image
	docker rmi $(FULL_IMAGE_NAME):$(DOCKER_TAG) || true

.PHONY: prune
prune: ## Remove unused Docker resources
	docker system prune -f

.PHONY: test
test: ## Test ffmpeg with a simple conversion (requires sample.mp4 in current dir)
	@if [ ! -f sample.mp4 ]; then \
		echo "Creating a test video..."; \
		docker run --rm -v $(PWD):/data -w /data $(FULL_IMAGE_NAME):$(DOCKER_TAG) \
			ffmpeg -f lavfi -i testsrc=duration=5:size=320x240:rate=30 \
			-f lavfi -i sine=frequency=1000:duration=5 \
			-c:v libx264 -c:a aac sample.mp4; \
	fi
	@echo "Converting sample.mp4 to sample_out.webm..."
	docker run --rm -v $(PWD):/data -w /data $(FULL_IMAGE_NAME):$(DOCKER_TAG) \
		ffmpeg -i sample.mp4 -c:v libvpx -c:a libopus sample_out.webm
	@echo "Test completed. Check sample_out.webm"

.PHONY: logs
logs: ## Show build logs from last build
	docker logs $(CONTAINER_NAME) 2>&1 || echo "No container logs found"

.PHONY: size
size: ## Show image size
	docker images $(FULL_IMAGE_NAME):$(DOCKER_TAG) --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}"