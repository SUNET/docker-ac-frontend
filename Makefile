all: build push
build:
	docker build --no-cache=true -t ac-frontend .
	docker tag -f ac-frontend docker.sunet.se/ac-frontend
update:
	docker build -t ac-frontend .
	docker tag -f ac-frontend docker.sunet.se/ac-frontend
push:
	docker push docker.sunet.se/ac-frontend	
