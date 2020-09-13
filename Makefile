include makefiles/gitignore.mk
include makefiles/ytt.mk
include makefiles/rq.mk
include makefiles/help.mk

################################################################################
# 変数
################################################################################

################################################################################
# マクロ
################################################################################

################################################################################
# タスク
################################################################################
.PHONY: deploy-docs
deploy-docs: ## ドキュメントをデプロイする
	git subtree push --prefix docs/html/ origin gh-pages

.PHONY: nginx
nginx: ## ドキュメントをデプロイする
	docker run --rm -it --mount type=bind,source=$(PWD)/awscli-edition/,target=/usr/share/nginx/html/ --publish 80:80 nginx:stable
