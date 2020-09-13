export AWS_DEFAULT_OUTPUT=json
export AWS_DEFAULT_REGION=ap-northeast-1

################################################################################
# 変数
################################################################################
S3_BUCKET_NAME := member-only-static-content-dev
S3_BUCKET_JSON := s3-bucket-dev.output.json
CLOUDFRONT_JSON := cloudfront-dev.output.json
CLOUDFRONT_OAI_COMMENT := oai-$(S3_BUCKET_NAME)
ORIGIN_ID := S3-$(S3_BUCKET_NAME)

################################################################################
# マクロ
################################################################################
# Make taskの実行
# $(1): makeのtask
define make-task
@echo ''
@echo ''
@echo '--------------------------------------------[ $(1) ]'
@export AWS_PAGER='' && make --no-print-directory $(1)
endef

# Makefileの中身を抽出してhelpとして1行で出す
# $(1): Makefile名
define help
grep -E '^[a-zA-Z0-9_-]+:.*?## .*$$' $(1) \
| grep --invert-match "## non-help" \
| awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-40s\033[0m %s\n", $$1, $$2}'
endef

################################################################################
# タスク
################################################################################
.PHONY: up
up:
	$(call make-task,create-s3-bucket)
	$(call make-task,upload-content)
	$(call make-task,publish-website)
	$(call make-task,create-cloudfront)
	$(call make-task,restrict-s3-bucket-access)
	$(call make-task,restrict-private-content)

.PHONY: down
down:
	$(call make-task,delete-cloudfront)
	$(call make-task,delete-oai)
	$(call make-task,delete-website)
	$(call make-task,empty-s3-bucket)
	$(call make-task,delete-s3-bucket)
	rm -f *.output.json

##################################################
# タスク【S3】
##################################################
.PHONY: create-s3-bucket
create-s3-bucket: ## up s3バケットの作成
	@make --no-print-directory output-s3-bucket > /dev/null 2>&1 \
	|| aws s3api create-bucket --bucket $(S3_BUCKET_NAME) --create-bucket-configuration LocationConstraint=$(AWS_DEFAULT_REGION)
	@make --no-print-directory output-s3-bucket
	@echo Ouputted $(S3_BUCKET_JSON)
.PHONY: output-s3-bucket
output-s3-bucket:
	$(eval S3_BUCKET := $(shell aws s3api list-buckets | jq '.Buckets' | jq -c '.[] | select(.Name == "$(S3_BUCKET_NAME)")'))
	@if [ -n '$(S3_BUCKET)' ]; then \
		echo '$(S3_BUCKET)' | jq '.' > $(S3_BUCKET_JSON); \
	else \
		false; \
	fi
.PHONY: delete-s3-bucket
delete-s3-bucket: ## down s3バケットの削除
	$(eval S3_BUCKET := $(shell aws s3api list-buckets | jq '.Buckets' | jq -c '.[] | select(.Name == "$(S3_BUCKET_NAME)")'))
	@if [ -n '$(S3_BUCKET)' ]; then \
		echo 'S3バケットは手動推奨(再作成に時間をおかないといけないため)'; \
		echo '$$ aws s3api delete-bucket --bucket $(S3_BUCKET_NAME)'; \
	fi
#	[ -n '$(S3_BUCKET)' ] && aws s3api delete-bucket --bucket $(S3_BUCKET_NAME)


.PHONY: upload-content
upload-content: ## up S3バケットにコンテンツをアップロード
	aws s3api put-public-access-block --bucket $(S3_BUCKET_NAME) --public-access-block-configuration BlockPublicAcls=false,IgnorePublicAcls=false,BlockPublicPolicy=false,RestrictPublicBuckets=false
	aws s3 cp index.html s3://$(S3_BUCKET_NAME)/ --acl public-read
	aws s3 cp member-only.html s3://$(S3_BUCKET_NAME)/ --acl public-read
.PHONY: empty-s3-bucket
empty-s3-bucket: ## down S3バケットにあるコンテンツを全て削除
	aws s3 rm s3://$(S3_BUCKET_NAME)/ --recursive


.PHONY: publish-website
publish-website: ## up アップロードしたコンテンツをWebsiteとして公開
	aws s3 website s3://$(S3_BUCKET_NAME)/ --index-document index.html
	aws s3api put-bucket-acl --bucket $(S3_BUCKET_NAME) --acl public-read
	@echo 'Access!!'
	@echo 'http://$(S3_BUCKET_NAME).s3-website-$(AWS_DEFAULT_REGION).amazonaws.com'
.PHONY: delete-website
delete-website: ## down Websiteの公開をストップ
	aws s3api delete-bucket-website --bucket $(S3_BUCKET_NAME)

##################################################
# タスク【CloudFront】
##################################################
.PHONY: create-cloudfront
create-cloudfront: ## up CloudFront(CDN)の作成
	@make --no-print-directory output-cloudfront > /dev/null 2>&1 \
	|| aws cloudfront create-distribution \
		--origin-domain-name $(S3_BUCKET_NAME).s3-website-$(AWS_DEFAULT_REGION).amazonaws.com \
		--default-root-object index.html > /dev/null
	@cloudfront_id=$$(aws cloudfront list-distributions \
		| jq '.DistributionList.Items' \
		| jq -c '.[] | select(.Origins.Items[].DomainName | contains("$(S3_BUCKET_NAME)"))' \
		| jq -r '.Id') \
	&& echo "Waiting cloudfront deploying, $$cloudfront_id" \
	&& aws cloudfront wait distribution-deployed --id "$$cloudfront_id"
	@echo 'Deployed cloudfront'
	@make --no-print-directory output-cloudfront
	@echo 'Ouputted $(CLOUDFRONT_JSON)'
	@echo 'Access!!'
	@cat $(CLOUDFRONT_JSON) | jq '.DomainName' | xargs -I {domain} echo 'http://{domain}'
.PHONY: output-cloudfront
output-cloudfront:
	$(eval CLOUDFRONT := $(shell aws cloudfront list-distributions \
		| jq '.DistributionList.Items' \
		| jq -c '.[] | select(.Origins.Items[].DomainName | contains("$(S3_BUCKET_NAME)"))'))
	@if [ -n '$(CLOUDFRONT)' ]; then \
		echo '$(CLOUDFRONT)' | jq '.' > $(CLOUDFRONT_JSON); \
	else \
		false; \
	fi
.PHONY: delete-cloudfront
delete-cloudfront: ## down CloudFront(CDN)の削除
	$(eval CLOUDFRONT_ID := $(shell aws cloudfront list-distributions \
		| jq '.DistributionList.Items' \
		| jq -c '.[] | select(.Origins.Items[].DomainName | contains("$(S3_BUCKET_NAME)"))' \
		| jq -r '.Id'))
	@if [ -n '$(CLOUDFRONT_ID)' ]; then \
		echo 'Clear cloudfront cache'; \
		aws cloudfront create-invalidation --distribution-id $(CLOUDFRONT_ID) --paths "/*"; \
		config=$$(aws cloudfront get-distribution-config --id $(CLOUDFRONT_ID) | jq -c '.'); \
		is_enabled=$$(echo "$$config" | jq -r '.DistributionConfig.Enabled'); \
		if [ "$$is_enabled" = "true" ]; then \
			etag=$$(echo "$$config" | jq -r '.ETag'); \
			new_config=$$(echo "$$config" | jq '.DistributionConfig' | jq -c '.Enabled |= false'); \
			echo 'update distribution config'; \
			aws cloudfront update-distribution --id $(CLOUDFRONT_ID) --if-match "$$etag" --distribution-config "$$new_config" > /dev/null; \
			echo 'updated, wait deploying, $(CLOUDFRONT_ID)'; \
			aws cloudfront wait distribution-deployed --id $(CLOUDFRONT_ID); \
		fi; \
		etag=$$(aws cloudfront get-distribution-config --id $(CLOUDFRONT_ID) | jq -r '.ETag'); \
		echo 'Delete cloudfront'; \
		aws cloudfront delete-distribution --id $(CLOUDFRONT_ID) --if-match "$$etag"; \
	else \
		echo '該当するCloudFrontがありません'; \
	fi

##################################################
# タスク【S3 & CloudFront】
##################################################
.PHONY: restrict-s3-bucket-access
restrict-s3-bucket-access: ## up 直接S3バケットへのアクセスを禁止、CloudFront限定にする
	$(eval OAI := $(shell aws cloudfront create-cloud-front-origin-access-identity \
		--cloud-front-origin-access-identity-config CallerReference=access-identity-$(S3_BUCKET_NAME),Comment=$(CLOUDFRONT_OAI_COMMENT) | jq -c '.'))
	$(eval OAI_ID := $(shell echo '$(OAI)' | jq -r '.CloudFrontOriginAccessIdentity.Id'))
	$(eval S3_BUCKET_POLICY := $(shell echo '{ \
		"Statement": [{ \
			"Effect": "Allow", \
			"Principal": {"AWS": "arn:aws:iam::cloudfront:user/CloudFront Origin Access Identity $(OAI_ID)"}, \
			"Action": ["s3:GetObject"], \
			"Resource": ["arn:aws:s3:::$(S3_BUCKET_NAME)/*"] \
		}] \
	}'))
	$(eval CLOUDFRONT_ID := $(shell aws cloudfront list-distributions \
		| jq '.DistributionList.Items' \
		| jq -c '.[] | select(.Origins.Items[].DomainName | contains("$(S3_BUCKET_NAME)"))' \
		| jq -r '.Id'))
	$(eval CONFIG := $(shell aws cloudfront get-distribution-config --id $(CLOUDFRONT_ID) | jq -c '.'))
	$(eval ETAG := $(shell echo '$(CONFIG)' | jq -r '.ETag'))
	$(eval S3_ORIGIN_CONFIG := $(shell echo '{ \
		"Id": "$(ORIGIN_ID)", \
		"DomainName": "$(S3_BUCKET_NAME).s3.amazonaws.com", \
		"OriginPath": "", \
		"CustomHeaders": { \
			"Quantity": 0 \
		}, \
		"S3OriginConfig": { \
			"OriginAccessIdentity": "origin-access-identity/cloudfront/$(OAI_ID)" \
		}, \
		"ConnectionAttempts": 3, \
		"ConnectionTimeout": 10 \
	}'))
	$(eval OLD_ORIGINS := $(shell echo '$(CONFIG)' \
		| jq -crS '.DistributionConfig.Origins' \
	))
	$(eval NEW_ORIGINS := $(shell echo '$(OLD_ORIGINS)' \
		| jq '.Quantity |= 1' \
		| jq -crS '.Items |= [$(S3_ORIGIN_CONFIG)]' \
	))
	$(eval NEW_CONFIG := $(shell echo '$(OLD_CONFIG)' \
		| jq '.Origins |= $(NEW_ORIGINS)' \
		| jq '.DefaultCacheBehavior.TargetOriginId |= "$(ORIGIN_ID)"' \
		| jq -crS '.'))
	aws s3api put-bucket-policy --bucket $(S3_BUCKET_NAME) --policy '$(S3_BUCKET_POLICY)'
	aws s3api put-public-access-block --bucket $(S3_BUCKET_NAME) --public-access-block-configuration BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
	@if [ '$(OLD_ORIGINS)' != '$(NEW_ORIGINS)' ]; then \
		aws cloudfront create-invalidation --distribution-id $(CLOUDFRONT_ID) --paths "/*"; \
		aws cloudfront update-distribution --id $(CLOUDFRONT_ID) --if-match $(ETAG) --distribution-config '$(NEW_CONFIG)' > /dev/null; \
		aws cloudfront wait distribution-deployed --id $(CLOUDFRONT_ID); \
	else \
		echo 'CloudFrontのOriginのDistributionConfig.Originsに変更がないので、更新しません'; \
	fi
	@make --no-print-directory output-cloudfront
	@echo 'Ouputted $(CLOUDFRONT_JSON)'
	@echo 'Can not access!!'
	@echo 'http://$(S3_BUCKET_NAME).s3-website-$(AWS_DEFAULT_REGION).amazonaws.com'
	@echo 'Access!!'
	@cat $(CLOUDFRONT_JSON) | jq '.DomainName' | xargs -I {domain} echo 'http://{domain}'

.PHONY: delete-oai
delete-oai: ## down CloudFrontのOriginAccessIdentityを削除(使われてない必要がある)
	$(eval OAI_ID := $(shell aws cloudfront list-cloud-front-origin-access-identities \
		| jq '.CloudFrontOriginAccessIdentityList.Items' \
		| jq -r '.[] | select(.Comment == "$(CLOUDFRONT_OAI_COMMENT)").Id' \
	))
	$(eval OAI_ETAG := $(shell aws cloudfront get-cloud-front-origin-access-identity --id $(OAI_ID) \
		| jq -r '.ETag' \
	))
	aws cloudfront delete-cloud-front-origin-access-identity --id $(OAI_ID) --if-match $(OAI_ETAG)





.PHONY: restrict-private-content
restrict-private-content: ## up 特定のコンテンツをメンバー限定にする
	$(eval CLOUDFRONT_ID := $(shell aws cloudfront list-distributions \
		| jq '.DistributionList.Items' \
		| jq -c '.[] | select(.Origins.Items[].DomainName | contains("$(S3_BUCKET_NAME)"))' \
		| jq -r '.Id'))
	$(eval CONFIG := $(shell aws cloudfront get-distribution-config --id $(CLOUDFRONT_ID) | jq -c '.'))
	$(eval ETAG := $(shell echo '$(CONFIG)' | jq -r '.ETag'))
	$(eval CACHE_BEHAVIOR_ITEM := $(shell cat cache-behavior.template.json \
		| jq '.PathPattern |= "member-only.html"' \
		| jq -c '.TargetOriginId |= "$(ORIGIN_ID)"' \
	))
	$(eval OLD_CACHE_BEHAVIORS := $(shell echo '$(CONFIG)' \
		| jq -crS '.DistributionConfig.CacheBehaviors'))
	$(eval NEW_CACHE_BEHAVIORS := $(shell echo '$(OLD_CACHE_BEHAVIORS)' \
		| jq '.Items |= [$(CACHE_BEHAVIOR_ITEM)]' \
		| jq '.Quantity |= 1' \
		| jq -crS '.' \
	))
	$(eval NEW_CONFIG := $(shell echo '$(OLD_CONFIG)' \
		| jq '.DistributionConfig' \
		| jq '.CacheBehaviors |= $(NEW_CACHE_BEHAVIORS)' \
		| jq -crS '.' \
	))
	@if [ '$(OLD_CACHE_BEHAVIORS)' != '$(NEW_CACHE_BEHAVIORS)' ]; then \
		aws cloudfront create-invalidation --distribution-id $(CLOUDFRONT_ID) --paths "/*"; \
		aws cloudfront update-distribution --id $(CLOUDFRONT_ID) --if-match $(ETAG) --distribution-config '$(NEW_CONFIG)' > /dev/null; \
		aws cloudfront wait distribution-deployed --id $(CLOUDFRONT_ID); \
	else \
		echo 'CloudFrontのOriginのDistributionConfig.CacheBehaviorsに変更がないので、更新しません'; \
	fi



##################################################
# Option
##################################################
.PHONY: get-s3-bucket-acl
get-s3-bucket-acl: ## option バケットのACLを取得
	aws s3api get-bucket-acl --bucket $(S3_BUCKET_NAME) | jq '.'

.PHONY: ls-s3-bucket-objects
list-s3-bucket-objects: ## option バケットの中にあるオブジェクトの一覧
	aws s3api list-objects-v2 --bucket $(S3_BUCKET_NAME) | jq '.'

.PHONY: curl-website
curl-website: ## option curl
	curl http://$(S3_BUCKET_NAME).s3-website-$(AWS_DEFAULT_REGION).amazonaws.com

.PHONY: get-website
get-website: ## option s3バケットに公開中のwebsiteの情報を取得
	aws s3api get-bucket-website --bucket $(S3_BUCKET_NAME)

.PHONY: list-cloudfront
list-cloudfront: ## option CloudFrontのリスト

.PHONY: clear-cache
clear-cache: ## option CloudFrontのキャッシュを全削除
	$(eval CLOUDFRONT_ID := $(shell aws cloudfront list-distributions \
		| jq '.DistributionList.Items' \
		| jq -c '.[] | select(.Origins.Items[].DomainName | contains("$(S3_BUCKET_NAME)"))' \
		| jq -r '.Id'))
	if [ -n '$(CLOUDFRONT_ID)' ]; then \
		aws cloudfront create-invalidation --distribution-id $(CLOUDFRONT_ID) --paths "/*"; \
	else \
		echo 'CloudFrontが見つかりません'; \
	fi

.PHONY: confirm-active-trusted-signers
confirm-active-trusted-signers: ## option CloudFront API を使用して、信頼された署名者が有効であることを確認する
	$(eval CLOUDFRONT_ID := $(shell aws cloudfront list-distributions \
		| jq '.DistributionList.Items' \
		| jq -c '.[] | select(.Origins.Items[].DomainName | contains("$(S3_BUCKET_NAME)"))' \
		| jq -r '.Id' \
	))
	aws cloudfront get-distribution --id $(CLOUDFRONT_ID) \
		| jq '.Distribution.ActiveTrustedSigners'

.PHONY: create-cloudfront-keypair
create-cloudfront-keypair: ## option CloudFrontに使うキーペアを作成（登録にはrootアカウントでする必要がある）
	openssl genrsa -out private_key.pem 4096
	openssl rsa -pubout -in private_key.pem -out public_key.pem



.PHONY: help
help: ## Make タスク一覧
	@echo '######################################################################'
	@echo '# Makeタスク一覧'
	@echo '# $$ make XXX'
	@echo '# or'
	@echo '# $$ make XXX --dry-run'
	@echo '# downシリーズだけ見たい時'
	@echo '# $$ make help | grep "down"'
	@echo '######################################################################'
	@echo $(MAKEFILE_LIST) \
	| tr ' ' '\n' \
	| xargs -I {included-makefile} $(call help,{included-makefile})
