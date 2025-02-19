version ?= 1.5.0-pre.0

ci: clean deps lint package

clean:
	rm -rf bin/ vendor Gemfile.lock

stage:
	mkdir -p stage

package: stage
	tar \
	    --exclude='.git*' \
			--exclude='.bundle*' \
			--exclude='bin*' \
			--exclude='vendor*' \
	    --exclude='.tmp*' \
	    --exclude='stage*' \
	    --exclude='.idea*' \
	    --exclude='.DS_Store*' \
	    --exclude='logs*' \
	    --exclude='*.retry' \
	    --exclude='*.iml' \
	    -cvzf \
	    stage/aem-test-suite-$(version).tar.gz .

################################################################################
# Dependencies resolution targets.
# For deps-test-local targets, the local dependencies must be available on the
# same directory level where aem-stack-manager-messenger is at. The idea is
# that you can test AEM Stack Manager Messenger while also developing those
# dependencies locally.
################################################################################

deps:
	gem install bundler --version=2.0.2
	rm -rf .bundle
	bundle update

	bundle install --binstubs
	bundle exec inspec vendor --overwrite
	cd vendor && find . -name "*.tar.gz" -exec tar -xzvf '{}' \; -exec rm '{}' \;
	cd vendor && mv inspec-aem-aws-*.*.* inspec-aem-aws && cd inspec-aem-aws && make clean deps
	cd vendor && mv inspec-aem-security-*.*.* inspec-aem-security && cd inspec-aem-security && make clean deps

lint:
	bundle exec rubocop Gemfile

# copy user config to InSpec profiles config
config-aem-aws:
	cp $(config_path)/aem-aws.yaml vendor/inspec-aem-aws/conf/aem-aws.yaml
config-aem:
	cp $(config_path)/aem.yaml vendor/inspec-aem-security/conf/aem.yaml

acceptance:
	rspec acceptance/

define test_security
	cd vendor/inspec-aem-security && \
	  INSPEC_AEM_SECURITY_CONF=conf/aem.yaml \
		aem_stack_prefix=$(2) \
		make test-$(1)
endef

define aem_aws
	cd vendor/inspec-aem-aws && \
	  INSPEC_AEM_AWS_CONF=conf/aem-aws.yaml \
		aem_stack_prefix=$(2) \
		make test-$(1)
endef

define test-readiness-consolidated
	cd vendor/inspec-aem-aws && \
	  INSPEC_AEM_AWS_CONF=conf/aem-aws.yaml \
		aem_stack_prefix=$(1) \
		aem_component=author-publish-dispatcher \
		make test-successful-provisioning-author-publish-dispatcher
endef

define test-acceptance
	cd vendor/inspec-aem-aws && \
	  INSPEC_AEM_AWS_CONF=conf/aem-aws.yaml \
		aem_stack_prefix=$(2) \
		make test-acceptance-$(1)
endef

define test-contenthealthcheck-state
	cd vendor/inspec-aem-aws && \
	  INSPEC_AEM_AWS_CONF=conf/aem-aws.yaml \
		aem_stack_prefix=$(1) \
		make test-contenthealthcheck-alarm-state
endef

test-security-author:
	$(call test_security,author,$(stack_prefix))

test-security-publish:
	$(call test_security,publish,$(stack_prefix))

test-security-publish-dispatcher:
	$(call test_security,publish-dispatcher,$(stack_prefix))

test-aem-aws-readiness-full-set:
	$(call aem_aws,readiness,$(stack_prefix))

test-aem-aws-provisioning-full-set:
	$(call aem_aws,provisioning,$(stack_prefix))

test-aem-aws-provisioning-readiness-full-set:
	$(call aem_aws,provisioning-readiness,$(stack_prefix))

test-aem-aws-readiness-full-set-with-disabled-chaosmonkey:
	$(call aem_aws,readiness-with-disabled-chaosmonkey,$(stack_prefix))

test-aem-aws-provisioning-full-set-with-disabled-chaosmonkey:
	$(call aem_aws,provisioning-with-disabled-chaosmonkey,$(stack_prefix))

test-aem-aws-provisioning-readiness-full-set-with-disabled-chaosmonkey:
	$(call aem_aws,provisioning-readiness-with-disabled-chaosmonkey,$(stack_prefix))

test-aem-aws-readiness-consolidated:
	$(call test-readiness-consolidated,$(stack_prefix))

test-aem-aws-recovery-full-set:
	$(call aem_aws,recovery,$(stack_prefix))

test-aem-aws-recovery-full-set-with-disabled-chaosmonkey:
	$(call aem_aws,recovery-with-disabled-chaosmonkey,$(stack_prefix))

test-acceptance-architecture-full-set:
	$(call test-acceptance,full-set,$(stack_prefix))

test-acceptance-author-primary:
	$(call test-acceptance,author-primary,$(stack_prefix))

test-acceptance-author-standby:
	$(call test-acceptance,author-standby,$(stack_prefix))

test-acceptance-publish:
	$(call test-acceptance,publish,$(stack_prefix))

test-acceptance-author-dispatcher:
	$(call test-acceptance,author-dispatcher,$(stack_prefix))

test-acceptance-publish-dispatcher:
	$(call test-acceptance,publish-dispatcher,$(stack_prefix))

test-acceptance-orchestrator:
	$(call test-acceptance,orchestrator,$(stack_prefix))

test-contenthealthcheck-alarm:
	$(call test-contenthealthcheck-state,$(stack_prefix))

test-security: config-aem test-security-author test-security-publish test-security-publish-dispatcher

test-readiness-full-set: config-aem-aws test-aem-aws-readiness-full-set

test-provisioning-full-set: config-aem-aws test-aem-aws-provisioning-full-set

test-provisioning-readiness-full-set: config-aem-aws test-aem-aws-provisioning-readiness-full-set

test-readiness-full-set-with-disabled-chaosmonkey: config-aem-aws test-aem-aws-readiness-full-set

test-provisioning-full-set-with-disabled-chaosmonkey: config-aem-aws test-aem-aws-provisioning-full-set

test-provisioning-readiness-full-set-with-disabled-chaosmonkey: config-aem-aws test-aem-aws-provisioning-readiness-full-set

test-readiness-consolidated: config-aem-aws test-aem-aws-readiness-consolidated

test-recovery-full-set: config-aem-aws test-aem-aws-recovery-full-set

test-recovery-full-set-with-disabled-chaosmonkey: config-aem-aws test-aem-aws-recovery-full-set-with-disabled-chaosmonkey

test-acceptance-full-set: config-aem-aws test-acceptance-architecture-full-set test-acceptance-author-primary test-acceptance-author-standby test-acceptance-publish test-acceptance-author-dispatcher test-acceptance-publish-dispatcher test-acceptance-orchestrator

test-contenthealthcheck-alarm-state: config-aem-aws test-contenthealthcheck-alarm

release:
	rtk release

.PHONY: ci deps lint acceptance test-security-author test-security-publish test-security-publish-dispatcher test-security release
