.PHONY: test
test:
	cd sam-app && python3 -m pytest tests/ -v

.PHONY: build
build:
	cd sam-app && sam build --use-container

.PHONY: start-api
start-api:
	cd sam-app && sam local start-api

# invoke: 呼び出す
.PHONY: local-invoke
local-invoke:
	cd sam-app && sam local invoke

# 初回: sam deploy --guided
.PHONY: deploy
deploy:
	cd sam-app && sam deploy --guided

.PHONY: clean
clean:
	cd sam-app && aws cloudformation delete-stack --stack-name sam-app --region ap-northeast-1
