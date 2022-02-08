build:
	DOCKER_BUILDKIT=1 docker build . --output type=local,dest=.

build-custom:
	DOCKER_BUILDKIT=1 docker build --build-arg CUSTOM=1 . --output type=local,dest=.

clean:
	@rm -f u-boot.bin.sd.bin
